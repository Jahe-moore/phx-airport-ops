# 01_download_bts.R
# Downloads BTS Reporting Carrier On-Time Performance monthly files and keeps only
# flights that touch PHX (departing from or arriving at PHX).
#
# Why arrivals too: sub-question 1.1 links each PHX departure to the same aircraft's
# previous arrival at PHX, using the tail number.
#
# Why the month before is also pulled: a departure on the 1st often uses an aircraft
# that arrived the evening before. Without the prior month those departures would
# look unmatched because of a data boundary, which says nothing about operations.
#
# Usage: Rscript R/01_download_bts.R 2024-01 2025-12   (first and last month; one month also works: 2025-07 2025-07)

source("R/00_setup.R")

args  <- commandArgs(trailingOnly = TRUE)
first <- as.Date(paste0(if (length(args) >= 1) args[1] else window_start, "-01"))
last  <- as.Date(paste0(if (length(args) >= 2) args[2] else window_end, "-01"))

# The month before the window is included so departures on the window's first day can link
starts <- seq(floor_date(first - 1, "month"), last, by = "month")
months_needed <- lapply(starts, function(d) c(year(d), month(d)))

# Columns kept. Names are the prezipped-file names (CamelCase), which differ from the
# web-form names listed in early planning notes. See docs/DATA_SOURCES.md for the mapping.
keep_cols <- c(
  "FlightDate", "Reporting_Airline", "Tail_Number", "Flight_Number_Reporting_Airline",
  "Origin", "Dest", "CRSDepTime", "DepTime", "DepDelay", "DepDelayMinutes",
  "TaxiOut", "WheelsOff", "WheelsOn", "TaxiIn", "CRSArrTime", "ArrTime", "ArrDelay",
  "Cancelled", "CancellationCode", "Diverted", "CRSElapsedTime", "ActualElapsedTime",
  "Distance", "CarrierDelay", "WeatherDelay", "NASDelay", "SecurityDelay",
  "LateAircraftDelay", "FirstDepTime", "TotalAddGTime", "LongestAddGTime"
)

for (ym in months_needed) {
  y <- ym[1]; m <- ym[2]
  out <- file.path(dir_raw, sprintf("bts_phx_%s.csv.gz", month_tag(y, m)))
  if (file.exists(out)) { message("exists, skipping: ", out); next }

  url <- sprintf(
    "https://transtats.bts.gov/PREZIP/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_%d_%d.zip",
    y, m)
  zip <- file.path(dir_cache, basename(url))
  if (!file.exists(zip)) {
    message("downloading ", url)
    status <- download.file(url, zip, mode = "wb", quiet = TRUE)
    if (status != 0) stop("BTS download failed for ", y, "-", m, ". Stopping; no substitute data is used.")
  }

  csv_name <- grep("\\.csv$", unzip(zip, list = TRUE)$Name, value = TRUE)
  if (length(csv_name) != 1) stop("Expected one CSV inside ", zip)
  unzip(zip, files = csv_name, exdir = dir_cache, overwrite = TRUE)
  csv_path <- file.path(dir_cache, csv_name)

  all_flights <- fread(csv_path, select = keep_cols, colClasses = list(character = c("Tail_Number", "CancellationCode")))
  phx <- all_flights[Origin == airport | Dest == airport]
  message(sprintf("%d-%02d: %s national rows, %s touch PHX", y, m,
                  format(nrow(all_flights), big.mark = ","), format(nrow(phx), big.mark = ",")))

  fwrite(phx, out)
  file.remove(csv_path)   # keep only the zip in the cache
}
