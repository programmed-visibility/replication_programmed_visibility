# ==============================================================================
# 01_generate_embeddings.R
# Generate text embeddings using OpenAI API (text-embedding-3-small)
# ==============================================================================
#
# This script processes Facebook posts from Search 1 and generates semantic
# embeddings for subsequent clustering analysis. Uses batch processing with
# checkpointing for resilience.
#
# Input:  search_1.csv (from Meta Content Library)
# Output: merged_df_with_embeddings.rds
#
# Requirements:
#   - OpenAI API key with embedding access
#   - R packages: dplyr, httr, jsonlite, readr
#
# ==============================================================================

library(dplyr)
library(httr)
library(jsonlite)
library(readr)

# ------------------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------------------

# Set your OpenAI API key (or use environment variable)
# Option 1: Set directly (not recommended for shared code)
# Sys.setenv(OPENAI_API_KEY = "your-key-here")
#
# Option 2: Set in .Renviron file (recommended)
# Add line: OPENAI_API_KEY=your-key-here

if (Sys.getenv("OPENAI_API_KEY") == "") {
  stop("OPENAI_API_KEY environment variable not set. See script comments.")
}

# Processing parameters
BATCH_SIZE <- 100        # Embeddings per API call (max 2048 for this model)
CHECKPOINT_FREQ <- 500   # Save progress every N embeddings
CHECKPOINT_FILE <- "embedding_checkpoint.rds"
INPUT_FILE <- "search_1.csv"
OUTPUT_FILE <- "merged_df_with_embeddings.rds"

# ------------------------------------------------------------------------------
# LOAD DATA
# ------------------------------------------------------------------------------

cat("Loading data...\n")
merged_df <- read_csv(INPUT_FILE, show_col_types = FALSE)

merged_df <- merged_df %>%
  mutate(
    text = as.character(text),
    full_text = text
  ) %>%
  filter(!is.na(text), text != "")

cat(sprintf("Loaded %d posts for embedding\n", nrow(merged_df)))

# ------------------------------------------------------------------------------
# EMBEDDING FUNCTION
# ------------------------------------------------------------------------------

#' Generate embeddings for a batch of texts
#'
#' @param texts Character vector of texts to embed
#' @param batch_indices Integer vector of row indices
#' @param max_retries Maximum retry attempts for failed API calls
#' @return List with embeddings and indices
generate_batch_embeddings <- function(texts, batch_indices, max_retries = 5) {

  # Handle empty/NA texts

valid_mask <- !is.na(texts) & texts != ""
  valid_texts <- texts[valid_mask]
  valid_indices <- batch_indices[valid_mask]

  if (length(valid_texts) == 0) {
    return(list(
      embeddings = rep(list(NA), length(texts)),
      indices = batch_indices
    ))
  }

  # API request payload
  data <- list(
    model = "text-embedding-3-small",
    input = valid_texts,
    encoding_format = "float"
  )

  # Retry loop with exponential backoff
  for (attempt in 1:max_retries) {
    wait_time <- 2^(attempt - 1)

    response <- tryCatch({
      POST(
        url = "https://api.openai.com/v1/embeddings",
        add_headers(
          "Content-Type" = "application/json",
          "Authorization" = paste("Bearer", Sys.getenv("OPENAI_API_KEY"))
        ),
        body = toJSON(data, auto_unbox = TRUE),
        encode = "json",
        timeout(120)
      )
    }, error = function(e) {
      cat(sprintf("  Attempt %d failed: %s\n", attempt, conditionMessage(e)))
      return(NULL)
    })

    if (!is.null(response)) {
      status <- http_status(response)

      if (status$category == "Success") {
        result <- content(response, "parsed", simplifyVector = FALSE)
        embeddings <- lapply(result$data, function(x) x$embedding)

        # Reconstruct full vector with NA for invalid texts
        full_embeddings <- vector("list", length(texts))
        full_embeddings[valid_mask] <- embeddings
        full_embeddings[!valid_mask] <- list(NA)

        return(list(embeddings = full_embeddings, indices = batch_indices))
      } else {
        error_content <- content(response, as = "text", encoding = "UTF-8")
        cat(sprintf("  HTTP %d: %s\n", status$status_code, error_content))
      }
    }

    if (attempt < max_retries) {
      cat(sprintf("  Waiting %d seconds before retry...\n", wait_time))
      Sys.sleep(wait_time)
    }
  }

  warning(sprintf("Batch failed after %d attempts", max_retries))
  return(list(
    embeddings = rep(list(NA), length(texts)),
    indices = batch_indices
  ))
}

