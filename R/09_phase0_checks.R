# 09_phase0_checks.R
# Phase 0 feasibility checks. Every number in docs/phase0_memo.md comes from the tables
# this script writes to output/tables/phase0_*.csv.
#
# Go criteria (PLAN.md section 7):
#   1. Tail-number linking succeeds for at least 80% of PHX departures
#   2. Taxi-out and departure delay vary meaningfully by hour
#   3. At least one FAA dataset is usable
#
# Usage: Rscript R/09_phase0_checks.R 2025 7   (run after the 02_clean scripts for the full window)

source("R/00_setup.R")

args  <- commandArgs(trailingOnly = TRUE)
year  <- if (length(args) >= 1) as.integer(args[1]) else p0_year
month <- if (length(args) >= 2) as.integer(args[2]) else p0_month
tag   <- month_tag(year, month)
m_start <- as.Date(sprintf("%d-%02d-01", year, month))
m_end   <- ceiling_date(m_start, "month") - 1

# Reads the full-window processed tables and keeps the test month (plus the prior month for linking)
wtag <- window_args(c(window_start, window_end))$tag
keep <- function(df, col) df[df[[col]] >= m_start - 31 & df[[col]] <= m_end + 1, ]
dep_all <- keep(readRDS(file.path(dir_processed, sprintf("bts_departures_%s.rds", wtag))), "flight_date")
arr_all <- keep(readRDS(file.path(dir_processed, sprintf("bts_arrivals_%s.rds", wtag))), "flight_date")
wx      <- readRDS(file.path(dir_processed, sprintf("weather_hourly_%s.rds", wtag)))

dep <- dep_all |> filter(flight_date >= m_start, flight_date <= m_end)   # the test month only
summary_rows <- list()
add <- function(section, metric, value) summary_rows[[length(summary_rows) + 1]] <<- tibble(section, metric, value = as.character(value))
pct <- function(x) round(100 * x, 1)

# ---- 1. Row counts and missing data -----------------------------------------
flown <- dep |> filter(!cancelled)
add("counts", "phx_departures_scheduled", nrow(dep))
add("counts", "phx_departures_cancelled", sum(dep$cancelled))
add("counts", "phx_departures_diverted", sum(dep$diverted))
add("counts", "phx_arrivals_scheduled_in_month", sum(arr_all$flight_date >= m_start & arr_all$flight_date <= m_end))
add("counts", "carriers", n_distinct(dep$carrier))

missing <- flown |> summarise(across(c(tail, dep_delay, taxi_out, wheels_off, arr_delay), ~ pct(mean(is.na(.x))))) |>
  pivot_longer(everything(), names_to = "field", values_to = "pct_missing_among_flown")
save_table(missing, "phase0_bts_missing")
cause_share <- flown |> summarise(
  pct_arr_delay_15plus = pct(mean(arr_delay >= 15, na.rm = TRUE)),
  pct_cause_fields_populated = pct(mean(!is.na(carrier_delay))))
add("missing", "pct_flown_with_arrival_delay_15plus", cause_share$pct_arr_delay_15plus)
add("missing", "pct_flown_with_cause_fields", cause_share$pct_cause_fields_populated)
save_table(dep |> count(carrier, name = "departures") |> arrange(desc(departures)), "phase0_bts_carriers")

# ---- 2. Tail-number linking (sub-question 1.1) --------------------------------
# For each departure, find the same aircraft's most recent SCHEDULED arrival at PHX
# at or before the departure's scheduled time, within 24 hours.
# Scheduled times are used for the search because the airline's plan is what pairs an
# inbound with an outbound; actual times are then used to check the link makes sense.
arr_ok <- arr_all |> filter(!cancelled, !diverted, !is.na(tail)) |>
  transmute(tail, in_sched_arr = sched_arr, in_actual_arr = actual_arr, in_arr_delay = arr_delay,
            in_origin = origin, in_carrier = carrier, join_time = sched_arr) |> as.data.table()
