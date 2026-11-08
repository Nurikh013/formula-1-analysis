# Formula 1 World Championship Analysis

Exploratory analysis of Formula 1 race outcomes, drivers, circuits, qualifying,
pit stops and teammate networks, covering 1950-2024.

The included 13-page PDF is generated from the revised analysis. It presents
the current charts, their definitions and limitations, with Irisbaev Nuriddin
as presenter. Its cover uses original vector geometry, with no external photo.

## Run the analysis

Requirements: R 4.1+, igraph, dplyr 1.1.0+, ggplot2 3.4.0+, and maps.
From this project folder:

```sh
Rscript setup.R
Rscript F1_script.R
```

Eight required CSV tables are included in `datasets/`. To use a different
input directory, run `Rscript F1_script.R "/path/to/datasets"`.
The analysis exports 16 PNG charts, two network tables and session information
to `outputs/`, which is excluded from version control.

## Validate and rebuild the report

```sh
Rscript tests/validate.R
python -m pip install -r requirements-report.txt
python tools/build_report.py
```

Python 3.9+ and ReportLab are only needed to rebuild the PDF. The existing PDF
can be read without installing analysis tools. Run the R script or validation
first so the chart files exist. The PDF builder must be rerun after changing
the analysis or dataset, so the report remains consistent with the outputs.

The completed local validation covered 26,759 result rows, 1,125 races, 861
drivers, 5,006 unique teammate edges and 815 network vertices. See
[VALIDATION.md](VALIDATION.md) and `validation/` for checks and software versions.
GitHub Actions is configured to run the R analysis and validation after push;
that hosted workflow has not been run yet.

## Data and methodology

Source: Rohan Rao's Kaggle dataset, version 24. Its metadata labels the data
CC0. See [DATA_SOURCE.md](DATA_SOURCE.md), the checksum manifest and the dataset
README for exact provenance and required columns.

Driver IDs are analytical keys; names are display labels. A teammate edge
means two drivers appear for the same constructor in the same race. The graph
counts distinct teammates, not shared-race frequency. Drivers without a
teammate edge are omitted from the network, and a degree filter is used for
the displayed network only.

Race-status categories are explicit analytical conventions. The outcome pie
excludes Other, while season summaries include it. Generic Retired records
are not assumed to be accidents. Qualifying comparisons include only records
with both Q1 and Q3 times. Pit-stop charts use recorded durations under 120
seconds; they do not measure stationary wheel-change time in isolation.

Street/permanent heatmaps are optional and skipped by default: a country is
not a valid circuit-type proxy. See `datasets/README.md` for the optional
reviewed mapping. Era names are descriptive approximations.

These are descriptive summaries, not causal conclusions or forecasts.

## Project contents

- `formula_one.pdf`: regenerated 13-page report.
- `F1_script.R`, `setup.R`: analysis and package setup.
- `datasets/`: input tables, source metadata and SHA-256 manifest.
- `tests/validate.R`: runs the analysis and checks data/output invariants.
- `tools/build_report.py`: reproducible PDF source.
- `validation/`: recorded validation summary and session information.
- `.github/workflows/check.yml`: automated R validation configuration.

## Rights

Kaggle's CC0 label applies to the included source dataset. No open-source
license has been granted for the analysis code or report; public availability
alone does not grant additional reuse permissions. No license is inferred
from the dataset's terms.
