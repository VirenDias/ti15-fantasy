source("config.R")
source("src/calc-weighted-summary.R")

library(tidyverse)

role_size <- c(Core = 2L, Mid = 1L, Support = 2L)

pair_role_matches <- function(match_data, metric_cols) {
  # mean() without na.rm is deliberate: if any player in the role is missing a
  # metric for that match, the role has no score for it either
  paired <- match_data %>%
    filter(player_role %in% names(role_size)) %>%
    summarise(
      n_players = n(),
      across(all_of(metric_cols), mean),
      .by = c(team_id, player_role, match_id, is_radiant, start_time)
    )

  # is_radiant is in the grouping because roster-mates occasionally end up on
  # opposing teams, and those matches must not be averaged together
  return(
    paired %>%
      filter(n_players == role_size[player_role]) %>%
      select(-n_players)
  )
}

summarise_metrics <- function(
    matches,
    metric_cols,
    unit_cols,
    alpha = weight_alpha
) {
  stopifnot(!any(is.na(matches$start_time)))

  # One weight per unit-match, shared by every metric, so that the summaries and
  # the covariance below are mutually consistent
  return(
    matches %>%
      mutate(
        weight = calc_exp_weights(start_time, alpha),
        .by = all_of(unit_cols)
      ) %>%
      pivot_longer(
        all_of(metric_cols),
        names_to = "metric",
        values_to = "value"
      ) %>%
      reframe(
        calc_wtd_summary(value, weight),
        .by = c(all_of(unit_cols), metric)
      )
  )
}

calc_wtd_cov <- function(mat, weights) {
  # Rows are dropped listwise below, so a column that is mostly or entirely
  # empty would take the whole unit with it
  usable <- colSums(!is.na(mat)) >= 2
  mat <- mat[, usable, drop = FALSE]
  if (ncol(mat) == 0) {
    return(NULL)
  }

  keep <- complete.cases(mat) & !is.na(weights)
  mat <- mat[keep, , drop = FALSE]
  weights <- weights[keep]

  if (nrow(mat) < 2) {
    return(NULL)
  }

  sum_w <- sum(weights)
  ess <- sum_w^2 / sum(weights^2)
  if (ess <= 1) {
    return(NULL)
  }

  averages <- colSums(weights * mat) / sum_w
  centred <- sweep(mat, 2, averages)
  covariance <- (ess / (ess - 1)) * crossprod(centred, weights * centred) / sum_w

  attr(covariance, "n_used") <- nrow(mat)
  return(covariance)
}

summarise_covariance <- function(
    matches,
    metric_cols,
    unit_cols,
    alpha = weight_alpha
) {
  return(
    matches %>%
      mutate(
        weight = calc_exp_weights(start_time, alpha),
        .by = all_of(unit_cols)
      ) %>%
      nest(.by = all_of(unit_cols)) %>%
      mutate(
        cov = map(
          data,
          ~ calc_wtd_cov(as.matrix(.x[metric_cols]), .x$weight)
        )
      ) %>%
      select(-data) %>%
      filter(!map_lgl(cov, is.null)) %>%
      mutate(
        n_used = map_int(cov, ~ attr(.x, "n_used")),
        cov = map(
          cov,
          ~ as_tibble(.x, rownames = "metric_a") %>%
            pivot_longer(
              -metric_a,
              names_to = "metric_b",
              values_to = "covariance"
            )
        )
      ) %>%
      unnest(cov)
  )
}
