# =============================================================================
# Fix renv Setup Script
# =============================================================================
# Run this script if you're having issues with renv.lock
# =============================================================================

cat("\n=== Fixing renv Setup ===\n\n")

# Check if renv is installed
if (!requireNamespace("renv", quietly = TRUE)) {
  cat("Installing renv package...\n")
  install.packages("renv")
}

library(renv)

# Option 1: Delete and reinitialize renv
cat("\nOption 1: Clean reinitialize renv\n")
cat("This will delete the existing renv setup and create a fresh one.\n")
cat("Type 'yes' to proceed, or 'no' to skip.\n")

# For automatic fixing (uncomment the next lines if you want to auto-fix):
# Unlink renv directories and lock file
if (file.exists("renv.lock") && file.size("renv.lock") == 0) {
  cat("\nDetected empty renv.lock file.\n")
  cat("Removing empty renv.lock...\n")
  file.remove("renv.lock")
}

if (dir.exists("renv") && length(list.files("renv")) == 0) {
  cat("Removing empty renv directory...\n")
  unlink("renv", recursive = TRUE)
}

# Now reinitialize
cat("\nReinitializing renv...\n")
cat("When prompted, choose:\n")
cat("  1. Use 'renv' with this project? (Yes)\n")
cat("  2. Restore packages? (Yes - will install required packages)\n\n")

# Run init
renv::init(restore = TRUE)

cat("\n=== renv Fixed ===\n")
cat("You can now run your analysis scripts.\n\n")

