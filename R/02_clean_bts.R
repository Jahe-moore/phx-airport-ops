# 02_clean_bts.R
# Turns the PHX-filtered BTS files into two tidy tables with real timestamps:
#   departures: flights leaving PHX
#   arrivals:   flights landing at PHX (used to find each departure's inbound aircraft)
#
# Every timestamp here is PHX local clock time (America/Phoenix, UTC-7 all year).
# Departure times are in the origin's local time and arrival times in the destination's,
# so PHX-side times are always PHX local. Times at the other airport are not used.
#
# Why actual times are built as "scheduled + delay" instead of parsing DepTime/ArrTime:
# the actual hhmm fields do not say which day they fall on, so a flight scheduled at 23:50
# that leaves at 00:20 looks 23.5 hours early. Scheduled time plus the signed delay
# in minutes has no such problem.
#
# Usage: Rscript R/02_clean_bts.R 2024-01 2025-12   (default: the full window)

source("R/00_setup.R")
w <- window_args()
stopifnot(requireNamespace("R.utils", quietly = TRUE))   # fread needs R.utils to read .csv.gz

# The month before the window is read too, so first-day departures can find their inbound
months <- seq(floor_date(w$first - 1, "month"), w$last, by = "month")
files <- file.path(dir_raw, sprintf("bts_phx_%s.csv.gz", format(months, "%Y_%m")))
missing <- files[!file.exists(files)]
if (length(missing)) stop("Missing BTS files: ", paste(basename(missing), collapse = ", "))
bts <- rbindlist(lapply(files, fread, colClasses = list(character = c("Tail_Number", "CancellationCode")))) |> as_tibble()

# Local clock stored in a POSIXct labelled UTC so no time-zone conversion ever shifts it.
at_clock <- function(date, hhmm) as.POSIXct(as.Date(date), tz = "UTC") + hhmm_to_min(hhmm) * 60

bts <- bts |>
  mutate(
    FlightDate  = as.Date(FlightDate),
    Tail_Number = na_if(trimws(Tail_Number), ""),
    cancelled   = Cancelled == 1,
    diverted    = Diverted == 1,
    sched_dep   = at_clock(FlightDate, CRSDepTime),
    # Scheduled arrival rolls to the next day when its clock time is earlier than departure.
    sched_arr   = at_clock(FlightDate + if_else(CRSArrTime < CRSDepTime, 1L, 0L), CRSArrTime),
    actual_dep  = sched_dep + DepDelay * 60,
    actual_arr  = sched_arr + ArrDelay * 60,
    wheels_off  = actual_dep + TaxiOut * 60
  )

departures <- bts |> filter(Origin == airport) |>
  transmute(flight_date = FlightDate, carrier = Reporting_Airline, tail = Tail_Number,
            flight_num = Flight_Number_Reporting_Airline, dest = Dest,
            sched_dep, actual_dep, wheels_off,
            sched_hour = hour(sched_dep), dep_delay = DepDelay, taxi_out = TaxiOut,
            arr_delay = ArrDelay, cancelled, diverted, cancellation_code = CancellationCode,
            carrier_delay = CarrierDelay, weather_delay = WeatherDelay, nas_delay = NASDelay,
            security_delay = SecurityDelay, late_aircraft_delay = LateAircraftDelay)

arrivals <- bts |> filter(Dest == airport) |>
  transmute(flight_date = FlightDate, carrier = Reporting_Airline, tail = Tail_Number,
            flight_num = Flight_Number_Reporting_Airline, origin = Origin,
            sched_arr, actual_arr, arr_delay = ArrDelay, taxi_in = TaxiIn, cancelled, diverted)

tag <- w$tag
saveRDS(departures, file.path(dir_processed, sprintf("bts_departures_%s.rds", tag)))
saveRDS(arrivals,   file.path(dir_processed, sprintf("bts_arrivals_%s.rds", tag)))
message(sprintf("departures (incl. prior month): %d, arrivals: %d", nrow(departures), nrow(arrivals)))
