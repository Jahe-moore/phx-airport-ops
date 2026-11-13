# 04_build_flights.R
# Builds the one table every analysis script uses: one row per PHX departure in the window,
# with its inbound aircraft link, delay split, taxi excess, hourly load, and weather.
#
# Definitions (PLAN.md section 6, with Phase 0 decisions):
#   dep_delay_pos   departure delay with early departures counted as zero
#   inherited       min(inbound arrival lateness, departure delay), floored at zero, for the same
#                   tail number's turn at PHX. Zero when no inbound link exists.
#   phx_originated  dep_delay_pos minus inherited
#   excess_taxi     taxi-out minus the carrier's quiet-hour baseline (median taxi-out in the
#                   quietest quartile of hours, 06:00 to 22:59), floored at zero per flight
#   load            FAA ASPM scheduled departures in that date and clock hour (all carriers,
#                   so it is a more complete load measure than BTS alone)
#
# Usage: Rscript R/04_build_flights.R

source("R/00_setup.R")
w <- window_args()

dep_all <- readRDS(file.path(dir_processed, sprintf("bts_departures_%s.rds", w$tag)))
arr_all <- readRDS(file.path(dir_processed, sprintf("bts_arrivals_%s.rds", w$tag)))
wx      <- readRDS(file.path(dir_processed, sprintf("weather_hourly_%s.rds", w$tag)))
aspm    <- readRDS(file.path(dir_processed, "faa_aspm_hourly.rds"))

dep <- dep_all |> filter(flight_date >= w$first, flight_date <= w$end)

# ---- Tail-number link (same method as Phase 0) ---------------------------------
# Latest scheduled arrival of the same aircraft at PHX at or before the scheduled departure,
# within 24 hours. If two departures claim one inbound, only the first keeps it.
arr_ok <- arr_all |> filter(!cancelled, !diverted, !is.na(tail)) |>
  transmute(tail, in_sched_arr = sched_arr, in_actual_arr = actual_arr, in_arr_delay = arr_delay,
            in_origin = origin, join_time = sched_arr) |> as.data.table()
dep_dt <- dep |> mutate(row_id = row_number(), join_time = sched_dep) |> as.data.table()
linked <- arr_ok[dep_dt, roll = 24 * 3600, on = .(tail, join_time)] |> as_tibble() |> arrange(row_id)

linked <- linked |>
  mutate(matched = !is.na(in_sched_arr) & !cancelled) |>
  # Rank only among flown, linked departures, so a cancelled flight can never take the link
  group_by(tail, in_sched_arr, matched) |>
  mutate(matched = matched & row_number(sched_dep) == 1) |>
  ungroup() |>
  mutate(across(c(in_sched_arr, in_actual_arr, in_arr_delay, in_origin), ~ if_else(matched, .x, NA)),
         sched_turn_min = as.numeric(difftime(sched_dep, in_sched_arr, units = "mins")))

# ---- Delay split ---------------------------------------------------------------
flights <- linked |> mutate(
  dep_delay_pos  = pmax(dep_delay, 0),
  inherited      = if_else(matched & !is.na(in_arr_delay) & !is.na(dep_delay),
                           pmax(pmin(in_arr_delay, dep_delay), 0), 0),
  phx_originated = pmax(dep_delay_pos - inherited, 0),
  sched_hour_start = floor_date(sched_dep, "hour"),
  dow   = lubridate::wday(flight_date, label = TRUE, week_start = 1),
  month = month(flight_date), year = year(flight_date),
  regional = carrier %in% c("OO", "MQ", "YX", "9E", "OH", "QX", "ZW", "G7", "PT", "C5", "EV"))

# ---- Load: FAA scheduled departures in the hour --------------------------------
# Load uses the SCHEDULED hour (what the schedule asks of the airport). FAA's taxi-out delay
# uses the ACTUAL pushback hour, because a late flight taxis in a later, possibly busier hour.
flights <- flights |>
  left_join(aspm |> select(sched_hour_start = hour_start, load = sched_dep), by = "sched_hour_start") |>
  mutate(actual_dep_hour_start = floor_date(actual_dep, "hour")) |>
  left_join(aspm |> select(actual_dep_hour_start = hour_start, aspm_taxi_out_delay = avg_taxi_out_delay),
            by = "actual_dep_hour_start")

# ---- Excess taxi against each carrier's quiet-hour baseline ----------------------
# Quartile of distinct date-hours (not of flights, which would tilt it toward busy hours)
hours_06_22 <- distinct(flights, sched_hour_start, sched_hour, load) |> filter(sched_hour %in% 6:22)
q25 <- quantile(hours_06_22$load, 0.25, na.rm = TRUE)
baseline <- flights |>
  filter(!cancelled, sched_hour %in% 6:22, load <= q25, !is.na(taxi_out)) |>
  group_by(carrier) |> summarise(baseline_taxi = median(taxi_out), baseline_n = n(), .groups = "drop")
flights <- flights |> left_join(baseline, by = "carrier") |>
  mutate(excess_taxi = pmax(taxi_out - baseline_taxi, 0))

# ---- Weather at the scheduled hour -----------------------------------------------
flights <- flights |> left_join(wx |> rename(sched_hour_start = hour_start), by = "sched_hour_start")

saveRDS(flights, file.path(dir_processed, "flights.rds"))
saveRDS(baseline, file.path(dir_processed, "taxi_baseline_by_carrier.rds"))
message(sprintf("flights: %s departures, %s flown, link rate %.1f%% of flown with tail; quiet-hour threshold %.0f deps/hour",
                format(nrow(flights), big.mark = ","), format(sum(!flights$cancelled), big.mark = ","),
                100 * mean(flights$matched[!flights$cancelled & !is.na(flights$tail)]), q25))
