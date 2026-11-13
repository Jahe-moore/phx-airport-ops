# 41_build_deck.R
# Builds slides/PHX_Departure_Operations.pptx with officer.
#
# Look (matches Jake's ALKEME Next Best Policy deck): warm off-white slides with pale diagonal bands,
# navy full-bleed section dividers, one gold accent, a small uppercase gold label over a short title
# that ends in a period, big-number slides, simple flow diagrams and white cards. Charts are the
# deck_*.png files from 40_deck_charts.R (no titles of their own; the slide carries the headline).
#
# Every number is read at build time from output/tables. Speaker notes carry the talk track.
# Usage: Rscript R/40_deck_charts.R && Rscript R/41_build_deck.R

source("R/00_setup.R")
suppressPackageStartupMessages(library(officer))

# ---- Numbers -----------------------------------------------------------------------
hn_tbl <- read_csv(file.path(dir_tables, "headline_numbers.csv"), show_col_types = FALSE, col_types = "ccc")
h <- function(key) { v <- hn_tbl$value[hn_tbl$key == key]; if (length(v) != 1 || is.na(v)) stop("missing key: ", key); v }
hn <- function(key) as.numeric(h(key))
tb <- function(name) read_csv(file.path(dir_tables, paste0(name, ".csv")), show_col_types = FALSE)
p0 <- function(key) paste0(fmt_n(hn(key)), "%")
p1 <- function(key) paste0(format(round(hn(key), 1), nsmall = 1), "%")
usd <- function(key) fmt_usd(hn(key))
mill <- function(key) sprintf("%.2fM", hn(key) / 1e6)
carrier_name <- c(WN = "Southwest", AA = "American", OO = "SkyWest", DL = "Delta", UA = "United", MQ = "Envoy", F9 = "Frontier", AS = "Alaska")
cn <- function(code) unname(carrier_name[code])
growth <- tb("act2_growth_rates"); wx15 <- tb("act2_bad_weather_at_15")
ops_per_day <- hn("opsnet_operations_per_year") / 365.25
created_share <- 100 - hn("inherited_share_pct")
yrs <- function(x) if (is.na(x)) "+15%: not on this trend" else paste("+15% in", fmt_n(x, 1), "years")

# ---- Look --------------------------------------------------------------------------
NAVY <- "#1B2A4A"; GOLD <- "#E3A13B"; GOLD_D <- "#B9781C"; INK <- "#2B3445"; MUTED <- "#6E7584"
BG <- "#F3F1EC"; CARD <- "#FFFFFF"; LINE <- "#E2DED6"; SAND <- "#CFC8BC"; GREYBOX <- "#E4E1DA"
W <- 13.333; H <- 7.5; M <- 0.75
HEAD <- "Bahnschrift SemiBold"; BODY <- "Segoe UI"
f <- function(size, col = INK, family = BODY, bold = FALSE, italic = FALSE) fp_text(font.family = family, font.size = size, color = col, bold = bold, italic = italic)

# ---- Drawn assets (backgrounds, cards) ---------------------------------------------------
adir <- file.path(tempdir(), "deck_assets"); dir.create(adir, showWarnings = FALSE)
dev_png <- function(path, w, h, res = 144) png(path, width = w * res, height = h * res, res = res,
                                               type = if (capabilities("cairo")) "cairo" else "windows", bg = "transparent")
make_bg <- function(path, base, band1, band2, square, dots) {
  dev_png(path, W, H); par(mar = c(0, 0, 0, 0)); plot.new(); plot.window(c(0, W), c(0, H), xaxs = "i", yaxs = "i")
  rect(0, 0, W, H, col = base, border = NA)
  polygon(c(9.9, 11.3, 14.6, 13.2), c(0, 0, H, H), col = band1, border = NA)
  polygon(c(11.9, 12.5, 15.8, 15.2), c(0, 0, H, H), col = band2, border = NA)
  if (!is.na(square)) rect(0, 0, 0.32, 0.32, col = square, border = NA)
  for (i in 0:3) for (j in 0:3) points(0.12 + i * 0.07, H - 0.12 - j * 0.07, pch = 16, cex = 0.32, col = dots)
  dev.off(); path
}
bg_light <- make_bg(file.path(adir, "bg_light.png"), BG, "#E8E4DC", "#ECE9E2", GOLD, "#C9C3B8")
bg_navy  <- make_bg(file.path(adir, "bg_navy.png"), NAVY, "#22345A", "#203153", GOLD, "#3D5079")
rounded <- function(fill, border = NA, shadow = TRUE, w = 4, h = 2, r = 0.12) {
  path <- file.path(adir, sprintf("box_%s_%s_%.2f_%.2f_%s.png", sub("#", "", fill), sub("#", "", ifelse(is.na(border), "none", border)), w, h, shadow))
  if (file.exists(path)) return(path)
  dev_png(path, w, h, 120); par(mar = c(0, 0, 0, 0)); plot.new()
  grid::grid.newpage()
  if (shadow) grid::grid.roundrect(x = 0.503, y = 0.49, width = 0.985, height = 0.965, r = grid::unit(r, "inches"),
                                   gp = grid::gpar(fill = "#00000012", col = NA))
  grid::grid.roundrect(x = 0.5, y = 0.505, width = 0.985, height = 0.97, r = grid::unit(r, "inches"),
                       gp = grid::gpar(fill = fill, col = if (is.na(border)) NA else border, lwd = 1.4))
  dev.off(); path
}

