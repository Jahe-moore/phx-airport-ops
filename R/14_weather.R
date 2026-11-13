# 14_weather.R
# Sub-question 1.5: how much does weather add to each stage?
#
# Model (one per stage): minutes per departure ~ heat flag + storm flag, with fixed effects for
# scheduled hour, day of week, month-of-year-by-year, and carrier. Standard errors are clustered
# by date, because flights on the same day share the same weather and the same bad-day knock-on.
#
# Why the fixed effects: heat hours fall in the afternoon, when delay is already high. Comparing
# a 3 PM flight on a 112 F day with a 3 PM flight on a 98 F day, same month and carrier, isolates
# the heat effect from the time-of-day build-up.
#
# Sensitivity: heat thresholds of 105 F and 115 F.

source("R/00_setup.R")
suppressPackageStartupMessages(library(fixest))
f <- load_flights() |> filter(!is.na(temp_max_f)) |>
  mutate(ym = paste(year, month), storm = coalesce(storm, FALSE),
         taxi_faa = aspm_taxi_out_delay)

outcomes <- c(phx_originated = "Created at PHX (gate)", inherited = "Inherited from late inbound",
              taxi_faa = "Excess taxi-out (FAA)")
fit_one <- function(y, heat_var) {
  m <- feols(as.formula(sprintf("%s ~ %s + storm | sched_hour + dow + ym + carrier", y, heat_var)),
             data = f, cluster = ~flight_date)
  ct <- coeftable(m)
  tibble(outcome = y, heat_def = heat_var, term = rownames(ct), estimate = ct[, 1], se = ct[, 2],
         lo95 = ct[, 1] - 1.96 * ct[, 2], hi95 = ct[, 1] + 1.96 * ct[, 2], n = nobs(m))
}
res <- bind_rows(lapply(names(outcomes), function(y) bind_rows(lapply(c("heat_105", "heat_110", "heat_115"), function(h) fit_one(y, h))))) |>
  mutate(term = if_else(term == "stormTRUE", "storm", if_else(grepl("heat", term), "heat", term)))
save_table(res |> mutate(across(c(estimate, se, lo95, hi95), ~ round(.x, 2))), "act1_weather_models")

# Annual minutes attributable to heat (110 F) and storms, per stage: coefficient x flights exposed
exposure <- f |> summarise(heat_flights = sum(heat_110), storm_flights = sum(storm))
main <- res |> filter(heat_def == "heat_110") |>
  mutate(flights_per_year = if_else(term == "heat", exposure$heat_flights, exposure$storm_flights) / n_years,
         minutes_per_year = estimate * flights_per_year, stage = outcomes[outcome])
save_table(main |> mutate(across(where(is.numeric), ~ round(.x, 2))), "act1_weather_attributable")

g <- function(o, t) main |> filter(outcome == o, term == t)
record("heat_phx_orig_effect", round(g("phx_originated", "heat")$estimate, 1), "Added PHX-originated gate delay per departure in 110 F+ hours, minutes (controlled)")
record("heat_phx_orig_lo", round(g("phx_originated", "heat")$lo95, 1), "95% CI low")
record("heat_phx_orig_hi", round(g("phx_originated", "heat")$hi95, 1), "95% CI high")
record("heat_taxi_effect", round(g("taxi_faa", "heat")$estimate, 1), "Added FAA excess taxi per departure in 110 F+ hours, minutes")
record("storm_phx_orig_effect", round(g("phx_originated", "storm")$estimate, 1), "Added PHX-originated gate delay per departure in storm hours")
record("storm_taxi_effect", round(g("taxi_faa", "storm")$estimate, 1), "Added FAA excess taxi per departure in storm hours")
record("heat_flights_per_year", round(exposure$heat_flights / n_years), "Departures per year scheduled in 110 F+ hours")
record("storm_flights_per_year", round(exposure$storm_flights / n_years), "Departures per year scheduled in storm hours")
record("weather_minutes_per_year", round(sum(main$minutes_per_year)), "Gate and taxi minutes per year attributable to heat and storms")

p <- res |> filter(heat_def == "heat_110") |>
  mutate(stage = factor(outcomes[outcome], levels = rev(outcomes)), term = if_else(term == "heat", "Heat hour (110 F+)", "Storm hour")) |>
  ggplot(aes(estimate, stage, color = term)) +
  geom_vline(xintercept = 0, color = pal[["grey"]]) +
  geom_pointrange(aes(xmin = lo95, xmax = hi95), position = position_dodge(width = 0.5), size = 0.5) +
  scale_color_manual(values = c("Heat hour (110 F+)" = pal[["copper"]], "Storm hour" = pal[["navy"]])) +
  labs(title = sprintf("Storm hours add %.0f minutes of PHX-created gate delay per flight; 110 F heat adds %.0f",
                       g("phx_originated", "storm")$estimate, g("phx_originated", "heat")$estimate),
       subtitle = "Added minutes per departure versus a normal hour, same clock hour, weekday, month and carrier. Bars: 95% interval",
       x = "Added minutes per departure", y = NULL,
       caption = paste(src_bts, src_faa, src_noaa, "Storm: thunderstorm, gust 35+ kt or visibility under 3 mi.")) + theme_phx()
save_fig(p, "act1_weather_effects", height = 4.2)
