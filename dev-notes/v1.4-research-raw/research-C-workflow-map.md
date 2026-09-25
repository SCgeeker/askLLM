# 研究 C：askLLM「統計問題 → 分析工作流程路徑圖（workflow path map）」可行性與設計方案

日期：2026-09-25 · 基準版本：askLLM 1.3.1（commit `6235f98`）· 研究員：Fable
標記約定：**[證據]** = 本 repo 原始碼／上游原始碼／dev-notes 實測可回溯；**[推論]** = 由證據推導但未實測；**[待 spike]** = 必須在真 jamovi 或真 provider 驗證後才能定案。

---

## 0. 執行摘要（結論先行）

1. **產品形態：建議做成 jamovi Module Guider 的一個輸出模式（`outputMode: answer | workflow`），不是第三個分析、不是人格。** 理由：路徑圖的「零捏造」價值完全建立在 Module Guider 既有的 catalog 接地鏈（`scan_modules()` → `catalog_text()` → 約束句 → 逐字比對）之上；做成 Guider 的模式可 100% 重用，且與 S1 的雙向 prompt 邊界相容（Rj 節點只做「指向 R code tutor 的指標」，不在 Guider 內產碼）。第三個分析 `askllmw` 是可行的 Phase 2 升級路徑（當選項與結果項膨脹到影響 Guider 的簡潔時再拆）。人格方案直接否決（人格改語氣、不改輸出結構）。詳 §1。
2. **呈現技術：推薦「R 端由同一份 workflow JSON 決定性地生成三種呈現」——(1) `Html` 結果項放 HTML/CSS 步驟卡（節點＝方塊、分岔＝縮排子清單、必要時 inline SVG 畫分岔箭頭）；(2) `Table` 結果項放逐步清單（含「已比對／未比對」欄，最適合 .omv 存檔與匯出）；(3) `Preformatted` ASCII 樹作最終降級與可複製版本。** Mermaid（需 JS）否決；`Image`（grid/ggplot2）技術可行但列為選配。降級鏈：結構化 JSON 成功 → 三種呈現；JSON 失敗（小模型）→ 落回現行純文字 answer 並標示「本次無法產生路徑圖」。詳 §2。
3. **LLM 輸出結構：擴充既有 `ask_llm_structured()` 三段降級鏈為「可注入 parser」的通用版**，新增 `workflow` schema（nodes / edges / conditions / 每節點 menu_path・rj_pointer・rationale・checks）；驗證器 `validate_workflow()` 以 catalog 逐字比對 menu_path、以 `scan_rj()$packages` 比對 Rj 套件名，未通過節點**保留但降級標示**（不刪、不改寫、不代替 LLM 補路徑）。詳 §3。
4. **知識接地：stat-skills-tutorials 目前是「素養教程＋提示詞庫＋查核清單」的 Quarto 站，不是決策樹 KB，也沒有機器可讀索引；`docs/learn-r.json` 只是連結索引。** 建議在 `inst/catalog/workflow-kb.yaml` 自帶一份精簡雙語決策 KB（15–25 個設計樣板，節點以 jmv 分析 `name` 為鍵、執行期映射到本機 catalog 路徑），`includeKb` 開關控制；預估每次多 1.5–2.5k tokens。純靠模型是可接受的降級，但品質差異主要在「前提檢驗與分岔」這段。詳 §4。
5. **copilot 邊界：完全相容。** 路徑圖只是建議；新增 `progressNotes` String 選項（使用者自填「已完成步驟＋結果摘要」），納入 payload 指紋，LLM 據以重規劃並把已完成節點標 ✓。不做任何自動勾選（askLLM 不讀分析輸出，這是平台限制）。詳 §5。
6. **工作量：約 14–19 人天，分 M0 spike → M1 純函式（TDD）→ M2 KB → M3 渲染器 → M4 接線＋GUI E2E → M5 進度回填 → 收尾文件。** 最大風險依序：小模型結構化輸出失敗率、真機 Html 渲染／匯出行為、token 上限（4096 輸出）、payload 指紋漏納新選項導致快取誤判。詳 §6。

---

## 1. 產品定義

### 1.1 路徑圖應包含什麼

**[推論]**（綜合 README「迭代工作流程」段、`dev-notes/execution-plan` S1、LIMITATIONS §2「假設檢查請用 jamovi 內建 Assumption Checks」）

路徑圖是「研究問題 → 一連串使用者親手執行的 jamovi 步驟」的有向圖，節點與邊定義如下：

| 節點種類 `kind` | 內容 | 對應動作載體 |
|---|---|---|
| `question` | 研究問題重述（一句）＋設計判定（幾組？獨立／相依？依變項尺度？） | 無（純文字） |
| `data_check` | 資料檢查：缺失值、極端值、分布、樣本數 | 已安裝 catalog 路徑（如 `Analyses > Exploration > Descriptives`） |
| `assumption` | 前提檢驗：常態性、變異數同質、球形性、線性…；**明列要看哪個表／哪個 p 值** | catalog 路徑（多半是主分析內的 Assumption Checks 子面板，需標「在 X 分析的 Assumption Checks 區勾選 Y」） |
| `decision` | 分岔節點：條件文字（如「Shapiro-Wilk p < .05」）→ 兩條以上 outgoing edges | 無 |
| `main` | 主分析 | catalog 路徑 |
| `effect_size` / `posthoc` | 效果量／事後比較（常是主分析面板內的勾選項） | catalog 路徑＋勾選項描述 |
| `report` | 報告要點：要抄哪些數字、APA 句型骨架 | 無 |
| `gap` | **本機沒有對應分析**：指向 (a) `<available_modules>` 中逐字存在的模組名，或 (b) 「改用 R code tutor，建議提問：…」 | `available_text` 模組名 或 R code tutor 指標 |

