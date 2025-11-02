# =============================================================================
# Machine Learning Analysis
# =============================================================================
# Research Question: How crash frequency, severity, and type vary by:
#   - Time of day, day of week, season
#   - Urban vs rural areas in Victoria
# =============================================================================
# ML Goals:
#   1. Predict crash severity
#   2. Predict fatal crashes (binary classification)
#   3. Identify high-risk periods and factors
#   4. Compare models for urban vs rural areas
# =============================================================================

source(here::here("scripts", "00_setup.R"))

# Install ML packages if needed
ml_packages <- c("randomForest", "rpart", "rpart.plot", "caret", "pROC", "vcd")
install_if_missing <- function(packages) {
  new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
  if(length(new_packages) > 0) {
    install.packages(new_packages, dependencies = TRUE)
  }
}
install_if_missing(ml_packages)
lapply(ml_packages, library, character.only = TRUE)

cat("\n=== Machine Learning Analysis: Crash Severity Prediction ===\n\n")

# ---- Load and Prepare Data ----
cat("Loading and preparing data...\n")

accident <- readRDS(here(data_processed, "accident_cleaned.rds"))
node <- readRDS(here(data_processed, "node_cleaned.rds"))
person <- readRDS(here(data_processed, "person_cleaned.rds"))
atmospheric <- readRDS(here(data_processed, "atmospheric_cond_cleaned.rds"))
road_surface <- readRDS(here(data_processed, "road_surface_cond_cleaned.rds"))

# Aggregate tables (same as previous scripts)
atmospheric_agg <- atmospheric %>%
  group_by(accident_no) %>%
  summarise(atmosph_cond_desc = first(atmosph_cond_desc), .groups = "drop")

road_surface_agg <- road_surface %>%
  group_by(accident_no) %>%
  summarise(surface_cond_desc = first(surface_cond_desc), .groups = "drop")

node_agg <- node %>%
  group_by(node_id) %>%
  summarise(deg_urban_name = first(deg_urban_name), .groups = "drop")

# Join data
accident_main <- accident %>%
  left_join(node_agg, by = "node_id", relationship = "many-to-one") %>%
  left_join(atmospheric_agg, by = "accident_no", relationship = "one-to-one") %>%
  left_join(road_surface_agg, by = "accident_no", relationship = "one-to-one") %>%
  mutate(
    hour_of_day = as.numeric(accident_time) %/% 3600,
    hour_group = case_when(
      hour_of_day %in% 6:9 ~ "Morning_Rush",
      hour_of_day %in% 10:14 ~ "Midday",
      hour_of_day %in% 15:18 ~ "Afternoon_Rush",
      hour_of_day %in% 19:22 ~ "Evening",
      TRUE ~ "Night_Late_Night"
    ),
    month = month(accident_date),
    season = case_when(
      month %in% c(12, 1, 2) ~ "Summer",
      month %in% c(3, 4, 5) ~ "Autumn",
      month %in% c(6, 7, 8) ~ "Winter",
      month %in% c(9, 10, 11) ~ "Spring"
    ),
    day_of_week = day_week_desc,
    area_type = case_when(
      !is.na(deg_urban_name) & toupper(trimws(deg_urban_name)) == "RUR" ~ "Rural",
      !is.na(deg_urban_name) & toupper(trimws(deg_urban_name)) %in% c("MEL", "LAR", "SMA", "MED", "REG") ~ "Urban",
      !is.na(deg_urban_name) & grepl("RUR|RURAL", toupper(trimws(deg_urban_name))) ~ "Rural",
      !is.na(deg_urban_name) ~ "Urban",
      is.na(deg_urban_name) & !is.na(rma) & toupper(trimws(rma)) == "RUR" ~ "Rural",
      is.na(deg_urban_name) & !is.na(rma) & toupper(trimws(rma)) %in% c("ART", "LOC", "FRE") ~ "Urban",
      TRUE ~ "Unknown"
    ),
    # Create binary target variables
    is_fatal = ifelse(severity == 1, 1, 0),
    is_serious = ifelse(severity == 2, 1, 0),
    severity_category = case_when(
      severity == 1 ~ "Fatal",
      severity == 2 ~ "Serious",
      severity == 3 ~ "Minor",
      severity == 4 ~ "Property_Damage",
      TRUE ~ "Unknown"
    )
  )

