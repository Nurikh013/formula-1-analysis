# Use UTF-8 on Windows for names in the source CSV files.
if (.Platform$OS.type == "windows") {
  invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
}
# Formula 1 exploratory analysis, 1950-2024.
# Run from the project root: Rscript F1_script.R
# Optional first argument: folder containing the required CSV files.
required_packages <- c("igraph", "dplyr", "ggplot2", "maps")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace,
                                             logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop("Missing R packages: ", paste(missing_packages, collapse = ", "),
       ". Run Rscript setup.R first.", call. = FALSE)
}
if (packageVersion("dplyr") < "1.1.0" || packageVersion("ggplot2") < "3.4.0") {
  stop("Requires dplyr >= 1.1.0 and ggplot2 >= 3.4.0.", call. = FALSE)
}
suppressPackageStartupMessages({
  library(igraph)
  library(dplyr)
  library(ggplot2)
  library(maps)
})

args <- commandArgs(trailingOnly = TRUE)
data_dir <- if (length(args)) args[[1]] else "datasets"
output_dir <- "outputs"
image_dir <- file.path(output_dir, "images")
inputs <- c("drivers", "results", "races", "circuits", "constructors",
            "status", "qualifying", "pit_stops")
missing_files <- file.path(data_dir, paste0(inputs, ".csv"))
missing_files <- missing_files[!file.exists(missing_files)]
if (length(missing_files)) {
  stop("Missing input files:\n", paste(missing_files, collapse = "\n"),
       "\nSee datasets/README.md for the required files.", call. = FALSE)
}
dir.create(image_dir, recursive = TRUE, showWarnings = FALSE)
for (input in inputs) {
  assign(input, read.csv(file.path(data_dir, paste0(input, ".csv")),
                        na.strings = "\\N", stringsAsFactors = FALSE, fileEncoding = "UTF-8"))
}
# Use IDs for all joins, grouping and graph vertices, never shared surnames.
drivers$driver_key <- as.character(drivers$driverId)
driver_labels <- setNames(paste(drivers$forename, drivers$surname), drivers$driver_key)

# Keep the study period consistent with the presentation and chart titles.
races <- races %>% filter(year >= 1950, year <= 2024)
results <- results %>% semi_join(races, by = "raceId")

#2. Enrich results with driver / race / circuit info 

ds_f1 <- results %>%
  left_join(drivers      %>% select(driverId, driver_key, nationality),
            by = "driverId") %>%
  left_join(races        %>% select(raceId, year, circuitId, name),
            by = "raceId") %>%
  left_join(circuits     %>% select(circuitId, country, lat, lng),
            by = "circuitId") %>%
  left_join(constructors %>% select(constructorId, constructor_name = name,
                                    constructor_nationality = nationality),
            by = "constructorId") %>%
  left_join(status       %>% select(statusId, status),
            by = "statusId")

#View(ds_f1)

# 3. Unique drivers
all_drivers <- unique(ds_f1$driver_key)

# 4. Build Edges.csv - teammate pairings
# Two drivers are linked if they raced for the same constructor in the same race.
teammate_rows <- ds_f1 %>%
  distinct(raceId, constructorId, driver_key)
unique_edges <- teammate_rows %>%
  inner_join(teammate_rows, by = c("raceId", "constructorId"),
             relationship = "many-to-many") %>%
  filter(driver_key.x < driver_key.y) %>%
  transmute(Source = driver_key.x, Target = driver_key.y) %>%
  distinct()

write.csv(unique_edges, "outputs/F1_Edges.csv", row.names = FALSE)

#  5. Count edge appearances per driver
driver_appearances <- bind_rows(
  unique_edges %>% select(driver_key = Source),
  unique_edges %>% select(driver_key = Target)
) %>%
  count(driver_key, name = "Appearances")

# -- 6. Join nationality ---------------------------------------
nationality_lookup <- drivers %>%
  select(driver_key, nationality) %>%
  distinct(driver_key, .keep_all = TRUE)

all_drivers_df <- driver_appearances %>%
  left_join(nationality_lookup, by = "driver_key") %>%
  mutate(nationality = ifelse(is.na(nationality), "No Data", nationality)) %>%
  rename(Id = driver_key, Nationality = nationality)