dep_dt <- dep |> mutate(row_id = row_number(), join_time = sched_dep) |> as.data.table()
setkey(arr_ok, tail, join_time); setkey(dep_dt, tail, join_time)
linked <- arr_ok[dep_dt, roll = 24 * 3600, on = .(tail, join_time)] |> as_tibble() |> arrange(row_id)

linked <- linked |> mutate(
  matched = !is.na(in_sched_arr),
  ground_actual_min = as.numeric(difftime(actual_dep, in_actual_arr, units = "mins")),   # real time at the gate
  turn_sched_min    = as.numeric(difftime(sched_dep, in_sched_arr, units = "mins")))

eligible <- linked |> filter(!cancelled, !is.na(tail))

# One inbound should feed one outbound. When two flown departures claim the same inbound
# (the aircraft left PHX twice with no BTS-reported arrival in between, e.g. a return to the
# gate or a leg flown by a non-reporting operator), only the first keeps the link.
dup_inbounds <- eligible |> filter(matched) |> count(tail, in_sched_arr) |> filter(n > 1)
eligible <- eligible |> group_by(tail, in_sched_arr) |>
  mutate(matched = matched & (is.na(in_sched_arr) | row_number(sched_dep) == 1)) |> ungroup()
match_tbl <- tibble(
  denominator = c("all scheduled departures (strict: one departure per inbound)",
                  "flown departures with a tail number (strict)",
                  "flown departures with a tail number, excluding day 1 of month (strict)"),
  departures = c(nrow(linked), nrow(eligible), sum(eligible$flight_date > m_start)),
  matched    = c(sum(eligible$matched), sum(eligible$matched), sum(eligible$matched & eligible$flight_date > m_start))) |>
  mutate(match_rate_pct = pct(matched / departures))
save_table(match_tbl, "phase0_tail_match_rate")

good <- eligible |> filter(matched)
turn_q <- quantile(good$ground_actual_min, c(0, .01, .05, .25, .5, .75, .95, .99, 1), na.rm = TRUE)
turn_tbl <- tibble(quantile = names(turn_q), ground_time_min = round(as.numeric(turn_q), 1))
save_table(turn_tbl, "phase0_turn_time_distribution")
add("tail_link", "matched_with_negative_ground_time", sum(good$ground_actual_min < 0, na.rm = TRUE))
add("tail_link", "matched_with_ground_time_under_20_min", sum(good$ground_actual_min < 20, na.rm = TRUE))
add("tail_link", "inbounds_claimed_by_more_than_one_departure", nrow(dup_inbounds))
add("tail_link", "matched_inbound_from_different_carrier", sum(good$in_carrier != good$carrier, na.rm = TRUE))

# Unmatched flown departures: are they first flights of the day (aircraft that overnighted
# without a PHX arrival in BTS, e.g. after maintenance or an international or non-reporting leg)?
unmatched <- eligible |> filter(!matched)
save_table(unmatched |> count(carrier, sort = TRUE, name = "unmatched_departures") |>
             left_join(eligible |> count(carrier, name = "eligible_departures"), by = "carrier") |>
             mutate(pct_unmatched = pct(unmatched_departures / eligible_departures)),
           "phase0_tail_unmatched_by_carrier")

# Inherited delay, first look (PLAN.md section 6 definitions)
inh <- good |> filter(!is.na(dep_delay), !is.na(in_arr_delay)) |> mutate(
  dep_delay_pos = pmax(dep_delay, 0),
  inherited = pmax(pmin(in_arr_delay, dep_delay), 0),
  phx_originated = pmax(dep_delay_pos - inherited, 0))
inh_tbl <- inh |> summarise(
  departures = n(),
  total_dep_delay_min = sum(dep_delay_pos),
  inherited_min = sum(inherited),
  phx_originated_min = sum(phx_originated)) |>
  mutate(inherited_share_pct = pct(inherited_min / total_dep_delay_min))
save_table(inh_tbl, "phase0_inherited_delay_first_look")

# ---- 3. Variation by hour (go criterion 2) ------------------------------------
# Load measure: scheduled departures in that date and clock hour.
load <- dep |> count(flight_date, sched_hour, name = "deps_in_hour")
flown_l <- flown |> left_join(load, by = c("flight_date", "sched_hour"))

