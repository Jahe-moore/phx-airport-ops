# Phase 0 Memo: Feasibility Check

Date: 2026-11-10. Test month: July 2025 (peak heat and monsoon). Every number below is read from a table in `output/tables/phase0_*.csv`, written by `R/09_phase0_checks.R`.

## Verdict: GO

| Go criterion (PLAN.md section 7) | Result | Pass? | Table |
|---|---|---|---|
| Tail-number linking works for at least 80% of PHX departures | 94.4% of flown departures with a tail number (strict: one departure per inbound). 93.5% of all scheduled departures | Yes | `phase0_tail_match_rate` |
| Taxi-out and departure delay vary meaningfully by hour | Mean departure delay ranges 4.4 to 36.0 min across hours 06 to 22. Mean taxi-out ranges 11.7 to 18.5 min | Yes | `phase0_by_hour` |
| At least one FAA dataset is usable | OPSNET daily delays and ASPM hourly airport metrics are both public without a login | Yes | `phase0_summary` (faa) |

## What each source delivered

| Source | Status | Key facts |
|---|---|---|
| BTS on-time | Works, scripted | 15,729 PHX departures scheduled in July 2025, 153 cancelled, 75 diverted, 12 carriers. Tail number, departure delay, taxi-out, wheels-off: 0% missing among flown flights. Arrival delay 0.5% missing (diversions). Column names differ from the plan (CamelCase); mapping added to `DATA_SOURCES.md` |
| FAA OPSNET | Works, browser form | Daily PHX operations and FAA delays by cause, public after the 20th of the next month |
| FAA ASPM Airport Analysis | Works, browser form | Hourly PHX scheduled departures, taxi-out time, taxi-out delay against FAA's unimpeded time, gate and airborne delay. Public within 60 days of month end. Has a "CSV for Excel" export |
| FAA ASPM called rates (ADR) and runway configuration | Not in the public display | Plan fallback applies: 1.4 uses OPSNET daily delays, Act 2 uses hourly scheduled departures as the load measure |
| NOAA weather (via Iowa Environmental Mesonet) | Works, scripted | 744 of 744 hours covered, 0 missing temperatures, 100% of flown departures joined to a weather hour |
| TSA throughput | Works, scripted | Both July weeks parsed (1,981 pages, 0 problem pages). PHX checkpoints: T-3 North, T-4 A, T-4 B, T-4 C, T-4 D, same set both weeks. Daily PHX throughput 46,193 to 59,086. Peak hour 06:00 at 4,772 passengers on average |

## Data quality findings that change the plan

1. **The TSA PDFs cannot be read as plain text.** Date, hour, and airport are merged cells printed once beside the rows they cover. `R/02_clean_tsa.R` assigns rows by position on the page instead. Checks: the worst label sits 0.5 points from its block's center, and no PHX checkpoint name appears under any other airport (`phase0_tsa_phx_name_leak_check` is empty).
2. **TSA coverage has gaps.** Four weeks in the 2024 to 2025 window were not found in the reading-room search for "throughput": weeks starting 2024-02-11, 2024-10-27, 2025-11-02, 2025-11-09 (`phase0_tsa_weeks_not_found`). They may exist under other names. File names are hand-typed with typos ("septembe", "demember", "august-42024"); the download script now tolerates these. TSA is descriptive context only, so four weeks do not block the analysis, and every TSA chart will name any week still missing after Phase 1 searches for them.
3. **BTS covers 80.6% of PHX operations.** BTS flown departures plus arrivals: 31,129. OPSNET total operations: 38,611. The gap is general aviation, military, cargo, international, and non-reporting carriers. Limitation 2 is now a measured number.
4. **BTS taxi-out is validated.** On 2025-07-15, BTS mean taxi-out is 13.69 min and FAA ASPM reports 13.59 min. ASPM counts 586 departures that day against BTS's 490, consistent with finding 3.
5. **The quiet-hour taxi baseline gives a smaller excess than FAA's.** For 2025-07-15, the planned baseline (each carrier's median taxi-out in the quietest quartile of hours) gives 0.85 min of excess per departure when early flights count as negative, and 2.12 min when each flight is floored at zero. FAA ASPM's taxi-out delay against its unimpeded time gives 3.99 min. The FAA unimpeded time is published only per airport and hour: the public Taxi Times report has no carrier or flight split and no unimpeded column. Decision needed (below).
6. **Tail linking has a duplicate case.** 259 inbound arrivals were the latest prior arrival for two flown departures (the aircraft left PHX twice with no reported arrival between, for example a return to gate). The strict match keeps only the first departure. Turn-time checks on matched pairs: 1 negative ground time, 1 under 20 minutes, median 69 min, 95th percentile 703 min (overnight aircraft). The links are sound.

## First look: are the peaks big enough to matter?

Yes for gate delay and taxi-out. No for the airfield as FAA records it.

