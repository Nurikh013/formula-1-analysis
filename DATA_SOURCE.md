# Data source

Provider: Rohan Rao (Kaggle username `rohanrao`).

[Formula 1 World Championship (1950 - 2024)](https://www.kaggle.com/datasets/rohanrao/formula-1-world-championship-1950-2020)

The URL retains its older `1950-2020` slug. The retrieved dataset is version 24,
last updated 2025-01-29, and its `races.csv` covers 1950 through 2024.
The download and metadata were retrieved on 2026-11-08.

Kaggle's dataset metadata lists **CC0: Public Domain**. This description applies
to the downloaded dataset; it is not a license for the project's code, slides,
or cover photo. The downloaded archive includes 14 tables; the eight tables
actually required by this analysis are included under `datasets/`.

`datasets/manifest.json` records the exact row count and SHA-256 checksum of
each included table. `datasets/source-metadata.json` records the version,
provider metadata, retrieval date, and downloaded archive checksum. These let
future readers distinguish this snapshot from later Kaggle updates.

Download endpoint used:
https://www.kaggle.com/api/v1/datasets/download/rohanrao/formula-1-world-championship-1950-2020

The retrieved snapshot is suitable for testing this revised script, but its
identity with the dataset originally used to create the slide images cannot
be established without the original project's data or checksums.
