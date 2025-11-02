# =============================================================================
# Master Script - Run All Analysis Steps
# =============================================================================
# Run this script to execute the entire data exploration workflow
# Or run each script individually in order
# =============================================================================

cat("\n")
cat("========================================\n")
cat("  Big Data Project - Full Workflow\n")
cat("========================================\n\n")

# Step 1: Setup
cat("Step 1: Setting up environment...\n")
source(here::here("scripts", "00_setup.R"))
cat("✓ Setup complete\n\n")

# Step 2: Data Ingestion
cat("Step 2: Ingesting data...\n")
source(here::here("scripts", "01_ingest.R"))
cat("✓ Ingestion complete\n\n")

# Step 3: Data Cleaning
cat("Step 3: Cleaning data...\n")
source(here::here("scripts", "02_clean.R"))
cat("✓ Cleaning complete\n\n")

# Step 4: Exploratory Data Analysis
cat("Step 4: Running exploratory data analysis...\n")
source(here::here("scripts", "03_eda.R"))
cat("✓ EDA complete\n\n")

cat("========================================\n")
cat("  All Analysis Steps Complete!\n")
cat("========================================\n")
cat("Check the 'figures/' folder for all generated plots.\n")
cat("Check the 'data/processed/' folder for cleaned datasets.\n")
cat("\nNext: Review figures and customize analysis as needed.\n\n")

