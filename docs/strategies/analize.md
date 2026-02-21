# SEStrategyAllocator — Improvement Analysis

## Status

| #   | Topic                                         | Status        | Priority |
| --- | --------------------------------------------- | ------------- | -------- |
| 1   | Forward Window Alignment                      | **COMPLETED** | High     |
| 2   | Confidence-Based Threshold ("no operar nada") | **NEXT**      | High     |
| 3   | Variance Penalization in Scoring              | Pending       | Medium   |

---

## 1. Forward Window Alignment

### Problem

The allocator recalculates every day but evaluates strategy performance over a fixed `forwardWindow = 4` days. This creates a training/inference mismatch.

### Analysis Results (BTCUSD, 10 strategies, 1450 days)

| Horizon | Correlation | Hit Rate (score>0 → perf>0) | Hit Rate (score<0 → perf<0) |
| ------- | ----------- | --------------------------- | --------------------------- |
| 1d      | 0.055       | 36%                         | 36%                         |
| 2d      | 0.373       | 48%                         | 49%                         |
| 3d      | 0.423       | 51%                         | 53%                         |
| 5d      | 0.578       | 58%                         | 61%                         |
| 10d     | 0.759       | 69%                         | 71%                         |

### Key Finding

1-day forward window has near-zero predictive power (correlation 0.055). The 3 macro features (rolling return, volatility, drawdown over 150-day window) capture market regime signals that operate at multi-day scales, not intraday.

### Decision: forwardWindow = 5

Route 1 selected: keep daily re-evaluation, change forward window to 5 days.

- Correlation 0.578 — statistically significant
- Hit rate 58% — actionable with proper risk management
- Daily re-evaluation still catches regime changes (features are 150-day rolling, shift slowly)
- No architectural changes needed

### Changes Applied

- `Horizon.mq5`: `AllocatorForwardWindow` default 4 → 5
- `storage/sets/Live.set`: `AllocatorForwardWindow` 4 → 5

### Distance Analysis

Neighbor distance does NOT significantly improve prediction quality. Close neighbors (below median distance) and far neighbors show similar correlation. This suggests distance-based confidence thresholds (Point 2) may not be effective with current features.

---

## 2. Confidence-Based Threshold ("no operar nada")

### Problem

Current threshold is 0.0 — any strategy with positive score gets activated. The system never decides "no strategy is appropriate today".

### Core Question

Is there a threshold value where the score becomes statistically predictive? Or is any threshold just arbitrary filtering (overfitting)?

### Data Available

The analysis export (`BTCUSD_Allocator_Analysis.json`) contains per-day:

- `scores[]`: KNN scores at horizons [1,2,3,5,10] per strategy (array[50])
- `forward_performances[]`: actual forward performance at same horizons (array[50])
- `score_stds[]`: standard deviation of forward performances across KNN neighbors (array[50])
- `avg_neighbor_distance`: average distance to K nearest neighbors

### What We Need to Study

- Distribution of KNN scores across all historical days
- Correlation between score magnitude and actual forward performance
- Whether higher scores reliably predict better outcomes or if it's noise
- Out-of-sample validation: does a threshold found in one period hold in another?
- Walk-forward analysis to avoid overfitting

### Status: Ready for analysis after next training backtest

---

## 3. Variance Penalization in Scoring

### Problem

Two strategies can have the same KNN score but very different consistency across neighbors. The current system does not distinguish between consistent and volatile performance among similar historical conditions.

### Concept

```
adjusted_score = mean_score - lambda * score_std
```

### Data Available

`score_stds[]` in the analysis export captures per-neighbor performance standard deviation for each strategy at each horizon.

### Status: Waiting for Point 2 completion
