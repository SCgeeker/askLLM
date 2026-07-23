# S5b live 驗證:模組路徑命中率 v1.0 vs v1.1 / Module-path hit rate, v1.0 vs v1.1

規格依據 / Spec ref:`specs/v1.1-module-aware.zh-TW.md` §6 S5b。

執行日期 / Run date:2026-07-23。實跑腳本:`tools/compare-models.R`
(`compare_models(..., with_catalog = TRUE/FALSE, scan_dirs = c(<APPDATA>/jamovi/modules,
"C:/Program Files/jamovi 2.7.37.0/Resources/modules"))`)。逐次呼叫報告存於
`dev-notes/s5b-raw/*.md`(未 commit,供覆核用)。

## 方法 / Method

- **題目集 / questions**(取自 `docs/LIMITATIONS.zh-TW.md` 曾出錯的兩題):
  1. iris:「建議這份資料集可做的統計分析?請指出 jamovi 選單路徑」
  2. mtcars(`mpg, hp, wt, cyl` 4 變項):「這份資料適合哪些迴歸分析?請指出選單路徑」
- **模型 / models**:`openai/gpt-4o-mini`(provider `github`)、`gemini-flash-latest`
  (provider `gemini`)。
- **版本 / versions**:v1.0(`with_catalog = FALSE`,不附選單樹)vs v1.1
  (`with_catalog = TRUE`,附本機實掃選單樹 + available 清單,`.askllm_system_prompt(TRUE)`)。
- 2 題 × 2 模型 × 2 版本 = **8 次呼叫**,間隔 5 秒。
- **合法路徑集合**:以 `scan_modules(dirs = c(使用者 %APPDATA%\jamovi\modules,
  jamovi 主程式安裝目錄下的 Resources\modules))` 實際掃描本機取得(共 56 條,
  含 `jmv` 內建 26 條 + 8 個外掛模組)。之所以要手動指定 `scan_dirs`,是因為
  本測試在 jamovi engine 之外以 `Rscript` 執行,`default_module_dirs()` 的
  自我定位/`.libPaths()` 訊號偵測不到隨 jamovi 主程式安裝的 `jmv` 本身,只
  掃得到 `%APPDATA%\jamovi\modules` 下使用者自裝的模組;在真實 jamovi
  engine 內執行時,`jmv` 會經由該訊號自動納入,不需手動指定。
- **命中判定**:`tools/compare-models.R` 新增的 `.askllm_extract_paths()` 從
  回覆逐行抽取 `Analyses > ...` 片段(在粗體/code 結束符、` - `/` — ` 分隔、
  冒號等邊界處截斷,去尾端標點後壓縮空白),`.askllm_check_path_hits()` 與
  合法路徑集合逐字比對。

## 結果表 / Results table

| 題目 question | 模型 model | 版本 version | 提取路徑數 extracted | 命中數 hits | 命中率 hit rate | 備註 notes |
|---|---|---|---|---|---|---|
| iris | gpt-4o-mini | v1.0 | 0 | 0 | n/a | 回覆用 `→`/backtick,無 `Analyses > ` 前綴,無法機械核對(見下方質性觀察) |
| iris | gpt-4o-mini | v1.1 | 3 | 3 | 100% | — |
| iris | gemini-flash-latest | v1.0 | 0 | 0 | n/a | 同上,格式不一致 |
| iris | gemini-flash-latest | v1.1 | 8 | 8 | 100% | — |
| mtcars | gpt-4o-mini | v1.0 | 0 | 0 | n/a | 完全通用化選單(「分析 → 迴歸 → 線性」),非 jamovi 實際措辭 |
| mtcars | gpt-4o-mini | v1.1 | 3 | 3 | 100% | — |
| mtcars | gemini-flash-latest | v1.0 | 0 | 0 | n/a | 附 SPSS 選單對照,jamovi 段用 `➔` 無 `Analyses` 前綴 |
| mtcars | gemini-flash-latest | v1.1 | 4 | 4 | 100% | — |

**總計 / totals**

| 版本 version | 提取路徑數 total extracted | 命中數 total hits | 命中率 hit rate |
|---|---|---|---|
| v1.0 | 0 | 0 | n/a(0/0,見下方說明) |
| v1.1 | 18 | 18 | **100%**(18/18) |

## v1.1 是否仍有 miss?/ Any v1.1 misses?

