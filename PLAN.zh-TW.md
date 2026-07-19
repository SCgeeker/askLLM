# askLLM — ellmer 包裝為 jamovi module 實作計畫

## Context

Rj 試點成功(jamovi 內顯示 ellmer LLM 回覆)後,依核准的 v1 規格建置正式 jamovi module:**資料感知問答**——使用者勾選變項+輸入問題,模組附上變項摘要,LLM 針對「你的資料」回答,Preformatted 顯示,單輪問答,金鑰走檔案不進 UI。此為 jmv-agent 母專案「R package → jamovi module」的試點案例。總規劃由 Fable 5 完成;執行任務按難度配模型。

**關鍵環境約束(已查證)**:
- jamovi 2.7.37 bundled R 4.5.0、CRAN snapshot 2025-05-25 → compilerr 會裝到 **ellmer 0.2.0(無 `chat_openai_compatible()`,用 `chat_openai(base_url=, api_key=)` 打 OpenAI 相容端點)**;開發用系統 R 4.6.1(ellmer 0.4.2)→ 需版本適應層
- 需 compilerr 另裝的相依僅 coro/httr2/later/promises/S7 + ellmer(輕;curl/openssl 已在 snapshot)
- jamovi spawn 的 R 不繼承環境變數、HOME=%USERPROFILE%(Rj 實測)→ 金鑰四段查找鏈
- `install(home='C:/Program Files/jamovi 2.7.37.0')` 必填(Windows 自動偵測為空)
- schema 的 `Action` 型別是半成品(enum 只有 "open")→ **不可用作執行按鈕**,防抖走三層設計
- 不寫 `.u.yaml`(uicompiler 自動生成堪用 UI);`Rscript -e` 含 `\$` 會 segfault → 寫 .R 檔執行

## 模組結構

