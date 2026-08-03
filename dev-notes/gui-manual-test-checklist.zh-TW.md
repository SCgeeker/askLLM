# askLLM 本機 jamovi GUI 手測 checklist

> 建立：2026-07-29 · 對象：jasp-ai-landscape 迭代已完成的 item 1/2/3（item 4 純文件、item 5 未做）
> 適用版本：工作區 `main`（commit `233d49b` 之後）
> 背景：CI 環境 `jmvtools::check()` 找不到 jamovi，故 GUI 層一律未測；此清單供作者在本機一般版 jamovi 逐項點測。

---

## 0. 前置（環境）

- [ ] 已安裝**一般版 jamovi**（**非** Microsoft Store／MSIX 版——Store 版把 R 鎖在 WindowsApps，jmvtools 建置會失敗，見 memory `jmvtools-build-needs-nonstore-jamovi`）。
- [ ] 讓 jmvtools 找到 jamovi。先測：
  ```r
  jmvtools::check("D:/path/to/jamovi")   # home 指向 jamovi 安裝資料夾
  ```
  找到會印 jamovi 版本；找不到可改設環境變數 `JAMOVI_HOME` 後重開 R。

## 1. 重跑 prepare 交叉驗證手補的 h.R（重要）

CI 無 jamovi，`R/askllm.h.R` 的 4 個新選項（`role`／`promptLang`／`systemPrompt`／`testConnection`）與 `provider` 的 `openrouter` 選項都是**手動補**的。有 jamovi 後：

- [ ] 執行 `jmvtools::prepare(".")`，讓它由 yaml 重新產生 `askllm.h.R`。
- [ ] `git diff R/askllm.h.R`：**預期無實質差異**（僅可能行尾/排版）。若 prepare 產出與手補版**不同** → 以 prepare 產出為準，重跑一次測試（`devtools::test()`）確認全綠，並記錄差異。

## 2. 安裝到 jamovi

- [ ] `jmvtools::install(".", home="D:/path/to/jamovi")`（或省略 home 若 check 已能找到）。
- [ ] 開 jamovi → 找到 **askLLM** 選單 → 開啟「Ask LLM about your data」分析。
- [ ] 載入任一含連續＋類別變項的資料（例：內建 `mtcars` 類資料，或自備 .csv）。

---

## 3. 逐項 GUI 檢查

### 項目 1 — 人格選擇

- [V] 展開 **LLM settings** 摺疊區，確認新增三欄：**Persona**（下拉）、**Prompt language**（下拉）、**Custom system prompt**（單行寬框）。
- [V] Persona 下拉三個選項標題正確顯示 emoji：**🧭 Consultant** / **🎓 Tutor** / **💡 Explainer**（預設 Consultant）。若 emoji 變成空格/方塊 → 記錄（字型或 jus 呈現問題）。
- [V] Prompt language 兩選項：**English** / **繁體中文**（預設 English）。
- [V] **Custom system prompt** 是**寬的單行輸入框**（jus 3.0 不支援 multiline textarea；可直接貼入自訂 prompt 文字）。
- [ ] 填問題 → 勾 **Submit** → 分別切 Consultant / Tutor / Explainer 各送一次：
  - [ ] Consultant：直接給統計建議（簡潔、開處方）。
  - [ ] Tutor：以**反問引導**、不直接給答案。
  - [ ] Explainer：**定義術語**、面向初學者逐步說明。
  - （三者語氣應明顯不同——後端 live 已驗證，此處確認 GUI 有正確把 role 傳進去。）
- [ ] Prompt language 切 **繁體中文** 再送一次 → 回答語言/prompt 走中文分支。
- [ ] 在 **Custom system prompt** 貼一段自訂 prompt → 送出 → 回答**改依自訂 prompt**（覆蓋人格模板）；清空後恢復人格行為。

-> Read 20260729001.omv for check lists across lines 41-47 ~ 回答完整性與LLM有關; system prompt可讓使用者以Data Variable 編輯，再選擇匯進?

### 項目 2 — OpenRouter 供應商

- [V] Provider 下拉出現 **OpenRouter**，位置在 **Gemini 之後、GitHub 之前**。
- [V] 選 OpenRouter → Model 欄自動帶入 **`openai/gpt-oss-20b:free`**（若沒自動帶入是 js `PROVIDER_DEFAULTS` 未生效，記錄）。
- [V] 已設 `OPENROUTER_API_KEY`（`setx` 或 `.Renviron`，設完**完全重啟 jamovi**）→ 填問題 → Submit → 得到真實回覆。
- [V] 未設金鑰時 → 顯示取得金鑰指引（含 `OPENROUTER_API_KEY` 與 openrouter.ai/keys）。

-> Read 20260729002.omv

### 項目 3 — Test Connection（非課金疎通檢查）

- [V] Submit 附近出現 **Test Connection** CheckBox。
- [V] 勾 Test Connection（不勾 Submit）→ 對各 provider 顯示對應文案（**均附「金鑰來源」**）：
  - [V] NVIDIA / OpenRouter：`✓ 端點可連線（此供應商的 /models 不驗證金鑰…）`
  - [V] Gemini：`✓ 金鑰有效`（金鑰對）／`✗ 金鑰無效（400）`（故意打錯金鑰）
  - [V] GitHub Models：`✓ 金鑰有效（404）`（金鑰對）／`✗ 未授權（401）`（打錯）
  - [V] Ollama：起服務→`✓ 本機服務可連線`；未起→`✗ 服務未啟動`
- [V] **Test 優先**：同時勾 Test Connection 與 Submit → 只做連線檢查、**不呼叫 LLM**（供應商後台應顯示零 completion 消耗）。
- [V] 故意打錯金鑰做一次 Gemini/GitHub → 確認 `✗` 文案與 HTTP 碼正確。

-> 補充：Instruction 排版維持段落區塊文字語言一致，先英文再中文

---

## 4. 整合／回歸行為

- [V] **等待狀態**：送出後、回覆前，畫面顯示「正在等候…／Waiting…」而非卡死。
- [V] **快取回放**：同樣參數再按一次 → meta 出現 `· cached`、不重打 API。
- [V] **快取失效**：只改 Persona 或 Prompt language 或 Custom prompt → **重新呼叫**（非 cached），證明 role/lang/systemPrompt 已進防抖 payload。
- [V] **查證提醒**：回覆下方仍有 ⚠ caveat（選單路徑是否比對本機清單，依 includeCatalog）。
- [V] 開一份**舊 .omv**（1.1 版存的）→ 結果能正常還原、不報錯（確認新增選項未破壞相容）。 -> Test on 20260728001.omv

---

## 5. 記錄

每項填：✅通過 / ⚠️有異（附截圖或訊息）/ ⏭️略過。發現 GUI 問題就回報，我這邊對照 yaml/js/b.R 定位。特別留意：
- emoji 在 ComboBox 的實際呈現
- systemPrompt 單行寬框是否夠貼入自訂 prompt
- OpenRouter 自動帶入 model 是否生效（js 手工複本風險）
- prepare 重生的 h.R 與手補版是否一致

測完若一切正常，即可升版 `1.2.0`、`jmvtools::install()` 打包、`git push`。
