# Project brief: reproducible pipeline for the annual contaminant reports

## Background

We produce a yearly report on the Swedish National Monitoring Programme for Contaminants in Biota. The current marine report title is *"Graphic and statistical overview of temporal trends and spatial variations in the Swedish National Monitoring Programme for Contaminants in Marine Biota (including data through 2024)"*. There is a parallel freshwater report.

Working on the report is also how we inspect and QC the new year's data and decide whether to contact the laboratories. QC is a core purpose of the pipeline, not a side effect.

All code is in R.

## Current setup (to be replaced)

- Marine and freshwater have separate scripts and separate yearly folders (e.g. `MCOM2025`, `FCOM2025`).
- Each year, the previous year's folder is copied and the scripts are modified.
- Each yearly folder has three subfolders, each with its own R project:
  1. **raw_data**: reads this year's raw lab files and arranges them to match the fmcom format.
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

### The yearly cycle and the National Contaminants database

The data is reported to the [National Contaminants database](https://www.sgu.se/produkter-och-tjanster/datavardskapen-grundvatten-och-miljogifter/rapporterad-data-till-datavardskap-for-miljogifter/) (Datavärdskap för miljögifter), hosted at the Geological Survey of Sweden (SGU). The database is only available in Swedish, which makes it hard to use for researchers who don't read Swedish. Codes and names from the database keep "SGU" in their names in fmcom and MoCiS2 (e.g. `station_code_SGU`, `contaminant_code_SGU`, `contaminants_SGU_NRM.csv`).

Nothing in this pipeline goes to the national database. The cycle is:

1. **Before the report:** last year's data, downloaded from the national database after its QC, is added to fmcom (in the fmcom repo).
2. **The report (this pipeline):** the new year's data is read from the lab files, QC'd, temporarily attached to fmcom, and run through HARSAT, tables, figures and the report.
3. **After the report:** the QC'd new-year data is converted and submitted to the national database through a separate pipeline, which adds another QC layer.
4. **Next year:** that data is downloaded from the national database and added to fmcom, and the cycle starts again.

The pipeline is still not one continuous run. There are **two QC checkpoints**, and `run.R` makes both explicit:

1. **After step 1 (new year's data):** you review the QC output, contact labs, and add corrections before continuing to step 2.
2. **After step 3 (the finished report):** you look through the report for oddities and contact labs where needed. After correcting, you re-run all three steps.

Today both checkpoints are visual, human review. **Later:** make more of the step 1 QC automatic, with scripted checks (e.g. values outside the historical range, unexpected LOQ patterns, missing samples) that flag problems before anyone looks at plots.

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
- **Master tables from fmcom:** read contaminant and station tables from the fmcom GitHub repo (`data-raw/master_tables/`) at the same commit as the renv-pinned fmcom package, so they update along with the data and stay reproducible. Done in step 1 (2026-10-21). The old local `contaminant_SGU_NRM.csv` and `stations_SGU_marine.xlsx` have been removed. Until fmcom is installed from GitHub, the tables are read from fmcom's `master` branch, and the run record says so. The HARSAT stations file stays a local config file, because HARSAT needs extra columns and the spring stations.
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
3. **The new year's data.** It comes from the raw lab files, which are *not* in the repo (gitignored, and not public). It's also the data *before* it goes through the national database. The database's QC may change values, so the version that later ends up in fmcom can differ from what the report used.

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

### Station names and season in the new year's data

- **The fmcom convention applies:** a plain station name (e.g. "Ängskärsklubb") and season in a separate column. The lab files follow this convention, through the drop-down list in the lab spreadsheets. The old MoCiS convention ("Ängskärsklubb höst/vår") is being phased out.
- **Season comes from the sampling date** (esbase catch date, joined by specimen ID), using the same rule as fmcom's `data-raw/adding_next_year_fmcom.R`:
  - January–February: Winter
  - March–June and July 1–15: Spring
  - July 16–December: Autumn

  Compare the day as a number, because of a possible bug in fmcom where July 1–9 get no season (reported as an fmcom issue).
- **Winter samples are excluded** from the analysis, because winter conditions affect contaminant concentrations. Winter samples are no longer collected, and the few old ones have already been removed from fmcom, so this should rarely happen. If any new-year sample does fall in winter, it's left out of the analysis but **listed in the QC output** (often it will be a wrong date), not dropped silently.
- **MoCiS2:** the code list needs a plain "Ängskärsklubb" entry (like the existing plain "Utlängan"). `moc_read_lab()` also needs `na.rm = TRUE` in the fuzzy station check, so that an unknown station gives a warning instead of an error. The user is making these changes in NRM-MOC/MoCiS2.

### Step 1: how the new year's data is built (implemented 2026-10-21)

Step 1 mirrors fmcom's `data-raw/adding_next_year_fmcom.R`, which converts the national database download into fmcom rows. Step 1 starts from the lab files read with MoCiS2 instead, i.e. the same data before it goes to the national database. That way the temporary new-year dataset looks the way the data will look in fmcom next year. Differences from the fmcom script are marked "Differs from fmcom" in `R/raw_data.R`.

- **Lab files** are listed in `config/<programme>.yml`, because their names change every year. Step 1 warns about `.xlsm` files in the folder that aren't listed, and ignores Excel lock files (`~$`).
- **Stations and contaminants** are joined to the fmcom master tables on the national database codes (`PROVPLATS_ID` = `station_code_SGU`, `UNIK_PARAMETERKOD` = `contaminant_code_SGU`), not on names. Extra spaces in the master tables are stripped on reading.
- **CB-118U** (CB118 from the Umeå lab) is kept as CB118 with laboratory UMU, as fmcom has it. From 2025, CLC is no longer measured, so it's the only CB118 source, and HARSAT's TEQ sums need it.
- **Isotopes** are included whenever an SI file is listed (read with `negative_for_nondetect: false`). The step 1 output is a temporary dataset, also used during the year, but it doesn't need to be complete.
- **Censoring:** `LOQ_LOD` and `is_censored` come from MoCiS2's flags: `b` → `<LOD`, `q` → `<LOQ`, `q` + `Ja` → `>LOD, <LOQ`. This differs from fmcom, whose national database download seems to lose `Ja` (reported as an fmcom issue). **Uncertainty** is MoCiS2's `MATOSAKERHET`, which is in the same unit as the value.
- **Method rules** (`config/method_rules.csv`): egg content needs a different extraction method than the one the lab reports for all tissues. The rules are BFR `SLV_m064_f3` → `f4` and CLC `SLV_m063_f3` → `f2`. They match on the reported method, so fat % rows are never changed. In fmcom format both BFR methods map to `SFA_CLC_BFR`, so the rule matters mainly for the submission to the national database.
- **As in fmcom:**
  - bismuth (`Bi`) is kept
  - PFAS in muscle is removed (only liver is used)
  - pooled samples get sex "Mixed"
  - eggs get age 0
  - fat % and dry weight % are attached per lab sample (`sample_ID`)
  - the metals file's `TPRC` is dropped, as in the national database submission script
- **Samples without esbase data** (no date) get their year from the config and are listed in the QC output.
- **Identical rows from a lab file** are removed and counted in the QC output. In 2025, the PFAS file listed FHXSA twice in its accreditation list, which made MoCiS2 repeat every FHXSA row.
- **Checked against the old script** on the 2025 files: in the 5,221 rows both produced, every value and unit is identical. All other differences come from the decisions above.

**Open follow-ups from the 2025 run:**
- Biological data is missing for 2 Kinnbäcksfjärden herring pools (`B2026/...`).
- Mussels and guillemot eggs have no catch dates in the esbase extract.
- The Umeå instrument code changed (`GC-MS-MS-QQQ` in 2024, `GC-MS-MS` in 2025). It needs checking with the lab, and fmcom's method master table needs adjusting.
- A possible MoCiS2 fix: `distinct()` in `read_lab_file_ackr()`.

### Checklist: adding a new contaminant

Moved to the user guide (`docs/user-guide.md`, "Adding a new contaminant").

### Later additions

- **Measurement uncertainty** (reviewed 2026-10-23; to discuss with the statistician):
  - *What the number is.* fmcom's `uncertainty` is the labs' **expanded uncertainty U2** (k = 2) in the unit of the value. MoCiS2 submits it to the national database as `MATOSAKERHET` with `MATOSAKERHET_TYP = "U2"` and a unit, but fmcom keeps only the number, so the type isn't documented in fmcom itself. Worth raising in fmcom: keep the type and unit, or document them.
  - *Fixed:* step 2a passed U2 to HARSAT as a percentage labelled `%`, which HARSAT reads as a relative SD, so reported uncertainties entered twice too large (variance × 4). The old MCOM25 scripts did the same. Step 2a now passes the absolute value labelled `U2`, and HARSAT halves it.
  - *Waiting for review:* the generic `biota_sd_constant`/`biota_sd_variable` in `config/harsat/determinand.csv`, used for the ~75 % of values without a reported uncertainty. The current `sd_variable` is the mean relative U2 (about twice too large as an SD), and the current `sd_constant` is on the wrong unit and basis (often orders of magnitude too large). `tools/generic_uncertainty.R` now re-estimates both the way HARSAT's own `ctsm_uncrt_estimate()` does, from marine and freshwater data together, and writes a comparison to `output/tools/` without changing `determinand.csv`. A one-page note with the findings and questions was written for the meeting.
  - *Data follow-up:* about 4,000 values in fmcom have an uncertainty larger than the value (mostly SFA PCBs and pesticides 2022–2023, SU 2012–2019), probably percentages or wrong units in the submitted data. Listed in `output/tools/implausible_uncertainties.csv`.
  - *Biological variables:* hand-set first approximations (2026-10-22), correctly halved where they come from U2: dry weight % from the labs' 4 % (U2), lipid weight % from the BFR lab's 25 % (U2; the dioxin lab reports 100 %, probably a placeholder), and measurement precision for age, length and weight.
  - *After the decision:* re-run both reports (freshwater about 1.5 h, marine about 3 h) and compare with the current results.
- **Average dry weight and lipid % in `config/harsat/species.csv`** updated from fmcom on 2026-10-23 with `tools/biological_averages.R` (marine and freshwater together). This corrected three old entries: cod liver lipid (10.03 → 36.6), eelpout lipid (measured in muscle, was in the liver column) and Arctic char dry weight (muscle and liver were swapped). Perch liver lipid (0.73) is kept: fmcom has no perch liver fat values, and its source is unknown. Re-run the tool every few years as data accumulates.
- **Rounding of trends for the biological variables (HARSAT):** HARSAT rounds `overall_change`, `recent_change` and `dtrend` to one decimal. That suits % per year for contaminants, but for the biological variables (`normal` distribution, trends in the variable's own unit per year) small changes in age or length show as 0.0. Possible change in HARSAT develop: more decimals, or significant figures, for `normal` series.
- **Time trends for auxiliary biological data** (age, length, weight, fat %, etc.): add these to the report once everything else is in place. HARSAT couldn't previously run these statistics. The user has added support for them in the HARSAT develop version (1.0.6.1011).
- **QC of the new year against earlier years** (not essential now; builds on "QC as its own output" under Technical requirements). Today's step 1 QC checks structure (codes, stations, esbase matches), and the visual QC looks at concentrations in the report figures. Neither catches problems in the **uncertainty, LOQ and LOD values**. Working with PFAS showed how much these can vary: after the lab switch in 2020, PFAS LOQs and uncertainties changed a lot from year to year, which makes observations hard to interpret. Idea: for each substance (and lab, species, tissue), compare the new year's concentrations, uncertainties (as U2 / value), LOD and LOQ with the previous ~5 years, and flag values outside the usual range, for example as a table and plots of the yearly distributions. It could be part of step 1 (new year's data plus fmcom) or a separate script in `tools/`. It would also catch issues like the implausible uncertainties found in fmcom (uncertainty larger than the value).
- **Shorten the README:** done 2026-10-26. The README is now a short front page, and the instructions for running the pipeline are in `docs/user-guide.md`.
- **Biological data for birds and mussels:** this year the report only uses the biological (esbase) data for fish. Bird and mussel biological data aren't processed yet. They're included later, when data is reported to the national database.

### Freshwater changes to bring into the shared setup

These are the user's notes on changes made in the freshwater version that marine doesn't have yet:

- The appendix contents table is now created in the HARSAT figures script (`tables_figures.R`). Before, it came from the `functions` code in the report folder. The marine version needs adapting from freshwater.
- File paths have been moved out of the `.Rmd` templates, so they only need to be set once.
- Update the reference library (`.bib`), possibly including all references from the original table, and add references to the text outside the tables.
