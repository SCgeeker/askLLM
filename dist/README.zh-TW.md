# dist/ —— 已建置的 `.jmo` 套件

本目錄存放 askLLM 編譯完成的 jamovi 模組套件,由 `jmvtools::install()` 在安裝過程中順帶產出。

## 檔名格式

```
askLLM_<版本>_<平台>.jmo
```

範例:`askLLM_1.3.0_win64.jmo` 代表:

- `askLLM` —— 模組名稱
- `1.3.0` —— 模組版本(來自 `DESCRIPTION` / `jamovi/0000.yaml`)
- `win64` —— 目標作業系統與 CPU 架構(Windows 64 位元)

檔名原本還帶 `jamovi-<系列版本>` 標記,那是 1.0.0 時期的建置慣例,現已移除:模組 manifest 只宣告 `jms: '1.0'`(模組規格版本),而以 jamovi 2.7 建置的檔案已實測可在 jamovi 28.2.0.0 執行。在檔名標上系列版本,反而讓使用者以為不能用。

## 平台綁定

`.jmo` **不是**跨平台通用檔案,而是針對以下三者的特定組合建置:

1. **作業系統**(Windows / macOS / Linux)
2. **CPU 架構**(如 x64)

安裝與目前執行環境不同作業系統或架構的 `.jmo`,會安裝失敗或行為不可預期。

jamovi 版本這一項則沒那麼硬。不同 jamovi 發行版所綁的 R 與 CRAN snapshot 確實不同,所以無法保證一份建置到處都能跑。能報告的是實測結果:1.3.0 的建置在 jamovi 28.2.0.0 上正常運作。若你的平台不同,請依下方步驟從原始碼重新建置,而非直接使用本目錄現有檔案。

## 如何重新建置

在 R console 中,以本 repo 為工作目錄(或以 `path` 參數指向本 repo):

```r
jmvtools::install(home = "C:/Program Files/jamovi 2.7.37.0")
```

會編譯模組並產出新的 `.jmo` 至本目錄,檔名依上述格式命名。

## 如何安裝 `.jmo`

在 jamovi 中:點選右上角 `⊕` 圖示 → **Side-load** 分頁 → 選擇 `.jmo` 檔 → 等待安裝完成。
