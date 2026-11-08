# Run from the project root: Rscript tests/validate.R
# Runs the actual analysis and checks key data and graph invariants.
analysis <- new.env()
source("F1_script.R", local = analysis, encoding = "UTF-8")
with(analysis, {
  stopifnot(nrow(results) > 0,
            !anyDuplicated(drivers$driverId),
            !anyDuplicated(races$raceId),
            !anyDuplicated(circuits$circuitId),
            !anyDuplicated(constructors$constructorId),
            !anyDuplicated(status$statusId),
            all(races$year >= 1950 & races$year <= 2024),
            nrow(ds_f1) == nrow(results),
            !anyNA(ds_f1$driver_key),
            !anyDuplicated(unique_edges),
            all(unique_edges$Source != unique_edges$Target),
            all(unique_edges$Source %in% drivers$driver_key),
            all(unique_edges$Target %in% drivers$driver_key),
            sum(all_drivers_df$Appearances) == 2 * nrow(unique_edges),
            all(pole_win$conversion >= 0 & pole_win$conversion <= 100),
            all(is.finite(qual_by_year$avg_improvement)),
            sum(status_year_counts$count) == nrow(results))
  # Same-surname drivers must remain separate graph vertices when present.
  shared <- drivers$surname[duplicated(drivers$surname)]
  stopifnot(length(shared) > 0,
            !anyDuplicated(drivers$driver_key[drivers$surname %in% shared]))
  summary <- c(paste("Result rows:", nrow(results)),
               paste("Distinct drivers:", length(unique(ds_f1$driver_key))),
               paste("Teammate edges:", nrow(unique_edges)),
               paste("Graph vertices:", nrow(all_drivers_df)),
               paste("PNG charts:", length(list.files(image_dir, pattern = "\\.png$"))),
               "All validation assertions passed.")
  writeLines(summary, file.path(output_dir, "validation-summary.txt"))
  cat(paste(summary, collapse = "\n"), "\n")
})
