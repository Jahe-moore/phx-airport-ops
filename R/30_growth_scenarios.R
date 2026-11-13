# 30_growth_scenarios.R
# Act 2: if PHX traffic grows 15%, which measured stage degrades first?
#
# Step 1, fit (2.1). For each stage, delay per departure in an hour is fitted against that hour's
# scheduled departures (FAA ASPM), within the same clock hour across days:
#     y ~ load + load^2 | clock hour + day of week + month   (weighted by departures, SE clustered by date)
# Comparing 8 AM on a busy day with 8 AM on a light day measures the load effect without
# confusing it with the build-up of delay through the day.
#
# Step 2, scenarios (2.2, 2.3). Every hour's load and departures are scaled by +5, +10, +15, +20%.
# The predicted change in delay per departure is added to today's observed value. Inherited delay
# is held at today's per-departure level: it is created at other airports.
# Intervals: 1,000 draws of the coefficients from their clustered covariance.
#
# Step 3 (2.4). The fit is repeated on hot days (any hour at 110 F+) and storm days.
#
# "Degrades first" (docs/method_decisions.md #7): primary = largest rise in annual minutes at +15%.
# Second view: growth level at which a stage's busiest-hour average crosses 15 minutes per departure.
#
# Limit: the scenario assumes the schedule grows in proportion in every hour, with today's runways,
# gates and procedures. Where +15% exceeds the busiest loads ever observed in an hour, it is an
# extrapolation; the share of hours inside the observed range is reported.

source("R/00_setup.R")
suppressPackageStartupMessages(library(fixest))
set.seed(20261110)
f <- load_flights()
aspm <- readRDS(file.path(dir_processed, "faa_aspm_hourly.rds"))
growth <- c(0, 0.05, 0.10, 0.15, 0.20)

day_wx <- f |> group_by(flight_date) |> summarise(hot_day = any(heat_110 %in% TRUE), storm_day = any(storm %in% TRUE), .groups = "drop")

gate_panel <- f |> filter(sched_hour >= 5) |> group_by(sched_hour_start, flight_date, sched_hour, dow, year, month) |>
  summarise(n = n(), load = first(load), gate = mean(phx_originated, na.rm = TRUE), inherited = mean(inherited, na.rm = TRUE), .groups = "drop") |>
  filter(!is.na(load), load > 0) |> mutate(ym = paste(year, month)) |> left_join(day_wx, by = "flight_date")
taxi_panel <- aspm |> filter(hour >= 5, dep_for_metric > 0, sched_dep > 0) |>
  transmute(flight_date = date, sched_hour = hour, dow = lubridate::wday(date, label = TRUE, week_start = 1),
            ym = format(date, "%Y %m"), n = dep_for_metric, load = sched_dep, taxi = avg_taxi_out_delay) |>
  left_join(day_wx, by = "flight_date")

fit <- function(panel, y) feols(as.formula(sprintf("%s ~ load + I(load^2) | sched_hour + dow + ym", y)),
                                data = panel, weights = ~n, cluster = ~flight_date)

