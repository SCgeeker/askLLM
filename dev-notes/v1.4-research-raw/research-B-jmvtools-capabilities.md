# 研究 B:jmvtools / jamovi-compiler / jmvcore 最新狀態與模組開發者能力邊界

調查日期:2026-09-25。目的:評估 askLLM(jamovi LLM 模組,現行 v1.3.1)的擴充方向。

## 0. 方法與來源可信度

- **原始碼(已證實的主要依據)**,全部 clone 至 `scratchpad/`:
  - `jmvtools/`:github.com/jamovi/jmvtools,HEAD `ee9488d` 2026-09-19「Version 28.3.1」。
  - `jamovi-compiler/`:github.com/jamovi/jamovi-compiler,HEAD `0f554f5` **2025-10-08**(已停更,見 §1.2)。
  - `jamovi/`:github.com/jamovi/jamovi monorepo(sparse checkout),HEAD `360cb89` 2026-09-24;內含 `jmvcore/`、`jamovi-compiler/`、`server/`、`engine/`、`client/`、`electron/`。
  - `jmv/`:github.com/jamovi/jmv,HEAD `cf04eb0` 2026-08-22,jmv 2.8.0。
  - `devdocs/`:github.com/jamovi/dev.jamovi.org(dev.jamovi.org 的 Astro 原始碼),HEAD `17737bb` 2026-09-17。
- **網路限制**:`www.jamovi.org`、`docs.jamovi.org`、`dev.jamovi.org`、CRAN 皆被本環境 egress proxy 擋下(403);`api.github.com/repos/jamovi/jmvcore` 回 403(session 未授權)、`git clone jamovi/jmvcore` 失敗。因此 jamovi 官方發行日期只能靠搜尋引擎摘要,標為「未確認」。
- 標記:**[已證實]** = 有原始碼/官方文件檔案與行號;**[推論]** = 由程式碼合理推導但未實機驗證;**[未確認]** = 無法取得一手來源。

---

## 1. jmvtools 最新版本與 changelog

### 1.1 版本與時間線 [已證實]

`jmvtools/DESCRIPTION`:`Version: 28.3.1`,`Imports: node (>= 1.1), jmvcore (>= 2.3.4)`,**沒有 `Depends: R (>= x)`**。版號自 2026-06 起改為跟隨 jamovi 主版號:

| 版本 | commit | 日期 | 重點 |
|---|---|---|---|
| 2.7.13 | `5685f7b` | 2025-11-07 | 移除 compiler submodule,改以 git subtree 內嵌於 `inst/node_modules/jamovi-compiler/`(`7649701`) |
| 2.7.14 | `5f20c29` | 2025-11-22 | 同步 compiler |
| 2.7.17 / 2.7.24 / 2.7.25 | | 2026-03-25/26 | 同步 compiler |
| 2.7.26 | `ec47dec` | 2026-04-14 | 同步 compiler |
| 28.0 / 28.1 | `11c64ac` / `e8fbcb5` | 2026-06-16 | 對應 jamovi 28.x |
| 28.2 | `a67db51` | 2026-07-13 | |
| 28.3 | `b0bbefb` | 2026-07-15 | |
| **28.3.1** | `ee9488d` | **2026-09-19** | 同步 compiler(File/Text/Svg/vector image,見 §2);新增 `justfile`(維護者發行用:S3 `repo.jamovi.org` 同步、subtree 更新);「Added build, deploy commands」= justfile 的 `build`(`R CMD build .`)與 S3 push,**非**新的 R API |

安裝方式不變:`install.packages('jmvtools', repos=c('https://repo.jamovi.org','https://cran.r-project.org'))`(`jmvtools/README.md`;`devdocs/.../tuts0101-getting-started.md:34`)。

### 1.2 jamovi-compiler 與 jmvcore 的原始碼位置已搬家 [已證實]

- 獨立 repo `jamovi/jamovi-compiler` 最後 commit 是 2025-10-08(`0f554f5` "Fix to Action options (URGENT)"),**沒有** File/Text/Svg。真正的 compiler 開發在 monorepo `jamovi/jamovi/jamovi-compiler/`,以 `git subtree split -P jamovi-compiler` 推到 `compiler` 分支,再 subtree pull 進 jmvtools(`jmvtools/justfile` 的 `update-compiler-branch`/`pull-compiler-subtree`)。
- jmvcore 亦在 monorepo:`jamovi/jmvcore/DESCRIPTION` `Version: 28.3`, `Date: 2026-09-24`,`BugReports: https://github.com/jamovi/jamovi/issues`。jmv 的 CI 已改為「install jmvcore from the jamovi monorepo」(`jmv` commit `4ba879d` 2026-06-12)。
- 結論:**查 schema/jmvcore 請以 `jmvtools/inst/node_modules/jamovi-compiler/` 或 monorepo 為準**;`diff -rq` 顯示獨立 repo 與內嵌版在 `schemas/optionschemas.yaml`、`resultelementschemas.yaml`、`uictrlschemas.yaml`、`analysisschema.yaml`、`resultsschema.yaml`、`compiler.js`、`uicompiler.js` 等全部不同,且內嵌版多了 `docker.js`。

### 1.3 `prepare` / `install` / `create` 行為 [已證實]

`jmvtools/R/main.R` 的 R API 未變:`check(home)`、`install(pkg='.', home, debug)`、`prepare(pkg, home)`、`create(path, home, gitignore)`、`addAnalysis(name, title, path, home)`、`i18nCreate/i18nUpdate`、`version()`。全部只是呼叫 node 跑 `index.js`(`main.R:5-7`)。
- `install()` 在非 Windows 會傳 `--rpath R.home('bin')`(`main.R:29-44, 66-77`);Windows 只傳 `--home`。
- Linux 且未指定 home → 預設 `home='flatpak'`(`main.R:33-34`)。
- compiler CLI(`index.js:70-77`):`jmc --build path`、`--prepare path`、`--install path [--home path|docker:container]`、`--check`、`--i18n`。新增 **`--home docker:<container>`**:在執行中的 jamovi 容器映像裡起一個拋棄式容器編譯 `.jmo`,再以 `echo "install: /tmp/x.jmo" > /proc/1/fd/0` 交給 server 安裝(`docker.js:40-80`;monorepo `1cf1b28` 2026-09-08)。對桌面開發者無影響,但顯示官方主推 cloud/容器工作流。
- `minApp` 檢查:`index.js:320-330`,`0000.yaml` 未填時預設 `1.0.8`;`minApp > appVersion` 則拒絕編譯/安裝。**新元素(File/Text/Svg)官方文件要求 `minApp: 28.3.0`**(`devdocs/src/content/docs/reference/api/option-file.md:10-14`、`text.md:32-36`)。

### 1.4 對 jamovi 28.x 與 R 版本的要求

