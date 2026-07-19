# Setting up your NVIDIA NIM API key

## What is this

NVIDIA NIM is NVIDIA's cloud LLM API service, covering a range of open and commercial models. Sign-up usually comes with a free usage quota — **no credit card required** to get a key and start testing. Calls go through NVIDIA's cloud API, so your question and data summary are sent to NVIDIA's servers.

## Get a key

1. Go to <https://build.nvidia.com> and sign up or log in (Google, GitHub, or email).
2. Open any model page (e.g. `meta/llama-3.1-8b-instruct`) and click "Get API Key".
3. Copy the generated key (usually starts with `nvapi-`).

## Set the key

askLLM reads the environment variable **`NVIDIA_API_KEY`**. Pick one method below — Method A is simpler.

### Method A: Windows environment variable (recommended)

Open PowerShell and run (replace the quoted text with your key):

```powershell
setx NVIDIA_API_KEY "nvapi-xxxxxxxxxxxxxxxxxxxxxxxx"
```

Or add a user variable `NVIDIA_API_KEY` via "Settings > System > About > Advanced system settings > Environment Variables".

### Method B: write it to a .Renviron file

Open (create if missing) one of the following files in a plain-text editor:

- `%USERPROFILE%\.Renviron`
- `%USERPROFILE%\OneDrive\文件\.Renviron`
- `%USERPROFILE%\OneDrive\Documents\.Renviron` (the folder name depends on your OneDrive locale; either is fine)

Add a line:

```
NVIDIA_API_KEY=nvapi-xxxxxxxxxxxxxxxxxxxxxxxx
```

**After setting the key, fully quit and restart jamovi** for the new environment variable to take effect.

## Using it in askLLM

- Set **Provider** to "NVIDIA NIM".
- **Model** defaults to `meta/llama-3.1-8b-instruct`; change it to any other NIM-hosted model name if needed.

## Troubleshooting

| Message shown | Meaning | What to do |
|---|---|---|
| API key not yet set for ... | `NVIDIA_API_KEY` was not found | Follow "Set the key" above and restart jamovi |
| Invalid or expired key, please check .Renviron | Key is mistyped or revoked | Re-copy the key from build.nvidia.com |
| Wrong endpoint or model name (model: ...) | The Model field names a model that doesn't exist | Check spelling, or revert to the default |
| Usage limit reached, try again later | Free quota exhausted or rate-limited | Wait and retry, or check usage on build.nvidia.com |
| Could not connect, please check your network | Network or firewall is blocking the request | Check your connection and retry |