邊：`from → to`，選填 `condition`（分岔標籤）。典型分岔：常態性不符 → 無母數（`Analyses > T-Tests > Independent Samples T-Test` 內勾 Mann-Whitney U 或 `Analyses > ANOVA > One-Way ANOVA (Kruskal-Wallis)`）；變異數不齊 → Welch；>2 組 → ANOVA 而非多次 t 檢定。

每個節點附：`menu_path`（**必須逐字出自 catalog**，否則留空）、`options_hint`（面板內要勾什麼，自由文字，不驗證）、`rationale`（一句為什麼）、`checks`（看哪個數字、判準）、`rj_pointer`（僅 `gap` 節點：給 R code tutor 的建議提問，**不含程式碼**）。

### 1.2 與現有 Module Guider 的差異

| 面向 | 現行 Module Guider（answer） | 路徑圖（workflow） |
|---|---|---|
| 輸出 | 一段散文＋若干逐字路徑 **[證據 `askllm.r.yaml` 僅 `answer` Html]** | 結構化圖：節點／邊／條件，可機械驗證每個節點 |
| 時間軸 | 回答「現在該用哪個分析」 | 回答「從問題到報告的整條路，含分岔與前提檢驗順序」 |
| 驗證粒度 | 事後抽取路徑比對（`dev-notes/catalog-hit-rate.md` 18/18）**[證據]** | 逐節點驗證結果**渲染在圖上**（✓／⚠ 未比對／✗ 不存在） |
| 迭代 | 使用者把上一步結果摘要進下一題 **[證據 README]** | 同上，另加 `progressNotes` 讓圖上標記進度並重規劃（§5） |
| 前提檢驗 | 常被省略或籠統 **[證據 LIMITATIONS §2]** | 由 KB 樣板強制作為節點出現（§4） |

### 1.3 三種落地形態比較

| | A. Module Guider 選項 `outputMode` | B. 第三個分析 `askllmw` | C. 第四個人格 |
|---|---|---|---|
| 重用 catalog 接地鏈（`.askllm_gather_context`、`.ASKLLM_CATALOG_SUFFIX`、`build_prompt`） | 直接重用 **[證據 `askllm.b.R:65-88`、`llm-adapter.R:100-183`]** | 需複製 `.runInner()` 骨架（現 `askllmr.b.R` 即為此模式，214 行）**[證據]** | 重用 |
| 與 S1 雙向邊界（Guider 不產 R 碼）相容 | 相容：`gap` 節點只給 R code tutor 指標 | 需第三套邊界句（w ↔ askllm ↔ askllmr 三向） | 相容 |
| a.yaml / u.yaml / js 改動 | 加 1 List（`outputMode`）＋1 String（`progressNotes`）＋1 Bool（`includeKb`）；`askllm.js` 不動 | 全套 provider 選項第三份複本；`PROVIDER_DEFAULTS` 第三份手工複本 **[證據 execution-plan「雙處同步」→ 變三處]** | 加 1 enum 值 |
| r.yaml 改動 | 加 `workflowMap`(Html)、`workflowSteps`(Table)、`workflowText`(Preformatted)，`visible` 依模式切 | 全新 r.yaml | 無（但無處放圖） |
| payload 指紋 | v1.5：加 `output_mode`、`progress_notes`、`include_kb` | 獨立 | 加 role 值即可 |
| .h.R | `jmvtools::prepare` 重生（S2 規則）**[證據]** | 同 | 同 |
| 使用者心智模型 | 「同一個 Guider，切成路徑圖模式」；答案與圖可並存 | 選單三個入口，需自己判斷差別 | 人格＝語氣，把結構塞進去違反 `.ASKLLM_PROMPTS` 的設計（三人格 base 只定身分）**[證據 `askllm.b.R:120-166`]** |
| 結構化輸出失敗時的降級 | 自然：落回 answer 模式，圖區顯示「本次無法產生路徑圖」 | 需自建降級呈現 | 無法降級（人格不能「失敗」） |
| 未來擴充空間 | 若選項再增（例如 KB 分類篩選、圖形樣式），Guider 面板會擠 | 空間大 | 無 |

**推薦：A（Module Guider 選項）先行；B 作為 Phase 2 的拆分選項，條件是 A 的選項數 ≥ 3 個以上且 GUI 手測回饋面板過擠。C 否決。** [推論]

補充：`inst/catalog/known-modules.yaml` 有 **Statkat（Method Selection Tool）** **[證據 L36-40]**——它正是「依研究問題與測量尺度選方法」的 jamovi 模組。路徑圖的 `question` 節點可在使用者未裝 Statkat 時，透過 `available_text` 機制合法提及它（名字逐字在清單中）。這是與既有零捏造規則相容的「推薦安裝」路徑。

---

## 2. 呈現技術：在 jamovi 結果面板畫「路徑圖」

### 2.0 上游事實（決定一切的地基）

**[證據]** jamovi client `client/resultsview/html.js`（master，2026-09 抓取）：

- Html 結果項的內容以 jQuery **`$content.html(doc.content)`** 直接插入 DOM；**沒有任何 sanitizer（無 DOMPurify）**，不剝 inline `style`、不剝 `<svg>`。
- `doc.stylesheets` 每項以 `$.get('module/' + ss)` 抓回後塞成 `<style class="module-asset">`；`doc.scripts` 每項以 `<script src="module/…" class="module-asset">` 追加到 `<head>`——即 **JS/CSS 只能是「模組隨附資產」，路徑相對模組目錄**。
- `render()` 開頭先 `this.$head.find('.module-asset').remove()`，再插入內容；`a[href]` 點擊統一導到 `window.openUrl(href)`（外開瀏覽器）。
- `image.js`：圖片以 **CSS `background-image: url('res/<path>')`** 顯示，尺寸取 `element.width/height`；無 SVG 特別處理。