位置:`D:\core\LAB\Analysis\jmv_modules\askLLM\`(獨立 git repo)。模組名 `askLLM`。

```
askLLM/
├── DESCRIPTION            # Imports: jmvcore, R6, ellmer
├── jamovi/askllm.a.yaml   # 選項;askllm.r.yaml # 結果;不寫 .u.yaml
├── R/askllm.b.R           # R6 body(薄,~150 行,防抖狀態機)
├── R/llm-adapter.R        # ellmer 版本適應層(純函式)
├── R/llm-providers.R      # provider 對照表(純函式)
├── R/key-loader.R         # 金鑰查找鏈(純函式)
├── R/data-summary.R       # 資料摘要器(純函式)
├── tests/testthat/        # 只測純函式,系統 R 跑
└── docs/SETUP-*.md        # 各 provider 金鑰教學(繁中)
```

**a.yaml 選項**:data、vars(Variables)、question(String)、includeSummary(Bool, true)、**submit(Bool, false,防抖硬閘)**、provider(List: nim/gemini/github/ollama/custom,預設 nim)、model(String,預設 meta/llama-3.1-8b-instruct)、baseUrl(String,custom 用)、maxLevels(Integer, 10)。

**r.yaml items**(全部 `clearWith: []`):instructions(引導/錯誤/金鑰教學)、answer(回覆)、meta(模型名·耗時·cached 標記)。

**.b.R**:`.init()` 只排引導文字(三步教學+隱私提醒),零網路;`.run()` = 守門(!submit || question 空 → 引導)→ 組 payload → **state 快取比對(identical 則回放,零 API)** → 金鑰載入(敗→教學文字,不 throw)→ `ask_llm()`(tryCatch)→ setContent+setState。

## 四個純函式檔設計

1. **llm-adapter.R**:`make_chat(base_url, model, api_key, system_prompt, ctor=NULL)`——`packageVersion('ellmer') >= '0.4.0'` 走 `chat_openai_compatible`,否則 `chat_openai`(0.2.0,**必須明給 model**,其預設是 gpt-4o);`ctor` 注入點供測試塞假物件。`ask_llm(...)` 回結構化 list(ok/text/model/elapsed/error),永不 stop()。
2. **llm-providers.R**:`provider_spec(name, base_url_option)` 回 `list(base_url, env_vars, needs_key, default_model, setup_doc)`。**全 provider 統一走 OpenAI 相容端點**(gemini 用 `.../v1beta/openai/`、github 用 `models.github.ai/inference`、ollama `localhost:11434/v1` 免金鑰、custom 讀 baseUrl 選項)。
3. **key-loader.R**:`load_api_key(env_vars)` 四段鏈——Sys.getenv → readRenviron(%USERPROFILE%\.Renviron)→ readRenviron(%USERPROFILE%/OneDrive/文件/.Renviron,動態組路徑)→ readRenviron(~/.Renviron);回 `list(key, source)` 或 NULL。`key_setup_text(provider)` 回繁中教學(申請網址、.Renviron 兩個候選路徑、格式範例、重啟提醒)。
4. **data-summary.R**(opus 級):`summarize_data(df, vars, max_levels=10, char_budget=4000)`——numeric:n/遺漏/mean/sd/median/min/max(signif 4);factor:水準數+前 N 水準次數(頻次排序,超出併為 "... and K more"),水準名 cap 40 字元;edge cases:全 NA、零變異、單一觀測、NA 水準;超 budget 逐變項截斷附標記。prompt 模板:`<summary>` 包裹+「Answer about THIS dataset. Be concise.」。

## 防抖三層(反應式重跑防重複計費)

1. **submit Bool 硬閘**:未勾一律只顯示引導;改問題先取消勾選(教學明示)
2. **payload state 快取**:payload=問題+摘要+provider+model+baseUrl 的字串,與 `answer$state$payload` `identical()` 則回放,每個實質變更最多一次 API 呼叫
3. **`clearWith: []`**:state 不被選項變更清掉;`.run()` 每次主動覆寫畫面

M2 驗收需實測:String TextBox 是 commit-on-Enter 還是逐鍵(即使逐鍵,硬閘仍完全擋住)。殘餘風險:state 跨存檔行為未實測,最壞=重開檔多打一次,可接受。

## 測試策略

- **A 純函式 testthat**(系統 R 4.6.1,TDD RED→GREEN):test-data-summary(型態/遺漏/截斷/edge)、test-providers(五表全覆蓋)、test-key-loader(每段鏈+全敗+教學關鍵字)、test-adapter(ctor 注入假物件、參數傳遞、401/timeout 錯誤翻譯)
- **B live 測試**(opt-in):`skip_if(ASKLLM_LIVE_TESTS != '1')`,對 NIM 問 PONG 一條
- **C 0.2.0 路徑**:jamovi 內由 M0 煙霧與 E2E 覆蓋(bundled R 無法跑 testthat)
- **D E2E 手動腳本**(見驗證節)

## 里程碑

| 里程碑 | 內容 | 驗收 |
|---|---|---|
| **M0 最小網路煙霧(最先)** | create+addAnalysis 骨架;.b.R 硬編金鑰鏈+`chat_openai(base_url=NIM)` 一問一答;prepare+install | compilerr 裝 ellmer 0.2.0 成功(記耗時);jamovi Results 出現 NIM 回覆(證 engine HTTPS+0.2.0 可用);記錄 engine 內 ellmer 版本與 HOME |
| M0 失敗分支 | 依序:`Remotes: tidyverse/ellmer` → httr2 手打 chat/completions(httr2 在 snapshot base) | 三選一定案才進 M1 |
| M1 純函式層 | 四檔 TDD | devtools::test() 全綠;live PONG 過 |
| M2 完整整合 | 正式 yaml+.b.R+防抖;重裝 | E1–E7 全過;實測 String 觸發行為 |
| M3 多 provider+文件 | gemini/github/ollama/custom 實測;SETUP-*.md ×4 | 各 provider 成功或明確友善錯誤 |
| M4 發佈整備 | README、隱私聲明、(視需要).u.yaml、.jmo | 乾淨環境 sideload 可用;檢查清單全勾 |

## 任務委派(按難度配模型;子代理不 commit,主迴圈每波驗收後統一 commit)

| 波 | 任務 | 代理/模型 | 依賴 |
|---|---|---|---|
| W1-1 | 骨架 create/addAnalysis/git init/DESCRIPTION | sonnet | — |
| W1-2 | M0 煙霧 .b.R(硬編) | sonnet | W1-1 |
| W1-3 | M0 install+jamovi 目視驗收 | **主迴圈** | W1-2 |
| W2-1 | key-loader+providers TDD | sonnet | M0 |
| W2-2 | llm-adapter TDD(版本分岔+錯誤翻譯) | **opus** | M0 決策 |
| W2-3 | data-summary+prompt 模板 TDD | **opus** | — |
| W3-1 | 正式 a.yaml/r.yaml | haiku/sonnet | W2 全 |
| W3-2 | .b.R 整合+防抖狀態機 | **opus** | W3-1 |
| W3-3 | E2E 手動驗收 | **主迴圈** | W3-2 |
| W4-1 | provider 實測 | sonnet+主迴圈 | W3-3 |
| W4-2 | SETUP×4+README+隱私聲明 | sonnet | W4-1 |
| W4-3 | 發佈檢查+.jmo | 主迴圈 | W4-2 |

## 風險(擇要)

- ellmer 0.2.0 於 R 4.5.0 未實測 → M0 首驗,備援已排序(Remotes → httr2 手打)
- engine HTTPS 未實測 → M0 首驗
- 隱私:摘要外送 → 引導文字+README 明示;僅聚合統計不含原始列;ollama 為零外送選項
- 回覆過長 → api_args 設 max_tokens + 呈現端 cap
- 金鑰不落 .omv:金鑰只在行程環境變數,不進 options(E9 驗證 grep 不到)

## E2E 驗證(jamovi 內)

E1 空白→只有引導與隱私提醒;E2 填問題不勾 Submit→零呼叫;E3 勾 Submit→數秒得針對資料的回覆+meta;E4 無關選項變更/重勾→快取回放(meta 標 cached,NIM 用量頁對照無新呼叫);E5 改問題→恰一次新呼叫;E6 金鑰缺失→繁中教學非紅字 error;E7 斷網→友善錯誤;E8(M3)各 provider;E9 存 .omv 重開→回覆仍在且檔內 grep 不到金鑰。

參考檔:`jmv_mcp/pilot/rj-ellmer-smoke.R`(已實測金鑰鏈與 NIM 呼叫)、`jmv_mcp/inst/node_modules/jamovi-compiler/schemas/optionschemas.yaml`(選項型別權威)。

## 文件語言規範(自本計畫起生效)

**所有計畫與記錄文件以中英文「分開」儲存**:repo 內每份計畫/開發記錄/里程碑報告一律成對產出——`<名稱>.zh-TW.md`(繁體中文)與 `<名稱>.en.md`(英文),內容對等。適用範圍:本計畫存入 askLLM repo 時(`PLAN.zh-TW.md`/`PLAN.en.md`)、每波驗收記錄(`dev-notes/`)、M0 決策記錄、README(README.md 英文為主 + README.zh-TW.md)、SETUP 教學(雙語成對)。git commit 訊息維持英文(既有慣例)。W4-2 文件任務的工作量按此加倍估算。