# Annual minutes and busiest-hour average under growth g, for one coefficient vector b
project <- function(panel, y, b, g) {
  d <- b[1] * panel$load * g + b[2] * panel$load^2 * ((1 + g)^2 - 1)
  per_dep <- pmax(panel[[y]] + d, 0)
  annual <- sum(per_dep * panel$n * (1 + g)) / n_years
  by_h <- tapply(per_dep * panel$n, panel$sched_hour, sum) / tapply(panel$n, panel$sched_hour, sum)
  c(annual = annual, peak = max(by_h), peak_hour = as.numeric(names(by_h)[which.max(by_h)]))
}
run_stage <- function(panel, y, label, day_type = "All days") {
  m <- fit(panel, y)
  b <- coef(m); V <- vcov(m)
  draws <- MASS::mvrnorm(1000, b, V)
  base <- project(panel, y, b, 0)
  out <- lapply(growth, function(g) {
    pt <- project(panel, y, b, g)
    sims <- apply(draws, 1, function(bb) project(panel, y, bb, g)[["annual"]]) - base[["annual"]]
    tibble(stage = label, day_type, growth_pct = 100 * g, annual_min = pt[["annual"]],
           increase_min = pt[["annual"]] - base[["annual"]], increase_lo = quantile(sims, 0.05), increase_hi = quantile(sims, 0.95),
           peak_hour = pt[["peak_hour"]], peak_per_dep = pt[["peak"]])
  })
  list(model = tibble(stage = label, day_type, b_load = b[1], se_load = sqrt(V[1, 1]), b_load2 = b[2], se_load2 = sqrt(V[2, 2]),
                      hours = nobs(m), marginal_at_mean = b[1] + 2 * b[2] * weighted.mean(panel$load, panel$n)),
       scen = bind_rows(out))
}
# Inherited delay held constant per departure: grows only with departures
inherited_scen <- function(panel, day_type = "All days") {
  base <- sum(panel$inherited * panel$n) / n_years
  by_h <- tapply(panel$inherited * panel$n, panel$sched_hour, sum) / tapply(panel$n, panel$sched_hour, sum)
  tibble(stage = "Inherited from late inbound", day_type, growth_pct = 100 * growth, annual_min = base * (1 + growth),
         increase_min = base * growth, increase_lo = base * growth, increase_hi = base * growth,
         peak_hour = as.numeric(names(by_h)[which.max(by_h)]), peak_per_dep = max(by_h))
}

res_all <- list(run_stage(gate_panel, "gate", "Created at PHX (gate)"), run_stage(taxi_panel, "taxi", "Excess taxi-out"))
scen <- bind_rows(lapply(res_all, `[[`, "scen"), inherited_scen(gate_panel))
models <- bind_rows(lapply(res_all, `[[`, "model"))

# Bad-weather day types
for (dt in c("hot_day", "storm_day")) {
  lab <- c(hot_day = "Hot days (110 F+)", storm_day = "Storm days")[[dt]]
  gp <- gate_panel[gate_panel[[dt]] %in% TRUE, ]; tp <- taxi_panel[taxi_panel[[dt]] %in% TRUE, ]
  r <- list(run_stage(gp, "gate", "Created at PHX (gate)", lab), run_stage(tp, "taxi", "Excess taxi-out", lab))
  scen <- bind_rows(scen, bind_rows(lapply(r, `[[`, "scen")), inherited_scen(gp, lab))
  models <- bind_rows(models, bind_rows(lapply(r, `[[`, "model")))
}
scen <- scen |> group_by(stage, day_type) |>
  mutate(increase_pct = 100 * increase_min / annual_min[growth_pct == 0]) |> ungroup()
save_table(scen |> mutate(across(where(is.numeric), ~ round(.x, 2))), "act2_scenarios")
save_table(models |> mutate(across(where(is.numeric), ~ signif(.x, 4))), "act2_load_models")

# ---- How far +15% reaches beyond what PHX has already handled ----------------------------
rng <- taxi_panel |> group_by(sched_hour) |> mutate(max_seen = max(load), typical = median(load)) |> ungroup()
inside <- rng |> filter(sched_hour %in% 6:22) |> summarise(pct_inside = 100 * mean(load * 1.15 <= max_seen),
  pct_hours_already_15_above_typical = 100 * mean(load >= 1.15 * typical))
save_table(inside |> mutate(across(everything(), ~ round(.x, 1))), "act2_extrapolation_check")
record("act2_pct_hours_inside_range", round(inside$pct_inside, 1), "Share of hours whose +15% load is within the busiest load already seen in that clock hour")
record("act2_pct_hours_15_above_typical", round(inside$pct_hours_already_15_above_typical, 1), "Share of hours already running 15%+ above that hour's typical load")

