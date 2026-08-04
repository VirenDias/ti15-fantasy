calc_exp_summary <- function(
    values, 
    ranks = NULL,
    alpha = NULL, 
    func = "average"
) {
  values <- values[!is.na(values)]
  alpha <- if (!is.null(alpha)) {
    alpha
  } else if (is.null(alpha) & is.null(ranks)) {
    2 / (length(values) + 1)
  } else if (is.null(alpha) & !is.null(ranks)) {
    2 / (ceiling(max(ranks)) + 2)
  }
  
  powers <- if (is.null(ranks)) (length(values) - 1):0 else ranks
  weights <- (1 - alpha)^powers
  ew_avg <- sum(weights * values) / sum(weights)
  
  if (func == "average") {
    summary <- ew_avg
  } else if (func == "stddev") {
    bias <- sum(weights)^2 / (sum(weights)^2 - sum(weights^2))
    ew_std <- sqrt(bias * sum(weights * (values - ew_avg)^2) / sum(weights))
    summary <- ew_std
  }
  
  return(summary)
}