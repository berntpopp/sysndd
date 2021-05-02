FROM r-base
MAINTAINER Docker User bernt.popp@gmail.com

RUN R -e "install.packages(c('plumber', 'sealr', 'tidyverse', 'DBI', 'RMariaDB', 'jsonlite', 'config'))"

CMD ["/sysndd_api_volume/start_sysndd_api.R"]