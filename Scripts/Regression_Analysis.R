# ============================================================
# Spatial Analysis of 5-Year Home Price Appreciation in the Kansas City MSA
# Matthew Ong | mong01@tamu.edu | February 2026
# ============================================================

# Libraries
library(tidyverse) 
library(tidyr)
library(dplyr)
library(ggplot2) 
library(stargazer)

# ============================================================
# 1. Import Data
# ============================================================

# Distance matrix and price growth data
distance_matrix <- read_csv("kc_distance_matrix.csv")
price_change <- read_csv("kc_growth.csv")

# ============================================================
# 2. Data Cleaning and Transformation
# ============================================================

# Pivot distance matrix to wide format
dist_wide <- distance_matrix %>%
  pivot_wider(names_from = TargetID, values_from = Distance) %>%
  rename(RegionName = InputID) %>%
  arrange(RegionName)

# Merge distance data with price growth
merged_df <- dist_wide %>%
  full_join(price_change, by = "RegionName") %>%
  arrange(RegionName) %>%
  rename(
    dist_mci        = `Airport (MCI)`,
    dist_plaza      = `The Plaza`,
    dist_pnl        = `Power and Light`,
    dist_legends    = `The Legands`,
    dist_lees_summit= `Lee's Summit`,
    growth_5yr      = cum_5yr_log_growth,
    log_initial     = log_initial_price,
    pct_change      = percent_change
  )

# Prepare regression dataset (drop rows with missing growth or initial price)
reg_df <- merged_df %>%
  drop_na(growth_5yr, log_initial)

# ============================================================
# 3. Regression Models
# ============================================================

# Individual Point-of-Interest Regressions
plaza_lm       <- lm(growth_5yr ~ dist_plaza + log_initial, data = reg_df)
mci_lm         <- lm(growth_5yr ~ dist_mci + log_initial, data = reg_df)
pnl_lm         <- lm(growth_5yr ~ dist_pnl + log_initial, data = reg_df)
legends_lm     <- lm(growth_5yr ~ dist_legends + log_initial, data = reg_df)
lees_summit_lm <- lm(growth_5yr ~ dist_lees_summit + log_initial, data = reg_df)

# Export regression table
stargazer(
  plaza_lm, pnl_lm, lees_summit_lm, mci_lm, legends_lm,
  type = "html",
  out = "regression_table.html",
  title = "Distance to Points of Interest and 5-Year Home Price Appreciation",
  dep.var.labels = "Log 5-Year Growth",
  digits = 4
)

# Full regression model with all POIs
full_model <- lm(
  growth_5yr ~ dist_plaza + dist_pnl + dist_lees_summit + dist_mci + dist_legends + log_initial,
  data = reg_df
)
stargazer(
  full_model,
  type = "html",
  out = "full_model_table.html",
  title = "Full Model: All POIs and Initial Price"
)

# Urban core index regression
reg_df <- reg_df %>%
  mutate(urban_core = (dist_plaza + dist_pnl) / 2)

urban_core_lm <- lm(growth_5yr ~ urban_core + log_initial, data = reg_df)
stargazer(
  urban_core_lm,
  type = "html",
  out = "urban_core_table.html",
  title = "Distance to Urban Core and 5-Year Home Price Appreciation"
)

# Interaction regression
interaction_lm <- lm(growth_5yr ~ log_initial * urban_core, data = reg_df)
stargazer(
  interaction_lm,
  type = "html",
  out = "interaction_table.html",
  title = "5-Year Home Price Appreciation: Initial Price x Distance to Urban Core"
)

# ============================================================
# 4. Histogram of 5-Year Growth Percentages
# ============================================================

# Define bins and colors
breaks_pct <- c(0, 0.162362, 0.310224, 0.393885, 0.479034, 0.596069, 0.728834)
bin_colors <- c("#9ecae1", "#79b4d6", "#549dcb", "#357fbd", "#1a59ab", "#003399")

# Assign each ZIP code to a growth bin
hist_df <- reg_df %>%
  mutate(
    growth_bin = cut(
      pct_change,
      breaks = breaks_pct,
      include.lowest = TRUE,
      right = TRUE
    )
  )

# Summarize counts per bin
hist_data <- hist_df %>%
  group_by(growth_bin) %>%
  summarise(count = n(), .groups = "drop") %>%
  mutate(
    count = ifelse(is.na(count), 0, count),
    bin_start = breaks_pct[seq_len(length(breaks_pct)-1)],
    bin_end   = breaks_pct[seq(2, length(breaks_pct))],
    bin_mid   = (bin_start + bin_end)/2,
    bin_label = paste0(round(bin_start*100), "%–", round(bin_end*100), "%")
  )

# Plot histogram
ggplot(hist_data, aes()) +
  geom_rect(aes(
    xmin = bin_start,
    xmax = bin_end,
    ymin = 0,
    ymax = count,
    fill = growth_bin
  ), color = "black") +
  geom_text(aes(
    x = bin_mid,
    y = count + 2,
    label = count
  ), size = 3) +
  geom_text(aes(
    x = bin_mid,
    y = -3,
    label = bin_label
  ), angle = 45, hjust = 0.8, size = 3) +
  scale_y_continuous(expand = expansion(mult = c(0.1, 0.05))) +
  scale_fill_manual(values = bin_colors) +
  scale_x_continuous(labels = NULL, expand = c(0,0)) +
  labs(
    title = "Distribution of 5-Year Home Price Appreciation",
    x = "Growth Percentage",
    y = "Number of ZIP Codes"
  ) +
  theme_minimal() +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    axis.text.x = element_blank(),
    legend.position = "none",
    plot.title = element_text(face = "bold")
  )

# ============================================================
