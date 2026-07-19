# M2 完整整合驗收記錄

日期:2026-07-20|結果:**通過**|模組版本 1.0.0

## 使用者實機驗收(jamovi 2.7.37)

| # | 驗收項 | 結果 |
|---|--------|------|
| E1 | 空白狀態只顯示引導與隱私提醒 | ✅ |
| E2 | 填問題但未勾 Submit → 零呼叫 | ✅ |
| E3 | 勾 Submit → 針對資料的回覆 + meta(模型·耗時) | ✅ NIM 2.7s / Gemini 6.5s |
| E4 | 取消再重勾 → 快取回放,meta 標 `cached`,instructions 顯示「(快取回放,未呼叫 API)」 | ✅ |
| E5 | 改問題 → 恰一次新呼叫 | ✅ |
| 等待狀態 | 送出後立即顯示「正在等候 <provider> 回覆…」 | ✅ |

**資料感知品質實證**(Gemini,勾選 Attach data summary):模組附上摘要後,LLM 正確辨識「著名的鳶尾花 Iris 資料集,1 個 3 分類的類別變數(Species)與 4 個連續型數值變數」,並逐項給出**具體 jamovi 選單路徑**(`Analyses > ANOVA > One-Way ANOVA`、`Analyses > Regression > Correlation Matrix`、`Analyses > Factor > Principal Component Analysis` 等)——正是本模組「資料感知問答」的設計目標。

## 過程中修正的缺陷(依序)

1. **問題輸入框過小且無法多行**:jamovi 標準控制項無多行輸入(schema 只有單行 TextBox,上游最新版亦然)。解法採官方唯一擴充管道——view 層 `loaded`/`updated` 事件注入 HTML `<textarea>`(仿 Rj 模組作法),原生單行框以三重策略定位後隱藏。哨兵定位法僅在 Submit 未勾時使用,避免觸發計費呼叫。
2. **textarea 溢出面板**:一度改插在 Label 之後導致水平排版溢出;最終回到原輸入框位置,寬度依面板實寬計算(260–560px),`resize: both` 保留水平+垂直拉伸。
3. **切換 provider 未帶入對應模型**:provider 下拉掛 `change` 事件自動填入該家預設模型;使用者自訂值不覆蓋。**注意**:jamovi-compiler 對控制項層事件的 yaml 鍵必須寫 `change`,寫 `changed` 會被編成空函式(值得回報上游)。
4. **Gemini 預設模型過時**:`gemini-2.0-flash` 已退役。查 ellmer 0.4.2 的 `chat_google_gemini()` 發現它也是寫死預設值;改採 Google 伺服器端別名 **`gemini-flash-latest`**(實測 HTTP 200),由 Google 自動解析到最新 flash 模型,發佈後永不過時。
5. **回覆被攔腰截斷**:`max_tokens=1024` 被 Gemini 3.x 的思考 token 吃光;提高至 4096。
6. **金鑰改抓環境變數**:jamovi engine 清洗行程環境變數,但 Windows 環境變數真正值存在登錄檔;查找鏈新增 `HKCU\Environment` 與 `HKLM\...\Session Manager\Environment` 兩段(以 `utils::readRegistry()`),排在 `.Renviron` 檔案之前。實測命中 `registry:system`。

## 等待狀態的實作

`ResultsElement$setStatus('running')` 對應 jamovi 內部 `ANALYSIS_RUNNING`(與 Bayes 類分析同一指示),配合 `private$.checkpoint()` 立即序列化並推送當下結果到畫面——否則畫面要等 `.run()` 整個結束才更新。回覆到達後轉 `complete`。

## 測試狀態

`devtools::test()`:**186 通過 / 0 失敗 / 1 跳過**(跳過為 opt-in 的 live NIM 測試)。