# Filter and prepare ML dataset
ml_data <- accident_main %>%
  filter(area_type != "Unknown",
         !is.na(severity),
         !is.na(accident_type_desc)) %>%
  select(
    # Target variables
    severity,
    severity_category,
    is_fatal,
    is_serious,
    # Features
    area_type,
    hour_of_day,
    hour_group,
    day_of_week,
    season,
    accident_type_desc,
    atmosph_cond_desc,
    surface_cond_desc,
    no_of_vehicles,
    speed_zone
  ) %>%
  # Convert to factors for ML
  mutate(
    area_type = as.factor(area_type),
    hour_group = as.factor(hour_group),
    day_of_week = as.factor(day_of_week),
    season = as.factor(season),
    severity_category = as.factor(severity_category),
    accident_type_desc = as.factor(accident_type_desc),
    atmosph_cond_desc = as.factor(atmosph_cond_desc),
    surface_cond_desc = as.factor(surface_cond_desc)
  )

cat("ML dataset prepared:", nrow(ml_data), "accidents\n")
cat("  Urban:", sum(ml_data$area_type == "Urban"), "\n")
cat("  Rural:", sum(ml_data$area_type == "Rural"), "\n")
cat("  Fatal crashes:", sum(ml_data$is_fatal == 1), "(", round(100*mean(ml_data$is_fatal), 2), "%)\n")
cat("  Serious crashes:", sum(ml_data$is_serious == 1), "(", round(100*mean(ml_data$is_serious), 2), "%)\n\n")

# ---- Split Data ----
cat("Splitting data into train/test sets (70/30)...\n")
set.seed(1234)
train_indices <- sample(1:nrow(ml_data), size = floor(0.7 * nrow(ml_data)))
train_data <- ml_data[train_indices, ]
test_data <- ml_data[-train_indices, ]

cat("  Training set:", nrow(train_data), "accidents\n")
cat("  Test set:", nrow(test_data), "accidents\n\n")

# ---- Helper Functions ----
# Print results to console
print_results <- function(obj, title = "") {
  if (title != "") cat("\n", title, ":\n", sep = "")
  print(obj)
  cat("\n")
}

# Print confusion matrix nicely formatted
print_confusion_matrix <- function(predicted, actual, title = "Confusion Matrix") {
  # Ensure both predicted and actual are factors with same levels
  actual_factor <- as.factor(actual)
  predicted_factor <- as.factor(predicted)
  
  # Get all possible levels (union of actual and predicted, or use actual levels)
  all_levels <- sort(unique(c(levels(actual_factor), levels(predicted_factor))))
  
  # For binary classification, ensure both 0 and 1 are shown
  if (length(all_levels) == 2 && all(all_levels %in% c("0", "1", "0.0", "1.0"))) {
    # Normalize to 0 and 1
    all_levels <- c("0", "1")
    predicted_factor <- factor(predicted, levels = all_levels)
    actual_factor <- factor(actual, levels = all_levels)
  } else {
    predicted_factor <- factor(predicted, levels = all_levels)
    actual_factor <- factor(actual, levels = all_levels)
  }
  
  cm <- confusionMatrix(predicted_factor, actual_factor)
  
  cat("\n", title, ":\n", sep = "")
  cat("========================================\n")
  
  # Print confusion matrix table
  cat("\nConfusion Matrix:\n")
  cat("                 Actual\n")
  cat("Predicted    ")
  for (level in all_levels) {
    cat(sprintf("%12s", level))
  }
  cat("\n")
  cat("----------------------------------------\n")
  
  # Show all prediction levels (even if they have zero counts)
  for (pred_level in all_levels) {
    cat(sprintf("%-10s", pred_level))
    for (actual_level in all_levels) {
      count <- sum(predicted_factor == pred_level & actual_factor == actual_level)
      cat(sprintf("%12d", count))
    }
    cat("\n")
  }
  
  # Print metrics
  cat("\nMetrics:\n")
  cat("  Accuracy:    ", sprintf("%.4f", cm$overall["Accuracy"]), "\n")
  cat("  95% CI:      [", sprintf("%.4f", cm$overall["AccuracyLower"]), 
      ", ", sprintf("%.4f", cm$overall["AccuracyUpper"]), "]\n")
  
  if (length(levels(as.factor(actual))) == 2) {
    # Binary classification
    cat("  Sensitivity: ", sprintf("%.4f", cm$byClass["Sensitivity"]), "\n")
    cat("  Specificity: ", sprintf("%.4f", cm$byClass["Specificity"]), "\n")
    cat("  Precision:   ", sprintf("%.4f", cm$byClass["Precision"]), "\n")
    cat("  Recall:      ", sprintf("%.4f", cm$byClass["Sensitivity"]), "\n")
    cat("  F1 Score:    ", sprintf("%.4f", 2 * (cm$byClass["Precision"] * cm$byClass["Sensitivity"]) / 
                                      (cm$byClass["Precision"] + cm$byClass["Sensitivity"])), "\n")
  }
  
  cat("========================================\n\n")
  
  return(cm)
}

