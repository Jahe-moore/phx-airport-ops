# 00_setup.R
# Shared settings for every script. Source this first: source("R/00_setup.R")
#
# Run every script from the project root (the folder that holds PLAN.md).

suppressWarnings(suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(lubridate)
  library(data.table)
  library(ggplot2)
}))

# ---- Paths -------------------------------------------------------------------
stopifnot(file.exists("PLAN.md"))  # fails loudly if run from the wrong folder

dir_raw       <- "data/raw"
dir_processed <- "data/processed"
dir_figures   <- "output/figures"
dir_tables    <- "output/tables"

# Large source files (national BTS zips at ~30 MB each, weekly TSA PDFs at ~5 MB each)
# are cached OUTSIDE the project so they never sync to OneDrive or land in git.
# Set PHX_CACHE_DIR to choose where. Without it, a temp folder is used and the
# files are downloaded again next session.
options(timeout = 900)   # large national files; the default 60 s is too short
dir_cache <- Sys.getenv("PHX_CACHE_DIR", unset = file.path(tempdir(), "phx_cache"))
dir.create(dir_cache, recursive = TRUE, showWarnings = FALSE)

# ---- Analysis parameters -----------------------------------------------------
airport   <- "PHX"
local_tz  <- "America/Phoenix"   # Arizona stays on UTC-7 all year (no daylight saving)

# Phase 0 test month. July is the hardest month at PHX: peak heat plus monsoon storms.
p0_year  <- 2025
p0_month <- 7

# Full analysis window (PLAN.md section 4): two calendar years
window_start <- "2024-01"
window_end   <- "2025-12"

# ---- Helpers -----------------------------------------------------------------
# BTS stores clock times as hhmm numbers (5 = 00:05, 2400 = midnight at the END of the day).
# Returns minutes after midnight. 2400 becomes 1440 so it sorts after 2359.
hhmm_to_min <- function(x) {
  x <- as.integer(x)
  (x %/% 100) * 60 + (x %% 100)
}

month_tag <- function(y, m) sprintf("%d_%02d", y, m)

# Reads "YYYY-MM YYYY-MM" from the command line (default: the full analysis window)
# and returns the first and last month plus a file tag like "2024_01_to_2025_12".
window_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  first <- as.Date(paste0(if (length(args) >= 1) args[1] else window_start, "-01"))
  last  <- as.Date(paste0(if (length(args) >= 2) args[2] else window_end, "-01"))
  list(first = first, last = last, end = ceiling_date(last, "month") - 1,
       tag = sprintf("%s_to_%s", format(first, "%Y_%m"), format(last, "%Y_%m")))
}

save_table <- function(df, name) {
  path <- file.path(dir_tables, paste0(name, ".csv"))
  readr::write_csv(df, path)
  message("wrote ", path)
  invisible(path)
}

# ---- Shared analysis helpers ---------------------------------------------------
n_years <- 2   # the window is two full calendar years; "per year" figures divide by this

# Colors: Jake's portfolio palette (navy, steel, copper) plus neutrals
pal <- c(navy = "#1B2A4A", steel = "#5B7FA6", copper = "#B08D57", grey = "#9AA3AE", light = "#D9DEE5", red = "#A4473B")
stage_cols <- c("Inherited from late inbound" = "#9AA3AE", "Created at PHX (gate)" = "#1B2A4A", "Excess taxi-out" = "#B08D57")

theme_phx <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(plot.title = element_text(face = "bold", color = pal[["navy"]], size = base_size + 2),
          plot.subtitle = element_text(color = "#4A5568"),
          plot.caption = element_text(color = "#6B7280", size = base_size - 3, hjust = 0),
          plot.title.position = "plot", plot.caption.position = "plot",
          panel.grid.minor = element_blank(), legend.position = "top", legend.title = element_blank())
}

src_bts  <- "Source: BTS Reporting Carrier On-Time Performance, 2024-2025."
src_faa  <- "Source: FAA ASPM Airport Analysis, 2024-2025."
src_ops  <- "Source: FAA OPSNET, 2024-2025."
src_noaa <- "Weather: KPHX ASOS via Iowa Environmental Mesonet."
src_tsa  <- "Source: TSA checkpoint throughput (FOIA reading room), 2024-2025."

save_fig <- function(p, name, width = 9, height = 5.2) {
  # Wrap long titles and source lines so nothing is cut off at the chart edge
  wrap <- function(x, n) if (is.null(x)) x else paste(strwrap(x, n), collapse = intToUtf8(10))
  p$labels$title <- wrap(p$labels$title, round(width * 11))
  p$labels$subtitle <- wrap(p$labels$subtitle, round(width * 14))
  p$labels$caption <- wrap(p$labels$caption, round(width * 18))
  path <- file.path(dir_figures, paste0(name, ".png"))
  ggsave(path, p, width = width, height = height, dpi = 200, bg = "white")
  message("wrote ", path)
  invisible(path)
}

load_flights <- function(flown_only = TRUE) {
  f <- readRDS(file.path(dir_processed, "flights.rds"))
  if (flown_only) f <- f[!f$cancelled, ]
  f
}

fmt_n   <- function(x, d = 0) format(round(x, d), big.mark = ",", nsmall = d, scientific = FALSE)
fmt_usd <- function(x) ifelse(abs(x) >= 1e6, paste0("$", format(round(x / 1e6, 1), nsmall = 1), "M"), paste0("$", fmt_n(x)))

# Every headline number the report, deck and page use is appended here by the script that computes it.
# key, value, label. Downstream documents read this file; nothing is typed by hand.
record <- function(key, value, label = "") {
  path <- file.path(dir_tables, "headline_numbers.csv")
  old <- if (file.exists(path)) readr::read_csv(path, show_col_types = FALSE, col_types = "ccc") else tibble(key = character(), value = character(), label = character())
  new <- bind_rows(filter(old, key != !!key), tibble(key = key, value = as.character(value), label = label))
  readr::write_csv(arrange(new, key), path)
  invisible(value)
}
