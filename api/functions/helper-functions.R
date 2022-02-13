# nest the gene tibble
# based on https://xiaolianglin.com/2018/12/05/Use-memoise-to-speed-up-your-R-plumber-API/
nest_gene_tibble <- function(tibble) {
    nested_tibble <- tibble %>%
        nest_by(symbol, hgnc_id, .key = "entities")
    
    return(nested_tibble)
}


# generate a random password
# based on https://stackoverflow.com/questions/22219035/function-to-generate-a-random-password
random_password <- function() {
	samp <- c(0:9, letters, LETTERS, "!", "$")
	password <- paste(sample(samp, 12), collapse="")
	return(password)
}


# validate email
# based on https://www.r-bloggers.com/2012/07/validating-email-adresses-in-r/
isValidEmail <- function(x) {
    grepl("\\<[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}\\>", as.character(x), ignore.case=TRUE)
}


# generate initials for avatar from full name
# based on https://stackoverflow.com/questions/24833566/get-initials-from-string-of-words
generate_initials <- function(first_name, family_name) {
		initials <- paste(substr(strsplit(paste0(first_name, " ", family_name), " ")[[1]], 1, 1), collapse="")
		return(initials)
}


# send noreply mail
send_noreply_email <- function(email_body, email_subject, email_recipient, email_blind_copy = "noreply@sysndd.org") {
		email <- compose_email(
			body = md(email_body),
			footer = md("Visit [SysNDD.org](https://www.sysndd.org) for the latest information on Neurodevelopmental Disorders.")
			)

		suppressMessages(email %>%
		  smtp_send(
			from = "noreply@sysndd.org",
			subject = email_subject,
			to = email_recipient,
			bcc = email_blind_copy,
			credentials = creds_envvar(
				pass_envvar = "SMTP_PASSWORD",
				user = dw$mail_noreply_user,
				host = dw$mail_noreply_host,
				port = dw$mail_noreply_port,
				use_ssl = dw$mail_noreply_use_ssl
			)
		  ))
		return("Request mail send!")
}