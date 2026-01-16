# R Pipeline for Search 1 Clustering Analysis

This directory contains the R scripts used for the clustering analysis of Search 1 (field mapping) in the study "Programmed Visibility: Tax Reform Legitimacy between Strategic Opacity and Platform Circulation."

## Overview

The pipeline performs semantic clustering of 13,880 Facebook posts to identify thematic groupings in global tax reform discourse. It uses:

- **OpenAI embeddings** (`text-embedding-3-small`) for semantic representation
- **UMAP** for dimensionality reduction (1536D → 50D → 2D)
- **K-means** for clustering with systematic parameter optimization
- **GPT-4** for interpretable cluster labeling

## Pipeline Structure

```
R/
├── 01_generate_embeddings.R   # Generate text embeddings via OpenAI API
├── 02_umap_reduction.R        # Reduce dimensions: 1536D → 50D
├── 03_clustering.R            # K-means clustering with optimization
├── 04_visualization.R         # 2D UMAP visualization + Gephi export
├── 05_cluster_labeling.R      # Automatic labeling with GPT-4
└── README.md                  # This file
```

## Requirements

### R Packages

```r
# Core dependencies
install.packages(c("dplyr", "httr", "jsonlite", "readr", "ggplot2"))

# UMAP
install.packages("uwot")

# Clustering
install.packages(c("cluster", "fpc", "clusterSim"))

# Visualization
install.packages(c("patchwork", "igraph", "scales"))
```

### API Keys

Scripts 01 and 05 require an OpenAI API key:

```r
# Option 1: Set in script (not recommended for shared code)
Sys.setenv(OPENAI_API_KEY = "your-key-here")

# Option 2: Add to ~/.Renviron (recommended)
# OPENAI_API_KEY=your-key-here
```

## Usage

Run scripts sequentially:

```r
source("01_generate_embeddings.R")  # ~2-3 hours for 14k posts
source("02_umap_reduction.R")       # ~5-10 minutes
source("03_clustering.R")           # ~10-20 minutes
source("04_visualization.R")        # ~5 minutes
source("05_cluster_labeling.R")     # ~2-5 minutes
```

### Input

- `search_1.csv`: Raw posts from Meta Content Library (see `SEARCH_QUERIES.md`)

### Outputs

| File | Description |
|------|-------------|
| `merged_df_with_embeddings.rds` | Posts with 1536D embeddings |
| `embedding_umap_50d.rds` | 50D UMAP matrix |
| `merged_df_with_clusters.csv` | Posts with cluster assignments |
| `cluster_labels.csv` | Cluster ID → label mapping |
| `kmeans_optimization.png` | Parameter search diagnostics |
| `umap_2d_visualization.png` | 2D cluster visualization |
| `facebook_posts_clusters.graphml` | Gephi-compatible network file |

## Method Details

### Embedding Generation (Script 01)

Uses OpenAI's `text-embedding-3-small` model (1536 dimensions) with:
- Batch processing (100 texts per API call)
- Automatic checkpointing for resilience
- Exponential backoff retry logic

### Dimensionality Reduction (Script 02)

UMAP parameters optimized for text embeddings:
- `n_neighbors = 30` (captures local + global structure)
- `min_dist = 0.1` (preserves cluster separation)
- `metric = cosine` (standard for semantic similarity)

First reduction: 1536D → 50D for clustering.

### Clustering (Script 03)

K-means clustering with systematic optimization:
- Grid search over k = 4–15 clusters
- Multi-metric evaluation:
  - **Silhouette** (35% weight): cluster cohesion
  - **Davies-Bouldin** (25% weight): cluster separation
  - **Calinski-Harabasz** (20% weight): variance structure
  - **BSS/TSS** (20% weight): variance explained
- Composite scoring identifies optimal k
- Final clustering with 50 random initializations for stability

Expected results: k=5 clusters with Silhouette ~0.465, Davies-Bouldin ~0.94, BSS/TSS ~79%.

### Visualization (Script 04)

- Second UMAP reduction: 50D → 2D for visualization
- GraphML export with node attributes for Gephi

### Labeling (Script 05)

GPT-4 generates interpretable labels by:
- Sampling 30 representative posts per cluster
- Prompting for specific, concrete thematic labels

## Reproducibility Notes

- Set `RANDOM_SEED = 42` for reproducible results
- K-means uses 50 independent initializations (`nstart = 50`)
- GPT-4 labeling may vary slightly between runs (temperature = 0.7)
- Embeddings are deterministic for the same input text

## Citation

If using this code, please cite the main paper (citation details upon publication).

## License

MIT

