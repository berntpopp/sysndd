FROM rocker/tidyverse:latest
## Install Java
RUN apt-get update && apt-get install -y \
default-jdk \
## used for keyring package
libsecret-1-dev \
## used to build rJava and other packages
libbz2-dev \
libicu-dev \
liblzma-dev
RUN install2.r Rcpp plumber DBI RMariaDB jsonlite config jose RCurl stringdist xlsx easyPubMed rvest lubridate pool memoise coop reshape2 blastula keyring future knitr timetk
