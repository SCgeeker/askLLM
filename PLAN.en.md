# askLLM — Wrapping ellmer as a jamovi Module: Implementation Plan

## Context

Following the successful Rj pilot (LLM replies rendered inside jamovi), this plan builds the production jamovi module per the approved v1 spec: **data-aware Q&A** — the user selects variables and types a question; the module attaches a variable summary so the LLM answers about *their* data. Preformatted output, single-turn, API keys kept in files (never in the UI/options). This doubles as the pilot case for the parent jmv-agent project ("R package → jamovi module"). Master planning by Fable 5; execution tasks assigned to models by difficulty.

**Key verified constraints**:
- jamovi 2.7.37 bundles R 4.5.0 with CRAN snapshot 2025-05-25 → compilerr installs **ellmer 0.2.0 (no `chat_openai_compatible()`; use `chat_openai(base_url=, api_key=)` for OpenAI-compatible endpoints)**; dev system R is 4.6.1 (ellmer 0.4.2) → a version-adaptive layer is required
- Extra deps to bundle are light: coro/httr2/later/promises/S7 + ellmer (curl/openssl already in snapshot)
- jamovi-spawned R inherits no env vars; HOME=%USERPROFILE% (measured in Rj pilot) → 4-step key lookup chain
- `install(home='C:/Program Files/jamovi 2.7.37.0')` is mandatory on Windows
- The `Action` option type is half-baked (enum only "open") → cannot serve as a submit button; debounce uses a three-layer design
- Skip `.u.yaml` (uicompiler auto-generates a usable UI); never use `Rscript -e` with escaped `\$` (segfaults) — run .R files instead

## Module Structure