doc <- read_pptx()
sz <- xml2::xml_find_first(doc$presentation$get(), "//p:sldSz", xml2::xml_ns(doc$presentation$get()))
xml2::xml_set_attrs(sz, c(cx = "12192000", cy = "6858000"))   # 16:9, 13.333 x 7.5 in
loc <- function(l, t, w, h) ph_location(left = l, top = t, width = w, height = h)
par_ <- function(x, prop, align = "left", after = 4, line = 1.1) fpar(ftext(x, prop = prop), fp_p = fp_par(text.align = align, padding.bottom = after, line_spacing = line))
put <- function(x, prop, l, t, w, h, align = "left", after = 4, line = 1.1) doc <<- ph_with(doc, par_(x, prop, align, after, line), location = loc(l, t, w, h))
put_lines <- function(lines, prop, l, t, w, h, after = 8) doc <<- ph_with(doc, do.call(block_list, lapply(lines, par_, prop = prop, after = after)), location = loc(l, t, w, h))
img <- function(path, l, t, w, h) doc <<- ph_with(doc, external_img(path, width = w, height = h), location = loc(l, t, w, h))
box <- function(l, t, w, h, fill = CARD, border = LINE, shadow = TRUE) img(rounded(fill, border, shadow, w, h), l, t, w, h)
solid <- function(l, t, w, h, col) {
  p <- file.path(adir, paste0("s_", sub("#", "", col), ".png"))
  if (!file.exists(p)) { png(p, 16, 16, bg = col); par(mar = c(0, 0, 0, 0)); plot.new(); dev.off() }
  img(p, l, t, w, h)
}
png_dim <- function(path) { con <- file(path, "rb"); on.exit(close(con)); b <- readBin(con, "raw", 24)
  c(w = sum(as.integer(b[17:20]) * 256^(3:0)), h = sum(as.integer(b[21:24]) * 256^(3:0))) }

slide_no <- 0
footer <- function(dark = FALSE) {
  slide_no <<- slide_no + 1
  # No slide number: the 10-minute deck reuses these slides, and a number would skip
  put("PHX DEPARTURE OPERATIONS", f(9.5, if (dark) "#8E9BB5" else MUTED, HEAD), W - 4.6, H - 0.48, 4.1, 0.3, align = "right")
}
# Speaker notes come from video/deck_notes.json (written by 43_video_script.R), loaded after all
# slides are built, so the deck notes and video/script.md are always the same text.
notes <- function(x) invisible(NULL)

