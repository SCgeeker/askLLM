# GitHub Models: models available for free

With just a **GitHub account** (Copilot Free is enough — no credit card), once your token is configured (see [SETUP-github.en.md](SETUP-github.en.md)) any of the models below can be typed straight into askLLM's **Model** field.

This page reflects the GitHub Models catalog API (`https://models.github.ai/catalog/models`) as queried on **2026-07-21**: 37 models, of which 2 are embedding models that askLLM does not use and are omitted here. The list changes as GitHub updates it — see <https://github.com/marketplace/models> for the current set.

## Free-tier limits (Copilot Free)

Limits depend on the model's **tier**, not its size:

| Tier | Requests/min | Requests/day | Tokens per request | Concurrent |
|---|---|---|---|---|
| **low** | 15 | 150 | 8000 in / 4000 out | 5 |
| **high** | 10 | 50 | 8000 in / 4000 out | 2 |
| **custom** | varies; usually unavailable or tightly capped on the free plan | | | |

> Official limits: <https://docs.github.com/en/github-models/use-github-models/prototyping-with-ai-models>
>
> ⚠️ The **8000-token input cap** matters in practice: with many variables selected, or a large `Max factor levels shown`, the data summary can exceed it. If you hit a usage error, reduce the number of selected variables first.

## low tier — most generous quota, **recommended for teaching and everyday use**

| Model ID | Publisher | Notes |
|---|---|---|
| `openai/gpt-4o-mini` | OpenAI | **askLLM default**; good speed/quality balance |
| `openai/gpt-4.1-mini` | OpenAI | Newer generation, better instruction following |
| `openai/gpt-4.1-nano` | OpenAI | Lightest and fastest |
| `mistral-ai/mistral-medium-2505` | Mistral AI | Mid-size general purpose |
| `mistral-ai/mistral-small-2503` | Mistral AI | Small general purpose |
| `mistral-ai/ministral-3b` | Mistral AI | Very small, speed first |
| `mistral-ai/codestral-2501` | Mistral AI | Code-oriented |
| `cohere/cohere-command-a` | Cohere | General purpose |
| `meta/meta-llama-3.1-8b-instruct` | Meta | Lightweight open model |
| `meta/llama-3.2-11b-vision-instruct` | Meta | Accepts image input |
| `microsoft/phi-4` | Microsoft | Small but strong at reasoning |
| `microsoft/phi-4-mini-instruct` | Microsoft | Lighter still |
| `microsoft/phi-4-mini-reasoning` | Microsoft | Reasoning-oriented |
| `microsoft/phi-4-reasoning` | Microsoft | Reasoning-oriented |
| `microsoft/phi-4-multimodal-instruct` | Microsoft | Multimodal |

## high tier — more capable, but only 50 calls per day

| Model ID | Publisher | Notes |
|---|---|---|
| `openai/gpt-4.1` | OpenAI | Long context (million-token input), strong all-round |
| `openai/gpt-4o` | OpenAI | General-purpose flagship |
| `meta/llama-3.3-70b-instruct` | Meta | Large open model |
| `meta/meta-llama-3.1-405b-instruct` | Meta | Very large open model |
| `meta/llama-4-scout-17b-16e-instruct` | Meta | Llama 4 family |
| `meta/llama-4-maverick-17b-128e-instruct-fp8` | Meta | Llama 4 family |
| `meta/llama-3.2-90b-vision-instruct` | Meta | Large vision model |
| `deepseek/deepseek-v3-0324` | DeepSeek | Large general purpose |

## custom tier — advanced/reasoning models, mostly closed to free accounts

`openai/gpt-5`, `openai/gpt-5-chat`, `openai/gpt-5-mini`, `openai/gpt-5-nano`, `openai/o1`, `openai/o1-mini`, `openai/o1-preview`, `openai/o3`, `openai/o3-mini`, `openai/o4-mini`, `deepseek/deepseek-r1`, `deepseek/deepseek-r1-0528`

> Even though these appear in the catalog, a free account calling them may still get a 403 (no access) or exhaust its quota almost immediately. askLLM reports a friendly message either way.

## Comparing models with askLLM

The repo ships a comparison script that puts the same dataset and question through several models in a row and writes a side-by-side report, so you can judge **accuracy and completeness**:

```r
# In an R console (askLLM installed, token configured)
source('tools/compare-models.R')
compare_models(
    models = c('openai/gpt-4o-mini', 'openai/gpt-4.1-mini',
               'microsoft/phi-4', 'meta/meta-llama-3.1-8b-instruct'),
    provider = 'github')
```

See the header of [`tools/compare-models.R`](../tools/compare-models.R) for details.

## Choosing a model for askLLM's task

askLLM asks the model to read a data summary and suggest statistical analyses, which rewards **good instruction following** and, for many users, **solid Chinese output**:

- **Teaching demos and student use**: start with low-tier `openai/gpt-4o-mini` or `openai/gpt-4.1-mini` — the quota comfortably covers a whole class of experimentation.
- **Most complete answers**: switch to high-tier `openai/gpt-4.1`, keeping the 50-per-day limit in mind.
- **Comparing open models**: `meta/llama-3.3-70b-instruct` (high) versus `microsoft/phi-4` (low) makes an interesting pair.
- Differences in **non-English output quality** are most visible on the smaller models — compare them yourself before recommending one to students.
