# Project brief: reproducible pipeline for the annual contaminant reports

## Background

We produce a yearly report on the Swedish National Monitoring Programme for Contaminants in Biota. The current marine report title is *"Graphic and statistical overview of temporal trends and spatial variations in the Swedish National Monitoring Programme for Contaminants in Marine Biota (including data through 2024)"*. There is a parallel freshwater report.

Working on the report is also how we inspect and QC the new year's data and decide whether to contact the laboratories. QC is a core purpose of the pipeline, not a side effect.

All code is in R.

## Current setup (to be replaced)

- Marine and freshwater have separate scripts and separate yearly folders (e.g. `MCOM2025`, `FCOM2025`).
- Each year, the previous year's folder is copied and the scripts are modified.
- Each yearly folder has three subfolders, each with its own R project:
  1. **raw_data**: reads this year's raw lab files and arranges them to match the fmcom format. The data is then submitted to SGU, where additional QC checks happen, then downloaded again from SGU and added to the fmcom database.
  2. **HARSAT**: temporarily attaches the new year's data to fmcom, runs it through HARSAT (statistical assessment tool, installed from GitHub), and produces statistics tables and figures for the report.
  3. **report**: builds the report with an R Markdown script.

## Decisions made

- **One repository and one top-level R project** for both programmes. No yearly copies of the code.
- **Start with marine** (the 2025 marine report is needed now), but design for freshwater from the start: the programme (`marine`/`freshwater`) and year are parameters.
- **Years are handled with git tags**, not folders. Tag the commit used for each published report (e.g. `marine-2025`) so it can be reproduced exactly.
- **Year always means the last year of data included.** For example, `marine-2025` and `output/marine_2025/` mean data through 2025. This applies to the config, output folders and tags. The old folder names were inconsistent: `MCOM25` and `FCOM26` both contained data through 2024.
- **Development happens on the local C drive with test data.** Claude Code has no access to the shared drives. Real runs happen from a clone on the shared drive, or from a local clone with data on the shared drive.

## Target structure

Agreed on 2026-10-13, after reading through the MCOM2025 baseline scripts:

```
<repo>/
├── fmcom-annual-report.Rproj
├── renv.lock                     # pins package versions (fmcom, HARSAT, MoCiS2, MoCiS.tools)
├── config/
│   ├── marine.yml                # year, lab file names, HARSAT substance groups, etc.
│   ├── freshwater.yml
│   ├── lookups/                  # shared name/label tables (replace hard-coded ifelse chains)
│   │   ├── stations.csv          # code -> name -> coordinates
│   │   ├── species.csv           # Latin -> English/short names
│   │   └── determinands.csv      # code -> label, group, order (replaces variables.xlsx
│   │                             #   and contents_for_HARSAT.csv)
│   ├── harsat/                   # HARSAT's own information files
│   │                             #   (determinand, species, thresholds, stations)
│   └── corrections/              # year-specific fixes as data, not code
│       └── marine_2025_harsat_convergence.csv   # the update_assessment() fixes
├── R/                            # shared functions
│   ├── load_fmcom.R              # the only place fmcom is read
│   ├── harsat_helpers.R          # get_basis_nrm, fix_name, ts_plot
│   ├── labels.R                  # name lookups from config/lookups
│   └── report_helpers.R          # appendix_*() template functions
├── 01_raw_data/
│   ├── prepare_new_year.R        # lab files + esbase -> fmcom format
│   └── qc_report.Rmd             # (later)
├── 02_harsat/                    # keeps the folder layout HARSAT expects
│   ├── prepare_harsat_input.R    # fmcom + new year -> one HARSAT input file per substance group
│   ├── run_harsat.R              # loops over substance groups; convergence fixes from corrections/
│   └── tables_figures.R          # time-series plots (.pdf), maps, summary tables, appendix contents
├── 03_report/
│   ├── generate_appendix.R       # writes the appendix .Rmd from templates and renders it to PDF
│   ├── rmd/                      # section templates
│   ├── preamble-latex.tex
│   └── references.bib
├── tools/                        # occasional upkeep, not part of the yearly run
│   ├── generic_uncertainty.R
│   └── biological_averages.R
├── run.R                         # entry point, one call per step
├── data/      (gitignored)       # lab files, esbase, etc.
└── output/    (gitignored)
    └── marine_2025/              # replaces the old "MCOM2025" folder, now generated
```

The yearly publication is the appendix-style PDF ("Graphic and statistical overview ..."), built by `03_report/generate_appendix.R`. The old `generate_report_stuff.R` (main-report figures) is obsolete and has been removed.

The pipeline is not one continuous run: there is a manual break between step 1 and step 2 for the SGU submission/QC/download round-trip. `run.R` should make that break explicit.

## Principles for handling yearly changes

1. **Parameters** (year, stations, species, LOQs, etc.) go in config files, not scripts.
2. **Method improvements** (new QC check, better plot) are committed to main and apply to future years. Old years remain available through their tags.
3. **One-off data fixes** for a specific year (e.g. wrong units from a lab batch, an excluded sample) go in a `config/corrections/` CSV that the pipeline applies, not in `if (year == 2025)` code.
4. **Report narrative** is year-specific. Either edit the report text (`rmd/header.Rmd`) each year and rely on the tag, or keep the text in per-year child documents with shared code for tables and figures.

## Technical requirements