**[證據]** jmvcore（CRAN 鏡像 `cran/jmvcore` `R/html.R`、`R/image.R`）：

- `Html$setContent(content)` **直接存 `private$.content`，不經 knitr**；另有獨立 `knit()` 方法才走 `knitr::knit()` 並抽 `knitMeta$script/stylesheet`。`asProtoBuf()` 送 `content / scripts / stylesheets` 三欄。
- `Image$new(options, width=400, height=300, renderFun=, requiresData=, mode='raster', …)`；`saveAs()` 支援 PNG（優先 `ragg::agg_png`，否則 `grDevices::png`）、PDF（`cairo_pdf`）、SVG（`svg()`）、EPS、PPTX（`export::graph2ppt`）。渲染由 `self$analysis$.render(funName=renderFun, image=self, …)` 呼叫模組的 `.plotFun(image, ggtheme, theme, ...)`。
- jamovi issue #1529（未解）：透過 `htmltools::htmlDependencies()`＋knit 路徑附掛 CSS/JS 會遺失依賴。**對本方案無影響**（我們走 `setContent` + inline，不走 `knit()`）。

**[證據]** jamovi-compiler `schemas/resultelementschemas.yaml`：結果元素型別 = Table / Image / Group / Array / Preformatted / Html / Output / Action；Html 允許欄位 `name,type,title,description,visible,clearWith,refs,content`；Image 允許 `width,height,renderFun,requiresData,…`。

**[證據]** 本 repo 已在真機依賴 Html + inline `style`：commit `8c02010`（`<pre style="white-space:pre-wrap; …">`）。該 commit 訊息當時標「待 GUI 驗證」，但 client 原始碼證實無過濾，且後續 v1.3.x 截圖／發版未回退 → **inline style 在 jamovi Html 中有效** [證據＋推論]。

**[證據]** bundled R 套件：jmv `DESCRIPTION` Imports 含 **ggplot2**、GGally、ggrepel、dplyr…；**無 igraph、DiagrammeR、ggraph、gridExtra、patchwork**；`grid` 是 base R 內建套件（一定有）。`semPlot`（會拉 igraph）僅在 Suggests，不隨 jamovi 出貨 [推論]。

### 2.1 逐一評估

| 途徑 | 可行性 | 優點 | 缺點／風險 | 判定 |
|---|---|---|---|---|
| **(a) Preformatted ASCII 樹** | ✅ 確定可行（現行 `instructions/meta` 即 Preformatted）**[證據]** | 零風險、.omv 完整保存、可整段複製到筆記；小模型／Ollama 亦可（只要 JSON 通過即決定性生成） | `white-space: pre` 長行不換行會溢出（`8c02010` 的根因）**[證據]** → 行寬須在 R 端硬限（≤ 72 字）；CJK 等寬對齊在 jamovi 字型下不保證 [待 spike]；表達分岔靠縮排，複雜圖可讀性差 | **保留為最終降級＋可複製版** |
| **(b) Html + R 端 inline SVG（無 JS）** | ✅ 可行（`.html()` 不過濾 `<svg>`）**[證據 html.js]** | 真正的「圖」；無外部依賴；.omv 內以字串保存；可用 `viewBox` + `width:100%` 自適應面板寬 | SVG `<text>` 不自動換行（需 R 端斷行或 `<foreignObject>`）；版面配置（layout）要自己算——建議限制為「主幹垂直、分岔一層」的鐵路圖，不做通用 DAG layout；匯出 PDF/Word 是否保留 inline SVG [待 spike]；深色主題無（jamovi 目前僅淺色）[推論] | **推薦：分岔區用 SVG，節點主體用 HTML/CSS 方塊（見 b′）** |
| **(b′) Html + 純 HTML/CSS 步驟卡（無 SVG）** | ✅ 可行（inline style 已在真機生效）**[證據 8c02010 + html.js]** | 文字自動換行、雙語 CJK 無對齊問題、最容易做「✓ 已比對／⚠ 未比對」的視覺標示、`<a href>` 可連到 tutorials 站 | 分岔只能用縮排／箭頭字元（→ ↳）表達，不如 SVG 直觀 | **推薦主體** |
| **(c) Html + Mermaid（需 JS）** | ⚠ 技術上可能、產品上不宜 | 語法簡潔，LLM 很會寫 Mermaid | (1) JS 只能是模組資產（`module/…`），Mermaid 打包 ≈ 2.5–3 MB 進 `.jmo`；(2) `render()` 先移除 `.module-asset` 再插內容，script 載入是非同步，**沒有 hook 能在內容插入後可靠呼叫 `mermaid.run()`** **[證據 html.js 流程]**；(3) 在沒裝 askLLM 的機器開 `.omv`，只剩 Mermaid 原始碼文字；(4) 不能用 CDN：Ollama 離線情境＋`JAMOVI_NETWORK_SANDBOX=1` **[證據 v1.2 研究 §3.3]**；(5) LLM 直接寫 Mermaid 會繞過驗證器（路徑寫在圖裡）；(6) Electron 結果 iframe 的 CSP 未知 [待 spike] | **否決** |
| **(d) Image + grid/ggplot2** | ✅ 可行（grid 為 base、ggplot2 隨 jmv 出貨）**[證據]**；DiagrammeR/igraph 不可用 | 原生 jamovi 圖片項；匯出 PNG/SVG/PDF/PPTX 走官方路徑 **[證據 image.R saveAs]**；.omv 保存圖檔 | 要自己寫 layout + 用 `grid.roundrect/grid.text/grid.lines(arrow=)` 畫；CJK 字型在 ragg/png 下是否正確（Windows 預設字型缺中文）[待 spike]；固定 `width/height` 不隨節點數自適應（可 `setSize`）；點不了連結；文字多時擠 | **選配（Phase 2 匯出需求出現時再做）** |
| **(e) jmvcore Table 逐步列表** | ✅ 確定可行（Table 是 jamovi 最成熟的元素）**[證據 compiler schema]** | 最佳 .omv／Word／PDF 匯出相容；欄位天然承載「步驟、節點、路徑、條件、驗證狀態」；排序穩定 | 非「圖」；分岔要用「條件」欄描述；本 repo 目前沒用過 Table（需在 h.R 由 prepare 生成 `Table$new(columns=…)`，b.R 用 `addRow`）[推論] | **推薦並列：Table 是「可靠層」，Html 是「可讀層」** |

