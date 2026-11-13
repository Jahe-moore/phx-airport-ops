# 13_airfield.R
# Sub-question 1.4: how often is the airfield (or the air traffic system) the constraint?
#
# Source: FAA OPSNET, the official count of air traffic delays of 15+ minutes, by cause.
# These delays are a cause overlay. The minutes sit inside gate and taxi time already (a ground
# stop holds aircraft at the gate), so they are not added to the stage ranking.
# Hourly called departure rates are not public, so utilization is not computed (PLAN.md fallback).

source("R/00_setup.R")
ops <- readRDS(file.path(dir_processed, "faa_opsnet_daily.rds"))

by_month <- ops |> group_by(month = floor_date(date, "month")) |> summarise(
  operations = sum(total_ops), delays = sum(sysimp_total), delay_minutes = sum(total_min),
  Weather = sum(cause_wx), Volume = sum(cause_vol), Runway = sum(cause_rwy),
  Equipment = sum(cause_equip), Other = sum(cause_other),
  days_with_delay = sum(sysimp_total > 0), .groups = "drop") |>
  mutate(delays_per_1000_ops = 1000 * delays / operations)
save_table(by_month |> mutate(delays_per_1000_ops = round(delays_per_1000_ops, 2)), "act1_airfield_by_month")

tot <- ops |> summarise(operations_per_year = sum(total_ops) / n_years, delays_per_year = sum(sysimp_total) / n_years,
  delay_minutes_per_year = sum(total_min) / n_years, days_with_delay_pct = 100 * mean(sysimp_total > 0),
  weather_share_pct = 100 * sum(cause_wx) / sum(sysimp_total), volume_share_pct = 100 * sum(cause_vol) / sum(sysimp_total),
  runway_share_pct = 100 * sum(cause_rwy) / sum(sysimp_total), other_share_pct = 100 * sum(cause_other) / sum(sysimp_total),
  delays_per_1000_ops = 1000 * sum(sysimp_total) / sum(total_ops))
top10 <- ops |> arrange(desc(sysimp_total)) |> head(10)
tot$top10_days_share_pct <- 100 * sum(top10$sysimp_total) / sum(ops$sysimp_total)
save_table(tot |> mutate(across(where(is.numeric), ~ round(.x, 1))), "act1_airfield_totals")
save_table(top10 |> select(date, total_ops, sysimp_total, cause_wx, cause_vol, cause_rwy, cause_other, total_min), "act1_airfield_worst_days")

record("opsnet_delays_per_year", round(tot$delays_per_year), "FAA-recorded air traffic delays at PHX per year")
record("opsnet_delay_minutes_per_year", round(tot$delay_minutes_per_year), "FAA-recorded delay minutes per year")
record("opsnet_days_with_delay_pct", round(tot$days_with_delay_pct, 1), "Share of days with any FAA-recorded delay")
record("opsnet_volume_share_pct", round(tot$volume_share_pct, 1), "Volume share of FAA-recorded delays")
record("opsnet_weather_share_pct", round(tot$weather_share_pct, 1), "Weather share of FAA-recorded delays")
record("opsnet_delays_per_1000_ops", round(tot$delays_per_1000_ops, 2), "FAA-recorded delays per 1,000 operations")
record("opsnet_top10_days_share_pct", round(tot$top10_days_share_pct, 1), "Share of FAA delays on the worst 10 days")
record("opsnet_operations_per_year", round(tot$operations_per_year), "PHX airport operations per year (FAA)")

p <- by_month |> select(month, Weather, Volume, Runway, Equipment, Other) |> pivot_longer(-month) |>
  mutate(name = factor(name, levels = c("Other", "Equipment", "Runway", "Weather", "Volume"))) |>
  ggplot(aes(month, value, fill = name)) + geom_col(width = 25) +
  scale_fill_manual(values = c(Volume = pal[["navy"]], Weather = pal[["steel"]], Runway = pal[["copper"]], Equipment = pal[["red"]], Other = pal[["grey"]])) +
  scale_x_date(date_breaks = "3 months", date_labels = "%b %Y") +
  labs(title = sprintf("FAA delays at PHX come in bursts: %.0f%% fall on the worst 10 of 731 days", tot$top10_days_share_pct),
       subtitle = sprintf("FAA-recorded air traffic delays (15+ minutes) by month and cause. Volume %.0f%%, weather %.0f%%, runway %.0f%%",
                          tot$volume_share_pct, tot$weather_share_pct, tot$runway_share_pct),
       x = NULL, y = "Delays per month", caption = paste(src_ops, "OPSNET delays overlap gate and taxi delay; they are not added to the stage totals.")) +
  theme_phx()
save_fig(p, "act1_airfield_by_month")
