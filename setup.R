# Run once: Rscript setup.R
packages <- c("igraph", "dplyr", "ggplot2", "maps")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
if (packageVersion("ggplot2") < "3.4.0") {
  stop("ggplot2 >= 3.4.0 is required for linewidth support.")
}
print(sessionInfo())

if (packageVersion("dplyr") < "1.1.0") stop("dplyr >= 1.1.0 is required.")
