
# SET UP

library(tidyverse)
library(sf)
library(knitr)
library(dplyr)
library(spdep)
library(caret)
library(ckanr)
library(FNN)
library(grid)
library(gridExtra)
library(ggcorrplot) 
library(corrr)   
library(kableExtra)
library(jtools)    
library(ggstance) 
library(ggpubr)
library(broom.mixed) 
library(RColorBrewer)
library(ggplot2)
library(lubridate)

knitr::opts_chunk$set(echo = TRUE)

# CRIME DATA
## get the crime data (2022-now)
## https://opendataphilly.org/datasets/crime-incidents/

crime <- st_read("/Users/yaohanxu/Documents/GitHub/PhillyPatrol_Optimization_Model/crime_data/crime.shp") %>%
  st_transform(crs = st_crs(2272), check = TRUE)

boundary <- st_read("/Users/yaohanxu/Documents/GitHub/PhillyPatrol_Optimization_Model/Census_Tracts_2010.geojson") %>%
  st_transform(crs = st_crs(2272), check = TRUE)

# WEIGHT

## Preview the current crime types
crime %>%
  group_by(text_gener) %>%
  summarize(count = n()) %>%
  slice_max(order_by = count, n = 10) %>% # This replaces top_n()
  ungroup() %>%
  kable() %>%
  kable_styling()

## Federal Crime Type
# https://cortezdefense.com/federal-classification-of-crimes/#:~:text=Federal%20crimes%20are%20classified%20by,carries%20the%20most%20severe%20punishment.
crime <- crime %>%
  mutate(federal_category = case_when(
    text_gener %in% c("Thefts", "Theft from Vehicle", "Motor Vehicle Theft") ~ "Grade E Felony",
    text_gener %in% c("Other Assaults") ~ "Class A Misdemeanor",
    text_gener %in% c("Vandalism/Criminal Mischief") ~ "Class B Misdemeanor",
    text_gener %in% c("Fraud") ~ "Grade D Felony",
    text_gener %in% c("Aggravated Assault No Firearm") ~ "Grade C Felony",
    text_gener %in% c("Aggravated Assault Firearm") ~ "Grade B Felony",
    text_gener %in% c("Burglary Residential") ~ "Grade D Felony",
    text_gener %in% c("Homicide - Criminal") ~ "Grade A Felony",
    TRUE ~ "Unclassified"  
  ))

crime.weighted <- crime %>%
  mutate(crime_severity = case_when(
    federal_category == "Grade A Felony" ~ 7,
    federal_category == "Grade B Felony" ~ 6,
    federal_category == "Grade C Felony" ~ 5,
    federal_category == "Grade D Felony" ~ 4,
    federal_category == "Grade E Felony" ~ 3,
    federal_category == "Class A Misdemeanor" ~ 2,
    federal_category == "Class B Misdemeanor" ~ 1.5,
    federal_category == "Class C Misdemeanor" ~ 1,
    federal_category == "Infraction" ~ 0.5,
    federal_category == "Unclassified" ~ 0.5,
    TRUE ~ NA_real_
  ))

# VIZ 1

Pallete5 <- brewer.pal(8, "YlGnBu")
severity_levels <- sort(unique(crime.weighted$crime_severity))
names(Pallete5) <- severity_levels

## Crime Severity Dot Map
ggplot() + 
  geom_sf(data = boundary, fill = "lightgrey", col = "white", alpha=0.5) +
  geom_sf(data = crime.weighted, aes(colour = factor(crime_severity)), size = 0.25) +
  scale_color_manual(values = Pallete5) +
  labs(title = "Crime severity, Philadelphia") +
  theme_void()

## Crime Severity Hot spot Map
crime_data_frame <- as.data.frame(st_coordinates(crime.weighted))

ggplot() +
  stat_density_2d(
    data = crime_data_frame, 
    aes(x = X, y = Y, fill = after_stat(level)), 
    size = 0.1, 
    bins = 20, 
    geom = 'polygon'
  ) +
  geom_sf(data = boundary, fill = "transparent", color = "darkgrey") +
  scale_fill_gradient(low = "cornsilk", high = "skyblue4", name = "Density") +
  labs(title = "Density of Crime Severity, Philadelphia") +
  theme_void()

# TIMELINE

# Create a new column with the time frame
crime.weighted$time_frame <- cut(
  crime.weighted$hour,
  breaks = c(0, 8, 16, 24),
  labels = c("0:00-8:00", "8:00-16:00", "16:00-24:00"),
  include.lowest = TRUE,
  right = FALSE)

crime.weighted <- crime.weighted %>%
  relocate(hour, .before = time_frame)

crime0 <- crime.weighted %>%
  filter(time_frame == "0:00-8:00") %>%
  sample_n(8000)

crime8 <- crime.weighted %>%
  filter(time_frame == "8:00-16:00") %>%
  sample_n(8000)

crime16 <- crime.weighted %>%
  filter(time_frame == "16:00-24:00") %>%
  sample_n(8000)

#OUTPUT
st_write(crime.weighted, "/Users/yaohanxu/Documents/GitHub/PhillyPatrol_Optimization_Model/output/crime_weighted.shp")
st_write(crime0, "/Users/yaohanxu/Documents/GitHub/PhillyPatrol_Optimization_Model/output/crime_0-8.shp")
st_write(crime8, "/Users/yaohanxu/Documents/GitHub/PhillyPatrol_Optimization_Model/output/crime_8-16.shp")
st_write(crime16, "/Users/yaohanxu/Documents/GitHub/PhillyPatrol_Optimization_Model/output/crime_16-24.shp")
