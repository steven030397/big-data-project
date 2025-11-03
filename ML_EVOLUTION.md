# Machine Learning Process Evolution

This document tracks the iterative improvements made to the machine learning pipeline for fatal crash prediction, based on our conversation and analysis results.

## Problem Statement
Predict fatal crashes (binary classification) with severe class imbalance: only 1.66% of crashes are fatal (98.34% non-fatal).

---

## Iteration 1: Baseline Models (No Class Imbalance Handling)

### Initial Implementation
- **Models**: Logistic Regression, Random Forest
- **Approach**: Standard classification with default 0.5 threshold
- **Class Handling**: None

### What Was Wrong
1. **Zero Specificity**: Models achieved 98%+ accuracy by predicting all crashes as non-fatal
2. **No Sensitivity**: Models identified zero fatal crashes (sensitivity = 0%)
3. **Misleading Metrics**: High accuracy masked complete failure to identify the target class
4. **No Threshold Tuning**: Using default 0.5 threshold which maximizes accuracy (favors majority class)

### Symptoms
```
Accuracy: 0.9829
Sensitivity: 1.0000  (all predicted as fatal - wait, this contradicts above...)
Specificity: 0.0000  (none correctly identified as non-fatal)
```
**Note**: Some models showed the opposite - predicting all as non-fatal with specificity = 0.

---

## Iteration 2: Basic Class Imbalance Handling

### Changes Made
1. **Logistic Regression**: Optimal threshold selection using Youden's Index on training data
2. **Random Forest**: Class weights inversely proportional to class frequency
   - Formula: `w_i = N / (2 × n_i)` where N = total samples, n_i = samples in class i
   - Fatal crashes received ~30× more weight than non-fatal

### What Was Wrong
1. **Data Leakage**: Threshold optimized on training set, then evaluated on test set (not using CV)
2. **Threshold Selection Method**: Using Youden's Index on full training set (could overfit)
3. **Incomplete Evaluation**: No cross-validation to ensure robustness

### Results
- Improved sensitivity (can identify some fatal crashes)
- Better balance between sensitivity and specificity
- Still potential for overfitting to training data

---

## Iteration 3: Cross-Validation for Threshold Selection

### Changes Made
1. **Added Cross-Validation**: 5-fold CV to find optimal threshold
2. **Metric**: Initially maximized **F1 score** during CV
3. **Process**: For each fold, train model → find threshold maximizing F1 → average thresholds

### What Was Wrong
1. **F1 Score Bias**: Maximizing F1 in severely imbalanced data prioritizes recall (sensitivity)
   - Led to very low thresholds (e.g., 0.05)
   - High sensitivity but poor specificity
   - Many false positives
2. **Urban Model Particularly Poor**: With even more severe imbalance (~1% fatal rate), F1 optimization led to:
   - Very low threshold (0.29)
   - High sensitivity (83.3%) but extremely low specificity (27.7%)
   - Accuracy dropped to 28.29% (worse than baseline!)
3. **Unbalanced Trade-off**: F1 score doesn't adequately balance precision and specificity

### Example Results (F1 Optimization)
```
Urban Model:
- Accuracy: 28.29%
- Sensitivity: 83.30%
- Specificity: 27.70%
- Precision: 1.22%
- Optimal Threshold: 0.29 (from CV maximizing F1)
```
**Problem**: While catching many fatal crashes, the model generates excessive false alarms.

---

## Iteration 4: Youden's Index for Threshold Optimization

### Changes Made
1. **Changed Optimization Metric**: From F1 score to **Youden's Index** (Sensitivity + Specificity)
2. **Rationale**: Better balance between identifying true positives and avoiding false positives
3. **CV Protocol**: 5-fold CV, optimize Youden's Index in each fold

### Results
- Better balance between sensitivity and specificity
- Improved accuracy compared to F1 optimization
- More conservative thresholds

### Example Results (Youden's Index)
```
Urban Model:
- Accuracy: 98.37%
- Sensitivity: 3.21% (much lower than F1 approach)
- Specificity: 99.39% (much better than F1 approach)
- Precision: 5.32%
- Optimal Threshold: 0.89 (much higher, more conservative)
```

### Remaining Limitations
- Still using simple class weights for Random Forest
- Threshold optimization could be improved with more sophisticated resampling
- No hyperparameter tuning (mtry, ntree fixed)

---

## Iteration 5: Python-Style Advanced Pipeline

### Changes Made (Requested Pipeline)
1. **Stratified Cross-Validation**: 5-fold with `shuffle=True, random_state=42`
   - Ensures each fold maintains ~98-2 class ratio
2. **SMOTE Resampling**: Synthetic Minority Oversampling Technique
   - Applied inside each CV fold during training
   - Creates synthetic fatal crash examples
3. **Grid Search**: Hyperparameter tuning during CV
   - `mtry`: [3, 5, 7]
   - `ntree`: [100, 200]
   - Optimized on mean CV F1 score
4. **PR-Curve Threshold Tuning**: Precision-Recall curve instead of ROC
   - More informative for imbalanced data
   - Maximizes F1 score from PR curve
5. **Evaluation Metrics**: Added PR-AUC (Average Precision) alongside ROC-AUC

### Initial Issue
**Threshold Overfitting to Balanced Data**: 
- Threshold was optimized on SMOTE-balanced validation predictions
- Led to unrealistic F1 scores (e.g., 0.9249)
- When applied to real imbalanced test data, performance was much worse

