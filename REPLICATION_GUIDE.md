# Replication Guide

## Prerequisites

### 1. Meta Content Library Access

Apply at [Meta Content Library](https://developers.facebook.com/docs/content-library). Approval typically takes 2-4 weeks.

**Limitations:**
- Data queries must be executed in the MCL web interface
- Raw post-level data cannot be bulk-exported
- Results may vary based on query date (posts can be deleted/unpublished)

### 2. R Environment (for Search 1 clustering)

```r
install.packages(c("dplyr", "httr", "jsonlite", "readr", "ggplot2",
                   "uwot", "cluster", "fpc", "clusterSim",
                   "patchwork", "igraph", "scales"))
```

**API Keys:** Scripts 01 and 05 require an OpenAI API key:
```r
# Add to ~/.Renviron (recommended)
OPENAI_API_KEY=your-key-here
```

### 3. Python Environment

```bash
pip install pandas numpy matplotlib seaborn
```

## Replication Steps

### Step 1: Execute MCL Searches

Use the exact queries from [SEARCH_QUERIES.md](SEARCH_QUERIES.md). For each search:

1. Log into MCL
2. Enter the query (hashtags with OR operators)
3. Set date range and language filter
4. Export results to CSV

### Step 2: Prepare Your Data

Place exported CSVs in a directory structure like:

```
/your/path/data/
├── search_1.csv
├── search_2.csv
├── search_3.csv
├── search_4.csv
├── search_5.csv
└── search_6.csv
```

### Step 3: Run Search 1 Clustering (R)

Navigate to `notebooks/R/` and run scripts sequentially:

```r
source("01_generate_embeddings.R")  # ~2-3 hours for 14k posts
source("02_umap_reduction.R")       # ~5-10 minutes
source("03_clustering.R")           # ~10-20 minutes
source("04_visualization.R")        # ~5 minutes
source("05_cluster_labeling.R")     # ~2-5 minutes
```

**Outputs:**
- `merged_df_with_clusters.csv` → Input for Python analysis
- `kmeans_optimization.png` → Parameter search diagnostics
- `umap_2d_visualization.png` → Cluster visualization
- `facebook_posts_clusters.graphml` → Gephi-compatible network file

See `notebooks/R/README.md` for full documentation.

### Step 4: Update File Paths

In each notebook, update the file path to point to your data:

```python
# Change this:
df = pd.read_csv('/content/drive/MyDrive/data/search_1_clustered.csv')

# To your path:
df = pd.read_csv('/your/path/data/merged_df_with_clusters.csv')
```

### Step 5: Run Python Analysis

**For Google Colab:**
1. Upload notebooks to Colab
2. Mount Google Drive (if storing data there)
3. Run cells sequentially

**For local Jupyter:**
1. Install requirements
2. Open notebooks
3. Run cells sequentially

## Expected Outputs

### Search 1 (Clustering)

**R pipeline:**
- Cluster assignments for 13,880 posts
- K-means optimization diagnostics (k=5 optimal)
- 2D UMAP visualization
- GPT-4 generated cluster labels

**Python analysis:**
- Cluster composition by actor type
- Temporal distribution by cluster
- Keyword prevalence per cluster

### Searches 2-6 (Reform Analysis)

- Posts per month by critical period
- Engagement metrics (mean, median, max)
- Top posting Pages
- Keyword prevalence

## Validation

Your results should approximately match:

| Search | Posts | Posts/Month (avg) |
|--------|-------|-------------------|
| 2 (BEPS 1.0) | ~155 | ~3.5 |
| 3 (TCJA) | ~1,584 | ~16 overall, ~266 peak |
| 4 (Tariffs T1) | ~4,777 | ~136 |
| 5 (BEPS 2.0) | ~266 | ~3.3 |
| 6 (Tariffs T2) | ~12,641 | ~2.7 Biden, ~1,221 Trump 2.0 |

Minor variations (±10%) are expected due to MCL data changes over time.

## Reproducibility Notes

- R scripts use `RANDOM_SEED = 42` for reproducible results
- K-means uses 50 independent initializations (`nstart = 50`)
- GPT-4 labeling may vary slightly between runs (`temperature = 0.7`)
- Embeddings are deterministic for the same input text
