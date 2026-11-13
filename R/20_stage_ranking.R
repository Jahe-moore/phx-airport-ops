# 20_stage_ranking.R
# Act 1 answer: annual minutes lost by stage, converted to dollars, and which stage has the most
# recoverable value.
#
# Stages (non-overlapping, per BTS departure):
#   Inherited from late inbound   gate delay carried in on the aircraft
#   Created at PHX (gate)         the rest of the gate departure delay
#   Excess taxi-out               FAA taxi-out delay vs unimpeded (low case: BTS quiet-hour baseline)
#
# Dollar inputs come from data/reference/cost_inputs.csv (sources and dollar-years listed there).
#   Airline cost: a gate minute is valued at A4A crew + ownership + other (no fuel or maintenance,
#   engines are off), with the full block-minute cost as the high case. A taxi minute is valued
#   at the full A4A block-minute cost.
#   Passenger cost: delay minutes x passengers on the flight x FAA/DOT value of travel time,
#   raised from 2015 to 2025 dollars with CPI-U. Passengers per flight = seats x load factor from
#   FAA Table 3-6 (regional jet for regional carriers, all-aircraft average for the rest).
#
# Recoverable ("addressable") minutes, measured against PHX's own performance:
#   Gate: each carrier-hour's PHX-created delay per departure above the median large carrier in
#         that same hour (high case: above the best large carrier).
#   Taxi: FAA taxi delay above the level seen in the quietest quarter of hours (the queue part).
#   Inherited: created at other airports, so not counted as recoverable at PHX.
# No public source prices the fixes, so "return" here is recoverable value per year, not ROI.

source("R/00_setup.R")
f <- load_flights()
ci <- read_csv("data/reference/cost_inputs.csv", show_col_types = FALSE)
v  <- setNames(ci$value, ci$input)

cpi <- read_csv(file.path(dir_raw, "cpi_u_monthly.csv"), show_col_types = FALSE)
names(cpi) <- c("date", "cpi")
cpi_y <- cpi |> group_by(y = year(date)) |> summarise(months = sum(!is.na(cpi)), cpi = mean(cpi, na.rm = TRUE))
infl <- cpi_y$cpi[cpi_y$y == 2025] / cpi_y$cpi[cpi_y$y == 2015]
record("cpi_2015_to_2025", round(infl, 4), "CPI-U ratio 2025 / 2015 (2025 averages the months published)")
record("cpi_2025_months", cpi_y$months[cpi_y$y == 2025], "Months of 2025 CPI-U published in the source")

rate <- list(
  gate_low  = v[["a4a_block_min_crew"]] + v[["a4a_block_min_ownership"]] + v[["a4a_block_min_other"]],
  gate_high = v[["a4a_block_min_total"]],
  taxi      = v[["a4a_block_min_total"]],
  vtts      = c(low = v[["vtts_air_low"]], base = v[["vtts_air_all_purpose"]], high = v[["vtts_air_high"]]) * infl / 60)
pax <- function(regional, case = "base") {
  main <- switch(case, low = v[["seats_narrowbody_small"]] * v[["load_factor_narrowbody_small"]],
                 base = v[["seats_all_aircraft"]] * v[["load_factor_all_aircraft"]],
                 high = v[["seats_narrowbody_large"]] * v[["load_factor_narrowbody_large"]])
  if_else(regional, v[["seats_regional_jet_61_99"]] * v[["load_factor_regional_jet_61_99"]], main)
}
record("rate_gate_airline", round(rate$gate_low, 2), "Airline cost per gate-delay minute, USD (A4A 2025 crew + ownership + other)")
record("rate_taxi_airline", round(rate$taxi, 2), "Airline cost per taxi minute, USD (A4A 2025 full block minute)")
record("vtts_2025_per_hour", round(rate$vtts[["base"]] * 60, 2), "Passenger value of time, USD per hour in 2025 dollars")
record("pax_per_dep_mainline", round(pax(FALSE), 1), "Passengers per mainline departure (FAA Table 3-6)")
record("pax_per_dep_regional", round(pax(TRUE), 1), "Passengers per regional departure (FAA Table 3-6)")

f <- f |> mutate(taxi_faa = coalesce(aspm_taxi_out_delay, 0),
                 pax_low = pax(regional, "low"), pax_base = pax(regional, "base"), pax_high = pax(regional, "high"))

