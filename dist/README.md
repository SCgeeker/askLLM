# dist/ — built `.jmo` packages

This folder holds the compiled jamovi module package(s) for askLLM, produced by `jmvtools::install()` (which builds the `.jmo` as a side effect of installing).

## Filename format

```
askLLM_<version>_<platform>.jmo
```

Example: `askLLM_1.3.1_win64.jmo` means:

- `askLLM` — module name
- `1.3.1` — module version (from `DESCRIPTION` / `jamovi/0000.yaml`)
- `win64` — target OS and CPU architecture (Windows 64-bit)

The filename used to carry a `jamovi-<series>` tag as well. That came from the 1.0.0 build convention and has been dropped: the module manifest declares only `jms: '1.0'`, the module spec version, and a build made against jamovi 2.7 was verified running on jamovi 28.2.0.0. Tagging a series in the filename told users the file would not work for them when it does.

## Platform binding

A `.jmo` is **not** universal. It is built for one specific combination of:

1. **Operating system** (Windows / macOS / Linux)
2. **CPU architecture** (e.g. x64)

Installing a `.jmo` built for a different OS or architecture than the one you're running will fail or behave unpredictably.

Across jamovi versions the picture is softer. Bundled R and CRAN snapshot versions do differ between jamovi releases, so one build is not guaranteed to work everywhere. What can be reported is what was tested: the 1.3.1 build runs on jamovi 28.2.0.0. If you're on a different platform, rebuild from source (see below) rather than using a file from this folder.

## How to rebuild

From the R console, with this repo as the working directory (or `path` pointed at it):

```r
jmvtools::install(home = "C:/Program Files/jamovi 2.7.37.0")
```

This compiles the module and drops a fresh `.jmo` into this folder, named per the format above.

## How to install a `.jmo`

In jamovi: click the `⊕` icon (top right) → **Side-load** tab → choose the `.jmo` file → wait for installation to finish.
