# Setting up Ollama (local, on your own machine)

## What is this

Ollama runs open-source LLMs **on your own computer** — **completely free, no API key, no credit card**. Every question and data summary is **processed only on your machine and never sent to any external server** — the most privacy-preserving option this module offers, ideal for sensitive data. The trade-off is that reply quality and speed depend on your hardware and the size of the model you choose.

## Install and prepare

1. Go to <https://ollama.com> and download/install Ollama (Windows/macOS/Linux supported).
2. Once installed, Ollama runs in the background and serves requests at `http://localhost:11434`.
3. Open a terminal (PowerShell or Command Prompt) and pull a model, e.g.:

   ```powershell
   ollama pull llama3.2
   ```

   Download time depends on model size and your connection; this only needs to be done once per model.

## Set the key

**Not needed** — Ollama runs locally and requires no API key. It is the only key-free option among the five providers.

## Using it in askLLM

- Make sure Ollama is running (it usually auto-starts and stays in the background after install; run `ollama list` in a terminal if you want to confirm it is reachable).
- Set **Provider** to "Ollama (local)".
- **Model** defaults to `llama3.2`; if you pulled a different model (e.g. `mistral`, `qwen2.5`), enter that name here — it must match the name used with `ollama pull`.

## Troubleshooting

| Message shown | Meaning | What to do |
|---|---|---|
| Wrong endpoint or model name (model: ...) | The name in the Model field is not installed locally | Run `ollama pull <model-name>`, or run `ollama list` to see what's installed |
| Could not connect, please check your network | Ollama isn't running, or `localhost:11434` is blocked by a firewall | Confirm the Ollama app is running; restart it if needed |
| Usage limit reached, try again later | Rare for local execution | Check whether another process is heavily using Ollama at the same time |

## Why choose Ollama

If you're analyzing data that must never leave your machine (e.g. unpublished clinical or organizational data), Ollama is the **only zero-data-egress** option in this module: the summary statistics of your selected variables never leave your computer. The trade-off is hardware requirements (8GB+ free RAM is a reasonable minimum, depending on model size) and typically lower reply quality than large cloud models.
