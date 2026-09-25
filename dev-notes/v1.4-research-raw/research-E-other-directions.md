# askLLM 擴充方向盤點（作者尚未提出者）— 研究報告 E

> 日期：2026-09-25｜基準：askLLM v1.3.1（`/home/user/askLLM`，HEAD `6235f98`）
> 範圍：**排除**作者已提出的兩個方向（(1) AI 協助把統計問題轉成分析工作流程路徑圖；(2) 匯入外部檔案：自訂提示詞／輔助資料／codebook）。下文只在與之交界處點到為止。
> 標記：**[證據]** 已從 repo 或外部來源查證；**[推論]** 依現有結構推斷；**[spike]** 需真機／真 API 驗證。
> 邊界原則（`dev-notes/execution-plan.zh-TW.md` S1，2026-09-10 升為明文）：askLLM 只建議、不代做——不執行分析、不寫資料欄、不驅動介面。每個候選都標示是否在此邊界內。

---

## 0. 方法與來源

**已詳讀（repo）**：`README.md`、`README.zh-TW.md`（章節結構）、`PLAN.zh-TW.md`、`dev-notes/execution-plan.zh-TW.md`（S1–S6）、`dev-notes/jasp-ai-landscape.zh-TW.md`、`dev-notes/v1.2-actionable-research.zh-TW.md`（§1、§3、§6）、`dev-notes/r-tutor-bridge-plan.zh-TW.md`、`dev-notes/library-submission-response.zh-TW.md`、`dev-notes/jonathon-reply-draft.zh-TW.md`、`docs/LIMITATIONS.zh-TW.md`、`docs/choose-model.html`（結構）、`docs/learn-r.json`、`R/` 全部檔案的函式清單、`R/askllm.b.R`／`R/askllmr.b.R` 的 `.runInner()`、`R/llm-adapter.R`、`R/data-summary.R`、`R/rj-env.R`、`R/module-catalog.R`、`R/r-tutor.R`、`R/llm-providers.R`、`R/key-loader.R`、`jamovi/*.yaml`、`jamovi/js/askllm.js`、`tests/testthat/`（25 個檔、345 個 `test_that` 區塊）、`tools/*.R`、`inst/catalog/known-modules.yaml`。**`.github/` 不存在（無 CI）[證據]。**

**外部查證**：WebSearch 可用；WebFetch 對 `cran.r-project.org`、`opensource.posit.co`、`ellmer.tidyverse.org`、`jasp-stats.org`、`forum.jamovi.org`、`rnwy.com` 皆被 egress proxy 封鎖，改以 GitHub raw（ellmer `NEWS.md`、`DESCRIPTION`、`provider-openai-compatible.R`）、GitHub releases（jasp-desktop）與搜尋摘要替代。forum.jamovi.org 的三條討論串只取得搜尋摘要，未讀全文（下文標明）。

---

## 1. 會改變優先序的外部事實

### 1.1 GitHub Models 已於 2026-07-30 全面退役 —— askLLM 1.3.1 仍把它列為一級供應商 [證據]

- GitHub Changelog：2026-06-16 停收新客戶；7/16、7/23 brownout；**2026-07-30 起 playground、model catalog、inference API、BYOK 對所有客戶關閉，無寬限期**。
- ellmer 開發版 NEWS：`chat_github()`、`models_github()` 已 defunct（「GitHub Models retired」）。
- askLLM 現況：`R/llm-providers.R` 的 `github` 分支（`models.github.ai/inference`、預設 `openai/gpt-4o-mini`）、`jamovi/askllm.a.yaml` 與 `askllmr.a.yaml` 的 provider 選項、`jamovi/js/askllm.js`／`askllmr.js` 的 `PROVIDER_DEFAULTS`、`R/llm-ping.R` 的 github override（404=通）、`docs/SETUP-github.*`、`docs/MODELS-github.*`、`docs/choose-model.html` 的 GitHub 卡片、`README.md` 第 129 行「A GitHub account alone unlocks **35 free models**」、`jamovi/0000.yaml` description ——**全部指向一個已不存在的服務**。這是 v1.3.1 現在就壞掉的功能，也是「模型腐爛防治」最具體的實例（比作者在 execution-plan 記錄的 `:free` 清單腐爛更嚴重：整個 provider 消失）。
- 影響：使用者選 GitHub Models 會得到連線／404 錯誤；`translate_error()` 會把它翻成「端點或模型名錯誤」，誤導使用者去改模型名。

### 1.2 ellmer 0.5.0（2026-09-14 上 CRAN）能力盤點 [證據：GitHub `NEWS.md`、`DESCRIPTION` 0.5.0.9000、`R/provider-openai-compatible.R`]

| 能力 | 版本 | 對 askLLM 的意義 |
|---|---|---|
| `tool()` + `Chat$register_tool()`（0.3 簡化簽名；0.4 `tool()` 回傳可呼叫函式；`tool_annotations()`、`tool_reject()`） | 0.1 起有、0.3+ 成熟 | 可讓 LLM「查」catalog／known-modules／教學索引（唯讀），見方向 N |
| `Chat$chat_structured()`／`type_*()`／`type_from_schema()` | 0.2+ | 結構化輸出；jamovi 28.x（bundled R 4.6.0）可裝 0.4.x/0.5；2.7.x 停在 0.2.0（有 `chat_structured`，但作者 v1.2 研究以「0.2.0 無 `chat_structured`」描述——實際 NEWS 顯示 0.2.0 已引入，建議 spike 確認） |
| `batch_chat()`／`parallel_chat()`（0.4 轉正式）、`batch_chat_structured()` | 0.2+ | 只對評測工具（`tools/compare-models.R`）有用，模組內單次問答用不到 |
| `Chat$get_tokens()`、`Chat$get_cost()`（0.2+）、`Chat$token_count()`、`models_update_prices()`（0.5） | 0.2+/0.5 | token／費用計量（方向 K） |
| `models_ollama()`、`models_openai()`、`models_google_gemini()`…；`ProviderOpenAICompatible` 有 `models_list()` 方法但**無** exported `models_openai_compatible()` | 0.2+ | 動態模型清單；但 askLLM 的 `R/llm-ping.R` 已自行 GET `/models`，不必依賴 ellmer（方向 A） |
| `credentials` 取代 `api_key`（0.4；`chat_openai_compatible(api_key=)` 仍存在但 deprecated） | 0.4 | 現行 `make_chat()` 用 `Sys.setenv(OPENAI_API_KEY=)` 繞過，可改 `credentials = function() key` 免污染行程環境（小重構） |
| `chat_openai_compatible()` 擷取 `reasoning_content` 為 `ContentThinking`；`chat_ollama()` 支援 structured chat、`params(reasoning_effort=)` | 0.4.1/0.4.2 | `as.character(raw)` 目前是否會夾帶 thinking 內容需 spike（gpt-oss、qwen3 類模型） |
| OpenTelemetry、`Chat$on_request_start/end()`、`Chat$get_rounds()` | 0.4.1/0.5 | 多輪對話（方向 G）可用 rounds；但為相容 0.2.0，建議用純文字歷史區塊 |
| 檔案上傳 `Chat$file_upload()`、`content_pdf_file()`、citations | 0.2–0.5 | 與作者已提的「匯入外部檔案」方向交界，本文不展開 |

