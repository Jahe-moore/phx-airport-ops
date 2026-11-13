# 01_download_cpi.R
# Downloads the monthly CPI-U index (all items, U.S. city average, not seasonally adjusted,
# BLS series CUUR0000SA0) from FRED, mirror series CPIAUCNS.
#
# Why: FAA/DOT publish the passenger value of travel time in 2015 dollars and say to adjust
# it with CPI-U to the analysis year. The annual averages computed here do that.
#
# Usage: Rscript R/01_download_cpi.R

source("R/00_setup.R")

out <- file.path(dir_raw, "cpi_u_monthly.csv")
status <- download.file("https://fred.stlouisfed.org/graph/fredgraph.csv?id=CPIAUCNS", out, mode = "wb", quiet = TRUE)
if (status != 0) stop("CPI download failed. Stopping; no substitute data is used.")
cpi <- read_csv(out, show_col_types = FALSE)
message("wrote ", out, " (", nrow(cpi), " months, last ", max(cpi[[1]]), ")")
