# =============================================================================
# Statistical Analysis
# =============================================================================
# Research Question: How crash frequency, severity, and type vary by:
#   - Time of day, day of week, season
#   - Urban vs rural areas in Victoria
# =============================================================================

source(here::here("scripts", "00_setup.R"))

cat("\n=== Statistical Analysis: Crash Patterns ===\n\n")

# ---- Load Processed Data ----
cat("Loading data...\n")

accident <- readRDS(here(data_processed, "accident_cleaned.rds"))
node <- readRDS(here(data_processed, "node_cleaned.rds"))
person <- readRDS(here(data_processed, "person_cleaned.rds"))
atmospheric <- readRDS(here(data_processed, "atmospheric_cond_cleaned.rds"))
road_surface <- readRDS(here(data_processed, "road_surface_cond_cleaned.rds"))

# Aggregate tables (same as EDA)
atmospheric_agg <- atmospheric %>%
  group_by(accident_no) %>%
  summarise(atmosph_cond_desc = first(atmosph_cond_desc), .groups = "drop")

road_surface_agg <- road_surface %>%
  group_by(accident_no) %>%
  summarise(surface_cond_desc = first(surface_cond_desc), .groups = "drop")

node_agg <- node %>%
  group_by(node_id) %>%
  summarise(deg_urban_name = first(deg_urban_name), .groups = "drop")

person_agg <- person %>%
  group_by(accident_no) %>%
  summarise(
    min_inj_level = min(inj_level, na.rm = TRUE),
    total_fatalities = sum(inj_level_desc == "Fat", na.rm = TRUE),
    total_serious_injuries = sum(inj_level_desc == "Ser", na.rm = TRUE),
    .groups = "drop"
  )

# Join data
accident_main <- accident %>%
  left_join(node_agg, by = "node_id", relationship = "many-to-one") %>%
  left_join(atmospheric_agg, by = "accident_no", relationship = "one-to-one") %>%
  left_join(road_surface_agg, by = "accident_no", relationship = "one-to-one") %>%
  left_join(person_agg, by = "accident_no", relationship = "one-to-one") %>%
  mutate(
    hour_of_day = as.numeric(accident_time) %/% 3600,
    hour_group = case_when(
      hour_of_day %in% 6:9 ~ "Morning Rush (6-9)",
      hour_of_day %in% 10:14 ~ "Midday (10-14)",
      hour_of_day %in% 15:18 ~ "Afternoon Rush (15-18)",
      hour_of_day %in% 19:22 ~ "Evening (19-22)",
      TRUE ~ "Night/Late Night (23-5)"
    ),
    month = month(accident_date),
    season = case_when(
      month %in% c(12, 1, 2) ~ "Summer",
      month %in% c(3, 4, 5) ~ "Autumn",
      month %in% c(6, 7, 8) ~ "Winter",
      month %in% c(9, 10, 11) ~ "Spring"
    ),
    area_type = case_when(
      !is.na(deg_urban_name) & toupper(trimws(deg_urban_name)) == "RUR" ~ "Rural",
      !is.na(deg_urban_name) & toupper(trimws(deg_urban_name)) %in% c("MEL", "LAR", "SMA", "MED", "REG") ~ "Urban",
      !is.na(deg_urban_name) & grepl("RUR|RURAL", toupper(trimws(deg_urban_name))) ~ "Rural",
      !is.na(deg_urban_name) ~ "Urban",
      is.na(deg_urban_name) & !is.na(rma) & toupper(trimws(rma)) == "RUR" ~ "Rural",
      is.na(deg_urban_name) & !is.na(rma) & toupper(trimws(rma)) %in% c("ART", "LOC", "FRE") ~ "Urban",
      TRUE ~ "Unknown"
    )
  )

accident_analysis <- accident_main %>%
  filter(area_type != "Unknown") %>%
  mutate(
    area_type = factor(area_type, levels = c("Urban", "Rural")),
    severity = as.factor(severity),
    is_fatal = (severity == 1),
    is_serious = (severity == 2)
  )

cat("Analysis dataset:", nrow(accident_analysis), "accidents\n")
cat("  Urban:", sum(accident_analysis$area_type == "Urban"), "\n")
cat("  Rural:", sum(accident_analysis$area_type == "Rural"), "\n\n")

# ---- Helper Functions ----
# Print results to console
print_results <- function(obj, title = "") {
  if (title != "") cat("\n", title, ":\n", sep = "")
  print(obj)
  cat("\n")
}