### 1.3 JASP 0.98／0.98.1 的 AI 功能清單 [證據：jasp-desktop releases、jasp-stats.org 搜尋摘要]

- **聊天介面**：自然語言提問、**建立並執行分析、檢視結果、產生報告**（「generate reports」）。
- **tool calling**（function calling／native tool use）驅動 JASP GUI。
- 供應商：任何 OpenAI 相容 API（OpenAI、Anthropic、Mistral、OpenRouter、**local models**）；Preferences 內 Test Connection。
- 人格：Alfred（顧問）／Socrates（導師）／Evelyn（解說）＋**可在 Preferences 自訂人格**。
- 0.98.1 為 bug fix 與翻譯，AI 無新增。
- **對 askLLM 文件的一個修正風險**：`README.md` 第 160 行比較表寫 JASP「Within JASP only; **no fully local option**」——JASP 0.98.1 明列支援 local models（走 OpenAI 相容端點）。作者身在 jamovi team Slack，公開文件出現可被反駁的比較句不利；建議改為「JASP 亦可接本機模型，但代理式架構送出的是完整分析結果」（差異在資訊架構，不在能否本機）。

### 1.4 jamovi 結果**可以**以文字複製 [證據：forum t=1551、docs Syntax Mode]

- 一般模式右鍵 Copy → 剪貼簿為 **HTML**（貼進 Word/Excel）。
- **Syntax Mode** 下右鍵 Copy → **ASCII 純文字表格**，且同時看得到 jamovi 產生的 `jmv::xxx(...)` 語法（即「哪個分析、哪些選項」）。
- 另有 LaTeX copy、Export → HTML/PDF。
- 意義：「使用者貼上結果 → LLM 解讀」不需要平台開放 Results API，Syntax Mode 的純文字＋語法行就是現成的可貼載體；askLLM 的 `question` 欄已由 `jamovi/js/askllm.js` 換成 5 行 `textarea`（無 maxlength）[證據]，String 選項是否有長度上限需 [spike]。

### 1.5 jamovi Cloud [證據：forum t=4151 摘要、cloud.jamovi.org]

- Rj 在 Cloud（含 team plan）不可用（任意程式碼執行風險）；Cloud 顯示「Installing modules is not available on your plan」。
- 結論：askLLM 的 .jmo sideload 在 Cloud 基本不可行；R code tutor 更無對象。列為非目標（方向 P）。

### 1.6 社群與治理訊號

- **library 投稿（2026-07-27）**：Jonathon「暫不上架，非拒絕」；三層關切＝價值天花板（模組拿不到分析輸出）、信任邊界（資料→任意外部端點＋自備金鑰，custom provider 最棘手）、先例（要先建 LLM 模組安全審查政策）[證據]。→ 方向 B（結果解讀）跨價值門檻、方向 C（送出前預覽）直接回應信任邊界。
- **forum t=4054（2025-09-29）「downloadable log (against cheating)」**：教師要可下載的操作紀錄以查核學生作業是否自己做；Jonathon 回覆團隊在想「forensics features」[證據：搜尋摘要]。→ 方向 H（問答日誌）與教學情境高度契合。
- **社群 jamovi-mcp（yjm110517）**：啟動本機 jamovi engine、開檔、讀寫資料、跑分析、匯出結果、存 .omv [證據：Glama 摘要]。屬 jmv-agent 軌，印證 S6 分軌決策正確；askLLM 不需重做。
- **教學／科研痛點文獻**：假設檢驗在社科研究報告中**不到 25%**（PMC10830673）；APA 報告最常見錯誤＝漏報效果量、`p = .000`（StatMate/MetricGate）；LLM 統計回饋 **35% 過於籠統、錯誤或直接給答案**（arXiv 2511.04213／2511.07628）；ChatGPT 回饋「對學生驗證正確性的信心幫助有限」（PMC12292746）。→ 方向 D、J 的需求基礎，也提醒 tutor 人格必須「不給答案」並需評測（方向 F）。

---

## 2. 現況程式結構（可掛載點速覽）

| 層 | 檔案 | 可重用純函式 | 備註 |
|---|---|---|---|
| 分析主體 | `R/askllm.b.R`（635 行）、`R/askllmr.b.R`（214 行） | `.askllm_build_payload()`（指紋 v1.4：question/summary/base_url/model/context/role/lang/system_prompt/system_prompt_var/enable_actions）、`.askllm_decide()`、`.askllm_gather_context()`、`.askllm_system_prompt()`、`.askllm_resolve_custom()`、`.askllm_caveat_text()`、`.askllm_guide_text()`、`.askllm_guide_links_html()` | state 只存於 `answer`／`code` 一個 item：`list(payload, text/code, meta_line, has_*)`；失敗不 setState |
| LLM 介接 | `R/llm-adapter.R` | `make_chat()`（ellmer ≥0.4 走 `chat_openai_compatible`，否則 `chat_openai`；`ctor` 注入）、`build_prompt()`（A/B/C 情形逐字降級保證）、`translate_error()`、`ask_llm()` | 回傳 `list(ok, text, model, elapsed_s, error)`，**無 tokens 欄** |
| 供應商／金鑰 | `R/llm-providers.R`、`R/key-loader.R`、`R/llm-ping.R` | `provider_spec()`、`load_api_key()`（env→registry→.Renviron 鏈）、`ping_endpoint()`／`.ping_transport()`（已 GET `/models`，body 回傳但**未解析**）、`.askllm_test_connection_text()` | ping 的 body 是動態模型清單的免費來源 |
| 接地 | `R/data-summary.R`、`R/module-catalog.R`、`R/rj-env.R`、`inst/catalog/known-modules.yaml` | `summarize_data()`（4000 字元預算、逐變項截斷）、`scan_modules()`／`catalog_text()`（2500 字元、整模組貪婪截斷）／`available_text()`（900 字元）、`scan_rj()`／`rj_env_text()` | known-modules 已含 `esci`（效果量）與 `jpower`（檢定力）[證據] |
| R 家教 | `R/r-tutor.R` | `.ASKLLM_RJ_COMMON/SUFFIX`、`.askllmr_split()`（fence split）、`.askllm_wrap_html()`、`.askllmr_links_html()`、`.ASKLLM_TUTORIALS_URL` | 常青 URL 皆為檔案層常數＋字面測試 |
| 休眠 | `R/action-{schema,validate,formula,exec}.R` | `parse_plan()`、`validate_plan()`、`ask_llm_structured()`（三段降級鏈）、`validate_formula()`、`exec_analysis()` | UI 已撤，依 S1 保持休眠；`ask_llm_structured()` 的降級鏈可被非執行用途重用 |
| UI | `jamovi/*.{a,r,u}.yaml`、`jamovi/js/*.js` | `PROVIDER_DEFAULTS` 三處手工複本；`question` 注入 textarea；`onProviderChanged` | jus 3.0 無按鈕、無動態下拉、無超連結 widget（Html item 才有 `<a>`） |
| 工具 | `tools/compare-models.R`（`.askllm_extract_paths()`／`.askllm_check_path_hits()`）、`tools/release-check.R`（`check_known_modules_freshness()`、`check_learn_r_links()`）、`tools/sync-known-modules.R` | 已有「路徑命中率」機械檢核與發佈檢查 | 無 CI；live 測試以 `ASKLLM_LIVE_TESTS=1` opt-in |

