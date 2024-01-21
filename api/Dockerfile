FROM rocker/tidyverse:4.2.1
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
RUN Rscript -e 'install.packages(c("Rcpp", "plumber", "DBI", "RMariaDB", "jsonlite", "config", "jose", "RCurl", "stringdist", "xlsx", "easyPubMed", "rvest", "lubridate", "pool", "memoise", "coop", "reshape2", "blastula", "keyring", "future", "knitr", "rlang", "timetk", "xml2", "igraph", "BiocManager", "logger", "tictoc", "fs", "factoextra", "FactoMineR", "vctrs", "httr", "stringr", "ellipsis", "ontologyIndex"), repos="https://cloud.r-project.org")'
RUN Rscript -e 'BiocManager::install(c("STRINGdb"))'