# Visualize confusion matrix
plot_confusion_matrix <- function(conf_mat, title = "Confusion Matrix", model_name = "") {
  conf_mat_df <- as.data.frame(conf_mat)
  names(conf_mat_df) <- c("Predicted", "Actual", "Freq")
  
  # Calculate percentages
  conf_mat_df <- conf_mat_df %>%
    group_by(Actual) %>%
    mutate(Percent = round(100 * Freq / sum(Freq), 1)) %>%
    ungroup()
  
  p <- ggplot(conf_mat_df, aes(x = Actual, y = Predicted, fill = Freq)) +
    geom_tile(color = "white", size = 0.5) +
    geom_text(aes(label = paste(Freq, "\n(", Percent, "%)", sep = "")), 
              color = "black", size = 4, fontface = "bold") +
    scale_fill_gradient(low = "lightblue", high = "darkblue", guide = "none") +
    labs(
      title = title,
      subtitle = model_name,
      x = "Actual",
      y = "Predicted"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 12),
      axis.text = element_text(size = 11),
      axis.title = element_text(size = 12, face = "bold")
    )
  
  return(p)
}

# Calculate performance metrics
calculate_metrics <- function(predicted, actual) {
  cm <- confusionMatrix(as.factor(predicted), as.factor(actual))
  metrics <- tibble(
    Accuracy = cm$overall["Accuracy"],
    Sensitivity = cm$byClass["Sensitivity"],
    Specificity = cm$byClass["Specificity"],
    Precision = cm$byClass["Precision"],
    Recall = cm$byClass["Sensitivity"],
    F1 = 2 * (cm$byClass["Precision"] * cm$byClass["Sensitivity"]) / 
         (cm$byClass["Precision"] + cm$byClass["Sensitivity"])
  )
  return(list(cm = cm, metrics = metrics))
}

# =============================================================================
# 1. PREDICT FATAL CRASHES (Binary Classification)
# =============================================================================

cat("\n=== 1. Predicting Fatal Crashes (Binary Classification) ===\n")

# Prepare data for fatal crash prediction
fatal_features <- c("area_type", "hour_group", "day_of_week", "season", 
                    "accident_type_desc", "atmosph_cond_desc", "surface_cond_desc",
                    "no_of_vehicles", "speed_zone")

train_fatal <- train_data %>%
  select(all_of(fatal_features), is_fatal) %>%
  filter(!is.na(atmosph_cond_desc), !is.na(surface_cond_desc))

test_fatal <- test_data %>%
  select(all_of(fatal_features), is_fatal) %>%
  filter(!is.na(atmosph_cond_desc), !is.na(surface_cond_desc))

cat("Training samples:", nrow(train_fatal), "\n")
cat("Test samples:", nrow(test_fatal), "\n")
cat("Fatal rate in training:", round(100*mean(train_fatal$is_fatal), 2), "%\n\n")

# 1.1 Logistic Regression
cat("1.1 Training Logistic Regression model...\n")
glm_fatal <- glm(is_fatal ~ ., data = train_fatal, family = binomial)
glm_pred <- predict(glm_fatal, newdata = test_fatal, type = "response")
glm_pred_class <- ifelse(glm_pred > 0.5, 1, 0)

glm_confusion <- table(Predicted = glm_pred_class, Actual = test_fatal$is_fatal)
glm_metrics_result <- print_confusion_matrix(glm_pred_class, test_fatal$is_fatal, 
                                             "Logistic Regression Confusion Matrix")
glm_metrics <- calculate_metrics(glm_pred_class, test_fatal$is_fatal)

