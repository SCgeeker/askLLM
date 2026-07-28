# askLLM 執行計畫（實作路線圖）

> 建立日期：2026-07-28
> 依據：`dev-notes/jasp-ai-landscape.zh-TW.md` 第四節（建議下一步，投報率排序）＋第五節（模型指引外置，已定案）
> 基準版本：askLLM 1.1.1 → 目標 1.2.0
> 規劃：Fable；兩項待決點已由作者裁決（見第四節）

## 進度（2026-07-29）
- ✅ **里程碑 A1／項目 1 人格選擇**：已實作＋主迴圈驗收（587→ 當時 556 測試綠、降級保證逐字相同）。role/promptLang/systemPrompt 三選項，emoji 人格，顯式語言選單。
- ✅ **里程碑 A2／項目 4 隱私文件**：README×2＋LIMITATIONS×2 新增隱私差異化小節，主迴圈驗收（純新增、來源可回溯）。
- ✅ **里程碑 B1／項目 2 OpenRouter**：一級供應商＋docs，主迴圈驗收（587 pass / 0 fail）。**live 實測發現**：計畫預設 `meta-llama/llama-3.3-70b-instruct:free` 已下架，改用 **`openai/gpt-oss-20b:free`**（2026-07-29 實測 HTTP 200 / cost 0）。
- ✅ **里程碑 D1／項目 3 Test Connection**：spike（推翻「200=金鑰有效」）＋實作＋主迴圈驗收（651 pass / 0 fail、8 分類分支 live+offline 皆對）。統一 `/models` GET＋per-provider override＋誠實分級文案（作者裁決）。新增 `R/llm-ping.R`、`testConnection` 選項；httr2 入 Imports。
- ⏳ **待辦**：C1／項目 5（指引外置，依賴 B、含**外部** GitHub Pages 開通＋Slack review；程式面 r.yaml Html item＋新建 askllm.md 待 Pages URL 定案）。
- ⚠️ **累積殘留**：`h.R` 因無一般版 jamovi 已**兩度手補**（item 1＋2），待有環境重跑 `jmvtools::prepare` 交叉驗證；多行 TextBox UI 未手測；`:free` 模型清單本質易腐（已證實）。尚未 commit。

---

## 零、現況與計畫的落差盤點（逐檔核對，非臆測）

| 落差點 | 現況 | 對計畫的影響 |
|---|---|---|
| **OpenRouter** | `R/llm-providers.R` **完全沒有** OpenRouter provider；只在 `docs/choose-model.html` 的 Custom 卡片以範例出現 | 「升為一級供應商」＝**新增** provider，牽動 a.yaml、providers、b.R、js、docs 五處 |
| **role 選擇器** | `askllm.a.yaml` 無 role 選項；system prompt 集中在 `askllm.b.R` 的 `.askllm_system_prompt(has_catalog)` 單一函式 | 全新選項＋prompt 分支，改動面小且封閉 |
| **Gemini 預設模型** | `provider_spec('gemini')` 已是 `gemini-flash-latest`（常青別名） | 第四節與第五節矛盾 → **已裁決保留別名**（見第四節裁決 1） |
| **Test Connection** | 完全沒有；jus 3.0 無按鈕 widget，唯一可行觸發器是仿 `submit` 的 Bool checkbox | 需新選項＋新純函式（走 `/models` GET，不產生 token 計費） |
| **結果面板可點連結** | `askllm.r.yaml` 三個 item 全是 `Preformatted`，**放不了真 `<a href>`** | **已裁決新增獨立 `Html` item**（見第四節裁決 2） |
| **help 檔** | `jamovi/` 內**沒有 `askllm.md`** | 第五節 Help 頁錨點從零新建 |
| **GitHub Pages** | `docs/choose-model.html` 原型已存在（雙語、暗色、決策式）；repo 尚未開 Pages、`.jmo` 尚無指向它的穩定連結 | 需先定 URL 規則（依賴關係源頭） |
| **UI 預設模型同步** | `jamovi/js/askllm.js` 的 `PROVIDER_DEFAULTS` 是 `R/llm-providers.R` 的手工複本 | 新增 provider 時兩處必須同步 |
| **README 隱私** | `README.zh-TW.md` 已有 Ollama 零外送敘述，但無「vs. JASP 代理式整份外送」的差異化對比 | 屬敘述強化，非新內容 |