**沒有** — 本次 8 組呼叫中,v1.1 提取到的 18 條路徑全數逐字命中掃描清單,
無 `misses`。原因可歸因於 §4.3.3 system prompt 明確指示「cite each menu
path exactly as written」,加上 user prompt 指令段要求「quote each menu
path EXACTLY as written there」——兩個模型在本樣本中都確實遵守。樣本數小
(8 次呼叫、18 條路徑),不足以宣稱零 miss 是穩定保證,但方向與規格預期一致。

## 為何 v1.0 命中率是「0/0」而非「0/N」?/ Why v1.0 is "0/0" not "0/N"?

`.askllm_extract_paths()` 是嚴格比照 v1.1 的輸出格式設計的
(`Analyses > 選單群組 > ... > 選單標題`,亦即 v1.1 prompt 明確要求模型
「exactly as written」引用的格式)。v1.0 prompt 完全沒有這類格式指令,兩個
模型在 8 次回覆中沒有一次自發採用 `Analyses > ...` 這種寫法,而是各自用
`→`、`➔`、反引號包裹的自然語言描述(如 `` `Regression` ➔ `Linear
Regression` ``、「選擇『分析』→『迴歸』→『線性』」)。這代表:

1. **v1.0 的選單路徑不是機械可核對的** ——沒有一致格式,無法程式化比對,
   使用者只能自己逐條核對(這正是 `docs/LIMITATIONS.zh-TW.md` 既有結論)。
2. 人工核對本次 8 則回覆,質性觀察如下(詳見 `dev-notes/s5b-raw/*.md`):
   - **iris / gpt-4o-mini(v1.0)**:5 條建議中 4 條的「群組 > 標題」實際
     存在(`Exploration > Descriptives`、`ANOVA > One-Way ANOVA`、
     `Regression > Correlation Matrix`、`Regression > Linear Regression`,
     大小寫或字面小差異),但第 1 條「`Descriptives` → `Descriptive
     Statistics`」中的「Descriptive Statistics」是虛構子選單(真實只有
     `Descriptives` 本身,無此子項)。
   - **iris / gemini(v1.0)**:5 條中 3 條群組/標題正確
     (`Exploration>Descriptives`、`ANOVA>One-Way ANOVA`、
     `Regression>Correlation Matrix`);第 4 條「`Regression` ➔
     `Multinomial Logistic Regression`」把真實的三層結構
     (`Regression > Logistic Regression > N Outcomes`)壓扁、改名成不存在
     的單一選單項;第 5 條「`Factor` ➔ `Principal Component Analysis`」
     漏了中間層 `Data Reduction`。
   - **mtcars / gpt-4o-mini(v1.0)**:**完全虛構**——用「分析 → 迴歸 →
     線性」這種通用統計軟體式選單(類 SPSS 措辭),與 jamovi 實際英文選單
     (`Regression > Linear Regression`)完全對不上,是本次樣本中最嚴重的
     幻覺案例。
   - **mtcars / gemini(v1.0)**:額外附上一段 SPSS 選單對照(非 jamovi,
     題目未問),jamovi 段本身路徑正確但格式為 `` `Analyses` ➔
     `Regression` ➔ `Linear...` `` 這種零散寫法,非可直接比對字串。

   → 概略估計(人工判讀,非程式化):v1.0 兩模型的「群組 > 標題」語意正確率
   約 7/10(iris 兩則各 4/5、3/5 條語意正確;mtcars 兩則各 0/1、1/1),但
   **格式上沒有一條符合可機械核對的 `Analyses > ...` 逐字標準**,且至少
   3 條屬於結構性虛構(虛構子選單、壓扁多層結構、通用化改寫)。

3. **v1.1 的貢獻正在於「格式 + 內容」雙重約束**:不只要求路徑存在
   (內容正確),還要求逐字引用 catalog 文字(格式可核對)。本次結果顯示
   兩者在小樣本下都達成了。

## compare-models.R 介面變更摘要 / Interface changes

- 新增參數:
  - `with_catalog = FALSE`:`TRUE` 時以 `pkgload::load_all()` 或已安裝套件
    載入的 `scan_modules()` + `catalog_text()` + `available_text()`
    (讀 `inst/catalog/known-modules.yaml`)組出 `catalog_text`/
    `available_text`,連同 `.askllm_system_prompt(TRUE)` 一併傳給
    `ask_llm()`;`FALSE` 時維持 v1.0 既有呼叫路徑(逐位元組不變)。
  - `known_path = NULL`:覆寫 `known-modules.yaml` 路徑(供測試/非安裝情境注入)。
  - `check_paths = TRUE`:不論 `with_catalog` 為何,只要能取得本機掃描結果
    就計算「合法選單路徑集合」並在報告中加入命中率欄位;無法掃描
    (如找不到任何模組)時靜默略過,報告退回無命中率欄位的舊格式。
  - `scan_dirs = NULL`:覆寫 `scan_modules()` 掃描目錄(預設交給
    `default_module_dirs()` 自動偵測;見上方「合法路徑集合」段落說明何時
    需要手動指定)。