# Visualize confusion matrix
glm_cm_plot <- plot_confusion_matrix(
  glm_confusion,
  title = "Logistic Regression: Fatal Crash Prediction",
  model_name = "Binary Classification"
)
ggsave(here(figures_dir, "ml_01_logistic_confusion_matrix.png"), glm_cm_plot,
       width = 8, height = 6, dpi = 300)
cat("  Confusion matrix plot saved\n")

# ROC Curve for Logistic Regression
glm_roc <- roc(test_fatal$is_fatal, glm_pred)
glm_roc_plot <- ggroc(glm_roc, legacy.axes = TRUE) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray") +
  labs(
    title = "ROC Curve: Logistic Regression (Fatal Crash Prediction)",
    x = "False Positive Rate",
    y = "True Positive Rate (Sensitivity)"
  ) +
  annotate("text", x = 0.6, y = 0.3, 
           label = paste("AUC =", round(auc(glm_roc), 3)), 
           size = 5, fontface = "bold") +
  theme_minimal()
ggsave(here(figures_dir, "ml_01_logistic_roc_curve.png"), glm_roc_plot,
       width = 8, height = 6, dpi = 300)
cat("  ROC curve plot saved (AUC =", round(auc(glm_roc), 3), ")\n")

# Feature importance (coefficients)
glm_coef <- summary(glm_fatal)$coefficients %>%
  as.data.frame() %>%
  rownames_to_column("Feature") %>%
  arrange(desc(abs(Estimate))) %>%
  slice_head(n = 15)

glm_coef_plot <- glm_coef %>%
  ggplot(aes(x = reorder(Feature, abs(Estimate)), y = Estimate, fill = Estimate > 0)) +
  geom_col() +
  coord_flip() +
  scale_fill_manual(values = c("FALSE" = "red3", "TRUE" = "green3"), guide = "none") +
  labs(
    title = "Top 15 Logistic Regression Coefficients",
    subtitle = "Fatal Crash Prediction",
    x = "Feature",
    y = "Coefficient Estimate"
  ) +
  theme_minimal()
ggsave(here(figures_dir, "ml_01_logistic_coefficients.png"), glm_coef_plot,
       width = 10, height = 8, dpi = 300)
cat("  Feature coefficients plot saved\n")

# 1.2 Random Forest
cat("\n1.2 Training Random Forest model...\n")
rf_fatal <- randomForest(
  as.factor(is_fatal) ~ .,
  data = train_fatal,
  ntree = 100,
  importance = TRUE
)

rf_pred <- predict(rf_fatal, newdata = test_fatal)
rf_pred_proba <- predict(rf_fatal, newdata = test_fatal, type = "prob")[,2]
rf_accuracy <- mean(rf_pred == as.factor(test_fatal$is_fatal))

rf_confusion <- table(Predicted = rf_pred, Actual = as.factor(test_fatal$is_fatal))
rf_metrics_result <- print_confusion_matrix(rf_pred, test_fatal$is_fatal, 
                                           "Random Forest Confusion Matrix")
rf_metrics <- calculate_metrics(rf_pred, test_fatal$is_fatal)

# Visualize confusion matrix
rf_cm_plot <- plot_confusion_matrix(
  rf_confusion,
  title = "Random Forest: Fatal Crash Prediction",
  model_name = "Binary Classification"
)
ggsave(here(figures_dir, "ml_01_rf_confusion_matrix.png"), rf_cm_plot,
       width = 8, height = 6, dpi = 300)
cat("  Confusion matrix plot saved\n")

# ROC Curve for Random Forest
rf_roc <- roc(test_fatal$is_fatal, rf_pred_proba)
rf_roc_plot <- ggroc(rf_roc, legacy.axes = TRUE) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray") +
  labs(
    title = "ROC Curve: Random Forest (Fatal Crash Prediction)",
    x = "False Positive Rate",
    y = "True Positive Rate (Sensitivity)"
  ) +
  annotate("text", x = 0.6, y = 0.3, 
           label = paste("AUC =", round(auc(rf_roc), 3)), 
           size = 5, fontface = "bold") +
  theme_minimal()
ggsave(here(figures_dir, "ml_01_rf_roc_curve.png"), rf_roc_plot,
       width = 8, height = 6, dpi = 300)
cat("  ROC curve plot saved (AUC =", round(auc(rf_roc), 3), ")\n")

# Feature importance
rf_importance <- importance(rf_fatal) %>%
  as.data.frame() %>%
  rownames_to_column("Feature") %>%
  arrange(desc(MeanDecreaseGini))