# Calculate Cramér's V
cramers_v <- function(chi_sq_stat, n, min_dim) {
  sqrt(chi_sq_stat / (n * (min_dim - 1)))
}

# =============================================================================
# 1. FREQUENCY ANALYSIS - Statistical Tests
# =============================================================================

cat("\n=== 1. Frequency Analysis: Statistical Tests ===\n")

# 1.1 Chi-square test: Crash frequency by day of week (Urban vs Rural)
cat("\n1.1 Testing: Crash frequency by day of week (Urban vs Rural)\n")
freq_day_week <- table(accident_analysis$day_week_desc, accident_analysis$area_type)
test_day_week <- chisq.test(freq_day_week)
print(test_day_week)

# Cramér's V (effect size)
n <- sum(freq_day_week)
cramers_v_day_week <- cramers_v(test_day_week$statistic, n, min(dim(freq_day_week)))
cat("  Cramér's V:", round(as.numeric(cramers_v_day_week), 4), "\n")

# Visualize frequency by day of week
freq_day_week_df <- as.data.frame(freq_day_week) %>%
  pivot_wider(names_from = Var2, values_from = Freq) %>%
  rename(Day = Var1)

freq_day_week_long <- freq_day_week_df %>%
  pivot_longer(cols = c(Urban, Rural), names_to = "Area", values_to = "Count") %>%
  mutate(Day = factor(Day, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", 
                                       "Friday", "Saturday", "Sunday")))

