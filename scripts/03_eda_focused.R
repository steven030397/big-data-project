# =============================================================================
# Focused Exploratory Data Analysis
# =============================================================================
# Research Question: How crash frequency, severity, and type vary by:
#   - Time of day, day of week, season
#   - Urban vs rural areas in Victoria
# =============================================================================

source(here::here("scripts", "00_setup.R"))

cat("\n=== Focused EDA: Crash Patterns by Time and Location ===\n\n")

# ---- Load and Join Required Data ----
cat("Loading and joining data...\n")

# Load required tables
accident <- readRDS(here(data_processed, "accident_cleaned.rds"))
node <- readRDS(here(data_processed, "node_cleaned.rds"))
person <- readRDS(here(data_processed, "person_cleaned.rds"))
atmospheric <- readRDS(here(data_processed, "atmospheric_cond_cleaned.rds"))
road_surface <- readRDS(here(data_processed, "road_surface_cond_cleaned.rds"))

cat("  Loaded accident table:", nrow(accident), "rows\n")
cat("  Loaded node table:", nrow(node), "rows\n")
cat("  Loaded person table:", nrow(person), "rows\n")

# Join data
cat("\nJoining tables...\n")

# Handle many-to-many relationships by aggregating first
# Some accidents may have multiple atmospheric/road surface conditions
cat("  Aggregating atmospheric conditions...\n")
atmospheric_agg <- atmospheric %>%
  group_by(accident_no) %>%
  summarise(
    atmosph_cond_desc = first(atmosph_cond_desc),  # Take first if multiple
    .groups = "drop"
  )

cat("  Aggregating road surface conditions...\n")
road_surface_agg <- road_surface %>%
  group_by(accident_no) %>%
  summarise(
    surface_cond_desc = first(surface_cond_desc),  # Take first if multiple
    .groups = "drop"
  )

# Handle node join - aggregate by node_id if multiple rows
cat("  Aggregating node data...\n")
node_agg <- node %>%
  group_by(node_id) %>%
  summarise(
    deg_urban_name = first(deg_urban_name),  # Take first if multiple
    .groups = "drop"
  )

# Aggregate person-level severity to accident level
# Note: inj_level numeric: 1=Fat (most severe), 3=Ser, 4=Not (least severe)
# We want MIN inj_level (lowest number = most severe injury in accident)
# Accident table already has severity, but person-level gives us counts
cat("  Aggregating person-level severity data...\n")
person_agg <- person %>%
  group_by(accident_no) %>%
  summarise(
    # Get most severe injury level (min since lower = more severe)
    min_inj_level = min(inj_level, na.rm = TRUE),
    # Get most severe injury description
    max_severity_desc = case_when(
      any(inj_level == 1, na.rm = TRUE) ~ "Fat",  # Fatal if any
      any(inj_level == 3, na.rm = TRUE) ~ "Ser",  # Serious if any
      TRUE ~ "Not"  # Otherwise not injured
    ),
    total_fatalities = sum(inj_level_desc == "Fat", na.rm = TRUE),
    total_serious_injuries = sum(inj_level_desc == "Ser", na.rm = TRUE),
    .groups = "drop"
  )

# Now join aggregated tables
accident_main <- accident %>%
  # Join with node for urban/rural classification
  left_join(
    node_agg,
    by = "node_id",
    relationship = "many-to-one"
  ) %>%
  # Join atmospheric conditions
  left_join(
    atmospheric_agg,
    by = "accident_no",
    relationship = "one-to-one"
  ) %>%
  # Join road surface conditions
  left_join(
    road_surface_agg,
    by = "accident_no",
    relationship = "one-to-one"
  ) %>%
  # Join person-level severity
  left_join(
    person_agg,
    by = "accident_no",
    relationship = "one-to-one"
  )

cat("  Joined dataset:", nrow(accident_main), "accidents\n")