rf_importance_plot <- rf_importance %>%
  slice_head(n = 15) %>%
  ggplot(aes(x = reorder(Feature, MeanDecreaseGini), y = MeanDecreaseGini)) +
  geom_col(fill = "steelblue", alpha = 0.8) +
  coord_flip() +
  labs(
    title = "Top 15 Features for Fatal Crash Prediction",
    subtitle = "Random Forest Model (Mean Decrease Gini)",
    x = "Feature",
    y = "Importance"
  ) +
  theme_minimal()
ggsave(here(figures_dir, "ml_01_rf_feature_importance.png"), rf_importance_plot,
       width = 10, height = 8, dpi = 300)
cat("  Feature importance plot saved\n")

# Model Comparison: Performance Metrics
binary_metrics <- bind_rows(
  glm_metrics$metrics %>% mutate(Model = "Logistic Regression"),
  rf_metrics$metrics %>% mutate(Model = "Random Forest")
) %>%
  mutate(Model = factor(Model, levels = c("Logistic Regression", "Random Forest")))

binary_metrics_long <- binary_metrics %>%
  pivot_longer(cols = c(Accuracy, Sensitivity, Specificity, Precision, Recall, F1),
               names_to = "Metric", values_to = "Value") %>%
  mutate(Metric = factor(Metric, levels = c("Accuracy", "Sensitivity", "Specificity", 
                                           "Precision", "Recall", "F1")))

binary_metrics_plot <- binary_metrics_long %>%
  ggplot(aes(x = Metric, y = Value, fill = Model)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Logistic Regression" = "steelblue", 
                               "Random Forest" = "darkgreen")) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1)) +
  labs(
    title = "Model Performance Comparison: Fatal Crash Prediction",
    subtitle = "Binary Classification Metrics",
    x = "Metric",
    y = "Score",
    fill = "Model"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
ggsave(here(figures_dir, "ml_01_binary_model_comparison.png"), binary_metrics_plot,
       width = 12, height = 6, dpi = 300)
cat("  Model comparison plot saved\n")

# =============================================================================
# 2. PREDICT SEVERITY CATEGORY (Multi-class Classification)
# =============================================================================

cat("\n=== 2. Predicting Severity Category (Multi-class) ===\n")

# Prepare data
severity_features <- c("area_type", "hour_group", "day_of_week", "season",
                       "accident_type_desc", "atmosph_cond_desc", "surface_cond_desc",
                       "no_of_vehicles", "speed_zone")

train_severity <- train_data %>%
  select(all_of(severity_features), severity_category) %>%
  filter(!is.na(atmosph_cond_desc), !is.na(surface_cond_desc),
         !is.na(severity_category), severity_category != "Unknown")

test_severity <- test_data %>%
  select(all_of(severity_features), severity_category) %>%
  filter(!is.na(atmosph_cond_desc), !is.na(surface_cond_desc),
         !is.na(severity_category), severity_category != "Unknown")

cat("Training samples:", nrow(train_severity), "\n")
cat("Test samples:", nrow(test_severity), "\n\n")

# 2.1 Random Forest for Severity
cat("2.1 Training Random Forest for severity prediction...\n")
rf_severity <- randomForest(
  severity_category ~ .,
  data = train_severity,
  ntree = 100,
  importance = TRUE
)

rf_severity_pred <- predict(rf_severity, newdata = test_severity)
rf_severity_accuracy <- mean(rf_severity_pred == test_severity$severity_category)

cat("  Accuracy:", round(rf_severity_accuracy, 4), "\n")

# Confusion matrix - print to console
rf_severity_confusion <- table(Predicted = rf_severity_pred, 
                               Actual = test_severity$severity_category)
rf_severity_cm_result <- print_confusion_matrix(rf_severity_pred, test_severity$severity_category,
                                               "Random Forest Severity Prediction Confusion Matrix")

# Visualize confusion matrix (heatmap)
rf_severity_cm_df <- as.data.frame(rf_severity_confusion)
names(rf_severity_cm_df) <- c("Predicted", "Actual", "Freq")
rf_severity_cm_df <- rf_severity_cm_df %>%
  group_by(Actual) %>%
  mutate(Percent = round(100 * Freq / sum(Freq), 1)) %>%
  ungroup()

rf_severity_cm_plot <- ggplot(rf_severity_cm_df, aes(x = Actual, y = Predicted, fill = Freq)) +
  geom_tile(color = "white", size = 0.5) +
  geom_text(aes(label = paste(Freq, "\n(", Percent, "%)", sep = "")), 
            color = "black", size = 3.5, fontface = "bold") +
  scale_fill_gradient(low = "lightblue", high = "darkblue", guide = "none") +
  labs(
    title = "Random Forest: Severity Category Prediction",
    subtitle = "Multi-class Classification Confusion Matrix",
    x = "Actual Severity",
    y = "Predicted Severity"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 12),
    axis.text = element_text(size = 10),
    axis.title = element_text(size = 12, face = "bold")
  )
