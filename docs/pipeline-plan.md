# Pipeline design: decisions and open questions

Background, design decisions and open questions for the pipeline. For how to run it, see the [user guide](user-guide.md).

## Background

We produce yearly reports on the Swedish National Monitoring Programmes for Contaminants in Marine and Freshwater Biota: *"Graphic and statistical overview of temporal trends and spatial variations in the Swedish National Monitoring Programme for Contaminants in Marine Biota (including data through 2025)"*, and the corresponding freshwater report.

Working on the report is also how we inspect and QC the new year's data and decide whether to contact the laboratories. QC is a core purpose of the pipeline, not a side effect.

All code is in R.

## Previous setup (replaced in 2026)

Until the 2025 marine and 2024 freshwater reports, each programme and year had its own folder (e.g. `MCOM2025`, `FCOM2025`), made by copying the previous year's folder and modifying the scripts. Each folder had three subfolders with their own R projects:

1. **raw_data**: read the year's raw lab files and arranged them to match the fmcom format.
2. **HARSAT**: temporarily attached the new year's data to fmcom, ran HARSAT, and produced statistics tables and figures.
3. **report**: built the report with an R Markdown script.

The MCOM2025 and FCOM2026 scripts were kept in the repository as a baseline while the pipeline was built, and removed once it reproduced their results; they remain in the git history.

## Decisions

- **One repository and one top-level R project** for both programmes. No yearly copies of the code. The programme (`marine`/`freshwater`) and year are parameters, set in `config/<programme>.yml`.
- **Years are handled with git tags**, not folders. The commit used for each published report is tagged (e.g. `marine-2025`), so it can be reproduced exactly.
- **Year always means the last year of data included.** For example, `marine-2025` and `output/marine_2025/` mean data through 2025. This applies to the config, output folders and tags. The old folder names were inconsistent: `MCOM25` and `FCOM26` both contained data through 2024.
- **Development happens locally; the report is run from a clone on the museum's shared drive**, with the data folder set in `.Renviron` (`FMCOM_DATA_DIR`).
- **The yearly publication is the appendix-style PDF** ("Graphic and statistical overview ..."), built by `03_report/generate_appendix.R`. The old `generate_report_stuff.R` (main-report figures) was obsolete and has been removed.

## Structure

```
<repo>/
├── fmcom-annual-report.Rproj
├── run.R                         # entry point: runs the steps in order, with the QC checkpoints
├── config/
│   ├── marine.yml, freshwater.yml   # year, lab files, esbase file, HARSAT groups, report settings
│   ├── method_rules.csv          # corrections of reported analytical methods (e.g. egg extraction)
│   ├── lookups/                  # names and order used in the report (determinands, species)
│   ├── harsat/                   # HARSAT information files (determinand, species, thresholds),
│   │                             #   stations per programme, sums, automatic convergence fixes
│   ├── report/                   # threshold tables shown in the report
│   └── submission/               # SGU's blank template; log of submissions per programme
├── R/                            # shared functions (config, step 1, QC, HARSAT, figures, report)
├── 01_raw_data/
│   └── prepare_new_year.R        # lab files + esbase -> new year's data in fmcom format, QC
├── 02_harsat/
│   ├── prepare_harsat_input.R    # fmcom + new year -> one HARSAT input file per group
│   ├── run_harsat.R              # one HARSAT run per group, automatic convergence fixes
│   ├── tables_figures.R          # time series plots, maps, summary tables, appendix contents
│   └── run_step2_job.R           # steps 2a-2c as an RStudio background job
├── 03_report/
│   ├── generate_appendix.R       # writes the appendix .Rmd from templates and renders it to PDF
│   ├── rmd/                      # header and section templates
│   ├── text/                     # year-specific report text per programme
│   ├── preamble-latex.tex
│   └── references.bib
├── 04_submission/
│   └── prepare_submission.R      # lab files + esbase -> SGU's template, filled; QC; changes since last version
├── tools/                        # occasional upkeep of the HARSAT information files
├── docs/                         # user guide, this document
├── data/     (gitignored)        # lab files, esbase extracts
├── dev/      (gitignored)        # scripts in development
└── output/   (gitignored)        # everything produced, e.g. output/marine_2025/
```

### The yearly cycle and the National Contaminants database

