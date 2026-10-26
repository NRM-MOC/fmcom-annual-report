# fmcom-annual-report

Reproducible pipeline for the annual reports on temporal trends and spatial variation in the Swedish National Monitoring Programmes for Contaminants in Freshwater and Marine Biota. It combines the historical data in [fmcom](https://github.com/NRM-MOC/fmcom) (the Freshwater and Marine Contaminant Monitoring dataset) with the new year's lab results, assesses the time series with [HARSAT](https://github.com/osparcomm/HARSAT) and produces the report ("Graphic and statistical overview ...") as a PDF.

Working on the report is also how the new year's data is quality-checked before it is submitted to the [National Contaminants database](https://www.sgu.se/produkter-och-tjanster/datavardskapen-grundvatten-och-miljogifter/rapporterad-data-till-datavardskap-for-miljogifter/) hosted at the Geological Survey of Sweden (SGU) (database only available in Swedish).

> **Status:** marine and freshwater both run end to end. Marine was validated against the scripts used for the 2025 report; freshwater has been tested with the 2024 data.

## How it works

```
            fmcom (historical data, from GitHub)
                           │
lab files + esbase ──► Step 1 ──► new year's data in fmcom format + QC   ──► QC CHECKPOINT 1
                           │
                       Step 2a ──► HARSAT input (fmcom + new year)
                       Step 2b ──► HARSAT assessment, automatic convergence fixes
                       Step 2c ──► tables, time series plots, maps
                           │
                       Step 3  ──► report appendix (PDF)                 ──► QC CHECKPOINT 2
```

The pipeline adds the new year *temporarily* to fmcom, from the lab files. The quality-checked data is submitted to the National Contaminants database through a separate pipeline, and is added to fmcom the following year. The QC checkpoints are where the new year's data and the finished report are reviewed, and labs contacted if something looks wrong.

Both programmes, marine and freshwater, use the same code; each has its own settings file in `config/`.

## Folders

| Folder | Contents |
|---|---|
| `run.R` | Entry point: runs the steps in order |
| `config/` | All settings. `marine.yml` / `freshwater.yml` per programme; `harsat/` HARSAT information files, stations, sums and convergence fixes; `lookups/` names and order used in the report; `report/` threshold tables |
| `R/` | Functions used by the steps |
| `01_raw_data/`, `02_harsat/`, `03_report/` | The step scripts; `03_report/rmd/` report templates, `03_report/text/` year-specific report text |
| `tools/` | Occasional scripts: generic uncertainties and biological averages for the HARSAT information files |
| `data/` | Input data: lab files, esbase (not in git) |
| `output/` | Everything the pipeline produces, per programme and year, e.g. `output/marine_2025/` (not in git) |
| `docs/` | User guide and design notes |

## Getting started

1. Clone the repository and open `fmcom-annual-report.Rproj` in RStudio.
2. Install the R packages and TinyTeX.
3. Create `.Renviron` from `.Renviron.example`, pointing to the data folder (and, optionally, a local HARSAT checkout).
4. Open `run.R`, set `programme`, and run it step by step.

The [user guide](docs/user-guide.md) has the details: setup, run times, running HARSAT as a background job, what to update each year, publishing a report, and adding new contaminants.

## Documentation

- [docs/user-guide.md](docs/user-guide.md): how to set up and run the pipeline
- [docs/pipeline-plan.md](docs/pipeline-plan.md): design decisions, background and open questions

## Data

The lab files and the esbase data are not public, so step 1 can only be run at the Swedish Museum of Natural History. The historical data is public in [fmcom](https://github.com/NRM-MOC/fmcom).

## Licence

Code and documentation: [CC BY 4.0](LICENSE.md), the same licence as fmcom.
