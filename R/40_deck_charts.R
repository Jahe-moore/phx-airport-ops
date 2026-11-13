# 40_deck_charts.R
# Redraws the key charts for the slide deck: no titles or captions (the slide carries the headline
# and the source line), bigger text, and the deck palette. Reads only output/tables, so the deck
# charts always match the report.
# Output: output/figures/deck_*.png

source("R/00_setup.R")
windowsFonts(Segoe = windowsFont("Segoe UI"))

NAVY <- "#1B2A4A"; GOLD <- "#E3A13B"; SAND <- "#CFC8BC"; STEEL <- "#5B7FA6"; INK <- "#2B3445"; MUTED <- "#7A8291"
tb <- function(name) read_csv(file.path(dir_tables, paste0(name, ".csv")), show_col_types = FALSE)

theme_deck <- function() {
  theme_minimal(base_size = 15, base_family = "Segoe") +
    theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(color = "#ECE9E3"),
          axis.title = element_text(color = MUTED, size = 12), axis.text = element_text(color = INK),
          legend.position = "top", legend.justification = "left", legend.title = element_blank(),
          legend.text = element_text(color = INK, size = 13),
          plot.background = element_rect(fill = "white", color = NA), plot.margin = margin(10, 16, 8, 8))
}
save_deck <- function(p, name, w = 10, h = 4.6) {
  ggsave(file.path(dir_figures, paste0("deck_", name, ".png")), p, width = w, height = h, dpi = 220, bg = "white")
}
hours_lab <- function(x) ifelse(x < 12, paste0(x, "a"), ifelse(x == 12, "12p", paste0(x - 12, "p")))

# 1. Inherited vs created at PHX, by hour
d <- tb("act1_inherited_by_hour") |> pivot_longer(c(inherited, phx_originated)) |>
  mutate(name = factor(if_else(name == "inherited", "Carried in on a late plane", "Created at PHX"),
                       levels = c("Carried in on a late plane", "Created at PHX")))
save_deck(ggplot(d, aes(sched_hour, value, fill = name)) + geom_col(width = 0.78) +
  scale_fill_manual(values = c("Carried in on a late plane" = SAND, "Created at PHX" = NAVY)) +
  scale_x_continuous(breaks = seq(5, 23, 2), labels = hours_lab) +
  labs(x = "Scheduled departure", y = "Minutes late per flight") + theme_deck(), "inherited")

# 2. Gate delay by hour, peak highlighted
d <- tb("act1_gate_by_hour") |> filter(sched_hour >= 5)
pk <- d$sched_hour[which.max(d$mean_dep_delay)]
save_deck(ggplot(d, aes(sched_hour, mean_dep_delay, fill = sched_hour == pk)) + geom_col(width = 0.78, show.legend = FALSE) +
  geom_text(aes(label = round(mean_dep_delay)), vjust = -0.5, size = 4.2, family = "Segoe", color = INK) +
  scale_fill_manual(values = c(`TRUE` = GOLD, `FALSE` = NAVY)) +
  scale_x_continuous(breaks = seq(5, 23, 2), labels = hours_lab) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = "Scheduled departure", y = "Minutes late per flight") + theme_deck(), "gate")

# 3. Taxi queue by pushback hour, morning bank shaded
d <- tb("act1_taxi_by_hour") |> filter(hour >= 5)
save_deck(ggplot(d, aes(hour, faa_taxi_out_delay)) +
  annotate("rect", xmin = 6.5, xmax = 11.5, ymin = -Inf, ymax = Inf, fill = GOLD, alpha = 0.16) +
  annotate("text", x = 9, y = max(d$faa_taxi_out_delay) * 1.12, label = "7 to 11 AM bank", family = "Segoe", color = "#9A6A1E", size = 4.6, fontface = "bold") +
  geom_area(fill = NAVY, alpha = 0.10) + geom_line(color = NAVY, linewidth = 1.4) + geom_point(color = NAVY, size = 2.2) +
  scale_x_continuous(breaks = seq(5, 23, 2), labels = hours_lab) +
  scale_y_continuous(limits = c(0, max(d$faa_taxi_out_delay) * 1.2), expand = expansion(mult = c(0, 0))) +
  labs(x = "Pushback hour", y = "Extra taxi minutes per flight") + theme_deck(), "taxi")

# 4. FAA delays by month and cause
d <- tb("act1_airfield_by_month") |> select(month, Volume, Weather, Runway, Other, Equipment) |>
  mutate(Other = Other + Equipment) |> select(-Equipment) |> pivot_longer(-month) |>
  mutate(name = factor(name, levels = c("Other", "Runway", "Weather", "Volume")))