# Excess taxi-out baseline: each carrier's median taxi-out in the quietest quartile of
# date-hours (hours from 06:00 to 22:59 only, so overnight oddities don't set the baseline).
q25 <- quantile(load$deps_in_hour[load$sched_hour %in% 6:22], 0.25)
baseline <- flown_l |> filter(sched_hour %in% 6:22, deps_in_hour <= q25, !is.na(taxi_out)) |>
  group_by(carrier) |> summarise(baseline_taxi = median(taxi_out), n_base = n(), .groups = "drop")
flown_l <- flown_l |> left_join(baseline, by = "carrier") |> mutate(excess_taxi = taxi_out - baseline_taxi)
add("hourly", "quiet_hour_threshold_deps_per_hour", q25)

by_hour <- flown_l |> group_by(sched_hour) |> summarise(
  departures = n(),
  avg_deps_per_day = round(n() / n_distinct(dep$flight_date), 1),
  mean_dep_delay = round(mean(pmax(dep_delay, 0), na.rm = TRUE), 2),
  pct_dep_15plus = pct(mean(dep_delay >= 15, na.rm = TRUE)),
  mean_taxi_out = round(mean(taxi_out, na.rm = TRUE), 2),
  p90_taxi_out = quantile(taxi_out, .9, na.rm = TRUE),
  mean_excess_taxi = round(mean(excess_taxi, na.rm = TRUE), 2),
  .groups = "drop")
save_table(by_hour, "phase0_by_hour")
busy <- by_hour |> filter(sched_hour %in% 6:22)
add("hourly", "dep_delay_range_across_hours_6_to_22", paste(range(busy$mean_dep_delay), collapse = " to "))
add("hourly", "taxi_out_range_across_hours_6_to_22", paste(range(busy$mean_taxi_out), collapse = " to "))
add("hourly", "corr_hourly_load_vs_taxi_out", round(cor(flown_l$deps_in_hour, flown_l$taxi_out, use = "complete.obs"), 3))

p <- by_hour |> filter(sched_hour %in% 5:23) |>
  select(sched_hour, `Mean departure delay (min, early = 0)` = mean_dep_delay, `Mean taxi-out (min)` = mean_taxi_out,
         `Departures per day` = avg_deps_per_day) |>
  pivot_longer(-sched_hour) |>
  ggplot(aes(sched_hour, value)) + geom_col(fill = "#3b6e8f") +
  facet_wrap(~ name, ncol = 1, scales = "free_y") +
  labs(title = "PHX departures by scheduled hour, July 2025 (Phase 0 check)",
       x = "Scheduled departure hour (Phoenix local)", y = NULL,
       caption = "Source: BTS Reporting Carrier On-Time Performance, July 2025. Flown departures only.") +
  theme_minimal(base_size = 11)
ggsave(file.path(dir_figures, "phase0_by_hour.png"), p, width = 8, height = 7, dpi = 150)

# ---- 4. FAA cross-checks -------------------------------------------------------
aspm_file <- file.path(dir_raw, "faa_aspm_airport_phx_2025_07_15_hourly.txt")
if (file.exists(aspm_file)) {
  aspm_tot <- grep("^Total :", readLines(aspm_file), value = TRUE)
  v <- as.numeric(strsplit(trimws(sub("Total :", "", aspm_tot)), "\\s+")[[1]])
  d15 <- flown_l |> filter(flight_date == as.Date("2025-07-15"))
  aspm_cmp <- tibble(
    metric = c("departures (ASPM: for metric computation; BTS: flown)", "mean taxi-out (min)",
               "mean taxi-out delay vs unimpeded (ASPM) / excess taxi vs quiet-hour baseline (BTS), signed",
               "same, BTS excess floored at zero per flight"),
    # Total-row positions: 1 sched dep, 2 sched arr, 3 deps for metric, 4 arrs for metric,
    # 5-7 on-time %, 8 gate dep delay, 9 taxi-out time, 10 taxi-out delay
    faa_aspm = c(v[3], v[9], v[10], v[10]),
    bts = c(nrow(d15), round(mean(d15$taxi_out, na.rm = TRUE), 2), round(mean(d15$excess_taxi, na.rm = TRUE), 2),
            round(mean(pmax(d15$excess_taxi, 0), na.rm = TRUE), 2)))
  save_table(aspm_cmp, "phase0_aspm_vs_bts_2025_07_15")
}