content <- function(label, title, source = NULL, talk = "") {
  doc <<- add_slide(doc, layout = "Blank", master = "Office Theme")
  img(bg_light, 0, 0, W, H)
  put(toupper(label), f(10.5, GOLD_D, HEAD), M, 0.42, 8, 0.3)
  solid(M, 0.74, 0.42, 0.045, GOLD)
  put(title, f(30, NAVY, HEAD), M, 0.86, W - 2 * M - 0.6, 1.25, line = 1.0)
  if (!is.null(source)) put(source, f(9, MUTED), M, H - 0.5, 8.2, 0.32)
  footer(); if (nzchar(talk)) notes(talk)
}
divider <- function(num, label, title, talk = "") {
  doc <<- add_slide(doc, layout = "Blank", master = "Office Theme")
  img(bg_navy, 0, 0, W, H)
  put(sprintf("%s  /  %s", num, toupper(label)), f(11, GOLD, HEAD), M, 3.0, 8, 0.32)
  solid(M, 3.34, 0.42, 0.045, GOLD)
  put(title, f(46, "#FFFFFF", HEAD), M, 3.45, 10.5, 1.3)
  footer(dark = TRUE); if (nzchar(talk)) notes(talk)
}
chart <- function(name, l = M, t = 2.1, w = W - 2 * M, h = 4.55) {
  box(l, t, w, h)
  path <- file.path(dir_figures, paste0("deck_", name, ".png")); d <- png_dim(path); r <- d[["w"]] / d[["h"]]
  iw <- min(w - 0.4, (h - 0.3) * r); ih <- iw / r
  img(path, l + (w - iw) / 2, t + (h - ih) / 2, iw, ih)
}
stat <- function(big, label, l, t, w = 3.6, col = GOLD, size = 44) {
  put(big, f(size, col, HEAD), l, t, w, 0.95, line = 0.9)
  put(label, f(13.5, INK), l, t + 0.95, w, 0.9, line = 1.05)
}
card <- function(tag, head, body, l, t, w, h, tag_col = NAVY, head_col = NAVY, head_size = 18, body_top = 1.42) {
  box(l, t, w, h)
  solid(l + 0.3, t + 0.32, 0.3 + nchar(tag) * 0.075, 0.27, tag_col)
  put(toupper(tag), f(9, "#FFFFFF", HEAD), l + 0.36, t + 0.32, 3, 0.27)
  put(head, f(head_size, head_col, HEAD), l + 0.3, t + 0.72, w - 0.6, 0.75, line = 1.0)
  put_lines(body, f(13.5, INK), l + 0.3, t + body_top, w - 0.6, h - body_top - 0.1, after = 5)
}
step_flow <- function(steps, cols, txt_cols, t, sub = NULL) {
  n <- length(steps); gap <- 0.38; w <- (W - 2 * M - gap * (n - 1)) / n
  for (i in seq_len(n)) {
    x <- M + (i - 1) * (w + gap)
    box(x, t, w, 1.25, fill = cols[i], border = NA, shadow = cols[i] != GREYBOX)
    put(sprintf("%d", i), f(10, txt_cols[i], HEAD), x, t + 0.16, w, 0.25, align = "center")
    put(steps[i], f(14.5, txt_cols[i], HEAD), x + 0.08, t + 0.42, w - 0.16, 0.75, align = "center", line = 1.0)
    if (!is.null(sub)) put(sub[i], f(10.5, MUTED), x, t + 1.35, w, 0.55, align = "center", line = 1.0)
    if (i < n) put("→", f(18, MUTED), x + w, t + 0.38, gap, 0.45, align = "center")
  }
}
src_bts <- "Source: BTS On-Time Performance, 2024-2025"
src_faa <- "Source: FAA ASPM, 2024-2025"

# ===================================== OPENING =====================================
doc <- add_slide(doc, layout = "Blank", master = "Office Theme")
img(bg_light, 0, 0, W, H)
put("NOVEMBER 2026", f(10.5, GOLD_D, HEAD), M, 0.6, 6, 0.3); solid(M, 0.92, 0.42, 0.045, GOLD)
put("Sky Harbor", f(58, NAVY, HEAD), M, 2.05, 9, 1.05, line = 0.9)
put("Departures", f(58, NAVY, HEAD), M, 2.95, 9, 1.05, line = 0.9)
put("Where the time goes between the gate and takeoff, and what breaks first as traffic grows. Built on public FAA, DOT, NOAA and TSA data.",
    f(15, MUTED), M, 4.25, 7.4, 0.9, line = 1.15)
put("Jake Moore", f(15, NAVY, HEAD), M, 5.55, 6, 0.35)
put("Management Information Systems  ·  University of Arizona, Eller College", f(11.5, MUTED), M, 5.88, 7, 0.3)
footer()
notes(sprintf("Hi, I'm Jake Moore, and in this one I treated Phoenix Sky Harbor like a consulting client. So the question is where departures lose time between the gate and takeoff, and what breaks first if traffic grows, and I only used public federal data to answer it."))

content("Table of contents", "What we'll cover.", talk = "So here's the plan. I'll set up the problem, show what the public data can and can't see, walk through where the time goes, give the one fix I'd pick, and then stress test it with 15 percent more traffic.")
items <- c("The problem and the two questions", "What public data can see", "Where the time goes", "The fix", "What breaks first as traffic grows", "Limits and what I learned")
for (i in seq_along(items)) {
  y <- 2.15 + (i - 1) * 0.72
  put(sprintf("%02d", i), f(11, GOLD_D, HEAD), M, y + 0.06, 0.6, 0.3)
  put("◆", f(9, GOLD), M + 0.62, y + 0.07, 0.3, 0.3)
  put(items[i], f(17, INK), M + 1.0, y, 8, 0.4)
  solid(M, y + 0.55, 7.8, 0.012, LINE)
}

divider("01", "Background", "The Problem.", talk = "So first, the problem.")

content("The problem", sprintf("About %s takeoffs and landings a day.", fmt_n(round(ops_per_day, -1))),
        source = "Source: FAA OPSNET, BTS On-Time Performance, 2024-2025",
        talk = sprintf("So Sky Harbor handles about %s takeoffs and landings a day, and it's American's hub and a huge Southwest station. Departures in the federal on-time data lose about %s million minutes a year at the gate, plus another %s million minutes sitting in the taxi line, and that time costs airlines and passengers real money.",
                       fmt_n(round(ops_per_day, -1)), format(round(hn("dep_delay_min_per_year") / 1e6, 1), nsmall = 1), format(round(hn("stage_taxi_min") / 1e6, 1), nsmall = 1)))