### 2.2 推薦組合與降級鏈

```
workflow JSON（已驗證）
   ├─ workflowMap   (Html)         ← b′ HTML/CSS 步驟卡；分岔用 inline SVG 小箭頭圖（b）
   ├─ workflowSteps (Table)        ← e：Step | Kind | Action (menu path / gap) | Condition | Verified
   └─ workflowText  (Preformatted) ← a：ASCII 樹（可複製；Html 若在某環境失效仍有此層）

降級鏈（由 R 端決定，使用者不需操作）
   段1 chat_structured() 成功 ──▶ 三層全出
   段2 純文字 JSON 成功    ──▶ 三層全出（meta 註 method=json）
   段3 非 JSON            ──▶ answer 顯示純文字回覆；workflow* 三項顯示
                               「本次模型未能輸出結構化路徑圖（method=text）；
                                 建議換較大模型或改回 answer 模式」
```

**小模型／Ollama 可用性** [推論]：段2「純文字要求 JSON」對 8B 級模型的成功率取決於 schema 深度；因此 schema 設計採**扁平**（nodes 為物件陣列，edges 為物件陣列，字串欄位為主，不用巢狀物件）——與 `action-schema.R` 為 ellmer 相容性採扁平的既有決策同構 **[證據 `action-schema.R:123-130` 註解]**。並在 prompt 給一個 6 節點的極簡範例（few-shot）。

### 2.3 渲染器設計要點（R 端純函式，TDD 友善）

- `render_workflow_html(wf)`、`render_workflow_ascii(wf, width = 72)`、`render_workflow_rows(wf)`（給 Table）三個純函式，同輸入同輸出，不碰 jmvcore。
- 所有 LLM 字串經 `.askllm_html_escape()` **[證據 `r-tutor.R:87-93`]** 後才進 HTML，杜絕 LLM 注入 `<script>`（因為 client 不 sanitize，這一層必須由我們做）。
- Html 樣式全部 inline（無 `<style>` 區塊依賴），跟 `8c02010` 同一策略。
- 驗證狀態視覺：✓ 綠框（menu_path 逐字命中）、⚠ 灰虛線（未比對：includeCatalog 關或掃描失敗）、✗ 紅框並附「此路徑不在本機清單」（比對失敗，**路徑文字照顯不改寫**，供教學示範幻覺）。
- `gap` 節點顯示「本機無對應分析 → 可安裝：<模組名>」或「→ 改用 Analyses ▸ askLLM ▸ R code tutor，建議提問：…」（與 `.ASKLLM_R_REDIRECT_SUFFIX` 措辭一致）**[證據 `askllm.b.R:196-205`]**。

---

## 3. LLM 輸出結構：schema、降級鏈、驗證器

### 3.1 現況可重用件 [證據]

- `ask_llm_structured(chat, prompt, action_type, max_actions)`：段1 `chat_structured` → 段2 純文字 JSON → 段3 純文字；**但 parser 寫死為 `parse_plan()`（action plan）**（`action-schema.R:96-121`）。
- `parse_plan()` 已處理 ellmer 對 `type_array(type_object)` 回 **data.frame** 的怪癖（2026-08-02 E2E bug）（`action-schema.R:44-46`）——workflow parser 必須沿用同一防禦。
- `make_chat()` 建的物件在 ellmer ≥ 0.4 原生有 `$chat_structured()`；ellmer 0.2.0（舊 jamovi）無 → 自動走段2 **[證據 v1.2 研究 §3.4、§4.4]**。
- 測試模式：以 `list(chat_structured=, chat=)` 假物件離線測三段（`test-action-structured.R`）**[證據]**。

### 3.2 建議改動：把降級鏈通用化（不破壞既有測試）

```r
# action-schema.R（既有簽名保持相容；新增 parser 注入點）
ask_llm_structured <- function(chat, prompt, action_type = NULL, max_actions = 3,
                               parser = function(raw) parse_plan(raw, max_actions),
                               json_hint = '…action-plan schema (keys: reply, actions)…')
```
既有呼叫不帶 `parser/json_hint` → 行為逐字不變（降級保證，比照 `build_prompt` 的 byte-identical 慣例）**[推論，依 repo 慣例]**。workflow 端呼叫 `ask_llm_structured(chat, prompt, .askllm_workflow_type(), parser = parse_workflow, json_hint = <workflow keys>)`。

### 3.3 workflow schema（扁平，ellmer 0.4.x `type_*` DSL）

