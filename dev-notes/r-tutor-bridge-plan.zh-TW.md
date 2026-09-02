# askLLM 雙分析設計：R code helper（Proposition A，讀法 A）

> 建立日期：2026-09-02（取代同日「單分析 toggle 版」規劃）
> 觸發：真機手測 `20260902001.omv` 證實 `rCode` toggle 在同一結果面板同時輸出「選單路徑諮詢＋R 產碼」，兩種意圖混雜——拆成獨立分析。
> 前提：M-R1（構件 1+4）已實作**未 commit**；核心為檔案層純函式，新分析 `.b.R` 直接重用。
> 決策不變：per-role 後綴、link-out 先、不 runtime 抓、種子語料延後、隱私鐵則、S1 邊界、`.h.R` 永不手改。
> 標記：**[證據]**／**[推論]**／**[spike]**／**★ 需作者簽核**。

---

## 零、M-R1 現況盤點（未 commit 的產物，退場與重用以此為準）

| 檔案 | M-R1 改動 | 讀法 A 處置 |
|---|---|---|
| `R/rj-env.R`（新） | `scan_rj()`、`rj_env_text()`、`.scan_rj_hit()`、`.scan_rj_not_installed()` | **原樣保留**，新分析直接呼叫 |
| `tests/testthat/test-rj-env.R` + `fixtures/modules/rj-{a,b,broken,none}` | 純函式測試 | **原樣保留** |
| `R/llm-adapter.R` | `build_prompt(rj_env_text=)`、`ask_llm(rj_env_text=)`；情形 A 條件改為 `!has_catalog && !has_rj`；指令段改為逐行組裝 | **保留**（預設 `NULL` 逐字相同已有測試鎖）；新分析用 |
| `R/askllm.b.R` | `.ASKLLM_RJ_COMMON`、`.ASKLLM_RJ_SUFFIX`、`.askllm_strip_fences()`、`.askllm_system_prompt(r_code=)`、`.askllm_caveat_text(has_rj_env=, has_material=, r_code=)`、`.askllm_build_payload(r_code=)`、`.askllm_gather_context(rCode=)`、`.runInner()` 七處 `opt$rCode` 接線 | **拆三類**：搬家／退回原簽名／刪除（見第一節） |
| `jamovi/askllm.a.yaml`、`askllm.u.yaml` | `rCode` Bool + CheckBox | **刪除** |
| `R/askllm.h.R` | prepare 重生（含 rCode） | 刪 rCode 後**重生** |
| `tests/testthat/test-adapter.R`（+6 案例） | `build_prompt`/`ask_llm` rj 接線 | **保留** |
| `tests/testthat/test-brun.R`（+6 案例） | payload `r_code`（2）、`gather_context` rCode（4） | **刪除**（對應函式退回原簽名） |
| `tests/testthat/test-role.R`（+13 案例） | caveat 四參數（4）、system prompt `r_code`（9） | **改指向**新分析的 `.askllmr_system_prompt()`／`.askllmr_caveat_text()`，斷言內容不變 |
| `tests/testthat/test-strip-fences.R`（新） | 純函式測試 | **保留** |
| `dev-notes/execution-plan.zh-TW.md` | S6 更新段 | 保留（文件） |

---

## 一、現有 `askllm` 分析退場範圍

### 1.1 精確清單

**刪除（諮詢分析不再有 R-code 意圖）**
- `jamovi/askllm.a.yaml`：`rCode` 選項整段
- `jamovi/askllm.u.yaml`：`rCode` CheckBox
- `R/askllm.b.R` `.runInner()`：
  - `.askllm_gather_context(opt$includeCatalog, rCode = …)` → 退回 `.askllm_gather_context(opt$includeCatalog)`
  - `rj_env_text_value` 變數與併入 `context_text` 的那段
  - `.askllm_build_payload(..., r_code = …)` 引數
  - 動作分支與一般分支的 `.askllm_system_prompt(..., r_code = …)`、`build_prompt(..., rj_env_text = …)`、`ask_llm(..., rj_env_text = …)`
  - `has_rj_env` 變數、state 的 `has_rj_env` 欄、三處 caveat 的 `has_rj_env=`/`r_code=` 引數（含 cached 回放）