# ---- Ranking and threshold view ----------------------------------------------------------
at15 <- scen |> filter(growth_pct == 15, day_type == "All days") |> arrange(desc(increase_min))
first_stage <- at15$stage[1]
save_table(at15 |> mutate(across(where(is.numeric), ~ round(.x, 1))), "act2_ranking_at_15")
k <- c("Created at PHX (gate)" = "gate", "Excess taxi-out" = "taxi", "Inherited from late inbound" = "inherited")
for (i in seq_len(nrow(at15))) {
  s <- k[[at15$stage[i]]]
  record(paste0("act2_", s, "_increase_min"), round(at15$increase_min[i]), paste(at15$stage[i], "added minutes per year at +15%"))
  record(paste0("act2_", s, "_increase_lo"), round(at15$increase_lo[i]), "90% interval low")
  record(paste0("act2_", s, "_increase_hi"), round(at15$increase_hi[i]), "90% interval high")
  record(paste0("act2_", s, "_increase_pct"), round(at15$increase_pct[i], 1), paste(at15$stage[i], "percent rise in annual minutes at +15%"))
  # Per-departure change strips out the 15% that comes only from having 15% more flights
  record(paste0("act2_", s, "_per_dep_change_pct"), round(100 * ((1 + at15$increase_pct[i] / 100) / 1.15 - 1), 1), paste(at15$stage[i], "change in minutes per departure at +15%"))
  record(paste0("act2_", s, "_peak_per_dep_now"), round(scen$peak_per_dep[scen$stage == at15$stage[i] & scen$growth_pct == 0 & scen$day_type == "All days"], 1), "Busiest-hour average per departure today")
  record(paste0("act2_", s, "_peak_per_dep_15"), round(at15$peak_per_dep[i], 1), "Busiest-hour average per departure at +15%")
}
record("act2_first_stage", first_stage, "Stage whose annual delay rises most at +15% traffic")
# Percent rise is the fairer comparison when the stages start from different sizes
first_pct <- at15 |> slice_max(increase_pct, n = 1)
record("act2_first_stage_by_pct", first_pct$stage, "Stage with the largest percent rise at +15%")

thr <- scen |> filter(day_type == "All days") |> group_by(stage) |>
  summarise(peak_now = peak_per_dep[growth_pct == 0],
            crosses_15_at = if (first(peak_per_dep[growth_pct == 0]) >= 15) "already over 15 today" else {
              x <- growth_pct[peak_per_dep >= 15]; if (length(x)) paste0("+", min(x), "%") else "not within +20%" }, .groups = "drop")
save_table(thr |> mutate(peak_now = round(peak_now, 1)), "act2_threshold_view")

wx15 <- scen |> filter(growth_pct == 15) |> select(stage, day_type, increase_pct) |> pivot_wider(names_from = day_type, values_from = increase_pct)
save_table(wx15 |> mutate(across(where(is.numeric), ~ round(.x, 1))), "act2_bad_weather_at_15")

# ---- Figure ------------------------------------------------------------------------------
pd <- scen |> filter(day_type == "All days")
p <- pd |> ggplot(aes(growth_pct, increase_min / 1000, color = stage, fill = stage)) +
  geom_ribbon(aes(ymin = increase_lo / 1000, ymax = increase_hi / 1000), alpha = 0.15, color = NA) +
  geom_line(linewidth = 1.2) + geom_point(size = 2) +
  scale_color_manual(values = stage_cols) + scale_fill_manual(values = stage_cols) +
  scale_x_continuous(breaks = 100 * growth, labels = function(x) paste0("+", x, "%")) +
  labs(title = sprintf("At +15%% traffic, %s grows fastest: +%.0f%% more minutes a year",
                       tolower(first_pct$stage), first_pct$increase_pct),
       subtitle = "Added delay minutes per year versus today, thousands, with 90% intervals. Inherited delay grows only with flight count",
       x = "Traffic growth (every hour scaled)", y = "Added thousand minutes per year",
       caption = paste(src_bts, src_faa, sprintf("Fitted within clock hour across days. %.0f%% of hours stay inside loads PHX has already handled at +15%%.", inside$pct_inside))) +
  theme_phx()
save_fig(p, "act2_growth_scenarios")
