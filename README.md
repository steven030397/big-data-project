# Big Data Project - Data Exploration

## Project Overview

This project explores accident and traffic data using R for exploratory data analysis (EDA).

## Project Structure

```
big-data-project/
├── data/
│   ├── raw/              # Original CSV files (read-only)
│   ├── cleaned/           # Interim data after ingestion
│   └── processed/         # Cleaned and joined datasets
├── scripts/
│   ├── 00_setup.R         # Environment setup and package loading
│   ├── 01_ingest.R        # Data ingestion from raw files
│   ├── 02_clean.R         # Data cleaning and joining
│   └── 03_eda.R           # Exploratory data analysis and figures
├── figures/               # All generated plots and visualizations
├── reports/               # Quarto/R Markdown reports
└── README.md             # This file
```

## Getting Started

### Prerequisites

- R (version 4.0 or higher)
- RStudio (recommended)
- `renv` package for package management

### Setup Instructions

1. **Open the RStudio Project**
   - Open `big-data-project.Rproj` in RStudio

2. **Initialize renv (first time only)**
   ```r
   install.packages("renv")
   renv::init()
   renv::restore()
   ```

3. **Run scripts in order**
   ```r
   source("scripts/00_setup.R")    # Setup environment
   source("scripts/01_ingest.R")    # Load raw data
   source("scripts/02_clean.R")     # Clean and prepare data
   source("scripts/03_eda.R")       # Generate exploratory plots
   ```

## Data Files

The following raw data files are available in `data/raw/`:

- `accident.csv`
- `accident_event.csv`
- `accident_location.csv`
- `atmospheric_cond.csv`
- `node.csv`
- `person.csv`
- `road_surface_cond.csv`
- `sub_dca.csv`

## Workflow

1. **Setup** (`00_setup.R`)
   - Loads required packages
   - Sets global options (theme, seed, etc.)
   - Creates necessary directories

2. **Ingestion** (`01_ingest.R`)
   - Reads all CSV files from `data/raw/`
   - Performs basic inspection
   - Saves interim data to `data/cleaned/`

3. **Cleaning** (`02_clean.R`)
   - Handles missing values
   - Converts data types (dates, factors)
   - Joins related tables
   - Saves processed data to `data/processed/`

4. **EDA** (`03_eda.R`)
   - Generates overview plots
   - Missing data visualization
   - Univariate distributions
   - Bivariate relationships
   - Correlation analysis
   - Saves all figures to `figures/`

## Output

- **Figures**: All plots are saved in `figures/` directory
- **Processed Data**: Cleaned datasets in `data/processed/`
- **Reports**: Analysis reports (when created) in `reports/`

## Packages Used

Core packages:
- `tidyverse` - Data manipulation and visualization
- `janitor` - Data cleaning utilities
- `skimr` - Summary statistics
- `naniar` - Missing data analysis
- `quarto` - Report generation

See `scripts/00_setup.R` for complete list.

## Notes

- Raw data files in `data/raw/` are read-only - never modify them
- Intermediate files are saved as `.rds` for efficient storage
- All scripts use `here::here()` for path management
- Figures are saved with descriptive names following the pattern: `dataset_type_description.png`

## Contributing

When making changes:
1. Update relevant scripts
2. Re-run scripts in order to regenerate outputs
3. Commit scripts and configuration files
4. Do not commit large data files or figures (see `.gitignore`)

## License

[Add license information if applicable]

