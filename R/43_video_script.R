# 43_video_script.R
# The video script, written once per slide. It is the single source for:
#   video/script.md         the full script, one section per slide
#   video/deck_notes.json   the same text, loaded into each slide's speaker notes by 41_build_deck.R
#   video/summary_cut.md    the 60-90 second recruiter cut
# Run it before 41_build_deck.R. Every number is filled from output/tables.
#
# Jake's slide-script rules: each slide opens by saying what is on screen and how it connects to the
# previous slide, explains how it was built and every number on it, says what it means, and hands off
# to the next slide. No [JAKE: ...] placeholder slots, ever. One sentence per line, blank-line pauses, 17-21 words on average, none over 28.
# Lists of three or more become bullets with a lead-in line. Digits for numbers. Voice:
# OneDrive\Projects\Wispr Flow Tone\VOICE_Spoken.md (check with check.py).

source("R/00_setup.R")
hn_tbl <- read_csv(file.path(dir_tables, "headline_numbers.csv"), show_col_types = FALSE, col_types = "ccc")
h <- function(k) { v <- hn_tbl$value[hn_tbl$key == k]; if (length(v) != 1) stop("missing headline number: ", k); v }
num <- function(k) as.numeric(h(k))
tb <- function(name) read_csv(file.path(dir_tables, paste0(name, ".csv")), show_col_types = FALSE)
r0 <- function(k) fmt_n(round(num(k)))
r1 <- function(k) format(round(num(k), 1), nsmall = 1)
money <- function(x) sprintf("$%.1f million", x / 1e6)
mill <- function(k) sprintf("%.2f million", num(k) / 1e6)
clock <- function(x) { x <- as.integer(x); if (x < 12) paste(x, "in the morning") else if (x == 12) "noon" else paste(x - 12, "at night") }
cname <- function(code) c(WN = "Southwest", AA = "American", OO = "SkyWest", DL = "Delta", UA = "United", MQ = "Envoy")[[code]]
top <- cname(h("taxi_bank_top_carrier")); second <- cname(h("taxi_bank_second_carrier")); gate_top <- cname(h("gate_recoverable_top_carrier"))
ops_day <- fmt_n(round(num("opsnet_operations_per_year") / 365.25, -1))
created <- fmt_n(round(100 - num("inherited_share_pct")))
wx <- tb("act2_bad_weather_at_15"); g <- tb("act2_growth_rates")
wxv <- function(day, stage) format(round(wx[[day]][wx$stage == stage], 1), nsmall = 1)
taxi_addr <- num("stage_taxi_addr_usd")

S <- list()
slide <- function(label, ...) S[[length(S) + 1]] <<- list(label = label, lines = c(...))
bul <- function(...) paste0("- ", c(...))

# ---- Spoken-number helpers: round the way it would be said, still computed from the data ----
near <- function(x, d = 0) { r <- round(x, d); paste(if ((r - x) / max(abs(r), 1) > 0.03) "almost" else "about", fmt_n(r, max(d, 0))) }
usd_say <- function(x) { r <- round(x / 1e6); paste0(if ((r - x / 1e6) / r > 0.03) "almost $" else "about $", fmt_n(r), " million") }
mil_say <- function(x) near(x / 1e6, 1)
yrs_say <- function(y) {
  if (is.na(y)) return("never at that pace")
  if (y > 20) return("decades away at that pace")
  f <- y - floor(y)
  if (f >= 0.3 && f <= 0.7) paste("roughly", floor(y), "or", ceiling(y), "years") else paste("roughly", round(y), "years")
}
frac_say <- function(p) if (abs(p - 33.3) < 3) "about a third" else if (p >= 63 && p <= 70) "about two-thirds" else if (abs(p - 25) < 2) "a quarter" else paste0(near(p), "%")
cap1 <- function(x) paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))
out_of_10 <- function(p) sprintf("About %d out of every 10", round(p / 10))
taxi_hot <- round(wx[["Hot days (110 F+)"]][wx$stage == "Excess taxi-out"])
taxi_storm <- round(wx[["Storm days"]][wx$stage == "Excess taxi-out"])
wx_line <- if (taxi_hot == taxi_storm) sprintf("On both hot days and storm days, the runway line still grows the most, at about %d%%.", taxi_hot) else
  sprintf("The runway line still grows the most, at about %d%% on hot days and about %d%% on storm days.", taxi_hot, taxi_storm)