all_drivers_df$Label <- unname(driver_labels[as.character(all_drivers_df$Id)])

# -- 7. Build Nodes.csv ----------------------------------------
write.csv(all_drivers_df, "outputs/F1_Nodes.csv", row.names = FALSE)

# 8. Bar chart: driver appearances by nationality
filtered_df <- all_drivers_df %>%
  slice_max(Appearances, n = 30, with_ties = FALSE) %>%
  arrange(desc(Appearances))

plot_current <- ggplot(filtered_df, aes(x = reorder(Id, -Appearances),
                        y = Appearances,
                        fill = Nationality)) +
  geom_bar(stat = "identity") +
  scale_x_discrete(labels = driver_labels) +
  theme_minimal() +
  labs(
    title = "Distinct Teammates per Driver (Top 30) (F1 1950-2024)",
    x     = "Driver",
    y     = "Distinct teammates"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(filename = file.path(image_dir, "f1_barchart.png"),
       width = 10, height = 6, dpi = 300, bg = "white")

# -- 9. DNF-status category popularity by year -----------------
#
#   "Finished"    to  race completed
#   "Mechanical"  to  engine, gearbox, hydraulics, etc.
#   "Accident"    to  collision, spun off
#   "Lapped"      to  finished but lapped
#   "Other"       to  everything else

ds_f1 <- ds_f1 %>%
  mutate(status_cat = case_when(
    status == "Finished"                           ~ "Finished",
    status %in% c("Accident", "Collision",
                  "Spun off",
                  "Fatal accident")               ~ "Accident",
    status %in% c("Engine", "Gearbox", "Hydraulics",
                  "Transmission", "Clutch",
                  "Suspension", "Brakes",
                  "Throttle", "Turbo",
                  "Power Unit", "ERS",
                  "Electrical", "Fuel system",
                  "Oil pressure", "Water leak",
                  "Overheating")                  ~ "Mechanical",
    grepl("^\\+", status)                          ~ "Lapped",
    TRUE                                           ~ "Other"
  ))

status_year_counts <- ds_f1 %>%
  group_by(year, status_cat) %>%
  summarise(count = n(), .groups = "drop")

# Most common status per year
most_popular_status <- status_year_counts %>%
  group_by(year) %>%
  filter(count == max(count)) %>%
  ungroup()

plot_current <- ggplot(most_popular_status,
       aes(x = as.factor(year), y = count, fill = status_cat)) +
  geom_bar(stat = "identity") +
  scale_fill_manual(values = c(
    "Finished"   = "#2ecc71",
    "Mechanical" = "#e67e22",
    "Accident"   = "#e74c3c",
    "Lapped"     = "#3498db",
    "Other"      = "#95a5a6"
  )) +
  labs(
    title = "Most Common Race Outcome Category per Year (F1 1950-2024)",
    x     = "Year", y     = "Count", fill  = "Status"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 6))

ggsave(filename = file.path(image_dir, "F1_Status_Popularity.png"),
       width = 10, height = 6, dpi = 300, bg = "white")

# 10. World map: race wins by driver nationality 
wins_by_nationality <- ds_f1 %>%
  filter(positionOrder == 1) %>%
  group_by(nationality) %>%
  summarise(Wins = n()) %>%
  rename(region = nationality) %>%
  mutate(region = recode(region,
                         "British"    = "UK",
                         "American"   = "USA",
                         "Brazilian"  = "Brazil",
                         "German"     = "Germany",
                         "French"     = "France",
                         "Italian"    = "Italy",
                         "Finnish"    = "Finland",
                         "Austrian"   = "Austria",
                         "Australian" = "Australia",
                         "Spanish"    = "Spain",
                         "Dutch"      = "Netherlands",
                         "Canadian"   = "Canada",
                         "Argentine"  = "Argentina",
                         "South African" = "South Africa",
                         "New Zealander" = "New Zealand",
                         "Belgian"    = "Belgium",
                         "Swiss"      = "Switzerland",
                         "Mexican"    = "Mexico",
                         "Colombian"  = "Colombia",
                         "Monegasque" = "Monaco",
                         "Hungarian"  = "Hungary",
                         "Japanese"   = "Japan"
  ))

world_map <- map_data("world")
world_map <- left_join(world_map, wins_by_nationality, by = "region")