- 新增內部 helper(不匯出、只服務本工具腳本):
  - `.askllm_legal_paths(scanned)`:把 `scan_modules()` 結果轉成
    `Analyses > ...` 格式的合法路徑字元向量(格式比照
    `R/module-catalog.R` 的 `.catalog_analysis_line()`,不含 menuSubtitle
    後綴)。
  - `.askllm_extract_paths(text)`:從回覆文字逐行抽取 `Analyses > ...`
    片段,在粗體/code 結束符、` - `/` — ` 分隔、冒號等邊界處截斷後去尾端
    標點、壓縮空白。
  - `.askllm_check_path_hits(text, legal_paths)`:回
    `list(total, hits, misses)`。
- 報告格式:`with_catalog = TRUE` 時額外輸出「送出的 catalog 文字」「送出
  的 available 文字」區塊;有合法路徑可核對時,摘要表與各模型回覆段落都
  加入提取路徑數/命中數/命中率(或未命中清單)。
- 向下相容:所有新參數皆有預設值,既有呼叫(不帶新參數、`with_catalog`
  預設 `FALSE`)行為不變;`tools/compare-models.R` 不隨套件安裝、無
  testthat 涵蓋,故本次變更不影響套件既有測試套件(520 案例)。

---

# S5b Live Validation: Module-Path Hit Rate, v1.0 vs v1.1 (English)

Spec ref: `specs/v1.1-module-aware.zh-TW.md` §6 S5b.

Run date: 2026-07-23. Driven by `tools/compare-models.R`
(`compare_models(..., with_catalog = TRUE/FALSE, scan_dirs = c(<APPDATA>/jamovi/modules,
"C:/Program Files/jamovi 2.7.37.0/Resources/modules"))`). Per-call reports live in
`dev-notes/s5b-raw/*.md` (not committed, kept for review).

## Method

- **Questions** (the two that previously produced errors per
  `docs/LIMITATIONS.zh-TW.md`):
  1. iris: "What analyses suit this dataset? Point out the jamovi menu paths."
  2. mtcars (`mpg, hp, wt, cyl`): "Which regression analyses suit this data? Point out the menu paths."
- **Models**: `openai/gpt-4o-mini` (provider `github`), `gemini-flash-latest`
  (provider `gemini`).
- **Versions**: v1.0 (`with_catalog = FALSE`, no menu tree attached) vs v1.1
  (`with_catalog = TRUE`, real locally-scanned menu tree + available-modules
  list attached, `.askllm_system_prompt(TRUE)`).
- 2 questions × 2 models × 2 versions = **8 calls**, 5s apart.
- **Legal path set**: obtained by actually scanning the machine with
  `scan_modules(dirs = c(user's %APPDATA%\jamovi\modules, the jamovi
  application's own Resources\modules))` — 56 paths total (26 from the
  bundled `jmv` module + 8 add-on modules). `scan_dirs` had to be given
  explicitly because this test ran via plain `Rscript` outside the jamovi
  engine, so `default_module_dirs()`'s self-location/`.libPaths()` signals
  could not see `jmv` (bundled with the jamovi app itself) — only the
  user-installed add-ons under `%APPDATA%\jamovi\modules` were found
  automatically. Inside the real jamovi engine, `jmv` would be picked up by
  that signal without manual overrides.
- **Hit test**: the new `.askllm_extract_paths()` in `tools/compare-models.R`
  pulls `Analyses > ...` fragments line by line (cutting at boundaries such
  as closing bold/code markers, ` - `/` — ` separators, or a colon, then
  trimming trailing punctuation and collapsing whitespace);
  `.askllm_check_path_hits()` compares them verbatim against the legal path set.

## Results table

(See the Chinese table above — identical numbers, columns: question / model / version / extracted / hits / hit rate / notes.)

**Totals**

| version | total extracted | total hits | hit rate |
|---|---|---|---|
| v1.0 | 0 | 0 | n/a (0/0, see below) |
| v1.1 | 18 | 18 | **100%** (18/18) |

