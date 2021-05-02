library(plumber)

setwd("/sysndd_api_volume")

root <- pr("sysndd_plumber.R") %>% 
	pr_run(port = 7777)