---

## 一、各執行項目細部計畫

### 項目 1：人格選擇（role 選擇器）

**目標**：仿 JASP 的 Alfred／Socrates／Evelyn，提供 `consultant`（顧問，現行行為）／`tutor`（導師，蘇格拉底式引導）／`explainer`（解說，面向初學者逐步解釋）三種人格，依選項切換 system prompt 開頭段；catalog 約束句（防路徑捏造）三種人格一律保留。
> system prompt預設英文,依系統語言切換中文;其他語言prompt待建; 使用者可自行修改
> 人格挑代表icon讓使用者辨識

**新增要求落實（2026-07-28 作者確認，已查驗可行）**
- **預設英文**：現況即是（`askllm.b.R:103` 硬寫英文），保留。
- **依系統語言切中文**：**spike 已完成（2026-07-28），結論：查無可靠管道**。jmvcore 2.7.38 內部雖有 private `.lang` 欄位，但（1）無公開 getter、（2）`jamovi.proto` 無 language 欄位、實測本機 jamovi 28.1.0.0 無證據前端會送入 `.lang`、（3）其回退機制正是被排除的 `Sys.getenv("LANGUAGE")`／OS locale。挖 `.__enclos_env__$private$.lang` 屬未定義行為、跨版本易失效。
  - **定案 → 顯式 `promptLang` 選單**（`en`／`zh`，預設 `en`），不做自動偵測。
  - prompt 模板以 named list `prompts[[role]][[lang]]` 組織，其他語言之後在此擴充（「其他語言待建」）。
- **使用者可自行修改**：新增 `systemPrompt` String 選項（多行 TextBox，預設空）；**非空時整段覆蓋** role×lang 模板（catalog 約束句仍照 `has_catalog` 附加）。精簡明確的優先序：`systemPrompt`（非空）＞ `prompts[[role]][[lang]]`。
- **人格 icon**：jus 3.0 選項**無原生 icon 欄位**（同「無超連結 widget」限制）→ 採 **emoji 放進選項標題**：`🧭 Consultant`／`🎓 Tutor`／`💡 Explainer`，達成辨識目的、零額外機制。

**改動檔案**
- `jamovi/askllm.a.yaml` — 新增 `role` List 選項（default: `consultant`）
- `jamovi/askllm.u.yaml` — LLM settings CollapseBox 內加 ComboBox
- `R/askllm.b.R` — `.askllm_system_prompt()` 加 `role = 'consultant'` 參數；`.runInner()` 傳入 `opt$role`；**payload 必須納入 role**（否則換人格會被防抖快取誤判 cached）
- `jamovi/askllm.md`（若里程碑 C 已建）補一句說明
- 編譯：`jmvtools::prepare()` 重生 `askllm.h.R`

**實作步驟**
1. RED：先寫 `.askllm_system_prompt(role=)` 的 testthat 測試
2. a.yaml 加選項 → prepare 重生 h.R
3. `.askllm_system_prompt()` 改為 `base` 依 role 三分支；`has_catalog` 附加句邏輯不動
4. `.askllm_build_payload()` 尾端追加 `role` 欄位（role 以「新欄、預設 `'consultant'`」加入，同步更新既有 byte-identical 測試預期，明確記錄 payload 格式版本升級）
5. u.yaml 放 ComboBox；手測三種人格輸出語氣差異

**驗收標準**
- 預設 `consultant` 時，system prompt 與 v1.1 現行字串**逐字相同**
- 切換 role 後重新 Submit 觸發新呼叫（非 cached）；同 role 重跑仍走快取
- 三種 prompt 於 has_catalog=TRUE 時皆含 catalog 約束句

