# 03_validate.R
# Checks the processed tables before any analysis: coverage by month, duplicates, missing
# fields, and agreement between independent sources. Writes output/tables/validate_*.csv.
# Stops with an error if a check that would invalidate the analysis fails.
#
# Usage: Rscript R/03_validate.R

source("R/00_setup.R")
w <- window_args()

dep  <- readRDS(file.path(dir_processed, sprintf("bts_departures_%s.rds", w$tag))) |> filter(flight_date >= w$first, flight_date <= w$end)
wx   <- readRDS(file.path(dir_processed, sprintf("weather_hourly_%s.rds", w$tag)))
ops  <- readRDS(file.path(dir_processed, "faa_opsnet_daily.rds"))
aspm <- readRDS(file.path(dir_processed, "faa_aspm_hourly.rds"))
tsa  <- read_csv(file.path(dir_processed, "tsa_phx_hourly_checkpoint.csv"), show_col_types = FALSE)

# Coverage by month across all sources
months <- tibble(month = seq(w$first, w$last, by = "month"))
cov <- months |>
  left_join(dep |> count(month = floor_date(flight_date, "month"), name = "bts_departures"), by = "month") |>
  left_join(dep |> filter(!cancelled) |> mutate(month = floor_date(flight_date, "month")) |> summarise(bts_flown = n(), bts_days = n_distinct(flight_date), .by = month), by = "month") |>
  left_join(wx |> filter(!is.na(temp_max_f)) |> count(month = floor_date(as.Date(hour_start), "month"), name = "weather_hours"), by = "month") |>
  left_join(ops |> mutate(month = floor_date(date, "month")) |> summarise(opsnet_days = n(), opsnet_ops = sum(total_ops), .by = month), by = "month") |>
  left_join(aspm |> mutate(month = floor_date(date, "month")) |> summarise(aspm_hours = n(), aspm_deps = sum(dep_for_metric), .by = month), by = "month") |>
  left_join(tsa |> mutate(month = floor_date(date, "month")) |> summarise(tsa_days = n_distinct(date), .by = month), by = "month") |>
  mutate(days_in_month = days_in_month(month), weather_hours_expected = days_in_month * 24,
         bts_share_of_aspm_deps_pct = round(100 * bts_flown / aspm_deps, 1))
save_table(cov, "validate_coverage_by_month")

# Duplicates: one row per carrier, flight number, date
dups <- dep |> count(carrier, flight_num, flight_date, sched_dep) |> filter(n > 1)
save_table(tibble(duplicate_flight_rows = nrow(dups)), "validate_duplicates")

# Missing fields among flown departures
miss <- dep |> filter(!cancelled) |> summarise(across(c(tail, dep_delay, taxi_out, wheels_off), ~ round(100 * mean(is.na(.x)), 2))) |>
  pivot_longer(everything(), names_to = "field", values_to = "pct_missing")
save_table(miss, "validate_missing_fields")

# Hard stops
if (any(cov$bts_days < cov$days_in_month, na.rm = TRUE)) stop("A month has BTS days missing")
if (any(is.na(cov$bts_departures))) stop("A month has no BTS data")
if (nrow(dups) > 0) warning(nrow(dups), " duplicate flight rows")
if (any(cov$opsnet_days < cov$days_in_month, na.rm = TRUE)) stop("OPSNET is missing days")
# BTS share of all PHX operations (FAA count), for limitation 2
arr <- readRDS(file.path(dir_processed, sprintf("bts_arrivals_%s.rds", w$tag))) |> filter(flight_date >= w$first, flight_date <= w$end, !cancelled)
record("bts_share_of_ops_pct", round(100 * (sum(!dep$cancelled) + nrow(arr)) / sum(ops$total_ops), 1), "BTS flown departures plus arrivals as a share of FAA-counted PHX operations")
message("validation passed; see output/tables/validate_*.csv")
