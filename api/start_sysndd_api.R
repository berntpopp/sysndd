library(plumber)

setwd("/sysndd_api_volume")

root <- pr("sysndd_plumber.R") %>% 
	pr_run(host = "0.0.0.0", port = 7777)