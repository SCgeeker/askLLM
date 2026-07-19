# dist/ —— 已建置的 `.jmo` 套件

本目錄存放 askLLM 編譯完成的 jamovi 模組套件,由 `jmvtools::install()` 在安裝過程中順帶產出。

## 檔名格式

```
askLLM_<版本>_<平台>_jamovi-<系列版本>.jmo
```

範例:`askLLM_1.0.0_win64_jamovi-2.7.jmo` 代表:

- `askLLM` —— 模組名稱
- `1.0.0` —— 模組版本(來自 `DESCRIPTION` / `jamovi/0000.yaml`)
- `win64` —— 目標作業系統與 CPU 架構(Windows 64 位元)
- `jamovi-2.7` —— 目標 jamovi **系列版本**(大.小版號),非 jamovi 的精確發行版

## 平台綁定

`.jmo` **不是**跨平台通用檔案,而是針對以下三者的特定組合建置:

1. **作業系統**(Windows / macOS / Linux)
2. **CPU 架構**(如 x64)
3. **jamovi 系列版本**(如 2.7.x)——因為不同系列所綁的 R 與 CRAN snapshot 版本不同

安裝與目前執行環境不同作業系統、架構或 jamovi 系列版本的 `.jmo`,會安裝失敗或行為不可預期。若你的平台不同,請依下方步驟從原始碼重新建置,而非直接使用本目錄現有檔案。

> 注意:本目錄目前存放的 `askLLM_0.0.0_win64_jamovi-2.7.jmo` 檔名版本仍是早期建置遺留的 `0.0.0`(見 `dev-notes/M0-result.zh-TW.md`),與模組實際版本 `1.0.0` 不一致。發佈前請重新建置以取得版本號正確的檔名。

## 如何重新建置

在 R console 中,以本 repo 為工作目錄(或以 `path` 參數指向本 repo):

```r
jmvtools::install(home = "C:/Program Files/jamovi 2.7.37.0")
```

會編譯模組並產出新的 `.jmo` 至本目錄,檔名依上述格式命名。

## 如何安裝 `.jmo`

在 jamovi 中:點選右上角 `⊕` 圖示 → **Side-load** 分頁 → 選擇 `.jmo` 檔 → 等待安裝完成。
