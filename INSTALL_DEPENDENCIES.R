# =============================================================================
# Install Missing Dependencies
# =============================================================================
# Run this script to install missing package dependencies
# Especially useful if you get errors about missing packages like 'crayon'
# =============================================================================

cat("\n=== Installing Missing Dependencies ===\n\n")

# List of common dependencies that might be missing
common_dependencies <- c(
  "crayon",      # Color terminal output
  "cli",         # Command line interface tools
  "glue",        # String interpolation
  "rlang",       # Core tidyverse dependency
  "vctrs",       # Vector types
  "pillar",      # Data frame formatting
  "fansi",       # ANSI color support
  "utf8",        # UTF-8 text handling
  "magrittr"     # Pipe operator
)

# Install missing dependencies
cat("Installing common dependencies...\n")
for (pkg in common_dependencies) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("  Installing", pkg, "...\n")
    install.packages(pkg, dependencies = TRUE)
  } else {
    cat("  ✓", pkg, "already installed\n")
  }
}

# Also ensure all CRAN dependencies of tidyverse are installed
cat("\nEnsuring all tidyverse dependencies are installed...\n")
install.packages("tidyverse", dependencies = TRUE)

cat("\n=== Dependencies Installation Complete ===\n")
cat("Now try running: source('scripts/00_setup.R')\n\n")