---

## 3. 候選方向（16 個，依投報率概略排序）

格式：定義／情境／邊界相容性／技術可行性（檔案）／工作量（人天，單人含測試與雙語文件）／風險／投報率與理由。

### A. 供應商衛生：GitHub Models 退役處置＋動態模型清單＋腐爛防治（v1.3.2 hotfix）

- **定義**：把已死的 GitHub Models 從一級供應商降為「已退役（graceful error）」，並讓 Test Connection 順帶列出端點實際可用的模型，從結構上降低 model id 腐爛的傷害。
- **情境**：教學（課前 5 分鐘設定金鑰時不會撞到已關閉的服務）；研究（換供應商時能立刻看到可用模型名，不必翻文件）。
- **邊界**：完全相容（零執行、零寫入）。
- **技術可行性**：
  - `R/llm-providers.R`：`github` 分支改回傳 `error = 'GitHub Models 已於 2026-07-30 退役，請改選 OpenRouter/NVIDIA/Gemini（見 choose-model 頁）'`（比照 custom 缺 baseUrl 的 error 欄；`.runInner()` 第 498 行已會把 `spec$error` 顯示在 instructions）。**不要**從 a.yaml List 移除 `github` 值——舊 `.omv` 載入時選項值不在 enum 內的行為未驗證 [spike]，保留值但標題改「GitHub Models (retired 2026-07)」最安全。
  - `jamovi/js/askllm.js`、`askllmr.js`：`PROVIDER_DEFAULTS.github` 改空字串；`R/askllm.b.R` `.askllm_provider_name()` 同步；`R/llm-ping.R` `.ping_classify()` 的 github override 保留但加註。
  - 動態清單：`R/llm-ping.R` 新增純函式 `.ping_models_from_body(body, n = 15)`（`jsonlite::fromJSON(body)$data$id`，失敗回 `character(0)`），`.askllm_ping_result_line()` 追加「此端點回報的模型（前 N 個）：…」；Ollama 的 `/v1/models` 回的是本機已 pull 的模型 → 同時解決「離線 Ollama 模型推薦」的一半（另一半是 choose-model.html 的內容）。
  - 文件：`docs/SETUP-github.*` 標 retired、`docs/MODELS-github.*` 標 deprecated 或刪、`README*` 第 129 行、`choose-model.html` GitHub 卡片改「已退役」、`0000.yaml` description；順手修 §1.3 的 JASP「no fully local option」句。
  - 測試：`tests/testthat/test-providers.R` 加 github error 案例；`test-ping.R` 加 body 解析案例（含非 JSON、無 `data` 欄）。
- **工作量**：1–1.5 天。
- **風險**：舊 `.omv` 相容（上述 spike）；`/models` 清單對 NIM/OpenRouter 可達數百筆，需截斷；GitHub 之後下一個腐爛的可能是 NIM 預設 `meta/llama-3.1-8b-instruct`——建議把「預設模型」也納入 `tools/release-check.R` 的 live 檢查（對每個 provider 打一次 `/models` 確認預設 id 仍在清單）。
- **投報率：高**。零新依賴、修的是已發生的故障、且發佈檢查從此能抓到同類腐爛。

### B. 結果解讀分析（第三個分析：「Results Interpreter」）——貼上 Syntax Mode 純文字輸出 → 解讀、APA 結果段落、效果量與檢定力提醒

- **定義**：新增第三個分析，使用者把 jamovi 在 Syntax Mode 複製的 ASCII 表格（含 `jmv::` 語法行）貼進文字框，LLM 回：白話解讀、APA 7 結果段落草稿、應補報的效果量／CI、前提檢驗提醒、下一步建議。**數字一律引用貼上文字，不重算**。
- **情境**：教學（學生最痛的「跑完了然後呢」；教師可指定 tutor 人格只提問不代寫）；研究（快速產出 APA 段落初稿、檢查是否漏報效果量）。
- **邊界**：相容——只解讀與草擬文字，不執行、不讀 jamovi Results（使用者手動搬運，與 README 既有「迭代工作流程」一致）。**但與 `docs/LIMITATIONS.zh-TW.md` 綜合建議第 6 點「不要用它取代假設檢查與結果解讀」有張力**：需改寫為「解讀草稿仍需自行核對；數值以 jamovi 為準；假設檢查用 jamovi 內建工具」，並在 caveat 明示。這是文件層的重新裁決，不是邊界原則的鬆動。
- **技術可行性**：
  - 依 `askllmr` 的既成模式新增 `askllmi`：`jamovi/askllmi.{a,r,u}.yaml`、`jamovi/js/askllmi.js`（複製 `askllmr.js`，textarea 改注入 `output` 欄）、`R/askllmi.b.R`、`R/askllmi.h.R`（`jmvtools::prepare` 重生，S2 永不手改）、`jamovi/0000.yaml` 第三筆。
  - 新純函式檔 `R/r-interpret.R`：`.ASKLLM_I_PROMPTS[[role]][[lang]]`、`.askllmi_system_prompt(role, lang, system_prompt)`（恆附「quote every number verbatim from <results>; never compute or invent statistics; if a needed statistic is absent, say which jamovi option produces it」）、`.askllmi_detect_syntax(text)`（regex `jmv::[A-Za-z]+\(` 抓分析名與選項 → 供 prompt 標註「使用者跑的是 ttestIS(welchs=TRUE)」）、`.askllmi_split_sections(text)`（以固定標題切 interpretation／apa／checklist，找不到就整段進 interpretation）、`.askllmi_caveat_text()`、`.askllmi_guide_text()`（教使用者 ⋮ → Syntax mode → 右鍵表格 → Copy）。
  - `R/llm-adapter.R` `build_prompt()` 加 `results_text = NULL` 參數，非 NULL 時插入 `<results>` 區塊（比照 `rj_env_text` 的降級保證：NULL 時逐字不變，既有 byte-identical 測試不受影響）。
  - 選項：`vars`、`output`（String，貼上區）、`question`（可空：預設「解讀並寫 APA 結果段落」）、`reportStyle`（List：apa7／plain／zh-thesis）、`includeSummary`、`submit`、`testConnection`、provider/model/baseUrl、`role`、`promptLang`、`systemPromptVar`。結果：`interpretation`（Html）、`apa`（Html）、`checklist`（Html）、`caveat`、`meta`；state 存於 `interpretation`。
  - 決定性檢核（可入 testthat 與 `tools/compare-models.R`）：`.askllmi_numbers_subset(answer, pasted)`——回覆中出現的數字必須是貼上文字中的數字子集（允許四捨五入到 2 位），違者在 caveat 標紅「回覆含未見於貼上輸出的數字」。這是本分析的「硬查證器」，對應 Module Guider 的路徑命中率。