- **[已證實]** jmvtools 不要求特定系統 R;它用 **jamovi 自帶的 R** 編譯:Windows `<home>/Frameworks/R/bin/x64/R.exe`、macOS `Frameworks/R.framework/Versions/Current/Resources/bin/R`、flatpak、Linux `<home>/lib/R`(`index.js:184-231`),並依偵測到的 R 版本選 CRAN 快照(`snapshots.js:635-696`:4.0.2、4.0.5、4.1.1–4.1.3、4.3.2、4.4.1、4.5.0、**4.6.0 → 快照 2026-05-11**)。
- **[已證實]** jamovi 28.x 綁 **R 4.6.0**:monorepo `docker-compose.yaml:5` `jamovi/r-base:4.6.0-resolute`;jmv 2.8.0 多筆 commit 針對 R 4.6 修正(`a215a9e`、`74ef1e5`、`2edf0e3`)。這與 askLLM dev-notes 提到開發機 R 4.6.1 一致。
- **[已證實]** Windows 若用 Microsoft Store(msix)版,`jmvtools` 找不到安裝位置;官方要求用 `.exe` 安裝(`devdocs/.../tuts0101-getting-started.md:12`)。
- **[已證實]** monorepo `version` 檔為 `28.3.0.0`(commit `6400e4d` 2026-09-18「Version 28.3」)。
- **[未確認]** 桌面版 28.3 是否已 GA:搜尋引擎摘要指 28.2.0 於 2026-08-13 釋出、28.3.0 已上 jamovi Cloud;GitHub Releases 頁只列到 2.7.30(28.x 未在 GitHub 發布)。askLLM README 目前寫 28.2.0.0。

### 1.5 協調者提供線索之核實 [已證實]

| 線索 | 核實結果 |
|---|---|
| (a) `type: File` = PR #1862,2026-09-15 合併 | **正確**。`github.com/jamovi/jamovi/pull/1862`「Added OptionFile」,作者 jonathon-love,dropmann 審核,2026-09-15 併入 `main`(來源分支 `optionfile`);monorepo 對應 commit `e83a9bc`(作者日期 09-13,commit 日期 09-15)。「OptionFile: now stores file in .omv」= `6acb8e2` 2026-09-17。 |
| (a) 測試模組 `jonathon-love/filetest` | **已 clone 核實**(2 commits,2026-09-14)。`jamovi/showfile.a.yaml`:`type: File, extensions: [txt, csv, md]` 與 `type: File, multiple: true`;`showfile.u.yaml`:`jus: '3.0'`,widget **`FileSelector`**(只需 `name`);`R/showfile.b.R`:`files <- c(list(self$options$file), self$options$files)` → `readLines(file$path)`、標頭用 `file$filename`;結果用 `Preformatted`。`DESCRIPTION` `Imports: jmvcore (>= 2.0)`;`0000.yaml` 仍是 `minApp: 1.0.8`(尚未照文件改 28.3.0)。 |
| (b) `Text` 結果元素(Markdown) | **正確**。`a44312c` 2026-09-16 新增、`d574fdb` 2026-09-17「Text results: now consumes markdown」;文件 `text.md` 2026-09-17。 |
| (c) SVG 結果元素、.docx/.odt 匯出、htmlify 重寫 = PR #1795 | **部分正確,歸屬需更正**。PR #1795 是 sjentsch 的「Improvements to htmlify, other smaller improvements」(2026-09-22 併入,三個小 commit:命名/選項處理)。SVG(`c2b837d` 09-13)、`.docx` 匯出(`b9f2444` 09-19)、`htmlify` 實作(`69e1223` 09-19)、`.odt` 匯出(`41ce522` 09-23)、hydration 重寫(09-16~09-23 多筆)都是 jonathon-love 直接 push 到 `main` 的 commit,不在 #1795。 |
| jmvtools 已升 28.3.0 / 28.3.1(2026-09-18) | **需區分**:jmvtools「Version 28.3」是 **2026-07-15**(`b0bbefb`),其內嵌 compiler **沒有** File/Text/Svg(以 `git show b0bbefb:…/optionschemas.yaml` 驗證,無 `File:`);**只有 28.3.1**(`ee9488d`,2026-09-19 08:49 +1000 = 09-18 22:49 UTC)才含新 schema。要用新功能請確認 `jmvtools::version()` 回 `28.3.1`。 |
| jmvcore 是否也升 28.3 | **是**。`68caf31` 2026-09-24 把 `jmvcore/DESCRIPTION` 從 `Version: 2.7.38 / Date: 2026-07-18` 改為 `Version: 28.3 / Date: 2026-09-24`——版號跳號,跟隨 jamovi 主版號。jamovi 28.2 桌面版隨附的是 jmvcore 2.7.38(與 askLLM dev-notes 實機觀察一致)。 |

---

## 2. jamovi-compiler schemas:選項型別與結果元素型別完整清單

以下皆取自 `jmvtools/inst/node_modules/jamovi-compiler/schemas/`(= monorepo 2026-09-19 版)。

### 2.1 選項型別(a.yaml `options[].type`)[已證實]

`analysisschema.yaml:103-122` 允許的 enum:`Data, Level, Variable, Variables, Terms, Integer, Number, String, Bool, List, NMXList, Array, Pairs, Sort, Output, Outputs, Pair, Group, Action, File`。

各型別屬性(`optionschemas.yaml`,行號為型別起始):

| 型別 | 行 | 屬性 | 備註 |
|---|---|---|---|
| Data | 2 | requiresMissings | |
| Variables | 26 | takeFromDataIfMissing, default, required, rejectUnusedLevels, suggested(continuous/ordinal/nominal/id), permitted(numeric/factor/id), rejectInf | |
| Level | 71 | variable `(var)`, allowNone, content | 綁定某 Variable 的 level |
| Variable | ~95 | 同 Variables 單值 + content | |
| Bool | 135 | default | |
| **Action** | 151 | title, hidden, **action: enum ["open"]**, default(標記 to deprecate) | 見 §2.3 |
| **File** | 174 | title, hidden, **multiple**, **extensions[]** | **新增**,見 §2.2 |
| Integer / Number | 197 / 217 | default, min, max | |
| String | 237 | content, default | |
| List | 255 | options[](name/title), default | |
| NMXList | 286 | options[], default[] | 多選 |
| Array | 317 | items, default, template | |
| Pairs | 339 | suggested, permitted | |
| Terms | 372 | default | |
| Group | 390 | elements | |
| Sort | 417 | | |

分析層級(`analysisschema.yaml:1-95`):`category: analyses|plots`(2025-05-21 新增「plots 分析」,對應 jamovi Plots 分頁;`devdocs/.../tuts0304-plot-modules.md`)、`weightsSupport: auto|integerOnly|full|none`、`arbitraryCode`(server 端預設把該分析 `enabled = not arbitrary_code`,即 Rj 那種需使用者明示啟用的機制,`server/jamovi/server/analyses/analyses.py:70-88`)、`completeWhenFilled`、`export`、`pause`、`formula`、`addonFor`。

