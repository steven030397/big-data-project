# =============================================================================
# Exploratory Data Analysis Script
# =============================================================================
# This script performs exploratory data analysis and generates figures
# Output: Figures saved to figures/
# =============================================================================

# Source setup script
source(here::here("scripts", "00_setup.R"))

cat("\n=== Starting Exploratory Data Analysis ===\n\n")

# ---- Load Processed Data ----
cat("Loading processed data...\n")
processed_files <- list.files(
  path = data_processed,
  pattern = "_cleaned\\.rds$",
  full.names = TRUE
)

data_list <- list()
for (file in processed_files) {
  name <- str_replace(basename(file), "_cleaned\\.rds$", "")
  data_list[[name]] <- readRDS(file)
  cat("  Loaded:", name, "(", nrow(data_list[[name]]), "rows,", 
      ncol(data_list[[name]]), "columns)\n")
}

# ---- Helper Function for Saving Figures ----
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

# ---- 1. Data Overview ----
cat("\n=== 1. Data Overview ===\n")

# Summary statistics for all datasets
for (name in names(data_list)) {
  df <- data_list[[name]]
  
  # Create overview plot
  cat("  Creating overview for:", name, "\n")
  
  # Dataset dimensions info
  dims_df <- data.frame(
    Metric = c("Rows", "Columns"),
    Value = c(nrow(df), ncol(df))
  )
  
  p_dims <- ggplot(dims_df, aes(x = Metric, y = Value)) +
    geom_col(fill = "steelblue", alpha = 0.7) +
    labs(
      title = paste("Dataset Dimensions:", name),
      subtitle = paste("Rows:", nrow(df), "| Columns:", ncol(df)),
      x = "",
      y = "Count"
    ) +
    geom_text(aes(label = Value), vjust = -0.5)
  
  save_figure(p_dims, paste0(name, "_01_dimensions.png"))
}

# ---- 2. Missing Data Visualization ----
cat("\n=== 2. Missing Data Analysis ===\n")

for (name in names(data_list)) {
  df <- data_list[[name]]
  
  if (any(is.na(df))) {
    cat("  Analyzing missing data for:", name, "\n")
    
    # For large datasets, downsample or disable warning
    # vis_miss recommends < 50,000 rows for visualization
    max_rows_for_vis <- 50000
    
    if (nrow(df) > max_rows_for_vis) {
      cat("    Dataset large (", nrow(df), " rows). Downsampling for visualization...\n")
      # Downsample to a representative sample
      df_sample <- df %>%
        slice_sample(n = max_rows_for_vis, replace = FALSE)
      cat("    Using sample of", nrow(df_sample), "rows\n")
      
      # Create visualization with downsampled data
      missing_vis <- vis_miss(df_sample, warn_large_data = FALSE) +
        labs(
          title = paste("Missing Data Pattern:", name),
          subtitle = paste("Sample of", nrow(df_sample), "rows from", 
                           nrow(df), "total rows")
        )
    } else {
      # Use full dataset if it's small enough
      missing_vis <- vis_miss(df, warn_large_data = FALSE) +
        labs(title = paste("Missing Data Pattern:", name))
    }
    
    save_figure(missing_vis, paste0(name, "_02_missing_data.png"), 
                width = 12, height = 8)
    
    # Also create a summary table of missing data
    missing_summary <- df %>%
      summarise_all(~sum(is.na(.))) %>%
      pivot_longer(everything(), names_to = "Variable", values_to = "Missing_Count") %>%
      mutate(Missing_Percent = round(100 * Missing_Count / nrow(df), 2)) %>%
      filter(Missing_Count > 0) %>%
      arrange(desc(Missing_Count))
    
    if (nrow(missing_summary) > 0) {
      # Save missing data summary as CSV
      write_csv(missing_summary, 
                here(figures_dir, paste0(name, "_02_missing_summary.csv")))
      cat("    Saved missing data summary table\n")
    }
  } else {
    cat("  No missing data found in:", name, "\n")
  }
}

# ---- 3. Univariate Analysis ----
cat("\n=== 3. Univariate Analysis ===\n")