**TDD 測試點**（`test-role.R`）
- `.askllm_system_prompt(role='consultant')` ≡ 現行字串（回歸鎖）
- `role='tutor'`、`'explainer'` 各含特徵句、且 has_catalog=TRUE 時皆含 "recommend analyses ONLY"
- `.askllm_build_payload(..., role='tutor')` ≠ `role='consultant'`（防抖區辨）
- 未知 role 落回 consultant（防禦性）

**風險/依賴**：無外部依賴，可立即做。payload 格式變動屬預期規格升版。
**投報率**：**最高**。純本地邏輯、零網路、教學價值直接，約半天工。

---

### 項目 2：供應商追隨更新（OpenRouter 升一級供應商＋docs）

**目標**：OpenRouter 成為 Provider 下拉的一級選項；Gemini／NVIDIA docs 補強。

**改動檔案**
- `R/llm-providers.R` — 新增 `openrouter` 分支：base_url `https://openrouter.ai/api/v1`、env_vars `OPENROUTER_API_KEY`（墊 `LLM_API_KEY` 相容）、needs_key TRUE、default_model **`openai/gpt-oss-20b:free`**（2026-07-29 live 實測定稿；原計畫的 `meta-llama/llama-3.3-70b-instruct:free` 已下架）、signup_url `https://openrouter.ai/keys`、key_example `sk-or-v1-xxxx...`
- `jamovi/askllm.a.yaml` — provider options 加 `openrouter`（放 gemini 之後、github 之前）
- `jamovi/js/askllm.js` — `PROVIDER_DEFAULTS` 同步加 `openrouter`
- `R/askllm.b.R` — `.askllm_provider_name()` 加 `openrouter = 'OpenRouter'`
- `docs/SETUP-openrouter.zh-TW.md`＋`.en.md`（新建，含 `:free` 後綴規則、無儲值 50 req/日、儲值 $10+ 後 1000 req/日）
- `docs/SETUP-gemini.zh-TW.md`／`.en.md` — 補述別名目前解析到 3.5 Flash-Lite（見裁決 1）
- `docs/SETUP-nim.zh-TW.md`／`.en.md` — 補 JASP 評價（40 req/min、77 個免費模型、尖峰穩定）
- `docs/choose-model.html` — OpenRouter 從 Custom 範例升為獨立卡片；chips 的 `data-pick` 同步
- README 兩語版 provider 清單、`jamovi/0000.yaml` description 提及 OpenRouter

**實作步驟**：RED（`test-providers.R` 加 openrouter 案例）→ providers 分支 → a.yaml/js/b.R 三處同步 → prepare → docs → 用真金鑰手測 `:free` 模型。

**驗收標準**
- `provider_spec('openrouter')` 回傳完整 spec；下拉切到 OpenRouter 時 Model 欄自動帶入預設 `:free` 模型
- 無金鑰時 `key_setup_text` 正確顯示 `OPENROUTER_API_KEY` 與申請網址
- 手測：免費模型一問一答成功；429 錯誤訊息可辨識

**TDD 測試點**（`test-providers.R`）
- spec 各欄位值；env_vars 順序（OPENROUTER_API_KEY 優先）
- `.askllm_provider_name('openrouter')`
- 既有 provider spec 全部不變（回歸鎖）
- 新增「a.yaml provider options 與 provider_spec 已知名單一致」的一致性測試（讀 yaml 比對）

**風險/依賴**：OpenRouter `:free` 清單會腐爛——預設選最穩定者，細節放常青頁（軟依賴項目 5 的 URL，程式端可先行不阻塞）。
**投報率**：高。約 1 天工，直接擴大免費使用者面。

---

### 項目 3：Test Connection 非課金疎通檢查

**目標**：不燒 token 驗證「金鑰找得到＋端點通＋權限夠」。


**設計要點**（jus 3.0 無按鈕，只能仿 `submit` 的 Bool 觸發器）
- 對 `{base_url}/models` 發 **GET**（OpenAI 相容目錄端點，不產生 completion 計費）。用 `httr2`（build 目錄已 vendor，零新依賴），`req_timeout(10)` + `req_error(is_error=function(resp) FALSE)` 讓 4xx/5xx 不拋例外、直接讀 status。
- **統一 URL、per-provider 狀態碼 override 表**（見下方 spike 結果）。