Location: `D:\core\LAB\Analysis\jmv_modules\askLLM\` (standalone git repo). Module name `askLLM`.

Files: `DESCRIPTION` (Imports: jmvcore, R6, ellmer); `jamovi/askllm.a.yaml` + `askllm.r.yaml` (no .u.yaml); `R/askllm.b.R` (thin R6 body ~150 lines, debounce state machine); pure-function files `R/llm-adapter.R`, `R/llm-providers.R`, `R/key-loader.R`, `R/data-summary.R`; `tests/testthat/` (pure functions only, run on system R); `docs/SETUP-*.md` (bilingual pairs).

**a.yaml options**: data; vars (Variables); question (String); includeSummary (Bool, true); **submit (Bool, false — hard debounce gate)**; provider (List: nim/gemini/github/ollama/custom, default nim); model (String, default meta/llama-3.1-8b-instruct); baseUrl (String, custom only); maxLevels (Integer, 10).

**r.yaml items** (all `clearWith: []`): instructions (guidance/errors/key setup text), answer (LLM response), meta (model · elapsed · cached flag).

**.b.R**: `.init()` renders guidance only (3-step tutorial + privacy notice), zero network. `.run()` = gate (!submit || empty question → guidance) → build payload → **state-cache compare (`identical()` → replay, zero API calls)** → key load (failure → setup text, never throw) → `ask_llm()` (tryCatch) → setContent + setState.

## Four Pure-Function Files

1. **llm-adapter.R**: `make_chat(base_url, model, api_key, system_prompt, ctor=NULL)` — ellmer >= 0.4.0 uses `chat_openai_compatible`, else `chat_openai` (0.2.0; **must pass model explicitly** — its default is gpt-4o); `ctor` injection point for test doubles. `ask_llm(...)` returns a structured list (ok/text/model/elapsed/error), never stops.
2. **llm-providers.R**: `provider_spec(name, base_url_option)` → `list(base_url, env_vars, needs_key, default_model, setup_doc)`. **All providers use OpenAI-compatible endpoints** (gemini via `/v1beta/openai/`, github via `models.github.ai/inference`, ollama `localhost:11434/v1` keyless, custom reads the baseUrl option).
3. **key-loader.R**: `load_api_key(env_vars)` 4-step chain — Sys.getenv → readRenviron(%USERPROFILE%\.Renviron) → readRenviron(%USERPROFILE%/OneDrive/文件/.Renviron, path built dynamically) → readRenviron(~/.Renviron); returns `list(key, source)` or NULL. `key_setup_text(provider)` returns setup instructions (signup URL, both candidate .Renviron paths, format example, restart reminder).
4. **data-summary.R** (opus-grade): `summarize_data(df, vars, max_levels=10, char_budget=4000)` — numeric: n/missing/mean/sd/median/min/max (signif 4); factors: level count + top-N level frequencies ("... and K more"), level names capped at 40 chars; edge cases: all-NA, zero variance, single observation, NA levels; per-variable truncation with markers when over budget. Prompt template wraps the summary in `<summary>` tags + "Answer about THIS dataset. Be concise."

## Debounce (three layers against reactive re-runs / duplicate billing)

1. **submit Bool hard gate**: unchecked → guidance only; users uncheck before editing the question (tutorial says so)
2. **payload state cache**: payload = question+summary+provider+model+baseUrl string; `identical()` with `answer$state$payload` → replay; at most one API call per substantive change
3. **`clearWith: []`**: state survives option changes; `.run()` overwrites the display every run

M2 must measure whether the String TextBox commits on Enter/blur or per keystroke (even per-keystroke is safe behind the hard gate). Residual risk: state persistence across .omv save/reopen untested; worst case = one extra API call, acceptable.

## Testing

- **A. Pure-function testthat** (system R 4.6.1, TDD RED→GREEN): data-summary (types/missing/truncation/edge), providers (full table), key-loader (each chain step + total failure + setup-text keywords), adapter (ctor-injected fakes, argument passing, 401/timeout translation)
- **B. Live test** (opt-in): `skip_if(ASKLLM_LIVE_TESTS != '1')`; single PONG round-trip against NIM
- **C. 0.2.0 path**: covered by M0 smoke + E2E inside jamovi (bundled R can't run testthat)
- **D. Manual E2E script** (below)

## Milestones

| Milestone | Content | Acceptance |
|---|---|---|
| **M0 minimal network smoke (first)** | create+addAnalysis skeleton; hard-coded .b.R: key chain + `chat_openai(base_url=NIM)` one round-trip; prepare+install | compilerr installs ellmer 0.2.0 (log duration); NIM reply appears in jamovi Results (proves engine HTTPS + 0.2.0 works); log engine-side ellmer version and HOME |
| M0 fallback branch | In order: `Remotes: tidyverse/ellmer` → raw httr2 chat/completions (httr2 is in snapshot base) | Decision locked before M1 |
| M1 pure-function layer | Four files, TDD | devtools::test() green; live PONG passes |
| M2 full integration | Production yaml + .b.R + debounce; reinstall | E1–E7 pass; measure String trigger behavior |
| M3 multi-provider + docs | gemini/github/ollama/custom tested; SETUP docs ×4 (bilingual) | Each provider succeeds or fails friendly |
| M4 release readiness | README (en + zh-TW), privacy notice, optional .u.yaml, .jmo | Clean-machine sideload works; checklist complete |

## Task Assignment (models by difficulty; subagents never commit — main loop commits per wave)

| Wave | Task | Agent/Model | Depends |
|---|---|---|---|
| W1-1 | Skeleton create/addAnalysis/git init/DESCRIPTION | sonnet | — |
| W1-2 | M0 smoke .b.R (hard-coded) | sonnet | W1-1 |
| W1-3 | M0 install + visual acceptance in jamovi | **main loop** | W1-2 |
| W2-1 | key-loader + providers TDD | sonnet | M0 |
| W2-2 | llm-adapter TDD (version fork + error translation) | **opus** | M0 decision |
| W2-3 | data-summary + prompt template TDD | **opus** | — |
| W3-1 | Production a.yaml/r.yaml | haiku/sonnet | W2 all |
| W3-2 | .b.R integration + debounce state machine | **opus** | W3-1 |
| W3-3 | Manual E2E acceptance | **main loop** | W3-2 |
| W4-1 | Provider verification | sonnet + main loop | W3-3 |
| W4-2 | SETUP ×4 + README + privacy notice (bilingual pairs) | sonnet | W4-1 |
| W4-3 | Release checks + .jmo | main loop | W4-2 |

## Risks (selected)

- ellmer 0.2.0 on R 4.5.0 untested → M0 first; fallbacks ordered (Remotes → raw httr2)
- Engine HTTPS untested → M0 first
- Privacy: summary leaves the machine → guidance + README disclosure; aggregate stats only, no raw rows; ollama as zero-egress option
- Long replies → max_tokens via api_args + display cap
- Keys never in .omv: keys live only in process env vars, never in options (E9 greps the file)

## E2E Verification (inside jamovi)

E1 blank → guidance + privacy notice only; E2 question w/o Submit → zero calls; E3 Submit → data-specific reply + meta within seconds; E4 unrelated option change / re-check → cache replay (meta shows cached; NIM usage page shows no new call); E5 edit question → exactly one new call; E6 broken key → friendly bilingual setup text, not a red R error; E7 offline → friendly connectivity error; E8 (M3) each provider; E9 save .omv and reopen → reply persists and no key string greps out of the file.

## Documentation Language Convention (effective from this plan)

**All plans and logs are saved in Chinese and English as separate files**: every plan / dev log / milestone report in the repo is produced as an equivalent pair — `<name>.zh-TW.md` and `<name>.en.md`. Applies to: this plan when saved into the askLLM repo (`PLAN.zh-TW.md` / `PLAN.en.md`), per-wave acceptance logs (`dev-notes/`), the M0 decision record, README (English `README.md` + `README.zh-TW.md`), and SETUP guides. Git commit messages remain in English (existing convention).

Reference files: `jmv_mcp/pilot/rj-ellmer-smoke.R` (verified key chain and NIM call), `jmv_mcp/inst/node_modules/jamovi-compiler/schemas/optionschemas.yaml` (authoritative option-type schema).