stat(fmt_n(hn("departures_per_year")), "airline departures a year in the federal on-time data", M, 2.35)
stat(paste0(mill("dep_delay_min_per_year"), " min"), "lost at the gate each year, early departures counted as zero", M + 4.1, 2.35)
stat(paste0(mill("stage_taxi_min"), " min"), "of extra taxi-out time beyond FAA's normal taxi time", M + 8.2, 2.35)
solid(M, 4.75, W - 2 * M, 0.012, LINE)
put_lines(c("American runs a hub here, and Southwest runs one of its biggest stations.",
            "Every late pushback costs crew time and fuel, and it costs passengers their time."), f(16, INK), M, 5.0, 11, 1.2)

content("The questions", "Two questions.", talk = "So I boiled it down to two questions. Where does time get lost and which single fix pays off the most, and if traffic grows 15 percent, which part of the operation breaks first.")
card("Question 1", "Where does time get lost, and which single fix has the best return?",
     c("Inbound plane, gate, pushback, taxi, takeoff.", "Sized in minutes and dollars."), M, 2.25, 5.7, 2.55)
card("Question 2", "If traffic grows 15%, what breaks first?",
     c("Fit on busier days PHX already had.", "Tested on hot days and storm days."), M + 6.1, 2.25, 5.7, 2.55, tag_col = GOLD, head_col = NAVY, body_top = 1.12)

content("Headline result", "The answer, up front.", source = paste(src_bts, "·", src_faa),
        talk = sprintf("So here's the answer up front. The best fix is thinning out the 7 to 11 AM departure rush, because that's where most of the runway line builds, and it's worth about %s a year in the base case. And that same morning line is the first thing to break when traffic grows, getting about %s worse per flight at plus 15 percent.",
                       usd("stage_taxi_addr_usd"), p1("act2_taxi_per_dep_change_pct")))
put(usd("stage_taxi_addr_usd"), f(96, GOLD, HEAD), M, 2.2, 6.2, 1.6, line = 0.85)
put("a year in recoverable value in the 7 to 11 AM taxi queue", f(17, NAVY, HEAD), M + 0.05, 3.85, 5.8, 0.8, line = 1.05)
solid(7.0, 2.35, 0.03, 3.6, LINE)
put("Best fix today", f(12, GOLD_D, HEAD), 7.4, 2.35, 5, 0.3)
put("Thin the morning departure bank so the runway line shrinks.", f(19, NAVY, HEAD), 7.4, 2.68, 5.3, 0.95, line = 1.0)
put("First to break at +15% traffic", f(12, GOLD_D, HEAD), 7.4, 3.9, 5, 0.3)
put(sprintf("The same queue: %s more taxi delay per flight, while gate delay barely moves.", p1("act2_taxi_per_dep_change_pct")), f(19, NAVY, HEAD), 7.4, 4.23, 5.3, 1.0, line = 1.0)

# ===================================== DATA =====================================
divider("02", "Foundations", "What the data can see.", talk = "So before any results, here's what public data can actually measure.")

content("Scope", "We start measuring at the gate.",
        talk = "So my first idea was curb to takeoff, and then I cut it back, because nobody publishes security wait times or gate assignments. The TSA only publishes passenger counts, so I used those for demand and nothing else, and I didn't model anything I couldn't measure.")
step_flow(c("Curb and check-in", "Security line", "Inbound plane arrives", "Gate and pushback", "Taxi-out", "Wheels up"),
          c(GREYBOX, GREYBOX, NAVY, NAVY, NAVY, GOLD), c(MUTED, MUTED, "#FFFFFF", "#FFFFFF", "#FFFFFF", NAVY), 2.55,
          sub = c("not published", "counts only, no waits", "BTS, per flight", "BTS, per flight", "FAA, per hour", ""))
solid(M + 2 * (W - 2 * M + 0.38) / 6, 4.55, (W - 2 * M + 0.38) / 6 * 4 - 0.38, 0.03, GOLD)
put("measured journey", f(10.5, GOLD_D, HEAD, italic = TRUE), M + 2 * (W - 2 * M + 0.38) / 6, 4.62, 7.5, 0.3, align = "center")
put("Rule I set: if a stage isn't measured publicly, it's out of scope. No estimating around missing data.", f(14, INK, italic = TRUE), M, 5.35, 11, 0.5)

content("Data", "Five public sources, one table.", talk = sprintf("So I pulled 5 sources. The BTS file has every domestic flight, the FAA gives taxi times and air traffic delays, then hourly weather at the airport and TSA checkpoint counts. And BTS covers about %s percent of what actually flies at PHX, because cargo, private and international flights aren't in it.", fmt_n(hn("bts_share_of_ops_pct"))))
srcs <- list(c("Per flight", "BTS on-time", "Every domestic flight: times, taxi, delay causes."),
             c("Per hour", "FAA ASPM", "Taxi-out delay against FAA's normal taxi time."),
             c("Per day", "FAA OPSNET", "Official air traffic delays, by cause."),
             c("Per hour", "Weather", "Heat, storms, wind and visibility at KPHX."),
             c("Per hour", "TSA counts", "Passengers screened, by checkpoint."))
