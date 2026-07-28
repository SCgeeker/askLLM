# JASP 完全整合 AI 情勢調查（對 askLLM 迭代的啟示）

> 建立日期：2026-07-28
> 目的：JASP 0.98 推出「完全整合 AI」後，重新校準 askLLM 的定位與迭代方向。
> 資料來源：JASP 官方部落格與 JASP Services BV 部落格（詳見文末連結）。

---

## 一、最重要的發現：JASP 0.98「完全整合 AI」

JASP 於 **2026-06-30** 發表、隨 **0.98 版（2026-07-02）** 出貨，把 AI 直接做進本體。這代表 JASP 已踏入 askLLM 原本設想的領域，是本次迭代最關鍵的前提變化。

### JASP AI vs. askLLM 對照

| 項目 | JASP 0.98 AI | 目前的 askLLM |
|---|---|---|
| 動作形態 | **代理型（agentic）**：操控 GUI、選擇分析、執行、對結果加註解與解讀 | **諮詢型（Q&A）**：送出所選變數的摘要，回覆方法建議＋jamovi 選單路徑 |
| 人格（persona） | Alfred（顧問）／Socrates（導師）／Evelyn（解說），並可於 Preferences 自訂 | 無（單一 system prompt） |
| 供應商 | Gemini／OpenAI／Anthropic／DeepSeek／NVIDIA／OpenRouter＋自訂 endpoint | NVIDIA／Gemini／GitHub Models／Ollama／自訂 |
| 金鑰驗證 | Preferences 內建 **Test Connection** 按鈕 | 無 |
| 送給 LLM 的內容 | 分析結果、輸出本身 | **僅摘要統計量（絕不送原始資料列）** |
| 執行範圍 | 僅限 JASP 內部 | jamovi 內部 |
| 存取方式 | 需使用者自備 API 金鑰／模型（免費社群版） | 需使用者自備金鑰（或本機 Ollama 免金鑰） |

---

## 二、可直接活用於 askLLM 的迭代點

### 1. 人格選擇（投報率最高）
JASP 的 Alfred／Socrates／Evelyn 與作者在給 Jonathon 回信中確立的定位——**「常駐 jamovi 內的統計方法諮詢師」**——正好呼應。

- 作法：在 `askllm.a.yaml` 加入 role 選擇器（例：`consultant`／`tutor`／`explainer`），依選項切換 system prompt。
- 價值：對教學情境（作者實驗室脈絡）訴求強；成本低（僅 prompt 分支）。

### 2. 供應商設定追隨 JASP 更新
- **Gemini 預設模型改為 `gemini-3.5-flash-lite`**（2026-07-21 更新，免費、實質無限制）；需改 `docs/SETUP-gemini`。
- **把 OpenRouter 升為一級供應商**：免費模型須在模型名附上 `:free`；無儲值時每日 50 requests、儲值 $10+ 後每日 1000 requests——把此知識寫入 docs。
- **NVIDIA**：JASP 評價為「40 req/min、77 個免費模型、尖峰時段可用性與速度較佳」，與 askLLM 現有推薦一致，可據以補強說明。

### 3. 加入類似 Test Connection 的非課金疎通檢查
現況：askLLM 要按下 Submit 才會發生（可能計費的）呼叫。可仿 JASP 的 Test Connection，提供**僅驗證金鑰＋endpoint 的非課金選項**，讓 UX 對齊。

### 4. 隱私：由「防守」轉為「差異化賣點」
JASP 自己警告：多數免費 LLM 會用輸入資料訓練網路 → 不適合病患資料、公司資料等敏感資料。

- askLLM 的結構性優勢：**只送摘要統計量＋Ollama 可完全本機執行**，比 JASP 代理（把結果與輸出整份送出）在隱私上更安全。
- 行動：在 README／LIMITATIONS 明確點出這個不對稱優勢。

### 5. 定位再確認（面對 JASP 競爭）
JASP AI 雖強，但**僅限 JASP**。askLLM 的生存區間因此更清晰：

1. **唯一能在 jamovi 內運作**的同類工具。
2. **以本機 module-catalog 為根據，封住選單路徑的捏造**（v1.1 實測 18/18 逐字命中）。
3. **隱私最大化＋Ollama 本機**。

作者給 Jonathon 的方針——「做模組做得到、而貼進聊天視窗做不到的事」——在 JASP 登場後反而更站得住腳，(2) 正是其核心。

---

## 三、旁註：對 sibling 專案 jmv-agent（見 PLAN.md）的價值