The data is reported to the [National Contaminants database](https://www.sgu.se/produkter-och-tjanster/datavardskapen-grundvatten-och-miljogifter/rapporterad-data-till-datavardskap-for-miljogifter/) (Datavärdskap för miljögifter), hosted at the Geological Survey of Sweden (SGU). The database is only available in Swedish, which makes it hard to use for researchers who don't read Swedish. Codes and names from the database keep "SGU" in their names in fmcom and MoCiS2 (e.g. `station_code_SGU`, `contaminant_code_SGU`, `contaminants_SGU_NRM.csv`).

The cycle is:

1. **Before the report:** last year's data, downloaded from the national database after its QC, is added to fmcom (in the fmcom repo).
2. **The report (steps 1–3):** the new year's data is read from the lab files, QC'd, temporarily attached to fmcom, and run through HARSAT, tables, figures and the report.
3. **After the report (step 4):** the QC'd new-year data is converted to SGU's template and submitted to the national database, which adds another QC layer.
4. **Next year:** that data is downloaded from the national database and added to fmcom, and the cycle starts again.

The pipeline is not one continuous run. There are **three QC checkpoints**, and `run.R` makes them explicit:

1. **After step 1 (new year's data):** review `qc_step1.csv` (scripted checks, see below), contact labs, and correct before continuing to step 2.
2. **After step 3 (the finished report):** look through the report for oddities and contact labs where needed. After correcting, re-run all three steps.
3. **During step 4 (the submission):** errors that slipped through are often found here. Corrections go into the lab files (new file versions, listed in the config), so a re-run of the report also gets them.

The visual review of the report is still the main check of the concentrations themselves. A screening of the new year's values against earlier years is being developed (see Open questions and later additions).

## Principles for handling yearly changes

1. **Parameters** (year, lab files, stations, species, etc.) go in config files, not scripts.
2. **Method improvements** (new QC check, better plot) are committed to main and apply to future years. Old years remain available through their tags.
3. **One-off data fixes** for a specific year (e.g. a wrong value from a lab batch) should go in a `config/corrections/` CSV that the pipeline applies, not in `if (year == 2025)` code. *Not built yet*: so far, errors have been corrected in the lab files and reported for correction in the national database.
4. **Report narrative** is year-specific and lives in `03_report/text/<programme>.Rmd`, edited each year; the shared text and tables come from the templates in `03_report/rmd/`.

## Technical choices

- **Paths:** `here::here()` everywhere; no absolute paths in scripts. The data folder is set by `FMCOM_DATA_DIR` in `.Renviron` (default `data/` in the project). Paths written into the report `.Rmd` use forward slashes, and the bibliography and LaTeX preamble are copied next to it, so step 3 also works from a network drive.
- **HARSAT:** the develop version (1.0.6.1011, commit `6ebfd51`). If `HARSAT_DEV_PATH` is set in `.Renviron`, the pipeline loads that local checkout with `pkgload::load_all()`; otherwise it uses a copy already loaded in the session, or the installed package. Each run records the HARSAT version, commit and path in its output folder. For a published report, the HARSAT commit used must exist on GitHub.
- **R Markdown** for the report, not Quarto (decided 2026-10-13). The appendix is generated from templates (`knit_expand`); moving that to Quarto isn't worth the effort for now. Programme and year come from the config, and output paths are set once (via `options()`), not in each template.
- **Substance groups are looped over**, listed in the config, with one HARSAT run per group, plus a separate run (`bio`) for the biological variables.
- **fmcom replaces mcomDb** everywhere, including the scripts in `tools/`.
- **Master tables from fmcom:** contaminant and station tables are read from the fmcom GitHub repo (`data-raw/master_tables/`) at the commit of the installed fmcom package (or `master` if fmcom wasn't installed from GitHub), so they update with the data. The HARSAT stations files stay local config files, because HARSAT needs extra columns and the spring stations.
- **Data access in one place:** `load_fmcom()` and `load_fmcom_with_new_year()`. The contaminant data is moving to Specify, so the data source will change later. Each run records the fmcom version used.
- **The new year's data is flagged** (`source = "new_year"`) when attached to fmcom; fmcom rows from the report year or later are dropped first, so a year is never counted twice.
- **`.gitignore`** excludes `data/`, `output/`, `dev/`, `.Renviron` and `renv/library/`. No raw lab data in the repository.
- **renv** to pin package versions (fmcom, MoCiS2, HARSAT) is planned, after the first runs from the shared-drive clone.
- Optional later: `targets` to cache the slow HARSAT run.

## Reproducing a published report

**Goal:** years later, someone should be able to rebuild a published report, e.g. `marine-2025`, with the same numbers, tables and figures.

A report is built from three things, and only one of them is in this repository:

1. **The code**, marked by the git tag (e.g. `marine-2025`).
2. **The historical data (fmcom)**, from the public fmcom package (github.com/NRM-MOC/fmcom; version 0.3.0 = data through 2024). Each run records the fmcom version and commit; renv will pin it.
3. **The new year's data**, from the lab files, which are not in the repository and not public. It is the data *before* it goes through the national database, whose QC may change values, so the version that later ends up in fmcom can differ from what the report used.

So step 1 saves the processed new-year data as `output/<programme>_<year>/new_year_data.rds`, and the output folder is kept on the shared drive with the report: at least the PDF, `new_year_data.rds`, `harsat/assessments/` (the fitted models) and the `run_info` files. Together with the tag, that defines the report. GitHub keeps the code; the shared drive keeps the results.

**Still to decide:**

- Whether to record a checksum of `new_year_data.rds` in the run output, to verify it's the same file.
- Whether fmcom should get git tags or releases per data update (e.g. `v0.3.0`), so it's easier to see which data version a report used than from a bare commit ID.
- Whether to make input data available, e.g. in a public data repository for the report years, if the data can be published.

**Note on fmcom formats:** the local `.rds` copy of fmcom and the package's `.rda` differ slightly in some column formats but are otherwise kept in sync. Before each report, the package is updated with the previous year's data and any bug fixes, so the package (via GitHub) is the source used for the report.

## How the pipeline was built

1. The MCOM2025 scripts were committed unchanged as a baseline, so the history shows every change.
2. They were restructured into the layout above, with years and paths replaced by config values and `here()`.
3. Marine 2025 was run through the new pipeline and checked against the old scripts: step 1 values, HARSAT input and summary tables were identical where both produced them.
4. Freshwater was added via `freshwater.yml` and tested with the 2024 data. Programme differences are config settings (report sections, winter samples, excluded species, station order), not separate code.

### Station names and season in the new year's data

- **The fmcom convention applies:** a plain station name (e.g. "Ängskärsklubb") and season in a separate column. The lab files follow this convention, through the drop-down list in the lab spreadsheets. The old MoCiS convention ("Ängskärsklubb höst/vår") is being phased out. MoCiS2's code list and station check were updated for this.
- **Season comes from the sampling date** (esbase catch date, joined by specimen ID), using the same rule as fmcom's `data-raw/adding_next_year_fmcom.R`:
  - January–February: Winter
  - March–June and July 1–15: Spring
  - July 16–December: Autumn

  The day is compared as a number, because fmcom's text comparison leaves July 1–9 without a season (reported as an fmcom issue).
- **Winter samples** are excluded in marine (`exclude_winter: true`), because winter conditions affect contaminant concentrations, and kept in freshwater. Either way they are listed in the QC output (often it will be a wrong date), not dropped silently.

### Step 1: how the new year's data is built

Step 1 mirrors fmcom's `data-raw/adding_next_year_fmcom.R`, which converts the national database download into fmcom rows. Step 1 starts from the lab files read with MoCiS2 instead, i.e. the same data before it goes to the national database. That way the temporary new-year dataset looks the way the data will look in fmcom next year. Differences from the fmcom script are marked "Differs from fmcom" in `R/raw_data.R`.

- **Lab files** are listed in `config/<programme>.yml`, because their names change every year. Step 1 warns about `.xlsm` files in the folder that aren't listed, and ignores Excel lock files (`~$`).
- **Stations and contaminants** are joined to the fmcom master tables on the national database codes (`PROVPLATS_ID` = `station_code_SGU`, `UNIK_PARAMETERKOD` = `contaminant_code_SGU`), not on names. Extra spaces in the master tables are stripped on reading.
- **esbase extracts** have had different column names over the years; step 1 looks for each field under the names seen so far, translates Swedish species names to Latin, and stops with a clear message if a column or the file is missing.
- **CB-118U** (CB118 from the Umeå lab) is kept as CB118 with laboratory UMU, as fmcom has it. From 2025, CLC is no longer measured, so it's the only CB118 source, and HARSAT's TEQ sums need it.
- **Isotopes** are included whenever an SI file is listed (read with `negative_for_nondetect: false`).
- **Censoring:** `LOQ_LOD` and `is_censored` come from MoCiS2's flags: `b` → `<LOD`, `q` → `<LOQ`, `q` + `Ja` → `>LOD, <LOQ`. This differs from fmcom, whose national database download seems to lose `Ja` (reported as an fmcom issue).
- **Uncertainty** is MoCiS2's `MATOSAKERHET`: the labs' expanded uncertainty (U2, k = 2) in the unit of the value.
- **Method rules** (`config/method_rules.csv`): egg content needs a different extraction method than the one the lab reports for all tissues. The rules are BFR `SLV_m064_f3` → `f4` and CLC `SLV_m063_f3` → `f2`. They match on the reported method, so fat % rows are never changed.
- **As in fmcom:** bismuth (`Bi`) is kept; PFAS in muscle is removed (only liver is used); pooled samples get sex "Mixed"; eggs get age 0; fat % and dry weight % are attached per lab sample (`sample_ID`); the metals file's `TPRC` is dropped.
- **Samples without esbase data** (no date) get their year from the config and are listed in the QC output.
- **Identical rows from a lab file** are removed and counted in the QC output (in 2025, the PFAS file listed FHXSA twice in its accreditation list, which made MoCiS2 repeat every FHXSA row).
- **QC (`qc_step1.csv`)** has 22 scripted checks, among them: unlisted lab files, MoCiS2 warnings, codes and stations not in the master tables, missing biological data (date, weight, age, sex), and whether each lab station matches one esbase location, which catches wrong specimen IDs in a lab file.
- **The lab files' "general info":** MoCiS2 takes the lab, executing lab, preparation, method and instrument for all rows of a file from the drop-down column of the "general info" sheet. The column to the right is for comments, e.g. when the right value is not in the drop-down list (in 2025, the new isotope lab Agroisolab was only in the comment). Steps 1 and 4 list every field with a comment that differs from the value, so it is seen without anyone having to remember it. The correction belongs in the lab file, not in the pipeline.

### Step 4: the submission to the national database

Until 2025, the submission was a separate script in its own folder, which read the same lab files again; its three output sheets were copied into SGU's template by hand. It is now step 4 of this pipeline (decided 2026-10-28), because it builds on exactly the same data as the report: corrections found in either the report QC or the submission QC then reach both.

- **Same data as step 1:** the lab files under `raw_data:`, the method rules, and the esbase reader. Only the esbase extract can differ (`submission: esbase_file:`), because a later extract often has the mussel and bird data that wasn't available for the report. The report keeps the extract it was made from, so it stays reproducible.
- **MoCiS2 does the conversion** (`moc_join_SGU()`, `moc_write_SGU()`), as before; step 4 writes the result into SGU's blank template (`config/submission/`), from row 6 and column B, keeping SGU's layout. BESTALLARE comes from the config, with the report title as RAPPORTNAMN. The template is replaced when SGU publishes a new version; its version is recorded in `run_info_step4.yml`.
- **Versions are set by hand** (`submission: version:`). Re-runs during the submission QC replace the version's files, and don't count as new versions. Once SGU's receipt (`.msg`) is saved in the version folder, the version is locked, and a resubmission needs a higher version.
- **Submitted files go to the existing SGU folder** (`FMCOM_SUBMISSION_DIR`, following its layout: `Marina/Marina 2025/v<n>/`), not in git, since they contain unpublished data, and not in the data folder, since they are output rather than raw data. Each version folder holds the uploaded file, the receipt, the QC, the run info, and the changes since the last submitted version.
- **The log** (`config/submission/submissions_<programme>.csv`) is in git, filled in by hand after each upload: year, version, date, Leverans-ID, type and a comment. It holds no measurements. Step 4 checks that every version with a receipt is in the log.

## Open questions and later additions

- **Measurement uncertainty** (reviewed 2026-10-23; to discuss with the statistician):
  - *What the number is.* fmcom's `uncertainty` is the labs' expanded uncertainty U2 (k = 2) in the unit of the value. MoCiS2 submits it to the national database as `MATOSAKERHET` with `MATOSAKERHET_TYP = "U2"` and a unit, but fmcom keeps only the number, so the type isn't documented in fmcom itself. Worth raising in fmcom: keep the type and unit, or document them.
  - *Fixed:* step 2a passed U2 to HARSAT as a percentage labelled `%`, which HARSAT reads as a relative SD, so reported uncertainties entered twice too large (variance × 4). The old MCOM25 scripts did the same. Step 2a now passes the absolute value labelled `U2`, and HARSAT halves it. Both reports were re-run with the fix.
  - *Waiting for review:* the generic `biota_sd_constant`/`biota_sd_variable` in `config/harsat/determinand.csv`, used for the ~75 % of values without a reported uncertainty. The current `sd_variable` is the mean relative U2 (about twice too large as an SD), and the current `sd_constant` is on the wrong unit and basis (often orders of magnitude too large). `tools/generic_uncertainty.R` re-estimates both the way HARSAT's own `ctsm_uncrt_estimate()` does, from marine and freshwater data together, and writes a comparison to `output/tools/` without changing `determinand.csv`.
  - *SLU's PFAS uncertainty* is a fixed 25 % of the value (30 % for PFOS) in every year, not a measured uncertainty per sample, and the 2020 file describes it as an RSD.
  - *Data follow-up:* about 4,000 values in fmcom have an uncertainty larger than the value (mostly SFA PCBs and pesticides 2022–2023, SU 2012–2019), probably percentages or wrong units in the submitted data. Listed in `output/tools/implausible_uncertainties.csv`.
  - *Biological variables:* hand-set first approximations (2026-10-22), halved where they come from U2: dry weight % from the labs' 4 % (U2), lipid weight % from the BFR lab's 25 % (U2; the dioxin lab reports 100 %, probably a placeholder), and measurement precision for age, length and weight.
  - *After the decision:* re-run both reports (freshwater about 2.5 h, marine about 4.5 h) and compare with the current results.
- **Years HARSAT leaves out of the trend fit:** besides years before a six-year gap and early years mostly below LOQ, HARSAT silently drops early years when the first model hits a parameter bound (25 freshwater and 15 marine series). This isn't reported as non-convergence, so the pipeline can't fix it. Raised with the statistician, who maintains HARSAT. The figures show all years, with those left out of the fit in grey.
- **Rounding of trends for normal-distribution series (HARSAT):** HARSAT rounds `overall_change`, `recent_change` and `dtrend` to one decimal. That suits % per year for contaminants, but for the biological variables modelled as normal (trends in their own unit per year), small changes, e.g. in fat %, show as 0.0. To be fixed in HARSAT.
- **Biological variables:** age, length, weight, fat % and dry weight % are assessed in their own HARSAT run (`bio`) and included in the report. Weight is log-normal; the others are normal. Bird and mussel biological data aren't processed yet; they're included later, when the data is reported to the national database.
- **Average dry weight and lipid % in `config/harsat/species.csv`** updated from fmcom on 2026-10-23 with `tools/biological_averages.R` (marine and freshwater together). This corrected three old entries: cod liver lipid (10.03 → 36.6), eelpout lipid (measured in muscle, was in the liver column) and Arctic char dry weight (muscle and liver were swapped). Perch liver lipid (0.73) is kept: fmcom has no perch liver fat values, and its source is unknown. Re-run the tool every few years as data accumulates.
- **QC of the new year against earlier years:** today's step 1 QC checks structure, and the visual QC looks at concentrations in the report figures; neither catches problems in the uncertainty, LOQ and LOD values. A screening script is in development (`dev/screen_new_year.R`): for each series it compares the new year's level with the trend of the previous 10 years, and checks changes in the share below LOQ, the LOQ/LOD levels, the relative uncertainty, fat and dry weight %, and series that are missing. It may become part of the QC after step 1.
- **PFAS (SLU, from 2020):** the lab files show one fixed LOD and LOQ per substance and year, varying by factors of 10–100 between years, with the largest problems in 2020–2022 (instrument problems and staff changes at the lab). Several PFAS that SU detected until 2019 are mostly below the limit since 2020, even when the LOQ is below the earlier typical concentrations. To decide: how to treat 2020–2022 in deeper analyses of the PFAS time series.
- **Data errors reported for correction in the national database:** the Gipsjön perch pool ID in the SU 2024 freshwater files, and linear PFOS reported as <0.006 in two Fladen herring liver samples (2022).
- **Step 4, to settle at the first real submission (January 2027):**
  - *Executing lab for dry weight in the SI file.* The template has one executing lab per file, so dry weight (TPRCI, MTPRCI), weighed at ACES, gets the isotope lab. The old marine script set it to `EJ_REL` by hand; the old freshwater script didn't, so the freshwater 2024 data at SGU has UC Davis for dry weight. Probably needs a fixed rule in step 4, decided once the rest of the SI file is updated.
  - *The SI file's general info for 2025:* SGU lab code for Agroisolab (new lab, code not yet requested), and the analysis method, which still says `UCD_SIA`.
  - *Test the whole step:* upload, receipt, log row, and a resubmission with the changes file.
- **Open follow-ups from the 2025 run:**
  - Biological data is missing for 2 Kinnbäcksfjärden herring pools (`B2026/...`).
  - Mussels and guillemot eggs have no catch dates in the esbase extract.
  - The Umeå instrument code changed (`GC-MS-MS-QQQ` in 2024, `GC-MS-MS` in 2025). It needs checking with the lab, and fmcom's method master table needs adjusting.
  - A possible MoCiS2 fix: `distinct()` in `read_lab_file_ackr()`.
