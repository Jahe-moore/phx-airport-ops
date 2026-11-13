# Phase Summaries

Numbers live in `output/tables/headline_numbers.csv` and the report; this file records what each phase did and what changed from `PLAN.md`.

| Phase | Done (2026-11-10) | Found | Changed from the plan |
|---|---|---|---|
| 0 Feasibility | One month (July 2025) of every source; `docs/phase0_memo.md` | GO on all three criteria. BTS taxi-out matches FAA's within a tenth of a minute | Weather from the Iowa Environmental Mesonet; TSA PDFs need a position-based parser; FAA publishes taxi delay against unimpeded time, which replaced the planned quiet-hour baseline as the primary measure |
| 1 Pipeline | Scripted downloads for Jan 2024 to Dec 2025 (BTS, weather, TSA, CPI); FAA OPSNET daily and ASPM hourly saved from the browser forms; cleaning, `03_validate.R`, `04_build_flights.R` | Every month complete in BTS and OPSNET; tail-number link rate above Phase 0's | Processed tables are `.rds` (no Parquet); raw national files cached in `C:\DataCache\PHX_Airport_Ops`; FAA files committed because no script can re-pull them |
| 2 Act 1 | Scripts `10` to `15`, `20` | Most gate delay starts at PHX; the morning taxi queue is the largest recoverable pool; FAA air traffic delays are bursty (volume and weather) and small in minutes next to gate delay | OPSNET over the full window showed far more volume delays than July alone suggested, so it is reported as a cause overlay with its own chart. Weather effect is smaller once hour, month and carrier are controlled |
| 3 Act 2 | Script `30` | Excess taxi-out degrades first at +15%, on all days, hot days and storm days | "Degrades first" ranked by the rise in annual minutes, since the 15-minute threshold is not crossed by any stage within +20% (`method_decisions.md` #7) |
| 4 Recommendation | Report section 6, `act1_recommendation_robustness.csv` | Thin the 7 to 11 AM departure bank; holds in 3 of 4 assumption sets | The one exception (gate-hold metering only) is stated with the alternative target |
| 5 Deliverables | Report (Quarto to PDF), deck (`41`), page (`42`), video scripts (`43`), README (`44`), `run_all.R` | | Built by scripts reading the tables; nothing typed by hand |
| 6 Record and publish | Jake | | Not started: record video, create GitHub repo, link from jakemoore.dev |