```r
.askllm_workflow_type <- function() ellmer::type_object(
  .description = "A step-by-step analysis workflow the USER will run in jamovi.",
  reply = ellmer::type_string("One-paragraph overview in the persona voice."),
  nodes = ellmer::type_array(items = ellmer::type_object(
    id        = ellmer::type_string("Short id, e.g. n1"),
    kind      = ellmer::type_enum(values = c('question','data_check','assumption',
                  'decision','main','effect_size','posthoc','report','gap')),
    title     = ellmer::type_string("Node label (<= 60 chars)"),
    menu_path = ellmer::type_string(
      "Menu path copied EXACTLY from <installed_analyses>, or empty string.",
      required = FALSE),
    options_hint = ellmer::type_string("Which boxes to tick inside that panel.", required = FALSE),
    checks    = ellmer::type_string("What number/table to look at and the decision rule.", required = FALSE),
    rationale = ellmer::type_string("Why this step.", required = FALSE),
    rj_pointer = ellmer::type_string(
      "ONLY for kind=gap: a question to ask the 'R code tutor' analysis. No code.",
      required = FALSE))),
  edges = ellmer::type_array(items = ellmer::type_object(
    from = ellmer::type_string(), to = ellmer::type_string(),
    condition = ellmer::type_string("Branch label, e.g. 'normality violated'; empty if unconditional.",
                                    required = FALSE))))
```

上限（`parse_workflow(raw, max_nodes = 12, max_edges = 20)`）：防 prompt-injection 濫炸與 4096 輸出 token 上限（§6 風險）。JSON 範例（供段2 few-shot 與測試 fixture）：

```json
{"reply":"…","nodes":[
 {"id":"n1","kind":"question","title":"Do two independent groups differ on score?"},
 {"id":"n2","kind":"data_check","title":"Descriptives by group","menu_path":"Analyses > Exploration > Descriptives","options_hint":"Split by group; tick Shapiro-Wilk, Histogram","checks":"n per group, missing, outliers"},
 {"id":"n3","kind":"decision","title":"Normality OK?","checks":"Shapiro-Wilk p ≥ .05 and |skew| < 1"},
 {"id":"n4","kind":"main","title":"Independent samples t-test (Welch)","menu_path":"Analyses > T-Tests > Independent Samples T-Test","options_hint":"tick Welch's, Effect size, Homogeneity test"},
 {"id":"n5","kind":"main","title":"Mann-Whitney U","menu_path":"Analyses > T-Tests > Independent Samples T-Test","options_hint":"tick Mann-Whitney U"},
 {"id":"n6","kind":"report","title":"Report t/U, df, p, effect size, CI"}],
 "edges":[{"from":"n1","to":"n2"},{"from":"n2","to":"n3"},
  {"from":"n3","to":"n4","condition":"yes"},{"from":"n3","to":"n5","condition":"no"},
  {"from":"n4","to":"n6"},{"from":"n5","to":"n6"}]}
```

### 3.4 驗證器 `validate_workflow(wf, catalog_paths, available_names, rj_packages, colnames)`（純函式、永不 stop）

| 檢查 | 資料來源 | 未通過處置 |
|---|---|---|
| `menu_path` 逐字 ∈ catalog 路徑集合 | `scan_modules()` → 每條 `.catalog_analysis_line()` 去掉前導空白與 `— subtitle` 後的 `Analyses > … > Title` **[證據 `module-catalog.R:196-204`]**；建議新增純函式 `catalog_paths(scanned)` 回傳 character 集合（與 `catalog_text()` 同源，不另造格式） | `verified = 'miss'`（✗），**路徑照顯**；另做「寬鬆比對」（大小寫／全形半形／去多餘空白）只用來提示「疑似指 X」，不自動改寫 |
| includeCatalog 關或掃描失敗 | `catalog_paths` 為 NULL | 全部 `verified = 'unchecked'`（⚠），caveat 沿用 `.askllm_caveat_text(has_catalog=FALSE)` 的誠實措辭 **[證據]** |
| `gap` 節點提到的模組名 | 必須逐字 ∈ `known$modules[].name` 且 ∉ installed（即 `available_text` 的集合）**[證據 `available_text()`]** | 不在集合 → 改標「無法核對的模組名」 |
| `rj_pointer` 不得含程式碼 | regex：`library\(|::|<-|function\(|install\.packages` | 命中 → 該欄清空並 note「已移除程式碼（請至 R code tutor）」——維持 S1 邊界 |
| （若未來允許 Rj 節點）套件名 | `scan_rj()$packages` ∪ base/recommended 名單 **[證據 `rj-env.R`]** | 未知套件 → ⚠ |
| 圖結構 | `edges` 的 `from/to` 都存在於 `nodes`；無孤立節點；至少一條從 `question` 出發的路徑；偵測環 | 壞邊丟棄＋note；有環 → 只渲染 Table/ASCII，不畫 SVG |
| 欄名（`options_hint/checks` 內若引用變數） | `names(self$data)`（比照 `.validate_arg` 的 colname 檢查）**[證據 `action-validate.R:48-52`]** | 只做提示，不拒絕（這些欄位是自由文字） |

回傳 `list(nodes = <每節點加 verified, notes>, edges, rejected_edges, notes, stats = list(hit, miss, unchecked))`；`stats` 寫進 `meta` 行（例如 `model · 6.1s · paths 5/6 verified`）——延續 `catalog-hit-rate` 的可量化精神。

### 3.5 Prompt 組裝

- system prompt：`.askllm_system_prompt(role, lang, custom, has_catalog)` 後再附 `.ASKLLM_WORKFLOW_SUFFIX[[lang]]`（僅 `outputMode == 'workflow'` 時附加，比照 `enable_actions` 的條件式附加模式）**[證據 `askllm.b.R:286-302`]**。核心句：「Plan the whole path the USER will run; put assumption checks before the main analysis; every `menu_path` must be copied exactly from `<installed_analyses>` or left empty; for anything not installed use kind=gap; never write R code here.」
- user prompt：`build_prompt()` 不改（降級保證）；KB 段（§4）與 `<progress>` 段（§5）以新參數 `extra_blocks` 插在 `<available_modules>` 之後、指令段之前 [推論，需保證 `extra_blocks = NULL` 時 byte-identical]。

