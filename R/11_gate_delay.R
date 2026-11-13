# 11_gate_delay.R
# Sub-question 1.2: how late do flights push back, by hour, carrier and cause?
#
# Cause minutes come from the five BTS cause fields. Two cautions, stated on the chart:
#   - They are filled in only when the flight ARRIVED 15+ minutes late, so on-time arrivals
#     that left PHX a little late contribute no cause minutes.
#   - Airlines report them, and they describe the whole trip's delay, not just the PHX part.

source("R/00_setup.R")
f <- load_flights()

by_hour <- f |> group_by(sched_hour) |> summarise(
  departures_per_day = n() / (365.5 * n_years),
  mean_dep_delay = mean(dep_delay_pos, na.rm = TRUE),
  pct_15_plus = 100 * mean(dep_delay >= 15, na.rm = TRUE),
  mean_phx_originated = mean(phx_originated, na.rm = TRUE), .groups = "drop")
save_table(by_hour |> mutate(across(where(is.numeric), ~ round(.x, 2))), "act1_gate_by_hour")

by_carrier <- f |> group_by(carrier) |> summarise(
  departures_per_year = n() / n_years, mean_dep_delay = mean(dep_delay_pos, na.rm = TRUE),
  pct_15_plus = 100 * mean(dep_delay >= 15, na.rm = TRUE), .groups = "drop") |>
  arrange(desc(departures_per_year))
save_table(by_carrier |> mutate(across(where(is.numeric), ~ round(.x, 2))), "act1_gate_by_carrier")

causes <- f |> filter(arr_delay >= 15) |> summarise(
  Carrier = sum(carrier_delay, na.rm = TRUE), `Late aircraft` = sum(late_aircraft_delay, na.rm = TRUE),
  `NAS (air traffic system)` = sum(nas_delay, na.rm = TRUE), Weather = sum(weather_delay, na.rm = TRUE),
  Security = sum(security_delay, na.rm = TRUE)) |>
  pivot_longer(everything(), names_to = "cause", values_to = "minutes") |>
  mutate(minutes_per_year = minutes / n_years, share_pct = 100 * minutes / sum(minutes)) |>
  arrange(desc(minutes))
save_table(causes |> mutate(across(where(is.numeric), ~ round(.x, 1))), "act1_gate_causes")
record("cause_carrier_share_pct", round(causes$share_pct[causes$cause == "Carrier"], 1), "Carrier-caused share of reported delay minutes (flights 15+ min late)")
record("cause_late_aircraft_share_pct", round(causes$share_pct[causes$cause == "Late aircraft"], 1), "Late-aircraft share of reported delay minutes")
record("cause_nas_share_pct", round(causes$share_pct[causes$cause == "NAS (air traffic system)"], 1), "NAS share of reported delay minutes")
record("cause_weather_share_pct", round(causes$share_pct[causes$cause == "Weather"], 1), "Extreme-weather share of reported delay minutes")

peak <- by_hour |> filter(sched_hour >= 5) |> slice_max(mean_dep_delay, n = 1)
first <- by_hour |> filter(sched_hour >= 5, sched_hour <= 7) |> summarise(m = mean(mean_dep_delay))
record("gate_delay_peak_hour", peak$sched_hour, "Hour with the highest mean departure delay")
record("gate_delay_peak_hour_mean", round(peak$mean_dep_delay, 1), "Mean departure delay in that hour, minutes")
record("gate_delay_morning_mean", round(first$m, 1), "Mean departure delay, 05:00-07:59, minutes")

p1 <- by_hour |> filter(sched_hour >= 5) |>
  ggplot(aes(sched_hour, mean_dep_delay)) + geom_col(fill = pal[["navy"]], width = 0.8) +
  geom_text(aes(label = round(mean_dep_delay)), vjust = -0.4, size = 3, color = pal[["navy"]]) +
  scale_x_continuous(breaks = seq(5, 23, 2)) +
  labs(title = sprintf("Departure delay builds through the day, from about %d minutes before 8 AM to %d minutes at %d:00",
                       round(first$m), round(peak$mean_dep_delay), peak$sched_hour),
       subtitle = "Average gate departure delay per flight by scheduled hour, minutes (early = 0)",
       x = "Scheduled departure hour (Phoenix local)", y = "Minutes per departure", caption = src_bts) + theme_phx()
save_fig(p1, "act1_gate_by_hour")

p2 <- causes |> mutate(cause = reorder(cause, minutes)) |>
  ggplot(aes(minutes_per_year / 1000, cause)) + geom_col(fill = pal[["steel"]], width = 0.7) +
  geom_text(aes(label = paste0(round(share_pct), "%")), hjust = -0.2, size = 3.2) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title = sprintf("Airline-caused and late-aircraft minutes make up %d%% of reported delay on PHX departures",
                       round(sum(causes$share_pct[causes$cause %in% c("Carrier", "Late aircraft")]))),
       subtitle = "Reported delay-cause minutes per year, PHX departures that arrived 15+ minutes late (thousands)",
       x = "Thousand minutes per year", y = NULL,
       caption = paste(src_bts, "Causes are carrier-reported and filled only for arrivals 15+ minutes late.")) + theme_phx()
save_fig(p2, "act1_gate_causes", height = 4.2)