plot_current <- ggplot(data = world_map,
       aes(x = long, y = lat, group = group, fill = Wins)) +
  geom_polygon(color = "black", linewidth = 0.15) +
  scale_fill_continuous(
    na.value = "grey90",
    low      = "#ffe0b2",
    high     = "#bf360c"
  ) +
  theme_void() +
  labs(
    title = "F1 Race Wins by Driver Nationality (1950-2024)",
    fill  = "Wins"
  )

ggsave(filename = file.path(image_dir, "F1_Wins_Map.png"),
       width = 10, height = 7, dpi = 300, bg = "white")

# 11. Grid  to  Finish position heatmap by circuit type
#
#   We classify circuits by country continent as a proxy for "type"
#   Alternatively classify by known street vs. permanent circuits.
#
# Optional mapping: circuitId,circuit_type (Street or Permanent).
# A country is not a valid proxy for circuit type. Missing mappings are omitted.
type_file <- file.path(data_dir, "circuit_types.csv")
has_circuit_types <- file.exists(type_file)
if (has_circuit_types) {
  circuit_types_map <- read.csv(type_file, stringsAsFactors = FALSE)
  stopifnot(all(c("circuitId", "circuit_type") %in% names(circuit_types_map)),
            !anyDuplicated(circuit_types_map$circuitId),
            all(circuit_types_map$circuit_type %in% c("Street", "Permanent")))
  ds_f1 <- ds_f1 %>% left_join(circuit_types_map, by = "circuitId")
} else {
  message("Skipping circuit-type heatmaps: no reviewed circuit_types.csv mapping.")
}

# Heatmap function: grid (x) vs finish (y) position frequency
plot_position_heatmap <- function(data, title_suffix) {
  heat_data <- data %>%
    filter(!is.na(grid), !is.na(positionOrder),
           grid > 0, positionOrder <= 20, grid <= 20) %>%
    count(grid, positionOrder)
  
  ggplot(heat_data, aes(x = grid, y = positionOrder, fill = n)) +
    geom_tile(color = "white", linewidth = 0.4) +
    geom_text(aes(label = ifelse(n > 0, n, "")),
              color = "white", size = 2.5) +
    scale_fill_gradientn(
      colors = c("#0d0221", "#3b0764", "#c77dff", "#f9c74f")
    ) +
    scale_x_continuous(breaks = 1:20) +
    scale_y_continuous(breaks = 1:20) +
    coord_fixed() +
    labs(
      title = paste("Grid  to  Finish Position Heatmap -", title_suffix),
      x     = "Grid Position (Start)",
      y     = "Finishing Position",
      fill  = "Count"
    ) +
    theme_minimal(base_size = 11)
}

# Generate heatmaps per circuit type
circuit_types <- list(
  list(label = "Street Circuits",    filter_val = "Street"),
  list(label = "Permanent Circuits", filter_val = "Permanent")
)

if (has_circuit_types) for (ct in circuit_types) {
  subset_data <- ds_f1 %>% filter(circuit_type == ct$filter_val)
  p <- plot_position_heatmap(subset_data, ct$label)
  file_name <- paste0("Heatmap_", gsub(" ", "_", ct$label), ".png")
  ggsave(filename = file.path(image_dir, file_name),
         plot = p, width = 9, height = 8, dpi = 300, bg = "white")
}

# Eras: Turbo 1 (1977-1988), NA (1989-2005), V8 (2006-2013),
#       Hybrid (2014-2021), Modern (2022-2024)
ds_f1 <- ds_f1 %>%
  mutate(era = case_when(
    year < 1977               ~ "Pre-Turbo (1950-1976)",
    year <= 1988              ~ "Turbo Era (1977-1988)",
    year <= 2005              ~ "V10/V12 Era (1989-2005)",
    year <= 2013              ~ "V8 Era (2006-2013)",
    year <= 2021              ~ "Hybrid Era (2014-2021)",
    TRUE                      ~ "Ground Effect (2022-2024)"
  ))

eras <- unique(ds_f1$era)

for (era_name in eras) {
  subset_data <- ds_f1 %>% filter(era == era_name)
  p <- plot_position_heatmap(subset_data, era_name)
  file_name <- paste0("Heatmap_", gsub("[^A-Za-z0-9]", "_", era_name), ".png")
  ggsave(filename = file.path(image_dir, file_name),
         plot = p, width = 9, height = 8, dpi = 300, bg = "white")
}