ops_g <- g$growth_2025_vs_2024_pct[2]; dep_g <- g$growth_2025_vs_2024_pct[3]

# 1
slide("Title",
  "Hi, my name is Jake Moore, and I study Management Information Systems at the University of Arizona.",
  "For this project, I wanted to understand where a late departure out of Phoenix Sky Harbor actually loses its time.",
  "I also wanted to know what would break first if the airport got about 15% busier.",
  "Everything I used is public data, so all of it can be checked.")
# 2
slide("What we'll cover",
  "I'll give you the answer early, and then walk through how I got there.")
# 3
slide("Divider: The Problem",
  "I'll start with the problem.")
# 4
slide("About 1,330 takeoffs and landings a day",
  sprintf("Sky Harbor is a very busy airport, with %s takeoffs and landings a day.", near(num("opsnet_operations_per_year") / 365.25, -2)),
  sprintf("I focused on the airline departures, which come to %s flights a year.", near(num("departures_per_year"), -4)),
  sprintf("Those flights lose %s million minutes a year waiting at the gate.", mil_say(num("dep_delay_min_per_year"))),
  sprintf("On top of that, they spend %s million minutes waiting in line for the runway.", mil_say(num("stage_taxi_min"))),
  "It's American's hub and one of Southwest's largest stations, so a slow morning here affects a lot of travelers.",
  "That led me to two questions.")
# 5
slide("Two questions",
  "The first was where that time is actually being lost, whether it's the plane arriving late, the gate, or the line for the runway.",
  "I wanted to put a dollar figure on each piece, so I could recommend one fix rather than a list.",
  "The second was what breaks first if traffic grows by 15%.",
  "I'll give you both answers up front.")
# 6
slide("The answer, up front",
  "The best fix, in my view, is thinning out the morning rush of departures, so fewer planes are trying to reach the runway at the same time.",
  sprintf("In my base case, that's worth %s a year.", usd_say(taxi_addr)),
  "That same morning line is also the first thing to break as traffic grows.",
  sprintf("It gets %s%% worse per flight, while the rest of the delay barely moves.", near(num("act2_taxi_per_dep_change_pct"))),
  "Before getting into that, I want to show what the data can actually see.")
# 7
slide("Divider: What the data can see",
  "Next, the data.")
# 8
slide("We start measuring at the gate",
  "Originally, I wanted to follow a passenger from the curb all the way to takeoff.",
  "However, nobody publishes check-in times or security wait times, and the TSA only reports how many people pass through.",
  "So I set a rule for myself: if a step isn't measured publicly, I leave it out.",
  "I didn't want to estimate a wait time, because one made-up number would undermine everything else.",
  "As a result, the analysis starts when the plane lands and runs through takeoff.")
# 9
slide("Five public sources, one table",
  "That left me with five public sources:",
  bul("the government's on-time data for every domestic flight",
      "the FAA's hourly taxi times",
      "the FAA's official count of air traffic delays",
      "hourly weather at the airport",
      "and the TSA's hourly passenger counts"),
  sprintf("I matched each departure to its aircraft's previous arrival using the tail number, which worked for %s%% of flights.", near(num("link_rate_pct"))),
  sprintf("The on-time data covers %s%% of the traffic here, since cargo and international flights aren't included.", near(num("bts_share_of_ops_pct"))),
  "I built everything in R, and the whole project reruns from a single script.")
# 10
slide("Divider: Where the time goes",
  "Now, where the time actually goes.")
# 11
slide(sprintf("%s%% of gate delay starts at PHX", created),
  "The first thing I wanted to know was where this delay was actually coming from.",
  "Is Phoenix causing it, or is it inheriting late planes from other airports?",
  "For every departure, I looked up the aircraft's previous arrival.",
  "If that plane landed 20 minutes late, those 20 minutes came from somewhere else.",
  "Ultimately, I expected that to be most of the delay, and it wasn't.",
  sprintf("%s minutes of delay started here in Phoenix.", out_of_10(100 - num("inherited_share_pct"))))
