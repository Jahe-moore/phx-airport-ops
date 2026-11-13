# Data Sources

Status key: **Confirmed** means checked on 2026-11-10 (planning or Phase 0). **Verify** means not yet checked. Phase 0 results are in `docs/phase0_memo.md`.

All five sources are free US government data with no license restrictions on reuse. Cite each in the report.

---

## 1. BTS Reporting Carrier On-Time Performance (backbone)

- **Publisher:** Bureau of Transportation Statistics, US DOT
- **Landing page:** https://www.transtats.bts.gov/Tables.asp?QO_VQ=EFD (Confirmed)
- **Grain:** one row per scheduled domestic flight, 1987 to present
- **Contents (Confirmed):** scheduled and actual departure and arrival times, cancellations and diversions, taxi-out and taxi-in, causes of delay and cancellation, air time, distance
- **Access (Confirmed):** web download form, one month per file. Tail number and flight number come only through the Download function.
- **Bulk option (Confirmed in Phase 0):** prezipped monthly files, about 31 MB zipped and 286 MB unzipped, national, all columns including tail number, at
  `https://transtats.bts.gov/PREZIP/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_YYYY_M.zip`
- **Lag:** roughly two to three months after month end. Check https://www.transtats.bts.gov/releaseinfo.asp for the latest month.

**Fields needed (Confirmed). The prezipped files use CamelCase names; the web-form names map as follows:**

| Web-form name | Prezip name |
|---|---|
| `FL_DATE` | `FlightDate` |
| `OP_UNIQUE_CARRIER` | `Reporting_Airline` |
| `TAIL_NUM` | `Tail_Number` |
| `OP_CARRIER_FL_NUM` | `Flight_Number_Reporting_Airline` |
| `ORIGIN`, `DEST` | `Origin`, `Dest` |
| `CRS_DEP_TIME`, `DEP_TIME`, `DEP_DELAY` | `CRSDepTime`, `DepTime`, `DepDelay` |
| `TAXI_OUT`, `WHEELS_OFF`, `WHEELS_ON`, `TAXI_IN` | `TaxiOut`, `WheelsOff`, `WheelsOn`, `TaxiIn` |
| `CRS_ARR_TIME`, `ARR_TIME`, `ARR_DELAY` | `CRSArrTime`, `ArrTime`, `ArrDelay` |
| `CANCELLED`, `CANCELLATION_CODE`, `DIVERTED` | `Cancelled`, `CancellationCode`, `Diverted` |
| `CARRIER_DELAY` ... `LATE_AIRCRAFT_DELAY` | `CarrierDelay`, `WeatherDelay`, `NASDelay`, `SecurityDelay`, `LateAircraftDelay` |

July 2025: 631,428 national rows, 31,457 touch PHX. Tail number, departure delay and taxi-out are 0% missing among flown PHX departures.

**Filter:** keep rows where `ORIGIN == "PHX"` or `DEST == "PHX"`. Arrivals are needed to link inbound aircraft to their next departure.

**Known problems:**
- Times are local and stored as hhmm integers (for example 5 means 00:05). Flights crossing midnight need date handling.
- The five cause-of-delay fields are populated only when arrival delay is 15 minutes or more. They are carrier-reported.
- Covers domestic flights by reporting carriers only. International flights and small carriers are absent. This is a stated limitation.
- Tail numbers are occasionally missing or malformed. Report the match rate. (July 2025: 94.4% of flown departures link to an inbound under a strict one-to-one rule.)
- BTS covers 80.6% of PHX operations counted by OPSNET (July 2025: 31,129 of 38,611).
- Actual times (`DepTime`, `ArrTime`) carry no date. Build actual times as scheduled time plus the signed delay in minutes.
- Arizona does not observe daylight saving time, which simplifies PHX local-time joins. Other airports' times are in their own local zones.

---

## 2. FAA OPSNET (official airfield delay counts)

- **Publisher:** Federal Aviation Administration
- **Portal:** https://aspm.faa.gov/opsnet/sys/Main.asp
- **Grain:** daily by facility
- **Contents:** airport operations counts and reportable delays with FAA cause categories (weather, volume, equipment, runway, other)
- **Access (Confirmed):** finalized monthly data is public without a login, released on the 20th of the following month. Next-day preliminary data requires an FAA login.
- **How to pull (Confirmed):** web report form at `https://www.aspm.faa.gov/opsnet/sys/Delays.asp`. Dates = Range, Facilities = PHX, Groupings = Facility + Date gives one row per day: total operations, system impact delays, delays by class and by cause (weather, volume, equipment, runway, other), average and total delay minutes. No public API. A plain scripted request loops on redirects; the form works in a browser. July 2025 saved verbatim as `data/raw/faa_opsnet_delays_phx_2025_07_daily.txt`.

**Known problems:**
- An OPSNET "delay" is a reportable air traffic delay of 15 minutes or more. It is a different definition from BTS departure delay. Do not add the two together.

---

## 3. FAA ASPM public reports (taxi baselines, rates, runway configuration)

