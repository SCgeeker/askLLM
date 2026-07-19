# M0 Network Smoke Test — Acceptance Record

Date: 2026-07-19 | Result: **PASSED — no fallback branch needed**

## Observed output inside jamovi (user visual acceptance)

```
R: R version 4.5.0 (2025-04-11 ucrt)
ellmer: 0.2.0
HOME: C:/Rtools/home/builder
USERPROFILE: C:\Users\Sau-Chin Chen
key source: C:\Users\Sau-Chin Chen/OneDrive/文件/.Renviron
LLM reply: PONG.
elapsed: 1s
```

## Acceptance conclusions

1. **compilerr dependency install**: the 2025-05-25 snapshot served prebuilt Windows binaries for all deps (coro/httr2/later/promises/S7/ellmer); the whole install took 0.5 min with zero on-site compilation.
2. **ellmer 0.2.0 works on jamovi's bundled R 4.5.0**: `chat_openai(base_url='https://integrate.api.nvidia.com/v1', api_key=, model=, echo='none')` functions correctly.
3. **The engine has outbound HTTPS**: NIM round trip in 1 second.
4. **Key lookup**: the engine inherits no env vars (consistent with the Rj pilot); `%USERPROFILE%/OneDrive/文件/.Renviron` was the hit.
5. **Critical surprise: the engine's `HOME=C:/Rtools/home/builder`** (a leftover build-environment value from jamovi packaging) — `~`/`path.expand` is completely unreliable inside the engine. **Design correction: the key lookup chain must be anchored on `Sys.getenv('USERPROFILE')`; `~/.Renviron` only as the final step.** Also, the OneDrive folder name is locale-dependent (文件 vs Documents) — try both.

## M0 decision (locked)

Use the **version-adaptive layer**: ellmer >= 0.4.0 → `chat_openai_compatible()`; otherwise `chat_openai()` (0.2.0, model passed explicitly). No `Remotes:` pinning, no raw-httr2 fallback needed.

## Environment notes

- jamovi-compiler's npm dependency chain (gettext-extractor→glob 11→lru-cache 11) is incompatible with the R `node` package's Node 16; worked around locally by replacing `D:\Apps\R\R-4.6.1\library\node\node.exe` with system Node 22 (original backed up as `node.exe.orig.bak`). Worth reporting upstream to jamovi.
- `.jmo` produced at `dist/askLLM_0.0.0_win64_jamovi-2.7.jmo` (5.1 MB); the 0.0.0 in the filename comes from 0000.yaml — to be unified in M2.
