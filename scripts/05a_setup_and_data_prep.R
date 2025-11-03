# =============================================================================
# ML Setup and Data Preparation
# =============================================================================
# This script sets up the ML environment, loads and prepares data,
# and defines helper functions used by other ML scripts.
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

cat("\n=== Machine Learning Setup and Data Preparation ===\n\n")

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
    flush.console()  # Flush after each row to prevent cutoff
  }
  
  # Print metrics
  cat("\nMetrics:\n")
  cat("  Accuracy:    ", sprintf("%.4f", cm$overall["Accuracy"]), "\n")
  cat("  95% CI:      [", sprintf("%.4f", cm$overall["AccuracyLower"]), 
      ", ", sprintf("%.4f", cm$overall["AccuracyUpper"]), "]\n")
  flush.console()  # Flush after accuracy metrics
  
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

cat("Setup complete! Data and helper functions ready.\n")
cat("Run the following scripts:\n")
cat("  05b_binary_lr.R - Logistic Regression\n")
cat("  05c_binary_rf.R - Random Forest (main)\n")
cat("  05d_severity.R - Multi-class Severity\n")
cat("  05e_urban_rural.R - Urban/Rural Models\n\n")

