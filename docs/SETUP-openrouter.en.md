# Setting up your OpenRouter API key

## What is this

OpenRouter is a unified cloud LLM gateway: one account and one key let you call models from dozens of vendors (OpenAI, Anthropic, Meta, Google, DeepSeek, and more). Many of them offer a **`:free`** tier, with **no credit card required** to get a key. Calls go through the cloud API, so your question and data summary are sent to OpenRouter and the upstream model provider's servers.

## Get a key

1. Go to <https://openrouter.ai/keys> and sign up or log in (Google, GitHub, or email).
2. Click "Create Key" and name it (e.g. `askLLM`).
3. Copy the generated key (starts with `sk-or-v1-`).

## The `:free` suffix rule (important)

Many models on OpenRouter exist in both a paid and a free version. **The free version requires a `:free` suffix on the model name**, e.g.:

```
openai/gpt-oss-20b:free
```

If you drop `:free`, the same model name routes to the paid version, and the call will either incur cost or fail (if no payment method is on file). Browse the current free-model list at <https://openrouter.ai/models?max_price=0> — the list changes over time, so treat askLLM's built-in default as a starting point only and check that page for what's current.

## Free-tier quota

| Account status | Daily request limit |
|---|---|
| No top-up | 50 requests/day |
| Topped up **US$10+** (one-time, lifetime) | 1000 requests/day |

The quota is per-request regardless of model size; the top-up threshold is a one-time lifetime unlock, not a subscription. Check OpenRouter's official documentation for the current rules, since provider policy can change.

## Set the key

askLLM tries the environment variables **`OPENROUTER_API_KEY`** then **`LLM_API_KEY`**, in that order (either one is enough). Pick one method below — Method A is simpler.

### Method A: Windows environment variable (recommended)

Open PowerShell and run (replace the quoted text with your key):

```powershell
setx OPENROUTER_API_KEY "sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxx"
```

Or add a user variable `OPENROUTER_API_KEY` via "Settings > System > About > Advanced system settings > Environment Variables".

### Method B: write it to a .Renviron file

Open (create if missing) one of the following files in a plain-text editor:

- `%USERPROFILE%\.Renviron`
- `%USERPROFILE%\OneDrive\文件\.Renviron`
- `%USERPROFILE%\OneDrive\Documents\.Renviron` (the folder name depends on your OneDrive locale; either is fine)

Add a line:

```
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxx
```

**After setting the key, fully quit and restart jamovi** for the new environment variable to take effect.

## Using it in askLLM

- Set **Provider** to "OpenRouter".
- **Model** defaults to `openai/gpt-oss-20b:free` (live-tested 2026-07-29, works and costs nothing); change it to any other `:free` model as needed — **keep the `:free` suffix**.

## Privacy note

Cloud service — your question and data summary leave your machine and go to OpenRouter and its upstream model provider. For zero data transmission, use the **Ollama (local)** provider instead.

## Troubleshooting

| Message shown | Meaning | What to do |
|---|---|---|
| API key not yet set for ... | Neither `OPENROUTER_API_KEY` nor `LLM_API_KEY` was found | Follow "Set the key" above and restart jamovi |
| Invalid or expired key, please check .Renviron | Key is mistyped or revoked | Create a new key at openrouter.ai/keys |
| Wrong endpoint or model name (model: ...) | The Model field names a model that doesn't exist, or is missing the `:free` suffix and hit the paid version instead | Check spelling and the `:free` suffix, or revert to the default |
| Usage limit reached, try again later | Free quota exhausted (50/day with no top-up, 1000/day topped up) or rate-limited | Wait and retry, or check usage/top-up at openrouter.ai |
| Could not connect, please check your network | Network or firewall is blocking the request | Check your connection and retry |
