# M0 網路煙霧驗收記錄

日期:2026-07-19|結果:**通過,不需失敗分支**

## jamovi 內實測輸出(使用者目視驗收)

```
R: R version 4.5.0 (2025-04-11 ucrt)
ellmer: 0.2.0
HOME: C:/Rtools/home/builder
USERPROFILE: C:\Users\Sau-Chin Chen
key source: C:\Users\Sau-Chin Chen/OneDrive/文件/.Renviron
LLM reply: PONG.
elapsed: 1s
```

## 驗收結論

1. **compilerr 相依安裝**:snapshot(2025-05-25)提供全部 Windows 預編譯 binary(coro/httr2/later/promises/S7/ellmer),整個 install 僅 0.5 分鐘,零現場編譯。
2. **ellmer 0.2.0 於 jamovi bundled R 4.5.0 可用**:`chat_openai(base_url='https://integrate.api.nvidia.com/v1', api_key=, model=, echo='none')` 正常運作。
3. **engine 可對外 HTTPS**:NIM 往返 1 秒。
4. **金鑰查找**:engine 不繼承環境變數(與 Rj 一致);`%USERPROFILE%/OneDrive/文件/.Renviron` 命中。
5. **關鍵意外發現:engine 的 `HOME=C:/Rtools/home/builder`**(jamovi 打包時遺留的建置環境值)——`~`/`path.expand` 在 engine 內完全不可靠。**設計修正:金鑰查找鏈一律以 `Sys.getenv('USERPROFILE')` 為基準;`~/.Renviron` 僅作為最後一段。** 另 OneDrive 資料夾名稱可能因語系而異(文件/Documents),兩者都要嘗試。

## M0 決策(定案)

採**版本適應層**方案:ellmer >= 0.4.0 用 `chat_openai_compatible()`,否則用 `chat_openai()`(0.2.0,明給 model)。不需 `Remotes:` 釘版,不需 httr2 手打備援。

## 環境備忘

- jamovi-compiler 的 npm 相依鏈(gettext-extractor→glob 11→lru-cache 11)與 R `node` 套件的 Node 16 不相容;本機以系統 Node 22 替換 `D:\Apps\R\R-4.6.1\library\node\node.exe`(原檔備份 `node.exe.orig.bak`)繞過。值得回報 jamovi 上游。
- `.jmo` 產出於 `dist/askLLM_0.0.0_win64_jamovi-2.7.jmo`(5.1 MB);檔名版本 0.0.0 來自 0000.yaml,M2 統一。