- **工作量**：4–6 天（含真機 E2E、雙語 guide、README 兩語版「三個分析」對照表、LIMITATIONS 改寫）。
- **風險**：(1) String 選項容量與 textarea 貼上大表格的表現 [spike]；(2) 小模型（NIM 8B、Ollama 3B）解讀品質差、易編數字——靠數字子集檢核＋caveat；(3) 隱私：貼上的是統計輸出、非原始列，與現行「只送摘要」口徑一致，但 guide 要提醒「不要貼含個案 ID 的表」；(4) 學生濫用（直接交 LLM 段落）——tutor 人格＋方向 H 的日誌是配套。
- **投報率：高**。這正是 Jonathon 定義的價值門檻（「解讀剛跑出的結果」）在**不等平台 API** 下的可達版本；教學痛點文獻最集中的一塊（APA、效果量、假設）；技術上 90% 重用 `askllmr` 骨架。

### C. 「Show what will be sent」送出前預覽＋高基數欄位／PII 防護

- **定義**：一個 Bool 選項，勾選時把**完整 prompt（system＋user）原文**顯示在結果面板、**不呼叫 LLM**；另在 `summarize_data()` 加入識別碼欄位偵測，避免把人名／ID 當 factor 水準送出。
- **情境**：教學（讓學生親眼看到「送出去的只有摘要統計」——LIMITATIONS 建議的教材點）；研究／IRB（資料保護審查可截圖存證）；對 Jonathon 的「信任邊界」關切給出可稽核的答案。
- **邊界**：相容（零網路）。
- **技術可行性**：
  - `jamovi/askllm.a.yaml`、`askllmr.a.yaml`：加 `previewPayload` Bool（default false）；u.yaml 放在 `testConnection` 旁。
  - `R/askllm.b.R`／`askllmr.b.R` `.runInner()`：在「4. 金鑰」之前插入分支——組好 `build_prompt()` 與 system prompt 後，若 `previewPayload` 為 TRUE，`answer$setContent(.askllm_wrap_html(paste(system, user)))`、meta 顯示「preview only · 0 API calls · ≈N chars」，return。所有需要的字串在該點已存在，**不需新純函式**（可加 `.askllm_preview_text(system, user)` 便於測試）。
  - PII／高基數：`R/data-summary.R` `.summ_factor()`／`.summ_character()` 加規則——`n_unique > 20 && n_unique / n_nonmissing > 0.9` 時輸出 `levels: <k> unique (identifier-like; levels withheld)` 而不列水準；新純函式 `.askllm_pii_flags(names, sample_levels)`（regex：`id|name|姓名|email|phone|電話|身分證|passport|address`；水準值符合 email／電話樣式）→ guide/caveat 附警語「以下欄位疑似含個資，建議取消勾選：…」。**現況真實缺口**：`Name` 這類字元欄位目前會把前 10 個名字（頻次最高者）送出 [證據：`.summ_character` 走 `.format_counts`]。
  - 測試：`test-data-summary.R` 加高基數案例；`test-brun.R` 加 preview 分支「零 `ask_llm` 呼叫」（mock）。
- **工作量**：1–2 天。
- **風險**：PII regex 有誤判／漏判，文案要寫成「疑似」；高基數規則會讓真正的多水準類別（例如 50 個縣市）不列水準——`maxLevels` 已是使用者可調參數，可加註。
- **投報率：高**。半天就能做出的透明度功能，直接對應 library 審查的核心疑慮，且補上一個真實的隱私漏洞。

### D. 「後記檢查表」：前提檢驗清單、效果量、遺漏值處理、樣本數／檢定力提醒

- **定義**：每則建議結尾固定附一段結構化「執行前後檢查表」：該分析在 jamovi 內的 Assumption Checks 位置（引用 catalog 真路徑）、該報告的效果量與 CI、遺漏值處理建議（依摘要中的 missing 數）、樣本數是否足夠與 jpower 建議。
- **情境**：教學（研究顯示 <25% 報告假設檢驗、效果量常漏報——把檢查表變成預設輸出即是課程設計）；研究（投稿前自查）。
- **邊界**：相容（純建議）。
- **技術可行性**：
  - `R/askllm.b.R`：新常數 `.ASKLLM_CHECKLIST_SUFFIX[[lang]]`，`.askllm_system_prompt()` 加 `checklist = TRUE` 參數（預設 FALSE 以保住既有回歸測試逐字性；a.yaml `addChecklist` Bool 預設 TRUE 由 `.runInner()` 傳入）。suffix 內容：「End with a section 'Before you report' listing: (a) assumption checks and where to tick them in jamovi (quote menu path from <installed_analyses>), (b) effect size(s) to report, (c) how to handle the missing values shown in <summary>, (d) whether n looks adequate; if a power analysis would help, suggest jpower from <available_modules>」。
  - `R/data-summary.R`：`.summ_numeric()` 加 `skew`（純 R 計算，無新依賴）與 `zero-variance` 標記，讓假設建議有資料根據；已有 `missing:` 計數。
  - 效果量／檢定力模組接地：`inst/catalog/known-modules.yaml` 已含 `esci`、`jpower` [證據]，`available_text()` 會自動列出未安裝者，prompt 只需點名。
  - `pwr` 是否在 Rj 環境：Rj 隨附 jmv 相依（car、psych、lavaan、lme4、afex、emmeans、ggplot2、BayesFactor…）[證據：docs.jamovi.org 摘要]；`pwr`／`effectsize` **未見於清單** [推論，需 spike]。R code tutor 的 `scan_rj()` 已把套件名送給 LLM，故 LLM 自然不會建議沒有的套件；跨分析引導：「要做檢定力分析請裝 jpower 或在 Rj 用 base R `power.t.test()`」。
  - payload：`addChecklist` 納入指紋（否則切換不觸發新呼叫），比照 `enable_actions` 欄位——payload 格式升 v1.5。
- **工作量**：1–2 天。
- **風險**：回覆變長（max_tokens 4096 應足）；小模型可能把檢查表寫得空泛——列入方向 F 的評分項；預設開啟會讓現有回歸測試的「逐字」預期改為「含檢查表段」。
- **投報率：高**。純 prompt＋一行摘要擴充，卻直接命中三個最常見的科研缺失。

### E. S4 grounding：被選變數各自的 Description 併入 summary

