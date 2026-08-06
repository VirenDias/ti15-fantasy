library(tidyverse)

get_hero_data <- function(python_exe = "python") {
  message("Retrieving hero data")
  
  dir_path <- paste0("data")
  file_path <- paste0(dir_path, "/heroes.txt")
  
  if (file.exists(file_path)) {
    heroes <- system(
      paste0(
        python_exe,
        " ",
        "utils/parse-hero-data.py",
        " ",
        "data/heroes.txt"
      ), 
      intern = TRUE
    ) %>%
      paste(., collapse = '\n') %>%
      read_csv(., progress = FALSE, show_col_types = FALSE)
  } else {
    stop(
      paste0(
        "Please extract npc_heroes.txt from ",
        "dota 2 beta/game/dota/pak01_dir.vpk first"
      )
    )
  }
  
  return(heroes)
}
