# Machine Learning Models Summary

## Overview
- **Total Models:** 5
- **Data Split:** 70% training / 30% testing
- **Random Seed:** 1234
- **Task Types:** Binary classification (4 models) and Multi-class classification (1 model)

---

## Model 1: Logistic Regression (Fatal Crash Prediction)

### **Target Variable:**
- `is_fatal` (Binary: 0 = Non-fatal, 1 = Fatal)

### **Predictors (9 features):**
1. `area_type` (Factor: Urban/Rural)
2. `hour_group` (Factor: Morning_Rush, Midday, Afternoon_Rush, Evening, Night_Late_Night)
3. `day_of_week` (Factor: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday)
4. `season` (Factor: Summer, Autumn, Winter, Spring)
5. `accident_type_desc` (Factor: Various crash types)
6. `atmosph_cond_desc` (Factor: Atmospheric conditions)
7. `surface_cond_desc` (Factor: Road surface conditions)
8. `no_of_vehicles` (Numeric)
9. `speed_zone` (Numeric)

### **Model Setup:**
- **Algorithm:** Logistic Regression (GLM)
- **Family:** Binomial (logit link)
- **Formula:** `is_fatal ~ .` (all features)
- **Threshold:** 0.5 (for binary classification)
- **Data Filtering:** Removes rows with missing `atmosph_cond_desc` or `surface_cond_desc`

### **Training Data:**
- Uses `train_fatal` dataset
- Features: All 9 predictors listed above

---

## Model 2: Random Forest (Fatal Crash Prediction)

### **Target Variable:**
- `is_fatal` (Binary: 0 = Non-fatal, 1 = Fatal)

### **Predictors (9 features):**
Same as Model 1:
1. `area_type`
2. `hour_group`
3. `day_of_week`
4. `season`
5. `accident_type_desc`
6. `atmosph_cond_desc`
7. `surface_cond_desc`
8. `no_of_vehicles`
9. `speed_zone`

### **Model Setup:**
- **Algorithm:** Random Forest
- **Number of Trees:** 100 (`ntree = 100`)
- **Importance Calculation:** Enabled (`importance = TRUE`)
- **Formula:** `as.factor(is_fatal) ~ .` (all features)
- **Data Filtering:** Removes rows with missing `atmosph_cond_desc` or `surface_cond_desc`

### **Training Data:**
- Uses `train_fatal` dataset (same as Model 1)

---

## Model 3: Random Forest (Severity Category Prediction)

### **Target Variable:**
- `severity_category` (Multi-class: Fatal, Serious, Minor, Property_Damage)

### **Predictors (9 features):**
Same 9 features as Models 1 & 2:
1. `area_type`
2. `hour_group`
3. `day_of_week`
4. `season`
5. `accident_type_desc`
6. `atmosph_cond_desc`
7. `surface_cond_desc`
8. `no_of_vehicles`
9. `speed_zone`

### **Model Setup:**
- **Algorithm:** Random Forest
- **Number of Trees:** 100 (`ntree = 100`)
- **Importance Calculation:** Enabled (`importance = TRUE`)
- **Formula:** `severity_category ~ .` (all features)
- **Data Filtering:** 
  - Removes rows with missing `atmosph_cond_desc` or `surface_cond_desc`
  - Removes rows with missing `severity_category`
  - Removes rows where `severity_category == "Unknown"`

### **Training Data:**
- Uses `train_severity` dataset
- Same 9 features as Models 1 & 2

---

## Model 4: Random Forest - Urban (Fatal Crash Prediction)

### **Target Variable:**
- `is_fatal` (Binary: 0 = Non-fatal, 1 = Fatal)

### **Predictors (8 features):**
1. `hour_group`
2. `day_of_week`
3. `season`
4. `accident_type_desc`
5. `atmosph_cond_desc`
6. `surface_cond_desc`
7. `no_of_vehicles`
8. `speed_zone`

**Note:** `area_type` is EXCLUDED because data is filtered to Urban only

### **Model Setup:**
- **Algorithm:** Random Forest
- **Number of Trees:** 100 (`ntree = 100`)
- **Importance Calculation:** Enabled (`importance = TRUE`)
- **Formula:** `as.factor(is_fatal) ~ .` (8 features, excludes `area_type`)
- **Data Filtering:** 
  - Only Urban crashes: `area_type == "Urban"`
  - Removes rows with missing `atmosph_cond_desc` or `surface_cond_desc`

### **Training Data:**
- Uses `train_urban` (filtered from `train_fatal` where `area_type == "Urban"`)

---

## Model 5: Random Forest - Rural (Fatal Crash Prediction)

### **Target Variable:**
- `is_fatal` (Binary: 0 = Non-fatal, 1 = Fatal)

### **Predictors (8 features):**
Same as Model 4:
1. `hour_group`
2. `day_of_week`
3. `season`
4. `accident_type_desc`
5. `atmosph_cond_desc`
6. `surface_cond_desc`
7. `no_of_vehicles`
8. `speed_zone`

**Note:** `area_type` is EXCLUDED because data is filtered to Rural only

### **Model Setup:**
- **Algorithm:** Random Forest
- **Number of Trees:** 100 (`ntree = 100`)
- **Importance Calculation:** Enabled (`importance = TRUE`)
- **Formula:** `as.factor(is_fatal) ~ .` (8 features, excludes `area_type`)
- **Data Filtering:** 
  - Only Rural crashes: `area_type == "Rural"`
  - Removes rows with missing `atmosph_cond_desc` or `surface_cond_desc`

### **Training Data:**
- Uses `train_rural` (filtered from `train_fatal` where `area_type == "Rural"`)

---

## Summary Table

| Model | Algorithm | Target | Classes | Predictors | Trees | Data Filter |
|-------|-----------|--------|---------|------------|-------|-------------|
| 1. Logistic Regression | GLM (Binomial) | `is_fatal` | Binary (0/1) | 9 features | N/A | Remove NA atmospheric/surface |
| 2. Random Forest (Fatal) | Random Forest | `is_fatal` | Binary (0/1) | 9 features | 100 | Remove NA atmospheric/surface |
| 3. Random Forest (Severity) | Random Forest | `severity_category` | Multi-class (4) | 9 features | 100 | Remove NA + Unknown severity |
| 4. Random Forest (Urban) | Random Forest | `is_fatal` | Binary (0/1) | 8 features | 100 | Urban only + Remove NA |
| 5. Random Forest (Rural) | Random Forest | `is_fatal` | Binary (0/1) | 8 features | 100 | Rural only + Remove NA |

---

## Feature Descriptions

1. **`area_type`**: Urban vs Rural classification
2. **`hour_group`**: Time periods (Morning Rush 6-9, Midday 10-14, Afternoon Rush 15-18, Evening 19-22, Night/Late Night 23-5)
3. **`day_of_week`**: Monday through Sunday
4. **`season`**: Summer, Autumn, Winter, Spring
5. **`accident_type_desc`**: Crash type classification (factor)
6. **`atmosph_cond_desc`**: Atmospheric conditions at time of crash (factor)
7. **`surface_cond_desc`**: Road surface conditions (factor)
8. **`no_of_vehicles`**: Number of vehicles involved (numeric)
9. **`speed_zone`**: Speed zone limit (numeric)

---

## Data Split Details

- **Train/Test Split**:** 70%/30%
- **Random Seed**: 1234 (for reproducibility)
- **Stratification**: None (simple random sampling)

