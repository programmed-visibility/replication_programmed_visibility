# ==============================================================================
# 03_clustering.R
# K-means clustering with parameter optimization
# ==============================================================================
#
# This script performs K-means clustering on the UMAP-reduced embeddings,
# with systematic optimization to identify the optimal number of clusters.
# Evaluates multiple quality metrics (Silhouette, Davies-Bouldin,
# Calinski-Harabasz, BSS/TSS) and combines them into a composite score.
#
# Input:  embedding_umap_50d.rds, merged_df_pre_clustering.rds
# Output: merged_df_with_clusters.rds, merged_df_with_clusters.csv,
#         clustering_results.rds, kmeans_optimization.png
#
# Requirements:
#   - R packages: cluster, fpc, clusterSim, ggplot2, dplyr, patchwork
#
# ==============================================================================

library(cluster)
library(fpc)
library(clusterSim)
library(ggplot2)
library(dplyr)
library(patchwork)

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

INPUT_UMAP <- "embedding_umap_50d.rds"
INPUT_DF <- "merged_df_pre_clustering.rds"

# K-means parameters
K_RANGE <- 4:15              # Range of cluster numbers to test
N_START <- 25                # Number of random initializations per k
MAX_ITER <- 100              # Maximum iterations for convergence
RANDOM_SEED <- 42            # For reproducibility

# Final clustering parameters (more robust)
FINAL_N_START <- 50          # More initializations for final result
FINAL_MAX_ITER <- 200        # More iterations for final result

# Sampling for expensive metrics
SAMPLE_SIZE <- 5000

# Composite score weights (sum to 1.0)
WEIGHTS <- list(
  silhouette = 0.35,         # Cluster cohesion (primary)
  davies_bouldin = 0.25,     # Cluster separation
  calinski_harabasz = 0.20,  # Variance structure
  bss_tss = 0.20             # Variance explained
)

# ------------------------------------------------------------------------------
# LOAD DATA
# ------------------------------------------------------------------------------

cat("Loading data...\n")
embedding_umap <- readRDS(INPUT_UMAP)
merged_df <- readRDS(INPUT_DF)

# Verify dimensions match
if (nrow(embedding_umap) != nrow(merged_df)) {
  stop("Dimension mismatch between UMAP matrix and dataframe!")
}

cat(sprintf("UMAP matrix: %d x %d\n", nrow(embedding_umap), ncol(embedding_umap)))
cat(sprintf("Dataframe: %d rows\n", nrow(merged_df)))

# ------------------------------------------------------------------------------
# K-MEANS GRID SEARCH
# ------------------------------------------------------------------------------

cat(sprintf("\nSearching k in range [%d, %d]...\n\n", min(K_RANGE), max(K_RANGE)))

results <- data.frame()
pb <- txtProgressBar(min = 0, max = length(K_RANGE), style = 3)

for (i in seq_along(K_RANGE)) {
  k <- K_RANGE[i]
  setTxtProgressBar(pb, i)

  # Run K-means
  set.seed(RANDOM_SEED)
  km <- kmeans(embedding_umap, centers = k, nstart = N_START, iter.max = MAX_ITER)

  # --- Calculate metrics ---

  # 1. Silhouette (sample if dataset too large)
  if (nrow(embedding_umap) > SAMPLE_SIZE) {
    sample_idx <- sample(seq_len(nrow(embedding_umap)), SAMPLE_SIZE)
    sil_score <- mean(silhouette(km$cluster[sample_idx],
                                  dist(embedding_umap[sample_idx, ]))[, 3])
  } else {
    sil_score <- mean(silhouette(km$cluster, dist(embedding_umap))[, 3])
  }

  # 2. Davies-Bouldin index (lower is better)
  db_score <- index.DB(embedding_umap, km$cluster)$DB

  # 3. Calinski-Harabasz index (higher is better)
  if (nrow(embedding_umap) > SAMPLE_SIZE) {
    ch_score <- cluster.stats(dist(embedding_umap[sample_idx, ]),
                               km$cluster[sample_idx])$ch
  } else {
    ch_score <- cluster.stats(dist(embedding_umap), km$cluster)$ch
  }

  # 4. Between/Total Sum of Squares ratio (higher is better)
  bss_tss <- km$betweenss / km$totss

  # 5. Within-cluster sum of squares (for elbow plot)
  wss <- km$tot.withinss

  results <- rbind(results, data.frame(
    k = k,
    silhouette = sil_score,
    davies_bouldin = db_score,
    calinski_harabasz = ch_score,
    bss_tss = bss_tss,
    wss = wss
  ))
}

