# Setting up Custom (any OpenAI-compatible endpoint)

## What is this

"Custom" lets you connect to **any OpenAI-compatible API endpoint** — a self-hosted vLLM or LM Studio server, text-generation-webui, or any cloud service not built into this module. Useful if you already run your own model server, or want to use a provider not covered by the other presets. Whether it's free or requires a credit card depends entirely on the service you connect to.

## Get a key

Depends on the service you're connecting to:

- Self-hosted services (e.g. vLLM/LM Studio on your local network) usually **don't require a real key**, but the field still needs a non-empty string — any placeholder like `local` works.
- Cloud OpenAI-compatible services that require a key: follow that service's own documentation to obtain one.

## Set the key

askLLM reads the environment variable **`LLM_API_KEY`**. Pick one method below — Method A is simpler.

### Method A: Windows environment variable (recommended)

Open PowerShell and run (replace the quoted text with your key, or any placeholder string for self-hosted services):

```powershell
setx LLM_API_KEY "your-key-here"
```

Or add a user variable `LLM_API_KEY` via "Settings > System > About > Advanced system settings > Environment Variables".

### Method B: write it to a .Renviron file

Open (create if missing) one of the following files in a plain-text editor:

- `%USERPROFILE%\.Renviron`
- `%USERPROFILE%\OneDrive\文件\.Renviron`
- `%USERPROFILE%\OneDrive\Documents\.Renviron` (the folder name depends on your OneDrive locale; either is fine)

Add a line:

```
LLM_API_KEY=your-key-here
```

**After setting the key, fully quit and restart jamovi** for the new environment variable to take effect.

## Using it in askLLM

- Set **Provider** to "Custom OpenAI-compatible".
- **Base URL (custom provider)** is **required**: enter your endpoint URL, e.g. a self-hosted vLLM server is often `http://localhost:8000/v1`, LM Studio is often `http://localhost:1234/v1`. Leaving it blank shows a reminder and the call is skipped.
- **Model** is **required**: custom providers have no built-in default; enter a model name actually available on that endpoint.

## Troubleshooting

| Message shown | Meaning | What to do |
|---|---|---|
| custom provider needs the baseUrl option filled in | Base URL field is empty | Enter the endpoint URL and re-tick Submit |
| This provider has no default model, please fill in the "Model" field | Model field is empty | Enter a model name actually available on that endpoint |
| API key not yet set for ... | `LLM_API_KEY` was not found | Follow "Set the key" above and restart jamovi (any non-empty placeholder works for self-hosted services) |
| Invalid or expired key, please check .Renviron | The endpoint rejected the key | Confirm whether the endpoint requires a key and that its format is correct |
| Wrong endpoint or model name (model: ...) | Base URL or Model name is wrong | Confirm the endpoint is running and the path includes `/v1` |
| Could not connect, please check your network | Endpoint isn't running, URL is wrong, or a firewall is blocking it | Confirm the self-hosted service is running and the URL/port are correct |
