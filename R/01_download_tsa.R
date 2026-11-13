# 01_download_tsa.R
# Downloads weekly TSA checkpoint throughput PDFs from the TSA FOIA reading room.
#
# The PDFs are national (about 1,000 pages each, ~5 MB), so they go to the cache
# folder outside the project. 02_clean_tsa.R extracts the PHX rows.
#
# File names are not perfectly regular (for example one week is named "tsa-total-throughput-data-...").
# So this script lists the reading room search results and takes the real links rather than
# building names from dates.
#
# Usage: Rscript R/01_download_tsa.R 2025-07-06 2025-07-19   (weeks whose start date falls in the range)

source("R/00_setup.R")

args <- commandArgs(trailingOnly = TRUE)
from <- as.Date(if (length(args) >= 1) args[1] else "2023-12-31")
to   <- as.Date(if (length(args) >= 2) args[2] else "2025-12-28")

base <- "https://www.tsa.gov"
links <- character()
for (page in 0:60) {
  html <- tryCatch(paste(readLines(sprintf("%s/foia/readingroom?keys=throughput&page=%d", base, page), warn = FALSE), collapse = "\n"),
                   error = function(e) "")
  any_pdf <- regmatches(html, gregexpr('/sites/default/files/foia-readingroom/[^"]*\\.pdf', html))[[1]]
  if (length(any_pdf) == 0) break   # past the last results page
  # Search results mix in other documents (calendars, complaint reports), so keep throughput files only
  links <- c(links, grep("throughput", any_pdf, value = TRUE))
}
links <- unique(links)

# Pull the week's start date out of the file name. Names are hand-typed and contain typos
# ("septembe-21-2025", "demember-22-2024", "august-42024", "april-20.-2025"), so month words
# are matched approximately and separators are optional. If the start date can't be read,
# the end date minus 6 days is used.
week_start <- function(name) {
  name <- tolower(basename(name))
  iso <- regmatches(name, regexec("([0-9]{4})-([0-9]{2})-([0-9]{2})", name))[[1]]
  if (length(iso)) return(as.Date(iso[1]))
  tok <- regmatches(name, gregexpr("([a-z]{3,})[-_. ]*([0-9]{1,2})[-_. ]*([0-9]{4})", name))[[1]]
  to_date <- function(t) {
    p <- regmatches(t, regexec("([a-z]{3,})[-_. ]*([0-9]{1,2})[-_. ]*([0-9]{4})", t))[[1]]
    word <- sub("^(data|throughput|total|to)+", "", p[2])          # "todecember" -> "december"
    mon <- agrep(word, tolower(month.name), max.distance = 2, value = FALSE)
    if (length(mon) != 1) mon <- which(substr(tolower(month.name), 1, 3) == substr(word, 1, 3))
    if (length(mon) != 1) return(as.Date(NA))
    suppressWarnings(as.Date(sprintf("%s-%02d-%02d", p[4], mon, as.integer(p[3]))))
  }
  if (length(tok) >= 1) { d <- to_date(tok[1]); if (!is.na(d)) return(d) }
  if (length(tok) >= 2) { d <- to_date(tok[length(tok)]); if (!is.na(d)) return(d - 6) }
  as.Date(NA)
}
all_idx <- tibble(url = links, start = as.Date(vapply(links, week_start, numeric(1)), origin = "1970-01-01"))
write_csv(all_idx, file.path(dir_cache, "tsa_all_links.csv"))   # used by the coverage check

idx <- all_idx |>
  filter(!is.na(start), start >= from, start <= to) |>
  arrange(start)

if (nrow(idx) == 0) stop("No TSA throughput PDFs found for ", from, " to ", to)
for (u in idx$url) {
  dest <- file.path(dir_cache, basename(u))
  if (!file.exists(dest)) {
    status <- download.file(paste0(base, u), dest, mode = "wb", quiet = TRUE)
    if (status != 0) stop("TSA download failed: ", u)
  }
  message("have ", basename(u))
}
write_csv(idx |> mutate(file = basename(url)), file.path(dir_cache, "tsa_index.csv"))