for (name in names(data_list)) {
  df <- data_list[[name]]
  cat("  Analyzing:", name, "\n")
  
  # Numeric columns
  numeric_cols <- df %>% 
    select(where(is.numeric)) %>% 
    names()
  
  if (length(numeric_cols) > 0) {
    # For large datasets, sample for visualization
    max_sample_size <- 50000
    
    # Distribution plots for first few numeric columns
    for (col in numeric_cols[1:min(5, length(numeric_cols))]) {
      # Sample if dataset is large
      if (nrow(df) > max_sample_size) {
        df_viz <- df %>% slice_sample(n = max_sample_size)
        subtitle_text <- paste(name, "- Sample of", max_sample_size, "rows")
      } else {
        df_viz <- df
        subtitle_text <- name
      }
      
      p_hist <- df_viz %>%
        ggplot(aes_string(x = col)) +
        geom_histogram(bins = 30, fill = "steelblue", alpha = 0.7, 
                      color = "white") +
        labs(
          title = paste("Distribution of", col),
          subtitle = subtitle_text,
          x = col,
          y = "Frequency"
        )
      
      save_figure(p_hist, paste0(name, "_03_hist_", col, ".png"))
    }
  }
  
  # Categorical columns
  factor_cols <- df %>% 
    select(where(is.factor)) %>% 
    names()
  
  if (length(factor_cols) > 0) {
    # Bar plots for first few categorical columns
    for (col in factor_cols[1:min(5, length(factor_cols))]) {
      p_bar <- df %>%
        count(.data[[col]]) %>%
        arrange(desc(n)) %>%
        slice_head(n = 20) %>%  # Top 20 categories
        ggplot(aes(x = reorder(.data[[col]], n), y = n)) +
        geom_col(fill = "steelblue", alpha = 0.7) +
        coord_flip() +
        labs(
          title = paste("Frequency of", col),
          subtitle = name,
          x = col,
          y = "Count"
        )
      
      save_figure(p_bar, paste0(name, "_04_bar_", col, ".png"), 
                  width = 10, height = 8)
    }
  }
}

# ---- 4. Bivariate Analysis (if main dataset exists) ----
cat("\n=== 4. Bivariate Analysis ===\n")

# If you have a joined main dataset, create relationship plots
# This is a placeholder - customize based on your analysis needs

if (length(data_list) > 1) {
  cat("  Multiple datasets available for relationship analysis\n")
  cat("  Note: Customize join logic and relationship plots as needed\n")
}

# ---- 5. Summary Statistics Tables ----
cat("\n=== 5. Summary Statistics ===\n")

for (name in names(data_list)) {
  df <- data_list[[name]]
  
  # Skim summary
  summary_stats <- skim(df)
  
  # Save as text file
  summary_file <- here(figures_dir, paste0(name, "_05_summary_stats.txt"))
  capture.output(print(summary_stats), file = summary_file)
  cat("  Saved summary stats:", name, "\n")
}

# ---- 6. Correlation Analysis (for numeric data) ----
cat("\n=== 6. Correlation Analysis ===\n")

for (name in names(data_list)) {
  df <- data_list[[name]]
  numeric_df <- df %>% select(where(is.numeric))
  
  if (ncol(numeric_df) > 1) {
    cat("  Creating correlation plot for:", name, "\n")
    
    cor_matrix <- cor(numeric_df, use = "complete.obs")
    
    # Convert to long format for plotting
    cor_long <- cor_matrix %>%
      as.data.frame() %>%
      rownames_to_column("Var1") %>%
      pivot_longer(-Var1, names_to = "Var2", values_to = "Correlation")
    
    p_cor <- ggplot(cor_long, aes(x = Var1, y = Var2, fill = Correlation)) +
      geom_tile(color = "white") +
      scale_fill_gradient2(low = "blue", high = "red", mid = "white",
                          midpoint = 0, limit = c(-1, 1), space = "Lab",
                          name = "Correlation") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1),
            axis.text.y = element_text(size = 8)) +
      labs(
        title = paste("Correlation Matrix:", name),
        x = "",
        y = ""
      ) +
      coord_fixed()
    
    save_figure(p_cor, paste0(name, "_06_correlation.png"), 
                width = 12, height = 10)
  }
}

# ---- 7. Time Series Analysis (if date columns exist) ----
cat("\n=== 7. Time Series Analysis ===\n")

for (name in names(data_list)) {
  df <- data_list[[name]]
  date_cols <- df %>% 
    select(where(~inherits(., "Date") || inherits(., "POSIXct"))) %>% 
    names()
  
  if (length(date_cols) > 0) {
    cat("  Found date columns in:", name, "\n")
    cat("    Date columns:", paste(date_cols, collapse = ", "), "\n")
    cat("  Note: Customize time series plots based on your analysis needs\n")
  }
}

# ---- EDA Summary ----
cat("\n=== EDA Complete ===\n")
cat("All figures saved to:", figures_dir, "\n")
cat("\nFigures generated:\n")
cat("  - Dataset dimensions\n")
cat("  - Missing data patterns\n")
cat("  - Univariate distributions (histograms and bar plots)\n")
cat("  - Summary statistics\n")
cat("  - Correlation matrices\n")
cat("\nNext steps:\n")
cat("  - Review figures in", figures_dir, "\n")
cat("  - Customize plots for specific research questions\n")
cat("  - Create Quarto report to document findings\n\n")