freq_day_week_plot <- freq_day_week_long %>%
  ggplot(aes(x = Day, y = Count, fill = Area)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Urban" = "steelblue", "Rural" = "darkgreen")) +
  labs(
    title = "Crash Frequency by Day of Week: Urban vs Rural",
    subtitle = paste("Chi-square test: p =", format(test_day_week$p.value, scientific = TRUE, digits = 3),
                     ", Cramér's V =", round(as.numeric(cramers_v_day_week), 4)),
    x = "Day of Week",
    y = "Number of Crashes",
    fill = "Area Type"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom"
  )
ggsave(here(figures_dir, "stats_01_freq_day_week.png"), freq_day_week_plot,
       width = 12, height = 6, dpi = 300)
cat("  Frequency plot saved\n")

# 1.2 Chi-square test: Crash frequency by time period (Urban vs Rural)
cat("\n1.2 Testing: Crash frequency by time period (Urban vs Rural)\n")
freq_time <- table(accident_analysis$hour_group, accident_analysis$area_type)
test_time <- chisq.test(freq_time)
print(test_time)

cramers_v_time <- cramers_v(test_time$statistic, sum(freq_time), min(dim(freq_time)))
cat("  Cramér's V:", round(as.numeric(cramers_v_time), 4), "\n")

# Visualize frequency by time period
freq_time_df <- as.data.frame(freq_time) %>%
  pivot_wider(names_from = Var2, values_from = Freq) %>%
  rename(Time = Var1)

freq_time_long <- freq_time_df %>%
  pivot_longer(cols = c(Urban, Rural), names_to = "Area", values_to = "Count") %>%
  mutate(Time = factor(Time, levels = c("Morning Rush (6-9)", "Midday (10-14)", 
                                        "Afternoon Rush (15-18)", "Evening (19-22)", 
                                        "Night/Late Night (23-5)")))

freq_time_plot <- freq_time_long %>%
  ggplot(aes(x = Time, y = Count, fill = Area)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Urban" = "steelblue", "Rural" = "darkgreen")) +
  labs(
    title = "Crash Frequency by Time Period: Urban vs Rural",
    subtitle = paste("Chi-square test: p =", format(test_time$p.value, scientific = TRUE, digits = 3),
                     ", Cramér's V =", round(as.numeric(cramers_v_time), 4)),
    x = "Time Period",
    y = "Number of Crashes",
    fill = "Area Type"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom"
  )
ggsave(here(figures_dir, "stats_01_freq_time.png"), freq_time_plot,
       width = 12, height = 6, dpi = 300)
cat("  Frequency plot saved\n")

# 1.3 Chi-square test: Crash frequency by season (Urban vs Rural)
cat("\n1.3 Testing: Crash frequency by season (Urban vs Rural)\n")
freq_season <- table(accident_analysis$season, accident_analysis$area_type)
test_season <- chisq.test(freq_season)
print(test_season)

cramers_v_season <- cramers_v(test_season$statistic, sum(freq_season), min(dim(freq_season)))
cat("  Cramér's V:", round(as.numeric(cramers_v_season), 4), "\n")

# Visualize frequency by season
freq_season_df <- as.data.frame(freq_season) %>%
  pivot_wider(names_from = Var2, values_from = Freq) %>%
  rename(Season = Var1)

freq_season_long <- freq_season_df %>%
  pivot_longer(cols = c(Urban, Rural), names_to = "Area", values_to = "Count") %>%
  mutate(Season = factor(Season, levels = c("Summer", "Autumn", "Winter", "Spring")))

freq_season_plot <- freq_season_long %>%
  ggplot(aes(x = Season, y = Count, fill = Area)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Urban" = "steelblue", "Rural" = "darkgreen")) +
  labs(
    title = "Crash Frequency by Season: Urban vs Rural",
    subtitle = paste("Chi-square test: p =", format(test_season$p.value, scientific = TRUE, digits = 3),
                     ", Cramér's V =", round(as.numeric(cramers_v_season), 4)),
    x = "Season",
    y = "Number of Crashes",
    fill = "Area Type"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
ggsave(here(figures_dir, "stats_01_freq_season.png"), freq_season_plot,
       width = 10, height = 6, dpi = 300)
cat("  Frequency plot saved\n")

# =============================================================================
# 2. SEVERITY ANALYSIS - Statistical Tests
# =============================================================================

cat("\n=== 2. Severity Analysis: Statistical Tests ===\n")

# 2.1 Chi-square test: Severity distribution (Urban vs Rural)
cat("\n2.1 Testing: Severity distribution (Urban vs Rural)\n")
severity_table <- table(accident_analysis$severity, accident_analysis$area_type)
test_severity <- chisq.test(severity_table)
print(test_severity)

cramers_v_severity <- cramers_v(test_severity$statistic, sum(severity_table), min(dim(severity_table)))
cat("  Cramér's V:", round(as.numeric(cramers_v_severity), 4), "\n")

# Visualize severity distribution
severity_df <- as.data.frame(severity_table) %>%
  pivot_wider(names_from = Var2, values_from = Freq) %>%
  rename(Severity = Var1) %>%
  mutate(Severity = case_when(
    Severity == "1" ~ "Fatal",
    Severity == "2" ~ "Serious",
    Severity == "3" ~ "Minor",
    Severity == "4" ~ "Property Damage",
    TRUE ~ as.character(Severity)
  ))

severity_long <- severity_df %>%
  pivot_longer(cols = c(Urban, Rural), names_to = "Area", values_to = "Count") %>%
  mutate(Severity = factor(Severity, levels = c("Fatal", "Serious", "Minor", "Property Damage")))

severity_plot <- severity_long %>%
  ggplot(aes(x = Severity, y = Count, fill = Area)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Urban" = "steelblue", "Rural" = "darkgreen")) +
  labs(
    title = "Severity Distribution: Urban vs Rural",
    subtitle = paste("Chi-square test: p =", format(test_severity$p.value, scientific = TRUE, digits = 3),
                     ", Cramér's V =", round(as.numeric(cramers_v_severity), 4)),
    x = "Severity Level",
    y = "Number of Crashes",
    fill = "Area Type"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
ggsave(here(figures_dir, "stats_02_severity_dist.png"), severity_plot,
       width = 10, height = 6, dpi = 300)
cat("  Severity distribution plot saved\n")

# 2.2 Fisher's exact test: Fatal crashes (Urban vs Rural)
cat("\n2.2 Testing: Fatal crash rates (Urban vs Rural)\n")
fatal_table <- table(accident_analysis$is_fatal, accident_analysis$area_type)
test_fatal <- fisher.test(fatal_table)
print(test_fatal)

# Odds ratio
urban_fatal_rate <- sum(accident_analysis$is_fatal & accident_analysis$area_type == "Urban") / 
                    sum(accident_analysis$area_type == "Urban")
rural_fatal_rate <- sum(accident_analysis$is_fatal & accident_analysis$area_type == "Rural") / 
                    sum(accident_analysis$area_type == "Rural")
cat("  Urban fatal rate:", round(urban_fatal_rate, 4), "\n")
cat("  Rural fatal rate:", round(rural_fatal_rate, 4), "\n")
cat("  Odds ratio:", round(test_fatal$estimate, 4), "\n")

# Visualize fatal crash rates
fatal_rates <- tibble(
  Area = c("Urban", "Rural"),
  Fatal_Rate = c(urban_fatal_rate, rural_fatal_rate),
  Fatal_Rate_Pct = c(urban_fatal_rate * 100, rural_fatal_rate * 100)
)

fatal_rates_plot <- fatal_rates %>%
  ggplot(aes(x = Area, y = Fatal_Rate, fill = Area)) +
  geom_col(alpha = 0.8) +
  geom_text(aes(label = paste(round(Fatal_Rate_Pct, 2), "%", sep = "")),
            vjust = -0.5, size = 5, fontface = "bold") +
  scale_fill_manual(values = c("Urban" = "steelblue", "Rural" = "darkgreen"), guide = "none") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 0.01), limits = c(0, max(fatal_rates$Fatal_Rate) * 1.2)) +
  labs(
    title = "Fatal Crash Rates: Urban vs Rural",
    subtitle = paste("Fisher's Exact Test: p =", format(test_fatal$p.value, scientific = TRUE, digits = 3),
                     ", Odds Ratio =", round(test_fatal$estimate, 4)),
    x = "Area Type",
    y = "Fatal Crash Rate",
    fill = "Area Type"
  ) +
  theme_minimal()
ggsave(here(figures_dir, "stats_02_fatal_rates.png"), fatal_rates_plot,
       width = 8, height = 6, dpi = 300)
cat("  Fatal rates plot saved\n")

# =============================================================================
# 3. CRASH TYPE ANALYSIS - Statistical Tests
# =============================================================================

cat("\n=== 3. Crash Type Analysis: Statistical Tests ===\n")

# 3.1 Chi-square test: Crash type distribution (Urban vs Rural)
cat("\n3.1 Testing: Crash type distribution (Urban vs Rural)\n")
crash_type_table <- table(accident_analysis$accident_type_desc, accident_analysis$area_type)
test_crash_type <- chisq.test(crash_type_table)
print(test_crash_type)

cramers_v_crash_type <- cramers_v(test_crash_type$statistic, sum(crash_type_table), min(dim(crash_type_table)))
cat("  Cramér's V:", round(as.numeric(cramers_v_crash_type), 4), "\n")

# Visualize crash type distribution (top 10)
crash_type_df <- as.data.frame(crash_type_table) %>%
  pivot_wider(names_from = Var2, values_from = Freq) %>%
  rename(Crash_Type = Var1) %>%
  mutate(Total = Urban + Rural) %>%
  arrange(desc(Total)) %>%
  slice_head(n = 10)

crash_type_long <- crash_type_df %>%
  select(Crash_Type, Urban, Rural) %>%
  pivot_longer(cols = c(Urban, Rural), names_to = "Area", values_to = "Count")

crash_type_plot <- crash_type_long %>%
  ggplot(aes(x = reorder(Crash_Type, Count), y = Count, fill = Area)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Urban" = "steelblue", "Rural" = "darkgreen")) +
  coord_flip() +
  labs(
    title = "Top 10 Crash Types: Urban vs Rural",
    subtitle = paste("Chi-square test: p =", format(test_crash_type$p.value, scientific = TRUE, digits = 3),
                     ", Cramér's V =", round(as.numeric(cramers_v_crash_type), 4)),
    x = "Crash Type",
    y = "Number of Crashes",
    fill = "Area Type"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
ggsave(here(figures_dir, "stats_03_crash_type.png"), crash_type_plot,
       width = 12, height = 8, dpi = 300)
cat("  Crash type plot saved\n")

# =============================================================================
# 4. ENVIRONMENTAL FACTORS - Statistical Tests
# =============================================================================

cat("\n=== 4. Environmental Factors: Statistical Tests ===\n")

# 4.1 Atmospheric conditions (Urban vs Rural)
if (any(!is.na(accident_analysis$atmosph_cond_desc))) {
  cat("\n4.1 Testing: Atmospheric conditions (Urban vs Rural)\n")
  atmos_table <- table(accident_analysis$atmosph_cond_desc, accident_analysis$area_type)
  test_atmos <- chisq.test(atmos_table)
  print(test_atmos)
  
  cramers_v_atmos <- cramers_v(test_atmos$statistic, sum(atmos_table), min(dim(atmos_table)))
  cat("  Cramér's V:", round(as.numeric(cramers_v_atmos), 4), "\n")
  
  # Visualize atmospheric conditions
  atmos_df <- as.data.frame(atmos_table) %>%
    pivot_wider(names_from = Var2, values_from = Freq) %>%
    rename(Atmospheric = Var1) %>%
    mutate(Total = Urban + Rural) %>%
    arrange(desc(Total))
  
  atmos_long <- atmos_df %>%
    select(Atmospheric, Urban, Rural) %>%
    pivot_longer(cols = c(Urban, Rural), names_to = "Area", values_to = "Count")
  
  atmos_plot <- atmos_long %>%
    ggplot(aes(x = reorder(Atmospheric, Count), y = Count, fill = Area)) +
    geom_col(position = "dodge", alpha = 0.8) +
    scale_fill_manual(values = c("Urban" = "steelblue", "Rural" = "darkgreen")) +
    coord_flip() +
    labs(
      title = "Atmospheric Conditions: Urban vs Rural",
      subtitle = paste("Chi-square test: p =", format(test_atmos$p.value, scientific = TRUE, digits = 3),
                       ", Cramér's V =", round(as.numeric(cramers_v_atmos), 4)),
      x = "Atmospheric Condition",
      y = "Number of Crashes",
      fill = "Area Type"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")
  ggsave(here(figures_dir, "stats_04_atmospheric.png"), atmos_plot,
         width = 12, height = 8, dpi = 300)
  cat("  Atmospheric conditions plot saved\n")
}

# 4.2 Road surface conditions (Urban vs Rural)
if (any(!is.na(accident_analysis$surface_cond_desc))) {
  cat("\n4.2 Testing: Road surface conditions (Urban vs Rural)\n")
  surface_table <- table(accident_analysis$surface_cond_desc, accident_analysis$area_type)
  test_surface <- chisq.test(surface_table)
  print(test_surface)
  
  cramers_v_surface <- cramers_v(test_surface$statistic, sum(surface_table), min(dim(surface_table)))
  cat("  Cramér's V:", round(as.numeric(cramers_v_surface), 4), "\n")
  
  # Visualize road surface conditions
  surface_df <- as.data.frame(surface_table) %>%
    pivot_wider(names_from = Var2, values_from = Freq) %>%
    rename(Surface = Var1) %>%
    mutate(Total = Urban + Rural) %>%
    arrange(desc(Total))
  
  surface_long <- surface_df %>%
    select(Surface, Urban, Rural) %>%
    pivot_longer(cols = c(Urban, Rural), names_to = "Area", values_to = "Count")
  
  surface_plot <- surface_long %>%
    ggplot(aes(x = reorder(Surface, Count), y = Count, fill = Area)) +
    geom_col(position = "dodge", alpha = 0.8) +
    scale_fill_manual(values = c("Urban" = "steelblue", "Rural" = "darkgreen")) +
    coord_flip() +
    labs(
      title = "Road Surface Conditions: Urban vs Rural",
      subtitle = paste("Chi-square test: p =", format(test_surface$p.value, scientific = TRUE, digits = 3),
                       ", Cramér's V =", round(as.numeric(cramers_v_surface), 4)),
      x = "Road Surface Condition",
      y = "Number of Crashes",
      fill = "Area Type"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")
  ggsave(here(figures_dir, "stats_04_road_surface.png"), surface_plot,
         width = 12, height = 8, dpi = 300)
  cat("  Road surface conditions plot saved\n")
}

# =============================================================================
# 5. STATISTICAL TESTS SUMMARY
# =============================================================================

cat("\n=== 5. Statistical Tests Summary ===\n")

# Create a summary table of all tests
tests_summary <- tibble(
  Test = c(
    "Frequency by Day of Week",
    "Frequency by Time Period",
    "Frequency by Season",
    "Severity Distribution",
    "Fatal Crash Rates",
    "Crash Type Distribution",
    if(exists("test_atmos")) "Atmospheric Conditions" else NULL,
    if(exists("test_surface")) "Road Surface Conditions" else NULL
  ),
  Test_Type = c(
    "Chi-square", "Chi-square", "Chi-square",
    "Chi-square", "Fisher's Exact",
    "Chi-square",
    if(exists("test_atmos")) "Chi-square" else NULL,
    if(exists("test_surface")) "Chi-square" else NULL
  ),
  P_Value = c(
    test_day_week$p.value,
    test_time$p.value,
    test_season$p.value,
    test_severity$p.value,
    test_fatal$p.value,
    test_crash_type$p.value,
    if(exists("test_atmos")) test_atmos$p.value else NA,
    if(exists("test_surface")) test_surface$p.value else NA
  ),
  Cramers_V = c(
    as.numeric(cramers_v_day_week),
    as.numeric(cramers_v_time),
    as.numeric(cramers_v_season),
    as.numeric(cramers_v_severity),
    NA,  # Fisher's exact doesn't have Cramér's V
    as.numeric(cramers_v_crash_type),
    if(exists("cramers_v_atmos")) as.numeric(cramers_v_atmos) else NA,
    if(exists("cramers_v_surface")) as.numeric(cramers_v_surface) else NA
  ),
  Significant = c(
    test_day_week$p.value < 0.05,
    test_time$p.value < 0.05,
    test_season$p.value < 0.05,
    test_severity$p.value < 0.05,
    test_fatal$p.value < 0.05,
    test_crash_type$p.value < 0.05,
    if(exists("test_atmos")) test_atmos$p.value < 0.05 else NA,
    if(exists("test_surface")) test_surface$p.value < 0.05 else NA
  )
) %>%
  filter(!is.na(Test)) %>%
  mutate(
    P_Value = round(P_Value, 6),
    Cramers_V = round(Cramers_V, 4),
    Significant = ifelse(Significant, "Yes", "No")
  )

# Visualize statistical tests summary
tests_summary_long <- tests_summary %>%
  pivot_longer(cols = c(P_Value, Cramers_V), names_to = "Metric", values_to = "Value") %>%
  filter(!is.na(Value)) %>%
  mutate(Metric = factor(Metric, levels = c("P_Value", "Cramers_V")))

pvalue_plot <- tests_summary %>%
  ggplot(aes(x = reorder(Test, P_Value), y = P_Value, fill = Significant)) +
  geom_col(alpha = 0.8) +
  geom_hline(yintercept = 0.05, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = length(tests_summary$Test), y = 0.06, 
           label = "p = 0.05", color = "red", fontface = "bold") +
  scale_fill_manual(values = c("Yes" = "darkgreen", "No" = "gray")) +
  scale_y_continuous(limits = c(0, max(tests_summary$P_Value, na.rm = TRUE) * 1.2)) +
  coord_flip() +
  labs(
    title = "Statistical Tests: P-Values Summary",
    subtitle = "Chi-square and Fisher's Exact Tests",
    x = "Test",
    y = "P-Value",
    fill = "Significant\n(p < 0.05)"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
ggsave(here(figures_dir, "stats_05_pvalues_summary.png"), pvalue_plot,
       width = 12, height = 8, dpi = 300)
cat("  P-values summary plot saved\n")

# Effect size plot (Cramér's V)
cramers_plot <- tests_summary %>%
  filter(!is.na(Cramers_V)) %>%
  ggplot(aes(x = reorder(Test, Cramers_V), y = Cramers_V, fill = Cramers_V)) +
  geom_col(alpha = 0.8) +
  geom_hline(yintercept = c(0.1, 0.3, 0.5), linetype = "dashed", 
             color = c("green", "orange", "red"), alpha = 0.5) +
  annotate("text", x = length(tests_summary %>% filter(!is.na(Cramers_V)) %>% pull(Test)), 
           y = 0.52, label = "Large (≥0.5)", color = "red", fontface = "bold", size = 3) +
  annotate("text", x = length(tests_summary %>% filter(!is.na(Cramers_V)) %>% pull(Test)), 
           y = 0.32, label = "Medium (≥0.3)", color = "orange", fontface = "bold", size = 3) +
  annotate("text", x = length(tests_summary %>% filter(!is.na(Cramers_V)) %>% pull(Test)), 
           y = 0.12, label = "Small (≥0.1)", color = "green", fontface = "bold", size = 3) +
  scale_fill_gradient(low = "lightblue", high = "darkblue", guide = "none") +
  coord_flip() +
  labs(
    title = "Effect Size: Cramér's V Summary",
    subtitle = "Measure of Association Strength (0 = no association, 1 = perfect association)",
    x = "Test",
    y = "Cramér's V"
  ) +
  theme_minimal()
ggsave(here(figures_dir, "stats_05_cramers_v_summary.png"), cramers_plot,
       width = 12, height = 8, dpi = 300)
cat("  Cramér's V summary plot saved\n")

# Print summary
print_results(tests_summary, "Statistical Tests Summary")

cat("\n=== Statistical Analysis Complete ===\n")
cat("All visualizations saved to:", figures_dir, "\n")
cat("\nSummary:\n")
cat("  - Chi-square tests for categorical associations\n")
cat("  - Fisher's exact test for fatal crash rates\n")
cat("  - Cramér's V for effect sizes\n")
cat("  - Statistical test visualizations\n")
cat("\nNext: Review test results and proceed to machine learning analysis.\n\n")