### 2.2 檔案選擇型別:**存在,名為 `File`** [已證實,jamovi ≥ 28.3]

- 引入 commit:monorepo `e83a9bc` 2026-09-15「Added OptionFile」、`6acb8e2` 2026-09-17「OptionFile now stores file in .omv」。dev 文件 `option-file.md`(2026-09-14)。
- a.yaml:
  ```yaml
  - name: lexicon
    type: File
    title: Lexicon
    multiple: false        # 可選
    extensions: [csv, txt] # 可選,不含點
  ```
- u.yaml 對應控制項 **`FileSelector`**(`uicompiler.js:858`;`uictrlschemas.yaml:32, 551-554`):一顆「Browse…」按鈕 + 已選檔案清單(`client/analysisui/fileselector.ts`)。檔案對話框由主視窗處理(`requestAction('selectFiles')` → `optionspanel.ts:134-135` → `host.showOpenDialog`)。
- **檔案不是以原路徑交給 R**:client 把檔案「複製進 session」(桌面版由 server 就地複製、cloud 為上傳),以內容 sha-256 + 副檔名命名放在 session temp(`server/jamovi/server/sessionfiles.py:1-30, 47-60`)。R 端 `self$options$<name>` 得到 `list(path=, filename=)`,`path` = `<sessionTemp>/<id>`(`jmvcore/R/options.R:1009-1016`),`filename` 為使用者原檔名;`multiple: true` 時為 list of list。未選為 `NULL`(header.template 預設 `NULL`)。
- 檔案內容會寫入 `.omv`(`server/.../formatio/omv.py` 於 `6acb8e2`),重開時若檔案沒帶著,UI 標「needs re-selecting」,R 端 `.check` 會 `reject("The file '{filename}' needs to be re-selected")`(`options.R:1019-1031`)。
- 大小受 session 儲存上限限制(上傳 413,`client/main/instance.ts:335-339`;`uploads.py` `max_bytes`)。
- `valueAsSource()` 只輸出檔名(不輸出路徑),供「R 語法」面板(`options.R:1076-1088`)。
- 對 askLLM 的意義:**可以讓使用者選 `prompts/*.md`、`codebook.csv` 等檔案並在 R 讀取**,且會隨 .omv 保存;代價是需要 `minApp: 28.3.0`。

### 2.3 `Action` 型別現況 [已證實 + 推論]

- a.yaml schema 只允許 `action: open`(`optionschemas.yaml:161-163`);dev 文件 `option-action.md` 亦只寫 `open`(「需 jamovi 2.7.12+」;`updates.md` 2025-11-11 條目)。`default` 欄位標記「to deprecate」。
- u.yaml 對應 **`ActionButton`**(`uicompiler.js:843`;`client/analysisui/gridactionbutton.ts`)= **真正的按鈕**:點擊把 Bool 值設為 TRUE → 分析執行 → server 於執行後把 action 選項清回 FALSE(`server/.../analyses/analysis.py:196-197`);載入 .omv 時亦一律清除,避免偽造檔案觸發(`analyses.py:138-146`,2026-09-19)。
- jmvcore `OptionAction`(`jmvcore/R/options.R:437-596`):`perform(fun)` 建立隱藏 `Array` of `Action` 結果元素,`fun(action)` 回傳 `list(data=<data.frame>, title=)` 時用 `jmvReadWrite::write_omv()` 寫到 session temp 並讓 client 開新視窗(`action='open'`);**2026-09-19 新增 `action='openExternal'`**(`02aeb48`):回傳 `list(path=, filename=)` 或寫到 `action$params$fullPath`,檔案搬到 session temp 的 `external/` 子目錄,server 一次性提供(`server.py:509-548` `download_temp`),桌面版交給 OS 開啟(electron `main.js` 有副檔名白名單:pdf/docx/md/txt/csv/xlsx/png/svg/zip…),瀏覽器版則下載。
- **[推論]** compiler schema 的 `action` enum 尚未加入 `openExternal`,故 a.yaml 直接寫 `action: openExternal` 會被 schema 驗證擋下;可能需在 R 端手動用 `jmvcore::OptionAction$new(..., action='openExternal')`(h.R 是產生檔,不宜手改)或等 schema 更新。
- **[推論]** 對 askLLM 最實用的用法:把 `submit` 從 `Bool`(CheckBox)改為 `Action`(ActionButton),R 端只讀 `self$options$submit` 是否 TRUE、不呼叫 `perform()`。因 server 執行後自動清回 FALSE,天然成為「一次性送出」按鈕,免除現行「先取消勾選再勾選」的 UX;需注意 `options.R:324-325`:「OptionAction 為 TRUE 時會觸發 clearWith」,askLLM 結果元素已設 `clearWith: []`,故不受影響。此點需實機驗證(`stage`、`hidden` 互動)。
- 結果元素 `Action`(`resultelementschemas.yaml:377-395`,必填 `operation`)是 `perform()` 內部用的,一般模組不需在 r.yaml 宣告。

### 2.4 結果元素型別(r.yaml `items[].type`)[已證實]

`resultsschema.yaml:41-54` enum:`Table, Group, Array, Image, Preformatted, Text, Html, Svg, State, Property, Output, Notification, Action`;`compiler.js:280-293` 產生 R 程式碼時接受:`Table, Image, Array, Group, Preformatted, Text, Html, Svg, State, Output, Outputs, Notice, Action`。
- **[未確認]** `type: Notice` 在 r.yaml 是否通過 schema(schema 寫 `Notification`,compiler.js 寫 `Notice`,jmv 自身 r.yaml 無此用法);dev 文件 `notice.md` 示範的是 r.yaml 宣告與 R 端動態 `jmvcore::Notice$new()` + `self$results$insert()` 兩種。動態建立是確定可行的路徑。

各元素屬性(`resultelementschemas.yaml`):

| 元素 | 行 | 屬性 | 備註 |
|---|---|---|---|
| Table | 2 | columns[](name,title,superTitle,type text/number/integer,format,content,combineBelow,sortable,visible,refs), rows, rowSelect, sortSelect, swapRowsColumns, notes | |
| Image | 87 | width, height, **widthB, heightB**, renderFun, requiresData, **mode: raster\|vector** | 見 §2.6 |
| Group / Array | 135 / 173 | items / template, layout, hideHeadingOnlyChild | |
| Preformatted | 220 | content | |
| **Text** | 251 | content | **新增**(`a44312c` 2026-09-16) |
| Html | 282 | content | 見 §2.5 |
| **Svg** | 313 | content | **新增**(`c2b837d` 2026-09-13) |
| Output | 344 | varTitle, varDescription, items, initInRun, **measureType: nominal\|ordinal\|continuous** | |
| Action | 377 | operation | 內部用 |