---

## 4. 知識接地：決策樹 KB 從哪來

### 4.1 現有來源盤點 [證據]

| 來源 | 實況 | 可直接當決策樹 KB？ |
|---|---|---|
| **stat-skills-tutorials**（`scgeeker.github.io/stat-skills-tutorials/`；本環境 egress 阻擋，改讀 GitHub repo 頁與 `_quarto.yml`） | Quarto 站；sidebar：**Literacy 6 個模組**（LLM 能力、提問、評估準則、分析選擇、進階解讀、分析後步驟）、**Prompts 提示詞庫**（pre-render 由腳本彙整）、**Verify 4 份**（工作流程指南、兩種人格查核清單、錯題辨識練習）、External 閱讀地圖（psyteachr 五本、lsj-book、bradduthie stats）。無 JSON/YAML 索引。 | ❌ 是素養／提示詞／查核清單，**不是**「設計 → 檢定」決策樹。可作為節點的 `learn_url`（Html 節點附連結）與 `report` 節點的查核清單來源 |
| `docs/learn-r.json` | `{version, updated, sections[{id,title_en,title_zh,links[{id,title,url,license,level,tags}]}]}`，供 `tools/release-check.R` 檢查連結存活 | ❌ 純連結索引；但其**格式**（雙語 title、`tags`、`level`）值得沿用為 KB 條目骨架 |
| jmvmcp「雙語統計決策 KB」 | 僅見於 `dev-notes/v1.2-actionable-research` §6（作者本機 `D:\Apps\R\R-4.6.1\library\jmvmcp`，v0.2.0）；公開網路搜尋查無此套件 | ⚠ 內容未見；若作者手上有，**是最佳種子**（已雙語、已對齊 jmv 分析名）[待 spike：請作者匯出該 KB 的 schema 與條目數] |
| known-modules.yaml 的 Statkat | 官方 library 的方法選擇工具 | 可作 `gap`／推薦安裝節點，不是 KB 本體 |

### 4.2 三種接地策略

| 策略 | 做法 | token 成本（每次呼叫） | 品質 | 判定 |
|---|---|---|---|---|
| **P0 純靠模型** | 只加 workflow 後綴句 | +150 tokens | 主分析選擇大致正確（LIMITATIONS §2 已證）；**前提檢驗、分岔、效果量常漏或順序錯**；小模型更差 | 作為 `includeKb=FALSE` 的降級 |
| **P1 bundle 精簡 YAML KB（推薦）** | `inst/catalog/workflow-kb.yaml`：15–25 個「設計樣板」，每條：`id`、`when`（適用問法關鍵字 en/zh）、`steps`（kind、jmv 分析 `name`、options_hint、checks）、`branches`（條件 → 替代 `name`）。R 端 `kb_text(kb, char_budget = 3000)`（比照 `catalog_text` 的貪婪截斷）**[證據 `.greedy_truncate`]**；**選取**：以問題關鍵字（`when`）打分取前 3 條塞進 `<decision_kb>`，全落空則塞索引行（每條一行） | 3 條 × ~350 字元 ≈ 1.0–1.3k tokens；索引模式 ≈ 400 tokens | 前提檢驗與分岔由樣板保證；LLM 負責「套用到這份資料＋措辭」；驗證器把 jmv `name` 映射到本機路徑（`scan_modules()` 的 `analyses[].name` 就是 jmv 分析名，如 `ttestIS`）**[證據 `module-catalog.R:112-125`]** | **推薦** |
| **P2 兩段式（先選樣板再展開）** | 第一次呼叫只給索引請模型選 id；第二次給完整樣板生成 | 兩次呼叫、延遲加倍、計費加倍 | 最省 context，適合 8k 上下文小模型 | 選配（僅 Ollama 小模型自動啟用）[推論] |

**KB 內容來源** [推論]：以 lsj-book（Navarro & Foxcroft，jamovi 官方教科書，CC BY-SA）章節結構為骨架（t 檢定、ANOVA、迴歸、卡方、相關、因素分析、信度），對齊 jmv 26 個分析名 **[證據 v1.2 研究 §3.3 清單]**；作者若有 jmvmcp KB 則直接轉檔。雙語欄位比照 `learn-r.json` 的 `title_en/title_zh`。**KB 是資料不是程式**：內容錯誤只影響建議品質，不影響安全（驗證器仍以 catalog 為準）。

**token 總帳（P1，cloud 模型）** [推論]：system ≈ 250 + summary ≈ 300–600 + catalog ≤ 2500 字元 ≈ 800 + available ≤ 900 字元 ≈ 300 + KB ≈ 1.2k + progress ≈ 200 + 指令 ≈ 150 → **輸入 ≈ 3.2–3.6k tokens**；輸出 JSON 8–12 節點 ≈ 1.2–2.0k tokens（`max_tokens = 4096` 夠用，但 zh 模式字元較貴，需保留 12 節點上限）。Ollama 8B（8k context）勉強可行，建議 `includeKb` 索引模式 + `max_nodes = 8`。

---

## 5. 與 copilot 邊界的相容性

**相容，且比動作模式更貼近 S1 精神** [證據 `execution-plan` S1 邊界宣告]：路徑圖的每個節點都是「你去點」，askLLM 不執行、不寫欄、不驅動 UI。`gap` 節點也只是指標。