- **Portal:** https://aspm.faa.gov
- **Contents (Confirmed at a general level):** ASPM reports include airport weather, runway configuration, and airport arrival and departure rates. Public users without a login can access Airport Analysis, City Pair Analysis, and Taxi Time data within 60 days after month end.
- **Phase 0 results (Confirmed):**
  - Airport Analysis (`/apm/sys/AnalysisAP.asp`) is public and groups by Local Hour. Hourly fields: scheduled departures and arrivals, on-time percentages, gate departure delay, taxi-out time, **taxi-out delay against FAA unimpeded time**, airport departure delay, airborne delay, taxi-in delay, block delay, gate arrival delay. Offers "CSV for Excel" export. Sample saved as `data/raw/faa_aspm_airport_phx_2025_07_15_hourly.txt`.
  - Called departure rates (ADR) and runway configuration are not in the public Airport Analysis display. Fallback applies.
  - Taxi Times report (`/apm/sys/TaxiTimes.asp`) is public: monthly PHX departures, mean taxi-out and a taxi-out time histogram, groupable by date, hour, runway or quarter hour. It has no carrier split and no unimpeded taxi time (July 2025: 18,223 departures, mean taxi-out 14.60 min).
  - Cross-check 2025-07-15: ASPM mean taxi-out 13.59 min, BTS 13.69 min.
- **Fallback:** if hourly rates are not public, drop utilization from sub-question 1.4, rely on OPSNET daily delays, and use hourly scheduled departures from BTS as the load measure in Act 2.
- **Login option:** FAA offers a data access request form, but elevated access is intended for FAA, other government, airline, and airport users. Do not plan around getting it.

---

## 4. NOAA hourly weather, station KPHX

- **Publisher:** NOAA National Centers for Environmental Information
- **Station:** Phoenix Sky Harbor International Airport ASOS, identifier KPHX (IEM station code `PHX`; METARs carry `KPHX`). USAF 722780 / WBAN 23183 only matter if NCEI Global Hourly is used instead
- **Options (Verify each):**
  - NCEI Local Climatological Data or Global Hourly: https://www.ncei.noaa.gov/access
  - Iowa Environmental Mesonet ASOS archive, a convenient scripted download of the same observations: https://mesonet.agron.iastate.edu/request/download.phtml (**Confirmed and used.** `asos.py` endpoint with `tz=America/Phoenix` returns local timestamps. July 2025: 803 observations, 744 of 744 hours covered)
- **Fields needed:** timestamp, temperature, wind speed and gust, visibility, present-weather codes (thunderstorm, dust), precipitation
- **Known problems:**
  - Timestamps are usually UTC. Convert to America/Phoenix (UTC-7 year-round).
  - Observations are roughly hourly with extra special reports during changing weather. Aggregate to the clock hour (max temperature, max gust, minimum visibility, any thunderstorm flag).

---

## 5. TSA checkpoint throughput (demand context only)

- **Publisher:** Transportation Security Administration
- **Location (Confirmed):** TSA FOIA Electronic Reading Room, https://www.tsa.gov/foia/readingroom
- **Grain (Confirmed):** hourly passenger throughput by airport and checkpoint, published weekly
- **Format (Confirmed):** PDF tables, one national file per week, about 1,000 pages and 5 MB. Columns: date, hour of day, airport, city, state, checkpoint, "Total Pax + KCM PAX" (screened passengers plus Known Crewmember). Date, hour and airport are merged cells printed once, vertically centered beside their rows and repeated on each page, so text extraction must use word positions (`R/02_clean_tsa.R`).
- **How to pull:** download the weekly PDFs for the analysis window, parse with `pdftools`, filter to PHX.
- **Phase 0 results:**
  - 100 weekly files for weeks starting in 2024 to 2025. Not found in the reading-room search: weeks starting 2024-02-11, 2024-10-27, 2025-11-02, 2025-11-09 (`output/tables/phase0_tsa_weeks_not_found.csv`). File names are hand-typed with typos, so links are read from the reading room search rather than built from dates.
  - PHX checkpoints in July 2025: T-3 North, T-4 A, T-4 B, T-4 C, T-4 D, same in both weeks. Check again across the full window.
  - Community parsed datasets not used; the project parses the PDFs itself.

**Use restrictions for this project:**
- Describe hourly passenger demand and the multi-year growth trend.
- Do not compute, model, or imply wait times. See `CLAUDE.md` hard rule 2.

---

## Cost conversion inputs (look up, cite, flag for Jake)

| Input | Likely source | Note |
|---|---|---|
| Airline direct operating cost per block minute | Airlines for America, "U.S. Passenger Carrier Delay Costs" | Use the latest published year and state it |
| Passenger value of travel time | US DOT, "Revised Departmental Guidance on Valuation of Travel Time" | Use the aviation values and state the year |
| Average passengers per departure at PHX | BTS T-100 segment data, or PHX published statistics | Needed only if passenger time is included |

Show results with and without passenger time, since airline cost alone is the conservative figure.

---

## Join keys

| Join | Key |
|---|---|
| BTS departure to its inbound flight | `TAIL_NUM`, with inbound `DEST == "PHX"` and the latest arrival before the departure on the same or prior day |
| BTS to NOAA | PHX local date and clock hour of scheduled departure |
| BTS to FAA | date, and hour where available |
| BTS to TSA | date and hour, for descriptive comparison of passenger and flight peaks |