opsnet_file <- file.path(dir_raw, "faa_opsnet_delays_phx_2025_07_daily.txt")
if (file.exists(opsnet_file)) {
  rows <- grep("^PHX [0-9]", readLines(opsnet_file), value = TRUE)
  # Field positions per the header notes in the raw file: 1 facility, 2 date, 3 total ops,
  # 4 system impact delays, 13-16 by class, 17 weather, 18 volume, 22 avg min, 23 total min
  f <- do.call(rbind, strsplit(rows, "\\s+"))
  ops <- tibble(date = mdy(f[, 2]), total_ops = as.numeric(f[, 3]), sysimp_delays = as.numeric(f[, 4]),
                wx = as.numeric(f[, 17]), vol = as.numeric(f[, 18]), delay_min = as.numeric(f[, 23]))
  stopifnot(all(ops$sysimp_delays == as.numeric(f[, 13]) + as.numeric(f[, 14]) + as.numeric(f[, 15]) + as.numeric(f[, 16])))
  bts_ops <- sum(!dep$cancelled) + sum(!arr_all$cancelled & arr_all$flight_date >= m_start & arr_all$flight_date <= m_end)
  add("faa", "opsnet_total_operations_month", sum(ops$total_ops))
  add("faa", "bts_flown_departures_plus_arrivals_month", bts_ops)
  add("faa", "bts_share_of_opsnet_operations_pct", pct(bts_ops / sum(ops$total_ops)))
  add("faa", "opsnet_system_impact_delays_month", sum(ops$sysimp_delays))
  add("faa", "opsnet_delays_weather", sum(ops$wx))
  add("faa", "opsnet_delays_volume", sum(ops$vol))
  add("faa", "opsnet_days_with_any_delay", sum(ops$sysimp_delays > 0))
  top2 <- ops |> arrange(desc(sysimp_delays)) |> head(2)
  add("faa", "opsnet_delays_on_worst_two_days", sum(top2$sysimp_delays))
  add("faa", "opsnet_worst_two_days", paste(top2$date, collapse = ", "))
}

# ---- 5. Weather ---------------------------------------------------------------
wx_m <- wx |> filter(as.Date(hour_start) >= m_start, as.Date(hour_start) <= m_end)
add("weather", "hours_in_month_with_observations", nrow(wx_m))
add("weather", "hours_expected", as.numeric(m_end - m_start + 1) * 24)
add("weather", "hours_missing_temperature", sum(is.na(wx_m$temp_max_f)))
add("weather", "hours_heat_105", sum(wx_m$heat_105, na.rm = TRUE))
add("weather", "hours_heat_110", sum(wx_m$heat_110, na.rm = TRUE))
add("weather", "hours_heat_115", sum(wx_m$heat_115, na.rm = TRUE))
add("weather", "hours_storm", sum(wx_m$storm, na.rm = TRUE))
add("weather", "hours_thunder", sum(wx_m$thunder, na.rm = TRUE))
add("weather", "max_temp_f", max(wx_m$temp_max_f, na.rm = TRUE))

wj <- flown_l |> mutate(hour_start = floor_date(sched_dep, "hour")) |> left_join(wx, by = "hour_start")
add("weather", "flown_departures_joined_to_weather_pct", pct(mean(!is.na(wj$temp_max_f))))
wx_first <- wj |> mutate(condition = case_when(storm ~ "storm hour", heat_110 ~ "heat >= 110 F", TRUE ~ "other")) |>
  group_by(condition) |> summarise(departures = n(),
    mean_dep_delay = round(mean(pmax(dep_delay, 0), na.rm = TRUE), 1),
    mean_taxi_out = round(mean(taxi_out, na.rm = TRUE), 1), .groups = "drop")
