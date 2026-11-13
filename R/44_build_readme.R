# 44_build_readme.R
# Writes README.md, the public summary, with every number read from output/tables/headline_numbers.csv.

source("R/00_setup.R")
hn <- read_csv(file.path(dir_tables, "headline_numbers.csv"), show_col_types = FALSE, col_types = "ccc")
h <- function(k) { v <- hn$value[hn$key == k]; if (length(v) != 1) stop("missing headline number: ", k); v }
num <- function(k) as.numeric(h(k))
m2 <- function(k) sprintf("%.2f million", num(k) / 1e6)
pc <- function(k) sprintf("%.1f%%", num(k))
cname <- function(code) c(WN = "Southwest", AA = "American", OO = "SkyWest", DL = "Delta", UA = "United")[[code]]

readme <- c(
"# PHX Departure Operations",
"",
"A consulting-style diagnostic of Phoenix Sky Harbor (PHX) departures built entirely on public federal data: where time is lost between the gate and takeoff, which single fix has the best return, and which stage breaks first if traffic grows 15%.",
"",
"## Findings (2024-2025)",
"",
"| | |",
"|---|---|",
sprintf("| Gate delay per year | %s minutes, %s of it created at PHX and the rest inherited from late inbound aircraft |", m2("dep_delay_min_per_year"), sprintf("%.1f%%", 100 - num("inherited_share_pct"))),
sprintf("| Excess taxi-out per year | %s minutes beyond FAA's unimpeded taxi time |", m2("stage_taxi_min")),
sprintf("| Largest stage | Gate delay created at PHX, about %s a year (airline cost plus passenger time, base case) |", fmt_usd(num("stage_gate_usd_base"))),
sprintf("| Recommendation | Thin the 7-11 AM departure bank: %s of the recoverable taxi queue, about %s a year in the base case. %s and %s schedule most of it |", pc("taxi_recoverable_7_11_share"), fmt_usd(num("stage_taxi_addr_usd")), cname(h("taxi_bank_top_carrier")), cname(h("taxi_bank_second_carrier"))),
sprintf("| Degrades first at +15%% traffic | Excess taxi-out: +%s annual minutes, %s worse per departure. Gate delay grows only with flight count (%s per departure) |", pc("act2_taxi_increase_pct"), pc("act2_taxi_per_dep_change_pct"), pc("act2_gate_per_dep_change_pct")),
"",
"![Stage ranking](output/figures/act1_stage_ranking.png)",
"",
"## Reproduce",
"",
"Prerequisites: R 4.6, `renv`, Quarto with TinyTeX (`quarto install tinytex`).",
"",
"```",
"# 1. choose a cache folder outside the repo (about 1.3 GB of national source files)",
"setx PHX_CACHE_DIR C:/DataCache/PHX_Airport_Ops        # Windows; use export on macOS/Linux",
"# 2. restore packages, then run everything (about 45 minutes, mostly downloads and PDF parsing)",
"Rscript -e \"renv::restore()\"",
"Rscript R/run_all.R",
"```",
"",
"Scripts run in numbered order: `01` download, `02` clean, `03` validate, `04` build the flight table, `10`-`15` Act 1, `20` stage ranking and dollars, `30` growth scenarios, `41`-`44` deck, page, video script and this README. Every number in the report, deck, page and README is read from `output/tables/headline_numbers.csv`.",
"",
"## Data",
"",
"| Source | Link |",
"|---|---|",
"| BTS Reporting Carrier On-Time Performance | https://www.transtats.bts.gov/Tables.asp?QO_VQ=EFD |",
"| FAA ASPM Airport Analysis and OPSNET (saved from the browser forms; query settings in each file) | https://www.aspm.faa.gov |",
"| KPHX hourly weather, Iowa Environmental Mesonet ASOS archive | https://mesonet.agron.iastate.edu/request/download.phtml |",
"| TSA checkpoint throughput, FOIA reading room | https://www.tsa.gov/foia/readingroom |",
"| Cost inputs (A4A, FAA/DOT value of time, FAA seats and load factors) | `data/reference/cost_inputs.csv` |",
"",
"## Limitations",
"",
"- Scope starts at the gate. Curb, check-in, security wait times and gate assignment are not publicly measured and are excluded.",
sprintf("- BTS covers domestic flights of the larger U.S. carriers, about %s of PHX operations by FAA count.", pc("bts_share_of_ops_pct")),
"- BTS delay causes are airline-reported and exist only for flights arriving 15+ minutes late.",
"- TSA data is passenger counts only. No wait times are implied.",
"- Act 2 is a projection fitted on observed PHX hours, assuming proportional schedule growth and today's infrastructure.",
"- Dollar figures depend on published unit costs (see `cost_inputs.csv`). Fix costs are not public, so value is recoverable value per year, not ROI.",
"",
"## Documents",
"",
"| File | What it is |",
"|---|---|",
"| `report/phx_departure_operations.pdf` | Full written report |",
"| `slides/PHX_Departure_Operations.pptx` | Presentation deck with speaker notes |",
"| `site/index.html` | One-page summary |",
"| `video/script.md`, `video/summary_cut.md` | Video scripts |",
"| `PLAN.md`, `docs/method_decisions.md`, `docs/phase0_memo.md`, `docs/DATA_SOURCES.md` | Plan, method choices, feasibility check, source notes |",
"")
writeLines(readme, "README.md")
message("wrote README.md")