- **定義**：`summarize_data()` 在每個變數區塊多一行 `description: …`（來自 jamovi Setup 面板的 Description，即 `jmv-desc` attribute），閉合「AI／人寫描述 → 描述接地下游提問」迴圈。
- **情境**：研究（SPSS 匯入的資料經 jmvReadWrite 會把 label 轉成 `jmv-desc` [證據]，等於免費拿到 codebook）；教學（教師在發給學生的 .omv 裡預填變數說明，學生提問自動有脈絡）。與作者「匯入 codebook 檔」方向互補：本方向讀的是**已在資料裡**的描述，零檔案 I/O。
- **邊界**：相容（只讀 attribute）。
- **技術可行性**：
  - `R/data-summary.R`：`summarize_data(df, vars, max_levels, char_budget, descriptions = NULL)`；`.summ_one(name, x, max_levels, desc)` 在型別行後插 `  description: <trunc 200 chars>`；`descriptions` 為 named list，NULL 時輸出逐字不變（降級保證，既有 23 個測試不動）。
  - `R/askllm.b.R`／`askllmr.b.R`：在「2. 組 payload」前 `descs <- lapply(setNames(opt$vars, opt$vars), function(v) tryCatch(attr(self$data[[v]], 'jmv-desc'), error = function(e) NULL))`（與現行 `systemPromptVar` 讀法相同，已在真機 28.1 驗證 attribute 存在）。summary 已在 payload 指紋內，改描述即觸發新呼叫，無需改 `.askllm_build_payload()`。
  - 選項：`includeDescriptions` Bool（default TRUE）放在 `includeSummary` 下；guide 隱私句補「變數說明文字也會送出」。
- **工作量**：1 天。
- **風險**：**prompt injection 通道擴大**——Description 已被當 system prompt 用，現在又進 `<summary>`；必須以「資料」語意包裹（放在 `<summary>` 內、截 200 字元、不解讀為指令），並在 `systemPromptVar` 選中的變數上避免重複送；描述可能含個資（連動方向 C 的 PII 偵測）；4000 字元預算會更快用盡（逐變項截斷機制已在）。
- **投報率：高**。作者已列 backlog、改動面小、對 SPSS 使用者是「開箱即接地」。

### F. Prompt 品質評測與回歸：golden set、`compare-models.R` 擴充、GitHub Actions CI

- **定義**：建立可重跑的「題庫 × 資料 × 期望」評測，把現有的路徑命中率擴充為多維評分（方向 B 的數字子集、方向 D 的檢查表完整度、tutor 人格是否漏答案、redirect 邊界是否正確），並在 CI 跑離線純函式測試、以 workflow_dispatch 跑 live 評測。
- **情境**：開發（每次改 prompt／換預設模型前有量化依據；LIMITATIONS 的 18/18 數字可持續更新）；教學（`docs/LIMITATIONS` 建議用 compare-models 當教材）。
- **邊界**：相容（開發工具）。
- **技術可行性**：
  - `tools/golden/*.yaml`：每題 `dataset`（內建 iris/mtcars/ToothGrowth）、`vars`、`question`、`role`、`expect`（`analysis_keywords`、`must_mention`（如 "effect size"）、`must_not`（如 "install.packages"、"Analyses > 比較"）、`redirect_expected`）。
  - `tools/compare-models.R`：`compare_models()` 加 `golden = NULL` 參數；新純函式 `.askllm_score_answer(text, expect, legal_paths)` 回 `list(path_hits, keyword_hits, forbidden_hits, ...)`；報告加總分表。既有 `.askllm_extract_paths()`／`.askllm_check_path_hits()` 直接重用。
  - `.github/workflows/test.yml`：`r-lib/actions/setup-r` + `setup-r-dependencies` + `devtools::test()`——測試本就設計為「系統 R、不需 jamovi」[證據：README For developers]，CI 零額外條件；`eval.yml`（手動觸發，secrets 放 `NVIDIA_API_KEY`／`OPENROUTER_API_KEY`）跑 golden set 並上傳報告 artifact。
  - 順手：`tools/release-check.R` 加「每 provider 預設模型仍在 `/models` 清單」檢查（方向 A）。
- **工作量**：2–3 天（題庫 10–15 題）。
- **風險**：live 評測有配額與費用（免費層足夠：每次 ≤ 30 呼叫）；評分規則過嚴會把合理回答判錯——以「警示」而非「失敗」呈現。
- **投報率：高**。repo 已有 345 個純函式測試與 byte-identical 回歸鎖的文化，缺的只是 CI 與 prompt 層的量化，補上後方向 B／D／J 的 prompt 迭代才有安全網。

### G. 多輪對話／歷史記憶（state 存歷史、token 預算）

- **定義**：勾選「延續上一輪」時，把本分析先前的 Q&A（存於 state）以 `<previous_exchanges>` 區塊附進 prompt，並以字元預算裁舊；取消勾選即清空。
- **情境**：教學（蘇格拉底式追問需要脈絡）；研究（多步驟分析規劃，取代現在「自己把上一步摘要進問題」的手工）。
- **邊界**：相容（仍是問答）。
- **技術可行性**：
  - state 擴充：`answer$setState(list(payload, text, meta_line, has_catalog, history = list(list(q=, a=, model=, ts=))))`；`R/askllm.b.R` 新純函式 `.askllm_trim_history(history, char_budget = 6000)`（保留最近者、超預算者摘要為「(earlier turns omitted)」）與 `.askllm_history_text(history)`。
  - `R/llm-adapter.R` `build_prompt()` 加 `history_text = NULL`（NULL 逐字不變）。**不用** ellmer `set_turns()`——0.2.0 與 0.4+ 的 Turn 物件形狀不同，純文字區塊對所有版本與 provider 一致。
  - 防抖：`.askllm_build_payload()` 加 `history_hash`（`digest` 不在 Imports，用 `nchar+substr` 或內建 `utils::` 無雜湊——可用歷史長度＋最後一則問題字串作指紋）；`keepHistory` Bool 納入指紋。
  - UI：`keepHistory` Bool；歷史顯示交給方向 H 的 log item。
- **工作量**：2–3 天。
- **風險**：state 隨 .omv 成長（每輪數 KB，設上限 20 輪）；反應式重跑與「延續」語意容易讓使用者誤觸新呼叫（沿用 submit 硬閘可擋）；context 變大 → 小模型品質下降、GitHub 類 8000 token 上限（已不存在）換成 NIM 的上限需查。
- **投報率：中**。README 已把「手動摘要上一步」定為工作流程且有教學站示範，自動化的邊際價值中等；但它是方向 H 與 J 的基礎設施，若做 H/J 則一併做。

### H. 研究日誌／作業紀錄：問答紀錄 Html item＋匯出

- **定義**：結果面板新增可折疊的「Session log」：每次呼叫的時間、provider、模型、人格、問題、回覆摘要、payload 指紋前 8 碼；jamovi 內建 Export（HTML/PDF）即可帶出，另 spike `<a download href="data:…">` 一鍵下載 Markdown。
- **情境**：教學（forum t=4054 教師要的「可下載紀錄」：學生交 .omv 時 AI 互動有跡可循，Jonathon 亦說在想 forensics）；研究（再現性：把 AI 諮詢過程與最終分析一起歸檔）。
- **邊界**：相容（只記錄自己的問答，不觸碰 jamovi 其他結果）。
- **技術可行性**：
  - `jamovi/askllm.r.yaml`（與 askllmr）：加 `log` Html item（`clearWith: []`）；`R/askllm.b.R` 新純函式 `.askllm_log_html(history)`；歷史來源即方向 G 的 `state$history`（不勾「延續」也照記，只是不進 prompt）。
  - 匯出：jamovi Export 已涵蓋 Html item [推論：Html item 屬 results 樹]；`data:` URI 下載在 Electron results iframe 中是否放行 [spike]；若不行，退回「全選複製」文案。
  - 隱私：log 只存已送出的內容，不另外增加外送。
