# ==============================================================================
# 04_visualization.R
# Generate 2D UMAP visualization and export for Gephi
# ==============================================================================
#
# This script creates a 2D UMAP projection for visualization purposes and
# exports the data in GraphML format for network visualization in Gephi.
#
# Input:  merged_df_with_clusters.rds, embedding_umap_50d.rds
# Output: umap_2d_visualization.png, facebook_posts_clusters.graphml
#
# Requirements:
#   - R packages: uwot, ggplot2, dplyr, igraph
#
# ==============================================================================

library(uwot)
library(ggplot2)
library(dplyr)
library(igraph)

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

INPUT_DF <- "merged_df_with_clusters.rds"
INPUT_UMAP <- "embedding_umap_50d.rds"
RANDOM_SEED <- 42

# ------------------------------------------------------------------------------
# LOAD DATA
# ------------------------------------------------------------------------------

cat("Loading data...\n")
merged_df <- readRDS(INPUT_DF)
embedding_umap_50d <- readRDS(INPUT_UMAP)

cat(sprintf("Loaded %d posts with %d clusters\n",
            nrow(merged_df),
            length(unique(merged_df$cluster[merged_df$cluster != 0]))))

# ------------------------------------------------------------------------------
# 2D UMAP FOR VISUALIZATION
# ------------------------------------------------------------------------------

cat("\nGenerating 2D UMAP projection...\n")

set.seed(RANDOM_SEED)

embedding_umap_2d <- umap(
  embedding_umap_50d,
  n_neighbors = 30,
  min_dist = 0.1,
  n_components = 2,
  metric = "euclidean",
  n_threads = 4,
  verbose = TRUE
)

# Add coordinates to dataframe
merged_df$umap_x <- embedding_umap_2d[, 1]
merged_df$umap_y <- embedding_umap_2d[, 2]

cat("2D projection completed.\n")

# ------------------------------------------------------------------------------
# VISUALIZATION PLOT
# ------------------------------------------------------------------------------

cat("\nGenerating cluster visualization...\n")

# Prepare cluster labels for plot
merged_df <- merged_df %>%
  mutate(cluster_label = ifelse(cluster == 0, "Noise", paste("Cluster", cluster)))

# Create color palette
n_clusters <- length(unique(merged_df$cluster_label)) - 1  # exclude noise
cluster_colors <- c(
  scales::hue_pal()(n_clusters),
  "gray70"  # noise color
)
names(cluster_colors) <- c(
  paste("Cluster", sort(unique(merged_df$cluster[merged_df$cluster != 0]))),
  "Noise"
)

# Main plot
p <- ggplot(merged_df, aes(x = umap_x, y = umap_y, color = cluster_label)) +
  geom_point(alpha = 0.6, size = 1) +
  scale_color_manual(values = cluster_colors) +
  labs(
    title = "UMAP Visualization of Tax Reform Discourse Clusters",
    subtitle = sprintf("Search 1: %s posts | %d clusters identified",
                       format(nrow(merged_df), big.mark = ","), n_clusters),
    x = "UMAP 1",
    y = "UMAP 2",
    color = "Cluster"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "right",
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  ) +
  guides(color = guide_legend(override.aes = list(size = 3, alpha = 1)))

ggsave("umap_2d_visualization.png", p, width = 12, height = 8, dpi = 300)
cat("Plot saved: umap_2d_visualization.png\n")

# ------------------------------------------------------------------------------
# EXPORT TO GRAPHML FOR GEPHI
# ------------------------------------------------------------------------------

cat("\nExporting GraphML for Gephi...\n")

# Clean text for XML export (remove control characters)
if ("text" %in% names(merged_df)) {
  merged_df$text_clean <- merged_df$text
  merged_df$text_clean[is.na(merged_df$text_clean)] <- ""

  # Normalize encoding
  merged_df$text_clean <- iconv(merged_df$text_clean, to = "UTF-8", sub = "")

  # Remove control characters
  merged_df$text_clean <- gsub("[[:cntrl:]]", " ", merged_df$text_clean, perl = TRUE)

  # Collapse whitespace
  merged_df$text_clean <- gsub("\\s+", " ", merged_df$text_clean)

  # Truncate to 200 characters for preview
  merged_df$text_clean <- trimws(substr(merged_df$text_clean, 1, 200))
}

# Create graph (nodes only, no edges)
g <- make_empty_graph(n = nrow(merged_df), directed = FALSE)

# Add node attributes
V(g)$id <- seq_len(nrow(merged_df))
V(g)$cluster <- merged_df$cluster
V(g)$x <- merged_df$umap_x
V(g)$y <- merged_df$umap_y

if ("membership_prob" %in% names(merged_df)) {
  V(g)$membership_prob <- merged_df$membership_prob
}

if ("text_clean" %in% names(merged_df)) {
  V(g)$text <- merged_df$text_clean
}

if ("post_owner.name" %in% names(merged_df)) {
  V(g)$author <- merged_df$`post_owner.name`
}

# Save GraphML
write_graph(g, "facebook_posts_clusters.graphml", format = "graphml")

cat(sprintf("GraphML saved: facebook_posts_clusters.graphml\n"))
cat(sprintf("  Nodes: %d\n", vcount(g)))
cat(sprintf("  Edges: %d (nodes only)\n", ecount(g)))

# ------------------------------------------------------------------------------
# GEPHI INSTRUCTIONS
# ------------------------------------------------------------------------------

cat("\n", strrep("=", 60), "\n")
cat("GEPHI IMPORT INSTRUCTIONS\n")
cat(strrep("=", 60), "\n")
cat("1. File > Open > facebook_posts_clusters.graphml\n")
cat("2. Layout: Select 'None' to use existing x,y coordinates\n")
cat("3. Appearance > Nodes > Color > Partition > 'cluster'\n")
cat("4. Labels: Use 'text' attribute for post preview\n")
cat(strrep("=", 60), "\n")

# ------------------------------------------------------------------------------
# SAVE UPDATED DATAFRAME
# ------------------------------------------------------------------------------

saveRDS(merged_df, "merged_df_with_coordinates.rds")

cat("\nFiles saved:\n")
cat("  - umap_2d_visualization.png\n")
cat("  - facebook_posts_clusters.graphml\n")
cat("  - merged_df_with_coordinates.rds\n")

cat("\nNext step: Run 05_cluster_labeling.R\n")