# 12
slide("Delay snowballs through the day",
  "That delay also builds over the course of the day.",
  sprintf("Early in the morning, flights leave %s minutes late on average.", near(num("gate_delay_morning_mean"))),
  sprintf("By %s, that has grown to %s minutes.", clock(h("gate_delay_peak_hour")), near(num("gate_delay_peak_hour_mean"))),
  "Each late aircraft makes its next flight late, and the effect stacks up throughout the day.")
# 13
slide("The runway line peaks in the morning rush",
  "The runway worked differently, because it wasn't a buildup over the day.",
  "Rather, it started in the morning.",
  sprintf("It peaks around %s AM, and that's when Southwest and American both send out their first big wave of flights.", h("taxi_peak_hour")),
  sprintf("A lot of aircraft are heading to the same runway at the same time, and that adds %s minutes of waiting per flight.", near(num("taxi_peak_hour_delay"))),
  sprintf("%s of that waiting happens between 7 and 11 AM, which is why the morning is where I focused the fix.", cap1(frac_say(num("taxi_recoverable_7_11_share")))))
# 14
slide("FAA delays are rare, and they come in bursts",
  "I also looked at the FAA's own count of air traffic delays, which only includes holds of 15 minutes or more.",
  sprintf("There are only %s a year, which is low for an airport this busy.", near(num("opsnet_delays_per_year"), -2)),
  sprintf("%s of them happen on just 10 bad days, mostly from storms and heavy traffic.", cap1(frac_say(num("opsnet_top10_days_share_pct")))),
  "So on most days, the runway itself isn't the bottleneck.")
# 15
slide("Storms hurt. Heat barely registers",
  "Given that this is Phoenix, I expected heat to be a major factor.",
  "To test it, I compared flights at the same time of day, on the same airline, in the same month.",
  sprintf("A 110 degree hour only adds %s minutes of delay per flight.", near(num("heat_phx_orig_effect"))),
  sprintf("Storms have a much bigger effect, at %s minutes per flight.", near(num("storm_phx_orig_effect"))),
  "However, there aren't many storm hours, so over a full year weather is a small share of the delay.")
# 16
slide("Gate delay created at PHX is the biggest pool",
  "Next, I put a dollar figure on each piece.",
  "That combines what a minute costs the airline with what a minute is worth to the passengers on board.",
  "I used the airline industry's own cost figures and the federal government's value for travelers' time.",
  sprintf("Delay created at the gate here is the largest, at %s a year.", usd_say(num("stage_gate_usd_base"))),
  sprintf("The runway line is next, at %s.", usd_say(num("stage_taxi_usd_base"))),
  sprintf("Delay carried in on late planes is %s.", usd_say(num("stage_inherited_usd_base"))),
  "These are estimates, so they could be off somewhat in either direction.")
# 17
slide("Divider: One fix",
  "That brings me to the fix.")
# 18
slide("Thin the 7 to 11 AM departure bank",
  "My recommendation is to thin out the morning rush, meaning the departures between 7 and 11 AM.",
  "I chose it by measuring how much time could be recovered if Phoenix simply matched its own better hours.",
  "The runway line had the most to give back.",
  sprintf("%s and %s each schedule %s of that morning rush, so they would need to work it out with the FAA tower and the airport.", top, second, frac_say(num("taxi_bank_top_carrier_share"))),
  sprintf("It's worth %s a year, and even recovering a quarter of that would be %s.", usd_say(taxi_addr), usd_say(0.25 * taxi_addr)))
# 19
slide("It only works if the line actually shrinks",
  "How the fix is carried out matters, though.",
  "If departures are actually spread out, the line gets shorter, and both the airline and the passengers get that time back.",
  "Some airports instead hold planes at the gate until the runway is clear.",
  sprintf("That saves fuel, but passengers still leave just as late, so it's only worth %s a year.", usd_say(num("taxi_metering_only_usd"))),
  sprintf("In that case, the better target would be how quickly planes turn around at the gate, where %s accounts for %s%% of the recoverable time.", gate_top, near(num("gate_recoverable_top_carrier_share"), -1)))
# 20
slide("Divider: What breaks first",
  "Now, the second question.")