save_deck(ggplot(d, aes(as.Date(month), value, fill = name)) + geom_col(width = 24) +
  scale_fill_manual(values = c(Volume = NAVY, Weather = STEEL, Runway = GOLD, Other = SAND), breaks = c("Volume", "Weather", "Runway", "Other")) +
  scale_x_date(date_breaks = "3 months", date_labels = "%b '%y") +
  labs(x = NULL, y = "FAA delays per month") + theme_deck(), "airfield")

# 5. Weather effects (110 F heat, storms) on each stage
d <- tb("act1_weather_models") |> filter(heat_def == "heat_110") |>
  mutate(stage = recode(outcome, phx_originated = "Gate delay at PHX", inherited = "Late inbound", taxi_faa = "Taxi queue"),
         term = if_else(term == "heat", "110 F hour", "Storm hour"))
save_deck(ggplot(d, aes(estimate, factor(stage, levels = rev(c("Gate delay at PHX", "Late inbound", "Taxi queue"))), color = term)) +
  geom_vline(xintercept = 0, color = SAND) +
  geom_pointrange(aes(xmin = lo95, xmax = hi95), position = position_dodge(width = 0.55), size = 0.7, linewidth = 1) +
  scale_color_manual(values = c(`110 F hour` = GOLD, `Storm hour` = NAVY)) +
  labs(x = "Extra minutes per flight vs a normal hour", y = NULL) + theme_deck() +
  theme(panel.grid.major.x = element_line(color = "#ECE9E3"), panel.grid.major.y = element_blank()), "weather", h = 4.2)

# 6. Stage ranking: minutes and dollars
d <- tb("act1_stage_ranking") |>
  mutate(stage = recode(stage, `Created at PHX (gate)` = "Gate delay created at PHX", `Excess taxi-out` = "Extra taxi-out time",
                        `Inherited from late inbound` = "Delay carried in on late planes"),
         stage = factor(stage, levels = rev(stage)))
save_deck(ggplot(d, aes(minutes_per_year / 1e6, stage, fill = stage == "Gate delay created at PHX")) +
  geom_col(width = 0.6, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.2fM min  ·  %s / yr", minutes_per_year / 1e6, fmt_usd(total_usd_base))),
            hjust = -0.04, size = 4.6, family = "Segoe", color = INK) +
  scale_fill_manual(values = c(`TRUE` = NAVY, `FALSE` = SAND)) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.55))) +
  labs(x = "Million minutes per year", y = NULL) + theme_deck() +
  theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(size = 14)), "stages", h = 3.6)

# 7. Growth: added minutes by stage
d <- tb("act2_scenarios") |> filter(day_type == "All days") |>
  mutate(stage = recode(stage, `Created at PHX (gate)` = "Gate delay at PHX", `Excess taxi-out` = "Taxi queue",
                        `Inherited from late inbound` = "Late inbound"))
cols <- c(`Taxi queue` = GOLD, `Gate delay at PHX` = NAVY, `Late inbound` = SAND)
save_deck(ggplot(d, aes(growth_pct, increase_min / 1000, color = stage, fill = stage)) +
  geom_ribbon(aes(ymin = increase_lo / 1000, ymax = increase_hi / 1000), alpha = 0.18, color = NA) +
  geom_line(linewidth = 1.5) + geom_point(size = 2.6) +
  scale_color_manual(values = cols) + scale_fill_manual(values = cols) +
  scale_x_continuous(breaks = c(0, 5, 10, 15, 20), labels = function(x) paste0("+", x, "%")) +
  labs(x = "Traffic growth", y = "Added thousand minutes / yr") + theme_deck(), "growth")

# 8. Checkpoint passengers vs departures by hour
d <- tb("act1_tsa_by_hour") |> filter(hour >= 3) |>
  select(hour, `Passengers screened` = passenger_share_pct, `Departures` = departure_share_pct) |> pivot_longer(-hour)
save_deck(ggplot(d, aes(hour, value, color = name)) + geom_line(linewidth = 1.5) + geom_point(size = 2.2) +
  scale_color_manual(values = c(`Passengers screened` = GOLD, Departures = NAVY)) +
  scale_x_continuous(breaks = seq(3, 23, 2), labels = hours_lab) +
  labs(x = NULL, y = "Share of the day (%)") + theme_deck(), "tsa")

message("wrote deck charts")
