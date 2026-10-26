# User guide

How to set up and run the pipeline, and what to update each year. For an overview of what the repository does, see the [README](../README.md); for design decisions and open questions, see [pipeline-plan.md](pipeline-plan.md).

**Contents**

1. [Setup](#setup)
2. [Running](#running)
3. [Each new year](#each-new-year)
4. [The esbase extract](#the-esbase-extract)
5. [Biological variables](#biological-variables)
6. [Marine and freshwater](#marine-and-freshwater)
7. [When the report is published](#when-the-report-is-published)
8. [Adding a new contaminant](#adding-a-new-contaminant)

## Setup

Run everything in RStudio by opening `fmcom-annual-report.Rproj`. The run for the report is done from a clone of this repository at the Swedish Museum of Natural History, with the data in a folder on the shared drive:

```bash
git clone https://github.com/NRM-MOC/fmcom-annual-report.git
```

### R packages

renv is not set up yet; until then, install these once:

```r
install.packages(c("tidyverse", "here", "yaml", "readxl", "knitr", "rmarkdown", "kableExtra",
                   "sf", "rnaturalearth", "rnaturalearthdata", "cowplot", "ggspatial",
                   "scales", "remotes", "pkgload", "tinytex"))
remotes::install_github("NRM-MOC/fmcom", upgrade = "never")
remotes::install_github("NRM-MOC/MoCiS2", upgrade = "never")
remotes::install_github("osparcomm/HARSAT@develop", upgrade = "never")   # or use a local copy, see below
```

`upgrade = "never"` avoids updating packages that are already loaded (which on Windows can fail with a `00LOCK` message). Install packages in a fresh R session.

### LaTeX

The PDF needs TinyTeX: `tinytex::install_tinytex()`. If it reports that the local TeX Live is older than the remote repository, update it with `tinytex::reinstall_tinytex()`; missing LaTeX packages are then installed automatically on the first render.

### Local settings (.Renviron)

Settings that differ per computer go in a file called `.Renviron` in the project folder (the folder with `fmcom-annual-report.Rproj`). It is not in git. Start from `.Renviron.example`:

```
FMCOM_DATA_DIR="X:/path/to/data"
HARSAT_DEV_PATH=C:/Users/<you>/github/HARSAT
```

- `FMCOM_DATA_DIR`: the data folder, the one that **contains** `marine/` and `freshwater/` (with `lab_files/` and `esbase/` in each). Leave it out to use `data/` in the project.
- `HARSAT_DEV_PATH`: a local HARSAT checkout, loaded with `pkgload::load_all()`. Leave it out to use the installed harsat package. The pipeline uses HARSAT in this order: a copy already loaded in the session (e.g. with `devtools::load_all()`), then `HARSAT_DEV_PATH`, then the installed package. Check that the checkout is on the intended commit (`git log -1` in the HARSAT folder); each run records the version and commit it used in `run_info_step2.yml`.

Common problems:

- **The file must be called exactly `.Renviron`**, with no extension. Windows editors often save it as `.Renviron.txt`, which R does not read. Create and save it from RStudio (File → New File → Text File), or rename it with `file.rename(".Renviron.txt", ".Renviron")`.
- **Lines starting with `#` are comments.** Remove the `#` in front of the settings you use.
- **Put quotes around paths that contain spaces**, as in the example. Use forward slashes.
- End the file with an empty line, and **restart R** after changing it (or run `readRenviron(".Renviron")`).

Check that R sees the settings:

```r
Sys.getenv("FMCOM_DATA_DIR")
list.files(file.path(Sys.getenv("FMCOM_DATA_DIR"), "marine", "lab_files"))
```

If the first line prints `""`, R has not read the file. Files starting with a dot are hidden in RStudio's Files pane: gear icon → *Show Hidden Files*.

## Running

Open `run.R`, set `programme <- "marine"` (or `"freshwater"`), and run it section by section, stopping at the QC checkpoints.

| Step | Run time, marine 2025 | Run time, freshwater 2024 | Main output in `output/<programme>_<year>/` |
|---|---|---|---|
| 1 New year's data + QC | ~20 s | ~20 s | `new_year_data.rds/.csv`, `qc_step1.csv` |
| 2a HARSAT input | ~10 s | ~10 s | `harsat/data/` |
| 2b HARSAT | **~4.5 h** | **~2.5 h** | `harsat/assessments/`, `harsat/convergence_log.csv`, `harsat/oddities/` |
| 2c Tables and figures | ~20 min | ~15 min | `harsat/biota_summary.csv`, `harsat/figs/`, `harsat/tables/`, `harsat/contents_for_appendix.csv` |
| 3 Report | ~2–6 min | ~1 min | `report/appendix_<programme>_<year>.pdf` |

Run times are from a 14-core laptop; with fewer cores, or with the project on a network drive, step 2b takes longer.

Each step also writes `run_info_step<n>.yml`: code version, fmcom and HARSAT versions, R version and the input files used.

### QC checkpoints

1. **After step 1:** review `qc_step1.csv`, contact labs if needed, fix and re-run step 1. Among other things, it checks that every lab specimen has biological data in esbase, and that each lab station matches one esbase location (which catches wrong specimen IDs in a lab file).
2. **After step 3:** look through the report for oddities; if data must be corrected, re-run all steps from step 1.

### Running some groups only

To run HARSAT (2b) and the tables and figures (2c) for some groups only, set e.g. `harsat_groups <- c("PAH")` before those steps. Remove it (`rm(harsat_groups)`) to run all groups again.

### Running HARSAT as a background job

Step 2b takes several hours. To keep RStudio free while it runs, and to avoid the slow output in the console, run steps 2a–2c as an RStudio background job with `02_harsat/run_step2_job.R`. It runs in a separate R session; progress shows in RStudio's Background Jobs tab. Start it from the console:

```r
programme <- "marine"   # or "freshwater"
rstudioapi::jobRunScript(here::here("02_harsat", "run_step2_job.R"),
                         workingDir = here::here(), importEnv = TRUE)
```

`importEnv = TRUE` passes `programme` (and `harsat_groups`, if set) to the job. Run step 3 afterwards, once the convergence log has been checked.

### Convergence

Time series whose HARSAT model doesn't converge are diagnosed and refitted automatically with the fixes in `config/harsat/convergence_fixes.yml`. `harsat/convergence_log.csv` lists every series, what was tried and the fix that worked (or "unresolved"). Series fixed with the smaller hess step are worth a visual check.

### Years left out of the trend fit

HARSAT leaves some years out of the trend fit: years before a six-year block without data, early years in which fewer than half of the years have values above LOQ, and, in a few series, early years that it drops until the model converges. The time series figures show all years, with those left out in grey.

## Each new year

1. **fmcom** is updated with last year's data (in the fmcom repository), then reinstalled here.
2. **`config/<programme>.yml`**:
   - `year:` the last year of data
   - `raw_data:` the exact lab file names under `lab_files:` (they change every year), and the esbase file.
   - `report:` authors, and the citation year
3. **The data folder:** put the lab files in `<data folder>/<programme>/lab_files/` and the esbase extract in `<data folder>/<programme>/esbase/`.
4. **`03_report/text/<programme>.Rmd`**: front page photo, acknowledgements (labs, project leaders, chemists), introduction and method updates. The file starts with a checklist.
5. **`config/report/thresholds_<programme>.csv`** if thresholds have changed.
6. Run the pipeline. Output goes to a new folder (e.g. `output/marine_2026/`); earlier years are not touched.

If you edit files in the server clone (e.g. the config), commit them there before `git pull`, so changes from GitHub can be merged in.

## The esbase extract

The biological data (date, sex, age, length, weight) comes from esbase. Set the file in `raw_data: esbase_file:`.

The column names have sometimes differed between extracts, so the pipeline looks for each field under the names seen so far (`esbase_columns` in `R/raw_data.R`), and translates Swedish species names to Latin. If a new extract uses a name that isn't known, step 1 stops and says which column is missing; add the new name in the config under `raw_data: esbase_columns:`.

## Biological variables

Age, total length, weight, fat % and dry weight % are assessed in their own HARSAT run (`bio` in `harsat: groups:`), separately from the contaminants. Each variable comes from one source, so nothing is counted twice (`harsat: biological:` in the config):

- age, length and weight: one value per specimen
- fat %: only from the dioxin lab (UMU), whose method has not changed over time
- dry weight %: only from the samples analysed for mercury

Weight is modelled as log-normal, like the contaminants (its spread grows in proportion to the mean), so its trends are in percent per year. The other variables are modelled as normal, so their trends are in units per year (percentage points for fat % and dry weight %). HARSAT currently rounds the changes in its summary to one decimal, so small trends in normal series (e.g. fat %) are shown as 0.

## Marine and freshwater

Both programmes use the same code and the same HARSAT information files; `programme` in `run.R` chooses the config file. Programme-specific are:

| | Marine | Freshwater |
|---|---|---|
| Settings | `config/marine.yml` | `config/freshwater.yml` |
| HARSAT stations | `config/harsat/stations_marine.csv` | `config/harsat/stations_freshwater.csv` |
| Threshold table | `config/report/thresholds_marine.csv` | `config/report/thresholds_freshwater.csv` (no mussels) |
| Year-specific text | `03_report/text/marine.Rmd` | `03_report/text/freshwater.Rmd` |
| Report sections (`report: sections:`) | herring, fish, mussel, egg | perch; pike and Arctic char |
| Winter samples (`raw_data: exclude_winter:`) | excluded | kept |
| Species not assessed (`harsat: exclude_species:`) | none | roach |
| Station order in tables (`tables_figures: station_order:`) | along the coast | north to south |

Each part of a substance's section in the report is a template in `03_report/rmd/` with the species codes it shows, set in `report: sections:`.

## When the report is published

GitHub keeps the code; the shared drive keeps the results. `output/` is not in git (the results contain data, and the folder is large).

1. Commit and push everything used for the report.
2. Tag that version, so it can always be found again:
   ```bash
   git tag -a marine-2025 -m "Marine report 2025 (data through 2025)"
   ```
   ```bash
   git push origin marine-2025
   ```
3. Keep `output/marine_2025/` on the shared drive: at least the PDF, `new_year_data.rds`, `harsat/assessments/` (the fitted HARSAT models, so results can be inspected later without re-running HARSAT) and the `run_info` files. The lab files and esbase data are not in git, so `new_year_data.rds` is what makes the report reproducible together with the tagged code.

**Re-running the same year overwrites `output/<programme>_<year>/`.** Copy the folder elsewhere first if you re-run after the report is published.

To look at an earlier version of the code later: `git checkout marine-2025`, or download it from the tag on GitHub.

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
