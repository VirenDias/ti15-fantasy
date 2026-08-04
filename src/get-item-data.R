library(tidyverse)
library(httr)

get_item_data <- function() {
  message("Retrieving item data")
  
  dir_path <- paste0("data")
  file_path <- paste0(dir_path, "/items.csv")
  
  if (file.exists(file_path)) {
    # Read data from disk
    items <- read_csv(file_path, progress = FALSE, show_col_types = FALSE)
  } else {
    # Get item data
    response <- GET(url = "https://api.opendota.com/api/constants/items")
    if (http_status(response)$category != "Success") {
      stop("Unsuccessful request")
    }
    
    # Store player data
    items <- data.frame(
      item_id = as.numeric(), 
      item_name = as.character(),
      has_active = as.logical()
    )
    for (item_name in names(content(response))) {
      item <- content(response)[[item_name]]
      items <- items %>%
        add_row(
          item_id = as.numeric(item$id), 
          item_name = as.character(item_name),
          has_active = if (length(item$abilities) == 0) {
            FALSE
          } else {
            sapply(
              X = item$abilities,
              FUN = function(x) x$type == "active"
            ) %>%
              sum() > 0
          }
        )
    }
    
    # Write the data to disk
    if (!dir.exists(dir_path)) {
      dir.create(dir_path)
    }
    items <- items %>% arrange(item_id)
    write_csv(x = items, file = file_path)
  }
  
  return(items)
}