# ---- Recoverable minutes ------------------------------------------------------------
large <- f |> count(carrier) |> filter(n / n_years >= 5000) |> pull(carrier)
ch <- f |> filter(carrier %in% large) |> group_by(carrier, sched_hour) |>
  summarise(rate = mean(phx_originated, na.rm = TRUE), n = n(), .groups = "drop")
bench <- ch |> group_by(sched_hour) |> summarise(bench_median = median(rate), bench_best = min(rate), .groups = "drop")
f <- f |> left_join(ch |> select(carrier, sched_hour, ch_rate = rate), by = c("carrier", "sched_hour")) |>
  left_join(bench, by = "sched_hour") |>
  mutate(ch_rate = coalesce(ch_rate, phx_originated),
         gate_addr_base = pmax(ch_rate - bench_median, 0), gate_addr_high = pmax(ch_rate - bench_best, 0))
save_table(bench |> mutate(across(where(is.numeric), ~ round(.x, 2))), "act1_gate_benchmark_by_hour")

aspm <- readRDS(file.path(dir_processed, "faa_aspm_hourly.rds"))
quiet <- aspm |> filter(hour %in% 6:22) |> filter(sched_dep <= quantile(sched_dep, 0.25)) |>
  summarise(q = sum(taxi_out_delay_min_total) / sum(dep_for_metric)) |> pull(q)
f <- f |> mutate(taxi_addr = pmax(taxi_faa - quiet, 0))
record("taxi_quiet_level", round(quiet, 2), "FAA taxi-out delay per departure in the quietest quarter of hours, minutes")

# ---- Stage table ---------------------------------------------------------------------
stage_row <- function(stage, mins, mins_low, addr, addr_high, air_rate_low, air_rate_high) {
  tibble(stage,
    minutes_per_year = sum(mins) / n_years,
    minutes_low_per_year = sum(mins_low) / n_years,
    airline_usd_low = sum(mins_low) * air_rate_low / n_years,
    airline_usd_base = sum(mins) * air_rate_low / n_years,
    airline_usd_high = sum(mins) * air_rate_high / n_years,
    passenger_usd_low = sum(mins_low * f$pax_low) * rate$vtts[["low"]] / n_years,
    passenger_usd_base = sum(mins * f$pax_base) * rate$vtts[["base"]] / n_years,
    passenger_usd_high = sum(mins * f$pax_high) * rate$vtts[["high"]] / n_years,
    addressable_min_per_year = sum(addr) / n_years,
    addressable_min_high_per_year = sum(addr_high) / n_years,
    addressable_usd_base = (sum(addr) * air_rate_low + sum(addr * f$pax_base) * rate$vtts[["base"]]) / n_years,
    addressable_usd_high = (sum(addr_high) * air_rate_high + sum(addr_high * f$pax_high) * rate$vtts[["high"]]) / n_years)
}
z <- rep(0, nrow(f))
stages <- bind_rows(
  stage_row("Created at PHX (gate)", f$phx_originated, f$phx_originated, f$gate_addr_base, f$gate_addr_high, rate$gate_low, rate$gate_high),
  stage_row("Excess taxi-out", f$taxi_faa, f$excess_taxi, f$taxi_addr, f$taxi_faa, rate$taxi, rate$taxi),
  stage_row("Inherited from late inbound", f$inherited, f$inherited, z, z, rate$gate_low, rate$gate_high)) |>
  mutate(total_usd_base = airline_usd_base + passenger_usd_base,
         total_usd_low = airline_usd_low + passenger_usd_low,
         total_usd_high = airline_usd_high + passenger_usd_high,
         capture_25_usd = 0.25 * addressable_usd_base, capture_50_usd = 0.50 * addressable_usd_base) |>
  arrange(desc(minutes_per_year))
save_table(stages |> mutate(across(where(is.numeric), ~ round(.x))), "act1_stage_ranking")

