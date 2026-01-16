# Programmed Visibility

Replication materials for: **"Programmed Visibility. Tax Reform Legitimacy between Strategic Opacity and Platform Circulation"**

## Overview

This repository contains the analytical code for examining visibility patterns of tax and trade governance reforms on Facebook. The study uses data from the Meta Content Library (MCL) to analyze 19,423 posts across three reform types:

| Configuration | Reform | Pattern |
|---------------|--------|---------|
| Strategic Opacity | BEPS 1.0 & 2.0 | ~3 posts/month regardless of political moments |
| Temporary Forced Visibility | TCJA | 266 posts/month spike → 99% decline |
| Mobilization-Dependent | Tariffs | 452× differential (Biden vs Trump 2.0) |

## Repository Structure

```
programmed-visibility/
├── README.md                    # This file
├── REPLICATION_GUIDE.md         # Step-by-step replication instructions
├── SEARCH_QUERIES.md            # Exact MCL query specifications
├── requirements.txt             # Python dependencies
└── notebooks/
    ├── R/                       # Search 1 clustering pipeline
    │   ├── README.md            # R pipeline documentation
    │   ├── 01_generate_embeddings.R
    │   ├── 02_umap_reduction.R
    │   ├── 03_clustering.R
    │   ├── 04_visualization.R
    │   └── 05_cluster_labeling.R
    ├── Clustering_search_1.ipynb      # Search 1: Cluster composition analysis
    └── Searches_2-6_analysis.ipynb    # Searches 2-6: Reform-specific analysis
```

## Analysis Pipeline

**Stage 1: Search 1 Clustering (R)**
1. `01_generate_embeddings.R` → OpenAI embeddings (text-embedding-3-small)
2. `02_umap_reduction.R` → UMAP dimensionality reduction (1536D → 50D)
3. `03_clustering.R` → K-means clustering with optimization
4. `04_visualization.R` → 2D UMAP visualization + Gephi export
5. `05_cluster_labeling.R` → GPT-4 cluster labeling

**Stage 2: Analysis (Python)**
- `Clustering_search_1.ipynb` → Cluster composition analysis
- `Searches_2-6_analysis.ipynb` → Reform-specific visibility patterns

See `notebooks/R/README.md` for detailed R pipeline documentation.

## Data Summary

| Search | Reform | Posts | Date Range |
|--------|--------|-------|------------|
| 1 | Field mapping | 13,880 | 2013–2025 |
| 2 | BEPS 1.0 | 155 | 2013–2016 |
| 3 | TCJA | 1,584 | 2017–2025 |
| 4 | Tariffs Trump 1.0 | 4,777 | 2018–2020 |
| 5 | BEPS 2.0 / Pillar Two | 266 | 2019–2025 |
| 6 | Tariffs Biden/Trump 2.0 | 12,641 | 2021–2025 |

See [SEARCH_QUERIES.md](SEARCH_QUERIES.md) for exact query specifications.

## Data Access

**Important:** Replication requires approved researcher access to the [Meta Content Library](https://developers.facebook.com/docs/content-library).

- Raw post-level data cannot be downloaded
- Queries must be executed within the MCL environment
- Each researcher must collect their own data using the provided query specifications

## Requirements

**Python:**
```
pandas>=1.5.0
numpy>=1.21.0
matplotlib>=3.5.0
seaborn>=0.12.0
```

**R (for Search 1 clustering):**
```r
install.packages(c("dplyr", "httr", "jsonlite", "readr", "ggplot2",
                   "uwot", "cluster", "fpc", "clusterSim",
                   "patchwork", "igraph", "scales"))
```

R scripts also require an OpenAI API key—see `notebooks/R/README.md` for setup.

## Quick Start

1. Obtain MCL access
2. Execute searches using specifications in `SEARCH_QUERIES.md`
3. Export results to CSV
4. **For Search 1:** Run R scripts sequentially (`notebooks/R/`)
5. Run Python notebooks
6. Update file paths as needed

See [REPLICATION_GUIDE.md](REPLICATION_GUIDE.md) for detailed instructions.

## Citation

Citation details will be provided upon publication.

## License

MIT