save_table(wx_first, "phase0_weather_first_look")

# Same-hour heat check: heat hours cluster in the afternoon, when delay is already high.
# Compare heat and non-heat departures within the same scheduled clock hour, only in hours
# where 110 F occurred at least once, then weight each hour's gap by its heat departures.
heat_same_hour <- wj |> filter(!storm %in% TRUE) |>
  group_by(sched_hour) |> filter(any(heat_110 %in% TRUE), any(!heat_110 %in% TRUE)) |>
  group_by(sched_hour, heat = heat_110 %in% TRUE) |>
  summarise(departures = n(), mean_dep_delay = mean(pmax(dep_delay, 0), na.rm = TRUE), .groups = "drop") |>
  pivot_wider(names_from = heat, values_from = c(departures, mean_dep_delay)) |>
  transmute(sched_hour, heat_departures = departures_TRUE, other_departures = departures_FALSE,
            heat_mean_delay = round(mean_dep_delay_TRUE, 1), other_mean_delay = round(mean_dep_delay_FALSE, 1),
            gap_min = round(heat_mean_delay - other_mean_delay, 1))
save_table(heat_same_hour, "phase0_heat_same_hour")
add("weather", "heat_gap_unadjusted_min", round(wx_first$mean_dep_delay[wx_first$condition == "heat >= 110 F"] -
                                                wx_first$mean_dep_delay[wx_first$condition == "other"], 1))
add("weather", "heat_gap_same_hour_weighted_min", round(weighted.mean(heat_same_hour$gap_min, heat_same_hour$heat_departures), 1))

# ---- 6. TSA --------------------------------------------------------------------
tsa_file <- file.path(dir_processed, "tsa_phx_hourly_checkpoint.csv")
if (file.exists(tsa_file)) {
  # Phase 0 used the two July 2025 weeks parsed at the time (6 to 19 July)
  tsa <- read_csv(tsa_file, show_col_types = FALSE) |> filter(date >= as.Date("2025-07-06"), date <= as.Date("2025-07-19"))
  daily <- tsa |> group_by(date) |> summarise(throughput = sum(throughput), .groups = "drop")
  hourly <- tsa |> group_by(hour) |> summarise(avg_throughput = round(sum(throughput) / n_distinct(tsa$date)), .groups = "drop")
  add("tsa", "days_parsed", nrow(daily))
  add("tsa", "daily_throughput_min", min(daily$throughput))
  add("tsa", "daily_throughput_max", max(daily$throughput))
  add("tsa", "peak_hour", hourly$hour[which.max(hourly$avg_throughput)])
  add("tsa", "peak_hour_avg_throughput", max(hourly$avg_throughput))
  add("tsa", "checkpoints", paste(sort(unique(tsa$checkpoint)), collapse = "; "))
  add("tsa", "checkpoint_set_same_both_weeks",
      identical(sort(unique(tsa$checkpoint[tsa$date <= min(tsa$date) + 6])), sort(unique(tsa$checkpoint[tsa$date > min(tsa$date) + 6]))))
  save_table(hourly, "phase0_tsa_by_hour")
}
links_file <- file.path(dir_cache, "tsa_all_links.csv")
if (file.exists(links_file)) {
  links <- read_csv(links_file, show_col_types = FALSE)
  cov <- links |> filter(!is.na(start), year(start) %in% 2024:2025) |> distinct(start) |>
    count(year = year(start), name = "weekly_files_found")
  save_table(cov, "phase0_tsa_file_coverage")
  # Weeks (Sunday starts) covering 2024-2025 with no file found in the reading-room search
  all_weeks <- seq(as.Date("2023-12-31"), as.Date("2025-12-28"), by = "week")
  save_table(tibble(week_start = all_weeks[!all_weeks %in% links$start]), "phase0_tsa_weeks_not_found")
  add("tsa", "unparseable_file_names", sum(is.na(links$start)))
}

save_table(bind_rows(summary_rows), "phase0_summary")
