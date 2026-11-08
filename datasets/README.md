# Included input tables

The eight required tables from Rohan Rao's Kaggle dataset, version 24, are
included here. See [data source](../DATA_SOURCE.md), `source-metadata.json`, and
`manifest.json` for provenance, version, row counts, checksums, and the license
listed by Kaggle. Original downloaded CSV bytes are preserved.

- `drivers.csv`: driverId, forename, surname, nationality
- `results.csv`: raceId, driverId, constructorId, statusId, grid, positionOrder
- `races.csv`: raceId, year, circuitId, name
- `circuits.csv`: circuitId, name, country, lat, lng
- `constructors.csv`: constructorId, name, nationality
- `status.csv`: statusId, status
- `qualifying.csv`: raceId, driverId, q1, q2, q3
- `pit_stops.csv`: raceId, driverId, milliseconds

The script treats the literal `\N` as missing data and filters races to
1950-2024. Standings and lap-time files were previously loaded but unused.

## Optional circuit classification

Street/permanent heatmaps are skipped by default because the original
country-based classification was incorrect. To enable them, add a reviewed
`circuit_types.csv` with columns `circuitId,circuit_type`. Each circuit ID must
appear once; allowed values are `Street` and `Permanent`. Unmapped circuits
are excluded. If a venue's type changed historically, extend the mapping and
join to include a season or date range before using it for historical claims.