# 21
slide("The morning taxi line breaks first",
  "To test growth, I compared the same hour on busy days and slower days, so I wasn't simply comparing mornings to evenings.",
  "Then I increased every hour's traffic by 15%.",
  sprintf("The runway line gets %s%% worse per flight.", near(num("act2_taxi_per_dep_change_pct"))),
  "Gate delay barely changes per flight, and it only grows because there are more flights.",
  "So the morning runway line is what breaks first, and it's the same place the fix is aimed at.")
# 22
slide("The taxi line pulls away as traffic grows",
  "As traffic increases, the runway line keeps pulling away from everything else.",
  "The shaded area shows the range the result could reasonably fall within.",
  sprintf("%s%% of those busier hours are levels Phoenix has already handled, so this isn't a guess far beyond the data.", cap1(near(num("act2_pct_hours_inside_range")))))
# 23
slide("Same answer on hot days and storm days",
  "I also checked whether bad weather changes the result, and it doesn't.",
  wx_line,
  "That gives me confidence the answer holds up in Phoenix's actual conditions.")
# 24
slide("But 15% isn't coming on its own",
  "That said, Phoenix barely grew between 2024 and 2025.",
  "Passenger counts actually dipped slightly.",
  sprintf("Airport traffic grew %s, so reaching 15%% is %s.", if (ops_g < 1) "less than 1%" else paste0(near(ops_g), "%"), yrs_say(g$years_to_plus_15_pct[2])),
  sprintf("Airline flights grew %s%%, which would take %s.", near(dep_g), yrs_say(g$years_to_plus_15_pct[3])),
  "So 15% growth likely won't happen on its own.",
  "If it does, it will probably be an airline adding a wave of morning flights, which is exactly where the line already breaks.")
# 25
slide("Divider: So what",
  "So, what does this mean for Phoenix?")
# 26
slide("What PHX should watch",
  "If I were advising the airport, I would watch three things:",
  bul("morning taxi times, since the FAA publishes them monthly and they move first",
      "any new morning flights, since those are the most costly",
      "and how quickly planes turn around at the gate, since that's the largest pool today"),
  "If I had to choose one, it would be morning taxi times.")
# 27
slide("What this can't see",
  "There are a few limitations I want to be upfront about:",
  bul("the analysis starts at the gate, so security lines aren't included",
      "about a fifth of flights aren't in the on-time data",
      "airlines report their own delay causes",
      "the TSA data is passenger counts only",
      "the growth test assumes the same runways and procedures",
      "and the dollar figures are averages, with no cost estimate for the fix itself"),
  "None of these change the direction of the answer, but they do mean the numbers carry a range.")
# 28
slide("What I learned",
  "The biggest lesson for me was that most of the work is getting messy public data to line up.",
  "The modeling was the easier part.",
  "Leaving out what I couldn't measure also made the results much more credible.")
# 29
slide("Questions",
  "To sum it up, if I were running Sky Harbor, I would track morning taxi times every month and work with the airlines to spread out the morning rush.",
  "The code, the full report, and the data sources are linked below. Thank you for watching.")

stopifnot(length(S) == 29)

# ---- Write script.md ----------------------------------------------------------------
md <- c("# PHX Departure Operations: deck script",
        "",
        "One section per slide. This is the same text as the speaker notes in `slides\\PHX_Departure_Operations.pptx`, both built by `R\\43_video_script.R` from `output\\tables`. Edit a copy if you rewrite by hand.",
        "")
for (i in seq_along(S)) {
  md <- c(md, "---", "", sprintf("## Slide %d: %s", i, S[[i]]$label), "")
  for (ln in S[[i]]$lines) md <- c(md, ln, "")
}
writeLines(md, "video/script.md")
jsonlite::write_json(lapply(S, `[[`, "lines"), "video/deck_notes.json", auto_unbox = FALSE, pretty = TRUE)

