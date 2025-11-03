# =============================================================================
# Binary Classification: Random Forest for Fatal Crash Prediction
# =============================================================================
# Source setup script first
source(here::here("scripts", "05a_setup_and_data_prep.R"))

cat("\n=== Running 05c_binary_rf.R: Random Forest (Main) ===\n\n")

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
cat("Test samples:", nrow(test_fatal), "\n\n")

# 1.2 Random Forest with SMOTE Pipeline
cat("\n1.2 Training Random Forest model with SMOTE pipeline...\n")
cat("  Pipeline: Stratified CV + SMOTE resampling + Grid Search + PR-curve threshold tuning\n")

# Use new SMOTE pipeline
rf_result <- train_rf_with_smote_cv(
  train_data = train_fatal,
  test_data = test_fatal,
  target_var = "is_fatal",
  features = fatal_features,
  n_folds = 5,
  tune_grid = expand.grid(
    mtry = c(3, 5, 7),
    ntree = c(100, 200)
  )
)

rf_fatal <- rf_result$model
rf_pred_proba <- rf_result$test_pred_proba
rf_pred <- as.factor(rf_result$test_pred_class)
rf_optimal_threshold <- rf_result$optimal_threshold
rf_accuracy <- mean(rf_pred == as.factor(test_fatal$is_fatal))

cat("  Final model trained with best parameters from grid search\n")
cat("  Optimal threshold (from PR curve):", round(rf_optimal_threshold, 4), "\n")

rf_confusion <- table(Predicted = rf_pred, Actual = as.factor(test_fatal$is_fatal))
rf_metrics_result <- print_confusion_matrix(rf_pred, test_fatal$is_fatal, 
                                           "Random Forest Confusion Matrix")
rf_metrics <- calculate_metrics(rf_pred, test_fatal$is_fatal, positive_class = "1")

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

# Precision-Recall Curve for Random Forest
if (require(PRROC, quietly = TRUE)) {
  rf_pr_auc <- pr.curve(scores.class0 = rf_pred_proba[test_fatal$is_fatal == 1],
                         scores.class1 = rf_pred_proba[test_fatal$is_fatal == 0],
                         curve = TRUE)
  cat("  PR-AUC =", round(rf_pr_auc$auc.integral, 4), "\n")
}

# Plot PR curve
rf_pr_plot <- rf_result$pr_data %>%
  ggplot(aes(x = recall, y = precision)) +
  geom_line(size = 1.2, color = "darkgreen") +
  geom_hline(yintercept = mean(test_fatal$is_fatal), linetype = "dashed", color = "gray") +
  geom_vline(xintercept = rf_result$pr_data$recall[which.max(rf_result$pr_data$f1)], 
             linetype = "dashed", color = "red", alpha = 0.5) +
  annotate("point", x = rf_result$pr_data$recall[which.max(rf_result$pr_data$f1)], 
           y = rf_result$pr_data$precision[which.max(rf_result$pr_data$f1)], 
           color = "red", size = 3) +
  labs(
    title = "Precision-Recall Curve: Random Forest (with SMOTE)",
    subtitle = paste("Optimal threshold =", round(rf_optimal_threshold, 4), 
                     "(maximizes F1)"),
    x = "Recall (Sensitivity)",
    y = "Precision"
  ) +
  theme_minimal()
ggsave(here(figures_dir, "ml_01_rf_pr_curve.png"), rf_pr_plot,
       width = 8, height = 6, dpi = 300)
cat("  PR curve plot saved\n")

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

