# Setting up your GitHub Models API key

## What is this

GitHub Models lets anyone with a GitHub account call a range of models (including OpenAI's GPT family) using a personal access token. **Free usage, no separate credit card needed** — just a GitHub account. Calls go through the cloud API, so your question and data summary are sent to GitHub/Azure servers.

## Get a key

1. Go to <https://github.com/settings/tokens> (sign in to GitHub first).
2. Create a new Personal Access Token.
3. ⚠️ **Grant the Models permission** — this is the most common cause of failure:
   - **Fine-grained token** (`github_pat_...`): under **Account permissions**, find **Models** and set it to **Read-only**. Without this the token authenticates and can even list the model catalog, but every inference call returns **HTTP 403 `no_access`**.
   - **Classic token** (`ghp_...`): tick `read:user` (GitHub Models currently keys access off that scope).
4. Copy the generated token immediately — it is shown only once.

> Already created a token without the permission? Open it from the token page, edit permissions, add Models (Read-only), and save — no need to generate a new one.

## Set the key

askLLM tries **`GITHUB_MODELS_TOKEN`** → **`GITHUB_PAT`** → **`GITHUB_TOKEN`**, in that order (any one is enough).

> ⚠️ **Use `GITHUB_MODELS_TOKEN`, not `GITHUB_TOKEN`.**
> `GITHUB_TOKEN` is the variable git and the GitHub CLI (`gh`) read first. If you store a Models-only token under that name, your own `git push` and `gh` commands will start using it and get rejected (`Permission to ... denied`). A dedicated name avoids the clash entirely.
>
> Already set it as `GITHUB_TOKEN`? Rename it:
> ```powershell
> setx GITHUB_MODELS_TOKEN "your-token-here"
> reg delete "HKCU\Environment" /v GITHUB_TOKEN /f
> ```

Pick one method below — Method A is simpler.

### Method A: Windows environment variable (recommended)

Open PowerShell and run (replace the quoted text with your token):

```powershell
setx GITHUB_MODELS_TOKEN "your-token-here"
```

Or add a user variable `GITHUB_MODELS_TOKEN` via "Settings > System > About > Advanced system settings > Environment Variables".

### Method B: write it to a .Renviron file

Open (create if missing) one of the following files in a plain-text editor:

- `%USERPROFILE%\.Renviron`
- `%USERPROFILE%\OneDrive\文件\.Renviron`
- `%USERPROFILE%\OneDrive\Documents\.Renviron` (the folder name depends on your OneDrive locale; either is fine)

Add a line:

```
GITHUB_MODELS_TOKEN=your-token-here
```

**After setting the key, fully quit and restart jamovi** for the new environment variable to take effect.

## Using it in askLLM

- Set **Provider** to "GitHub Models".
- **Model** defaults to `openai/gpt-4o-mini`; change it to any other model listed in the GitHub Models catalog if needed.

## Troubleshooting

| Message shown | Meaning | What to do |
|---|---|---|
| API key not yet set for ... | None of `GITHUB_MODELS_TOKEN` / `GITHUB_PAT` / `GITHUB_TOKEN` was found | Follow "Set the key" above and restart jamovi |
| Key is valid but lacks permission for this model | Token is missing the Models permission (most common) | Edit the token and add Models (Read-only) under Account permissions |
| Invalid or expired key | Token mistyped or expired | Create a new token at github.com/settings/tokens |
| Wrong endpoint or model name (model: ...) | The Model field names a model that doesn't exist | Check spelling, or revert to the default |
| Usage limit reached, try again later | Free quota exhausted or rate-limited | Wait and retry |
| Could not connect, please check your network | Network or firewall is blocking the request | Check your connection and retry |