ggsave(here(figures_dir, "ml_02_severity_confusion_matrix.png"), rf_severity_cm_plot,
       width = 10, height = 8, dpi = 300)
cat("  Confusion matrix plot saved\n")

# Calculate per-class metrics
rf_severity_cm_caret <- confusionMatrix(rf_severity_pred, test_severity$severity_category)
severity_metrics <- tibble(
  Class = names(rf_severity_cm_caret$byClass[, "Sensitivity"]),
  Sensitivity = rf_severity_cm_caret$byClass[, "Sensitivity"],
  Specificity = rf_severity_cm_caret$byClass[, "Specificity"],
  Precision = rf_severity_cm_caret$byClass[, "Precision"],
  F1 = rf_severity_cm_caret$byClass[, "F1"]
)

severity_metrics_long <- severity_metrics %>%
  pivot_longer(cols = c(Sensitivity, Specificity, Precision, F1),
               names_to = "Metric", values_to = "Value")

severity_metrics_plot <- severity_metrics_long %>%
  ggplot(aes(x = Class, y = Value, fill = Metric)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_brewer(palette = "Set2") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1)) +
  labs(
    title = "Per-Class Performance Metrics: Severity Prediction",
    subtitle = "Random Forest Multi-class Classification",
    x = "Severity Class",
    y = "Score",
    fill = "Metric"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom"
  )
ggsave(here(figures_dir, "ml_02_severity_per_class_metrics.png"), severity_metrics_plot,
       width = 12, height = 6, dpi = 300)
cat("  Per-class metrics plot saved\n")

# Feature importance
rf_severity_importance <- importance(rf_severity) %>%
  as.data.frame() %>%
  rownames_to_column("Feature") %>%
  arrange(desc(MeanDecreaseGini))

rf_severity_importance_plot <- rf_severity_importance %>%
  slice_head(n = 15) %>%
  ggplot(aes(x = reorder(Feature, MeanDecreaseGini), y = MeanDecreaseGini)) +
  geom_col(fill = "darkorange", alpha = 0.8) +
  coord_flip() +
  labs(
    title = "Top 15 Features for Severity Category Prediction",
    subtitle = "Random Forest Model (Mean Decrease Gini)",
    x = "Feature",
    y = "Importance"
  ) +
  theme_minimal()
ggsave(here(figures_dir, "ml_02_severity_feature_importance.png"), rf_severity_importance_plot,
       width = 10, height = 8, dpi = 300)
cat("  Feature importance plot saved\n")

# =============================================================================
# 3. SEPARATE MODELS FOR URBAN vs RURAL
# =============================================================================

cat("\n=== 3. Separate Models: Urban vs Rural ===\n")

# 3.1 Urban Model
cat("\n3.1 Training models for Urban crashes...\n")
train_urban <- train_fatal %>%
  filter(area_type == "Urban")
test_urban <- test_fatal %>%
  filter(area_type == "Urban")

rf_urban <- randomForest(
  as.factor(is_fatal) ~ .,
  data = train_urban %>% select(-area_type),
  ntree = 100,
  importance = TRUE
)

rf_urban_pred <- predict(rf_urban, newdata = test_urban %>% select(-area_type))
rf_urban_pred_proba <- predict(rf_urban, newdata = test_urban %>% select(-area_type), type = "prob")[,2]
rf_urban_accuracy <- mean(rf_urban_pred == as.factor(test_urban$is_fatal))

rf_urban_confusion <- table(Predicted = rf_urban_pred, Actual = as.factor(test_urban$is_fatal))
rf_urban_metrics_result <- print_confusion_matrix(rf_urban_pred, test_urban$is_fatal,
                                                  "Urban Random Forest Confusion Matrix")