- **工作量**：1–2 天（在 G 之上）；獨立做（不含多輪 prompt）約 1.5 天。
- **風險**：.omv 體積；學生可刪 log（不是防作弊硬機制，文件須誠實：這是 provenance 不是 forensics）。
- **投報率：中高**。教學情境的直接需求、低成本、與作者「收集使用資訊」的推廣目標契合。

### I. 與 stat-skills-tutorials 深度連結：每個建議附教學章節連結

- **定義**：把姊妹站的章節做成索引（id、標題、URL、對應 jmv 分析名／關鍵字），回覆渲染時**決定性**地偵測回覆中提到的分析名稱，在 `links` item 追加「延伸學習」連結；不讓 LLM 產 URL。
- **情境**：教學（回覆 → 教材一鍵直達）；研究（初學者自學）。
- **邊界**：相容。
- **技術可行性**：
  - `inst/tutorials/index.json`（比照 `docs/learn-r.json` 結構，增加 `analyses: ["ttestIS","anovaOneW"]`、`keywords_zh/en`）；`R/askllm.b.R` 新純函式 `.askllm_tutorial_links(answer_text, catalog_hits, index)`——優先用 `.askllm_extract_paths()`（現在住在 `tools/compare-models.R`，需搬進 `R/`）抓到的 menuTitle 對應，其次關鍵字比對；輸出 `<p>Learn more: <a …></a></p>` 附加到 `links`。
  - `tools/release-check.R` `check_learn_r_links()` 擴充讀 `index.json` 做連結存活檢查（既有函式幾乎可直接用）。
  - 教學站側：需確認章節 URL／錨點穩定 [spike，屬姊妹專案]。
- **工作量**：2 天（模組側）＋索引整理（視教學站章節數）。
- **風險**：匹配精度（同義詞、中文）；教學站改版連結失效——release-check 可抓。
- **投報率：中高**。作者同時擁有兩個專案，這是最便宜的「生態綁定」；零 LLM 成本、零幻覺。

### J. 教學模式：練習題／自我測驗、學生作業回饋、教師端 prompt「軟鎖」

- **定義**：tutor 人格深化為三種教學子模式——`quiz`（依資料出 3 題選擇題並在使用者作答後給解析）、`feedback`（學生貼上自己的解讀段落，LLM 依規準評語但不改寫）、`socratic`（現行 tutor）；教師可把課程規則放進 .omv 的某變數 Description（現有 `systemPromptVar` 機制）作為「軟鎖」。
- **情境**：教學為主（作者實驗室脈絡；文獻顯示 LLM 回饋 35% 有瑕疵 → 子模式 prompt 要限制「不給答案、只指出缺漏」）。
- **邊界**：相容。**「鎖定」無法硬性執行**——學生可取消勾選、改人格、編輯 .omv；文件必須誠實稱之為「課程預設」，不承諾防繞過。若要硬鎖需 jamovi 平台層支援（不在模組能力內），列為需重新裁決的期望管理，而非邊界問題。
- **技術可行性**：
  - `jamovi/askllm.a.yaml`：`role` List 加 `quiz`／`feedback`（或另設 `teachMode` List 只在 role=tutor 時生效——後者 UI 上需 `enable` 條件，jus 3.0 支援 `enable: (role:tutor)` [推論]）；`.ASKLLM_PROMPTS` 加對應模板；`.askllm_system_prompt()` 的未知 role 落回 consultant 的防禦邏輯不變。
  - `feedback` 子模式需要「學生段落」輸入——可重用方向 B 的 `output` 貼上欄，或直接用 `question`。
  - 評測：方向 F 的 golden set 加「tutor 不得出現完整答案句」的 `must_not` 規則。
  - 教師軟鎖：純文件＋範例 .omv（`docs/teaching/`），零程式。
- **工作量**：2–3 天（prompt＋測試＋教師手冊）。
- **風險**：小模型不遵守「不給答案」；quiz 品質依賴模型；教師期待硬鎖而失望（文案）。
- **投報率：中**。與作者教學定位吻合、成本低，但價值高度依賴 F 的評測與 B 的貼上欄。

### K. 費用／token 計量顯示、快取策略、離線 Ollama 模型推薦

- **定義**：meta 行加「in/out tokens · 估計費用」；Test Connection 對 Ollama 列本機已 pull 的模型並依 choose-model 頁給建議；快取層維持現有 payload 防抖（OpenAI 相容端點無 prompt caching 可用）。
- **情境**：研究（付費 provider 時心裡有數）；教學（讓學生看到「一次提問 ≈ 2k tokens」）。
- **邊界**：相容。
- **技術可行性**：
  - `R/llm-adapter.R` `ask_llm()`：成功後 `tok <- tryCatch(chat$get_tokens(), error = function(e) NULL)`（ellmer ≥0.2；0.1 為 `tokens()`）、`cost <- tryCatch(chat$get_cost(), …)`（≥0.2；未知價格回 NA）；回傳 list 加 `tokens_in/tokens_out/cost`；`ctor` 假物件測試不受影響（欄位 NULL）。
  - `R/askllm.b.R` `.askllm_meta_line(model, elapsed, tokens_in, tokens_out, cost)`（既有二參數呼叫逐字不變）。
  - Ollama 推薦：方向 A 的 `/models` 解析已涵蓋；`docs/choose-model.html` Ollama 卡片加「依記憶體選模型」表。
- **工作量**：0.5–1 天。
- **風險**：`get_cost()` 價格表來自 LiteLLM，免費層／NIM 多為 NA → 顯示「n/a」而非 0；0.2.0 分支 API 差異需 tryCatch。
- **投報率：中低**。好做但使用者多在免費層；價值主要在教學透明度。

### L. 多語系：promptLang 擴充至日／韓／簡中；UI 翻譯

- **定義**：`.ASKLLM_PROMPTS`／`.ASKLLM_R_PROMPTS`／`.ASKLLM_RJ_SUFFIX`／caveat／guide 文字增加 `ja`、`ko`、`zh-CN`；UI 標籤走 jamovi 模組 i18n。
- **情境**：教學（日韓 jamovi 社群活躍；JASP 0.96 亦在擴語言）。
- **邊界**：相容。
- **技術可行性**：prompt 層已是 `prompts[[role]][[lang]]` 設計 [證據]，加語言＝加 named list 項＋a.yaml `promptLang` 選項；但 `.askllm_caveat_text()`／`.askllm_guide_text()`／`.askllmr_*_text()` 目前是「英＋繁中」硬編雙語段，需重構為 lang-keyed 並保留現行輸出逐字（回歸鎖）。UI 翻譯：jamovi 支援模組 `i18n/*.po`（jmvtools i18n 流程）[推論，需 spike]。
- **工作量**：每語言 2–3 天（prompt 撰寫需母語審校）＋重構 1 天。
- **風險**：作者無法審校的語言品質；guide 文字 4 語並列會太長 → 改為依 `promptLang` 單語顯示。
- **投報率：中**。市場擴張型，非核心價值；建議先做重構（lang-keyed），語言由社群貢獻。

