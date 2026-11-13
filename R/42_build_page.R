# 42_build_page.R
# Builds the one-page project summary, site/index.html, with its charts copied to site/img/.
#
# Every number is read at build time from output/tables/headline_numbers.csv (or other tables in
# output/tables). No results are typed by hand, so a rerun of the pipeline plus this script keeps
# the page current. The page is self-contained: no external scripts, system fonts only.
#
# Usage: Rscript R/42_build_page.R

source("R/00_setup.R")

hn_tbl <- read_csv(file.path(dir_tables, "headline_numbers.csv"), show_col_types = FALSE, col_types = "ccc")
h <- function(key) {
  v <- hn_tbl$value[hn_tbl$key == key]
  if (length(v) != 1 || is.na(v)) stop("headline_numbers.csv has no value for key: ", key)
  v
}
hn  <- function(key) as.numeric(h(key))
pct <- function(key, d = 0) paste0(fmt_n(hn(key), d), "%")
usd <- function(key) fmt_usd(hn(key))
mm  <- function(x, d = 2) sprintf("%.*fM", d, as.numeric(x) / 1e6)
esc <- function(x) gsub("<", "&lt;", gsub("&", "&amp;", x, fixed = TRUE), fixed = TRUE)
carrier_name <- c(WN = "Southwest", AA = "American", OO = "SkyWest", DL = "Delta", UA = "United", MQ = "Envoy",
                  F9 = "Frontier", AS = "Alaska", B6 = "JetBlue", NK = "Spirit", HA = "Hawaiian", G4 = "Allegiant")
cn <- function(code) unname(ifelse(code %in% names(carrier_name), carrier_name[code], code))

# ---- Charts --------------------------------------------------------------------------
charts <- list(
  list(file = "act1_stage_ranking",
       takeaway = sprintf("Gate delay created at PHX is the largest stage at %s minutes a year; the 3 stages together cost about %s a year.",
                          mm(hn("stage_gate_min"), 1), usd("total_usd_base"))),
  list(file = "act1_inherited_by_hour",
       takeaway = sprintf("%s%% of departure delay is created at PHX; %s arrives on late inbound aircraft.",
                          round(100 - hn("inherited_share_pct")), pct("inherited_share_pct"))),
  list(file = "act1_taxi_by_hour",
       takeaway = sprintf("Taxi-out queues peak in the morning bank at %s extra minutes per flight around %d:00.",
                          fmt_n(hn("taxi_peak_hour_delay"), 1), as.integer(hn("taxi_peak_hour")))),
  list(file = "act2_growth_scenarios",
       takeaway = sprintf("At +15%% traffic, excess taxi-out rises %s in annual minutes and %s per flight; gate delay rises only with flight count.",
                          pct("act2_taxi_increase_pct", 1), sprintf("%+.1f%%", hn("act2_taxi_per_dep_change_pct")))))
dir.create("site/img", recursive = TRUE, showWarnings = FALSE)
for (ch in charts) {
  src <- file.path(dir_figures, paste0(ch$file, ".png"))
  if (!file.exists(src)) stop("missing figure: ", src)
  file.copy(src, file.path("site/img", basename(src)), overwrite = TRUE)
}
chart_html <- paste(vapply(charts, function(ch) sprintf(
  '<figure class="chart"><img src="img/%s.png" alt="%s" loading="lazy"><figcaption>%s</figcaption></figure>',
  ch$file, esc(ch$takeaway), esc(ch$takeaway)), character(1)), collapse = "\n      ")

a1 <- sprintf("The morning departure bank's taxi queue holds the most recoverable value, about %s a year, with %s of it in the 7 to 11 AM pushback window.",
              usd("stage_taxi_addr_usd"), pct("taxi_recoverable_7_11_share"))
a2 <- sprintf("Excess taxi-out degrades first: at +15%% traffic its annual minutes rise %s and its delay per flight rises %s, while gate delay grows only with the number of flights.",
              pct("act2_taxi_increase_pct", 1), pct("act2_taxi_per_dep_change_pct", 1))
rec <- sprintf("Spread departures out of the 7 to 11 AM bank so the taxi queue shrinks. %s (%s of the bank's queue), %s (%s), the FAA tower and PHX operations would act together. Value at stake: %s a year in the base case, %s in the high case. Holding aircraft at the gate alone saves only fuel and maintenance, about %s a year, because passengers still leave late.",
               cn(h("taxi_bank_top_carrier")), pct("taxi_bank_top_carrier_share"), cn(h("taxi_bank_second_carrier")), pct("taxi_bank_second_carrier_share"),
               usd("stage_taxi_addr_usd"), usd("stage_taxi_addr_usd_high"), usd("taxi_metering_only_usd"))
stats <- list(
  c(fmt_n(hn("departures_per_year")), "reporting-carrier departures per year"),
  c(mm(hn("dep_delay_min_per_year")), "departure delay minutes per year"),
  c(usd("total_usd_base"), "yearly cost of the 3 measured stages"),
  c(pct("link_rate_pct", 1), "of departures linked to their inbound aircraft"))
