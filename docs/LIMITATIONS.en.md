# Limitations and usage advice

askLLM lets an LLM read a summary of your data and suggest analyses, but **LLMs produce confident-sounding content that is wrong (hallucination)**. This page records the error types observed in testing and the usage advice that follows from them.

**This document's v1.0 baseline testing motivated the v1.1 catalog mechanism; each section now includes a v1.1 mitigation note.**

Original v1.0 test method: `tools/compare-models.R` asked one question each about `iris` and `mtcars`, comparing `openai/gpt-4o-mini`, `openai/gpt-4.1`, `openai/gpt-4.1-mini`, and `microsoft/phi-4` on GitHub Models (2026-07-21). v1.1 validation appears in the v1.1 Mitigation sections below.

## Observed error types

### 1. jamovi menu paths are the most common error (every model tested)

This deserves the most caution: a model can correctly conclude "you should run an ANOVA" and then state the wrong path to it — with exactly the same confident tone. Paths actually produced in testing:

| Path the model wrote | Problem |
|---|---|
| `Analyses > Compare > Independent Samples t-test` | jamovi has no "Compare" menu (t-tests live under **T-Tests**) |
| `Exploration > Correlation` | Correlation Matrix is under **Regression**, not Exploration |
| `Exploration > Principal Component Analysis` | PCA is under the **Factor** menu |
| `Classification > Discriminant Analysis`, `Machine Learning > Classifier` | **No such menus or analyses exist in base jamovi at all** |
| `Compute > Descriptives`, `Visualise > Categorical plots`, `Predict > ANOVA` | Entirely invented menu names |
| `Regression > General Linear Model > Linear Regression` | Invented nesting |

**Advice**: treat the analysis *name* in the answer as a starting point and take the *path* from the actual jamovi interface. In teaching, this is a ready-made demonstration that an LLM's confidence is unrelated to its correctness.

### v1.1 Mitigation (2026-07-23)

**Background**: The path hallucinations recorded in §1.1 were the most dangerous failure mode for statistical beginners in v1.0, and the core benefit challenge jamovi's team raised when considering official library inclusion.

**v1.1 mechanism**: askLLM now scans the user's machine for installed jamovi modules (with their real menu trees) and sends the list of uninstalled modules from the official jamovi library alongside the data summary. The system prompt instructs the model to "cite each menu path exactly as written"; the user prompt demands "quote each menu path EXACTLY as written there."

**Acceptance results** (2026-07-23, `tools/compare-models.R`, 2 questions × 2 models × 2 versions = 8 calls):
- v1.0: 0 mechanically verifiable paths (models did not adopt the `Analyses > ...` format); manual review estimates ~70% semantic correctness, but at least 3 items show structural fabrication (invented submenu, flattened hierarchy, generic rewrite)
- v1.1: **18/18 = 100% zero fabrication** — all 18 extracted paths matched the scanned catalog verbatim

Full data: [`dev-notes/catalog-hit-rate.md`](../dev-notes/catalog-hit-rate.md).

**Caveats**:
- Sample is small (8 calls, 18 paths, 2 models) — not enough to guarantee zero misses globally, but directionally consistent with spec intent
- Disabling the `includeCatalog` option reverts to v1.0 behavior
- In-app guidance ("verify paths against the actual jamovi interface") remains, encouraging user verification

### 2. Statistical suggestions are broadly sensible but need your judgement

The models suggested descriptives, ANOVA, correlation and PCA for iris, and multiple regression for mtcars — all reasonable directions. But they **cannot see your research question**, only the summary statistics, so they:

- do not know whether your data meet the assumptions (normality, independence, homogeneity)
- do not know what the variables actually mean or how they were measured
- may suggest analyses irrelevant to your goal (purely exploratory PCA, for instance)

**Advice**: treat the answer as a list of candidate analyses and filter it with your own research question. Use jamovi's built-in Assumption Checks for assumptions — do not ask the LLM.

### 3. Response times vary enormously

| Model | Measured |
|---|---|
| `openai/gpt-4.1` | 4.7 s |
| `openai/gpt-4.1-mini` | 5.4 s |
| `openai/gpt-4o-mini` | 5.7–10.2 s |
| `microsoft/phi-4` | **314–315 s (over 5 minutes)** |

