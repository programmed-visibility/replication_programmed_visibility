# ==============================================================================
# 02_umap_reduction.R
# Dimensionality reduction using UMAP (1536D -> 50D)
# ==============================================================================
#
# This script reduces the high-dimensional OpenAI embeddings (1536 dimensions)
# to 50 dimensions using UMAP, preparing data for clustering. The 50D
# representation preserves semantic structure while being computationally
# tractable for clustering algorithms.
#
# Input:  merged_df_with_embeddings.rds
# Output: embedding_umap_50d.rds, merged_df_pre_clustering.rds
#
# Requirements:
#   - R packages: uwot, dplyr
#
# ==============================================================================

library(uwot)
library(dplyr)

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

INPUT_FILE <- "merged_df_with_embeddings.rds"
OUTPUT_UMAP <- "embedding_umap_50d.rds"
OUTPUT_DF <- "merged_df_pre_clustering.rds"

# UMAP parameters optimized for text embeddings
UMAP_PARAMS <- list(
  n_neighbors = 30,      # Local neighborhood size (larger = more global structure)
  min_dist = 0.1,        # Minimum distance between points (controls clustering tightness)
  n_components = 50,     # Output dimensions for clustering
  metric = "cosine",     # Cosine similarity standard for text embeddings
  n_threads = 4          # Parallel threads (adjust to your CPU)
)

RANDOM_SEED <- 42  # For reproducibility

# ------------------------------------------------------------------------------
# LOAD EMBEDDINGS
# ------------------------------------------------------------------------------

cat("Loading embeddings...\n")
merged_df <- readRDS(INPUT_FILE)

# Convert embedding list to matrix
embedding_matrix <- do.call(rbind, lapply(merged_df$embedding, unlist))

cat(sprintf("Embedding matrix: %d x %d\n",
            nrow(embedding_matrix), ncol(embedding_matrix)))

# ------------------------------------------------------------------------------
# HANDLE MISSING VALUES
# ------------------------------------------------------------------------------

n_na <- sum(!complete.cases(embedding_matrix))
if (n_na > 0) {
  cat(sprintf("Found %d rows with NA embeddings, removing...\n", n_na))
  valid_idx <- complete.cases(embedding_matrix)
  embedding_matrix <- embedding_matrix[valid_idx, ]
  merged_df <- merged_df[valid_idx, ]
  cat(sprintf("Remaining: %d posts\n", nrow(embedding_matrix)))
}

# ------------------------------------------------------------------------------
# UMAP DIMENSIONALITY REDUCTION
# ------------------------------------------------------------------------------

cat("\nRunning UMAP reduction to 50D...\n")
cat(sprintf("Parameters: n_neighbors=%d, min_dist=%.2f, metric=%s\n",
            UMAP_PARAMS$n_neighbors, UMAP_PARAMS$min_dist, UMAP_PARAMS$metric))

set.seed(RANDOM_SEED)

embedding_umap_50d <- umap(
  embedding_matrix,
  n_neighbors = UMAP_PARAMS$n_neighbors,
  min_dist = UMAP_PARAMS$min_dist,
  n_components = UMAP_PARAMS$n_components,
  metric = UMAP_PARAMS$metric,
  n_threads = UMAP_PARAMS$n_threads,
  verbose = TRUE
)

cat("\nReduction completed!\n")
cat(sprintf("Output dimensions: %d x %d\n",
            nrow(embedding_umap_50d), ncol(embedding_umap_50d)))

# ------------------------------------------------------------------------------
# SUMMARY STATISTICS
# ------------------------------------------------------------------------------

cat("\n50D Matrix Statistics:\n")
cat(sprintf("  Value range: [%.3f, %.3f]\n",
            min(embedding_umap_50d), max(embedding_umap_50d)))
cat(sprintf("  Mean: %.3f\n", mean(embedding_umap_50d)))
cat(sprintf("  SD: %.3f\n", sd(embedding_umap_50d)))

# ------------------------------------------------------------------------------
# SAVE OUTPUTS
# ------------------------------------------------------------------------------

saveRDS(embedding_umap_50d, OUTPUT_UMAP)
saveRDS(merged_df, OUTPUT_DF)

cat("\nFiles saved:\n")
cat(sprintf("  - %s (50D UMAP matrix)\n", OUTPUT_UMAP))
cat(sprintf("  - %s (updated dataframe)\n", OUTPUT_DF))

cat("\nNext step: Run 03_clustering.R\n")
