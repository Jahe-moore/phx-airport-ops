# 10_inherited_delay.R
# Sub-question 1.1: how much PHX departure delay arrives on a late inbound aircraft, and how
# much is created at PHX?
#
# Method: each departure is linked to the same aircraft's previous arrival at PHX (tail number).
# Inherited = min(inbound lateness, departure delay), floored at zero. The rest of the departure
# delay is PHX-originated. Early departures count as zero delay.
#
# Sensitivity: airlines pad turns. If an inbound is 20 minutes late into a turn scheduled with
# 30 minutes of slack, little of that lateness should carry over. The slack version subtracts each
# turn's scheduled time above the carrier's 10th-percentile turn before computing inherited delay.

source("R/00_setup.R")
f <- load_flights()

# ---- Annual totals ------------------------------------------------------------
tot <- f |> summarise(
  departures_per_year = n() / n_years,
  linked_pct = 100 * mean(matched[!is.na(tail)]),
  dep_delay_min_per_year = sum(dep_delay_pos, na.rm = TRUE) / n_years,
  inherited_min_per_year = sum(inherited, na.rm = TRUE) / n_years,
  phx_originated_min_per_year = sum(phx_originated, na.rm = TRUE) / n_years) |>
  mutate(inherited_share_pct = 100 * inherited_min_per_year / dep_delay_min_per_year)

# Slack-adjusted sensitivity
min_turn <- f |> filter(matched, sched_turn_min > 0) |> group_by(carrier) |>
  summarise(p10_turn = quantile(sched_turn_min, 0.10), .groups = "drop")
f_s <- f |> left_join(min_turn, by = "carrier") |>
  mutate(slack = pmax(coalesce(sched_turn_min - p10_turn, 0), 0),
         inherited_slack = if_else(matched & !is.na(in_arr_delay) & !is.na(dep_delay),
                                   pmax(pmin(in_arr_delay - slack, dep_delay), 0), 0))
tot$inherited_slack_min_per_year <- sum(f_s$inherited_slack) / n_years
tot$inherited_slack_share_pct <- 100 * tot$inherited_slack_min_per_year / tot$dep_delay_min_per_year
save_table(tot |> mutate(across(where(is.numeric), ~ round(.x, 1))), "act1_inherited_totals")
save_table(min_turn, "act1_turn_p10_by_carrier")

record("dep_delay_min_per_year", round(tot$dep_delay_min_per_year), "Departure delay minutes per year (BTS flights, early = 0)")
record("inherited_min_per_year", round(tot$inherited_min_per_year), "Inherited delay minutes per year")
record("phx_originated_min_per_year", round(tot$phx_originated_min_per_year), "PHX-originated gate delay minutes per year")
record("inherited_share_pct", round(tot$inherited_share_pct, 1), "Share of departure delay inherited from late inbound aircraft")
record("inherited_slack_share_pct", round(tot$inherited_slack_share_pct, 1), "Inherited share after removing turn slack (sensitivity)")
record("link_rate_pct", round(tot$linked_pct, 1), "Flown departures linked to their inbound aircraft")
record("departures_per_year", round(tot$departures_per_year), "BTS flown PHX departures per year")

# ---- By hour ---------------------------------------------------------------------
by_hour <- f |> filter(sched_hour >= 5) |> group_by(sched_hour) |> summarise(
  departures_per_day = n() / (365.5 * n_years),
  inherited = mean(inherited, na.rm = TRUE), phx_originated = mean(phx_originated, na.rm = TRUE), .groups = "drop")
save_table(by_hour |> mutate(across(where(is.numeric), ~ round(.x, 2))), "act1_inherited_by_hour")

# ---- By carrier --------------------------------------------------------------------
by_carrier <- f |> group_by(carrier) |> summarise(
  departures_per_year = n() / n_years,
  inherited_per_dep = mean(inherited, na.rm = TRUE), phx_originated_per_dep = mean(phx_originated, na.rm = TRUE),
  phx_originated_min_per_year = sum(phx_originated, na.rm = TRUE) / n_years, .groups = "drop") |>
  arrange(desc(phx_originated_min_per_year))
save_table(by_carrier |> mutate(across(where(is.numeric), ~ round(.x, 2))), "act1_inherited_by_carrier")

# ---- Figure ----------------------------------------------------------------------------
share_phx <- round(100 - tot$inherited_share_pct)
p <- by_hour |> pivot_longer(c(inherited, phx_originated)) |>
  mutate(name = factor(if_else(name == "inherited", "Inherited from late inbound", "Created at PHX (gate)"),
                       levels = c("Inherited from late inbound", "Created at PHX (gate)"))) |>
  ggplot(aes(sched_hour, value, fill = name)) + geom_col(width = 0.8) +
  scale_fill_manual(values = stage_cols) +
  scale_x_continuous(breaks = seq(5, 23, 2)) +
  labs(title = sprintf("%d%% of PHX departure delay is created at PHX; the rest arrives on late inbound aircraft", share_phx),
       subtitle = "Average gate departure delay per flight by scheduled hour, minutes (early departures count as zero)",
       x = "Scheduled departure hour (Phoenix local)", y = "Minutes per departure",
       caption = paste(src_bts, "Inbound linked by tail number. Hour 5 to 23 shown.")) +
  theme_phx()
save_fig(p, "act1_inherited_by_hour")