### 2.5 `Html` 結果元素允許的內容 [已證實]

- R 端(`jmvcore/R/html.R`):`setContent(html)`、`setScripts(paths)`、`setStylesheets(paths)`(自動加上 `<package>/` 前綴,由 server 以 `module/<pkg>/<path>` 提供)、`knit(rmd)`(knitr 產出 + html_dependencies);`content` active binding。**R 端完全不過濾**。
- Client 渲染(`jamovi/client/resultsview/html.ts`):
  - 內容經 `htmlTrusted()` = `template.innerHTML = html`(`client/common/htmlelementcreator.ts:83-90`),**無任何 sanitize**。
  - **`<script>` 會被明確重新執行**:「Scripts inside innerHTML are not executed… we clone each script's text into a new element, append it to the head」(`html.ts` render())。
  - `<a href>` 點擊被攔截改呼叫 `window.openUrl(href)`(外部瀏覽器開啟)。
  - 結果面板 iframe `sandbox="allow-scripts allow-same-origin"`(`client/main/resultspanel.ts:254`)。
- Server CSP(`server/jamovi/server/server.py:900-908`):`default-src 'self'; font-src 'self' data:; img-src 'self' data:; script-src 'self' 'unsafe-eval' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; frame-src 'self' <hosts> https://www.jamovi.org; connect-src 'self' data:`。
- 結論表:

| 內容 | 可否 | 依據 |
|---|---|---|
| inline SVG(`<svg>…</svg>`) | 可 | 無 sanitize;或改用 `Svg` 元素(§2.7) |
| `<img src="data:image/png;base64,…">` | 可 | CSP `img-src 'self' data:` |
| `<img src="https://外部">` | **不可** | CSP `img-src` 不含外部主機 [推論:CSP header 由 server 送出,桌面版 client 同樣經 server 提供] |
| `<style>` / inline `style=` | 可 | `style-src 'unsafe-inline'` |
| `<script>` inline | 可(會執行) | `html.ts`;`script-src 'unsafe-inline'` |
| `fetch()`/XHR 到外部 API(例如從結果面板直接叫 LLM) | **不可** | CSP `connect-src 'self' data:` |
| 外部 `<script src=https://cdn…>` | **不可** | `script-src 'self'`;需打包進模組並用 `setScripts()` |
| 匯出 docx/html | Html 以「verbatim html / formatted text」處理(`client/main/formatio/htmlify.ts:146-147`、`docxify.ts:433`) | [推論] docx 匯出會丟棄 script/CSS 只留文字 |

官方文件 `html.md` 警告 Html「應節制使用」,敘述性文字建議改用新 `Text`。

### 2.6 `Image` 結果元素渲染機制 [已證實]

`jmvcore/R/analysis.R` `.createImage()`(約 430–560 行):
- `renderFun` 指向 `.b.R` 的 private 方法(慣例 `.plot`),呼叫簽章 `render(image, theme=, ggtheme=, ...)`;回傳 `TRUE/FALSE` 或一個可 `print()` 的物件(ggplot2 物件會被 `print()`,`analysis.R:~540`);也可在函式內用 base/grid 直接畫。
- 裝置:`mode: vector` → `grDevices::svg()`(**新增**,`5c488fa` 2026-09-14);否則有 `ragg` 就 `ragg::agg_png()`,否則 `grDevices::png(type=cairo|windows|quartz)`。
- 尺寸:`width/height` × `widthScale/heightScale` 選項,加 `widthB/heightB` 偏移(`image.R:30-67`);`setSize2()` 自 2.7.16。
- `requiresData: TRUE` 時渲染前會重讀資料。

### 2.7 `Text`、`Svg`(新)[已證實]

- **Text**(`jmvcore/R/text.R`;client `text.ts` 用 `richMarkdown()`):純文字段落自動換行,支援 Markdown 子集(粗體、斜體、刪除線、連結、清單、`<sub>/<sup>`);**不支援**標題、引言、程式碼區塊、表格、圖片;HTML entities 不解碼;`*` 需跳脫(`text.md`)。`setContent()` 對非字串會 `capture.output()`。→ 對 askLLM 的 LLM 回答(Markdown)是一個比 Html 更「原生」的容器,但無程式碼區塊,R code tutor 仍需 Preformatted/Html。
- **Svg**(`jmvcore/R/svg.R` 繼承 Html):`setContent(svg 字串)`,可帶 scripts/stylesheets;client 渲染後把 SVG 收割存成 analysis resource(`server/.../analysis.py:392-412`),因此匯出/存檔可保留;engine 端 `saveAs` 直接 `reject`。

### 2.8 `Output` 型別現況 [已證實]

- a.yaml `type: Output` → `OptionOutput`;r.yaml `type: Output`(屬性見 §2.4);R 端 `set(keys,titles,descriptions,measureTypes)`、`setValues()`、`setRowNums()`。
- `measureType` 在 compiler schema 與 jmvcore(`output.R:166-172, 248-254`)**只有 continuous/ordinal/nominal**;dev 文件 `output.md:21` 與教學寫可用 `id` ── **文件與實作不一致,勿用 `id`**(與 dev-notes v1.2 §3.1 結論一致)。
- 2026-06 新增官方教學 `tuts0202a-output-variables.md` 與參考頁 `option-output.md`、`output.md`(含 `set()` 動態多欄)。

### 2.9 Level / Terms / Pairs / Array / Group / Sort / NMXList

皆存在且屬性見 §2.1 表;2025-下半年至今無變更(diff 獨立 repo vs 內嵌版時這些區段無差異)。

### 2.10 `minApp` 欄位的行為 [已證實 + 未確認]

- **編譯期(已證實)**:`index.js:320-330` —— `0000.yaml` 無 `minApp` 時預設 `'1.0.8'`;把 `minApp` 與「編譯所對的 jamovi 版本」(`installer.check(home)` 或 `--assume-app-version`)各轉成 `10000*major+100*minor+patch` 比較,`minApp` 較新就 `throw 'This module requires a newer version of jamovi (minApp: … > …)'`。也就是說 **`minApp: 28.3.0` 的模組無法對 28.2 安裝編譯**,這同時避免了 28.3.1 compiler 產生 `jmvcore::Text$new()` / `OptionFile$new()` 的 `.h.R` 卻跑在只有 jmvcore 2.7.38 的 28.2 上。
- **模組庫(已證實)**:server `modules/modules.py:496-501` 讀庫索引的 `requires: jamovi: ">= x.y.z"` 成 `min_app_version`;client `modules.ts:571` `minAppVersion > this.version` 時把該模組標為 `'old'`,商店顯示「Requires a newer version of jamovi」(`store/pagemodules.ts:363`)。
- **側載 .jmo(未確認)**:`index.js` 未見把 `minApp` 轉寫為 `requires` 的程式碼,server 側載路徑亦未見對 `minApp` 的檢查;推測側載時**不擋**,舊版 jamovi 會在載入分析時因 `jmvcore::Text` 不存在而報錯。需實機驗證。