### M. macOS／Linux `.jmo` 建置與 jamovi library 收錄準備

- **定義**：以 CI 產出 macOS（arm64/x64）與 Linux 的 `.jmo`，並整理「安全審查資料包」供 library 政策成形時送審。
- **情境**：教學／研究（學術界 macOS 比例高；目前 README 只支援 Windows 64-bit [證據]）。
- **邊界**：相容（發佈工程）。
- **技術可行性**：askLLM 本身無編譯碼，但相依（httr2→curl、openssl、S7、coro）含原生碼 → `.jmo` 平台綁定 [證據：dev.jamovi.org 摘要＋`dist/README.md`]。CI：GitHub Actions macOS runner 安裝 jamovi dmg → `jmvtools::install(home=…)`；Linux 以 flatpak/AppImage 的 jamovi 路徑 [spike]。`tools/release-check.R` 的 `JAMOVI_HOME`／`PLATFORM_TAG` 已參數化，可擴成矩陣。library 收錄：Jonathon 明言先建政策再談 [證據]，短期不可控；能做的是把方向 C（送出預覽）、F（評測）、LIMITATIONS 實測整理成「security review packet」。
- **工作量**：3–5 天（CI 不確定性高）。
- **風險**：runner 上 jamovi 安裝與 compilerr 編譯時間；每個 jamovi 大版更新需重建。
- **投報率：中高**。觸及率直接翻倍，但工程風險與維護成本不低；建議先手動在一台 Mac 建一次驗證可行，再決定 CI。

### N. ellmer tool calling：讓 LLM 主動查 catalog／known-modules／教學索引（仍不執行分析）

- **定義**：不再把 2500 字元的 catalog 硬塞進 prompt，而是註冊唯讀工具 `lookup_installed(query)`、`lookup_library(query)`、`lookup_tutorial(topic)`，由 LLM 按需查詢。
- **情境**：研究（裝了很多模組的機器：現行 `catalog_text()` 以整模組貪婪截斷，超預算的模組會被 `[+N more modules omitted]` 掉 [證據]——tool 查詢可解截斷）。
- **邊界**：相容——工具全部唯讀，回傳文字；**不得**註冊任何執行／寫入工具（與休眠的 `action-*.R` 明確切割）。
- **技術可行性**：`R/llm-adapter.R` `make_chat()` 加 `tools = NULL`，非 NULL 時 `chat$register_tool(ellmer::tool(fn, description, arguments = list(query = type_string())))`（0.4+ 簽名；0.2.0 為 `tool(fn, description, query = type_string())` → 版本分岔如現行 ctor 分支）；工具實作為 `R/llm-tools.R` 純函式，包 `scan_modules()`／`known-modules.yaml`／方向 I 的索引；`echo='none'` 與 tool 相容（NEWS：tool 與 streaming echo 不相容，非串流無妨）。provider 支援：NIM Llama 3.1、Ollama llama3.2、Gemini OpenAI 相容端點皆支援 tools [證據：搜尋摘要]；不支援時 ellmer 拋錯 → 降級為現行 inline 模式。
- **工作量**：4–6 天（含 provider 矩陣實測）。
- **風險**：每題多 1–3 次往返（延遲、配額）；小模型工具呼叫不穩；現行 inline 已 18/18，收益只在超預算情境。
- **投報率：低至中**。技術上成熟、邊界內，但目前痛點不強；建議等到有使用者回報「我的模組被 omitted」再啟動，或作為方向 I 的進階版。

### O. 對接 jamovi 官方 MCP／skills：分軌與可分享資產

- **定義**：askLLM 模組本身**不接** MCP（S6）；改把 askLLM 已驗證的接地資產（`scan_modules()`、`known-modules.yaml` 同步腳本、防幻覺 prompt 措辭、LIMITATIONS 實測）整理成可被 jmv-agent／官方 skills 引用的形式，並在官方 skills 發布後對齊 `CLAUDE.md`／開發流程（S5）。
- **情境**：開發治理；社群（Jonathon 正在建 MCP API，「implementing MCP is 98% of the job」）。
- **邊界**：相容（不改模組行為）。
- **技術可行性**：抽出 `R/module-catalog.R`＋`tools/sync-known-modules.R` 為獨立小套件（或 jmvmcp 的 toolset）；文件化「askLLM 三個接地器」規格（`specs/v1.1-module-aware.*` 已是規格級文件）。
- **工作量**：2–3 天。
- **風險**：官方 MCP 時程不可控；重複投資。
- **投報率：低至中（對 askLLM 本體）**。價值在生態與作者的社群位置，不在模組功能；建議只做「等官方 skills 出來再對齊」的被動策略。

### P. jamovi Cloud 相容性（記錄為非目標）

- **定義**：評估 askLLM 在 jamovi Cloud 的可行性。
- **結論**：Cloud 無 Rj（安全考量）、多數方案不可安裝模組、無 sideload；即使可裝，engine 對外 HTTPS 是否放行未知。**不可行且不可控**，建議在 `docs/LIMITATIONS` 與 README 安裝節加一句「Cloud 不支援」即可。
- **工作量**：0.5 天文件。**投報率：低**。

---

## 4. 總表

| # | 方向 | 投報率 | 工作量（人天） | 邊界相容 | 建議版本 |
|---|---|---|---|---|---|
| A | 供應商衛生（GitHub Models 退役處置＋`/models` 動態清單＋預設模型腐爛檢查） | 高 | 1–1.5 | ✔ | **v1.3.2 hotfix（立即）** |
| — | 文件修正：README「35 free models」、JASP「no fully local option」句 | 高 | 0.3 | ✔ | v1.3.2 |
| C | Show what will be sent＋高基數／PII 防護 | 高 | 1–2 | ✔ | v1.4 |
| E | S4 grounding：變數 Description 併入 summary | 高 | 1 | ✔ | v1.4 |
| D | 後記檢查表（前提檢驗／效果量／遺漏值／jpower） | 高 | 1–2 | ✔ | v1.4 |
| F | Prompt 評測 golden set＋CI | 高 | 2–3 | ✔（開發工具） | v1.4（CI 可先行） |
| B | 結果解讀分析（貼上 Syntax Mode 輸出 → 解讀／APA／效果量） | 高 | 4–6 | ✔，但需改寫 LIMITATIONS 第 6 點口徑 | v1.4（主打功能） |
| I | stat-skills-tutorials 深連結（決定性索引） | 中高 | 2＋索引 | ✔ | v1.5 |
| H | 問答日誌／作業紀錄（Session log） | 中高 | 1–2 | ✔ | v1.5 |
| M | macOS／Linux `.jmo`＋審查資料包 | 中高 | 3–5 | ✔ | v1.5（先手動建置驗證） |
| G | 多輪對話／歷史 | 中 | 2–3 | ✔ | v1.5（作為 H/J 基礎） |
| J | 教學模式（quiz／feedback／教師軟鎖） | 中 | 2–3 | ✔；「鎖」須誠實為軟鎖 | v1.5 |
| K | token／費用計量、Ollama 推薦 | 中低 | 0.5–1 | ✔ | v1.5（順手） |
| L | 多語系（ja/ko/zh-CN；UI i18n） | 中 | 重構 1＋每語 2–3 | ✔ | 後續（先重構，語言由社群） |
| N | ellmer tool calling（唯讀查詢工具） | 低–中 | 4–6 | ✔（唯讀工具） | 後續（有截斷回報再啟動） |
| O | 對接官方 MCP／skills（分軌、資產外借） | 低–中 | 2–3 | ✔ | 後續（被動對齊） |
| P | jamovi Cloud | 低 | 0.5（文件） | — | 非目標 |