# -- 12. Pie chart: race outcome distribution ------------------
result_counts <- ds_f1 %>%
  count(status_cat) %>%
  filter(status_cat != "Other")

plot_current <- ggplot(result_counts, aes(x = "", y = n, fill = status_cat)) +
  geom_bar(width = 1, stat = "identity") +
  coord_polar("y", start = 0) +
  scale_fill_manual(values = c(
    "Finished"   = "#2ecc71",
    "Mechanical" = "#e67e22",
    "Accident"   = "#e74c3c",
    "Lapped"     = "#3498db"
  )) +
  labs(
    title = "Distribution of Race Outcomes (F1 1950-2024)",
    x = "", y = "", fill = "Outcome"
  ) +
  theme_void()

ggsave(filename = file.path(image_dir, "F1_Race_Result_Distribution.png"),
       width = 8, height = 6, dpi = 300, bg = "white")

# 13. Teammate network
edges_net <- read.csv("outputs/F1_Edges.csv")
nodes_net  <- read.csv("outputs/F1_Nodes.csv")

g <- graph_from_data_frame(edges_net, directed = FALSE, vertices = nodes_net)

# Display only nodes with at least 15 distinct neighbours.
# This is a visualization filter, not an Indy-500 or active-driver filter.
deg        <- degree(g)
g_filtered <- induced_subgraph(g, vids = V(g)[deg >= 15])

# Map nationalities to colors.
nat_palette <- c(
  "British"    = "#003087",
  "German"     = "#CC0000",
  "Brazilian"  = "#009C3B",
  "French"     = "#0055A4",
  "Finnish"    = "#003580",
  "Austrian"   = "#ED2939",
  "Australian" = "#FFCD00",
  "Italian"    = "#008C45",
  "American"   = "#B22234",
  "Dutch"      = "#FF6600",
  "Spanish"    = "#F1BF00",
  "No Data"    = "#AAAAAA"
)

node_nat    <- V(g_filtered)$Nationality
node_colors <- ifelse(node_nat %in% names(nat_palette),
                      nat_palette[node_nat], "#AAAAAA")

# Node size follows the number of distinct teammates.
node_sizes <- log1p(degree(g_filtered)) * 3.5

# Use a fixed seed for a reproducible layout.
set.seed(42)
layout_coords <- layout_with_fr(g_filtered, niter = 1000)

# Draw and export the network.
png(file.path(image_dir, "F1_Teammate_Network.png"), width = 1600, height = 1100, res = 140)
par(bg = "#F8F8F8", mar = c(2, 2, 4, 2))
plot(
  g_filtered,
  layout             = layout_coords,
  vertex.color       = node_colors,
  vertex.frame.color = "white",
  vertex.size        = node_sizes,
  vertex.label       = NA,
  vertex.label.cex   = 0.55,
  vertex.label.color = "black",
  vertex.label.family= "sans",
  edge.color         = adjustcolor("#999999", alpha.f = 0.3),
  edge.width         = 0.4,
  main               = ""
)

# Network title
title(
  main = "F1 Teammate Network (1950-2024)",
  sub  = "Degree >= 15 shown | Color = nationality | Size = displayed graph degree",
  cex.main = 1.5, font.main = 2,
  cex.sub  = 0.85, col.sub  = "#555555"
)

# Nationality legend
present_nats <- unique(node_nat[node_nat %in% names(nat_palette)])
legend(
  "bottomleft",
  legend = present_nats,
  fill   = nat_palette[present_nats],
  border = "white",
  bty    = "n",
  cex    = 0.7,
  title  = "Nationality"
)

dev.off()

# 14. Pit stop strategy: average stop duration by constructor 
# (bonus: only available from 2011 onward in the dataset)
pit_analysis <- pit_stops %>%
  left_join(results %>% select(raceId, driverId, constructorId),
            by = c("raceId", "driverId")) %>%
  left_join(constructors %>% select(constructorId, name),
            by = "constructorId") %>%
  left_join(races %>% select(raceId, year), by = "raceId") %>%
  filter(!is.na(milliseconds), milliseconds < 120000) %>%  # remove outliers
  mutate(duration_sec = milliseconds / 1000)