### 2.11 jamovi 28.2(穩定版)vs 28.3(開發版)模組能力差異表

判定依據:jmvtools 28.2(`a67db51`,2026-07-13)與 28.3(`b0bbefb`,2026-07-15)內嵌的 compiler schema **皆無** `File`/`Text`/`Svg`/`mode`;28.3.1(`ee9488d`)才有;jmvcore 2.7.38(2026-07-18)vs 28.3(2026-09-24)。jamovi 28.2 桌面版 = 2026-08-13 釋出、jmvcore 2.7.38;28.3 = monorepo `main`(`version` 28.3.0.0,2026-09-18)+ jamovi Cloud。

| 能力 | jamovi 28.2 穩定版(jmvtools 28.2/28.3、jmvcore 2.7.38) | jamovi 28.3 開發版(jmvtools 28.3.1、jmvcore 28.3) | 來源 |
|---|---|---|---|
| a.yaml `type: File` + u.yaml `FileSelector` | ✗ | ✓(`multiple`, `extensions`;檔案存入 .omv) | §2.2, §1.5 |
| r.yaml `type: Text`(Markdown 段落) | ✗ | ✓ | §2.7 |
| r.yaml `type: Svg` | ✗ | ✓ | §2.7 |
| `Image` `mode: vector`(SVG 輸出)、`widthB/heightB` | ✗ mode;`widthB/heightB`、`setSize2()` 自 2.7.16 已有 | ✓ | §2.6;`5c488fa` |
| `Action` 選項 + `ActionButton`(`action: open`) | ✓(自 2.7.12,2025-11) | ✓ | §2.3 |
| `OptionAction` `action='openExternal'`(交給 OS 開檔/下載) | ✗ | ✓ jmvcore/server/electron;compiler schema enum 尚未列 | `02aeb48` |
| `Html` / `Preformatted` / `Notice` / `Output` / `State` | ✓ | ✓(無變更) | §2.4, §2.5, §2.8 |
| `category: plots`、`weightsSupport` | ✓(2025-05 起) | ✓ | §2.1 |
| 結果匯出 .docx / .odt;`htmlify` 重寫;Text/Html 匯出以 verbatim html 處理 | ✗ .docx/.odt(28.2 有 html/pdf/LaTeX 等既有匯出) | ✓(`b9f2444` 09-19、`41ce522` 09-23) | §1.5 |
| 從執行中的 Docker 容器安裝(`--home docker:`) | ✗ | ✓(jmvtools 28.3.1) | §1.3 |
| jmvcore `knit_print` S3、表格數字格式同 jamovi | ✗ | ✓ | §5 |
| Engine 檔案系統/網路限制、`self$data` attributes、`.omv` 路徑不可得 | 相同 | 相同 | §4 |
| u.yaml 其餘 widget、JS events、CSP | 相同 | 相同 | §3 |

**對 askLLM 的直接後果**:目前 `DESCRIPTION` `Imports: jmvcore (>= 0.8.5)`、`0000.yaml` `minApp: 1.0.8` 在兩邊都能裝(見 §5「相容性」)。若採用 File/Text/Svg,必須 (1) 用 jmvtools **28.3.1** 編譯、(2) `minApp: 28.3.0`、(3) 放棄 28.2 使用者或維持兩條分支;若只採用 `Action` 按鈕,28.2 即可。

---

## 3. u.yaml(jus 3.0)可用 widget 與事件

### 3.1 控制項完整清單 [已證實]

`uictrlschemas.yaml:1-31`(`ControlBase.type` enum):`CheckBox, RadioButton, ComboBox, TextBox, ListBox, VariablesListBox, TargetLayoutBox, Supplier, VariableSupplier, CollapseBox, Label, LayoutBox, VariableLabel, TermLabel, RMAnovaFactorsBox, LevelSelector, Output, CustomControl, ModeSelector, Content, ActionButton, FileSelector`,另允許 `"./xxx"` 自訂路徑。(`uischema.yaml` 是舊版清單,含 `ListItem.*`,已不再使用。)

### 3.2 逐項確認

| 問題 | 答案 | 依據 |
|---|---|---|
| 有無 Button? | **有:`ActionButton`**,綁 `Action` 選項 | §2.3;`gridactionbutton.ts` 為 `<button>` |
| 有無 multiline TextBox? | **無**。`TextBox` 是 `<input type="text">`(`client/analysisui/gridtextbox.ts:197`);schema 屬性只有 `format, suffix, alignText, borderless, width(small…largest), suggestedValues`(`uictrlschemas.yaml:~330-372`)+ 文件的 `inputPattern` | [已證實] |
| multiline 的替代方案 | `CustomControl` + `creating` 事件在 `ui.<name>.$el` 放 `<textarea>`,寫回 `hidden: true` 的 String 選項(`ui.question.setValue()`) | [推論] 依 `advanced-customisation.md`「Adding a custom control」「Options UI from scratch」章節,官方支援的做法 |
| ComboBox 可否由 JS 動態填選項? | **UI 層可以**:`gridcombobox.ts:40` 把 `options` 註冊為 property,`onPropertyChanged('options')` 會 `updateOptionsList()`;JS 可 `ui.provider.setPropertyValue('options', [{name,title},…])`(`propertysupplier.ts:114`) | [推論] 但 a.yaml `List` 的值仍由 jmvcore `OptionList` 依宣告的 options 檢查,不在清單內的值會被 reject → 動態選項只適合「子集」;若要真動態(例如 Ollama 模型列表),應改 `String` + `TextBox suggestedValues`(schema 支援 `suggestedValues[]`,可由 JS 設 property)[未確認實機] |
| events 可做什麼? | view:`creating, loaded, updated, remoteDataChanged`(`uischema.yaml:23-33`);所有 OptionControl:`changing, changed`(舊名 `change`);ListBox:`listItemAdded/Removed`;Supplier:`updated`;CustomControl:`creating, updated`。handler `(ui, event)`;`ui.<opt>.value()/setValue()`;`ui.view.model.options.beginEdit()/endEdit()` 批次;DOM:`ui.view.el/$el`、`ui.<ctrl>.el`;內部 `requestData('columns'|'column')` 可讀資料集欄位中繼資料(名稱、measureType、levels 等)(`client/analysisui/main.ts:80-115`) | [已證實] `advanced-customisation.md`、`actions.ts`、`main.ts` |
| JS 能否讀檔案系統 / 跳檔案對話框? | **不能直接**。選項 UI 跑在 iframe(`analysisui.html`),無 Node/FS;檔案對話框只有 `FileSelector` 走 `requestAction('selectFiles')`(`main.ts:99-101` 的 type 也只有 `'createColumn' | 'selectFiles'`)。CustomControl 理論上可呼叫同一內部 `requestAction('selectFiles')`,但非公開 API | [已證實 + 推論] |
| JS 能否直接打外部 HTTP(例如叫 LLM)? | **不能**:CSP `connect-src 'self' data:`(`server.py:906`) | [已證實] |