- `R/askllm.b.R` 函式簽名**退回原狀**：
  - `.askllm_build_payload()`：移除 `r_code` 參數（payload 格式**回到 v1.4**；理由見 1.2）
  - `.askllm_gather_context()`：移除 `rCode` 參數與 `rj_env_text` 回傳欄
  - `.askllm_system_prompt()`：移除 `r_code` 參數（R helper 用自己的組裝函式，見 2.4）
  - `.askllm_caveat_text()`：退回單參數 `has_catalog`；rj 兩態句抽出成共用純函式（見 1.3）
- `R/askllm.h.R`：`jmvtools::prepare(home = "C:/Program Files/jamovi 28.1.0.0")` 重生

**搬家（從 `askllm.b.R` 移到新檔 `R/r-tutor.R`，不改名、不改內容）**
- `.ASKLLM_RJ_COMMON`、`.ASKLLM_RJ_SUFFIX`、`.askllm_strip_fences()`

**保留（諮詢分析原有能力，零變動）**
- catalog 接地（`includeCatalog`、`.ASKLLM_CATALOG_SUFFIX`、`build_prompt` B/C 情形）、三人格模板、`promptLang`、`systemPrompt`、`systemPromptVar`（jmv-desc）、Test Connection、`enableActions` 動作模式與 `llmColumns` Output、防抖快取、`.askllm_guide_text()`（僅加一句導引，見未決題 5）

### 1.2 回歸鎖（退場後諮詢分析必須與 rCode 加入前逐字相同）

| 鎖 | 對象 | 驗證方式 |
|---|---|---|
| L1 | `.askllm_system_prompt()` 六種 (role, lang) × has_catalog × enable_actions | 既有 `test-role.R` 回歸案例（M-R1 前就有）；M-R1 新增的 `r_code=FALSE` 三案例在參數移除後改為「無此參數」斷言或刪除 |
| L2 | `build_prompt()` 情形 A/B/C | 既有 `test-adapter.R` byte-identical 案例＋M-R1 新增的 `rj_env_text=NULL` 案例（保留） |
| L3 | `.askllm_build_payload()` | **payload 回到 v1.4**：M-R1 的 v1.5 在末尾無條件追加 `FALSE` 字串，會讓所有既存 `.omv` 的快取指紋一次性失效（重開後改選項即重打 LLM）[推論]；移除參數後既有 byte-identical 測試直接成立 |
| L4 | `.askllm_caveat_text(has_catalog)` | 既有測試；M-R1 的「舊兩參數呼叫逐字相同」案例改為單參數 |
| L5 | `.runInner()` 不再引用 R-code 概念 | 新增 source-scan 測試：讀 `R/askllm.b.R` 原始碼，`expect_false(any(grepl('opt\\$rCode|rj_env_text|r_code', lines)))`（廉價、防回流） |
| L6 | a.yaml 選項集合 | 新增測試：讀 `askllm.a.yaml`，`expect_false('rCode' %in% option_names)` |

顯示層例外：`answer$setContent(.askllm_strip_fences(res$text))` 是否留在諮詢分析——不影響 L1–L4（它只改畫面），列未決題 6（推薦保留）。

### 1.3 一個小重構（讓兩分析共用 caveat 片段）
- 從 M-R1 的 `.askllm_caveat_text()` 抽出 `.askllm_rj_caveat_lines(has_rj_env)` → `list(en = <chr>, zh = <chr>)`（內容＝M-R1 已寫好的 `r_en`/`r_zh` 三態邏輯：未執行提醒＋`TRUE`/`FALSE`/`NA` 兩態句）
- 諮詢分析的 `.askllm_caveat_text()` 不呼叫它；R helper 的 `.askllmr_caveat_text()` 呼叫它

