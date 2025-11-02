# =============================================================================
# Data Ingestion Script
# =============================================================================
# This script reads raw data files and performs initial inspection
# Output: Interim data files saved to data/cleaned/
# =============================================================================

# Source setup script
source(here::here("scripts", "00_setup.R"))

cat("\n=== Starting Data Ingestion ===\n\n")

# ---- Read Raw Data Files ----
cat("Reading raw data files...\n")

# List all CSV files in data/raw
raw_files <- list.files(
  path = data_raw,
  pattern = "\\.csv$",
  full.names = TRUE
)

# Read each CSV file
data_list <- list()
for (file in raw_files) {
  file_name <- tools::file_path_sans_ext(basename(file))
  cat("  Reading:", file_name, "\n")
  
  # Read with readr for better type handling
  data_list[[file_name]] <- read_csv(
    file,
    show_col_types = FALSE,
    na = c("", "NA", "NULL", "null", "N/A", "n/a")
  )
  
  # Clean column names
  data_list[[file_name]] <- janitor::clean_names(data_list[[file_name]])
  
  # Print basic info
  cat("    Dimensions:", nrow(data_list[[file_name]]), "x", 
      ncol(data_list[[file_name]]), "\n")
}

# ---- Basic Data Inspection ----
cat("\n=== Data Summary ===\n")
for (name in names(data_list)) {
  cat("\n---", toupper(name), "---\n")
  cat("Rows:", nrow(data_list[[name]]), "\n")
  cat("Columns:", ncol(data_list[[name]]), "\n")
  cat("Column names:", paste(names(data_list[[name]]), collapse = ", "), "\n")
  
  # Check for common ID columns
  id_cols <- grep("id|key|code", names(data_list[[name]]), 
                  value = TRUE, ignore.case = TRUE)
  if (length(id_cols) > 0) {
    cat("Potential ID columns:", paste(id_cols, collapse = ", "), "\n")
  }
  
  # Missing data summary
  missing_count <- sum(is.na(data_list[[name]]))
  if (missing_count > 0) {
    cat("Missing values:", missing_count, "\n")
  }
}

# ---- Save Interim Data ----
cat("\n=== Saving Interim Data ===\n")
for (name in names(data_list)) {
  output_file <- here(data_interim, paste0(name, "_interim.rds"))
  saveRDS(data_list[[name]], output_file)
  cat("  Saved:", name, "\n")
}

# ---- Save Metadata ----
metadata <- list(
  ingestion_date = Sys.Date(),
  files_read = names(data_list),
  file_info = lapply(data_list, function(df) {
    list(
      nrows = nrow(df),
      ncols = ncol(df),
      colnames = names(df)
    )
  })
)

saveRDS(metadata, here(data_interim, "ingestion_metadata.rds"))

# ---- Return Data List for Next Script ----
cat("\n=== Ingestion Complete ===\n")
cat("Data loaded into memory as 'data_list'\n")
cat("Interim files saved to:", data_interim, "\n\n")

# Optional: Attach to global environment for interactive use
if (interactive()) {
  list2env(data_list, envir = .GlobalEnv)
  cat("Data frames attached to global environment.\n\n")
}