---

## 4. Engine 層 R 行程的檔案系統存取與可得中繼資料

### 4.1 有沒有沙箱?[已證實]

- Engine 是 C++ + RInside(`jamovi/engine/engine/*.cpp`)。**原始碼中沒有 chroot/seccomp/AppContainer/路徑白名單**(grep `sandbox|seccomp|chroot|unshare` 於 `engine/`、`server/` 只命中一則註解)。
- 唯二的限制:
  1. R 函式鎖定(`enginer.cpp:~497-517`):永遠鎖 `utils::install.packages/update.packages/download.packages/remove.packages`;**僅當 `JAMOVI_EXTRA_LOCKDOWN=1`**(cloud 用)才再鎖 `base::source/library/system/system2/shell/shell.exec/download.file/url`。桌面 `platform/env.conf`、`ubuntu.conf` 皆無此變數。
  2. Linux 上若設定 `memory_limit_session` 才有 `RLIMIT_AS`(`server/jamovi/server/__main__.py:25-35`)。
- **`JAMOVI_NETWORK_SANDBOX=1` 與 R engine 無關**:它只在 `electron/app/main.js:215-245`,用途是為 Electron 的 Chromium **network service** 開啟 `NetworkServiceSandbox`,以避免 Windows 讀取 Wi-Fi SSID 觸發定位權限提示;只在 MSIX 與 NSIS 安裝版打開(portable zip 不開)。**因此 dev-notes v1.2 §3.2 把它解讀為「引擎收緊網路」是誤讀**;askLLM 的 ellmer HTTP 能正常運作也證明 engine 網路未受限。
- **結論**:桌面版模組在 engine 內可讀寫**使用者帳號權限可及的任意路徑**(`~/askLLM/prompts/*.md`、`C:/Users/.../codebook.csv`),用一般 R I/O 即可 [推論,基於無沙箱程式碼;未實機測試]。Cloud 版則另有 `JAMOVI_EXTRA_LOCKDOWN`,且使用者檔案只能經 `File` 選項上傳進 session。
- [未確認] Windows MSIX(Store)版是否有 AppContainer 檔案系統虛擬化影響 engine 讀取使用者目錄。

### 4.2 能否知道目前 .omv 的路徑?**不能** [已證實]

- Engine 收到的 `AnalysisRequest`(`jmvcore/inst/jamovi.proto:31-63`)欄位:`sessionId, instanceId, analysisId, name, ns, perform, options, changed, revision, restartEngines, clearState, addons, index, path/part/format(僅供存圖/存部件請求), i18n, arbitraryCode, enabled, maxDurationSeconds`。沒有資料集檔名/路徑/標題。
- 資料本身從共享記憶體 buffer `<enginePath>/<sessionId>/<instanceId>/buffer` 讀入(`engine/engine/enginer.cpp:176, 365`)。
- 可得的唯一路徑是 **session temp**:`analysis$.getSessionTemp()`(`analysis.R:598-602`,註解自稱 hack)= `<engine path>/<sessionId>/temp`,對應 server `session.py:74` 的 `session_path/temp`;server 可以 `{{SessionTemp}}/…` 形式提供其中檔案(`instance.py:170-172, 1037-1050`)。適合放暫存,不適合持久化。

### 4.3 `self$data` 上可得的 attributes [已證實,`engine/engine/readdf.cpp`]

| attribute | 層級 | 行 | 內容 |
|---|---|---|---|
| `jmv-desc` | 每欄 | 121, 139, 160, 180, 279 | 變數 Description(空字串時為 NULL)— askLLM 現行「變數 Description 當 system prompt」即靠此 |
| `jmv-id` | 每欄 | 158, 179, 274 | measureType 為 ID 時 `TRUE` |
| `jmv-retain-unused` | 每欄(factor) | 268 | 未 trim levels 時 `TRUE` |
| `jmv-missings` | 每欄 | 277 | 僅 Data 選項 `requiresMissings: true` 時附上 missing 值定義 |
| `values` | 每欄(integer factor) | 271 | level 對應的整數值 |
| `levels` / `class` | 每欄 | 260-266 | factor;ordinal → `c("ordered","factor")` |
| `jmv-weights-name` | data.frame | 299 | 權重欄名 |
| `jmv-weights` | data.frame | 322, 339 | 權重向量;jmvcore `weights.R`、`analysis.R:215-233` |

- measureType 不直接附上,但可推:numeric → continuous;`ordered` factor → ordinal;plain factor → nominal;`jmv-id` → ID。
- `readDataset(headerOnly)` 只讀 `self$options$varsRequired` 的欄(`analysis.R:603-611`);未被任何選項引用的欄位拿不到。Filter 欄不會傳入(`readdf.cpp:106-108`)。

---

## 5. jmvcore 28.3(2026-09-24)新增 API

`jamovi/jmvcore/NAMESPACE` exports:`Action, Analysis, Array, Column, Group, Html, Image, Notice, NoticeType, OptionAction, OptionArray, OptionBool, **OptionFile**, OptionGroup, OptionInteger, OptionLevel, OptionList, OptionNMXList, OptionNumber, OptionOutput, OptionPair, OptionPairs, OptionSort, OptionString, OptionTerm, OptionTerms, OptionVariable, OptionVariables, Options, Output, Preformatted, State, **Svg**, Table, **Text**` + 工具函式;新增 S3 `knitr::knit_print` for `Analysis`/`ResultsElement`。

2025-09 至今 jmvcore 相關 commit(monorepo `git log -- jmvcore`,depth 50 內):

| commit | 日期 | 內容 |
|---|---|---|
| `c2b837d` | 09-13 | Svg 結果元素 |
| `5c488fa` | 09-14 | Image `mode = vector` |
| `e83a9bc` | 09-15 | OptionFile |
| `a44312c` | 09-16 | Text 結果元素 |
| `6acb8e2` | 09-17 | OptionFile 檔案存進 .omv |
| `02aeb48` | 09-19 | OptionAction `openExternal` |
| `e0033df` 等 | 09-23 | 表格數字格式化與 jamovi 一致、`knit_print`、roxygen 8、i18n regex 修正 |
| `68caf31` | 09-24 | Version 28.3 |