for (i in seq_len(nrow(stages))) {
  k <- c("Created at PHX (gate)" = "gate", "Excess taxi-out" = "taxi", "Inherited from late inbound" = "inherited")[[stages$stage[i]]]
  record(paste0("stage_", k, "_min"), round(stages$minutes_per_year[i]), paste(stages$stage[i], "minutes per year"))
  record(paste0("stage_", k, "_usd_base"), round(stages$total_usd_base[i]), paste(stages$stage[i], "total cost per year, base case, USD"))
  record(paste0("stage_", k, "_usd_low"), round(stages$total_usd_low[i]), paste(stages$stage[i], "total cost per year, low case"))
  record(paste0("stage_", k, "_usd_high"), round(stages$total_usd_high[i]), paste(stages$stage[i], "total cost per year, high case"))
  record(paste0("stage_", k, "_airline_usd"), round(stages$airline_usd_base[i]), paste(stages$stage[i], "airline cost per year, base"))
  record(paste0("stage_", k, "_addr_min"), round(stages$addressable_min_per_year[i]), paste(stages$stage[i], "recoverable minutes per year, base"))
  record(paste0("stage_", k, "_addr_usd"), round(stages$addressable_usd_base[i]), paste(stages$stage[i], "recoverable value per year, base, USD"))
  record(paste0("stage_", k, "_addr_usd_high"), round(stages$addressable_usd_high[i]), paste(stages$stage[i], "recoverable value per year, high case"))
}
best <- stages |> slice_max(addressable_usd_base, n = 1)
record("best_stage", best$stage, "Stage with the most recoverable value per year")
record("total_usd_base", round(sum(stages$total_usd_base)), "All three stages, total cost per year, base case")

# ---- Does the ranking hold? ------------------------------------------------------------
# The two recoverable stages are compared under each assumption set. Also shown: a taxi fix that
# only moves the wait from the runway queue back to the gate (departure metering) saves engine-
# running cost (fuel + maintenance) but no passenger time, because the flight still leaves late.
engine_rate <- v[["a4a_block_min_fuel"]] + v[["a4a_block_min_maintenance"]]
val <- function(mins, air_rate, pax_col, vtts) (sum(mins) * air_rate + sum(mins * pax_col) * vtts) / n_years
robust <- tibble(
  case = c("Base: gate vs median carrier; taxi vs FAA quiet-hour level",
           "High: gate vs best carrier; all FAA taxi delay",
           "Alternative taxi measure: BTS excess over carrier quiet-hour median",
           "Taxi fix is metering only (fuel + maintenance saved, no passenger time)"),
  gate_usd = c(val(f$gate_addr_base, rate$gate_low, f$pax_base, rate$vtts[["base"]]),
               val(f$gate_addr_high, rate$gate_high, f$pax_high, rate$vtts[["high"]]),
               val(f$gate_addr_base, rate$gate_low, f$pax_base, rate$vtts[["base"]]),
               val(f$gate_addr_base, rate$gate_low, f$pax_base, rate$vtts[["base"]])),
  taxi_usd = c(val(f$taxi_addr, rate$taxi, f$pax_base, rate$vtts[["base"]]),
               val(f$taxi_faa, rate$taxi, f$pax_high, rate$vtts[["high"]]),
               val(f$excess_taxi, rate$taxi, f$pax_base, rate$vtts[["base"]]),
               sum(f$taxi_addr) * engine_rate / n_years)) |>
  mutate(larger = if_else(gate_usd > taxi_usd, "Created at PHX (gate)", "Excess taxi-out"))
save_table(robust |> mutate(across(where(is.numeric), round)), "act1_recommendation_robustness")
record("robust_cases_gate_wins", sum(robust$larger == "Created at PHX (gate)"), "Robustness cases where gate delay has more recoverable value")
record("robust_cases_total", nrow(robust), "Robustness cases compared")
record("taxi_metering_only_usd", round(robust$taxi_usd[4]), "Taxi recoverable value if the fix is metering only, USD per year")
record("taxi_bts_basis_usd", round(robust$taxi_usd[3]), "Taxi recoverable value on the BTS quiet-hour basis, USD per year")

# Where the recoverable taxi queue sits: by pushback hour and carrier
taxi_by_hour <- f |> group_by(hour = hour(actual_dep)) |> summarise(recoverable_min_per_year = sum(taxi_addr) / n_years, .groups = "drop") |>
  mutate(share_pct = 100 * recoverable_min_per_year / sum(recoverable_min_per_year))
save_table(taxi_by_hour |> mutate(across(where(is.numeric), ~ round(.x, 1))), "act1_taxi_recoverable_by_hour")
bank <- taxi_by_hour |> filter(hour %in% 7:11)
record("taxi_recoverable_7_11_share", round(sum(bank$share_pct), 1), "Share of recoverable taxi minutes with pushback 07:00-11:59, percent")
taxi_by_carrier <- f |> filter(hour(actual_dep) %in% 7:11) |> group_by(carrier) |>
  summarise(departures_per_year = n() / n_years, recoverable_min_per_year = sum(taxi_addr) / n_years, .groups = "drop") |>
  mutate(share_pct = 100 * recoverable_min_per_year / sum(recoverable_min_per_year)) |> arrange(desc(recoverable_min_per_year))
