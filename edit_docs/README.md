# SysNDD-Documentation

The repository subfolder for the SysNDD documentation.

First change the work directory:

```
## workfolder <- "path/to/the/edit_docs/"
setwd(workfolder)
```

Then build the documentation:

```
bookdown::render_book("index.Rmd", "all")
```

Rendering HTML widgets for PDF requires webshot and phantomjs [FROM:](https://bookdown.org/yihui/bookdown/html-widgets.html).
```
install.packages("webshot")
webshot::install_phantomjs()
```

The CSL file is [American Psychological Association 7th edition, from Zotero](https://www.zotero.org/styles/apa).