# ---- Diagnostic: Check deg_urban_name values ----
cat("\n=== Diagnostic: Checking urban/rural classification ===\n")
if ("deg_urban_name" %in% names(accident_main)) {
  deg_urban_summary <- accident_main %>%
    count(deg_urban_name, sort = TRUE)
  cat("\ndeg_urban_name values:\n")
  print(deg_urban_summary)
} else {
  cat("WARNING: deg_urban_name column not found!\n")
}

# Check RMA values as alternative
if ("rma" %in% names(accident_main)) {
  rma_summary <- accident_main %>%
    count(rma, sort = TRUE)
  cat("\nrma values:\n")
  print(rma_summary)
}

# ---- Create Derived Variables ----
cat("\n=== Creating derived variables ===\n")

accident_main <- accident_main %>%
  # Extract hour of day from accident_time
  mutate(
    hour_of_day = as.numeric(accident_time) %/% 3600,
    hour_group = case_when(
      hour_of_day %in% 6:9 ~ "Morning Rush (6-9)",
      hour_of_day %in% 10:14 ~ "Midday (10-14)",
      hour_of_day %in% 15:18 ~ "Afternoon Rush (15-18)",
      hour_of_day %in% 19:22 ~ "Evening (19-22)",
      TRUE ~ "Night/Late Night (23-5)"
    ),
    hour_group = factor(hour_group, levels = c(
      "Morning Rush (6-9)", "Midday (10-14)", "Afternoon Rush (15-18)",
      "Evening (19-22)", "Night/Late Night (23-5)"
    ))
  ) %>%
  # Extract season from accident_date
  mutate(
    month = month(accident_date),
    season = case_when(
      month %in% c(12, 1, 2) ~ "Summer",
      month %in% c(3, 4, 5) ~ "Autumn",
      month %in% c(6, 7, 8) ~ "Winter",
      month %in% c(9, 10, 11) ~ "Spring"
    ),
    season = factor(season, levels = c("Spring", "Summer", "Autumn", "Winter"))
  ) %>%
  # Create binary urban/rural variable
  # Based on actual values: MEL=Urban, RUR=Rural, LAR/SMA=Urban
  mutate(
    area_type = case_when(
      # Use deg_urban_name if available - check exact values first
      !is.na(deg_urban_name) & toupper(trimws(deg_urban_name)) == "RUR" ~ "Rural",
      !is.na(deg_urban_name) & toupper(trimws(deg_urban_name)) %in% c("MEL", "LAR", "SMA", "MED", "REG") ~ "Urban",
      !is.na(deg_urban_name) & toupper(trimws(deg_urban_name)) %in% c("RURAL") ~ "Rural",
      # Fallback to RMA classification if deg_urban_name is NA
      is.na(deg_urban_name) & !is.na(rma) & toupper(trimws(rma)) == "RUR" ~ "Rural",
      is.na(deg_urban_name) & !is.na(rma) & toupper(trimws(rma)) %in% c("ART", "LOC", "FRE") ~ "Urban",
      # If still unknown, check if it contains rural/rur
      !is.na(deg_urban_name) & grepl("RUR|RURAL", toupper(trimws(deg_urban_name))) ~ "Rural",
      !is.na(deg_urban_name) ~ "Urban",  # If deg_urban_name exists but not RUR, assume Urban
      TRUE ~ "Unknown"
    ),
    area_type = factor(area_type, levels = c("Urban", "Rural", "Unknown"))
  ) %>%
  # Ensure day of week is ordered
  mutate(
    day_week_desc = factor(day_week_desc, levels = c(
      "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ))
  )

# Check the classification results
area_type_summary <- accident_main %>%
  count(area_type, sort = TRUE)
cat("\nArea type classification results:\n")
print(area_type_summary)

cat("\n  Created: hour_of_day, hour_group, season, area_type\n")

# Filter out unknown area types for main analysis
accident_analysis <- accident_main %>%
  filter(area_type != "Unknown")

cat("\nAnalysis dataset:", nrow(accident_analysis), "accidents (excluding unknown area type)\n")
cat("  Urban crashes:", sum(accident_analysis$area_type == "Urban"), "\n")
cat("  Rural crashes:", sum(accident_analysis$area_type == "Rural"), "\n")

# ---- Helper Function ----
save_figure <- function(plot, filename, width = 10, height = 6, dpi = 300) {
  ggsave(
    filename = here(figures_dir, filename),
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    bg = "white"
  )
  cat("  Saved:", filename, "\n")
}

# =============================================================================
# 1. CRASH FREQUENCY ANALYSIS
# =============================================================================

cat("\n=== 1. Crash Frequency Analysis ===\n")

# 1.1 Crash frequency by time of day (hourly) - Urban vs Rural
# Ensure both categories are represented even if one has zero values
p1_1_data <- accident_analysis %>%
  filter(!is.na(area_type), area_type != "Unknown") %>%
  mutate(area_type = factor(area_type, levels = c("Urban", "Rural")))

# Check if we have both categories
cat("  Urban crashes:", sum(p1_1_data$area_type == "Urban", na.rm = TRUE), "\n")
cat("  Rural crashes:", sum(p1_1_data$area_type == "Rural", na.rm = TRUE), "\n")

p1_1 <- p1_1_data %>%
  ggplot(aes(x = hour_of_day, fill = area_type)) +
  geom_histogram(binwidth = 1, alpha = 0.7, position = "identity") +
  facet_wrap(~ area_type, ncol = 1, scales = "free_y") +
  scale_fill_manual(values = c("Urban" = "#2E86AB", "Rural" = "#A23B72"), 
                    drop = FALSE) +
  labs(
    title = "Crash Frequency by Hour of Day",
    subtitle = "Comparing Urban and Rural Areas",
    x = "Hour of Day",
    y = "Number of Crashes",
    fill = "Area Type"
  ) +
  theme(legend.position = "bottom")
save_figure(p1_1, "01_frequency_by_hour_urban_rural.png", width = 12, height = 8)

# 1.2 Crash frequency by time group - Urban vs Rural
p1_2 <- accident_analysis %>%
  filter(!is.na(area_type), area_type != "Unknown") %>%
  mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
  count(hour_group, area_type) %>%
  complete(hour_group, area_type, fill = list(n = 0)) %>%  # Ensure all combinations exist
  ggplot(aes(x = hour_group, y = n, fill = area_type)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Urban" = "#2E86AB", "Rural" = "#A23B72"), 
                    drop = FALSE) +
  labs(
    title = "Crash Frequency by Time Period",
    subtitle = "Comparing Urban and Rural Areas",
    x = "Time Period",
    y = "Number of Crashes",
    fill = "Area Type"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")
save_figure(p1_2, "01_frequency_by_time_group_urban_rural.png", width = 12, height = 6)

# 1.3 Crash frequency by day of week - Urban vs Rural
p1_3 <- accident_analysis %>%
  filter(!is.na(area_type), area_type != "Unknown") %>%
  mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
  count(day_week_desc, area_type) %>%
  complete(day_week_desc, area_type, fill = list(n = 0)) %>%  # Ensure all combinations exist
  ggplot(aes(x = day_week_desc, y = n, fill = area_type)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Urban" = "#2E86AB", "Rural" = "#A23B72"), 
                    drop = FALSE) +
  labs(
    title = "Crash Frequency by Day of Week",
    subtitle = "Comparing Urban and Rural Areas",
    x = "Day of Week",
    y = "Number of Crashes",
    fill = "Area Type"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")
save_figure(p1_3, "01_frequency_by_day_week_urban_rural.png", width = 10, height = 6)

# 1.4 Crash frequency by season - Urban vs Rural
p1_4 <- accident_analysis %>%
  filter(!is.na(area_type), area_type != "Unknown") %>%
  mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
  count(season, area_type) %>%
  complete(season, area_type, fill = list(n = 0)) %>%  # Ensure all combinations exist
  ggplot(aes(x = season, y = n, fill = area_type)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Urban" = "#2E86AB", "Rural" = "#A23B72"), 
                    drop = FALSE) +
  labs(
    title = "Crash Frequency by Season",
    subtitle = "Comparing Urban and Rural Areas",
    x = "Season",
    y = "Number of Crashes",
    fill = "Area Type"
  ) +
  theme(legend.position = "bottom")
save_figure(p1_4, "01_frequency_by_season_urban_rural.png", width = 10, height = 6)

# =============================================================================
# 2. CRASH SEVERITY ANALYSIS
# =============================================================================

cat("\n=== 2. Crash Severity Analysis ===\n")

# 2.1 Severity distribution - Urban vs Rural (overall)
p2_1 <- accident_analysis %>%
  filter(!is.na(area_type), area_type != "Unknown") %>%
  mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
  count(severity, area_type) %>%
  complete(severity, area_type, fill = list(n = 0)) %>%
  ggplot(aes(x = severity, y = n, fill = area_type)) +
  geom_col(position = "fill", alpha = 0.8) +
  scale_fill_manual(values = c("Urban" = "#2E86AB", "Rural" = "#A23B72"), 
                    drop = FALSE) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Crash Severity Distribution",
    subtitle = "Comparing Urban and Rural Areas",
    x = "Severity Level",
    y = "Proportion",
    fill = "Area Type"
  ) +
  theme(legend.position = "bottom")
save_figure(p2_1, "02_severity_distribution_urban_rural.png", width = 10, height = 6)

# 2.2 Severity by time of day - Urban vs Rural
p2_2 <- accident_analysis %>%
  filter(!is.na(area_type), area_type != "Unknown") %>%
  mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
  count(hour_group, severity, area_type) %>%
  complete(hour_group, severity, area_type, fill = list(n = 0)) %>%
  group_by(hour_group, area_type) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  ggplot(aes(x = hour_group, y = prop, fill = severity)) +
  geom_col(position = "fill", alpha = 0.8) +
  facet_wrap(~ area_type, ncol = 2, drop = FALSE) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Crash Severity by Time Period",
    subtitle = "Comparing Urban and Rural Areas",
    x = "Time Period",
    y = "Proportion",
    fill = "Severity"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")
save_figure(p2_2, "02_severity_by_time_group_urban_rural.png", width = 14, height = 6)

# 2.3 Severity by day of week - Urban vs Rural
p2_3 <- accident_analysis %>%
  filter(!is.na(area_type), area_type != "Unknown") %>%
  mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
  count(day_week_desc, severity, area_type) %>%
  complete(day_week_desc, severity, area_type, fill = list(n = 0)) %>%
  group_by(day_week_desc, area_type) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  ggplot(aes(x = day_week_desc, y = prop, fill = severity)) +
  geom_col(position = "fill", alpha = 0.8) +
  facet_wrap(~ area_type, ncol = 2, drop = FALSE) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Crash Severity by Day of Week",
    subtitle = "Comparing Urban and Rural Areas",
    x = "Day of Week",
    y = "Proportion",
    fill = "Severity"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")
save_figure(p2_3, "02_severity_by_day_week_urban_rural.png", width = 14, height = 6)

# 2.4 Severity by season - Urban vs Rural
p2_4 <- accident_analysis %>%
  filter(!is.na(area_type), area_type != "Unknown") %>%
  mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
  count(season, severity, area_type) %>%
  complete(season, severity, area_type, fill = list(n = 0)) %>%
  group_by(season, area_type) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  ggplot(aes(x = season, y = prop, fill = severity)) +
  geom_col(position = "fill", alpha = 0.8) +
  facet_wrap(~ area_type, ncol = 2, drop = FALSE) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Crash Severity by Season",
    subtitle = "Comparing Urban and Rural Areas",
    x = "Season",
    y = "Proportion",
    fill = "Severity"
  ) +
  theme(legend.position = "bottom")
save_figure(p2_4, "02_severity_by_season_urban_rural.png", width = 12, height = 6)

# =============================================================================
# 3. CRASH TYPE ANALYSIS
# =============================================================================

cat("\n=== 3. Crash Type Analysis ===\n")

# 3.1 Crash type distribution - Urban vs Rural
p3_1 <- accident_analysis %>%
  filter(!is.na(area_type), area_type != "Unknown") %>%
  mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
  count(accident_type_desc, area_type) %>%
  group_by(area_type) %>%
  mutate(prop = n / sum(n)) %>%
  ungroup() %>%
  # Get top 10 across both categories combined
  arrange(desc(n)) %>%
  slice_head(n = 10) %>%
  ggplot(aes(x = reorder(accident_type_desc, prop), y = prop, fill = area_type)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Urban" = "#2E86AB", "Rural" = "#A23B72"), 
                    drop = FALSE) +
  scale_y_continuous(labels = scales::percent) +
  coord_flip() +
  labs(
    title = "Top 10 Crash Types by Proportion",
    subtitle = "Comparing Urban and Rural Areas",
    x = "Crash Type",
    y = "Proportion",
    fill = "Area Type"
  ) +
  theme(legend.position = "bottom")
save_figure(p3_1, "03_crash_type_distribution_urban_rural.png", width = 12, height = 8)

# 3.2 Crash type by time period - Urban vs Rural
p3_2 <- accident_analysis %>%
  filter(!is.na(area_type), area_type != "Unknown", !is.na(accident_type_desc)) %>%
  mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
  count(hour_group, accident_type_desc, area_type) %>%
  group_by(hour_group, area_type) %>%
  slice_max(n, n = 5) %>%
  ungroup() %>%
  ggplot(aes(x = hour_group, y = n, fill = accident_type_desc)) +
  geom_col(position = "stack", alpha = 0.8) +
  facet_wrap(~ area_type, ncol = 1, scales = "free_y", drop = FALSE) +
  labs(
    title = "Top 5 Crash Types by Time Period",
    subtitle = "Comparing Urban and Rural Areas",
    x = "Time Period",
    y = "Number of Crashes",
    fill = "Crash Type"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")
save_figure(p3_2, "03_crash_type_by_time_urban_rural.png", width = 14, height = 10)

# =============================================================================
# 4. ENVIRONMENTAL FACTORS
# =============================================================================

cat("\n=== 4. Environmental Factors Analysis ===\n")

# 4.1 Atmospheric conditions by area type
if (any(!is.na(accident_analysis$atmosph_cond_desc))) {
  p4_1 <- accident_analysis %>%
    filter(!is.na(area_type), area_type != "Unknown", !is.na(atmosph_cond_desc)) %>%
    mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
    count(atmosph_cond_desc, area_type) %>%
    complete(atmosph_cond_desc, area_type, fill = list(n = 0)) %>%
    group_by(area_type) %>%
    mutate(prop = n / sum(n)) %>%
    ungroup() %>%
    ggplot(aes(x = reorder(atmosph_cond_desc, n), y = prop, fill = area_type)) +
    geom_col(position = "dodge", alpha = 0.8) +
    scale_fill_manual(values = c("Urban" = "#2E86AB", "Rural" = "#A23B72"), 
                      drop = FALSE) +
    scale_y_continuous(labels = scales::percent) +
    coord_flip() +
    labs(
      title = "Atmospheric Conditions Distribution",
      subtitle = "Comparing Urban and Rural Areas",
      x = "Atmospheric Condition",
      y = "Proportion",
      fill = "Area Type"
    ) +
    theme(legend.position = "bottom")
  save_figure(p4_1, "04_atmospheric_conditions_urban_rural.png", width = 12, height = 8)
}

# 4.2 Road surface conditions by area type
if (any(!is.na(accident_analysis$surface_cond_desc))) {
  p4_2 <- accident_analysis %>%
    filter(!is.na(area_type), area_type != "Unknown", !is.na(surface_cond_desc)) %>%
    mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
    count(surface_cond_desc, area_type) %>%
    complete(surface_cond_desc, area_type, fill = list(n = 0)) %>%
    group_by(area_type) %>%
    mutate(prop = n / sum(n)) %>%
    ungroup() %>%
    ggplot(aes(x = reorder(surface_cond_desc, n), y = prop, fill = area_type)) +
    geom_col(position = "dodge", alpha = 0.8) +
    scale_fill_manual(values = c("Urban" = "#2E86AB", "Rural" = "#A23B72"), 
                      drop = FALSE) +
    scale_y_continuous(labels = scales::percent) +
    coord_flip() +
    labs(
      title = "Road Surface Conditions Distribution",
      subtitle = "Comparing Urban and Rural Areas",
      x = "Surface Condition",
      y = "Proportion",
      fill = "Area Type"
    ) +
    theme(legend.position = "bottom")
  save_figure(p4_2, "04_road_surface_conditions_urban_rural.png", width = 12, height = 8)
}

# 4.3 Severity by atmospheric conditions
if (any(!is.na(accident_analysis$atmosph_cond_desc))) {
  p4_3 <- accident_analysis %>%
    filter(!is.na(area_type), area_type != "Unknown", !is.na(atmosph_cond_desc)) %>%
    mutate(area_type = factor(area_type, levels = c("Urban", "Rural"))) %>%
    count(atmosph_cond_desc, severity, area_type) %>%
    complete(atmosph_cond_desc, severity, area_type, fill = list(n = 0)) %>%
    group_by(atmosph_cond_desc, area_type) %>%
    mutate(prop = n / sum(n)) %>%
    ungroup() %>%
    ggplot(aes(x = reorder(atmosph_cond_desc, n), y = prop, fill = severity)) +
    geom_col(position = "fill", alpha = 0.8) +
    facet_wrap(~ area_type, ncol = 2, drop = FALSE) +
    scale_y_continuous(labels = scales::percent) +
    coord_flip() +
    labs(
      title = "Crash Severity by Atmospheric Conditions",
      subtitle = "Comparing Urban and Rural Areas",
      x = "Atmospheric Condition",
      y = "Proportion",
      fill = "Severity"
    ) +
    theme(legend.position = "bottom")
  save_figure(p4_3, "04_severity_by_atmospheric_urban_rural.png", width = 14, height = 8)
}

# =============================================================================
# 5. SUMMARY TABLES
# =============================================================================

cat("\n=== 5. Creating Summary Tables ===\n")

# 5.1 Summary table: Frequency by time and area
freq_summary <- accident_analysis %>%
  group_by(area_type, hour_group, day_week_desc, season) %>%
  summarise(
    n_crashes = n(),
    fatal_crashes = sum(severity == "1", na.rm = TRUE),
    serious_crashes = sum(severity == "2", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(area_type, hour_group, day_week_desc, season)

write_csv(freq_summary, here(figures_dir, "05_frequency_summary_table.csv"))
cat("  Saved: 05_frequency_summary_table.csv\n")

# 5.2 Summary table: Severity rates
severity_summary <- accident_analysis %>%
  group_by(area_type) %>%
  summarise(
    total_crashes = n(),
    fatal_rate = mean(severity == "1", na.rm = TRUE),
    serious_rate = mean(severity == "2", na.rm = TRUE),
    minor_rate = mean(severity == "3", na.rm = TRUE),
    property_damage_rate = mean(severity == "4", na.rm = TRUE),
    .groups = "drop"
  )

write_csv(severity_summary, here(figures_dir, "05_severity_rates_summary.csv"))
cat("  Saved: 05_severity_rates_summary.csv\n")

# 5.3 Summary table: Crash types
crash_type_summary <- accident_analysis %>%
  group_by(area_type, accident_type_desc) %>%
  summarise(
    n_crashes = n(),
    fatal_crashes = sum(severity == "1", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  group_by(area_type) %>%
  mutate(proportion = n_crashes / sum(n_crashes)) %>%
  arrange(area_type, desc(n_crashes))

write_csv(crash_type_summary, here(figures_dir, "05_crash_type_summary.csv"))
cat("  Saved: 05_crash_type_summary.csv\n")

cat("\n=== Focused EDA Complete ===\n")
cat("All relevant figures and tables saved to:", figures_dir, "\n")
cat("\nFigures generated:\n")
cat("  - Crash frequency by time/day/season (urban vs rural)\n")
cat("  - Crash severity patterns (urban vs rural)\n")
cat("  - Crash type distributions (urban vs rural)\n")
cat("  - Environmental factors analysis\n")
cat("\nSummary tables saved as CSV files.\n\n")