rf_urban_metrics <- calculate_metrics(rf_urban_pred, test_urban$is_fatal)

# Visualize confusion matrix
rf_urban_cm_plot <- plot_confusion_matrix(
  rf_urban_confusion,
  title = "Random Forest: Urban Area Fatal Crash Prediction",
  model_name = "Urban-Specific Model"
)
ggsave(here(figures_dir, "ml_03_urban_confusion_matrix.png"), rf_urban_cm_plot,
       width = 8, height = 6, dpi = 300)
cat("  Urban confusion matrix plot saved\n")

# ROC Curve for Urban
rf_urban_roc <- roc(test_urban$is_fatal, rf_urban_pred_proba)
rf_urban_roc_plot <- ggroc(rf_urban_roc, legacy.axes = TRUE) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray") +
  labs(
    title = "ROC Curve: Urban Area Model",
    subtitle = "Random Forest for Fatal Crash Prediction",
    x = "False Positive Rate",
    y = "True Positive Rate (Sensitivity)"
  ) +
  annotate("text", x = 0.6, y = 0.3, 
           label = paste("AUC =", round(auc(rf_urban_roc), 3)), 
           size = 5, fontface = "bold") +
  theme_minimal()
ggsave(here(figures_dir, "ml_03_urban_roc_curve.png"), rf_urban_roc_plot,
       width = 8, height = 6, dpi = 300)
cat("  Urban ROC curve plot saved (AUC =", round(auc(rf_urban_roc), 3), ")\n")

# 3.2 Rural Model
cat("\n3.2 Training models for Rural crashes...\n")
train_rural <- train_fatal %>%
  filter(area_type == "Rural")
test_rural <- test_fatal %>%
  filter(area_type == "Rural")

rf_rural <- randomForest(
  as.factor(is_fatal) ~ .,
  data = train_rural %>% select(-area_type),
  ntree = 100,
  importance = TRUE
)

rf_rural_pred <- predict(rf_rural, newdata = test_rural %>% select(-area_type))
rf_rural_pred_proba <- predict(rf_rural, newdata = test_rural %>% select(-area_type), type = "prob")[,2]
rf_rural_accuracy <- mean(rf_rural_pred == as.factor(test_rural$is_fatal))

rf_rural_confusion <- table(Predicted = rf_rural_pred, Actual = as.factor(test_rural$is_fatal))
rf_rural_metrics_result <- print_confusion_matrix(rf_rural_pred, test_rural$is_fatal,
                                                 "Rural Random Forest Confusion Matrix")
rf_rural_metrics <- calculate_metrics(rf_rural_pred, test_rural$is_fatal)

# Visualize confusion matrix
rf_rural_cm_plot <- plot_confusion_matrix(
  rf_rural_confusion,
  title = "Random Forest: Rural Area Fatal Crash Prediction",
  model_name = "Rural-Specific Model"
)
ggsave(here(figures_dir, "ml_03_rural_confusion_matrix.png"), rf_rural_cm_plot,
       width = 8, height = 6, dpi = 300)
cat("  Rural confusion matrix plot saved\n")

# ROC Curve for Rural
rf_rural_roc <- roc(test_rural$is_fatal, rf_rural_pred_proba)
rf_rural_roc_plot <- ggroc(rf_rural_roc, legacy.axes = TRUE) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray") +
  labs(
    title = "ROC Curve: Rural Area Model",
    subtitle = "Random Forest for Fatal Crash Prediction",
    x = "False Positive Rate",
    y = "True Positive Rate (Sensitivity)"
  ) +
  annotate("text", x = 0.6, y = 0.3, 
           label = paste("AUC =", round(auc(rf_rural_roc), 3)), 
           size = 5, fontface = "bold") +
  theme_minimal()
ggsave(here(figures_dir, "ml_03_rural_roc_curve.png"), rf_rural_roc_plot,
       width = 8, height = 6, dpi = 300)
cat("  Rural ROC curve plot saved (AUC =", round(auc(rf_rural_roc), 3), ")\n")

# Compare Urban vs Rural Models
urban_rural_metrics <- bind_rows(
  rf_urban_metrics$metrics %>% mutate(Model = "Urban"),
  rf_rural_metrics$metrics %>% mutate(Model = "Rural")
)

