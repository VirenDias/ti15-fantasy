library(tidyverse)

get_bingo_data <- function(python_exe = "python") {
  message("Retrieving bingo data")
  
  dir_path <- paste0("data")
  file_path <- paste0(dir_path, "/bingo_squares.txt")
  
  if (file.exists(file_path)) {
    # Read data from disk
    bingo_squares <- system(
      paste0(
        python_exe,
        " ",
        "utils/parse-bingo-data.py",
        " ",
        "data/bingo_squares.txt"
      ), 
      intern = TRUE
    ) %>%
      paste(., collapse = '\n') %>%
      read_csv(., progress = FALSE, show_col_types = FALSE)
  } else {
    stop(
      paste0(
        "Please extract bingo_2024_english.txt from ",
        "dota 2 beta/game/dota/pak01_dir.vpk first"
      )
    )
  }
  
  return(bingo_squares)
}