---

## 二、新分析設計：`askllmr`

### 2.1 命名與選單（★ 未決題 1、2）
- `name: askllmr`、`ns: askLLM`、`menuGroup: askLLM`、`menuTitle: R code helper`、`menuSubtitle: Get R code to paste into Rj Editor`、`title: R code helper (for Rj)`
- `jamovi/0000.yaml` `analyses` 加第二筆（`jmvtools::prepare` 是否自動重生此段 [spike]；若否則手加）
- 檔案組：`jamovi/askllmr.{a,r,u}.yaml`、`jamovi/js/askllmr.js`、`R/askllmr.b.R`、`R/askllmr.h.R`（prepare 生成，類別 `askllmrBase`/`askllmrOptions`/`askllmrResults`）

### 2.2 選項策略（重複哪些、省哪些）

| 選項 | 諮詢 `askllm` | R helper `askllmr` | 理由 |
|---|---|---|---|
| `data` | ✔ | ✔ | 必要 |
| `vars` | ✔ | ✔ | 摘要→正確欄名／型別，產碼必要 |
| `question` | ✔ | ✔（title：`What should the R code do?`） | |
| `includeSummary` | ✔ | ✔（default true） | 隱私揭露一致：仍只送摘要統計 |
| `includeCatalog` | ✔ | **省** | 產碼不需選單路徑接地；Rj 偵測改由 `scan_rj()` 直接做 |
| `submit` | ✔ | ✔ | 防抖觸發器 |
| `enableActions`／`llmColumns` | ✔ | **省** | 動作模式屬諮詢分析；R helper 定位「教，不代做」 |
| `testConnection` | ✔ | **省**（guide 文字指向「Ask LLM 分析的 Test Connection」） | 精簡面板；plumbing 相同，測一次即可（★ 未決題 4 唯一猶豫項） |
| `provider`／`model`／`baseUrl` | ✔ | ✔ | jamovi 每個分析獨立宣告，必須重複；`askllmr.js` 複製 `onProviderChanged` |
| `maxLevels` | ✔ | **省**（`summarize_data(max_levels = 10)` 固定） | 精簡 |
| `role`／`promptLang` | ✔ | ✔ | 共用 personas（★ 未決題 3，推薦共用） |
| `systemPrompt` | ✔ | ✔ | 覆蓋 base 身分；RJ 後綴仍附加（比照 catalog suffix 行為） |
| `systemPromptVar` | ✔ | ✔ | S4 grounding，同機制同優先序 |
| 新增 | — | 無 | Rj 掃描**強制**，不設開關；教材開關延後 |

`askllmr.u.yaml` 版面：VariableSupplier（`vars`、`systemPromptVar`）→ `question` TextBox → CheckBox（`includeSummary`、`submit`）→ CollapseBox「LLM settings」（`provider`、`model`、`baseUrl`、`role`、`promptLang`、`systemPrompt`）。共 12 個選項（諮詢分析 17 個）。

### 2.3 `askllmr.r.yaml` 結果形狀（刻意與諮詢分析不同：code block 為主）

| item | type | 內容 | 何時設 |
|---|---|---|---|
| `instructions` | Preformatted | 引導／等待／錯誤／金鑰教學（重用 `key_setup_text`、`.askllm_waiting_text`）；Rj 未裝時另加靜態提示 | `.init()` 靜態；`.run()` 更新 |
| `code` | Preformatted，title `R code — paste into Rj Editor` | LLM 回覆的**第一個 fenced block**（去圍欄） | 成功後 |
| `explanation` | Preformatted，title `What this code does` | 回覆中非 code 部分（去圍欄） | 成功後 |
| `links` | **Html**，title `''` | CTA：`Open Rj: Analyses ▸ R ▸ Rj ▸ Rj Editor` ＋ `<a href="https://scgeeker.github.io/askLLM/learn-r.html">Learn R with Rj</a>`；Rj 未裝時加 `Install Rj: Modules ▸ jamovi library` | `.init()` 靜態（S3）；`.run()` 依 `installed` 切換 |
| `caveat` | Preformatted | `.askllmr_caveat_text(has_rj_env)`：未由 askLLM 執行、貼進 Rj 跑並回報、兩態接地句、數值以 jamovi 為準 | 成功後與 cached 回放 |
| `meta` | Preformatted | `模型 · 耗時s`（重用 `.askllm_meta_line`） | 成功後 |