**spike 結果（2026-07-29 live 實測，推翻原「200=金鑰有效」假設）**
`GET /models` 對所有 provider 皆零計費，但**能否鑑別金鑰有效性因 provider 而異**：

| provider | 探測 URL | 有效金鑰 | 無效/無金鑰 | 能鑑別金鑰？ |
|---|---|---|---|---|
| nim | `/v1/models` | 200 | **200（相同清單）** | ❌ **僅證端點可達**（/models 公開不驗證） |
| openrouter | `/v1/models` | 200 | **200（相同清單）** | ❌ 同上 |
| gemini | `/v1beta/openai/models` | 200 | **400** `"pass a valid API key"` | ✅（需認 400 為金鑰無效） |
| github | `/inference/models` | **404** `page not found` | **401** `Unauthorized` | ✅（**404=通、401=失敗**；auth 在 route 檢查之前） |
| ollama | `/v1/models` | N/A（免金鑰） | 連線失敗 | ✅（無服務即連線失敗，正確） |
| custom | 使用者填 | 未驗證 | 未驗證 | ⚠️ 推論：部分自架（vLLM）亦不驗證金鑰 |

**判讀採「共用預設＋per-provider override」**：預設 200=通/401=金鑰無效/403=權限/連線失敗=網路；github override：404 也算通；gemini override：400+body 含 api key 視為金鑰無效。**github 不用 catalog fallback**（catalog 公開、任何金鑰皆 200，無鑑別力）。
- 沿用 `translate_error`：ping 內把 status+body 組成合成訊息再丟給它走既有 regex 分支（不改 `translate_error` 本身）；github 的 404=成功不進 error path，直接 `ok=TRUE`。
- **UX 誠實鐵則**：nim/openrouter/custom 的成功文案**不可寫「金鑰有效」**，只能寫「端點可連線」＋加註「此供應商的 /models 不驗證金鑰」。

**改動檔案**
- `jamovi/askllm.a.yaml` — 新增 `testConnection` Bool（default false）
- `jamovi/askllm.u.yaml` — CheckBox 放 LLM settings 內
- `R/llm-ping.R`（新檔，維持 adapter 單一職責）— 純函式 `ping_endpoint(base_url, api_key, needs_key)` → `list(ok, status, error)`，永不 stop()
- `R/askllm.b.R` — `.runInner()` 守門段前插入：`testConnection` 勾選時走 ping 分支，結果寫入引導 item（含金鑰來源 `load_api_key()$source`），**然後 return，不進入 LLM 呼叫**
- 防抖：ping 結果也需 state 快取（payload = base_url+model+provider）

**實作步驟**：RED（注入假 transport）→ `ping_endpoint()` → a/u.yaml → b.R 分支 → 五個 provider 各手測（含故意打錯金鑰驗證 401 文案）。

**驗收標準**
- 勾 Test Connection：各 provider 顯示「✓ 連線成功（金鑰來源：…）」或明確錯誤；**供應商後台可驗證零 token 消耗**
- Test Connection 與 Submit 同時勾選時，Test 優先、不觸發計費呼叫
- Ollama（免金鑰）與 custom（自填 baseUrl）都能 ping

**TDD 測試點**（`test-ping.R`）
- 注入假 transport：200/401/403/timeout 四情境結構化回傳
- `needs_key=FALSE`（ollama）不附 Authorization header
- b.R 決策：testConnection=TRUE 時不呼叫 `ask_llm`（mock 驗證零呼叫）

