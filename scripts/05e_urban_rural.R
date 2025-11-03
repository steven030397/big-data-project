# =============================================================================
# Separate Models: Urban vs Rural Areas
# =============================================================================
# Source setup script first
source(here::here("scripts", "05a_setup_and_data_prep.R"))

cat("\n=== Running 05e_urban_rural.R: Urban/Rural Models ===\n\n")

cat("\n=== 3. Separate Models: Urban vs Rural ===\n")

# 3.1 Urban Model with SMOTE Pipeline
cat("\n3.1 Training models for Urban crashes with SMOTE pipeline...\n")
train_urban <- train_fatal %>%
  filter(area_type == "Urban")
test_urban <- test_fatal %>%
  filter(area_type == "Urban")

# Use SMOTE pipeline for urban model
urban_features <- setdiff(fatal_features, "area_type")
rf_urban_result <- train_rf_with_smote_cv(
  train_data = train_urban,
  test_data = test_urban,
  target_var = "is_fatal",
  features = urban_features,
  n_folds = 5,
  tune_grid = expand.grid(
    mtry = c(3, 5, 7),
    ntree = c(100, 200)
  )
)

rf_urban <- rf_urban_result$model
rf_urban_pred_proba <- rf_urban_result$test_pred_proba
rf_urban_pred <- as.factor(rf_urban_result$test_pred_class)
rf_urban_optimal_threshold <- rf_urban_result$optimal_threshold
rf_urban_accuracy <- mean(rf_urban_pred == as.factor(test_urban$is_fatal))

rf_urban_confusion <- table(Predicted = rf_urban_pred, Actual = as.factor(test_urban$is_fatal))
rf_urban_metrics_result <- print_confusion_matrix(rf_urban_pred, test_urban$is_fatal,
                                                  "Urban Random Forest Confusion Matrix")
rf_urban_metrics <- calculate_metrics(rf_urban_pred, test_urban$is_fatal, positive_class = "1")

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

# 3.2 Rural Model with SMOTE Pipeline
cat("\n3.2 Training models for Rural crashes with SMOTE pipeline...\n")
train_rural <- train_fatal %>%
  filter(area_type == "Rural")
test_rural <- test_fatal %>%
  filter(area_type == "Rural")

# Use SMOTE pipeline for rural model
rural_features <- setdiff(fatal_features, "area_type")
rf_rural_result <- train_rf_with_smote_cv(
  train_data = train_rural,
  test_data = test_rural,
  target_var = "is_fatal",
  features = rural_features,
  n_folds = 5,
  tune_grid = expand.grid(
    mtry = c(3, 5, 7),
    ntree = c(100, 200)
  )
)

rf_rural <- rf_rural_result$model
rf_rural_pred_proba <- rf_rural_result$test_pred_proba
rf_rural_pred <- as.factor(rf_rural_result$test_pred_class)
rf_rural_optimal_threshold <- rf_rural_result$optimal_threshold
rf_rural_accuracy <- mean(rf_rural_pred == as.factor(test_rural$is_fatal))

rf_rural_confusion <- table(Predicted = rf_rural_pred, Actual = as.factor(test_rural$is_fatal))
rf_rural_metrics_result <- print_confusion_matrix(rf_rural_pred, test_rural$is_fatal,
                                                 "Rural Random Forest Confusion Matrix")
rf_rural_metrics <- calculate_metrics(rf_rural_pred, test_rural$is_fatal, positive_class = "1")

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
