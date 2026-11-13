# 01_download_weather.R
# Downloads every KPHX ASOS observation (routine hourly METARs plus special reports)
# from the Iowa Environmental Mesonet archive, with timestamps already in Phoenix time.
#
# IEM republishes the same NWS/FAA ASOS observations that NOAA NCEI archives. It is used
# because it returns one clean CSV per request with no login or token.
#
# Usage: Rscript R/01_download_weather.R 2024-01 2025-12   (also pulls the last day before the window)

source("R/00_setup.R")

args  <- commandArgs(trailingOnly = TRUE)
first <- as.Date(paste0(if (length(args) >= 1) args[1] else window_start, "-01"))
last  <- as.Date(paste0(if (length(args) >= 2) args[2] else window_end, "-01"))

start <- first - 1                              # prior day, for overnight joins
end   <- ceiling_date(last, "month")            # exclusive

out <- file.path(dir_raw, sprintf("kphx_asos_%s_to_%s.csv", format(first, "%Y_%m"), format(last, "%Y_%m")))
if (file.exists(out)) { message("exists, skipping: ", out); quit(save = "no") }

url <- paste0(
  "https://mesonet.agron.iastate.edu/cgi-bin/request/asos.py?station=PHX&data=all",
  "&year1=", year(start), "&month1=", month(start), "&day1=", day(start),
  "&year2=", year(end),   "&month2=", month(end),   "&day2=", day(end),
  "&tz=America%2FPhoenix&format=onlycomma&latlon=no&elev=no&missing=M&trace=T&direct=no",
  "&report_type=3&report_type=4")   # 3 = routine hourly, 4 = special reports

status <- download.file(url, out, mode = "wb", quiet = TRUE)
if (status != 0) stop("IEM download failed. Stopping; no substitute data is used.")
n <- length(readLines(out)) - 1
message("wrote ", out, " (", n, " observations)")
if (n < 24 * as.numeric(end - start) * 0.9) stop("Too few observations (", n, "). Check the request before using this file.")
