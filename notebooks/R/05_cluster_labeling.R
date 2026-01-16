# ==============================================================================
# 05_cluster_labeling.R
# Automatic cluster labeling using GPT-4
# ==============================================================================
#
# This script generates interpretable labels for each cluster by sampling
# representative posts and using GPT-4 to identify recurring themes.
#
# Input:  merged_df_with_clusters.rds
# Output: merged_df_with_labels.csv, cluster_labels.csv
#
# Requirements:
#   - OpenAI API key with GPT-4 access
#   - R packages: httr, jsonlite, dplyr, purrr
#
# ==============================================================================

library(httr)
library(jsonlite)
library(dplyr)
library(purrr)

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

# Set your OpenAI API key (or use environment variable)
# Sys.setenv(OPENAI_API_KEY = "your-key-here")

if (Sys.getenv("OPENAI_API_KEY") == "") {
  stop("OPENAI_API_KEY environment variable not set.")
}

INPUT_FILE <- "merged_df_with_clusters.rds"
SAMPLES_PER_CLUSTER <- 30  # Number of posts to sample for labeling
MODEL <- "gpt-4o"          # OpenAI model to use
RATE_LIMIT_DELAY <- 3      # Seconds between API calls

# ------------------------------------------------------------------------------
# LOAD DATA
# ------------------------------------------------------------------------------

cat("Loading clustered data...\n")
merged_df <- readRDS(INPUT_FILE)

# Get unique clusters (excluding noise = 0)
unique_clusters <- sort(unique(merged_df$cluster))
unique_clusters <- unique_clusters[unique_clusters != 0]

cat(sprintf("Found %d clusters to label\n", length(unique_clusters)))

# ------------------------------------------------------------------------------
# LABELING FUNCTION
# ------------------------------------------------------------------------------

#' Generate cluster label using GPT-4
#'
#' @param texts Character vector of sample texts from cluster
#' @param cluster_id Numeric cluster identifier
#' @return Character string with cluster label
get_cluster_label <- function(texts, cluster_id) {

  prompt <- paste(
    sprintf("You are analyzing social media posts grouped into Cluster %d.", cluster_id),
    "Your task is to assign a short, descriptive label (max 5 words) that summarizes",
    "the main theme or topic of this cluster.",
    "",
    "Guidelines:",
    "- Be specific and concrete (e.g., 'Tax Policy Advocacy', 'Corporate Tax News')",
    "- Avoid generic terms like 'discussion' or 'posts'",
    "- Focus on the substantive topic, not the format",
    "",
    "Here are sample posts from this cluster:",
    "",
    "---",
    paste(texts, collapse = "\n\n---\n\n"),
    "---",
    "",
    "Return ONLY the label, without quotes or explanation.",
    sep = "\n"
  )

  data <- list(
    model = MODEL,
    messages = list(
      list(role = "user", content = prompt)
    ),
    temperature = 0.7,
    max_tokens = 50
  )

  response <- tryCatch({
    POST(
      url = "https://api.openai.com/v1/chat/completions",
      add_headers(
        "Content-Type" = "application/json",
        "Authorization" = paste("Bearer", Sys.getenv("OPENAI_API_KEY"))
      ),
      body = toJSON(data, auto_unbox = TRUE),
      encode = "json",
      timeout(60)
    )
  }, error = function(e) {
    warning(sprintf("API error for cluster %d: %s", cluster_id, conditionMessage(e)))
    return(NULL)
  })

  if (is.null(response)) return(NA_character_)

  if (http_status(response)$category != "Success") {
    error_msg <- content(response, "text", encoding = "UTF-8")
    warning(sprintf("API error for cluster %d: %s", cluster_id, error_msg))
    return(NA_character_)
  }

  result <- content(response, as = "parsed", simplifyVector = FALSE)
  label <- trimws(result$choices[[1]]$message$content)

  # Clean up label (remove quotes if present)
  label <- gsub('^["\']|["\']$', '', label)

  return(label)
}

# ------------------------------------------------------------------------------
# GENERATE LABELS
# ------------------------------------------------------------------------------

cat("\nGenerating cluster labels...\n\n")

cluster_labels <- list()

for (clust in unique_clusters) {
  cat(sprintf("Processing Cluster %d... ", clust))

  # Get posts from this cluster
  cluster_posts <- merged_df %>%
    filter(cluster == clust, !is.na(full_text), full_text != "")

  n_posts <- nrow(cluster_posts)

  if (n_posts == 0) {
    cat("no valid posts, skipping\n")
    cluster_labels[[as.character(clust)]] <- NA_character_
    next
  }

  # Sample posts
  n_sample <- min(SAMPLES_PER_CLUSTER, n_posts)
  sampled_texts <- cluster_posts %>%
    slice_sample(n = n_sample) %>%
    pull(full_text)

  # Get label from GPT
  label <- get_cluster_label(sampled_texts, clust)
  cluster_labels[[as.character(clust)]] <- label

  cat(sprintf("'%s' (n=%d)\n", label, n_posts))

  # Rate limiting
  Sys.sleep(RATE_LIMIT_DELAY + runif(1))
}

# ------------------------------------------------------------------------------
# CREATE LABELS DATAFRAME
# ------------------------------------------------------------------------------

labels_df <- tibble(
  cluster = as.integer(names(cluster_labels)),
  cluster_label = unlist(cluster_labels)
)

cat("\n", strrep("=", 60), "\n")
cat("CLUSTER LABELS SUMMARY\n")
cat(strrep("=", 60), "\n")
print(labels_df, n = Inf)

# ------------------------------------------------------------------------------
# MERGE WITH MAIN DATA
# ------------------------------------------------------------------------------

# Remove embedding column if present (for CSV export)
if ("embedding" %in% names(merged_df)) {
  merged_df <- merged_df %>% select(-embedding)
}

# Join labels
merged_df <- merged_df %>%
  left_join(labels_df, by = "cluster")

# Clean list columns for CSV export
merged_df_clean <- merged_df %>%
  mutate(across(where(is.list), ~ sapply(., function(x) {
    if (is.null(x)) return(NA_character_)
    if (is.atomic(x)) return(as.character(x))
    return(paste(as.character(x), collapse = " | "))
  })))

# ------------------------------------------------------------------------------
# SAVE OUTPUTS
# ------------------------------------------------------------------------------

write.csv(merged_df_clean, "merged_df_with_labels.csv", row.names = FALSE)
write.csv(labels_df, "cluster_labels.csv", row.names = FALSE)
saveRDS(merged_df, "merged_df_with_labels.rds")

cat("\nFiles saved:\n")
cat("  - merged_df_with_labels.csv (full dataset with labels)\n")
cat("  - merged_df_with_labels.rds (R format)\n")
cat("  - cluster_labels.csv (labels only)\n")

cat("\n", strrep("=", 60), "\n")
cat("LABELING COMPLETE\n")
cat(strrep("=", 60), "\n")