其他你點名的 API 現況:
- **Notice**(`notice.R`):`NoticeType$ERROR/STRONG_WARNING/WARNING/INFO`;方法 `set(type, content)`、`setContent(content)`;**沒有 `setType()`**(dev 文件 `notice.md:43` 寫 `setType`,與程式碼不符)。
- **Html**:見 §2.5;另有 `knit()`。
- **Output**:見 §2.8。
- **setState / state**:`ResultsElement$setState(obj)` / `$state`,受 `clearWith` 控制(`tuts0203-state.md:117-131`)。
- **`.checkpoint(flush=TRUE)`**:Analysis private 方法(`analysis.R:58-70`),把目前結果送回 client 讓使用者看到中途進度;`run()` 在 addon 間自動呼叫(`analysis.R:329-333`)。askLLM 可在「送出前先顯示『呼叫中…』」時用 `private$.checkpoint()`。
- **requiresData**:Options 層 active(`options.R:18-27`,預設 TRUE;無任何 Variable(s) 選項時為 FALSE)與 Image/元素層 `requiresData`。
- **weightsSupport**:`'auto'|'integerOnly'|'full'|'none'`(`analysisschema.yaml:41-46`;`analysis.R:220-233` 決定 `weightsStatus`,並自動在 results 前插入 `.weights` Notice);官方教學 `tuts0202b-weighted-data.md`(2026-06-11)。
- 中繼資料讀取:只有 §4.3 的 attributes;jmvcore 無「讀取所有欄位中繼資料」的公開 API。
- [未確認] CRAN 上 jmvcore 的版本(CRAN 被擋);jmv 2.8.0 要求 `jmvcore (>= 2.4.2)`,jmvtools 要求 `>= 2.3.4`。

**與 askLLM `DESCRIPTION` `Imports: jmvcore (>= 0.8.5)` 的相容性** [已證實 + 推論]
- `.jmo` 不打包 jmvcore;engine 用 jamovi 隨附的 jmvcore(`R_LIBS=…/modules/base/R`,`enginer.cpp:291-300`)。28.2 → jmvcore 2.7.38,28.3 → 28.3;兩者都滿足 `>= 0.8.5`(R 的 `package_version` 比較:`28.3 > 2.7.38 > 0.8.5`),**現行 askLLM 在 28.2 與 28.3 都可載入**。
- 產生的 `.h.R` 只在 `requireNamespace("jmvcore")` 成立時定義類別(`header.template:4-46`),沒有版本檢查;真正的相容性由所用的 API 決定:只要不用 `Text`/`Svg`/`OptionFile`/`openExternal`,28.3.1 compiler 產出的程式碼在 2.7.38 上仍可跑(`Html`/`Preformatted`/`OptionAction` 等 API 未變)。
- 若採用新 API:建議把 `Imports` 改為 `jmvcore (>= 28.3)` 並設 `minApp: 28.3.0`(官方測試模組 `filetest` 用 `jmvcore (>= 2.0)` + `minApp: 1.0.8`,是玩具模組沒改;文件要求 28.3.0)。注意 `jmvcore (>= 28.3)` 在 R 語意上也排除了 2.7.x,與 jmvcore 跳號一致。
- [推論] compilerr.js 打包相依時會跳過 jmvcore(base 套件),不會把它塞進 `.jmo`;askLLM dev-notes 已提醒「勿在 Imports 加 jmv」,jmvcore 同理由 jamovi 提供。

---

## 6. dev.jamovi.org 2026 年新內容 [已證實,來自 `devdocs/` git log]

- 2026-04/05:整站以 Astro 重建(Ravi Selker),新增 `CLAUDE.md`/`AI.md` 與 `.claude/agents/`(**這是文件維護者用 Claude Code 寫文件的鷹架,不是給模組的 AI 功能**)。
- 新教學/章節(依日期):
  - 05-19 `tuts0304-plot-modules.md`(`category: plots`,Plots 分頁)
  - 05-28 `tuts0110-module-datasets.md`(模組附範例資料集)
  - 06-04/05 `tuts0202a-output-variables.md`(原 Computed Columns)、`reference/api/option-output.md`、`output.md`(含 `set()`)
  - 06-11 `tuts0202b-weighted-data.md`(`weightsSupport`)
  - 07-29 模組投稿:命名規範、範例資料集、審查時程
  - 09-14 `reference/api/option-file.md`(File 選項;「需 28.3」)
  - 09-17 `reference/api/text.md`(Text 元素;「需 28.3」)
- `resources/misc/updates.md`:2025-11-11「2.7.12 新 analysis action system」、2025-12-31「2.7.16 image sizing」。
- **沒有** AI / MCP / skills 相關章節或教學;`Html` 頁只是參考頁(建議節制使用)。
- 已知文件缺口:`reference/api/results-elements.md` 表格尚未列 Svg;`ui-definition.md` 仍寫 `jus: '2.0'` 為典型值(JS 事件需 3.0);`notice.md` 的 `setType` 不存在;`output.md` 的 `id` measureType 不被實作接受。

---

## 7. 三分表:對 askLLM 擴充方向的判定

### 可行(有原始碼/文件證據)

| 方向 | 機制 | 條件 |
|---|---|---|
| 讓使用者用檔案對話框選 prompt/codebook 檔 | a.yaml `type: File`(+ `extensions`, `multiple`),R 讀 `self$options$x$path` | **jamovi ≥ 28.3、jmvtools 28.3.1、`minApp: 28.3.0`** |
| 真正的「送出」按鈕 | a.yaml `type: Action`(`action: open` 佔位)→ u.yaml `ActionButton`;R 只讀 `self$options$submit`;server 執行後自動歸零 | jamovi ≥ 2.7.12;結果元素保持 `clearWith: []`;需實機驗證不呼叫 `perform()` 的行為 |
| 直接讀使用者本機任意路徑(桌面版) | 一般 R I/O;engine 無 FS 沙箱 | 路徑需使用者自己輸入(String 選項)或用 File 選項;cloud 版不適用 |
| Markdown 回答用原生段落元素 | r.yaml `type: Text`(Markdown 子集) | jamovi ≥ 28.3;無程式碼區塊,R code tutor 仍需 Preformatted/Html |
| Html 內嵌 inline SVG、`data:` 圖片、內嵌 CSS、內嵌 JS | 無 sanitize + CSP 允許 | 外部資源與外部 fetch 不行 |
| 圖表 | `Image` + `.plot`(ggplot2 或任何可 print 物件),`mode: vector` 得 SVG;或 `Svg` 元素直接給 SVG 字串 | vector/Svg 需 28.3 |
| 由 R 產生檔案交給 OS 開啟或下載(例如把回答存成 .md/.docx) | `OptionAction` `action='openExternal'` | jamovi ≥ 28.3;compiler schema enum 尚未含 `openExternal`(需繞或等更新) |
| 中途回報進度 | `private$.checkpoint()` | 已存在 |
| 讀變數 Description/ID/ordinal/weights 中繼資料 | `attr(col,'jmv-desc')`、`'jmv-id'`、`ordered` class、`jmv-weights*` | 已在用 |
| UI 依 provider 動態調整 | JS events(`changed`)`setValue`/`setPropertyValue('options'…)`/`enable` 綁定 | 動態 List 值仍受 a.yaml 宣告限制 |

