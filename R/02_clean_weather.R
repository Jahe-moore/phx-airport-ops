# 02_clean_weather.R
# Rolls KPHX observations up to one row per local clock hour.
#
# An hour gets the worst conditions reported in it: max temperature, max gust,
# min visibility, and a thunderstorm flag if any report in the hour had one.
# Worst-case is used because a 20-minute storm cell can stop departures for the whole hour.
#
# Definitions (PLAN.md section 6):
#   extreme heat hour: max temperature >= 110 F (105 F and 115 F kept as sensitivity flags)
#   storm hour: thunderstorm reported, OR gust >= 35 knots, OR visibility < 3 miles
#
# Usage: Rscript R/02_clean_weather.R 2024-01 2025-12   (default: the full window)

source("R/00_setup.R")
w <- window_args()
tag <- w$tag

raw <- read_csv(file.path(dir_raw, sprintf("kphx_asos_%s.csv", tag)), na = c("M", ""),
                col_types = cols(.default = col_character()))

num <- function(x) suppressWarnings(as.numeric(if_else(x == "T", "0", x)))   # "T" = trace precipitation

obs <- raw |> transmute(
  valid = as.POSIXct(valid, format = "%Y-%m-%d %H:%M", tz = "UTC"),  # already Phoenix local clock (tz= in request)
  tmpf = num(tmpf), sknt = num(sknt), gust = num(gust), vsby = num(vsby), p01i = num(p01i),
  wxcodes = coalesce(wxcodes, ""), metar = metar)

hourly <- obs |>
  mutate(hour_start = floor_date(valid, "hour")) |>
  group_by(hour_start) |>
  summarise(
    n_obs     = n(),
    temp_max_f = suppressWarnings(max(tmpf, na.rm = TRUE)),
    wind_max_kt = suppressWarnings(max(sknt, na.rm = TRUE)),
    gust_max_kt = suppressWarnings(max(gust, na.rm = TRUE)),   # NA when no gust was reported
    vis_min_mi = suppressWarnings(min(vsby, na.rm = TRUE)),
    precip_in  = suppressWarnings(max(p01i, na.rm = TRUE)),
    thunder    = any(grepl("TS", wxcodes)),
    dust       = any(grepl("DU|DS", wxcodes)),   # dust, blowing dust, duststorm (haze left out: too common to mean much)
    .groups = "drop") |>
  mutate(across(where(is.numeric), ~ if_else(is.infinite(.x), NA_real_, .x)),
         heat_105 = temp_max_f >= 105, heat_110 = temp_max_f >= 110, heat_115 = temp_max_f >= 115,
         storm = thunder | coalesce(gust_max_kt >= 35, FALSE) | coalesce(vis_min_mi < 3, FALSE))

saveRDS(hourly, file.path(dir_processed, sprintf("weather_hourly_%s.rds", tag)))
message("hours: ", nrow(hourly))
