library(tidyverse)
library(readxl)
library(pcaMethods)
library(sf)
library(mclust)

parse_sheet <- function(file_path, sheet_name) {
  # Read the sheet
  sheet_data <-
    suppressMessages(read_excel(file_path, sheet = sheet_name, col_names = FALSE))
  
  # Find the row index where the first column entry is "Area Code"
  start_row <- which(sheet_data[[1]] == "Area Code")
  
  # If "Area Code" is not found, skip this sheet
  if (length(start_row) == 0) {
    return(NULL)
  }
  
  # Read the data from the sheet, skipping the metadata rows
  data_frame <-
    suppressMessages(read_excel(file_path, sheet = sheet_name, skip = start_row - 1))
  
  if (!any(c("Local Authority District", "County or Unitary Authority") %in% names(data_frame))) {
    return(NULL)
  }
  
  data_frame <-
    filter(data_frame,!all(
      is.na(`Local Authority District`),
      is.na(`County or Unitary Authority`)
    ))
  
  return(data_frame)
}


read_excel_sheets_auto <- function(file_path) {
  # Get all sheet names in the file
  sheet_names <- excel_sheets(file_path)
  
  # Apply parse_sheet to all sheets in excel file
  data_frames <-
    lapply(sheet_names, function(sheet_name)
      parse_sheet(file_path, sheet_name))
  
  # Remove entries with null result
  data_frames <- Filter(Negate(is.null), data_frames)
  
  # Return the list of data frames
  return(data_frames)
}

sheets <- read_excel_sheets_auto("data/humanreadable.xlsx")

merged_data <- Reduce(function(df1, df2) {
  # Find duplicated column names (excluding 'Area Code')
  duplicated_columns <-
    setdiff(intersect(names(df1), names(df2)), "Area Code")
  
  # Drop duplicated columns from the second data frame
  df2 <- df2[,!(names(df2) %in% duplicated_columns)]
  
  # Perform inner join
  left_join(df1, df2, by = "Area Code")
}, sheets)

merged_data %>%
  select(where( ~ !all(is.na(.)))) %>%
  select(
    -c(
      "Lower 95% Confidence Interval",
      "Upper 95% Confidence Interval",
      "Data accuracy",
      "ITL Level 1"
    )
  ) %>%
  mutate(across(c(
    everything(), -c("Area Code", "Local Authority District")
  ),  ~ as.numeric(.x))) -> clean_data

glimpse(clean_data)

# Scale numeric data to mean zero, unit variance
clean_data[, 4:40] <- scale(clean_data[, 4:40])
# Coerce cleaned data to matrix
data_mat <- clean_data[, 4:40] %>% as.matrix

# Fit probabilistic PCA (to deal with missing data)
pca <- ppca(data_mat, nPcs = 10)

# Save loadings to csv
loadings(pca) %>%
  as_tibble(rownames = "variable") %>%
  write_csv("outputs/pca_loadings.csv")

# Fit clusters
cluster <- Mclust(scores(pca), G = 1:10)
clean_data$cluster <- cluster$classification
# cluster <- kmeans(scores(pca),centers=6)
# clean_data$cluster <- cluster$cluster

# Put scores in cleaned data
clean_data[, paste("dim", 1:10, sep = "")] <- scores(pca)

boundaries <- read_sf("boundaries/LAD_DEC_2022_UK_BGC.shp")
boundaries %>%
  left_join(clean_data, by = join_by(LAD22CD == `Area Code`)) -> geo_data

geo_data %>%
  filter(!is.na(cluster)) %>%
  ggplot(aes(fill = factor(cluster))) +
  geom_sf() +
  ggthemes::theme_map() +
  theme(panel.background = element_rect(color="white")) +
  labs(
    fill = "Cluster",
    title = "Cluster analysis of local authorities in the UK",
    subtitle = "ONS subnational indicators dataset",
    caption = "@jwhandley17"
  )

ggsave("outputs/lad_clusters.png",
       width = 10,
       height = 16)