[`jasp-agent-instructions`](https://github.com/jasp-stats/jasp-agent-instructions)（2026-06-16 更新）已提供：

- `.claude/mcp-server.R`、`session_startup.R`、`hooks/block-test-edits.js`
- 12 份規則檔、`fix-debug-analysis` 除錯技能
- 橫跨 **Claude Code／Codex CLI／GitHub Copilot** 三平台，並新增 `MIGRATION.md`

這與 PLAN.md 的六大模組幾乎一對一對應，jmv-agent 端值得**重新取得此最新版以更新基礎**。惟此屬開發工具框架，與 askLLM 終端模組為不同專案，勿混淆。

---

## 四、建議下一步（依投報率排序）

1. **人格選擇**（role 選擇器＋分支 system prompt）
2. **供應商 docs 追隨更新**（Gemini 3.5 Flash-Lite 為預設、OpenRouter 升級、NVIDIA 說明補強）
3. Test Connection 相當的非課金疎通檢查
4. README／LIMITATIONS 強化隱私差異化敘述

---

## 五、模型指引外置策略（2026-07-28 定案）

### 背景問題
寫死的 model id 腐爛速度遠快於模組發佈（例：Gemini 數週內換版）。`askllm.a.yaml`
的預設 `provider: nim` + `model: meta/llama-3.1-8b-instruct` 中，NVIDIA／GitHub 的
id 會腐爛；Gemini 已用 `gemini-flash-latest` 自動更新別名，天然免疫。

### 定案
1. **保留有主見的預設**（provider=nim + 具體 model），不學 JASP「零預設」，維持
   開箱即用；腐爛風險由外部連結（本策略）＋未來 `/v1/models` 動態列出（v1.2）吸收。
2. **自備金鑰、金鑰不落地**：沿用 env var／`.Renviron`／Windows 登錄檔查找鏈
   （見 `R/key-loader.R`），金鑰絕不寫入 `.omv`。正式公開沿用此模型即可。
3. **穩定 URL、可變內容**：`.jmo` 只 bake 一條你掌控的 GitHub Pages 連結；內容用
   git 更新、不必重送模組。載體為 **GitHub Pages 自維樞紐頁**（選項 B），頁內再深連
   結各供應商官方模型頁。

### jamovi 錨點（關鍵現實：不是 JASP 的 Qt Preferences 面板）
jus 3.0 選項側欄**無原生可點超連結 widget**，故連結放在能點的兩處：
- **分析 Help 頁（`jamovi/askllm.md`，即 `?` 說明）**——對應 JASP 右上「i」圖示；
  內容指引「如何先準備自用 API，安裝完畢後 askLLM 如何取得金鑰」。**只放穩定連結，
  勿放 model 清單**（help 檔 bake 進模組，清單放這裡又會腐爛）。
- **結果面板引導文字（HTML，已雙語）**——真 `<a href>`，跑起來即見。

### GitHub Pages 頁內容（決策式，非靜態清單）
「哪個適合你」導引：無卡→Gemini／NVIDIA；有 GitHub 帳號→GitHub Models；
要完全本機→Ollama；已有供應商→Custom（填 Base URL）。每格附：Provider 下拉值、
Model 欄值、env var 名、取得金鑰連結、免費額度、隱私標記。

原型檔：`docs/choose-model.html`（2026-07-28 建立，待貼 jamovi team Slack 請
Jonathon 等人過目後定稿）。

### 各 provider 權威資料（取自 `R/llm-providers.R`，供頁面用）
| Provider（下拉值） | env var | 預設 model | 取得金鑰 | base_url |
|---|---|---|---|---|
| NVIDIA NIM | `NVIDIA_API_KEY` | `meta/llama-3.1-8b-instruct` | build.nvidia.com | integrate.api.nvidia.com/v1 |
| Google Gemini (free) | `GEMINI_API_KEY`／`GOOGLE_API_KEY` | `gemini-flash-latest`（別名，免腐爛） | aistudio.google.com/apikey | generativelanguage.googleapis.com/v1beta/openai |
| GitHub Models | `GITHUB_MODELS_TOKEN`（優先，避免撞 gh/git） | `openai/gpt-4o-mini` | github.com/settings/tokens | models.github.ai/inference |
| Ollama (local) | 無（免金鑰） | `llama3.2` | ollama.com | localhost:11434/v1 |
| Custom | `LLM_API_KEY` | 使用者填 | 依端點 | 使用者填 baseUrl |

### 前輪三個待決點結果
1. 常青頁載體 → **GitHub Pages**（作者已受邀 jamovi team Slack，可於頻道請 review）
2. `/v1/models` 動態列出 → **列為 v1.2 future work**
3. bundled docs 去留 → **保留 SETUP 金鑰步驟（結構層），抽走會腐爛的 model 清單改連常青頁**

---

## 資料來源

- [Breakthrough Development: JASP with Fully Integrated AI（2026-06-30）](https://jasp-stats.org/2026/06/30/breakthrough-development-jasp-with-fully-integrated-ai/)
- [Introducing JASP 0.98: Fully Integrated AI Support（2026-07-02）](https://jasp-stats.org/2026/07/02/introducing-jasp-0-98-fully-integrated-ai-support/)
- [Set up a Fully Integrated AI in JASP, and Run it for Freeeee（JASP Services BV）](https://www.jasp-services.com/set-up-a-fully-integrated-ai-in-jasp-and-run-it-for-freeeee/)
- [Free API Key Hunting（updated, 2026-07-09）](https://jasp-stats.org/2026/07/09/free-api-key-hunting/)
- [jasp-stats/jasp-agent-instructions（GitHub）](https://github.com/jasp-stats/jasp-agent-instructions)