save_table(taxi_by_carrier |> mutate(across(where(is.numeric), ~ round(.x, 1))), "act1_taxi_recoverable_bank_by_carrier")
record("taxi_bank_top_carrier", taxi_by_carrier$carrier[1], "Carrier with most recoverable taxi minutes in the 07-11 bank")
record("taxi_bank_top_carrier_share", round(taxi_by_carrier$share_pct[1], 1), "Its share, percent")
record("taxi_bank_second_carrier", taxi_by_carrier$carrier[2], "Second carrier")
record("taxi_bank_second_carrier_share", round(taxi_by_carrier$share_pct[2], 1), "Its share, percent")

# Who owns the recoverable gate minutes: by carrier
gate_by_carrier <- f |> group_by(carrier) |> summarise(recoverable_min_per_year = sum(gate_addr_base) / n_years,
  phx_originated_min_per_year = sum(phx_originated) / n_years, .groups = "drop") |>
  mutate(share_of_recoverable_pct = 100 * recoverable_min_per_year / sum(recoverable_min_per_year)) |> arrange(desc(recoverable_min_per_year))
save_table(gate_by_carrier |> mutate(across(where(is.numeric), ~ round(.x, 1))), "act1_gate_recoverable_by_carrier")
gate_by_hour <- f |> group_by(sched_hour) |> summarise(recoverable_min_per_year = sum(gate_addr_base) / n_years, .groups = "drop")
save_table(gate_by_hour |> mutate(recoverable_min_per_year = round(recoverable_min_per_year)), "act1_gate_recoverable_by_hour")
top_c <- gate_by_carrier[1, ]
record("gate_recoverable_top_carrier", top_c$carrier, "Carrier holding the most recoverable gate minutes")
record("gate_recoverable_top_carrier_share", round(top_c$share_of_recoverable_pct, 1), "Its share of recoverable gate minutes, percent")

# ---- Figures ---------------------------------------------------------------------------
lab <- function(x) paste0(fmt_n(x / 1e6, 2), "M min  |  ", fmt_usd(0))
p1 <- stages |> mutate(stage = factor(stage, levels = rev(stage))) |>
  ggplot(aes(minutes_per_year / 1e6, stage, fill = stage)) + geom_col(width = 0.65, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.2fM min  |  %s per year", minutes_per_year / 1e6, fmt_usd(total_usd_base))), hjust = -0.05, size = 3.4) +
  scale_fill_manual(values = stage_cols) + scale_x_continuous(expand = expansion(mult = c(0, 0.45))) +
  labs(title = sprintf("Gate delay created at PHX is the largest stage: %.1fM minutes and %s a year",
                       stages$minutes_per_year[stages$stage == "Created at PHX (gate)"] / 1e6,
                       fmt_usd(stages$total_usd_base[stages$stage == "Created at PHX (gate)"])),
       subtitle = "Annual delay minutes by stage, PHX departures, 2024-2025 average. Dollars: airline cost plus passenger time, base case",
       x = "Million minutes per year", y = NULL,
       caption = paste(src_bts, src_faa, "Costs: A4A 2025 block-minute cost; FAA/DOT value of travel time (2025 $). See cost_inputs.csv.")) + theme_phx()
save_fig(p1, "act1_stage_ranking", height = 3.8)

p2 <- stages |> filter(addressable_usd_base > 0) |> mutate(stage = factor(stage, levels = rev(stage))) |>
  ggplot(aes(y = stage)) +
  geom_col(aes(x = addressable_usd_high / 1e6), fill = pal[["light"]], width = 0.6) +
  geom_col(aes(x = addressable_usd_base / 1e6, fill = stage), width = 0.6, show.legend = FALSE) +
  geom_text(aes(x = addressable_usd_base / 1e6, label = fmt_usd(addressable_usd_base)), hjust = 1.1, color = "white", size = 3.6, fontface = "bold") +
  scale_fill_manual(values = stage_cols) +
  labs(title = sprintf("%s holds the most recoverable value: %s a year if matched to PHX's own benchmark",
                       best$stage, fmt_usd(best$addressable_usd_base)),
       subtitle = "Recoverable value per year, base case (dark) and high case (light), USD millions",
       x = "USD millions per year", y = NULL,
       caption = "Gate: carriers brought to the median large carrier in the same hour (high: best carrier). Taxi: queue time above the quiet-hour level (high: all FAA taxi delay).") + theme_phx()
save_fig(p2, "act1_recoverable_value", height = 3.4)