- **Gate delay builds through the day.** Mean departure delay (early counted as zero) is 4.4 min at 06:00 and climbs to 36.0 min at 20:00. Share of departures 15+ min late rises from 6.9% to 47.6% (18:00). This is the shape of delay carried forward from earlier flights.
- **Inherited versus PHX-originated, first cut:** of 257,364 departure delay minutes on linked flights, 114,532 (44.5%) are inherited from a late inbound and 142,832 are created at PHX. So more than half of the lost gate time starts at PHX.
- **Taxi-out tracks the morning bank.** The 08:00 hour has the most departures (45.5 per day) and the longest mean taxi-out (18.5 min, 90th percentile 28 min). Hourly load and taxi-out correlate at 0.22 across flights.
- **FAA-recorded airfield delays are rare.** OPSNET logged 123 delays at PHX for all of July, 105 of them weather and 18 volume. 108 fell on two days (2025-07-01 and 2025-07-02, storm days). PHX is not runway-constrained most days by FAA's 15-minute definition.
- **Weather:** departures in hours at or above 110 F average 32.9 min of delay versus 18.3 min otherwise, a 14.6 min gap; storm hours average 37.4 min (164 departures). Heat hours fall in the afternoon, when delay is already high. Comparing heat and non-heat departures within the same clock hour still leaves a 9.2 min gap, weighted by heat departures (`phase0_heat_same_hour`). So heat carries a sizeable effect beyond time of day in this month. Day-of-week, carrier and inbound lateness are not yet controlled; the Phase 2 regression does that. July 2025 had 34 hours at 110 F or more, 156 at 105 F, 5 at 115 F, and 7 storm hours.

Early read for the story: the Act 1 recommendation is likely to target the gate turn (PHX-originated delay), since FAA records very few runway delays. Act 2 is likely to point at the 08:00 departure bank's taxi-out. Phase 2 tests both hypotheses.

## Decisions needed from Jake before Phase 1

| # | Decision | Recommendation |
|---|---|---|
| 1 | Excess taxi baseline | Two layers. For the stage ranking and the Act 2 load curves, which work at airport-hour level, use FAA ASPM taxi-out delay against unimpeded time, pulled hourly from the public Airport Analysis report. For anything by carrier or by flight, use the BTS quiet-hour baseline floored at zero per flight, and report the gap to FAA's figure (2.12 vs 3.99 min on 2025-07-15) as a stated range |
| 2 | Where the two-year raw cache lives | The national BTS zips total about 0.75 GB for 2024 to 2025 and the TSA PDFs about 0.5 GB. Keep them off OneDrive. Recommended: `C:\DataCache\PHX_Airport_Ops` on JAHE's local disk, set as `PHX_CACHE_DIR` (a name kept apart from jake4's `C:\HubData` hub databases). The alternative is the temp folder and a re-download each session (about 10 minutes). Only PHX extracts (about 1 MB per month) go in `data/raw` |
| 3 | FAA pulls for the full window | OPSNET and ASPM are web forms, and a plain scripted request loops on redirects because the site expects a browser session. Recommended: I drive the forms in Chrome month by month and save each report verbatim to `data/raw` (24 months times 2 reports). Since no script can regenerate them, commit these small `faa_*.txt` captures to the repo through a `.gitignore` exception, and document the exact query settings in each file header so anyone can re-pull them |
| 4 | Inherited delay definition | Keep PLAN.md's definition for Phase 1. A refinement to consider for Phase 2: subtract the scheduled turn buffer, so an inbound 10 minutes late into a 90-minute turn is not counted as inherited |

## What changed from the plan

- BTS field names are CamelCase in the prezipped files (`Tail_Number` where the plan listed `TAIL_NUM`). Mapping is in `DATA_SOURCES.md`.
- Weather comes from the Iowa Environmental Mesonet ASOS archive (same KPHX observations as NOAA), because it returns one CSV per request with no token.
- TSA counts are "Total Pax + KCM PAX", meaning screened passengers plus Known Crewmember entries.
- The public ASPM report includes FAA's taxi-out delay against unimpeded time. The plan did not expect this. It is a better excess-taxi reference than the planned quiet-hour baseline.
- Hourly called departure rates are not public. Utilization is dropped from 1.4, as the plan's fallback anticipated.

## Files

Scripts: `R/00_setup.R`, `R/01_download_bts.R`, `R/01_download_weather.R`, `R/01_download_tsa.R`, `R/02_clean_bts.R`, `R/02_clean_weather.R`, `R/02_clean_tsa.R`, `R/09_phase0_checks.R`. Run order is as numbered, each with `2025 7` as arguments (TSA takes a date range). Set `PHX_CACHE_DIR` first.

Figure: `output/figures/phase0_by_hour.png`.

Reproducibility: package versions are pinned in `renv.lock` (run `renv::restore()` first). A clean re-run of all seven scripts on 2026-11-10 reproduced `phase0_summary.csv` exactly. On JAHE a local, git-ignored `.Renviron` keeps the renv package library outside OneDrive.