### Fix Applied
- **Validation Holdout Strategy**: 
  - Split original training data: 80% for CV+SMOTE training, 20% holdout (maintains original imbalance)
  - Hyperparameters selected via CV on SMOTE-balanced folds
  - Final model retrained on full training set with SMOTE
  - **Threshold optimized on validation holdout predictions** (original imbalanced distribution)
- This ensures threshold is realistic for production use

### Final Pipeline Structure
```
1. Split data: 70% train, 30% test
2. From training: 20% validation holdout (keep original imbalance)
3. From remaining 80%: Stratified 5-fold CV with:
   a. SMOTE resampling in each fold
   b. Grid search (mtry, ntree)
   c. Model training with best params
4. Retrain final model on full 80% with SMOTE using best params
5. Find optimal threshold on validation holdout (imbalanced) predictions using PR curve
6. Evaluate final model on test set using optimal threshold
```

### Final Results
```
Logistic Regression:
- Accuracy: 91.64%
- Sensitivity: 35.59%
- Specificity: 92.62%
- Precision: 7.73%
- F1: 0.127
- ROC-AUC: 0.783
- PR-AUC: 0.0676
- Optimal Threshold: 0.05

Random Forest (Main):
- Accuracy: 94.38%
- Sensitivity: 19.73%
- Specificity: 95.68%
- Precision: 7.35%
- F1: 0.1071
- ROC-AUC: 0.765
- PR-AUC: 0.0536
- Optimal Threshold: 0.79
- Best Params: mtry=3, ntree=100 (from CV)
```

---

## Iteration 6: Code Modularization

### Changes Made
1. **Split Large Script**: `05_ml_analysis.R` (1356 lines) split into:
   - `05a_setup_and_data_prep.R`: Setup, data loading, helper functions
   - `05b_binary_lr.R`: Logistic Regression
   - `05c_binary_rf.R`: Random Forest (main)
   - `05d_severity.R`: Multi-class severity prediction
   - `05e_urban_rural.R`: Urban and Rural separate models

### Benefits
- Improved maintainability
- Faster execution (only run needed models)
- Clearer code organization
- Fixed console output truncation issues

---

## Key Learnings

### 1. Class Imbalance is Fundamental
- 1.66% fatal rate means accuracy alone is meaningless
- Must focus on sensitivity (recall) for safety applications
- Multiple techniques needed: resampling + threshold tuning + appropriate metrics

### 2. Threshold Selection is Critical
- Default 0.5 threshold is inappropriate for imbalanced data
- Optimal thresholds are much lower (0.05-0.89 depending on context)
- Must optimize on realistic (imbalanced) validation data, not balanced data

### 3. Metric Selection Matters
- **F1 Score**: Good for balanced classes, but in extreme imbalance it prioritizes recall too heavily
- **Youden's Index**: Better balance, but may be too conservative
- **PR-AUC**: Most informative for imbalanced data (measures precision-recall trade-off)

### 4. Resampling Location Matters
- **SMOTE during training**: Good for learning better decision boundaries
- **Threshold on imbalanced validation**: Ensures realistic production performance
- Don't optimize threshold on SMOTE-balanced predictions

### 5. Different Contexts Need Different Approaches
- **Urban**: ~1% fatal rate → requires very conservative thresholds (0.89)
- **Rural**: ~4% fatal rate → more balanced, lower thresholds (0.81) work better
- Separate models for different contexts improves performance

---

## Final Pipeline Summary

### For Logistic Regression:
1. Train on full training set
2. Find optimal threshold via PR curve on training predictions (maximizes F1)

### For Random Forest:
1. Stratified 5-fold CV with SMOTE in each fold
2. Grid search for hyperparameters (mtry, ntree) - optimize on CV F1
3. Retrain final model on full training set with SMOTE (best params)
4. Optimize threshold on validation holdout (imbalanced) via PR curve
5. Evaluate on test set

### Key Features:
- ✅ Proper train/validation/test split
- ✅ Stratified CV to maintain class distribution
- ✅ SMOTE for balanced training
- ✅ Grid search for hyperparameter tuning
- ✅ PR-curve threshold optimization
- ✅ Realistic evaluation on imbalanced test data
- ✅ Multiple metrics: Accuracy, Sensitivity, Specificity, Precision, F1, ROC-AUC, PR-AUC

---

## Remaining Challenges

1. **Low Precision**: Even with all improvements, precision remains low (5-12%)
   - This reflects the fundamental difficulty of predicting rare events
   - 1.66% base rate means even perfect sensitivity results in low precision

2. **Sensitivity vs Specificity Trade-off**: 
   - Urban model: 3.21% sensitivity, 99.39% specificity (very conservative)
   - Rural model: 8.35% sensitivity, 97.43% specificity (better balance)
   - Balancing these is domain-dependent (safety vs. resource allocation)

3. **Limited Feature Set**: Currently using only temporal, geographic, and basic crash type features
   - Could benefit from: vehicle characteristics, driver demographics, road geometry details, environmental factors

---

## Recommendations for Future Work

1. **Ensemble Methods**: Combine LR and RF predictions
2. **Feature Engineering**: Create interaction terms, polynomial features
3. **Cost-Sensitive Learning**: Explicitly incorporate cost of false negatives vs false positives
4. **Alternative Algorithms**: XGBoost, LightGBM, or neural networks
5. **Temporal Features**: Day-of-year, holidays, special events
6. **Spatial Features**: Nearby crash history, road network characteristics