# ---- 10-minute version: 13 of the 29 slides, with the dropped slides' key points folded in ----
# Keys are slide numbers in the full deck. 41_build_deck.R builds slides/PHX_Departure_Operations_10min.pptx
# from these and loads these notes.
M <- list()
mslide <- function(n, ...) M[[length(M) + 1]] <<- list(full = n, label = S[[n]]$label, lines = c(...))
mslide(1,
  "Hi, I'm Jake Moore, and I study Management Information Systems at the University of Arizona.",
  "If you've flown out of Phoenix Sky Harbor, you've probably sat at the gate or on the taxiway wondering what the holdup was.",
  "I wanted to find out where that time actually goes, using only public data.",
  "Then I asked a second question: if the airport gets about 15% busier, what breaks first?")
mslide(4,
  sprintf("Sky Harbor handles %s takeoffs and landings a day.", near(num("opsnet_operations_per_year") / 365.25, -2)),
  sprintf("I focused on the airline departures, which is %s flights a year.", near(num("departures_per_year"), -4)),
  sprintf("Across those flights, %s million minutes a year are lost at the gate, and %s million more are spent waiting in line for the runway.", mil_say(num("dep_delay_min_per_year")), mil_say(num("stage_taxi_min"))),
  "Gate delay is how much later each flight pushed back than scheduled, added up across every flight, and early departures count as zero so they don't cancel out the late ones.",
  "The runway waiting is taxi time beyond what the FAA considers a normal, unimpeded taxi at Phoenix.",
  "Sky Harbor is American's hub and one of Southwest's biggest stations, so when the morning goes badly here, it affects connections across the country.")
mslide(6,
  "I'll give you the answer first.",
  "The best fix is thinning out the morning departure rush.",
  "Too many flights are scheduled to leave between 7 and 11, so they end up waiting in line for the same runway.",
  sprintf("Spreading them out is worth %s a year in time saved for the airlines and their passengers.", usd_say(taxi_addr)),
  "That same morning line is also the first thing to break as the airport grows.",
  sprintf("With 15%% more traffic, it gets %s%% worse per flight, while everything else barely moves.", near(num("act2_taxi_per_dep_change_pct"))))
mslide(8,
  "I originally wanted to follow a passenger from the curb all the way to takeoff.",
  "However, security wait times and check-in times aren't published anywhere, so I set a rule: if it isn't measured, it isn't in the analysis.",
  "That meant starting when the plane lands and ending when it takes off.",
  "For that, I used five public sources: the federal on-time records for every domestic flight, the FAA's hourly taxi times, the FAA's count of air traffic delays, hourly weather at the airport, and the TSA's passenger counts.",
  "The tail number is the registration painted on the aircraft, so it follows the same plane from one flight to the next.",
  sprintf("I matched every departure to that plane's previous arrival using its tail number, which worked for %s%% of flights.", near(num("link_rate_pct"))),
  sprintf("That on-time data covers %s%% of the traffic here, since cargo and international flights aren't included.", near(num("bts_share_of_ops_pct"))))
mslide(11,
  "The first thing I wanted to know was where this delay was actually coming from.",
  "Is Phoenix causing it, or is it inheriting late planes from other airports?",
  "For every departure, I looked at how late that aircraft arrived.",
  "If it landed 20 minutes late, those 20 minutes came from somewhere else.",
  "More precisely, I took the smaller of two numbers: how late the plane arrived, and how late the next flight left. Whatever was left over started in Phoenix.",
  "I expected that to explain most of the delay, and it didn't.",
  sprintf("%s minutes of delay start right here in Phoenix.", out_of_10(100 - num("inherited_share_pct"))),
  sprintf("Airlines also build some cushion into their turnarounds, and if I give them credit for that, the Phoenix share rises to %s%%.", near(100 - num("inherited_slack_share_pct"))),
  "It also compounds through the day.",
  sprintf("Early in the morning, flights leave %s minutes late on average.", near(num("gate_delay_morning_mean"))),
  sprintf("By %s, that's up to %s minutes, because every late plane makes its next flight late too.", clock(h("gate_delay_peak_hour")), near(num("gate_delay_peak_hour_mean"))),
  "Those are averages across every flight scheduled in each hour, over both years.")
