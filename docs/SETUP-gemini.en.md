# Setting up your Google Gemini API key

## What is this

Google Gemini is offered through Google AI Studio, with a **free tier and no credit card required** to get a key. Calls go through the cloud API, so your question and data summary are sent to Google's servers.

## Get a key

1. Go to <https://aistudio.google.com/apikey> and sign in with a Google account.
2. Click "Create API key".
3. Copy the generated key.

## Set the key

askLLM tries the environment variables **`GEMINI_API_KEY`** then **`GOOGLE_API_KEY`**, in that order (either one is enough). Pick one method below — Method A is simpler.

### Method A: Windows environment variable (recommended)

Open PowerShell and run (replace the quoted text with your key):

```powershell
setx GEMINI_API_KEY "your-key-here"
```

Or add a user variable `GEMINI_API_KEY` via "Settings > System > About > Advanced system settings > Environment Variables".

### Method B: write it to a .Renviron file

Open (create if missing) one of the following files in a plain-text editor:

- `%USERPROFILE%\.Renviron`
- `%USERPROFILE%\OneDrive\文件\.Renviron`
- `%USERPROFILE%\OneDrive\Documents\.Renviron` (the folder name depends on your OneDrive locale; either is fine)

Add a line:

```
GEMINI_API_KEY=your-key-here
```

**After setting the key, fully quit and restart jamovi** for the new environment variable to take effect.

## Using it in askLLM

- Set **Provider** to "Google Gemini (free tier)".
- **Model** defaults to `gemini-flash-latest` (a server-side alias Google resolves to the newest flash model, so it never goes stale as versions retire); change it if needed.

## Troubleshooting

| Message shown | Meaning | What to do |
|---|---|---|
| API key not yet set for ... | Neither `GEMINI_API_KEY` nor `GOOGLE_API_KEY` was found | Follow "Set the key" above and restart jamovi |
| Invalid or expired key, please check .Renviron | Key is mistyped or revoked | Create a new key at aistudio.google.com/apikey |
| Wrong endpoint or model name (model: ...) | The Model field names a model that doesn't exist | Check spelling, or revert to the default |
| Usage limit reached, try again later | Free quota exhausted or rate-limited | Wait and retry, or check usage in AI Studio |
| Could not connect, please check your network | Network or firewall is blocking the request | Check your connection and retry |
