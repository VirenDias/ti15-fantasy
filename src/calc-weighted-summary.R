library(tidyverse)

calc_exp_weights <- function(times, alpha = NULL) {
  n <- length(times)
  if (n == 0) {
    return(numeric(0))
  }

  # 0 for the newest observation, n - 1 for the oldest
  powers <- n - rank(times, ties.method = "first")
  if (is.null(alpha)) {
    alpha <- 2 / (n + 1)
  }

  return((1 - alpha)^powers)
}

calc_wtd_summary <- function(values, weights) {
  keep <- !is.na(values) & !is.na(weights)
  values <- values[keep]
  weights <- weights[keep]

  if (length(values) == 0) {
    return(
      tibble(
        n = 0L,
        ess = NA_real_,
        average = NA_real_,
        stddev = NA_real_,
        sem = NA_real_
      )
    )
  }

  sum_w <- sum(weights)
  ess <- sum_w^2 / sum(weights^2)
  average <- sum(weights * values) / sum_w

  # The bias correction is undefined with a single effective observation
  stddev <- if (ess > 1) {
    sqrt((ess / (ess - 1)) * sum(weights * (values - average)^2) / sum_w)
  } else {
    NA_real_
  }

  return(
    tibble(
      n = length(values),
      ess = ess,
      average = average,
      stddev = stddev,
      sem = stddev / sqrt(ess)
    )
  )
}
