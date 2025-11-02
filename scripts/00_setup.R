# =============================================================================
# Setup Script
# =============================================================================
# This script initializes the R environment for the Big Data project
# Run this script first before any other analysis scripts
# =============================================================================

# ---- Package Management with renv ----
# Check if renv is available and properly initialized
if (requireNamespace("renv", quietly = TRUE)) {
  # Check if renv.lock exists and is valid
  lockfile <- here::here("renv.lock")
  if (file.exists(lockfile) && file.size(lockfile) > 0) {
    # Try to restore packages from lockfile
    tryCatch({
      renv::restore(prompt = FALSE)
    }, error = function(e) {
      cat("Note: renv restore encountered an issue. Continuing with manual package installation.\n")
      cat("Error:", e$message, "\n")
    })
  } else {
    cat("Note: renv.lock is empty or missing. Continuing without renv.\n")
    cat("To initialize renv later, run: renv::init()\n\n")
  }
}

# ---- Install and Load Required Packages ----
required_packages <- c(
  # Core data manipulation
  "tidyverse",      # dplyr, ggplot2, readr, etc.
  "janitor",        # clean_names() and other cleaning utilities
  "here",           # path management
  
  # Data exploration
  "skimr",          # summary statistics
  "naniar",         # missing data visualization
  "GGally",         # extended ggplot2 plots
  
  # Reporting
  "quarto",         # Quarto documents
  "knitr",          # document rendering
  
  # Utilities
  "lubridate",      # date/time handling
  "scales"          # axis formatting
)

# Function to install missing packages with dependencies
install_if_missing <- function(packages) {
  installed <- installed.packages()[,"Package"]
  new_packages <- packages[!(packages %in% installed)]
  if(length(new_packages) > 0) {
    cat("Installing packages:", paste(new_packages, collapse = ", "), "\n")
    install.packages(new_packages, dependencies = TRUE)
    cat("Package installation complete.\n\n")
  }
}

# Install missing packages (with dependencies)
install_if_missing(required_packages)

# Function to safely load packages with dependency checking
load_package_safely <- function(package) {
  if (!require(package, character.only = TRUE, quietly = TRUE)) {
    cat("Package", package, "failed to load. Attempting to install dependencies...\n")
    # Try to install dependencies
    install.packages(package, dependencies = TRUE)
    # Try loading again
    if (!require(package, character.only = TRUE, quietly = TRUE)) {
      stop("Failed to load package: ", package, 
           "\nPlease install it manually: install.packages('", package, "')")
    }
  }
}

# Load all packages with error handling
cat("Loading packages...\n")
for (pkg in required_packages) {
  tryCatch({
    load_package_safely(pkg)
    cat("  ✓", pkg, "\n")
  }, error = function(e) {
    cat("  ✗", pkg, "- Error:", e$message, "\n")
  })
}
cat("\n")

# ---- Global Options ----
# Set random seed for reproducibility
set.seed(1234)

# Set default ggplot2 theme
theme_set(theme_minimal(base_size = 12) +
          theme(
            plot.title = element_text(face = "bold", size = 14),
            plot.subtitle = element_text(size = 11),
            axis.title = element_text(size = 11),
            legend.position = "bottom"
          ))

# Set knitr options for reports
if (knitr::is_html_output()) {
  knitr::opts_chunk$set(
    echo = TRUE,
    warning = FALSE,
    message = FALSE,
    fig.width = 10,
    fig.height = 6,
    fig.path = here("figures/")
  )
}

# ---- Project Paths ----
# Define key directories using here::here()
project_root <- here::here()
data_raw <- here("data", "raw")
data_interim <- here("data", "cleaned")
data_processed <- here("data", "processed")
figures_dir <- here("figures")
reports_dir <- here("reports")

# Create directories if they don't exist
dirs_to_create <- c(data_interim, data_processed, figures_dir, reports_dir)
for (dir in dirs_to_create) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }
}

# ---- Helper Functions ----
# Print session info for reproducibility
print_session_info <- function() {
  cat("\n=== Session Info ===\n")
  print(sessionInfo())
  cat("\n=== Working Directory ===\n")
  cat(here::here(), "\n\n")
}

# Print project structure
print_project_structure <- function() {
  cat("\n=== Project Structure ===\n")
  cat("Project Root:", project_root, "\n")
  cat("Raw Data:", data_raw, "\n")
  cat("Interim Data:", data_interim, "\n")
  cat("Processed Data:", data_processed, "\n")
  cat("Figures:", figures_dir, "\n")
  cat("Reports:", reports_dir, "\n\n")
}

# ---- Print Initialization Message ----
cat("\n")
cat("========================================\n")
cat("  Big Data Project - Environment Setup\n")
cat("========================================\n")
print_project_structure()
print_session_info()
cat("Setup complete! Ready to begin analysis.\n")
cat("========================================\n\n")

