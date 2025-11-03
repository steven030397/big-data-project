# =============================================================================
# Binary Classification: Logistic Regression for Fatal Crash Prediction
# =============================================================================
# Source setup script first
source(here::here("scripts", "05a_setup_and_data_prep.R"))

cat("\n=== Running 05b_binary_lr.R: Logistic Regression ===\n\n")

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
cat("Fatal rate in training:", round(100*mean(train_fatal$is_fatal), 2), "%\n")
cat("Fatal rate in test:", round(100*mean(test_fatal$is_fatal), 2), "%\n")
cat("Class distribution - Training:\n")
cat("  Non-fatal (0):", sum(train_fatal$is_fatal == 0), 
    "(", round(100*mean(train_fatal$is_fatal == 0), 2), "%)\n")
cat("  Fatal (1):", sum(train_fatal$is_fatal == 1), 
    "(", round(100*mean(train_fatal$is_fatal == 1), 2), "%)\n")
cat("Class distribution - Test:\n")
cat("  Non-fatal (0):", sum(test_fatal$is_fatal == 0), 
    "(", round(100*mean(test_fatal$is_fatal == 0), 2), "%)\n")
cat("  Fatal (1):", sum(test_fatal$is_fatal == 1), 
    "(", round(100*mean(test_fatal$is_fatal == 1), 2), "%)\n")
if (mean(train_fatal$is_fatal) < 0.05 || mean(train_fatal$is_fatal) > 0.95) {
  cat("\nWARNING: Severe class imbalance detected! Models may predict all one class.\n")
  cat("Consider using class weights, resampling, or threshold tuning.\n")
}
cat("\n")

# 1.1 Logistic Regression with PR-curve threshold tuning
cat("1.1 Training Logistic Regression model...\n")
cat("  Using Precision-Recall curve to find optimal threshold (maximizing F1)\n")

# Train model on full training set
glm_fatal <- glm(is_fatal ~ ., data = train_fatal, family = binomial)
glm_pred <- predict(glm_fatal, newdata = test_fatal, type = "response")

# Find optimal threshold using PR curve on training predictions
glm_train_pred <- predict(glm_fatal, newdata = train_fatal, type = "response")
glm_pr_result <- find_optimal_threshold_pr(glm_train_pred, train_fatal$is_fatal, 
                                            positive_class = 1, metric = "f1")
glm_optimal_threshold <- glm_pr_result$threshold
glm_pr_data <- glm_pr_result$pr_data

# Apply optimal threshold
glm_pred_class <- ifelse(glm_pred > glm_optimal_threshold, 1, 0)

glm_confusion <- table(Predicted = glm_pred_class, Actual = test_fatal$is_fatal)
glm_metrics_result <- print_confusion_matrix(glm_pred_class, test_fatal$is_fatal, 
                                             "Logistic Regression Confusion Matrix")
glm_metrics <- calculate_metrics(glm_pred_class, test_fatal$is_fatal, positive_class = "1")

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

# Precision-Recall Curve for Logistic Regression
if (require(PRROC, quietly = TRUE)) {
  glm_pr_auc <- pr.curve(scores.class0 = glm_pred[test_fatal$is_fatal == 1],
                         scores.class1 = glm_pred[test_fatal$is_fatal == 0],
                         curve = TRUE)
  cat("  PR-AUC =", round(glm_pr_auc$auc.integral, 4), "\n")
}

# Plot PR curve
glm_pr_plot <- glm_pr_data %>%
  ggplot(aes(x = recall, y = precision)) +
  geom_line(size = 1.2, color = "steelblue") +
  geom_hline(yintercept = mean(test_fatal$is_fatal), linetype = "dashed", color = "gray") +
  geom_vline(xintercept = glm_pr_data$recall[which.max(glm_pr_data$f1)], 
             linetype = "dashed", color = "red", alpha = 0.5) +
  annotate("point", x = glm_pr_data$recall[which.max(glm_pr_data$f1)], 
           y = glm_pr_data$precision[which.max(glm_pr_data$f1)], 
           color = "red", size = 3) +
  labs(
    title = "Precision-Recall Curve: Logistic Regression",
    subtitle = paste("Optimal threshold =", round(glm_optimal_threshold, 4), 
                     "(maximizes F1)"),
    x = "Recall (Sensitivity)",
    y = "Precision"
  ) +
  theme_minimal()
ggsave(here(figures_dir, "ml_01_logistic_pr_curve.png"), glm_pr_plot,
       width = 8, height = 6, dpi = 300)
cat("  PR curve plot saved\n")

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