cw <- (W - 2 * M - 4 * 0.25) / 5
for (i in seq_along(srcs)) card(srcs[[i]][1], srcs[[i]][2], srcs[[i]][3], M + (i - 1) * (cw + 0.25), 2.2, cw, 2.55, tag_col = if (i == 1) GOLD else NAVY, head_size = 15.5, body_top = 1.12)
put(sprintf("%s of flown departures matched to the plane's previous arrival by tail number  ·  BTS covers %s of PHX operations",
            p1("link_rate_pct"), p0("bts_share_of_ops_pct")), f(13.5, NAVY, HEAD), M, 5.3, W - 2 * M, 0.4)

# ===================================== WHERE TIME GOES =====================================
divider("03", "Where time is lost", "Where the time goes.", talk = "So, where does the time actually go.")

content("Gate delay", sprintf("%d%% of gate delay starts at PHX.", round(created_share)), source = paste(src_bts, "· inbound linked by tail number"),
        talk = sprintf("So I linked every departure to the plane's previous arrival, and %s percent of the gate delay is created right here at PHX, while the rest comes in on a plane that was already late. Even if you give airlines credit for the slack they build into turns, it's still most of it.", fmt_n(round(created_share))))
chart("inherited", w = 8.2)
stat(paste0(fmt_n(round(created_share)), "%"), "of gate-delay minutes are created at PHX", 9.35, 2.4, 3.3)
stat(p0("inherited_share_pct"), "arrive on a late inbound plane", 9.35, 4.3, 3.3, col = NAVY)

content("Through the day", "Delay snowballs through the day.", source = src_bts,
        talk = sprintf("So delay builds all day, from about %s minutes a flight before 8 AM to about %s minutes by %s o'clock, and that's the knock-on pattern where every late plane makes the next one late.", fmt_n(round(hn("gate_delay_morning_mean"))), fmt_n(round(hn("gate_delay_peak_hour_mean"))), h("gate_delay_peak_hour")))
chart("gate")

content("Taxi-out", "The runway line peaks in the morning rush.", source = paste(src_faa, "· extra time beyond FAA's unimpeded taxi time"),
        talk = sprintf("Taxi-out is different, because it peaks in the morning bank, when the most planes push back at once, at about %s extra minutes a flight around %s AM. And %s percent of the avoidable line sits between 7 and 11.", fmt_n(round(hn("taxi_peak_hour_delay"))), h("taxi_peak_hour"), fmt_n(round(hn("taxi_recoverable_7_11_share")))))
chart("taxi", w = 8.2)
stat(paste0(format(round(hn("taxi_peak_hour_delay"), 1), nsmall = 1), " min"), sprintf("extra taxi per flight at %s AM", h("taxi_peak_hour")), 9.35, 2.4, 3.3)
stat(p0("taxi_recoverable_7_11_share"), "of the avoidable line sits between 7 and 11 AM", 9.35, 4.3, 3.3, col = NAVY)

content("Airfield", "FAA delays are rare, and they come in bursts.", source = "Source: FAA OPSNET, 2024-2025",
        talk = sprintf("The FAA's own delay counts were smaller than I expected, about %s a year, and %s percent of them land on just 10 bad days, mostly storms and volume. Those minutes already show up inside gate and taxi time, so I treat them as a cause and not a separate stage.", fmt_n(hn("opsnet_delays_per_year")), fmt_n(round(hn("opsnet_top10_days_share_pct")))))
chart("airfield", w = 8.2)
stat(fmt_n(hn("opsnet_delays_per_year")), "FAA-recorded delays a year", 9.35, 2.4, 3.3)
stat(p0("opsnet_top10_days_share_pct"), "fall on the worst 10 of 731 days", 9.35, 4.3, 3.3, col = NAVY)

content("Weather", "Storms hurt. Heat barely registers.", source = paste(src_bts, "· weather: KPHX ASOS · same hour, weekday, month and carrier"),
        talk = sprintf("I expected the 110 degree days to be a big deal, and they're really not, about %s minutes a flight. Storm hours are the ones that hurt, about %s minutes, but there just aren't many of them, so over a year weather is a small piece.", format(round(hn("heat_phx_orig_effect"), 1), nsmall = 1), fmt_n(round(hn("storm_phx_orig_effect")))))
chart("weather", w = 8.2)
stat(paste0("+", fmt_n(round(hn("storm_phx_orig_effect"))), " min"), "of gate delay per flight in a storm hour", 9.35, 2.4, 3.3, col = NAVY)
stat(paste0("+", format(round(hn("heat_phx_orig_effect"), 1), nsmall = 1), " min"), "in a 110 F hour, after controls", 9.35, 4.3, 3.3)

