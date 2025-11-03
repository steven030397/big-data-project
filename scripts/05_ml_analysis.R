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
ml_packages <- c("randomForest", "rpart", "rpart.plot", "caret", "pROC", "vcd", "ROSE", "PRROC")
install_if_missing <- function(packages) {
  new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
  if(length(new_packages) > 0) {
    install.packages(new_packages, dependencies = TRUE, repos = "https://cloud.r-project.org")
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

# =============================================================================
# IMPROVED PIPELINE: Stratified CV + SMOTE + Grid Search + PR-Curve Threshold
# =============================================================================

# Function to find optimal threshold using Precision-Recall curve (maximizes F1)
find_optimal_threshold_pr <- function(proba, actual, positive_class = 1, metric = "f1", verbose = TRUE) {
  # Create PR curve data
  pr_data <- tibble(
    threshold = seq(0.01, 0.99, by = 0.01),
    precision = NA_real_,
    recall = NA_real_,
    f1 = NA_real_
  )
  
  for (i in seq_along(pr_data$threshold)) {
    thresh <- pr_data$threshold[i]
    pred_class <- ifelse(proba > thresh, positive_class, 1 - positive_class)
    cm <- confusionMatrix(as.factor(pred_class), as.factor(actual), positive = as.character(positive_class))
    
    prec <- ifelse("Precision" %in% names(cm$byClass), cm$byClass["Precision"], 0)
    rec <- ifelse("Sensitivity" %in% names(cm$byClass), cm$byClass["Sensitivity"], 0)
    
    pr_data$precision[i] <- prec
    pr_data$recall[i] <- rec
    pr_data$f1[i] <- ifelse(prec + rec > 0, 2 * (prec * rec) / (prec + rec), 0)
  }
  
  # Find optimal threshold
  if (metric == "f1") {
    best_idx <- which.max(pr_data$f1)
    optimal_threshold <- pr_data$threshold[best_idx]
    best_metric <- pr_data$f1[best_idx]
    metric_name <- "F1"
  } else if (metric == "recall") {
    # Maximize recall while maintaining minimum precision
    min_precision <- 0.05  # At least 5% precision
    valid_idx <- which(pr_data$precision >= min_precision)
    if (length(valid_idx) > 0) {
      best_idx <- valid_idx[which.max(pr_data$recall[valid_idx])]
      optimal_threshold <- pr_data$threshold[best_idx]
      best_metric <- pr_data$recall[best_idx]
    } else {
      best_idx <- which.max(pr_data$recall)
      optimal_threshold <- pr_data$threshold[best_idx]
      best_metric <- pr_data$recall[best_idx]
    }
    metric_name <- "Recall"
  }
  
  if (verbose) {
    cat("  Optimal threshold:", round(optimal_threshold, 4), 
        "(maximizes", metric_name, "=", round(best_metric, 4), ")\n")
  }
  
  return(list(threshold = optimal_threshold, pr_data = pr_data))
}

# Stratified CV with SMOTE pipeline for Random Forest
train_rf_with_smote_cv <- function(train_data, test_data, target_var = "is_fatal", 
                                   features, n_folds = 5, tune_grid = NULL) {
  cat("  Setting up stratified 5-fold cross-validation with SMOTE pipeline...\n")
  
  # Prepare data
  X_train <- train_data %>% select(all_of(features))
  y_train <- as.factor(train_data[[target_var]])
  X_test <- test_data %>% select(all_of(features))
  y_test <- as.factor(test_data[[target_var]])
  
  # Create stratified folds (preserves class distribution)
  set.seed(42)
  folds <- createFolds(y_train, k = n_folds, list = TRUE, returnTrain = FALSE)
  
  cat("  Class distribution in training:", table(y_train), "\n")
  
  # Default tune grid if not provided
  if (is.null(tune_grid)) {
    tune_grid <- expand.grid(
      mtry = c(3, 5, 7),
      ntree = c(100, 200)
    )
  }
  
  # Store CV results
  cv_results <- list()
  cv_f1_scores <- numeric(nrow(tune_grid))
  
  cat("  Performing grid search with", nrow(tune_grid), "parameter combinations...\n")
  
  # Grid search with CV
  for (param_idx in 1:nrow(tune_grid)) {
    params <- tune_grid[param_idx, ]
    fold_scores <- numeric(n_folds)
    
    cat("    Testing: mtry =", params$mtry, ", ntree =", params$ntree, "\n")
    
    for (fold in 1:n_folds) {
      # Split fold
      val_indices <- folds[[fold]]
      train_indices <- setdiff(1:length(y_train), val_indices)
      
      X_train_fold <- X_train[train_indices, ]
      y_train_fold <- y_train[train_indices]
      X_val_fold <- X_train[val_indices, ]
      y_val_fold <- y_train[val_indices]
      
      # Apply SMOTE to training fold only (resample inside CV)
      tryCatch({
        train_fold_data <- bind_cols(X_train_fold, tibble(target = y_train_fold))
        
        # SMOTE using ROSE package
        train_fold_balanced <- ROSE(target ~ ., data = train_fold_data, seed = 42)$data
        
        X_train_balanced <- train_fold_balanced %>% select(-target)
        y_train_balanced <- as.factor(train_fold_balanced$target)
        
        # Train Random Forest with balanced data
        # Use balanced class weights
        class_counts <- table(y_train_balanced)
        class_weights <- c(
          sum(class_counts) / (2 * class_counts[1]),
          sum(class_counts) / (2 * class_counts[2])
        )
        names(class_weights) <- names(class_counts)
        
        # Combine data for randomForest
        train_balanced_df <- bind_cols(X_train_balanced, tibble(is_fatal = as.numeric(as.character(y_train_balanced))))
        train_balanced_df$is_fatal <- as.factor(train_balanced_df$is_fatal)
        
        rf_model <- randomForest(
          is_fatal ~ .,
          data = train_balanced_df,
          ntree = params$ntree,
          mtry = params$mtry,
          classwt = class_weights,
          importance = FALSE
        )
        
        # Predict on validation fold
        val_pred_proba <- predict(rf_model, newdata = X_val_fold, type = "prob")[,2]
        
        # Find optimal threshold for this fold using PR curve (silent during CV)
        pr_result <- find_optimal_threshold_pr(val_pred_proba, y_val_fold, 
                                               positive_class = 1, metric = "f1", verbose = FALSE)
        
        # Predict with optimal threshold
        val_pred_class <- ifelse(val_pred_proba > pr_result$threshold, 1, 0)
        
        # Calculate F1
        cm <- confusionMatrix(as.factor(val_pred_class), y_val_fold, positive = "1")
        prec <- ifelse("Precision" %in% names(cm$byClass), cm$byClass["Precision"], 0)
        rec <- ifelse("Sensitivity" %in% names(cm$byClass), cm$byClass["Sensitivity"], 0)
        f1 <- ifelse(prec + rec > 0, 2 * (prec * rec) / (prec + rec), 0)
        
        fold_scores[fold] <- f1
      }, error = function(e) {
        cat("      Warning: SMOTE failed in fold", fold, "- using class weights only\n")
        # Fallback: use class weights without SMOTE
        class_counts <- table(y_train_fold)
        class_weights <- c(
          sum(class_counts) / (2 * class_counts[1]),
          sum(class_counts) / (2 * class_counts[2])
        )
        names(class_weights) <- names(class_counts)
        
        # Combine data for randomForest
        train_fold_df <- bind_cols(X_train_fold, tibble(is_fatal = as.numeric(as.character(y_train_fold))))
        train_fold_df$is_fatal <- as.factor(train_fold_df$is_fatal)
        
        rf_model <- randomForest(
          is_fatal ~ .,
          data = train_fold_df,
          ntree = params$ntree,
          mtry = params$mtry,
          classwt = class_weights
        )
        
        val_pred_proba <- predict(rf_model, newdata = X_val_fold, type = "prob")[,2]
        val_pred_class <- ifelse(val_pred_proba > 0.5, 1, 0)
        
        cm <- confusionMatrix(as.factor(val_pred_class), y_val_fold, positive = "1")
        prec <- ifelse("Precision" %in% names(cm$byClass), cm$byClass["Precision"], 0)
        rec <- ifelse("Sensitivity" %in% names(cm$byClass), cm$byClass["Sensitivity"], 0)
        f1 <- ifelse(prec + rec > 0, 2 * (prec * rec) / (prec + rec), 0)
        
        fold_scores[fold] <- f1
      })
    }
    
    cv_f1_scores[param_idx] <- mean(fold_scores)
    cat("    Mean CV F1:", round(mean(fold_scores), 4), "\n")
    flush.console()  # Ensure output is displayed
  }
  
  # Find best parameters
  best_idx <- which.max(cv_f1_scores)
  best_params <- tune_grid[best_idx, ]
  best_cv_f1 <- cv_f1_scores[best_idx]
  
  cat("  Best parameters: mtry =", best_params$mtry, ", ntree =", best_params$ntree, 
      "(CV F1 =", round(best_cv_f1, 4), ")\n")
  
  # Retrain final model on full training set with best parameters + SMOTE
  cat("  Retraining final model on full training set with SMOTE...\n")
  train_full_data <- bind_cols(X_train, tibble(target = y_train))
  train_full_balanced <- ROSE(target ~ ., data = train_full_data, seed = 42)$data
  
  X_train_final <- train_full_balanced %>% select(-target)
  y_train_final <- as.factor(train_full_balanced$target)
  
  class_counts <- table(y_train_final)
  class_weights <- c(
    sum(class_counts) / (2 * class_counts[1]),
    sum(class_counts) / (2 * class_counts[2])
  )
  names(class_weights) <- names(class_counts)
  
  # Combine data for randomForest
  train_final_df <- bind_cols(X_train_final, tibble(is_fatal = as.numeric(as.character(y_train_final))))
  train_final_df$is_fatal <- as.factor(train_final_df$is_fatal)
  
  final_model <- randomForest(
    is_fatal ~ .,
    data = train_final_df,
    ntree = best_params$ntree,
    mtry = best_params$mtry,
    classwt = class_weights,
    importance = TRUE
  )
  
  # IMPORTANT: Find optimal threshold on original (imbalanced) validation holdout
  # This prevents overfitting to SMOTE-balanced data
  cat("  Optimizing threshold on validation holdout (maintaining original class imbalance)...\n")
  
  # Create a validation holdout from original training data (20% holdout)
  set.seed(42)
  val_holdout_idx <- createDataPartition(y_train, p = 0.2, list = FALSE)
  X_val_holdout <- X_train[val_holdout_idx, ]
  y_val_holdout <- y_train[val_holdout_idx]
  
  # Predict on validation holdout using final model
  val_holdout_proba <- predict(final_model, newdata = X_val_holdout, type = "prob")[,2]
  
  # Find optimal threshold on validation holdout (realistic imbalanced data)
  pr_result_val <- find_optimal_threshold_pr(val_holdout_proba, y_val_holdout, 
                                               positive_class = 1, metric = "f1", verbose = TRUE)
  
  optimal_threshold <- pr_result_val$threshold
  
  # Predict on test set
  test_pred_proba <- predict(final_model, newdata = X_test, type = "prob")[,2]
  
  # Apply optimized threshold to test set
  test_pred_class <- ifelse(test_pred_proba > optimal_threshold, 1, 0)
  
  # Get PR data for plotting (from validation holdout, not balanced training)
  pr_data <- pr_result_val$pr_data
  
  return(list(
    model = final_model,
    best_params = best_params,
    optimal_threshold = optimal_threshold,
    test_pred_proba = test_pred_proba,
    test_pred_class = test_pred_class,
    cv_results = cv_f1_scores,
    pr_data = pr_data
  ))
}

# Legacy CV function (kept for compatibility)
find_optimal_threshold_cv <- function(data, formula, model_type = "glm", n_folds = 5, positive_class = 1, metric = "youden") {
  # Extract target variable name from formula
  formula_str <- as.character(formula)
  target_var_str <- formula_str[2]
  # Handle factor conversion in formula (remove as.factor() wrapper if present)
  target_var_clean <- gsub("as\\.factor\\((.*)\\)", "\\1", target_var_str)
  target_var_clean <- trimws(target_var_clean)
  
  # Get actual target values for creating folds
  target_values <- data[[target_var_clean]]
  
  # Create folds
  set.seed(1234)
  folds <- createFolds(target_values, k = n_folds, list = TRUE)
  
  # Optimize threshold search: fewer steps for RF (it's slower), more for GLM
  if (model_type == "rf") {
    # For RF: coarser search to speed up (every 0.02 instead of 0.01)
    thresholds <- seq(0.01, 0.5, by = 0.02)
    # Use fewer trees during CV for speed (will use full 100 for final model)
    cv_ntree <- 50
  } else {
    # For GLM: finer search (faster to compute)
    thresholds <- seq(0.01, 0.5, by = 0.01)
    cv_ntree <- NULL  # Not used for GLM
  }
  
  if (metric == "youden") {
    cv_scores <- numeric(length(thresholds))
    metric_name <- "Youden's Index (Sensitivity + Specificity)"
  } else if (metric == "f1") {
    cv_scores <- numeric(length(thresholds))
    metric_name <- "F1 Score"
  } else if (metric == "balanced_acc") {
    cv_scores <- numeric(length(thresholds))
    metric_name <- "Balanced Accuracy"
  }
  
  total_iterations <- length(thresholds) * n_folds
  
  cat("  Cross-validating across", n_folds, "folds to find optimal threshold (maximizing", metric_name, ")...\n")
  cat("  Testing", length(thresholds), "thresholds (~", total_iterations, "model trainings)\n")
  if (model_type == "rf") {
    cat("  Note: Using", cv_ntree, "trees during CV for speed (final model uses 100)\n")
  }
  
  start_time <- Sys.time()
  
  iteration <- 0
  for (i in seq_along(thresholds)) {
    threshold <- thresholds[i]
    fold_scores <- numeric(n_folds)
    
    for (fold in seq_along(folds)) {
      iteration <- iteration + 1
      
      # Progress indicator every 10 iterations
      if (iteration %% 10 == 0 || iteration == 1) {
        elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
        cat(sprintf("    Progress: %d/%d (%.1f%%) - Elapsed: %.1f seconds\n", 
                    iteration, total_iterations, 
                    100 * iteration / total_iterations, elapsed))
      }
      
      # Split data
      train_indices <- unlist(folds[-fold])
      val_indices <- folds[[fold]]
      train_fold <- data[train_indices, ]
      val_fold <- data[val_indices, ]
      
      # Train model
      if (model_type == "glm") {
        model <- glm(formula, data = train_fold, family = binomial)
        pred_proba <- predict(model, newdata = val_fold, type = "response")
      } else if (model_type == "rf") {
        # Calculate class weights for this fold
        fold_target_var <- train_fold[[target_var_clean]]
        fold_target_factor <- as.factor(fold_target_var)
        fold_class_counts <- table(fold_target_factor)
        fold_class_levels <- names(fold_class_counts)
        fold_class_weights <- c(
          sum(fold_class_counts) / (2 * fold_class_counts[fold_class_levels[1]]),
          sum(fold_class_counts) / (2 * fold_class_counts[fold_class_levels[2]])
        )
        names(fold_class_weights) <- fold_class_levels
        
        model <- randomForest(
          formula,
          data = train_fold,
          ntree = cv_ntree,  # Use fewer trees during CV for speed
          classwt = fold_class_weights
        )
        pred_proba <- predict(model, newdata = val_fold, type = "prob")[, as.character(positive_class)]
      }
      
      # Apply threshold and calculate metric
      pred_class <- ifelse(pred_proba > threshold, positive_class, 1 - positive_class)
      actual <- val_fold[[target_var_clean]]
      
      # Calculate confusion matrix metrics
      cm <- confusionMatrix(as.factor(pred_class), as.factor(actual), positive = as.character(positive_class))
      sensitivity <- ifelse("Sensitivity" %in% names(cm$byClass), cm$byClass["Sensitivity"], 0)
      specificity <- ifelse("Specificity" %in% names(cm$byClass), cm$byClass["Specificity"], 0)
      
      # Calculate chosen metric
      if (metric == "youden") {
        # Youden's index: maximizes (sensitivity + specificity)
        score <- sensitivity + specificity
      } else if (metric == "f1") {
        precision <- ifelse("Precision" %in% names(cm$byClass), cm$byClass["Precision"], 0)
        recall <- sensitivity
        score <- ifelse(precision + recall > 0, 2 * (precision * recall) / (precision + recall), 0)
      } else if (metric == "balanced_acc") {
        # Balanced accuracy: (sensitivity + specificity) / 2
        score <- (sensitivity + specificity) / 2
      }
      
      fold_scores[fold] <- score
    }
    
    cv_scores[i] <- mean(fold_scores)
  }
  
  elapsed_total <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  cat("  CV complete! Total time:", round(elapsed_total, 1), "seconds\n")
  
  # Find threshold with maximum score
  best_idx <- which.max(cv_scores)
  optimal_threshold <- thresholds[best_idx]
  best_score <- cv_scores[best_idx]
  
  cat("  Optimal threshold:", round(optimal_threshold, 4), 
      "(maximizes", metric_name, "=", round(best_score, 4), "across CV folds)\n")
  
  return(optimal_threshold)
}

# Print confusion matrix nicely formatted
print_confusion_matrix <- function(predicted, actual, title = "Confusion Matrix", positive_class = "1") {
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
    
    # Explicitly set positive class for binary classification
    cm <- confusionMatrix(predicted_factor, actual_factor, positive = positive_class)
  } else {
    predicted_factor <- factor(predicted, levels = all_levels)
    actual_factor <- factor(actual, levels = all_levels)
    cm <- confusionMatrix(predicted_factor, actual_factor)
  }
  
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
  flush.console()  # Force output to display immediately
  
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
calculate_metrics <- function(predicted, actual, positive_class = "1") {
  # Ensure factors with consistent levels
  predicted_factor <- as.factor(predicted)
  actual_factor <- as.factor(actual)
  
  # For binary classification, explicitly set positive class
  if (length(levels(actual_factor)) == 2) {
    # Reorder levels so positive class is second (for caret confusionMatrix)
    levels_ordered <- sort(levels(actual_factor))
    if (positive_class %in% levels_ordered) {
      # Put positive class last
      other_level <- levels_ordered[levels_ordered != positive_class]
      levels_ordered <- c(other_level, positive_class)
      actual_factor <- factor(actual, levels = levels_ordered)
      predicted_factor <- factor(predicted, levels = levels_ordered)
    }
    
    cm <- confusionMatrix(predicted_factor, actual_factor, positive = positive_class)
  } else {
    cm <- confusionMatrix(predicted_factor, actual_factor)
  }
  
  # Check for class imbalance warning
  predicted_table <- table(predicted_factor)
  if (length(predicted_table) == 1) {
    warning("WARNING: Model predicts only one class! Check for class imbalance issues.")
  }
  
  metrics <- tibble(
    Accuracy = cm$overall["Accuracy"],
    Sensitivity = ifelse("Sensitivity" %in% names(cm$byClass), cm$byClass["Sensitivity"], NA),
    Specificity = ifelse("Specificity" %in% names(cm$byClass), cm$byClass["Specificity"], NA),
    Precision = ifelse("Precision" %in% names(cm$byClass), cm$byClass["Precision"], NA),
    Recall = ifelse("Sensitivity" %in% names(cm$byClass), cm$byClass["Sensitivity"], NA),
    F1 = ifelse("F1" %in% names(cm$byClass), cm$byClass["F1"], 
                ifelse("Precision" %in% names(cm$byClass) && "Sensitivity" %in% names(cm$byClass),
                       2 * (cm$byClass["Precision"] * cm$byClass["Sensitivity"]) / 
                       (cm$byClass["Precision"] + cm$byClass["Sensitivity"]), NA))
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