top_constructors <- pit_analysis %>%
  count(name) %>%
  arrange(desc(n)) %>%
  slice_head(n = 12) %>%
  pull(name)

pit_summary <- pit_analysis %>%
  filter(name %in% top_constructors) %>%
  group_by(name) %>%
  summarise(
    avg_pit = mean(duration_sec, na.rm = TRUE),
    sd_pit  = sd(duration_sec,  na.rm = TRUE),
    n       = n()
  ) %>%
  arrange(avg_pit)

plot_current <- ggplot(pit_summary, aes(x = reorder(name, avg_pit), y = avg_pit,
                        fill = avg_pit)) +
  geom_bar(stat = "identity") +
  geom_errorbar(aes(ymin = avg_pit - sd_pit,
                    ymax = avg_pit + sd_pit), width = 0.3) +
  scale_fill_gradient(low = "#1a237e", high = "#e53935") +
  coord_flip() +
  labs(
    title = "Average Pit Stop Duration by Constructor (2011-2024)",
    x     = "Constructor",
    y     = "Avg Duration (seconds)",
    fill  = "Avg (s)"
  ) +
  theme_minimal()

ggsave(filename = file.path(image_dir, "F1_PitStop_Duration.png"),
       width = 9, height = 6, dpi = 300, bg = "white")

#  15. Qualifying improvement: Q1  to  Q3 lap time delta 
# Convert lap time string "1:23.456"  to  seconds
parse_laptime <- function(t) {
  t <- as.character(t)
  t[t %in% c("\\N", "", NA)] <- NA
  sapply(t, function(x) {
    if (is.na(x)) return(NA)
    parts <- strsplit(x, ":")[[1]]
    if (length(parts) == 2) as.numeric(parts[1]) * 60 + as.numeric(parts[2])
    else as.numeric(x)
  })
}

qual_clean <- qualifying %>%
  mutate(
    q1_sec = parse_laptime(q1),
    q2_sec = parse_laptime(q2),
    q3_sec = parse_laptime(q3)
  ) %>%
  filter(!is.na(q1_sec), !is.na(q3_sec)) %>%
  mutate(improvement = q1_sec - q3_sec) %>%       # positive = faster in Q3
  left_join(races %>% select(raceId, year), by = "raceId") %>%
  left_join(drivers %>% select(driverId, driver_key), by = "driverId")

qual_by_year <- qual_clean %>%
  group_by(year) %>%
  summarise(avg_improvement = mean(improvement, na.rm = TRUE),
            .groups = "drop")

plot_current <- ggplot(qual_by_year, aes(x = year, y = avg_improvement)) +
  geom_line(color = "#c62828", linewidth = 1.1) +
  geom_point(color = "#1565c0", size = 2) +
  geom_smooth(method = "loess", se = TRUE,
              color = "orange", fill = "#ffe0b2", alpha = 0.3) +
  labs(
    title = "Average Q1 to Q3 Lap Time Improvement per Year",
    subtitle = "Positive = driver was faster in Q3 than Q1",
    x = "Year", y = "Improvement (seconds)"
  ) +
  theme_minimal()

ggsave(filename = file.path(image_dir, "F1_Qualifying_Improvement.png"),
       width = 9, height = 6, dpi = 300, bg = "white")

#  16. Mode result per year (dominant outcome)
calculate_mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

mode_status_per_year <- ds_f1 %>%
  filter(!is.na(status_cat)) %>%
  group_by(year) %>%
  summarise(mode_status = calculate_mode(status_cat), .groups = "drop")

plot_current <- ggplot(mode_status_per_year,
       aes(x = year, y = mode_status, color = mode_status, group = 1)) +
  geom_point(size = 3) +
  geom_line(color = "grey70", linewidth = 0.6) +
  scale_color_manual(values = c(
    "Finished"   = "#2ecc71",
    "Mechanical" = "#e67e22",
    "Accident" = "#e74c3c",
    "Other" = "#95a5a6",
    "Lapped"     = "#3498db"
  )) +
  labs(
    title = "Most Common Race Outcome per Year",
    x     = "Year", y     = "Dominant Status",
    color = "Status"
  ) +
  theme_minimal()

