# 02_clean_faa.R
# Tidies the two FAA captures saved from the public FAA web reports:
#   OPSNET daily delays (official FAA count of air traffic delays of 15+ minutes, by cause)
#   ASPM hourly airport metrics (taxi-out time, taxi-out delay against FAA's unimpeded time, etc.)
#
# How they were captured: see the "# Source:" line at the top of each file in data/raw.
# The FAA site only serves these reports to a browser session, so they are pulled in Chrome
# and the report table is saved as CSV. They are committed to the repo for that reason.
#
# Definitions worth knowing before using them:
#   - OPSNET counts only delays of 15+ minutes caused by air traffic control actions
#     (weather, volume, equipment, runway, other). It is not the same as BTS departure delay.
#   - ASPM "taxi-out delay" = actual taxi-out minus FAA's unimpeded taxi-out time for that
#     airport, carrier, season and runway configuration, averaged over the hour.
#
# Usage: Rscript R/02_clean_faa.R

source("R/00_setup.R")

opsnet <- read_csv(file.path(dir_raw, "faa_opsnet_delays_phx_2024_2025_daily.csv"), comment = "#", show_col_types = FALSE) |>
  mutate(date = mdy(date))
stopifnot(all(opsnet$sysimp_total == opsnet$class_ac + opsnet$class_at + opsnet$class_ga + opsnet$class_mil))
stopifnot(all(opsnet$sysimp_total == opsnet$cause_wx + opsnet$cause_vol + opsnet$cause_equip + opsnet$cause_rwy + opsnet$cause_other))
saveRDS(opsnet, file.path(dir_processed, "faa_opsnet_daily.rds"))

aspm <- read_csv(file.path(dir_raw, "faa_aspm_airport_phx_2024_2025_hourly.csv"), comment = "#", show_col_types = FALSE) |>
  mutate(date = mdy(date),
         hour_start = as.POSIXct(date, tz = "UTC") + hour * 3600,     # Phoenix local clock, same convention as BTS
         # Totals for the hour, so hours can be summed: average x number of departures measured
         taxi_out_delay_min_total = avg_taxi_out_delay * dep_for_metric,
         taxi_out_min_total       = avg_taxi_out_time * dep_for_metric)
saveRDS(aspm, file.path(dir_processed, "faa_aspm_hourly.rds"))

message(sprintf("OPSNET: %d days, %d delays. ASPM: %d hours, %s departures measured.",
                nrow(opsnet), sum(opsnet$sysimp_total), nrow(aspm), format(sum(aspm$dep_for_metric), big.mark = ",")))
