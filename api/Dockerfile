FROM rocker/tidyverse:4.3.2
RUN apt-get update && apt-get install -y \
## build tools for factoextra compilation
build-essential git wget libpcre3 libpcre3-dev libssl-dev zlib1g-dev cmake \
## Install Java
default-jdk \
## used for keyring package
libsecret-1-dev \
## used to build rJava and other packages
libbz2-dev \
libicu-dev \
liblzma-dev \
libsodium-dev \
libtool
RUN Rscript -e 'install.packages(c("httr", "stringr", "ellipsis", "ontologyIndex", "vctrs"), repos="https://cloud.r-project.org")'
RUN Rscript -e 'install_version("pool", version = "1.0.1", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("Rcpp", version = "1.0.10", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("plumber", version = "1.2.1", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("DBI", version = "1.1.3", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("RMariaDB", version = "1.2.2", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("jsonlite", version = "1.8.4", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("config", version = "0.3.1", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("jose", version = "1.2.0", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("RCurl", version = "1.98-1.12", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("stringdist", version = "0.9.10", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("xlsx", version = "0.6.5", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("easyPubMed", version = "2.13", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("rvest", version = "1.0.3", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("lubridate", version = "1.9.2", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("memoise", version = "2.0.1", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("coop", version = "0.6-3", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("reshape2", version = "1.4.4", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("blastula", version = "0.3.3", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("keyring", version = "1.3.1", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("future", version = "1.32.0", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("knitr", version = "1.43", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("rlang", version = "1.1.1", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("timetk", version = "2.8.3", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("xml2", version = "1.3.4", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("igraph", version = "1.4.3", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("BiocManager", version = "1.30.21", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("logger", version = "0.2.2", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("tictoc", version = "1.2", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("fs", version = "1.6.2", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("factoextra", version = "1.0.7", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'install_version("FactoMineR", version = "2.8", repos = "http://cran.us.r-project.org")'
RUN Rscript -e 'BiocManager::install(c("STRINGdb"))'