close(pb)

# ------------------------------------------------------------------------------
# COMPUTE COMPOSITE SCORE
# ------------------------------------------------------------------------------

cat("\nComputing composite scores...\n")

results <- results %>%
  mutate(
    # Normalize metrics to [0,1]
    sil_norm = (silhouette - min(silhouette)) /
               (max(silhouette) - min(silhouette) + 1e-10),

    # Davies-Bouldin: lower is better, so invert
    db_norm = 1 - ((davies_bouldin - min(davies_bouldin)) /
                   (max(davies_bouldin) - min(davies_bouldin) + 1e-10)),

    ch_norm = (calinski_harabasz - min(calinski_harabasz)) /
              (max(calinski_harabasz) - min(calinski_harabasz) + 1e-10),

    bss_norm = (bss_tss - min(bss_tss)) /
               (max(bss_tss) - min(bss_tss) + 1e-10),

    # Weighted composite score
    composite_score = (
      sil_norm * WEIGHTS$silhouette +
      db_norm * WEIGHTS$davies_bouldin +
      ch_norm * WEIGHTS$calinski_harabasz +
      bss_norm * WEIGHTS$bss_tss
    )
  ) %>%
  arrange(desc(composite_score))

# ------------------------------------------------------------------------------
# DISPLAY RESULTS
# ------------------------------------------------------------------------------

cat("\n", strrep("=", 70), "\n")
cat("K-MEANS OPTIMIZATION RESULTS\n")
cat(strrep("=", 70), "\n\n")

print(
  results %>%
    select(k, silhouette, davies_bouldin, bss_tss, composite_score) %>%
    arrange(k),
  digits = 3
)

cat("\n", strrep("=", 70), "\n")
cat("TOP 5 CONFIGURATIONS (by composite score)\n")
cat(strrep("=", 70), "\n\n")

print(
  results %>%
    select(k, silhouette, davies_bouldin, bss_tss, composite_score) %>%
    head(5),
  digits = 3
)

# Best configuration
best <- results[1, ]

cat("\n", strrep("=", 70), "\n")
cat("OPTIMAL CONFIGURATION\n")
cat(strrep("=", 70), "\n")
cat(sprintf("  Optimal k: %d clusters\n", best$k))
cat(sprintf("  Silhouette: %.3f (>0.3 = good, >0.5 = excellent)\n", best$silhouette))
cat(sprintf("  Davies-Bouldin: %.3f (<1.0 = good separation)\n", best$davies_bouldin))
cat(sprintf("  BSS/TSS: %.1f%% variance explained\n", best$bss_tss * 100))
cat(sprintf("  Composite Score: %.4f\n", best$composite_score))

# ------------------------------------------------------------------------------
# VISUALIZATION
# ------------------------------------------------------------------------------

cat("\nGenerating diagnostic plots...\n")

p1 <- ggplot(results, aes(x = k, y = silhouette)) +
  geom_line(color = "steelblue", linewidth = 1.2) +
  geom_point(color = "steelblue", size = 4) +
  geom_point(data = best, aes(x = k, y = silhouette),
             color = "red", size = 6, shape = 18) +
  labs(title = "Silhouette Score",
       subtitle = "Higher = better cluster cohesion",
       x = "Number of Clusters (k)", y = "Silhouette") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

p2 <- ggplot(results, aes(x = k, y = davies_bouldin)) +
  geom_line(color = "coral", linewidth = 1.2) +
  geom_point(color = "coral", size = 4) +
  geom_point(data = best, aes(x = k, y = davies_bouldin),
             color = "red", size = 6, shape = 18) +
  labs(title = "Davies-Bouldin Index",
       subtitle = "Lower = better cluster separation",
       x = "Number of Clusters (k)", y = "DB Index") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