content("Stage ranking", "Gate delay created at PHX is the biggest pool.", source = paste(src_bts, "·", src_faa, "· costs: A4A 2025, FAA/DOT value of time"),
        talk = sprintf("So when I put dollars on it, gate delay created at PHX is the biggest pool at about %s a year, then the taxi line at about %s, then the delay carried in on late planes. Dollars are airline cost per minute plus passengers' time.", usd("stage_gate_usd_base"), usd("stage_taxi_usd_base")))
chart("stages", t = 2.25, h = 3.75)
put("Airline cost per minute from Airlines for America (2025), plus passenger time at the FAA/DOT value. Base case shown.", f(12.5, MUTED, italic = TRUE), M, 6.2, 11, 0.35)

# ===================================== THE FIX =====================================
divider("04", "Recommendation", "One fix.", talk = "So, the one fix I'd pick.")

content("Recommendation", "Thin the 7 to 11 AM departure bank.", source = paste(src_bts, "·", src_faa),
        talk = sprintf("So I'd thin out the morning bank, because the taxi line is where the most value is recoverable, about %s a year in the base case. %s and %s each schedule about a third of it, so it's on them with the FAA tower and the airport. Even catching a quarter of it is worth around %s a year.",
                       usd("stage_taxi_addr_usd"), cn(h("taxi_bank_top_carrier")), cn(h("taxi_bank_second_carrier")), fmt_usd(0.25 * hn("stage_taxi_addr_usd"))))
card("Mechanism", "Fewer planes in line at once.", c("Spread morning departures into nearby hours, or sequence them so the queue stays short.", "Passengers and planes both get the time back."), M, 2.2, 3.75, 3.1)
card("Who acts", sprintf("%s and %s.", cn(h("taxi_bank_top_carrier")), cn(h("taxi_bank_second_carrier"))),
     c(sprintf("%s and %s of the line in that window.", p0("taxi_bank_top_carrier_share"), p0("taxi_bank_second_carrier_share")), "With the FAA tower and PHX airside ops."), M + 4.05, 2.2, 3.75, 3.1)
card("Value", sprintf("%s a year.", usd("stage_taxi_addr_usd")),
     c(sprintf("%s at 25%% capture.", fmt_usd(0.25 * hn("stage_taxi_addr_usd"))), sprintf("%s at 50%% capture.", fmt_usd(0.5 * hn("stage_taxi_addr_usd"))), "Fix cost isn't public, so this is value, not ROI."),
     M + 8.1, 2.2, 3.75, 3.1, tag_col = GOLD)

content("The catch", "It only works if the line actually shrinks.", source = "Recoverable value per year, base case",
        talk = sprintf("The catch is how you do it. If you just hold planes at the gate instead of shrinking the line, you only save fuel, about %s a year, because passengers still leave late. And then the better target is gate turns, where %s holds about %s percent of the recoverable minutes.",
                       usd("taxi_metering_only_usd"), cn(h("gate_recoverable_top_carrier")), fmt_n(round(hn("gate_recoverable_top_carrier_share")))))
box(M, 2.2, 5.6, 3.9, fill = CARD, border = GOLD)
solid(M + 4.2, 2.05, 1.2, 0.3, GOLD); put("SELECTED", f(9, NAVY, HEAD), M + 4.2, 2.05, 1.2, 0.3, align = "center")
put("Thin the bank", f(13, GOLD_D, HEAD), M + 0.35, 2.5, 5, 0.3)
put(usd("stage_taxi_addr_usd"), f(46, NAVY, HEAD), M + 0.35, 2.85, 5, 0.9)
put_lines(c("The queue gets shorter.", "Planes and passengers both save the time."), f(14, INK), M + 0.35, 3.95, 5, 1.6)
put("vs", f(16, MUTED, HEAD), M + 5.6, 3.8, 0.9, 0.4, align = "center")
box(M + 6.5, 2.2, 5.33, 3.9)
put("Hold planes at the gate", f(13, MUTED, HEAD), M + 6.85, 2.5, 5, 0.3)
put(usd("taxi_metering_only_usd"), f(46, MUTED, HEAD), M + 6.85, 2.85, 5, 0.9)
put_lines(c("Saves fuel only. Passengers still leave late.", sprintf("Then the better target is gate turns: %s, with %s holding %s.", usd("stage_gate_addr_usd"), cn(h("gate_recoverable_top_carrier")), p0("gate_recoverable_top_carrier_share"))), f(14, INK), M + 6.85, 3.95, 4.7, 1.9)

# ===================================== GROWTH =====================================
divider("05", "Stress test", "What breaks first.", talk = "So now the stress test. What happens with 15 percent more traffic.")