- Use `here::here()` for all paths. No absolute paths in scripts.
- The data location is set in config or `.Renviron` (e.g. `MCOM_DATA_DIR`), so switching between the local test data and the shared drive means changing one line.
- Use **renv**, and pin HARSAT to a specific GitHub commit. MoCiS2 and MoCiS.tools are installed from github.com/NRM-MOC.
- **HARSAT development version:** the user develops HARSAT and loads it with `devtools::load_all()` (currently the develop version, 1.0.6.1011). If `HARSAT_DEV_PATH` is set in `.Renviron`, the pipeline loads that local copy. Otherwise it uses the renv-installed version. Each run records the HARSAT version and commit in its output folder. For a published report, the HARSAT commit used must exist on GitHub so renv can pin it.
- **Keep R Markdown** for the report, not Quarto (decided 2026-10-13). The appendix is generated from templates (`knit_expand`), and moving that to Quarto isn't worth the effort for now. The programme and year come from the config, and output paths are set once, not hard-coded in each `.Rmd` template.
- **Substance groups are looped over**, listed in the config. Don't choose them by commenting lines in and out.
- **fmcom replaces mcomDb** everywhere.
- **Master tables from fmcom:** read contaminant and station tables from the fmcom GitHub repo (`data-raw/master_tables/`) at the same commit as the renv-pinned fmcom package, so they update along with the data and stay reproducible. When to switch: once we start importing raw lab files and have checked that the master tables cover every code needed (the current local `contaminant_SGU_NRM.csv` uses different codes). The HARSAT stations file stays a local config file, because HARSAT needs extra columns and the spring stations.
- **Isolate data access in one function** (e.g. `load_fmcom()`). The contaminant data is moving to Specify, so the data source will change later. Record which fmcom extract or version was used in each run's output.
- When attaching the new year's data to fmcom, **flag it** (e.g. `source = "new_year"`) so QC outputs and plots can highlight it.
- **QC as its own output**: step 1 (and ideally step 2) renders a QC report (e.g. `qc_report.html`) showing new values against the historical range per station/species/determinand, LOQ patterns, missing samples, and HARSAT anomalies. This should be usable for contacting labs without drafting the publication.
- `.gitignore` must exclude `data/`, `output/`, `.Renviron`, and `renv/library/`. No raw lab data in the repo.
- Optional later: `targets` to cache the slow HARSAT run.

## Reproducing a published report (to revisit when we get there)

**Goal:** Years later, someone should be able to rebuild a published report exactly, e.g. `marine-2025`, with the same numbers, tables and figures.

**The problem:** A report is built from three things, and only one of them is in this repo:

1. **The code.** It's in this repo, and the git tag (e.g. `marine-2025`) marks the exact version used.
2. **The historical data (fmcom).** It comes from the public fmcom package (github.com/NRM-MOC/fmcom, version 0.3.0 = data through 2024 at the time of writing). It's installed through renv, and `renv.lock` records the exact fmcom commit used, so restoring the project gets the same historical data back.
3. **The new year's data.** It comes from the raw lab files, which are *not* in the repo (gitignored, and not public). It's also the data *before* the SGU round trip. The SGU QC may change values, so the version that later ends up in fmcom can differ from what the report used.

**The idea:** Step 1 saves its final processed new-year dataset as a frozen file, e.g. `output/marine_2025/new_year_data.rds`, and that file is archived on the shared drive alongside the published report. Together these define the report completely:

- the git tag (code)
- `renv.lock` (package versions, including fmcom and HARSAT)
- the frozen new-year data file

**Things to decide later:**

- Where the frozen files are archived. This could be the shared drive, or a public data repository for the report years if the data can be published.
- Whether to record a checksum of the frozen file in the run output, so we can verify it's the same file.
- Whether fmcom should get git tags or releases per data update (e.g. `v0.3.0`). The version is in its `DESCRIPTION` but doesn't show as a release on GitHub. Tags would make it easier to see which data version a report used than a bare commit ID.

- Whether to make input data available. All current input files, including the raw lab data, HARSAT input and esbase biological data, can in principle be shared. They're kept in the gitignored `data/` folder for now. If committing some of them, or publishing them elsewhere, makes the pipeline easier to run and reproduce, move them out of `.gitignore`.

**Note on fmcom formats:** The local `.rds` copy of fmcom and the package's `.rda` differ slightly in some column formats but are otherwise kept in sync. Before each report, the package is updated with the previous year's data and any bug fixes, so the package (via GitHub and renv) is the source to use for the report.

## Migration plan

1. Copy last year's MCOM scripts into the repo unchanged and commit them as a baseline, so the history shows every change.
2. Restructure into the layout above. Replace hard-coded years and paths with config values and `here()`.
3. Create a small test dataset (an extract or synthetic data with the same columns) for development on the C drive.
4. Run marine 2025 through the new pipeline. Tag it `marine-2025` when the report is published.
5. Add freshwater via `freshwater.yml`. Where scripts really differ, use `switch(programme, ...)` or programme-specific functions in `R/`.

### Freshwater changes to bring into the shared setup

These are the user's notes on changes made in the freshwater version that marine doesn't have yet:

- The appendix contents table is now created in the HARSAT figures script (`tables_figures.R`). Before, it came from the `functions` code in the report folder. The marine version needs adapting from freshwater.
- File paths have been moved out of the `.Rmd` templates, so they only need to be set once.
- Update the reference library (`.bib`), possibly including all references from the original table, and add references to the text outside the tables.