**建議節奏**
- **v1.3.2（本週）**：A＋文件修正。GitHub Models 已死兩個月，這是信譽問題。
- **v1.4（主題：「解讀你的結果，看得見你送了什麼」）**：C → E → D → F（CI）→ B。前四項合計約 6 天、皆為小改動，先把地基與評測補齊，再用 4–6 天做 B；B 是 v1.4 的對外賣點，也是回應 Jonathon「價值天花板」的最直接證據。
- **v1.5（主題：教學工作流程）**：G → H → J → I → K；M 視手動建置結果決定是否進 CI。
- **後續**：L、N、O 依社群需求；P 記錄為非目標。

**與作者兩個既定方向的交界**：(1) 工作流程路徑圖——方向 D 的檢查表與方向 I 的深連結可作為路徑圖每個節點的「附件」；(2) 匯入外部檔案——方向 E 讀的是資料內既有描述，與 codebook 檔案匯入互補而非重疊；方向 C 的預覽對匯入的自訂提示詞同樣適用（匯入後先看會送出什麼）。

---

## 5. 來源

**Repo（`/home/user/askLLM`）**：`README.md`、`README.zh-TW.md`、`PLAN.zh-TW.md`、`DESCRIPTION`、`dev-notes/execution-plan.zh-TW.md`、`dev-notes/jasp-ai-landscape.zh-TW.md`、`dev-notes/v1.2-actionable-research.zh-TW.md`、`dev-notes/r-tutor-bridge-plan.zh-TW.md`、`dev-notes/library-submission-response.zh-TW.md`、`dev-notes/jonathon-reply-draft.zh-TW.md`、`dev-notes/M0-result.zh-TW.md`、`dev-notes/M2-result.zh-TW.md`、`docs/LIMITATIONS.zh-TW.md`、`docs/choose-model.html`、`docs/learn-r.json`、`docs/MODELS-github.zh-TW.md`、`R/*.R`、`jamovi/*.yaml`、`jamovi/js/askllm.js`、`tools/*.R`、`tests/testthat/*`、`inst/catalog/known-modules.yaml`、`dist/README.md`。

**外部**：
- GitHub Changelog：[GitHub Models is no longer available to new customers (2026-06-16)](https://github.blog/changelog/2026-06-16-github-models-is-no-longer-available-to-new-customers/)、[GitHub Models is being fully retired on July 30, 2026 (2026-07-01)](https://github.blog/changelog/2026-07-01-github-models-is-being-fully-retired-on-july-30-2026/)、[GitHub Models is now retired (2026-07-30)](https://github.blog/changelog/2026-07-30-github-models-is-now-retired/)
- ellmer：[NEWS.md（GitHub main）](https://raw.githubusercontent.com/tidyverse/ellmer/main/NEWS.md)、[DESCRIPTION](https://raw.githubusercontent.com/tidyverse/ellmer/main/DESCRIPTION)、[provider-openai-compatible.R](https://raw.githubusercontent.com/tidyverse/ellmer/main/R/provider-openai-compatible.R)、[ellmer 0.5.0 部落格（被封鎖，僅搜尋摘要）](https://opensource.posit.co/blog/2026-09-14_ellmer-0-5-0/)、[chat_ollama 參考](https://ellmer.tidyverse.org/reference/chat_ollama.html)
- JASP：[jasp-desktop releases](https://github.com/jasp-stats/jasp-desktop/releases)、[Introducing JASP 0.98](https://jasp-stats.org/2026/07/02/introducing-jasp-0-98-fully-integrated-ai-support/)、[Breakthrough Development: JASP with Fully Integrated AI](https://jasp-stats.org/2026/06/30/breakthrough-development-jasp-with-fully-integrated-ai/)、[JASP Services：Fraunhofer IPA](https://www.jasp-services.com/jasp-with-fully-integrated-ai-introduced-at-the-fraunhofer-ipa-quality-day/)
- jamovi 社群／文件：[Copy / Paste output as Text（t=1551）](https://forum.jamovi.org/viewtopic.php?t=1551)、[Feature suggestion: downloadable log (against cheating)（t=4054）](https://forum.jamovi.org/viewtopic.php?t=4054)、[Jamovi Cloud and Rj Editor（t=4151）](https://forum.jamovi.org/viewtopic.php?t=4151)、[Syntax Mode 文件](https://docs.jamovi.org/_pages/um_6_syntax_mode.html)、[Combining jamovi and R（Rj 隨附套件）](https://docs.jamovi.org/usermanual/um_6_jamovi_and_R.html)、[Distributing Modules](https://dev.jamovi.org/tutorial/tuts0110-distributing-modules/)、[jamovi MCP（yjm110517）@Glama](https://glama.ai/mcp/servers/yjm110517/jamovi-mcp)、[jmvReadWrite NEWS（jmv-desc）](https://github.com/sjentsch/jmvReadWrite/blob/main/NEWS.md)
- 教學／科研痛點：[Assumption-checking rather than (just) testing（PMC10830673）](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10830673/)、[Comparing ChatGPT Feedback and Peer Feedback…（PMC12292746）](https://pmc.ncbi.nlm.nih.gov/articles/PMC12292746/)、[Can we trust LLMs as a tutor…（arXiv 2511.04213）](https://arxiv.org/pdf/2511.04213)、[Beyond Correctness: Evaluating and Improving LLM Feedback in Statistical Education（arXiv 2511.07628）](https://arxiv.org/pdf/2511.07628)、[How to Report Effect Sizes: APA Guidelines（MetricGate）](https://metricgate.com/blogs/how-to-report-effect-sizes/)、[APA Statistics Reporting（Statoria）](https://statoria.com/tutorials/apa-reporting-statistics)
- 供應商端點：[NVIDIA NIM API Reference](https://docs.nvidia.com/nim/large-language-models/latest/api-reference.html)、[Gemini OpenAI compatibility](https://ai.google.dev/gemini-api/docs/openai)、[OpenRouter Models](https://openrouter.ai/docs/guides/overview/models)
