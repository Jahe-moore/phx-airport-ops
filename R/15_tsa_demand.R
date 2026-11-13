# 15_tsa_demand.R
# Sub-question 1.6 (and 2.5): what does passenger demand look like across the day, and how fast
# is PHX traffic growing?
#
# TSA counts are screened passengers plus Known Crewmember entries. They describe demand only.
# Nothing here says anything about how long anyone waited (CLAUDE.md hard rule 2).
#
# Growth is compared on matching weeks only (a week missing in either year is dropped from both),
# so a missing TSA file cannot fake growth or decline.

source("R/00_setup.R")
tsa <- read_csv(file.path(dir_processed, "tsa_phx_hourly_checkpoint.csv"), show_col_types = FALSE) |>
  filter(date >= as.Date("2024-01-01"), date <= as.Date("2025-12-31"))
ops <- readRDS(file.path(dir_processed, "faa_opsnet_daily.rds"))
f <- load_flights(flown_only = FALSE)

daily <- tsa |> group_by(date) |> summarise(throughput = sum(throughput), .groups = "drop")
days_present <- nrow(daily)
by_hour <- tsa |> group_by(hour) |> summarise(avg_passengers = sum(throughput) / days_present, .groups = "drop") |>
  left_join(f |> filter(!cancelled) |> count(hour = sched_hour, name = "n") |> mutate(departures_per_day = n / (365.5 * n_years)) |> select(-n), by = "hour") |>
  mutate(passenger_share_pct = 100 * avg_passengers / sum(avg_passengers),
         departure_share_pct = 100 * departures_per_day / sum(departures_per_day, na.rm = TRUE))
save_table(by_hour |> mutate(across(where(is.numeric), ~ round(.x, 1))), "act1_tsa_by_hour")

# Year-over-year growth on matching ISO weeks
wk <- daily |> mutate(yr = isoyear(date), wk = isoweek(date)) |> group_by(yr, wk) |>
  summarise(days = n(), throughput = sum(throughput), .groups = "drop") |> filter(days == 7)
both <- wk |> filter(yr %in% c(2024, 2025)) |> group_by(wk) |> filter(n_distinct(yr) == 2) |> ungroup()
g_tsa <- both |> group_by(yr) |> summarise(t = sum(throughput)) |> summarise(g = t[yr == 2025] / t[yr == 2024] - 1) |> pull(g)
g_ops <- ops |> group_by(yr = year(date)) |> summarise(o = sum(total_ops)) |> summarise(g = o[yr == 2025] / o[yr == 2024] - 1) |> pull(g)
g_bts <- f |> group_by(year) |> summarise(n = n()) |> summarise(g = n[year == 2025] / n[year == 2024] - 1) |> pull(g)
years_to <- function(g) if (g > 0) log(1.15) / log(1 + g) else NA_real_
growth <- tibble(measure = c("TSA passengers (matching weeks)", "FAA airport operations (OPSNET)", "BTS scheduled departures"),
                 growth_2025_vs_2024_pct = 100 * c(g_tsa, g_ops, g_bts),
                 years_to_plus_15_pct = sapply(c(g_tsa, g_ops, g_bts), years_to),
                 matching_weeks = c(n_distinct(both$wk), NA, NA))
save_table(growth |> mutate(across(where(is.numeric), ~ round(.x, 2))), "act2_growth_rates")

record("tsa_days_covered", days_present, "Days of TSA data in the window")
record("tsa_avg_daily", round(mean(daily$throughput)), "Average daily PHX checkpoint throughput")
record("tsa_peak_hour", by_hour$hour[which.max(by_hour$avg_passengers)], "Peak checkpoint hour")
record("tsa_peak_hour_avg", round(max(by_hour$avg_passengers)), "Average passengers in the peak checkpoint hour")
record("growth_tsa_pct", round(100 * g_tsa, 1), "TSA throughput growth 2025 vs 2024, matching weeks")
record("growth_ops_pct", round(100 * g_ops, 1), "FAA operations growth 2025 vs 2024")
record("growth_bts_pct", round(100 * g_bts, 1), "BTS scheduled departures growth 2025 vs 2024")
record("years_to_15_ops", round(years_to(g_ops), 1), "Years to +15% at the 2024-2025 operations growth rate")
record("years_to_15_tsa", round(years_to(g_tsa), 1), "Years to +15% at the 2024-2025 passenger growth rate")

peak_dep <- by_hour$hour[which.max(by_hour$departures_per_day)]
pk_tsa <- by_hour$hour[which.max(by_hour$avg_passengers)]
record("departure_peak_hour", peak_dep, "Scheduled hour with the most departures")
p <- by_hour |> filter(hour >= 3) |> select(hour, `Passengers screened` = passenger_share_pct, `Scheduled departures` = departure_share_pct) |>
  pivot_longer(-hour) |>
  ggplot(aes(hour, value, color = name)) + geom_line(linewidth = 1.2) + geom_point(size = 1.6) +
  scale_color_manual(values = c(`Passengers screened` = pal[["copper"]], `Scheduled departures` = pal[["navy"]])) +
  scale_x_continuous(breaks = seq(3, 23, 2)) +
  labs(title = sprintf("Checkpoint demand peaks at %d:00, %d %s ahead of the %d:00 departure peak",
                       pk_tsa, peak_dep - pk_tsa, if (peak_dep - pk_tsa == 1) "hour" else "hours", peak_dep),
       subtitle = "Share of the day's passengers screened and of the day's departures, by hour (percent)",
       x = "Hour (Phoenix local)", y = "Percent of daily total",
       caption = paste(src_tsa, src_bts, "TSA counts are passengers only; no wait times are implied.")) + theme_phx()
save_fig(p, "act1_tsa_vs_departures")