content("Headline result", "The morning taxi line breaks first.", source = paste(src_bts, "·", src_faa, "· same hour on busy vs light days"),
        talk = sprintf("So I compared the same hour on busy days and light days, and then scaled every hour up. The taxi line comes out first, about %s worse per flight at plus 15 percent, while gate delay just grows with the number of flights.", p1("act2_taxi_per_dep_change_pct")))
put(paste0("+", p1("act2_taxi_per_dep_change_pct")), f(110, GOLD, HEAD), M, 2.2, 7, 1.8, line = 0.85)
put("more taxi delay per flight at +15% traffic", f(19, NAVY, HEAD), M + 0.05, 4.1, 6.5, 0.5)
solid(7.6, 2.35, 0.03, 3.4, LINE)
stat(paste0("+", p1("act2_taxi_increase_pct")), "rise in total taxi minutes a year", 8.0, 2.3, 4.3, col = NAVY, size = 36)
stat(paste0("+", p1("act2_gate_per_dep_change_pct")), "change in gate delay per flight, so it only grows with flight count", 8.0, 4.15, 4.3, col = NAVY, size = 36)

content("Growth scenarios", "The taxi line pulls away as traffic grows.", source = paste(src_bts, "·", src_faa, "· 90% intervals"),
        talk = sprintf("Here's the full curve, and the shaded bands are the uncertainty. The taxi line separates from the rest as traffic climbs, and %s percent of hours at plus 15 are still inside loads PHX has already handled, so this isn't a wild extrapolation.", fmt_n(round(hn("act2_pct_hours_inside_range")))))
chart("growth")

content("Bad weather", "Same answer on hot days and storm days.", source = paste(src_bts, "·", src_faa),
        talk = "And I reran it on just the hot days and just the storm days, because Phoenix summers are their own thing, and the answer didn't change. The taxi line still grows fastest.")
types <- c("All days", "Hot days (110 F+)", "Storm days")
for (i in seq_along(types)) {
  x <- M + (i - 1) * 3.95; v <- wx15[[types[i]]]; s <- wx15$stage
  box(x, 2.25, 3.65, 3.6)
  put(toupper(types[i]), f(10.5, GOLD_D, HEAD), x + 0.3, 2.5, 3, 0.3)
  rows <- c("Excess taxi-out", "Created at PHX (gate)", "Inherited from late inbound")
  labs <- c("Taxi queue", "Gate delay at PHX", "Late inbound")
  for (k in seq_along(rows)) {
    val <- v[s == rows[k]]
    put(labs[k], f(14, INK), x + 0.3, 2.95 + (k - 1) * 0.85, 2.3, 0.4)
    put(paste0("+", format(round(val, 1), nsmall = 1), "%"), f(20, if (k == 1) GOLD_D else NAVY, HEAD), x + 2.2, 2.88 + (k - 1) * 0.85, 1.2, 0.45, align = "right")
  }
}
put("Rise in total minutes a year at +15% traffic", f(12.5, MUTED, italic = TRUE), M, 6.05, 8, 0.3)

content("Timing", "But 15% isn't coming on its own.", source = "Sources: FAA OPSNET, TSA throughput, BTS, 2024-2025",
        talk = sprintf("The honest part is that traffic was basically flat from 2024 to 2025, about %s for FAA operations. So 15 percent isn't coming on its own, and if it happens it's probably an airline adding a bank of flights, which is exactly where it'd hurt.", p1("growth_ops_pct")))
g <- growth
lab <- c("Passengers screened", "FAA airport operations", "Airline departures")
for (i in 1:3) {
  x <- M + (i - 1) * 3.95
  box(x, 2.25, 3.65, 2.6)
  put(toupper(lab[i]), f(10.5, GOLD_D, HEAD), x + 0.3, 2.5, 3.2, 0.3)
  gr <- g$growth_2025_vs_2024_pct[i]
  put(sprintf("%s%.1f%%", if (gr > 0) "+" else "", gr), f(36, NAVY, HEAD), x + 0.3, 2.85, 3.2, 0.8)
  put(paste("2025 vs 2024  ·", yrs(g$years_to_plus_15_pct[i])), f(12.5, INK), x + 0.3, 3.75, 3.2, 0.6)
}
put("A 15% jump would more likely come from a schedule decision, like a new bank of morning flights.", f(16, NAVY, HEAD), M, 5.25, 11.5, 0.5)

# ===================================== CLOSE =====================================
divider("06", "Wrap-up", "So what.", talk = "So, what this means and what I took away from it.")

content("Implications", "What PHX should watch.", talk = "So the one number I'd tell PHX to watch is morning taxi delay, because the FAA publishes it every month and it's the first thing that moves. Any new morning departures are the expensive ones, and gate turns are the big pool if the queue can't be shortened.")
watch <- list(c("Leading indicator", "Morning taxi delay.", "FAA publishes it hourly, 60 days after month end. It moves first."),
              c("Growth", "New morning flights cost the most.", "Growth outside the bank adds flights without adding line time."),
              c("Second target", "Gate turns.", sprintf("The biggest pool today, and %s holds most of the recoverable part.", cn(h("gate_recoverable_top_carrier")))))
