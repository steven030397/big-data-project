# =============================================================================
# Multi-class Classification: Severity Category Prediction
# =============================================================================
# Source setup script first
source(here::here("scripts", "05a_setup_and_data_prep.R"))

cat("\n=== Running 05d_severity.R: Multi-class Severity ===\n\n")

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