**風險/依賴**
- ~~GitHub Models /models 行為~~ **已 spike 解決**（見上表：404=通、401=失敗，不用 catalog fallback）。
- **未 live 驗證**：custom（無可測端點，推論）、github 403（手上 token 皆有權限，未重現）、gemini 專用金鑰（只測 GOOGLE_API_KEY）。實作時對 github 403 分支保守處理。
- **產品決策待定**：nim/openrouter/custom 的 `/models` 不驗證金鑰 → Test Connection 對這些 provider 只能保證「可連線」。文案語意需作者定調（見下）。
**投報率**：中高。UX 對齊 JASP，並把金鑰查找鏈可視化（過去 M0 除錯痛點）。約 1–1.5 天工。

---

### 項目 4：README／LIMITATIONS 隱私差異化

**目標**：把「只送摘要統計量＋Ollama 全本機」從防守敘述升級為與 JASP 的結構性對比賣點。

**改動檔案**（純文件，零程式）
- `README.zh-TW.md`／`README.md` — 新增「隱私設計 vs. 代理式 AI」小節：對照表（askLLM 送摘要統計 vs. JASP agentic 送整份結果與輸出；引 JASP 官方訓練資料警語），點名敏感資料（病患、公司資料）情境
- `docs/LIMITATIONS.zh-TW.md`／`.en.md` — 「綜合使用建議」後補一節，同口徑並交叉連結 README
- 措辭原則：**對比資訊架構差異，不貶低 JASP**（作者已在 jamovi team Slack，措辭要能公開被 Jonathon 看到）

**驗收標準**：兩語版一致；敘述可回溯到 JASP 官方部落格來源；不出現無法佐證的比較句。
**TDD**：不適用（純文件，依全域規則 skip）。
**風險/依賴**：無，可與任何項目並行。
**投報率**：中。半天內完成，對 library 收錄審查敘事直接有用。

---

### 項目 5：模型指引外置（GitHub Pages 常青樞紐頁）

**目標**：`.jmo` 只 bake 一條作者掌控的穩定 URL；會腐爛的 model 知識全部外移。
> Check https://jasp-stats.org/2026/07/09/free-api-key-hunting/ for alternative info.

**參考頁佐證（2026-07-28 抓取確認）**：該文佐證項目 2／裁決 1 的數據——Gemini 3.5 Flash-Lite（免費、實質無限）、OpenRouter `:free`＋無儲值 50／儲值 $10+ 後 1000 req/日、NVIDIA 40 req/min＋77 免費模型（尖峰穩定度優於 OpenRouter）。**GitHub Models 與 Ollama 該文未提**，兩者仍以我方自有 `SETUP-github`／`SETUP-ollama` 為準。此頁可作為 `choose-model.html`「免費金鑰哪裡拿」的深連結對象。

**子任務與改動檔案**
1. **開通 GitHub Pages**：`docs/choose-model.html` 發佈為 `https://scgeeker.github.io/askLLM/choose-model.html`（或設 `docs/` 為 Pages root）。**這條 URL 一經 bake 進 `.jmo` 不可再改**——先定案路徑。
2. **新建 `jamovi/askllm.md`**（分析 Help 頁，對應面板 `?`）：內容＝「如何準備自用 API → 安裝後 askLLM 如何取得金鑰」結構性說明＋**只放穩定連結，不放 model 清單**。
3. **`jamovi/askllm.r.yaml`**：**新增獨立 `Html` item 專放引導**（保留現有 `Preformatted` 給錯誤訊息，不驚動 `.askllm_guide_text()` 的純文字排版）；`R/askllm.b.R` 對此 item 補真 `<a href>` 指向常青頁。
4. **docs 瘦身**：各 `SETUP-*.md` 保留金鑰步驟（結構層），抽掉 model 清單改連常青頁；`MODELS-github.*.md` 內容併入常青頁後標 deprecated 或移除。
5. **choose-model.html 定稿**：併入項目 2 的 OpenRouter 卡片後，貼 jamovi team Slack 請 Jonathon 等人過目再定稿發佈。

**驗收標準**
- 面板 `?` 開得出 help 且連結可點；結果面板引導文字的 `<a href>` 在 jamovi 內實際可開瀏覽器
- Pages URL 上線且 html 為最新版；`.jmo` 內不再有任何寫死的第三方 model 清單（`gemini-flash-latest` 等選項預設除外，屬「有主見的預設」定案範圍）
- git push 後頁面更新、無需重發模組（實測一次）