**Advice**: avoid slow models like `microsoft/phi-4` for live classroom demos. A long wait after submitting usually means a slow model rather than a hang — the waiting message stays on screen throughout.

### 4. The catalog does not always match what inference accepts

`meta/meta-llama-3.1-8b-instruct` appears in the GitHub Models catalog but returns **HTTP 400 `Unknown model`** when called. `meta/llama-3.3-70b-instruct` from the same family works fine.

**Advice**: after switching models, ask one trivial question to confirm it works before relying on it.

## Overall usage advice

1. **Treat askLLM as a starting point for brainstorming, not as a statistical consultant's conclusion.** It is good at turning your data's features into candidate analyses, poor at giving steps you can follow blindly.
2. **Always check menu paths yourself.** This was the most consistent error source in testing.
3. **Keep "Attach data summary" ticked.** Without it the model is guessing outright — in one test it invented "8 samples across Saguaro / Palo Verde / Ironwood" for a dataset containing nothing of the sort.
4. **With beginners, pair it with teacher commentary.** Students struggle to tell a wrong *path* from a wrong *recommendation*.
5. **Cross-check two or more models.** Agreement between models raises confidence in the suggested analysis; paths still need verifying.
6. **Do not use it to replace assumption checks or result interpretation.** jamovi's Assumption Checks and actual output are the authority.

## Suggested use in teaching

These limitations make good teaching material in their own right:

- Have students ask askLLM first, then carry out the analysis in jamovi and discover the path errors themselves — a concrete encounter with hallucination.
- Use `tools/compare-models.R` to compare models and discuss why some answers are thorough and others thin.
- Discuss why summary statistics are enough to *suggest* an analysis but not enough to *draw a conclusion*.

## askLLM's privacy and information architecture advantages (for sensitive data)

### Background: JASP 0.98 vs. askLLM design divergence

JASP 0.98 (released 2026-07-02) introduced "Fully Integrated AI" using an agentic architecture: the LLM directly sees **the complete analysis results and outputs themselves**. askLLM takes a more conservative approach: the LLM sees only **summary statistics of the variables you selected** (counts, means, SDs, factor frequencies) — **never the raw data rows**.

This architectural difference becomes critical when handling **sensitive data** (patient records, business secrets, personal privacy).

### Why agentic design requires caution with sensitive data

JASP's own team noted on their official blog[^jasp-warning]: many free LLMs may use input content to train or improve their models. For sensitive data, this is a serious risk — agentic AI sends complete analysis results (including inferential statistics, effect sizes, detailed per-case analysis) to the LLM, giving it enough information to reconstruct or leak the privacy-critical core of the original data.

askLLM's "summary-only" design works differently:

- **Even when using cloud services**, the LLM sees only summary numbers, insufficient to reconstruct individual observations, reducing the risk of training-data leakage.
- **With Ollama local execution**, you can run **entirely offline**: your LLM and your data both run on your own machine, zero transmission.

### Usage recommendations

1. **First choice for sensitive data**: use the **Ollama (local)** provider. No API key needed, no network dependency, data never leaves your machine.
2. **If you must use cloud services**: askLLM's design naturally lowers risk, but we recommend:
   - First test with non-sensitive data to become familiar with the tool
   - Before deployment, confirm your organization's privacy/data protection policy allows it
   - Consider whether the summary-level analysis is sufficient for your needs (enough to suggest directions, but not enough to leak privacy)
3. **High-stakes scenarios** (e.g., clinical research, trade secrets, regulated personal data): require formal privacy assessment; agentic AI plus cloud services is not recommended.

For more background and detailed comparison, see the main README's "[Privacy by design vs. agentic AI](../README.md#privacy-by-design-vs-agentic-ai)" section.

---

[^jasp-warning]: JASP team. (2026). [Free API Key Hunting](https://jasp-stats.org/2026/07/09/free-api-key-hunting/); JASP Services BV. (2026). [Set up a Fully Integrated AI in JASP, and Run it for Freeeee](https://www.jasp-services.com/set-up-a-fully-integrated-ai-in-jasp-and-run-it-for-freeeee/)