ggsave(filename = file.path(image_dir, "F1_Mode_Result_Trend.png"),
       width = 9, height = 5, dpi = 300, bg = "white")


# 17. Wins for the top 10 drivers across the top 15 circuits
# Compare wins by driver and circuit.
circuit_data <- results %>%
  left_join(races    %>% select(raceId, year, circuitId),
            by = "raceId") %>%
  left_join(circuits %>% select(circuitId, circuit_name = name),
            by = "circuitId") %>%
  left_join(drivers  %>% select(driverId, driver_key),
            by = "driverId")

top10_drivers <- circuit_data %>%
  filter(positionOrder == 1) %>%
  count(driver_key) %>%
  arrange(desc(n)) %>%
  slice_head(n = 10) %>%
  pull(driver_key)

top15_circuits <- circuit_data %>%
  filter(positionOrder == 1) %>%
  count(circuit_name) %>%
  arrange(desc(n)) %>%
  slice_head(n = 15) %>%
  pull(circuit_name)

heatmap_data <- circuit_data %>%
  filter(positionOrder == 1,
         driver_key      %in% top10_drivers,
         circuit_name %in% top15_circuits) %>%
  count(driver_key, circuit_name)

plot_current <- ggplot(heatmap_data,
       aes(x = circuit_name, y = driver_key, fill = n)) +
  scale_y_discrete(labels = driver_labels) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = n), size = 3.2, color = "white", fontface = "bold") +
  scale_fill_gradientn(
    colors = c("#1a237e", "#1565c0", "#f57f17", "#f9a825")
  ) +
  labs(
    title    = "Wins: Top 10 Drivers x Top 15 Circuits",
    subtitle = "Color and number = total wins at that circuit",
    x        = "Circuit",
    y        = "Driver",
    fill     = "Wins"
  ) +
  theme_minimal() +
  theme(
    axis.text.x  = element_text(angle = 40, hjust = 1, size = 9),
    axis.text.y  = element_text(size = 10),
    plot.title   = element_text(size = 13, face = "bold"),
    plot.subtitle = element_text(size = 10, color = "grey50")
  )

ggsave("outputs/images/F1_Driver_Circuit_Heatmap.png",
       width = 13, height = 7, dpi = 300, bg = "white")

#  18. Pole  to  Win conversion by circuit 
# Build fresh from results to avoid column conflicts
pole_win_raw <- results %>%
  mutate(grid_int = suppressWarnings(as.integer(as.character(grid)))) %>%
  left_join(races    %>% select(raceId, circuitId), by = "raceId") %>%
  left_join(circuits %>% select(circuitId, circuit_name = name), by = "circuitId") %>%
  filter(!is.na(grid_int), grid_int > 0, !is.na(positionOrder))

pole_win <- pole_win_raw %>%
  group_by(circuit_name) %>%
  summarise(
    total_races = n_distinct(raceId),
    pole_wins   = sum(grid_int == 1 & positionOrder == 1, na.rm = TRUE),
    conversion  = round(pole_wins / total_races * 100, 1),
    .groups     = "drop"
  ) %>%
  filter(total_races >= 10) %>%
  arrange(desc(conversion)) %>%
  slice_head(n = 20)

plot_current <- ggplot(pole_win,
       aes(x = reorder(circuit_name, conversion),
           y = conversion,
           fill = conversion)) +
  geom_bar(stat = "identity") +
  geom_text(aes(label = paste0(conversion, "%")),
            hjust = -0.15, size = 3.2) +
  scale_fill_gradient(low = "#e8f5e9", high = "#1b5e20") +
  coord_flip() +
  labs(
    title    = "Pole Position  to  Race Win Conversion by Circuit",
    subtitle = "Top 20 circuits with 10+ races - how often pole leads to victory",
    x        = NULL,
    y        = "Pole  to  Win %",
    fill     = "%"
  ) +
  theme_minimal() +
  theme(
    legend.position = "none",
    plot.title      = element_text(size = 13, face = "bold"),
    plot.subtitle   = element_text(size = 10, color = "grey50")
  )

ggsave("outputs/images/F1_Pole_Win_Conversion.png",
       width = 10, height = 7, dpi = 300, bg = "white")

writeLines(capture.output(sessionInfo()), file.path(output_dir, "session-info.txt"))