mslide(13,
  "The runway behaves differently, because it doesn't build up over the day.",
  "Rather, it spikes in the morning.",
  sprintf("It peaks around %s AM, which is when Southwest and American both send out their first big wave of flights.", h("taxi_peak_hour")),
  sprintf("That puts a lot of aircraft in line for the same runway at the same time, and it adds %s minutes of waiting per flight.", near(num("taxi_peak_hour_delay"))),
  "To measure that waiting, I used the FAA's hourly taxi data, which compares each flight's actual taxi time to the FAA's unimpeded time for Phoenix, and the difference is time spent in line.",
  "Then I compared each hour against the level Phoenix sees in its quietest hours, and added up everything above that.",
  sprintf("%s of that extra waiting happens between 7 and 11 AM.", cap1(frac_say(num("taxi_recoverable_7_11_share")))),
  "I also checked the FAA's own count of air traffic delays, which only includes holds of 15 minutes or more.",
  sprintf("There are only %s of those a year here, and %s of them fall on just 10 bad days.", near(num("opsnet_delays_per_year"), -2), frac_say(num("opsnet_top10_days_share_pct"))),
  "So the runway works fine most days.",
  "The problem is the schedule sending too many planes to it at once.")
mslide(15,
  "Since this is Phoenix, I expected heat to be a big factor.",
  "I counted a hot hour as any hour that hit 110 degrees at the airport's weather station, and a storm hour as thunderstorms, strong gusts or low visibility.",
  "To test it, I compared flights at the same time of day, on the same weekday, on the same airline, in the same month, so the only real difference was the weather.",
  sprintf("A 110 degree hour only adds %s minutes per flight.", near(num("heat_phx_orig_effect"))),
  sprintf("Storms add %s minutes, but Phoenix doesn't get many storm hours, so over a full year weather is a small part of the delay.", near(num("storm_phx_orig_effect"))))
mslide(16,
  "Next, I put a dollar value on each part of the delay, combining what a minute costs the airline with what it's worth to the passengers on board.",
  sprintf("For the airline, I used Airlines for America's 2025 figure of %s dollars a minute for a plane that's moving.", near(num("rate_taxi_airline"))),
  sprintf("For a plane waiting at the gate, I used %s dollars a minute, because the engines are off and it isn't burning fuel.", near(num("rate_gate_airline"))),
  sprintf("For passengers, I used the federal value of %s dollars an hour of travel time, times %s people on a typical flight.", near(num("vtts_2025_per_hour")), near(num("pax_per_dep_mainline"), -1)),
  "Then I multiplied those rates by the minutes in each part of the delay.",
  sprintf("Delay created at the gate in Phoenix is the largest, at %s a year.", usd_say(num("stage_gate_usd_base"))),
  sprintf("The runway line is %s, and delay carried in on late planes is %s.", usd_say(num("stage_taxi_usd_base")), usd_say(num("stage_inherited_usd_base"))),
  "The gate is the biggest pool, but that doesn't automatically make it the best place to act.")
mslide(18,
  "To choose the fix, I asked how much time Phoenix could recover just by performing like its own better hours.",
  "For the runway, that's the waiting above Phoenix's quietest hours.",
  "For the gate, it's bringing each airline up to the typical large airline in that same hour.",
  "Delay that comes in on late planes doesn't count, since it starts at other airports.",
  "The morning runway line had the most to give back.",
  "So my recommendation is to thin out the 7 to 11 AM departure bank.",
  sprintf("%s and %s each schedule %s of it, so it would take both airlines working with the FAA tower and the airport.", top, second, frac_say(num("taxi_bank_top_carrier_share"))),
  sprintf("In my base case, that's worth %s a year, and even recovering a quarter of it is %s.", usd_say(taxi_addr), usd_say(0.25 * taxi_addr)))
mslide(19,
  "How it's done matters.",
  "If flights are actually spread out, the line gets shorter, and both the airlines and their passengers get that time back.",
  "Some airports instead hold planes at the gate until the runway is clear.",
  sprintf("That saves fuel, but passengers still leave just as late, so it's only worth %s a year.", usd_say(num("taxi_metering_only_usd"))),
  "That figure only counts the airline's fuel and maintenance cost, because nobody gets any travel time back.",
  sprintf("If that's the only option, the better target is turnaround time at the gate, where %s accounts for %s%% of the time that could be recovered.", gate_top, near(num("gate_recoverable_top_carrier_share"), -1)))