`Html` 為 jamovi-compiler 合法結果型別 [證據：`resultelementschemas.yaml:246`]；新分析無舊 `.omv` 還原問題，Html item 可**先於 C1** 落地（★ 未決題 9）。

### 2.4 `R/askllmr.b.R` 設計（重用清單＋新增純函式）

**直接重用（不重寫）**：`scan_rj()`、`rj_env_text()`、`build_prompt(rj_env_text=)`、`ask_llm(rj_env_text=)`、`make_chat()`、`translate_error()`、`provider_spec()`、`load_api_key()`、`key_setup_text()`、`summarize_data()`、`.askllm_build_payload()`（v1.4 簽名；rj 文字經 `context_text` 進指紋）、`.askllm_decide()`、`.askllm_meta_line()`、`.askllm_provider_name()`、`.askllm_waiting_text()`、`.askllm_resolve_custom()`、`.ASKLLM_RJ_SUFFIX`、`.askllm_strip_fences()`、`.askllm_rj_caveat_lines()`。

**新增純函式（檔案層，皆可離線測）**
- `.ASKLLM_R_PROMPTS[[role]][[lang]]`（3×2 短句 base 身分）：例 en/consultant：`You are an R coding tutor embedded in jamovi. The user writes R in jamovi's Rj Editor and asks you for code that works on the dataset described below.`；tutor／explainer 各一句語氣差異（蘇格拉底／零基礎）
- `.askllmr_system_prompt(role, lang, system_prompt = '', has_rj_env = FALSE)`：`base = custom 非空 ? custom : .ASKLLM_R_PROMPTS[[role]][[lang]]`，**恆**接 `.ASKLLM_RJ_SUFFIX[[role]][[lang]]`（R 家教是主體，不是後綴）；`has_rj_env` 目前不改字串（`<rj_environment>` 缺席時的行為已寫在 `.ASKLLM_RJ_COMMON`），參數保留供未來分支
- `.askllmr_split(text)` → `list(code, explanation)`：取第一個 fenced block 為 `code`（去圍欄），其餘為 `explanation`；無 fenced block → `code = ''`、`explanation = strip_fences(text)`；`NULL` → 兩者 `''`。決定性、不依賴 structured output（小型 Ollama 模型也能用）
- `.askllmr_caveat_text(has_rj_env)`：先英後中；固定句＋`.askllm_rj_caveat_lines(has_rj_env)`＋「Where numbers disagree with jamovi output, jamovi is correct」
- `.askllmr_links_html(installed, url = .ASKLLMR_LEARN_R_URL)`：字面 HTML 組裝（無 htmltools 依賴）；常青 URL 為檔案層常數（字面測試防誤刪）
- `.askllmr_guide_text()`／`.askllmr_no_rj_text()`：雙語靜態文字（含隱私揭露句：送摘要統計＋Rj 套件**名稱**，不含資料）