for (i in 1:3) card(watch[[i]][1], watch[[i]][2], watch[[i]][3], M + (i - 1) * 3.95, 2.2, 3.65, 2.6, tag_col = if (i == 1) GOLD else NAVY)

content("Limitations", "What this can't see.", talk = "And the limits, said out loud. It starts at the gate, BTS misses about a fifth of the traffic, the dollar inputs are published averages that still need checking, and nobody publishes what it costs an airline to move a bank, so this is recoverable value and not a return on investment.")
lims <- c("Starts at the gate. Curb, check-in and security waits aren't public.",
          sprintf("BTS covers about %s of PHX operations. Cargo, private and international flights are missing.", p0("bts_share_of_ops_pct")),
          "Delay causes are airline-reported, and only for flights 15+ minutes late.",
          "TSA data is passenger counts only. No wait times implied.",
          "Growth is a projection: same runways, same procedures, every hour scaled.",
          "Dollar inputs are published averages. Fix costs aren't public, so this is value, not ROI.")
for (i in seq_along(lims)) {
  y <- 2.15 + (i - 1) * 0.66
  put("◆", f(10, GOLD), M, y + 0.05, 0.3, 0.3)
  put(lims[i], f(16, INK), M + 0.4, y, 11.5, 0.45)
}

content("Reflection", "What I learned.", talk = "On the technical side, joining messy public data took most of the time, and the TSA PDFs alone needed a parser that reads where each number sits on the page. And on the judgment side, cutting the stages I couldn't measure made the whole thing more believable, and I'd do that the same way again.")
card("Technical", "Messy public data is most of the work.", c("Linked 95% of flights to their inbound plane by tail number.", "TSA PDFs needed a parser that reads where each number sits on the page.", "Everything rebuilds from one R script."), M, 2.2, 5.7, 3.2, body_top = 1.22)
card("Judgment", "Cut what you can't measure.", c("Dropped curb and security waits instead of guessing.", "Tested the fix against every assumption that could flip it.", "Said the limits out loud."), M + 6.1, 2.2, 5.7, 3.2, tag_col = GOLD, body_top = 1.22)

doc <- add_slide(doc, layout = "Blank", master = "Office Theme")
img(bg_navy, 0, 0, W, H)
put("THANK YOU", f(11, GOLD, HEAD), M, 2.7, 6, 0.32); solid(M, 3.04, 0.42, 0.045, GOLD)
put("Questions.", f(54, "#FFFFFF", HEAD), M, 3.15, 9, 1.2)
put("Jake Moore  ·  Repo, report and page links go here once published.", f(15, "#C9D2E3"), M, 4.55, 10, 0.4)
footer(dark = TRUE)
notes("So that's it. The code, the full report and the data sources are linked below, and thanks for watching.")

# ---- Speaker notes: the deck script, one sentence per paragraph with a blank line between ----
np <- fp_text(font.family = "Segoe UI", font.size = 14)
add_notes <- function(d, script) {
  for (i in seq_along(script)) {
    d <- on_slide(d, i)
    lines <- sub("^- ", "•  ", unlist(script[[i]]))
    paras <- unlist(lapply(lines, function(l) list(fpar(ftext(l, prop = np)), fpar(ftext("", prop = np)))), recursive = FALSE)
    d <- set_notes(d, do.call(block_list, paras), location = notes_location_type("body"))
  }
  d
}
bare <- file.path(tempdir(), "deck_no_notes.pptx")
print(doc, target = bare)

# Full deck
script <- jsonlite::read_json("video/deck_notes.json", simplifyVector = FALSE)
if (length(script) != length(doc)) stop("deck_notes.json has ", length(script), " slides but the deck has ", length(doc), ". Update 43_video_script.R.")
doc <- add_notes(doc, script)
print(doc, target = "slides/PHX_Departure_Operations.pptx")
message(sprintf("wrote slides/PHX_Departure_Operations.pptx (%d slides)", length(doc)))

# 10-minute deck: the same slides, keeping only the ones listed in deck_notes_10min.json
mini <- jsonlite::read_json("video/deck_notes_10min.json", simplifyVector = FALSE)
keep <- unlist(mini$keep)
d10 <- read_pptx(bare)
for (i in rev(seq_len(length(d10)))) if (!(i %in% keep)) d10 <- remove_slide(d10, index = i)
if (length(d10) != length(mini$notes)) stop("10-minute deck has ", length(d10), " slides but ", length(mini$notes), " notes")
d10 <- add_notes(d10, mini$notes)
print(d10, target = "slides/PHX_Departure_Operations_10min.pptx")
message(sprintf("wrote slides/PHX_Departure_Operations_10min.pptx (%d slides)", length(d10)))