# ------------------------------------------------------------------------------
# RESUME FROM CHECKPOINT (if exists)
# ------------------------------------------------------------------------------

if (file.exists(CHECKPOINT_FILE)) {
  cat("Checkpoint found, resuming...\n")
  merged_df <- readRDS(CHECKPOINT_FILE)

  if (!"embedding" %in% names(merged_df)) {
    merged_df$embedding <- vector("list", nrow(merged_df))
  }

  already_done <- sapply(merged_df$embedding, function(x) {
    !is.null(x) && !all(is.na(x))
  })
  start_idx <- sum(already_done) + 1

  cat(sprintf("Resuming from %d/%d\n", start_idx, nrow(merged_df)))
} else {
  merged_df$embedding <- vector("list", nrow(merged_df))
  start_idx <- 1
}

# ------------------------------------------------------------------------------
# MAIN PROCESSING LOOP
# ------------------------------------------------------------------------------

total <- nrow(merged_df)
current_idx <- start_idx

cat(sprintf("\nProcessing %d embeddings\n", total - start_idx + 1))
cat(sprintf("Batch size: %d | Checkpoint every: %d\n\n", BATCH_SIZE, CHECKPOINT_FREQ))

while (current_idx <= total) {
  batch_end <- min(current_idx + BATCH_SIZE - 1, total)
  batch_indices <- current_idx:batch_end

  cat(sprintf("Batch [%d-%d] - Progress: %.1f%%\n",
              current_idx, batch_end, current_idx / total * 100))

  # Extract and process batch
  batch_texts <- merged_df$full_text[batch_indices]
  batch_result <- generate_batch_embeddings(batch_texts, batch_indices)

  # Assign results
  for (i in seq_along(batch_result$indices)) {
    idx <- batch_result$indices[i]
    merged_df$embedding[[idx]] <- batch_result$embeddings[[i]]
  }

  # Periodic checkpoint
  if (batch_end %% CHECKPOINT_FREQ < BATCH_SIZE || batch_end == total) {
    saveRDS(merged_df, CHECKPOINT_FILE)
    n_done <- sum(sapply(merged_df$embedding, function(x) {
      !is.null(x) && !all(is.na(x))
    }))
    cat(sprintf("Checkpoint saved: %d/%d completed\n", n_done, total))
  }

  current_idx <- batch_end + 1

  # Rate limiting
  if (current_idx <= total) {
    Sys.sleep(1)
  }
}

# ------------------------------------------------------------------------------
# SAVE FINAL OUTPUT
# ------------------------------------------------------------------------------

saveRDS(merged_df, OUTPUT_FILE)

# Clean up checkpoint
if (file.exists(CHECKPOINT_FILE)) {
  file.remove(CHECKPOINT_FILE)
}

# Summary statistics
n_success <- sum(sapply(merged_df$embedding, function(x) {
  !is.null(x) && !all(is.na(x))
}))
n_failed <- total - n_success

cat("\n")
cat(strrep("=", 50), "\n")
cat("COMPLETED\n")
cat(sprintf("Embeddings generated: %d/%d\n", n_success, total))
if (n_failed > 0) {
  cat(sprintf("Failed: %d\n", n_failed))
}
cat(sprintf("Output saved to: %s\n", OUTPUT_FILE))
cat(strrep("=", 50), "\n")