**TDD 測試點**
- r.yaml 新增 Html item 後 `test-brun.R` 全綠（setContent 目標回歸）
- 引導文字含常青 URL 的字面測試（防未來重構誤刪）
- html/help 內容以人工檢視驗收，不入 testthat

**風險/依賴**
- 新增 Html item 影響舊 `.omv` 結果還原——需在真 jamovi 開舊檔驗證。
- Slack review 是外部等待點：發佈可先行（審稿用 URL 不變，內容 git 可改），不阻塞。
- 項目 2 的 OpenRouter 卡片應**先**併入，避免定稿後又改版。
**投報率**：中高但工序最長（約 2 天＋外部 review 等待）。唯一「一次做對、終身省維護」的項目。

---

## 二、建議實作順序（里程碑）

```
里程碑 A（即刻，可並行）
 ├─ A1. 項目 1 人格選擇          ← 投報率最高，零依賴
 └─ A2. 項目 4 隱私文件          ← 純文件，零依賴

里程碑 B（A 後或與 A 並行）
 └─ B1. 項目 2 OpenRouter 一級供應商＋docs 補強
        （Gemini 預設依裁決 1 保留 gemini-flash-latest 別名）

里程碑 C（依賴 B）
 └─ C1. 項目 5 模型指引外置
        （choose-model.html 須含 B1 的 OpenRouter 卡 → 定 Pages URL
         → 新建 askllm.md help → r.yaml 加 Html item → Slack review）

里程碑 D（依賴 B，與 C 可並行）
 └─ D1. 項目 3 Test Connection
        （先 spike GitHub Models 的 /models 可行性；
         放在 B 後是為了讓 openrouter 一併納入 ping 測試矩陣）

收尾：版本升 1.2.0，一次 jmvtools::install() 全量手測五（六）個 provider。
```

**依賴／並行關係總表**

| 項目 | 依賴 | 可與誰並行 |
|---|---|---|
| 1 人格 | 無 | 2、4 |
| 2 OpenRouter | 無 | 1、4 |
| 3 Test Connection | 軟依賴 2（provider 名單定稿） | 5 |
| 4 隱私文件 | 無 | 全部 |
| 5 指引外置 | 硬依賴 2（常青頁含 OpenRouter 卡再定稿）；Slack review 為外部等待 | 3 |

---

## 三、跨項目工程注意事項

- **雙處同步**：`R/llm-providers.R` 與 `jamovi/js/askllm.js` 的 `PROVIDER_DEFAULTS` 為手工複本，任何 provider 增修兩處都要動，並以一致性測試鎖住。
- **payload 格式版本**：項目 1（加 role）與項目 3（Test Connection）都動到防抖快取的 payload 組成，需明確記錄格式升版並同步既有 byte-identical 測試預期。
- **TDD**：R 程式改動一律走 `tdd-r`（RED → GREEN → REFACTOR）；純文件項目（4、help/html 內容）依全域規則 skip。
- **編碼**：所有 LLM I/O 與檔案讀寫維持 UTF-8；RStudio 2 空格縮排。

---

## 四、待決點裁決紀錄（2026-07-28，作者確認）

1. **Gemini 預設模型** → **保留 `gemini-flash-latest` 別名**（採第五節定案）。程式端不改；`docs/SETUP-gemini.*` 補述「別名目前解析到 3.5 Flash-Lite」＋JASP 對照。
2. **結果面板引導 item** → **新增獨立 `Html` item**，保留現有 `Preformatted` 給錯誤訊息（改動面小、不驚動 `.askllm_guide_text()`）。

---

## 資料來源

- `dev-notes/jasp-ai-landscape.zh-TW.md`（本計畫上游）
- 現有程式碼：`R/askllm.b.R`、`R/llm-providers.R`、`R/llm-adapter.R`、`R/key-loader.R`、`jamovi/askllm.{a,r,u}.yaml`、`jamovi/js/askllm.js`