**`.runInner()` 流程**
1. 守門：`submit` 且 `question` 非空，否則 guide
2. `summary_text`（`includeSummary && length(vars) > 0`）
3. **強制** `rj <- tryCatch(scan_rj(), …)`；`rj_env_text_value <- rj_env_text(rj)`（未裝→`NULL`）；`has_rj_env <- !is.null(rj_env_text_value)`
4. `custom <- .askllm_resolve_custom(var_desc, opt$systemPrompt)`（同諮詢分析的 jmv-desc 讀法）
5. `payload <- .askllm_build_payload(question, summary_text, base_url, model, context_text = rj_env_text_value %||% '', role, lang, custom, system_prompt_var)`
6. 快取比對：cached → 回放 `code`/`explanation`/`meta`/`caveat`（state 存 `code`, `explanation`, `meta_line`, `has_rj_env`）
7. 金鑰（同諮詢分析）
8. 等待狀態（`code$setStatus('running')` + `.checkpoint()`）
9. `ask_llm(question, summary_text, rj_env_text = rj_env_text_value, system_prompt = .askllmr_system_prompt(...), max_tokens = 4096)`
10. 成功：`parts <- .askllmr_split(res$text)` → `code`/`explanation`/`meta`/`caveat`/`links`；失敗：`instructions` 顯示 `translate_error` 文案、不動上次結果

**Rj 未裝分支**：不阻擋呼叫（LLM 依 `.ASKLLM_RJ_COMMON` 改教 Syntax Mode 與 `jmv::` 碼）；`instructions` 前置 `.askllmr_no_rj_text()`（零 LLM）；`links` 顯示安裝路徑；caveat 兩態句為 `FALSE` 版。

**S1 邊界自檢**：不 `eval`、不 `parse` 後求值、不寫 client 側呈現、網路面只有既有 LLM 呼叫；Rj 掃描只讀 metadata。

---

## 三、共用碼組織

- **同一 R 套件、同一 namespace**：`R/*.R` 檔案層函式（含 `.` 開頭）在套件內互相可見；`NAMESPACE` 的 `exportPattern("^[[:alpha:]]+")` 只決定匯出，不影響 `askllmr.b.R` 呼叫 `.askllm_*` [證據]。R6 類別名 `askllmrClass`/`askllmrBase` 與現有不衝突。
- **載入順序**：R 依字母序載入 `R/` 檔；現況 `askllm.b.R` 先於 `askllm.h.R` 仍能運作（R6 的 `inherit` 延遲求值 [推論，現況即證]），`askllmr.*` 同型，無新風險；`r-tutor.R`、`rj-env.R` 的常數在函式體內引用，無順序問題。
- **要不要 `R/llm-shared.R`**：**不需要**。plumbing 本來就在獨立檔（`llm-adapter.R`、`llm-providers.R`、`key-loader.R`、`llm-ping.R`、`data-summary.R`）。只做一件事：把 R-code 專用常數與函式從 `askllm.b.R` 搬到 **`R/r-tutor.R`**（`.ASKLLM_RJ_COMMON`、`.ASKLLM_RJ_SUFFIX`、`.askllm_strip_fences`、`.askllm_rj_caveat_lines`、`.ASKLLM_R_PROMPTS`、`.askllmr_*` 純函式）；`askllmr.b.R` 只留 R6 類別與 `.runInner()`——比照「`.b.R` 的可測邏輯抽到檔案層」的既有慣例，但避免 R helper 常數住在諮詢分析的檔案裡誤導維護者。
- **`jamovi/js/askllmr.js`**：`PROVIDER_DEFAULTS` 第三份手工複本（原兩處：`llm-providers.R`、`askllm.js`）→ 擴充既有一致性測試同時讀兩個 js。
- **`.h.R` 兩份**、`0000.yaml` 兩筆 analyses；`tests/testthat/test-brun.R` 加 `askllmrClass` 載入斷言。

---

## 四、修訂里程碑（從 M-R1 toggle 版 → A 版）