mslide(21,
  "For the second question, I compared the same hour on busy days and slower days, so I wasn't just comparing mornings to evenings.",
  "I fit a model of delay per flight against the number of departures scheduled in that hour, controlling for the weekday and the month.",
  "Then I added 15% more traffic to every hour and ran it again.",
  "The ranges come from rerunning that model 1,000 times with the uncertainty in its estimates.",
  sprintf("The runway line gets %s%% worse per flight.", near(num("act2_taxi_per_dep_change_pct"))),
  "A runway can only handle so many departures an hour, and as traffic gets close to that limit, the line grows fast.",
  "Gate delay barely changes per flight.",
  sprintf("%s%% of those busier hours are traffic levels Phoenix has already handled, and the result holds on hot days and storm days too.", cap1(near(num("act2_pct_hours_inside_range")))))
mslide(24,
  "That said, Phoenix barely grew from 2024 to 2025.",
  sprintf("Passenger counts dipped slightly, and airport traffic grew %s.", if (ops_g < 1) "less than 1%" else paste0(near(ops_g), "%")),
  "To estimate timing, I took the growth from 2024 to 2025 and asked how many years that rate would take to add up to 15%.",
  sprintf("At that pace, 15%% growth is %s.", yrs_say(g$years_to_plus_15_pct[2])),
  "More likely, it would come from an airline adding a new wave of morning flights, which is exactly where the line already breaks.")
mslide(27,
  "There are a few limits worth being clear about.",
  "The analysis starts at the gate, so security lines aren't included.",
  "About a fifth of flights, mostly cargo and international, aren't in the on-time data.",
  "Airlines report their own delay causes.",
  "The dollar figures are averages, with no cost estimate for the fix itself.",
  "None of that changes the direction of the answer, but it does mean the numbers carry a range.")
mslide(29,
  "The biggest lesson for me was that most of the work is getting messy public data to line up.",
  "The modeling was the easier part, and leaving out what I couldn't measure made the results more credible.",
  "If I were advising Sky Harbor, I'd track morning taxi times every month, since the FAA publishes them and they're the first thing to move.",
  "I'd also work with the airlines to spread out that morning rush.",
  "The code, the full report and the data are linked below. Thanks for watching.")
mini_keep <- vapply(M, `[[`, numeric(1), "full")

md10 <- c("# PHX Departure Operations: 10-minute script", "",
          "14 slides. Same text as the speaker notes in `slides/PHX_Departure_Operations_10min.pptx`, built by `R/43_video_script.R`.", "")
for (i in seq_along(M)) {
  md10 <- c(md10, "---", "", sprintf("## Slide %d: %s", i, M[[i]]$label), "")
  for (ln in M[[i]]$lines) md10 <- c(md10, ln, "")
}
writeLines(md10, "video/script_10min.md")
jsonlite::write_json(list(keep = mini_keep, notes = lapply(M, `[[`, "lines")), "video/deck_notes_10min.json", auto_unbox = FALSE, pretty = TRUE)
message(sprintf("wrote video/script_10min.md (%d slides, %d words)", length(M), sum(lengths(strsplit(unlist(lapply(M, `[[`, "lines")), "[[:space:]]+")))))

# ---- Summary cut ---------------------------------------------------------------------------
summary <- c("# Summary cut, 60 to 90 seconds", "",
  "Face cam. Same register as the deck script.", "",
  S[[1]]$lines[1], "",
  "For this project, I wanted to understand where a late departure out of Phoenix Sky Harbor actually loses its time.", "",
  sprintf("%s minutes of delay start here in Phoenix, rather than coming in on late planes from other airports.", out_of_10(100 - num("inherited_share_pct"))), "",
  "The line for the runway is worst in the morning, when Southwest and American both send out their first big wave of flights.", "",
  sprintf("My recommendation is to thin out that morning rush, which is worth %s a year.", usd_say(taxi_addr)), "",
  "That same morning line is also the first thing to break if traffic grows by 15%.", "",
  "The full walkthrough, the code, and the data are linked below.")
writeLines(summary, "video/summary_cut.md")
message(sprintf("wrote video/script.md, video/deck_notes.json (%d slides) and video/summary_cut.md", length(S)))