urban_rural_metrics_long <- urban_rural_metrics %>%
  pivot_longer(cols = c(Accuracy, Sensitivity, Specificity, Precision, Recall, F1),
               names_to = "Metric", values_to = "Value")

urban_rural_comparison_plot <- urban_rural_metrics_long %>%
  ggplot(aes(x = Metric, y = Value, fill = Model)) +
  geom_col(position = "dodge", alpha = 0.8) +
  scale_fill_manual(values = c("Urban" = "steelblue", "Rural" = "darkgreen")) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1)) +
  labs(
    title = "Model Performance Comparison: Urban vs Rural",
    subtitle = "Random Forest Models for Fatal Crash Prediction",
    x = "Metric",
    y = "Score",
    fill = "Area Type"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
ggsave(here(figures_dir, "ml_03_urban_rural_comparison.png"), urban_rural_comparison_plot,
       width = 12, height = 6, dpi = 300)
cat("  Urban vs Rural comparison plot saved\n")

# Feature importance comparison
rf_urban_importance <- importance(rf_urban) %>%
  as.data.frame() %>%
  rownames_to_column("Feature") %>%
  arrange(desc(MeanDecreaseGini)) %>%
  slice_head(n = 10) %>%
  mutate(Model = "Urban")

rf_rural_importance <- importance(rf_rural) %>%
  as.data.frame() %>%
  rownames_to_column("Feature") %>%
  arrange(desc(MeanDecreaseGini)) %>%
  slice_head(n = 10) %>%
  mutate(Model = "Rural")

urban_rural_importance_plot <- bind_rows(rf_urban_importance, rf_rural_importance) %>%
  ggplot(aes(x = reorder(Feature, MeanDecreaseGini), y = MeanDecreaseGini, fill = Model)) +
  geom_col(position = "dodge", alpha = 0.8) +
  coord_flip() +
  scale_fill_manual(values = c("Urban" = "steelblue", "Rural" = "darkgreen")) +
  labs(
    title = "Top 10 Feature Importance: Urban vs Rural Models",
    subtitle = "Random Forest Models Comparison",
    x = "Feature",
    y = "Importance (Mean Decrease Gini)",
    fill = "Area Type"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")
ggsave(here(figures_dir, "ml_03_urban_rural_feature_importance.png"), urban_rural_importance_plot,
       width = 12, height = 8, dpi = 300)
cat("  Urban vs Rural feature importance plot saved\n")

# =============================================================================
# 4. MODEL COMPARISON SUMMARY
# =============================================================================

cat("\n=== 4. Model Performance Summary ===\n")

# Overall model comparison
all_models_metrics <- bind_rows(
  glm_metrics$metrics %>% mutate(Model = "Logistic Regression (Fatal)"),
  rf_metrics$metrics %>% mutate(Model = "Random Forest (Fatal)"),
  tibble(Accuracy = rf_severity_accuracy, Sensitivity = NA, Specificity = NA,
         Precision = NA, Recall = NA, F1 = NA, Model = "Random Forest (Severity)"),
  rf_urban_metrics$metrics %>% mutate(Model = "Random Forest (Urban)"),
  rf_rural_metrics$metrics %>% mutate(Model = "Random Forest (Rural)")
)

model_comparison_plot <- all_models_metrics %>%
  ggplot(aes(x = Model, y = Accuracy, fill = Model)) +
  geom_col(alpha = 0.8) +
  scale_fill_brewer(palette = "Set1") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 0.1), limits = c(0, 1)) +
  labs(
    title = "Model Accuracy Comparison",
    subtitle = "All Models Performance",
    x = "Model",
    y = "Accuracy",
    fill = "Model"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none"
  )
ggsave(here(figures_dir, "ml_04_all_models_comparison.png"), model_comparison_plot,
       width = 12, height = 6, dpi = 300)
cat("  Overall model comparison plot saved\n")

# Print summary
print_results(all_models_metrics, "Model Performance Summary")

cat("\n=== Machine Learning Analysis Complete ===\n")
cat("All visualizations saved to:", figures_dir, "\n")
cat("\nSummary:\n")
cat("  - Binary classification models for fatal crash prediction\n")
cat("  - Multi-class models for severity prediction\n")
cat("  - Separate models for urban vs rural areas\n")
cat("  - Confusion matrices, ROC curves, and performance metrics\n")
cat("  - Feature importance analysis\n")
cat("\nNext: Review model results and compile final report.\n\n")
