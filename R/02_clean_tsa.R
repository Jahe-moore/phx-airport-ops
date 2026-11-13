# 02_clean_tsa.R
# Extracts PHX hourly checkpoint throughput from the weekly TSA PDFs.
#
# How the PDF is laid out (checked 2026-11-10 on July 2025 files):
#   - One row per checkpoint per hour, with the count at the right.
#   - Date, hour, and airport are merged cells: each is printed ONCE, vertically centered
#     beside the rows it covers, and reprinted on every page the block continues onto.
#   - So plain text extraction loses which rows belong to which airport. This script reads
#     each word's x/y position instead and assigns rows to the label they are centered on.
#
# The counts are "Total Pax + KCM PAX": screened passengers plus Known Crewmember entries.
# They are passenger COUNTS. They say nothing about wait times (CLAUDE.md hard rule 2).
#
# Usage: Rscript R/02_clean_tsa.R   (parses every PDF listed in the cache's tsa_index.csv)

source("R/00_setup.R")
suppressWarnings(suppressPackageStartupMessages(library(pdftools)))

# Column x positions on the page, in PDF points (stable across the files checked)
X_DATE <- c(40, 80); X_HOUR <- c(80, 100); X_AIRPORT <- c(100, 115)
X_CHECKPOINT <- c(315, 405); X_COUNT_MIN <- 405
Y_TOP <- 140; Y_BOTTOM <- 720            # skip the column header and the page number

# Assign rows to centered labels.
# rows_y: sorted y of data rows on one page. label_y: sorted y of labels on that page.
# Each label covers a contiguous run of rows and sits at the midpoint of its first and last row,
# so given where a block starts, its end is the row nearest to (2 * label_y - start_y).
assign_blocks <- function(rows_y, label_y) {
  n <- length(rows_y); out <- rep(NA_integer_, n); s <- 1; fit_error <- numeric(0)
  for (k in seq_along(label_y)) {
    if (s > n) break
    if (k == length(label_y)) e <- n else {
      target <- 2 * label_y[k] - rows_y[s]
      cand <- s:n
      e <- cand[which.min(abs(rows_y[cand] - target))]
    }
    out[s:e] <- k
    fit_error <- c(fit_error, abs((rows_y[s] + rows_y[e]) / 2 - label_y[k]))
    s <- e + 1
  }
  list(block = out, max_error = if (length(fit_error)) max(fit_error) else NA_real_, leftover = s <= n)
}

parse_page <- function(w, page) {
  w <- w[w$y > Y_TOP & w$y < Y_BOTTOM, ]
  # Data rows: checkpoint words plus a numeric count at the same y
  cp <- w[w$x >= X_CHECKPOINT[1] & w$x < X_CHECKPOINT[2], ]
  ct <- w[w$x >= X_COUNT_MIN & grepl("^[0-9,]+$", w$text), ]
  if (nrow(ct) == 0) return(NULL)
  rows <- ct |> group_by(y) |> summarise(count = as.integer(gsub(",", "", first(text))), .groups = "drop") |>
    left_join(cp |> arrange(x) |> group_by(y) |> summarise(checkpoint = paste(text, collapse = " "), .groups = "drop"), by = "y") |>
    arrange(y)

  ap  <- w[w$x >= X_AIRPORT[1] & w$x < X_AIRPORT[2] & grepl("^[A-Z]{3}$", w$text), ] |> arrange(y)
  dt  <- w[w$x >= X_DATE[1] & w$x < X_DATE[2] & grepl("^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$", w$text), ] |> arrange(y)
  hr  <- w[w$x >= X_HOUR[1] & w$x < X_HOUR[2] & grepl("^[0-9]{2}:[0-9]{2}$", w$text), ] |> arrange(y)
  if (nrow(ap) == 0 || nrow(dt) == 0 || nrow(hr) == 0) {
    return(tibble(page = page, problem = "missing labels"))
  }

  # Date, hour, and airport are three separate merged cells (a date spans many hours),
  # so each is assigned on its own.
  a <- assign_blocks(rows$y, ap$y)
  d <- assign_blocks(rows$y, dt$y)
  h <- assign_blocks(rows$y, hr$y)
  rows |> mutate(
    page = page,
    airport = ap$text[a$block],
    date = mdy(dt$text[d$block]),
    hour = as.integer(substr(hr$text[h$block], 1, 2)),
    airport_fit_error = a$max_error, date_fit_error = max(d$max_error, h$max_error),
    leftover_rows = a$leftover | d$leftover | h$leftover,
    problem = NA_character_)
}

index <- read_csv(file.path(dir_cache, "tsa_index.csv"), show_col_types = FALSE)
all_rows <- list()
for (f in index$file) {
  message("parsing ", f)
  pages <- pdf_data(file.path(dir_cache, f))
  parsed <- bind_rows(lapply(seq_along(pages), function(i) parse_page(pages[[i]], i)))
  all_rows[[f]] <- parsed |> mutate(source_file = f)
}
tsa <- bind_rows(all_rows)

# ---- Parser quality checks (written out, reported in the Phase 0 memo) ----------
qc <- tsa |> group_by(source_file) |> summarise(
  pages = n_distinct(page),
  pages_with_problems = n_distinct(page[!is.na(problem)]),
  rows = sum(is.na(problem)),
  rows_missing_checkpoint = sum(is.na(checkpoint) & is.na(problem)),
  worst_airport_centering_pts = max(airport_fit_error, na.rm = TRUE),
  worst_date_centering_pts = max(date_fit_error, na.rm = TRUE),
  pages_with_leftover_rows = n_distinct(page[leftover_rows %in% TRUE]),
  .groups = "drop")
save_table(qc, "phase0_tsa_parser_qc")

# In some weekly files the state column sits a few points further right, so the state code
# ("AZ") lands in front of the checkpoint name. Strip it so names match across weeks.
tsa <- tsa |> mutate(checkpoint = sub("^[A-Z]{2} (?=[^ ])", "", checkpoint, perl = TRUE))

phx <- tsa |> filter(is.na(problem), airport == !!airport) |>
  select(date, hour, checkpoint, throughput = count, source_file, page)

# Cross-check: checkpoint names seen under PHX must not appear under any other airport.
# If they did, rows near a block boundary could be mislabeled.
phx_names <- unique(phx$checkpoint)
leak <- tsa |> filter(is.na(problem), airport != !!airport, checkpoint %in% phx_names) |> count(airport, checkpoint)
save_table(leak, "phase0_tsa_phx_name_leak_check")

out <- file.path(dir_processed, "tsa_phx_hourly_checkpoint.csv")
write_csv(phx, out)
message("wrote ", out, " (", nrow(phx), " PHX checkpoint-hours)")