**進度回填設計（`progressNotes`，String 選項）** [推論]：

- jus 3.0 無動態 checkbox 清單 widget（同「無按鈕」限制，`execution-plan` 項目 3）**[證據]**，故用一個寬單行 TextBox（`width: largest`，同 `question`）。使用者填自由文字，建議格式在引導文字示範：`done n2,n3; n3: Shapiro p=.03 (violated)`。
- R 端純函式 `parse_progress(text)` 抽 `done` 的節點 id 集合（regex `\bn\d+\b`），其餘原文進 prompt 的 `<progress>` 區塊。LLM 指令：「Nodes listed as done are complete; do not re-plan them; use the reported results to choose the branch and continue.」
- 渲染：已完成節點標 ✓（HTML/Table/ASCII 三層一致）；決策節點若進度文字已含判定，圖上該分岔加粗。
- **payload 指紋必納入 `progress_notes`**（v1.5 格式），否則改進度不觸發新呼叫（同 role 納入指紋的教訓）**[證據 `askllm.b.R:23-32`]**。
- 不做的事：不讀 jamovi 結果、不自動勾選、不持久化進度到資料集（Output 欄路徑已休眠且違反 S1）。進度只活在選項字串（隨 .omv 的 analysis options 保存，重開檔案仍在）[推論：jamovi 選項本來就存進 .omv]。
- 與現行迭代法（把摘要寫進 question）的關係：`progressNotes` 是它的結構化版；兩者並存，`question` 仍是主問題。

---

## 6. 工作量估算、里程碑與風險

### 6.1 里程碑（TDD 於系統 R 離線跑；GUI 於作者本機 jamovi 28.2）

| 里程碑 | 內容 | TDD 測試點 | GUI E2E 驗收 | 人天 |
|---|---|---|---|---|
| **M0 spike** | (1) 在現行 `answer` Html 塞一段 inline SVG＋CSS 方塊，真機看渲染、存 .omv 重開、匯出 PDF/HTML；(2) `chat_structured()` 對 workflow schema（巢狀陣列）在 NIM llama-3.1-8b、Gemini flash、OpenRouter gpt-oss-20b、Ollama 8B 各跑 5 次記成功率／method；(3)（選配）grid 畫 3 節點流程圖在 Image 項，確認 CJK 字型 | 無（spike 不入 testthat） | 記錄於 dev-notes | 1.5–2 |
| **M1 純函式** | `parse_workflow()`（含 data.frame 列轉換）、`validate_workflow()`、`catalog_paths()`、`parse_progress()`、`ask_llm_structured(parser=)` 通用化 | RED→GREEN：合法/缺欄/超上限/壞邊/環/路徑命中/miss/unchecked/gap 模組名/rj_pointer 含碼剝除/data.frame 來源；既有 `test-action-structured.R` 全綠（回歸鎖） | — | 3 |
| **M2 KB** | `workflow-kb.yaml` 15–25 條雙語樣板；`kb_select()`、`kb_text()`；`build_prompt(extra_blocks=)` | 截斷預算、選取打分、`extra_blocks=NULL` byte-identical 回歸鎖、yaml 結構驗證測試（比照 `test-sync-known-modules.R`） | — | 3–4（含內容撰寫 2） |
| **M3 渲染器** | `render_workflow_html/ascii/rows`；escape；✓/⚠/✗ 標示；gap 措辭 | 快照式字面測試（含 escape 注入 `<script>`）、ASCII 行寬 ≤ 72、Table rows 欄數固定 | — | 2 |
| **M4 接線** | a.yaml：`outputMode`、`includeKb`、`progressNotes`；u.yaml；r.yaml 三項（`visible` 依模式）；`.runInner()` 分支；payload v1.5；`jmvtools::prepare` 重生 h.R；caveat 加一句「路徑圖為建議，步驟由你執行」 | payload 指紋翻轉測試（三個新選項各自→新 payload）；`.askllm_decide` 回歸；h.R 由 prepare 產生後 `git diff` 無實質差異 | 依 `gui-manual-test-checklist` 格式新增章節：answer 模式行為逐字不變；workflow 模式三層呈現；cached 回放；小模型 method=text 降級文案；舊 .omv（1.3.1）開啟不紅字 | 3 |
| **M5 進度回填** | `progressNotes` → `<progress>` → ✓ 標示與重規劃 | `parse_progress` 邊界；prompt 含 `<progress>` 段落 | 兩輪迭代實測（第 1 輪規劃 → 填 done n2 + 結果 → 第 2 輪圖更新） | 1 |
| **收尾** | README×2、LIMITATIONS×2 新節、`0000.yaml` description、版本 1.4.0、dist | 純文件 skip | 全 provider 各一問 | 1.5 |
| **合計** | | | | **15–17.5 人天**（含 M0 選配 Image 則 +1.5） |

### 6.2 風險登錄