p3 <- ggplot(results, aes(x = k, y = wss)) +
  geom_line(color = "darkgreen", linewidth = 1.2) +
  geom_point(color = "darkgreen", size = 4) +
  geom_point(data = best, aes(x = k, y = wss),
             color = "red", size = 6, shape = 18) +
  labs(title = "Within-Cluster Sum of Squares",
       subtitle = "Elbow method: look for bend in curve",
       x = "Number of Clusters (k)", y = "WSS") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

p4 <- ggplot(results, aes(x = k, y = bss_tss * 100)) +
  geom_line(color = "purple", linewidth = 1.2) +
  geom_point(color = "purple", size = 4) +
  geom_point(data = best, aes(x = k, y = bss_tss * 100),
             color = "red", size = 6, shape = 18) +
  labs(title = "Variance Explained (BSS/TSS)",
       subtitle = "Higher = clusters capture more structure",
       x = "Number of Clusters (k)", y = "Variance Explained (%)") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

combined <- (p1 | p2) / (p3 | p4)
ggsave("kmeans_optimization.png", combined, width = 14, height = 10, dpi = 300)

cat("Plot saved: kmeans_optimization.png\n")

# ------------------------------------------------------------------------------
# FINAL CLUSTERING
# ------------------------------------------------------------------------------

cat("\nRunning final clustering with optimal k...\n")

set.seed(RANDOM_SEED)
kmeans_final <- kmeans(
  embedding_umap,
  centers = best$k,
  nstart = FINAL_N_START,
  iter.max = FINAL_MAX_ITER
)

# Assign cluster labels
merged_df$cluster <- kmeans_final$cluster

# Calculate confidence score (inverse normalized distance to centroid)
# Higher values = post is more typical of its cluster
distances_to_center <- sapply(seq_len(nrow(embedding_umap)), function(i) {
  center <- kmeans_final$centers[kmeans_final$cluster[i], ]
  sqrt(sum((embedding_umap[i, ] - center)^2))
})

merged_df$membership_prob <- 1 - (distances_to_center - min(distances_to_center)) /
                                  (max(distances_to_center) - min(distances_to_center))

# ------------------------------------------------------------------------------
# FINAL STATISTICS
# ------------------------------------------------------------------------------

cat("\n", strrep("=", 70), "\n")
cat("FINAL CLUSTERING RESULTS\n")
cat(strrep("=", 70), "\n")
cat(sprintf("  Number of clusters: %d\n", best$k))
cat(sprintf("  All %d posts assigned (K-means has no noise category)\n", nrow(merged_df)))

cluster_sizes <- sort(table(merged_df$cluster), decreasing = TRUE)
cat("\nCluster distribution:\n")
for (i in seq_along(cluster_sizes)) {
  cat(sprintf("  Cluster %s: %s posts (%.1f%%)\n",
              names(cluster_sizes)[i],
              format(cluster_sizes[i], big.mark = ","),
              cluster_sizes[i] / sum(cluster_sizes) * 100))
}

# ------------------------------------------------------------------------------
# SAVE OUTPUTS
# ------------------------------------------------------------------------------

saveRDS(merged_df, "merged_df_with_clusters.rds")

merged_df_export <- merged_df %>% select(-embedding)
write.csv(merged_df_export, "merged_df_with_clusters.csv", row.names = FALSE)

write.csv(results, "kmeans_optimization_results.csv", row.names = FALSE)

saveRDS(list(
  kmeans_result = kmeans_final,
  optimal_k = best$k,
  optimization_results = results
), "clustering_results.rds")

cat("\nFiles saved:\n")
cat("  - merged_df_with_clusters.rds\n")
cat("  - merged_df_with_clusters.csv\n")
cat("  - clustering_results.rds\n")
cat("  - kmeans_optimization_results.csv\n")
cat("  - kmeans_optimization.png\n")

cat("\nNext step: Run 04_visualization.R\n")
