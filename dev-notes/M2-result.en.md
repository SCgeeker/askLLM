# M2 Full Integration — Acceptance Record

Date: 2026-07-20 | Result: **PASSED** | Module version 1.0.0

## User acceptance in jamovi 2.7.37

| # | Check | Result |
|---|-------|--------|
| E1 | Blank state shows guidance and privacy notice only | ✅ |
| E2 | Question typed but Submit unticked → zero calls | ✅ |
| E3 | Tick Submit → data-specific reply + meta (model · elapsed) | ✅ NIM 2.7s / Gemini 6.5s |
| E4 | Untick and re-tick → cache replay, meta shows `cached`, instructions show "(cache replay, no API call)" | ✅ |
| E5 | Edit the question → exactly one new call | ✅ |
| Waiting | "Waiting for a response from <provider>…" appears immediately on submit | ✅ |

**Evidence of data-aware quality** (Gemini, with Attach data summary ticked): given the attached summary, the LLM correctly identified "the well-known Iris dataset, one 3-level categorical variable (Species) and four continuous numeric variables" and returned **concrete jamovi menu paths** for each suggestion (`Analyses > ANOVA > One-Way ANOVA`, `Analyses > Regression > Correlation Matrix`, `Analyses > Factor > Principal Component Analysis`, …) — exactly the goal of the data-aware Q&A design.

## Defects fixed along the way (in order)

1. **Question box too small, single-line only**: jamovi has no multi-line text control (the schema offers only a single-line TextBox, upstream included). Fixed via the one official extension route — inject an HTML `<textarea>` from view-level `loaded`/`updated` events (the approach Rj uses); the native single-line input is located by a three-strategy finder and hidden. The sentinel strategy runs only while Submit is unticked so it can never trigger a billable call.
2. **Textarea overflowed the panel**: inserting after the Label produced a horizontal layout that overflowed; final version returns it to the original input position with width computed from the actual panel width (260–560px), keeping `resize: both`.
3. **Provider switch did not update the model**: the provider dropdown now has a `change` event that fills in that provider's default model; user-typed values are preserved. **Note**: jamovi-compiler requires the control-level event key to be `change` — `changed` compiles to an empty function (worth reporting upstream).
4. **Gemini default model went stale**: `gemini-2.0-flash` is retired. Inspecting ellmer 0.4.2's `chat_google_gemini()` showed it also hard-codes its default; we instead adopted Google's server-side alias **`gemini-flash-latest`** (verified HTTP 200), which Google resolves to the newest flash model — it can never go stale after release.
5. **Replies truncated mid-sentence**: `max_tokens=1024` was consumed by Gemini 3.x reasoning tokens; raised to 4096.
6. **Keys now read from environment variables**: the jamovi engine sanitizes the process environment, but the canonical Windows environment variable values live in the registry. The lookup chain gained `HKCU\Environment` and `HKLM\...\Session Manager\Environment` steps (via `utils::readRegistry()`), placed ahead of the `.Renviron` files. Verified hitting `registry:system`.

## How the waiting indicator works

`ResultsElement$setStatus('running')` maps to jamovi's internal `ANALYSIS_RUNNING` (the same indicator Bayesian analyses use), combined with `private$.checkpoint()` to serialize and push the current results to the UI immediately — otherwise the display would only update after `.run()` returns entirely. Elements switch to `complete` once the reply arrives.

## Test status

`devtools::test()`: **186 passing / 0 failing / 1 skipped** (the skip is the opt-in live NIM test).