stat_html <- paste(vapply(stats, function(s) sprintf('<div class="stat"><span class="big">%s</span><span class="lbl">%s</span></div>', esc(s[1]), esc(s[2])), character(1)), collapse = "\n      ")
limits <- c(
  "Scope starts at the gate. Curb, check-in, security waits and gate occupancy have no public data.",
  sprintf("BTS covers reporting carriers only, about %s%% of PHX operations counted by the FAA in 2024-2025.", fmt_n(hn("bts_share_of_ops_pct"))),
  "TSA data is passenger counts only and implies nothing about wait times.",
  "Act 2 is a projection with today's runways, gates and procedures, and an even schedule increase by hour.",
  "Dollar inputs come from published A4A and FAA/DOT values; fix costs are not public, so dollars are recoverable value, not ROI.")
limit_html <- paste(sprintf("<li>%s</li>", esc(limits)), collapse = "\n        ")

html <- sprintf('<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PHX Departure Operations</title>
<style>
  :root { --navy:#1B2A4A; --steel:#5B7FA6; --copper:#B08D57; --ink:#1F2937; --muted:#5B6472; --bg:#FFFFFF; --panel:#F3F5F8; --rule:#D9DEE5; }
  /* Always white, even in dark mode */
  :root { color-scheme: light; }
  html { background:#FFFFFF; }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--ink); font-family:Arial, Helvetica, sans-serif; font-size:17px; line-height:1.55; }
  main { max-width:1080px; margin:0 auto; padding:40px 16px 64px; }
  h1, h2 { font-family:Georgia, "Times New Roman", serif; color:var(--navy); line-height:1.2; }
  h1 { font-size:2.1rem; margin:0 0 6px; }
  h2 { font-size:1.4rem; margin:44px 0 14px; padding-top:14px; border-top:1px solid var(--rule); }
  .sub { color:var(--muted); margin:0 0 28px; }
  .answers { display:grid; grid-template-columns:repeat(auto-fit, minmax(280px, 1fr)); gap:16px; }
  .answer { background:var(--panel); border-left:5px solid var(--navy); padding:16px 18px; }
  .answer.q2 { border-left-color:var(--copper); }
  .answer h3 { margin:0 0 6px; font-size:0.95rem; text-transform:uppercase; letter-spacing:0.04em; color:var(--muted); }
  .answer p { margin:0; }
  .stats { display:grid; grid-template-columns:repeat(auto-fit, minmax(200px, 1fr)); gap:16px; margin-top:20px; }
  .stat { padding:12px 0; border-top:3px solid var(--steel); }
  .big { display:block; font-family:Georgia, serif; font-size:1.8rem; color:var(--copper); font-weight:bold; }
  .lbl { color:var(--muted); font-size:0.95rem; }
  .videos { display:grid; grid-template-columns:repeat(auto-fit, minmax(280px, 1fr)); gap:16px; }
  .video { aspect-ratio:16/9; background:var(--panel); border:1px dashed var(--rule); display:flex; align-items:center; justify-content:center; color:var(--muted); text-align:center; padding:12px; }
  .charts { display:grid; grid-template-columns:repeat(auto-fit, minmax(420px, 1fr)); gap:24px; }
  @media (max-width:500px) { .charts { grid-template-columns:1fr; } h1 { font-size:1.6rem; } }
  figure.chart { margin:0; }
  figure.chart img { width:100%%; height:auto; display:block; border:1px solid var(--rule); }
  figcaption { font-size:0.95rem; color:var(--ink); margin-top:8px; font-weight:bold; }
  .rec { background:var(--panel); border-left:5px solid var(--copper); padding:18px 20px; }
  .rec .usd { font-family:Georgia, serif; font-size:2rem; color:var(--copper); font-weight:bold; display:block; }
  ul { padding-left:20px; }
  .links a { display:inline-block; margin:0 16px 8px 0; color:var(--steel); }
  .muted { color:var(--muted); font-size:0.9rem; }
</style>
</head>
<body>
<main>
  <h1>Where PHX departures lose time, and what breaks first as traffic grows</h1>
  <p class="sub">Phoenix Sky Harbor treated as a consulting client, using public BTS, FAA, NOAA and TSA data for 2024 and 2025. By Jake Moore.</p>

  <div class="answers">
    <div class="answer"><h3>Where is time lost, and what is the best fix?</h3><p>%s</p></div>
    <div class="answer q2"><h3>What degrades first at +15%% traffic?</h3><p>%s</p></div>
  </div>
  <div class="stats">
      %s
  </div>

  <h2>Video</h2>
  <div class="videos">
    <div class="video">Summary video coming soon</div>
    <div class="video">Full walkthrough coming soon</div>
  </div>

  <h2>Key charts</h2>
  <div class="charts">
      %s
  </div>

  <h2>Recommendation</h2>
  <div class="rec">
    <span class="usd">%s a year</span>
    <p>%s</p>
  </div>

  <h2>Limitations</h2>
  <ul>
        %s
  </ul>

  <h2>Links</h2>
  <p class="links"><a href="#">GitHub repo (link once published)</a><a href="#">Full report, PDF (link once published)</a><a href="#">Slide deck (link once published)</a></p>
  <p class="muted">Every number on this page is generated by the project scripts from public data.</p>
</main>
</body>
</html>
', esc(a1), esc(a2), stat_html, chart_html, esc(usd("stage_taxi_addr_usd")), esc(rec), limit_html)

writeLines(html, "site/index.html", useBytes = TRUE)
message("wrote site/index.html and ", length(charts), " charts in site/img")