```
M-A0 退場（0.5 天）
 ├─ 刪 a/u.yaml rCode → prepare 重生 h.R
 ├─ .runInner() 退回七處接線;四個函式退回原簽名
 ├─ 刪 test-brun.R 的 6 個 rCode/r_code 案例;test-role.R 13 案例暫 skip(待 M-A3 改指向)
 └─ 回歸鎖 L1–L6 全綠 → **commit #1「revert rCode toggle; keep pure functions」**

M-A1 搬家（0.5 天）
 ├─ 新建 R/r-tutor.R;搬 RJ_COMMON/RJ_SUFFIX/strip_fences
 ├─ 抽 .askllm_rj_caveat_lines()
 └─ 全綠 → commit #2

M-A2 骨架（0.5 天）
 ├─ askllmr.{a,r,u}.yaml、askllmr.js、0000.yaml 第二筆
 ├─ prepare 生 askllmr.h.R;空 .b.R 只顯示 guide
 └─ jmvtools::install 於 28.1;選單出現兩個分析 → commit #3

M-A3 接線（1 天,TDD）
 ├─ RED:.ASKLLM_R_PROMPTS / .askllmr_system_prompt / .askllmr_split /
 │        .askllmr_caveat_text / .askllmr_links_html;test-role.R 13 案例改指向
 ├─ .runInner() 十步流程
 └─ 全綠 → commit #4

M-A4 GUI E2E（0.5 天,28.1 真機)
 ├─ Rj 已裝/暫改名未裝;三人格 × en/zh;cached 回放;Ollama 零外送
 ├─ 諮詢分析回歸:同一題在 askllm 無 R 碼、在 askllmr 無選單路徑
 └─ 存 .omv 重開兩分析皆還原 → commit #5

M-A5 文件與常青頁（原 M-R3,依賴不變)
 ├─ learn-r.json/html、check_learn_r_links()（可與 M-A2 並行）
 ├─ askllmr 的 links Html item 不等 C1;askllm 的 Html item 仍歸 C1
 └─ README/LIMITATIONS 兩語版:兩分析分工與隱私敘述;版本 1.3.0
```

**M-R1 產物搬／丟表**

| 產物 | 處置 |
|---|---|
| `rj-env.R` + 測試 + fixtures | 搬（原地） |
| `build_prompt`/`ask_llm` 的 `rj_env_text` + 6 測試 | 搬（原地） |
| `.ASKLLM_RJ_COMMON`/`.ASKLLM_RJ_SUFFIX` + 9 測試 | 搬到 `r-tutor.R`；測試改指向 `.askllmr_system_prompt()` |
| `.askllm_strip_fences` + 測試 | 搬到 `r-tutor.R` |
| caveat 三態邏輯 + 4 測試 | 抽成 `.askllm_rj_caveat_lines()`；測試改指向 `.askllmr_caveat_text()` |
| `.askllm_build_payload(r_code=)` + 2 測試 | **丟**（回 v1.4） |
| `.askllm_gather_context(rCode=)` + 4 測試 | **丟**（新分析直接呼叫 `scan_rj()`） |
| `.askllm_system_prompt(r_code=)` + 3 回歸測試 | **丟**參數；回歸測試改為「無此參數」 |
| a/u.yaml `rCode`、`.runInner()` 接線、state `has_rj_env` | **丟** |

---

## 五、未決／簽核點（推薦預設）

> **作者簽核（2026-09-02，讀法 A）**：#3 **共用三人格**；#1 命名 → `name: askllmr`、**menuTitle/title：「R code tutor」**、subtitle「Get R code to paste into Rj Editor」；#2 **同 menuGroup: askLLM**（與現有 `askllm` 併入同一 askLLM 選單下拉，已確認）；#4 **`testConnection` 保留**於 R code tutor（只省 `includeCatalog`/`enableActions`/`llmColumns`/`maxLevels`，共 13 選項）；**UI：`submit` CheckBox 排最後**（順序 `includeSummary` → `testConnection` → `submit`）；#5、#6、#9、#10 依推薦預設接受。→ §2.1/§2.2 依此調整（menuTitle=R code tutor、testConnection ✔、submit 置末）。

