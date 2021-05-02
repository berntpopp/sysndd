library(plumber)

root <- pr("sysndd_plumber.R") %>% 
	pr_run(port = 7777)