# Validation and methodology notes

## Completed local checks

The revised script executes successfully with the included Kaggle v24 snapshot.
The final run produced 16 PNG charts. All assertions in `tests/validate.R`
passed:

- lookup identifiers are unique;
- race years stay within 1950-2024;
- enrichment joins preserve the number of result rows;
- driver keys are complete and keep people with shared surnames separate;
- teammate edges are unique, non-self pairs with valid driver endpoints;
- the sum of teammate degrees equals twice the number of undirected edges;
- outcome-category counts sum to all result rows;
- qualifying summaries are finite;
- pole-to-win percentages stay between zero and 100.

Recorded counts: 26,759 result rows, 1,125 races, 861 distinct drivers, 5,006
unique edges and 815 network vertices. The other 46 drivers have no teammate
edge under this definition.

The local environment used R 4.5.3, igraph 2.3.4, dplyr 1.2.1, ggplot2 4.0.3
and maps 3.4.4. Full session information and the final validation summary are
included in `validation/`. The machine emits four inherited locale warnings
at R startup; the script sets Windows UTF-8 handling before reading data.
The analysis itself completed without analysis warnings. The optional mapping
notice and the smoothing-formula message are informational.

## Report verification

The PDF was rebuilt from the revised chart outputs, replacing the historical
slide images. It has 13 pages, selectable text, a named data source, explanatory
notes, and Irisbaev Nuriddin as its only presenter. The cover uses original
vector shapes. The report was rendered and visually reviewed for clipping,
overlap and legibility. No old cover photograph is included.

## Reproducibility and limits

Input bytes are recorded in `datasets/manifest.json`; provider/version metadata
and the original archive checksum are in `datasets/source-metadata.json`.
The source snapshot is the one supplied by the user through its Kaggle link.
Results are reproducible for this snapshot, without claiming identity with
unavailable inputs used for earlier versions of the project.

Numerical consistency does not validate causal claims. Historical shared-car
records, team identities, nationality labels, rule changes and measurement
conventions affect interpretation. The report states selection criteria and
these limitations beside the charts. Street/permanent comparisons remain
disabled until a reviewed circuit mapping is supplied.

GitHub Actions runs the same R analysis and validation on pushes and pull
requests. Its current results are available in the repository Actions tab.
The local validation records above describe the recorded preparation run.