| # | 風險 | 等級 | 對策 |
|---|---|---|---|
| 1 | **小模型結構化輸出失敗**（8B 級對巢狀陣列 JSON 常掉欄／截斷）[推論；M0 量化] | 高 | 扁平 schema＋few-shot＋`max_nodes`；段3 降級文案；`choose-model.html` 加「路徑圖模式建議模型」段；Ollama 自動用索引式 KB |
| 2 | **Html 渲染／匯出**：inline SVG 在 PDF/Word 匯出、舊版 jamovi client 差異 [待 spike M0] | 中 | Table 層保底（匯出最穩）；SVG 只用於分岔小圖，主體用 HTML/CSS |
| 3 | **token 上限**：`max_tokens = 4096`（`askllm.b.R:609`）**[證據]**；zh 輸出更貴 | 中 | `max_nodes ≤ 12`、`checks/rationale` 限長（schema description 標 ≤ 120 chars）；workflow 模式可把 `max_tokens` 提到 6144（provider 允許時） |
| 4 | **.omv 相容**：新增 r.yaml 三項；舊檔開啟時項目缺 state | 中 | `clearWith: []` 沿用；`visible` 依 `outputMode`；M4 E2E 開 1.3.1 產的 .omv 驗證（`execution-plan` 項目 5 同類風險曾列）**[證據]** |
| 5 | **payload 快取指紋漏納新選項** → 切換模式／改進度顯示舊圖 | 中（易犯） | 三個新選項全部進 `.askllm_build_payload()`（v1.5），各寫翻轉測試（同 role 教訓） |
| 6 | **LLM 內容注入 Html**（client 不 sanitize）**[證據 html.js]** | 中 | 所有字串過 `.askllm_html_escape()`；渲染器測試含 `<script>`、`onerror=` 注入案例；不接受 LLM 直接輸出 HTML/SVG/Mermaid |
| 7 | **KB 內容錯誤**（統計建議偏誤） | 中 | KB 是 YAML 資料、可由作者／社群 PR 修；每條標 `source`（lsj-book 章節）；LIMITATIONS 明示 KB 不是權威 |
| 8 | **prompt injection 經由變數名／水準名** | 低（已有先例對策） | 驗證器不信任任何 LLM 字串；node 上限；全圖含被拒項可稽核（同 v1.2 §4.3） |
| 9 | **Guider 面板過擠**（第 3 個新選項後） | 低 | 觸發拆為 `askllmw` 的門檻（§1.3） |
| 10 | **.h.R 手改誘惑**（CI 無 jamovi） | 低（有規則） | S2：一律 `jmvtools::prepare` 重生 **[證據]** |
| 11 | **ellmer 版本差**（0.2.0 無 `chat_structured`） | 低 | 段2 自動接手（既有設計）**[證據 v1.2 §4.4]** |

---

## 7. 待 spike 清單（合併）

1. 真機 jamovi 28.2：Html 內 inline SVG／CSS 方塊渲染、存 .omv 重開、匯出 PDF／HTML／Word 的保真度；Electron 結果 iframe 是否有 CSP（僅為記錄，方案不依賴 JS）。
2. 四個 provider × workflow schema 的結構化輸出成功率與 `method` 分布（各 ≥ 5 次）。
3. （選配）grid 在 ragg/png 下的 CJK 字型（Windows）。
4. 作者本機 jmvmcp v0.2.0 的「雙語統計決策 KB」schema 與條目，可否轉為 `workflow-kb.yaml` 種子。
5. jamovi 對 `Table` 動態 `addRow` 在 `clearWith: []` 下的 cached 回放行為（本 repo 首次用 Table）。

---

## 8. 證據索引

| 主張 | 位置 |
|---|---|
| Html 內容以 jQuery `.html()` 插入、無 sanitizer、scripts/stylesheets 走 `module/` 資產、`a[href]`→`window.openUrl` | jamovi/jamovi `client/resultsview/html.js`（master） |
| Image 以 CSS background-image 顯示 `res/<path>` | jamovi/jamovi `client/resultsview/image.js` |
| 結果元素型別與 Html/Image/Table/Preformatted 允許欄位 | jamovi/jamovi-compiler `schemas/resultelementschemas.yaml` |
| `Html$setContent` 不經 knit；`knit()` 才抽依賴；`Image` 建構參數與 `saveAs` 裝置 | cran/jmvcore `R/html.R`、`R/image.R` |
| htmltools 依賴遺失（未解） | jamovi/jamovi issue #1529 |
| jmv Imports 含 ggplot2；無 igraph/DiagrammeR/ggraph | jamovi/jmv `DESCRIPTION` |
| inline style 已在真機使用（Html + `<pre style>`） | 本 repo commit `8c02010`、`R/r-tutor.R:114-119` |
| 三段降級鏈與 data.frame 防禦 | `R/action-schema.R:44-46, 96-121`；`tests/testthat/test-action-structured.R` |
| catalog 掃描格式（`name`/menuGroup/…、`Analyses > … > Title — subtitle`） | `R/module-catalog.R:112-125, 196-204` |
| Rj 套件掃描 | `R/rj-env.R:42-88` |
| 條件式 system prompt 後綴模式、雙向邊界句 | `R/askllm.b.R:171-302` |
| payload 指紋教訓（role/lang/system_prompt 必納入） | `R/askllm.b.R:16-49` |
| S1 copilot 邊界、S2 .h.R 永不手改、jus 3.0 無按鈕/multiline | `dev-notes/execution-plan.zh-TW.md` |
| ellmer 結構化輸出可用、扁平 schema 決策、provider 覆蓋率待測 | `dev-notes/v1.2-actionable-research.zh-TW.md` §3.4、§4.2、§4.7 |
| 路徑幻覺與 v1.1 18/18 零捏造；假設檢查應用 jamovi 內建 | `docs/LIMITATIONS.zh-TW.md` §1、§2 |
| Statkat 方法選擇模組在官方 library | `inst/catalog/known-modules.yaml:36-40` |
| stat-skills-tutorials 站結構（Literacy/Prompts/Verify/External，Quarto，無 JSON 索引） | github.com/scgeeker/stat-skills-tutorials（README、`_quarto.yml`；站本身在本環境被 egress 阻擋） |
| `learn-r.json` 結構 | `docs/learn-r.json` |
| jmvmcp 公開查無 | WebSearch 2026-09-25（僅見 yjm110517/jamovi-mcp、lerlerchan/rstudio-mcp-server） |
