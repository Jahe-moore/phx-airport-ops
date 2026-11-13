# run_all.R
# Runs the whole project in order, from downloads to the finished report, deck and page.
# Usage, from the project root:  Rscript R/run_all.R            (everything)
#                                Rscript R/run_all.R analysis   (skip downloads and TSA parsing)
#
# Before the first run: set PHX_CACHE_DIR to a folder outside the repo (about 1.3 GB),
# run renv::restore(), and install Quarto with TinyTeX for the PDF report.

args <- commandArgs(trailingOnly = TRUE)
analysis_only <- length(args) > 0 && args[1] == "analysis"
rscript <- file.path(R.home("bin"), "Rscript")

steps <- c(
  if (!analysis_only) c("01_download_bts.R", "01_download_weather.R", "01_download_tsa.R", "01_download_cpi.R"),
  "02_clean_bts.R", "02_clean_weather.R",
  if (!analysis_only) "02_clean_tsa.R",
  "02_clean_faa.R", "04_build_flights.R", "03_validate.R",
  "09_phase0_checks.R 2025 7",
  "10_inherited_delay.R", "11_gate_delay.R", "12_taxi_out.R", "13_airfield.R", "14_weather.R", "15_tsa_demand.R",
  "20_stage_ranking.R", "30_growth_scenarios.R",
  "40_deck_charts.R", "43_video_script.R", "41_build_deck.R", "42_build_page.R", "44_build_readme.R")

for (s in steps) {
  parts <- strsplit(s, " ")[[1]]
  message("\n==== ", s)
  t0 <- Sys.time()
  status <- system2(rscript, c(file.path("R", parts[1]), parts[-1]))
  if (status != 0) stop("Step failed: ", s)
  message(sprintf("     done in %.0f s", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}

message("\n==== report")
quarto <- Sys.which("quarto")
if (quarto == "") quarto <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe"   # RStudio's bundled copy
# LaTeX comes from TinyTeX (tinytex::install_tinytex()); put it on PATH for this run
if (requireNamespace("tinytex", quietly = TRUE) && nzchar(tinytex::tinytex_root(error = FALSE)))
  Sys.setenv(PATH = paste(file.path(tinytex::tinytex_root(), "bin", "windows"), Sys.getenv("PATH"), sep = .Platform$path.sep))
status <- system2(quarto, c("render", "report/phx_departure_operations.qmd"))
if (status != 0) stop("Report render failed")
message("All steps finished.")
