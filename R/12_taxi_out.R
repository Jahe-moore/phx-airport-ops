# 12_taxi_out.R
# Sub-question 1.3: how long do aircraft queue between pushback and takeoff beyond normal?
#
# Two measures, reported as a range:
#   FAA (primary): ASPM taxi-out delay = actual taxi-out minus FAA's unimpeded taxi time.
#                  Each BTS flight takes the average for its actual pushback hour.
#   BTS (low end): taxi-out minus the carrier's median taxi-out in the quietest quarter of hours,
#                  floored at zero. Lower because quiet hours already contain some queueing.

source("R/00_setup.R")
f <- load_flights()
aspm <- readRDS(file.path(dir_processed, "faa_aspm_hourly.rds"))

tot <- f |> summarise(
  taxi_out_mean = mean(taxi_out, na.rm = TRUE),
  faa_excess_min_per_year = sum(aspm_taxi_out_delay, na.rm = TRUE) / n_years,
  bts_excess_min_per_year = sum(excess_taxi, na.rm = TRUE) / n_years,
  faa_excess_per_dep = mean(aspm_taxi_out_delay, na.rm = TRUE),
  bts_excess_per_dep = mean(excess_taxi, na.rm = TRUE))
# FAA's own total over every departure it measured (all carriers, larger than BTS)
tot$faa_all_flights_excess_min_per_year <- sum(aspm$taxi_out_delay_min_total, na.rm = TRUE) / n_years
save_table(tot |> mutate(across(where(is.numeric), ~ round(.x, 2))), "act1_taxi_totals")
record("taxi_faa_excess_min_per_year", round(tot$faa_excess_min_per_year), "Excess taxi-out minutes per year, FAA unimpeded basis, BTS flights")
record("taxi_bts_excess_min_per_year", round(tot$bts_excess_min_per_year), "Excess taxi-out minutes per year, quiet-hour basis, BTS flights")
record("taxi_faa_excess_per_dep", round(tot$faa_excess_per_dep, 2), "Excess taxi-out per departure, FAA basis, minutes")
record("taxi_out_mean", round(tot$taxi_out_mean, 1), "Mean taxi-out time, minutes")

# By actual pushback hour: FAA hourly figures weighted by departures measured
by_hour <- aspm |> group_by(hour) |> summarise(
  departures_per_day = sum(dep_for_metric) / (365.5 * n_years),
  faa_taxi_out_delay = sum(taxi_out_delay_min_total) / sum(dep_for_metric),
  taxi_out_time = sum(taxi_out_min_total) / sum(dep_for_metric), .groups = "drop") |>
  left_join(f |> group_by(hour = hour(actual_dep)) |> summarise(bts_excess = mean(excess_taxi, na.rm = TRUE), .groups = "drop"), by = "hour")
save_table(by_hour |> mutate(across(where(is.numeric), ~ round(.x, 2))), "act1_taxi_by_hour")

by_carrier <- f |> group_by(carrier) |> summarise(
  departures_per_year = n() / n_years, taxi_out_mean = mean(taxi_out, na.rm = TRUE),
  baseline_taxi = first(baseline_taxi), bts_excess_per_dep = mean(excess_taxi, na.rm = TRUE),
  faa_excess_per_dep = mean(aspm_taxi_out_delay, na.rm = TRUE), .groups = "drop") |> arrange(desc(departures_per_year))
save_table(by_carrier |> mutate(across(where(is.numeric), ~ round(.x, 2))), "act1_taxi_by_carrier")

peak <- by_hour |> filter(hour >= 5) |> slice_max(faa_taxi_out_delay, n = 1)
record("taxi_peak_hour", peak$hour, "Pushback hour with the highest FAA taxi-out delay")
record("taxi_peak_hour_delay", round(peak$faa_taxi_out_delay, 1), "FAA taxi-out delay per departure in that hour, minutes")
record("taxi_peak_hour_deps_per_day", round(peak$departures_per_day, 1), "Departures per day in that hour (FAA)")

p <- by_hour |> filter(hour >= 5) |> ggplot(aes(hour)) +
  geom_col(aes(y = departures_per_day / 10), fill = pal[["light"]], width = 0.8) +
  geom_line(aes(y = faa_taxi_out_delay, color = "FAA: taxi-out beyond unimpeded"), linewidth = 1.1) +
  geom_line(aes(y = bts_excess, color = "BTS: taxi-out beyond carrier quiet-hour median"), linewidth = 1.1, linetype = "22") +
  scale_color_manual(values = c("FAA: taxi-out beyond unimpeded" = pal[["copper"]], "BTS: taxi-out beyond carrier quiet-hour median" = pal[["navy"]])) +
  scale_y_continuous(sec.axis = sec_axis(~ . * 10, name = "Departures per day (grey bars)")) +
  scale_x_continuous(breaks = seq(5, 23, 2)) +
  labs(title = sprintf("Taxi-out queues peak with the %d:00 departure bank at %.1f extra minutes per flight", peak$hour, peak$faa_taxi_out_delay),
       subtitle = "Excess taxi-out per departure by actual pushback hour, minutes, with departures per day",
       x = "Pushback hour (Phoenix local)", y = "Extra taxi-out minutes per departure",
       caption = paste(src_faa, src_bts)) + theme_phx()
save_fig(p, "act1_taxi_by_hour")