## Any v1.1 misses?

**None.** All 18 extracted paths across the 8 calls matched the scanned
catalog verbatim. Both models honored the §4.3.3 system-prompt instruction
("cite each menu path exactly as written") and the user-prompt instruction
("quote each menu path EXACTLY as written there") in this sample. The sample
is small (8 calls, 18 paths), so zero misses here is not a strong guarantee
of zero misses in general — but it is directionally consistent with the spec's intent.

## Why is v1.0 "0/0" rather than "0/N"?

`.askllm_extract_paths()` is built to match v1.1's literal output format
(`Analyses > menu group > ... > menu title`, the exact format v1.1's prompt
demands). Neither model spontaneously used that literal format in any of the
8 v1.0 replies — instead they wrote free-form descriptions with `→`, `➔`, or
backticks (e.g. `` `Regression` ➔ `Linear Regression` ``, or fully generic
"Analyze → Regression → Linear" wording). This means:

1. **v1.0's menu paths are not mechanically verifiable** — there is no
   consistent format to compare programmatically; users have to check each
   one by hand (the existing conclusion in `docs/LIMITATIONS.zh-TW.md`).
2. Manual review of these 8 replies (see `dev-notes/s5b-raw/*.md` for full text):
   - **iris / gpt-4o-mini (v1.0)**: 4 of 5 suggestions had a real
     group/title match (case or wording aside); item 1's "Descriptives →
     Descriptive Statistics" invents a submenu that doesn't exist.
   - **iris / gemini (v1.0)**: 3 of 5 matched; item 4 flattens the real
     three-level path (`Regression > Logistic Regression > N Outcomes`)
     into a fabricated single item; item 5 drops the middle level
     (`Data Reduction`).
   - **mtcars / gpt-4o-mini (v1.0)**: **fully fabricated** — a generic
     "Analyze → Regression → Linear" menu (SPSS-flavored), nothing like
     jamovi's actual English wording. The worst hallucination in this sample.
   - **mtcars / gemini (v1.0)**: appended an unsolicited SPSS menu
     comparison; the jamovi portion was semantically correct but written as
     scattered `` `Analyses` ➔ `Regression` ➔ `Linear...` `` fragments, not a
     directly comparable string.

   Rough manual estimate: v1.0's semantic (group/title) correctness across
   both models is around 7/10 items, but **zero** of those items meet the
   machine-checkable `Analyses > ...` literal standard, and at least 3 items
   are structurally fabricated (invented submenu, flattened hierarchy, generic rewrite).

3. **v1.1's contribution is the combination of format + content
   constraints**: it demands both that the path exist (content) and that it
   be quoted verbatim from the catalog (format). Both held in this sample.

## compare-models.R interface changes

- New parameters:
  - `with_catalog = FALSE`: when `TRUE`, builds `catalog_text`/
    `available_text` via `scan_modules()` + `catalog_text()` +
    `available_text()` (reading `inst/catalog/known-modules.yaml`), loaded
    through `pkgload::load_all()` or the installed package, and passes them
    plus `.askllm_system_prompt(TRUE)` to `ask_llm()`; `FALSE` keeps the v1.0
    call path byte-identical.
  - `known_path = NULL`: override the `known-modules.yaml` path (for tests / non-installed contexts).
  - `check_paths = TRUE`: whenever a local scan succeeds (regardless of
    `with_catalog`), compute the legal-path set and add hit-rate columns to
    the report; silently skipped (falling back to the old report format) if
    no modules are found.
  - `scan_dirs = NULL`: override `scan_modules()`'s search directories
    (defaults to `default_module_dirs()`'s auto-detection; see the "legal
    path set" note above for when manual overrides are needed).
- New internal (unexported) helpers, local to this tool script:
  - `.askllm_legal_paths(scanned)`, `.askllm_extract_paths(text)`,
    `.askllm_check_path_hits(text, legal_paths)` — see Chinese section for details.
- Report format: `with_catalog = TRUE` adds "catalog text sent" / "available
  text sent" sections; when a legal-path set is available, both the summary
  table and per-model sections gain extracted/hit counts (or a miss list).
- Backward compatible: all new parameters have defaults; existing calls
  (`with_catalog` defaulting to `FALSE`) are unchanged. `tools/compare-models.R`
  is not installed with the package and has no testthat coverage, so this
  change does not affect the package's existing test suite (520 cases).
