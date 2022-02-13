make_entities_plot <- function(data_tibble) {
	plot <- ggplot(data = data_tibble , aes(x = entry_date, color = category)) +
		stat_bin(data=subset(data_tibble, category=="Definitive"), aes(y=cumsum(..count..)), geom="step", bins = 30) +
		stat_bin(data=subset(data_tibble, category=="Limited"), aes(y=cumsum(..count..)), geom="step", bins = 30) +
		theme_classic() +
		theme(axis.text.x = element_text(angle = -45, hjust = 0), axis.title.x = element_blank(), axis.title.y = element_blank(), legend.position="top", legend.title = element_blank())

	file <- "results/plot.png"
	ggsave(file, plot, width = 4.5, height = 2.5, dpi = 150, units = "in")
	return(base64Encode(readBin(file, "raw", n = file.info(file)$size), "txt"))
}


make_matrix_plot <- function(data_melt) {
	matrix_plot <- ggplot(data = data_melt, aes(x=Var1, y=Var2, fill=value)) +
		geom_tile(color = "white") +
		scale_fill_gradient2(low = "blue", high = "red", mid = "white", midpoint = 0, limit = c(-1,1), space = "Lab", name="Pearson\nCorrelation") +
		theme_classic() +
		theme(axis.text.x = element_text(angle = -90, hjust = 0), axis.title.x = element_blank(), axis.title.y = element_blank(), legend.position="top", legend.title = element_blank()) +
		coord_fixed()

	file <- "results/matrix_plot.png"
	ggsave(file, matrix_plot, width = 3.0, height = 3.5, dpi = 150, units = "in")
	return(base64Encode(readBin(file, "raw", n = file.info(file)$size), "txt"))
}