| # | 問題 | 推薦預設 | 簽核 |
|---|---|---|---|
| 1 | 新分析命名 | `askllmr`；title `R code helper (for Rj)`；menuTitle `R code helper` | ★ |
| 2 | menu 位置 | 同 `menuGroup: askLLM`，列第二；`menuSubtitle: Get R code to paste into Rj Editor`；不另設 subgroup | ★ |
| 3 | 是否共用 personas | **共用**：`role`/`promptLang` 各自宣告、模板共用；R helper 的 base 身分另寫三句短句（`.ASKLLM_R_PROMPTS`），語氣差異由既有 RJ 後綴承擔 | ★ |
| 4 | 選項精簡到哪 | 依 2.2 表：省 `includeCatalog`/`enableActions`/`llmColumns`/`testConnection`/`maxLevels`；**`testConnection` 是唯一可回收項**（若作者要 R helper 可獨立使用則加回） | ★ |
| 5 | 諮詢分析是否保留導引句 | **guide text 加一行**（雙語）：`Need R code for Rj? Use askLLM ▸ R code helper.`；**不**進 LLM prompt、不進 caveat（守 L1–L4 逐字） | ★ |
| 6 | `.askllm_strip_fences` 是否留在諮詢分析 | **保留**（顯示層，不影響回歸鎖；諮詢回覆偶爾也帶 ``` 圍欄） | ★ |
| 7 | code／explanation 拆分法 | **fence split**（決定性、任何模型可用）；structured output 留未來；小模型不吐圍欄時整段落 `explanation`、`code` 顯示「(no code block returned — ask again)」 | 實作時 spike（Ollama `llama3.2`） |
| 8 | `0000.yaml` 第二筆是否由 `prepare` 自動重生 | 假設會；否則手加並記入 CLAUDE.md | 實作時 spike |
| 9 | `links` Html item 是否等 C1 | **不等**：新分析無舊 `.omv` 還原風險；C1 的 askllm Html item 另行 | ★（低風險） |
| 10 | payload 是否回 v1.4 | **回 v1.4**（避免既存 `.omv` 一次性快取失效）；R helper 走同函式，rj 文字經 `context_text` 進指紋 | ★（技術，建議照做） |
| 11 | `testConnection` 省略後的引導 | R helper guide 文字：「Test your key in Ask LLM ▸ Test Connection」 | 隨 #4 |
| 12 | 版本 | 1.3.0；README 兩語版新增「兩個分析各做什麼」對照表 | — |

沿用先前簽核不變：per-role 後綴（不新增 coach 人格）、link-out 先（M-A5）、不 runtime 抓 `learn-r.json`、種子語料延後、CC BY-SA 4.0 接受（僅在種子語料啟動時生效）。

---

## 六、跨項目工程注意事項

- **三處同步**：`R/llm-providers.R`、`jamovi/js/askllm.js`、`jamovi/js/askllmr.js` 的 `PROVIDER_DEFAULTS`；一致性測試擴充。
- **`.h.R`**：兩份皆由 `jmvtools::prepare(home = "C:/Program Files/jamovi 28.1.0.0")` 重生；`tools/release-check.R` 的 `JAMOVI_HOME` 順手更新。
- **`.init()` 稽核（S3）**：`askllmr` 的 `instructions`、`links` 靜態內容置於 `.init()`。
- **隱私文案**：R helper guide 揭露「摘要統計＋Rj 套件名稱（環境中繼資料）」；Ollama 零外送敘述兩分析一致。
- **TDD**：R 改動走 `tdd-r`；yaml/html/md 人工驗收；commit 切五刀（M-A0～M-A4）以便回溯。
- **S1 邊界**：R helper 不 eval、不 parse-then-eval、不寫 client 側、不連第三方；「教，不代做」。

---

## 資料來源
- `git diff`（未 commit 的 M-R1）、`R/rj-env.R`、`tests/testthat/test-rj-env.R`、`test-strip-fences.R`
- `jamovi/0000.yaml`、`NAMESPACE`、`jamovi/askllm.{a,u,r}.yaml`
- `jamovi-compiler/schemas/resultelementschemas.yaml:246`（`Html` 結果型別）
- 真機手測 `20260902001.omv`（拆分理由）、`dev-notes/execution-plan.zh-TW.md` S1–S6
