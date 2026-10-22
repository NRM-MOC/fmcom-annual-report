# fmcom-annual-report

Reproducible pipeline for the annual reports on temporal trends and spatial variation in the Swedish National Monitoring Programmes for Contaminants in Freshwater and Marine Biota. It combines the historical data in [fmcom](https://github.com/NRM-MOC/fmcom) with the new year's lab results, assesses the time series with [HARSAT](https://github.com/osparcomm/HARSAT) and produces the report ("Graphic and statistical overview ...") as a PDF.

Working on the report is also how the new year's data is quality-checked before it is submitted to the [National Contaminants database](https://www.sgu.se/produkter-och-tjanster/datavardskapen-grundvatten-och-miljogifter/rapporterad-data-till-datavardskap-for-miljogifter/) hosted at the Geological Survey of Sweden (SGU). The database is only available in Swedish.

> **Status:** marine runs end to end. Freshwater still needs its own config, HARSAT stations file, report text and report sections (see [Marine and freshwater](#marine-and-freshwater)).

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

**The yearly cycle.** This pipeline adds the new year *temporarily* to fmcom, from the lab files. The QC'd data is submitted to the National Contaminants database through a separate pipeline, and is added into fmcom the following year.

**QC checkpoints.**
1. After step 1: review `qc_step1.csv`, contact labs if needed, fix and re-run step 1.
2. After step 3: look through the report for oddities; if data must be corrected, re-run all steps from step 1.

## Folders

| Folder | Contents |
|---|---|
| `run.R` | Entry point: runs the steps in order |
| `config/` | All settings. `marine.yml` / `freshwater.yml` per programme; `harsat/` HARSAT information files, stations, sums and convergence fixes; `lookups/` names and order used in the report; `report/` threshold tables |
| `R/` | Functions used by the steps |
| `01_raw_data/`, `02_harsat/`, `03_report/` | The step scripts; `03_report/rmd/` report templates, `03_report/text/` year-specific report text |
| `data/` | Input data: lab files, esbase (not in git) |
| `output/` | Everything the pipeline produces, per programme and year, e.g. `output/marine_2025/` (not in git) |
| `docs/pipeline-plan.md` | Design decisions and background |

## Setup

Run everything in RStudio by opening `fmcom-annual-report.Rproj`.

**R packages** (renv is not set up yet; until then install these once):

```r
install.packages(c("tidyverse", "here", "yaml", "readxl", "knitr", "rmarkdown", "kableExtra",
                   "sf", "rnaturalearth", "rnaturalearthdata", "cowplot", "ggspatial",
                   "scales", "remotes", "pkgload", "tinytex"))
remotes::install_github("NRM-MOC/fmcom", upgrade = "never")
remotes::install_github("NRM-MOC/MoCiS2", upgrade = "never")
remotes::install_github("osparcomm/HARSAT@develop", upgrade = "never")   # or load a local copy, see below
```

`upgrade = "never"` avoids updating packages that are already loaded (which on Windows can fail with a `00LOCK` message). Install packages in a fresh R session.

**LaTeX** for the PDF: TinyTeX (`tinytex::install_tinytex()`). If it reports that the local TeX Live is older than the remote repository, update it with `tinytex::reinstall_tinytex()`; missing LaTeX packages are then installed automatically on the first render.

**Local settings (optional).** Copy `.Renviron.example` to `.Renviron` in the project folder and restart R. It is not in git, because the settings differ per computer:
- `FMCOM_DATA_DIR`: where the data folder is. Leave out to use `data/` in the project.
- `HARSAT_DEV_PATH`: a local HARSAT checkout to load with `load_all()`. Leave out to use the installed package, or load HARSAT yourself with `devtools::load_all()` before running; the pipeline uses whatever HARSAT is already loaded.

(Files starting with a dot are hidden in RStudio's Files pane: gear icon → *Show Hidden Files*.)

## Where it is run

The run for the report is done from a local clone of this repository at the Swedish Museum of Natural History with `FMCOM_DATA_DIR` in `.Renviron` pointing to the data there.

## Running

Open `run.R`, set `programme <- "marine"` (or `"freshwater"`), and run it section by section, stopping at the QC checkpoints.

| Step | Run time (marine 2025) | Main output in `output/<programme>_<year>/` |
|---|---|---|
| 1 New year's data + QC | ~20 s | `new_year_data.rds/.csv`, `qc_step1.csv` |
| 2a HARSAT input | ~10 s | `harsat/data/` |
| 2b HARSAT | **~3 h** | `harsat/assessments/`, `harsat/convergence_log.csv`, `harsat/oddities/` |
| 2c Tables and figures | ~20 min | `harsat/biota_summary.csv`, `harsat/figs/`, `harsat/tables/`, `harsat/contents_for_appendix.csv` |
| 3 Report | ~2–6 min | `report/appendix_<programme>_<year>.pdf` |

Each step also writes `run_info_step<n>.yml`: code version, fmcom and HARSAT versions, R version and the input files used.

To run HARSAT (2b) and the tables and figures (2c) for some groups only, set e.g. `harsat_groups <- c("PAH")` before those steps.

**Convergence.** Time series whose HARSAT model doesn't converge are diagnosed and refitted automatically with the fixes in `config/harsat/convergence_fixes.yml`. `harsat/convergence_log.csv` lists every series, what was tried and the fix that worked (or "unresolved"). Series fixed with the smaller hess step are worth a visual check.

## Each new year

1. **fmcom** is updated with last year's data (in the fmcom repository), then reinstalled here.
2. **`config/<programme>.yml`**:
   - `year:` the last year of data
   - `raw_data:` the lab file folder and the exact lab file names (they change every year), and the esbase file
   - `report:` authors, and the citation year
3. **`03_report/text/<programme>.Rmd`**: front page photo, acknowledgements (labs, project leaders, chemists), introduction and method updates. The file starts with a checklist.
4. **`config/report/thresholds_<programme>.csv`** if thresholds have changed.
5. Run the pipeline. Output goes to a new folder (e.g. `output/marine_2026/`); earlier years are not touched.

## When the report is published

1. Commit and push everything used for the report.
2. Tag that version, so it can always be found again:
   ```bash
   git tag -a marine-2025 -m "Marine report 2025 (data through 2025)"
   ```
   ```bash
   git push origin marine-2025
   ```
3. Archive `output/marine_2025/` (the PDF, `new_year_data.rds` and the `run_info` files) on the shared drive. The lab files and esbase data are not in git, so `new_year_data.rds` is what makes the report reproducible together with the tagged code.

To look at an earlier version later: `git checkout marine-2025`, or download it from the tag on GitHub.

## Adding a new contaminant

For example, the new PFAS compounds that will be added over the coming years. Update these, in pipeline order, as far as the substance should go:

1. **MoCiS2 code list** (`inst/extdata/codelist.xlsx`, sheet `PARAMETRAR`, in NRM-MOC/MoCiS2): needed for the lab file code to be read at all.
   *If missing:* MoCiS2 warns "Unable to match the following substance codes", the rows are dropped, and the warning appears in `qc_step1.csv`.
2. **fmcom master table** (`data-raw/master_tables/contaminants_SGU_NRM.csv` in NRM-MOC/fmcom): gives the SGU code its fmcom name and substance group.
   *If missing:* `qc_step1.csv` reports "Substance codes not in the fmcom master table".
3. **HARSAT information files** (`config/harsat/determinand.csv`, plus `thresholds_biota.csv` if there is a threshold): needed for HARSAT to assess it. If the substance is part of a sum (e.g. PFAS-24), also update `config/harsat/determinand_sums.yml`.
   *If missing:* HARSAT leaves it out. That's intended until there are enough years of data (at least 5–10) to show trends.
4. **Report names** (`config/lookups/determinands.csv`): the name shown in plots, tables and the appendix, its report group and its order within the group.
   *If missing:* step 2c warns "Assessed but not in config/lookups/determinands.csv", and the substance is left out of the appendix.

If the substance belongs to a new substance group, also add the group to `harsat: groups:` in `config/<programme>.yml`.

## Marine and freshwater

Both programmes use the same code and the same HARSAT information files; `programme` in `run.R` chooses the config file. Programme-specific are:

| | Marine | Freshwater |
|---|---|---|
| Settings | `config/marine.yml` | `config/freshwater.yml` (placeholder) |
| HARSAT stations | `config/harsat/stations_marine.csv` | `stations_freshwater.csv` (to create) |
| Threshold table | `config/report/thresholds_marine.csv` | to create |
| Year-specific text | `03_report/text/marine.Rmd` | to create |
| Report sections | herring, fish, mussel, egg | perch, fish (the section logic in `R/report_helpers.R` still has the marine species groups built in) |
