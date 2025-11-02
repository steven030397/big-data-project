# =============================================================================
# Data Cleaning Script
# =============================================================================
# This script cleans and joins the data files
# Output: Cleaned and processed data saved to data/processed/
# =============================================================================

# Source setup script
source(here::here("scripts", "00_setup.R"))

cat("\n=== Starting Data Cleaning ===\n\n")

# ---- Load Interim Data ----
cat("Loading interim data...\n")
interim_files <- list.files(
  path = data_interim,
  pattern = "_interim\\.rds$",
  full.names = TRUE
)

data_list <- list()
for (file in interim_files) {
  name <- str_replace(basename(file), "_interim\\.rds$", "")
  data_list[[name]] <- readRDS(file)
  cat("  Loaded:", name, "(", nrow(data_list[[name]]), "rows)\n")
}

# ---- Data Cleaning Steps ----
cat("\n=== Cleaning Data ===\n")

# Example cleaning operations (customize based on your data):
# 1. Handle date columns
# 2. Convert appropriate columns to factors
# 3. Handle missing values
# 4. Standardize text fields
# 5. Create derived variables

cleaned_data <- data_list

for (name in names(cleaned_data)) {
  cat("  Cleaning:", name, "\n")
  df <- cleaned_data[[name]]
  
  # Convert date columns (adjust column names as needed)
  date_cols <- grep("date|time", names(df), value = TRUE, ignore.case = TRUE)
  for (col in date_cols) {
    if (is.character(df[[col]]) || inherits(df[[col]], "Date")) {
      df[[col]] <- lubridate::parse_date_time(df[[col]], 
                                               orders = c("ymd", "dmy", "mdy", "ymd HMS"))
    }
  }
  
  # Convert ID columns to appropriate types
  id_cols <- grep("^id$|_id$|^key$|_key$", names(df), value = TRUE, ignore.case = TRUE)
  for (col in id_cols) {
    if (is.character(df[[col]])) {
      # Check if it's numeric-looking
      if (all(grepl("^[0-9]+$", na.omit(df[[col]])))) {
        df[[col]] <- as.integer(df[[col]])
      }
    }
  }
  
  # Convert appropriate columns to factors (columns with low cardinality)
  # Adjust threshold as needed
  factor_threshold <- 50
  for (col in names(df)) {
    if (is.character(df[[col]]) && 
        length(unique(df[[col]])) <= factor_threshold &&
        !col %in% id_cols) {
      df[[col]] <- as.factor(df[[col]])
      cat("    Converted to factor:", col, "(", length(levels(df[[col]])), "levels)\n")
    }
  }
  
  cleaned_data[[name]] <- df
}

# ---- Data Joining (if applicable) ----
cat("\n=== Joining Data ===\n")
cat("Note: Customize join logic based on your data structure\n")

# Example: If accident.csv has ID columns that link to other tables
# Adjust based on your actual data structure

# Check for common keys
if ("accident" %in% names(cleaned_data)) {
  accident_df <- cleaned_data[["accident"]]
  cat("  Accident table:", nrow(accident_df), "rows\n")
  
  # Identify potential join keys
  accident_id_cols <- grep("id|key", names(accident_df), 
                           value = TRUE, ignore.case = TRUE)
  cat("  Potential join keys in accident:", 
      paste(accident_id_cols, collapse = ", "), "\n")
}

# Example join structure (customize as needed):
# main_dataset <- cleaned_data[["accident"]] %>%
#   left_join(cleaned_data[["accident_location"]], by = "accident_id") %>%
#   left_join(cleaned_data[["accident_event"]], by = "accident_id") %>%
#   left_join(cleaned_data[["atmospheric_cond"]], by = "accident_id") %>%
#   left_join(cleaned_data[["road_surface_cond"]], by = "accident_id") %>%
#   left_join(cleaned_data[["person"]], by = "accident_id") %>%
#   left_join(cleaned_data[["node"]], by = "node_id") %>%
#   left_join(cleaned_data[["sub_dca"]], by = "sub_dca_id")

# ---- Missing Data Analysis ----
cat("\n=== Missing Data Analysis ===\n")
for (name in names(cleaned_data)) {
  df <- cleaned_data[[name]]
  missing_pct <- round(100 * sum(is.na(df)) / (nrow(df) * ncol(df)), 2)
  cat("  ", name, ":", missing_pct, "% missing\n")
  
  # Identify columns with high missingness
  cols_with_na <- colSums(is.na(df))
  high_missing <- names(cols_with_na[cols_with_na > 0.5 * nrow(df)])
  if (length(high_missing) > 0) {
    cat("    High missingness (>50%):", paste(high_missing, collapse = ", "), "\n")
  }
}

# ---- Save Cleaned Data ----
cat("\n=== Saving Cleaned Data ===\n")
for (name in names(cleaned_data)) {
  output_file <- here(data_processed, paste0(name, "_cleaned.rds"))
  saveRDS(cleaned_data[[name]], output_file)
  cat("  Saved:", name, "\n")
}

# Also save as CSV for easy inspection (optional)
for (name in names(cleaned_data)) {
  if (nrow(cleaned_data[[name]]) < 100000) {  # Only save if not too large
    output_file <- here(data_processed, paste0(name, "_cleaned.csv"))
    write_csv(cleaned_data[[name]], output_file)
  }
}

# ---- Save Cleaning Metadata ----
cleaning_metadata <- list(
  cleaning_date = Sys.Date(),
  datasets_cleaned = names(cleaned_data),
  cleaning_steps = list(
    date_parsing = "Applied to date/time columns",
    factor_conversion = "Low cardinality character columns converted to factors",
    missing_data_analysis = "Analyzed missing data patterns"
  )
)

saveRDS(cleaning_metadata, here(data_processed, "cleaning_metadata.rds"))

cat("\n=== Cleaning Complete ===\n")
cat("Cleaned data saved to:", data_processed, "\n\n")

# Optional: Attach to global environment for interactive use
if (interactive()) {
  list2env(cleaned_data, envir = .GlobalEnv)
  cat("Cleaned data frames attached to global environment.\n\n")
}

