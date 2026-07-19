# dist/ — built `.jmo` packages

This folder holds the compiled jamovi module package(s) for askLLM, produced by `jmvtools::install()` (which builds the `.jmo` as a side effect of installing).

## Filename format

```
askLLM_<version>_<platform>_jamovi-<series>.jmo
```

Example: `askLLM_1.0.0_win64_jamovi-2.7.jmo` means:

- `askLLM` — module name
- `1.0.0` — module version (from `DESCRIPTION` / `jamovi/0000.yaml`)
- `win64` — target OS and CPU architecture (Windows 64-bit)
- `jamovi-2.7` — target jamovi **series** (major.minor), not jamovi's exact point release

## Platform binding

A `.jmo` is **not** universal. It is built for one specific combination of:

1. **Operating system** (Windows / macOS / Linux)
2. **CPU architecture** (e.g. x64)
3. **jamovi series** (e.g. 2.7.x) — because bundled R and CRAN snapshot versions differ across series

Installing a `.jmo` built for a different OS, architecture, or jamovi series than the one you're running will fail or behave unpredictably. If you're on a different platform, rebuild from source (see below) rather than using a file from this folder.

> Note: the `.jmo` currently checked in here (`askLLM_0.0.0_win64_jamovi-2.7.jmo`) has a stale `0.0.0` version tag left over from an early build (see `dev-notes/M0-result.en.md`), while the module's actual version is `1.0.0`. Rebuild before shipping to get a correctly versioned filename.

## How to rebuild

From the R console, with this repo as the working directory (or `path` pointed at it):

```r
jmvtools::install(home = "C:/Program Files/jamovi 2.7.37.0")
```

This compiles the module and drops a fresh `.jmo` into this folder, named per the format above.

## How to install a `.jmo`

In jamovi: click the `⊕` icon (top right) → **Side-load** tab → choose the `.jmo` file → wait for installation to finish.