### 不可行(有反證)

| 方向 | 原因 |
|---|---|
| 多行輸入的原生 TextBox | `TextBox` 是 `<input type=text>`;無 multiline 屬性(替代:CustomControl + `<textarea>`) |
| 知道目前開啟的 .omv 路徑/檔名 | `AnalysisRequest` 無此欄位;資料來自共享記憶體 buffer |
| 從選項 UI(JS)或結果面板(Html script)直接呼叫外部 API | CSP `connect-src 'self'`;選項 UI 無 FS/Node |
| Html 內載入外部 `<img src=https://>`、外部 `<script src>` | CSP `img-src 'self' data:`、`script-src 'self'` |
| Output 欄位 measureType `id` | compiler schema 與 jmvcore 僅 nominal/ordinal/continuous |
| 讀取未被選項引用的欄位 | `readDataset` 只給 `varsRequired` |
| 靠 `JAMOVI_NETWORK_SANDBOX` 判斷 engine 網路政策 | 該變數只影響 Electron 網路服務沙箱,與 R engine 無關 |

### 未確認

| 項目 | 缺什麼 |
|---|---|
| jamovi 桌面版 28.3 GA 日期(28.3.0 已在 Cloud;monorepo version=28.3.0.0) | jamovi.org 被擋;GitHub Releases 未列 28.x |
| 側載 .jmo 時 jamovi 是否檢查 `minApp`(編譯期檢查已證實) | server 側載路徑未見檢查碼;需實機 |
| `type: Notice` 於 r.yaml 是否過 schema(schema 寫 `Notification`) | 需實際 `jmvtools::prepare()` 驗證 |
| a.yaml `action: openExternal` 何時進 compiler schema | 目前 enum 只有 `open` |
| 不呼叫 `perform()` 的 `Action` 按鈕在 UI/clearWith 上的實際行為 | 需實機 |
| ComboBox 動態 options 與 jmvcore `OptionList` 值檢查的互動;`TextBox.suggestedValues` 可否由 JS 動態設 | 需實機 |
| Windows MSIX 版 engine 的檔案系統可見性 | 無原始碼線索 |
| CRAN jmvcore 版本、`jamovi/jmvcore` GitHub repo 是否已封存 | 網路被擋/未授權 |

---

## 8. 對 askLLM 的具體建議(摘要)

1. **短期(維持 28.2 相容)**:把 `submit` 改為 `Action` + `ActionButton`,解決「勾選→取消→再勾選」的 UX;R 端邏輯不變(不呼叫 `perform`)。先實機驗證。
2. **中期(要求 28.3:jmvtools 28.3.1 編譯、`minApp: 28.3.0`、`Imports: jmvcore (>= 28.3)`)**:新增 `File` 選項讓使用者載入 prompt 範本 / codebook,檔案隨 .omv 保存(範本:`jonathon-love/filetest`);回答改用 `Text`(敘述)+ `Preformatted`(程式碼)混排;R code tutor 可用 `openExternal` 匯出 `.R` 檔給使用者開啟。28.2 vs 28.3 差異見 §2.11。
3. **文件修正**:dev-notes 中「`JAMOVI_NETWORK_SANDBOX=1` 顯示引擎方向是收緊」的敘述應更正為「該變數只關 Electron 網路服務沙箱」;引用 jmvcore/compiler 時改指向 monorepo `jamovi/jamovi`。
4. **不要做**:在 Html 裡嵌 JS 直接呼叫 LLM(CSP 擋)、依賴 .omv 路徑、Output 用 `id`。

---

## 附錄:主要檔案索引(相對於 `scratchpad/`)

- `jmvtools/DESCRIPTION`, `jmvtools/R/main.R`, `jmvtools/justfile`, `jmvtools/README.md`
- `jmvtools/inst/node_modules/jamovi-compiler/{index.js, compiler.js, uicompiler.js, docker.js, snapshots.js, header.template}`
- `jmvtools/inst/node_modules/jamovi-compiler/schemas/{analysisschema, optionschemas, resultelementschemas, resultsschema, uictrlschemas, uischema}.yaml`
- `jamovi/jmvcore/R/{analysis.R, options.R, html.R, text.R, svg.R, image.R, notice.R, output.R, action.R, state.R}`, `jamovi/jmvcore/inst/jamovi.proto`, `jamovi/jmvcore/NAMESPACE`
- `jamovi/engine/engine/{readdf.cpp, enginer.cpp}`
- `jamovi/server/jamovi/server/{server.py, sessionfiles.py, uploads.py, options.py, session.py, instance.py, __main__.py, analyses/analysis.py, analyses/analyses.py}`
- `jamovi/client/resultsview/{html.ts, svg.ts, text.ts}`, `jamovi/client/analysisui/{gridtextbox.ts, gridcombobox.ts, gridactionbutton.ts, fileselector.ts, main.ts}`, `jamovi/client/main/{resultspanel.ts, optionspanel.ts}`, `jamovi/client/common/htmlelementcreator.ts`
- `jamovi/electron/app/main.js`, `jamovi/platform/env.conf`, `jamovi/version`, `jamovi/docker-compose.yaml`
- `devdocs/src/content/docs/reference/api/{option-file, option-action, text, html, notice, output, results-elements, analysis-definition, ui-definition}.md`, `devdocs/src/content/docs/learn/ui/advanced-customisation.md`, `devdocs/src/content/docs/resources/misc/updates.md`
- `filetest/{DESCRIPTION, jamovi/0000.yaml, jamovi/showfile.a.yaml, jamovi/showfile.u.yaml, jamovi/showfile.r.yaml, R/showfile.b.R}`(github.com/jonathon-love/filetest)
- GitHub PR 頁(WebFetch):`jamovi/jamovi#1862`(Added OptionFile,2026-09-15)、`#1795`(sjentsch,htmlify 改進,2026-09-22)
- `/home/user/askLLM/DESCRIPTION`(`jmvcore (>= 0.8.5)`)、`/home/user/askLLM/jamovi/0000.yaml`(`minApp: 1.0.8`)
- 網路來源(搜尋摘要,未直接讀取):jamovi 28.2.0 釋出 2026-08-13(Wikipedia);28.3.0 於 jamovi Cloud;GitHub Releases 頁最新 2.7.30。
