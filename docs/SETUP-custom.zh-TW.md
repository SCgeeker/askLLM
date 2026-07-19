# 設定 Custom(自訂 OpenAI 相容端點)

## 這是什麼

「Custom」讓你接上**任何 OpenAI 相容的 API 端點**,例如自架的 vLLM、LM Studio、text-generation-webui,或其他未內建於本模組的雲端服務。適合已有自己的模型伺服器、或想用尚未內建支援的 provider 的使用者。是否免費、是否需信用卡,取決於你所接的服務本身。

## 取得金鑰

視你所接的服務而定:

- 若是自架服務(如區網內的 vLLM/LM Studio),通常**不需要真正的金鑰**,但欄位仍需填一個非空字串(可填任意字串,如 `local`)。
- 若是需要金鑰的雲端 OpenAI 相容服務,請依該服務官方文件申請金鑰。

## 設定金鑰

askLLM 讀取環境變數 **`LLM_API_KEY`**。以下擇一方法設定,方法 A 較簡單。

### 方法 A:Windows 環境變數(推薦)

開啟 PowerShell,執行(引號內換成你的金鑰,或自架服務可用的任意字串):

```powershell
setx LLM_API_KEY "你的金鑰"
```

或由「設定 > 系統 > 關於 > 進階系統設定 > 環境變數」新增使用者變數 `LLM_API_KEY`。

### 方法 B:寫入 .Renviron 檔案

用純文字編輯器開啟(若不存在則新建)以下其中一個檔案:

- `%USERPROFILE%\.Renviron`
- `%USERPROFILE%\OneDrive\文件\.Renviron`
- `%USERPROFILE%\OneDrive\Documents\.Renviron`(視 OneDrive 語系資料夾名稱而定,兩者擇一存在即可)

加入一行:

```
LLM_API_KEY=你的金鑰
```

**設定後,務必完全關閉並重新啟動 jamovi,新的環境變數才會生效。**

## 在 askLLM 中使用

- **Provider** 下拉選單選「Custom OpenAI-compatible」。
- **Base URL (custom provider)** 欄位**必填**:填入你的端點網址,例如自架 vLLM 常見為 `http://localhost:8000/v1`,LM Studio 常見為 `http://localhost:1234/v1`。若留空,畫面會顯示提醒並停止呼叫。
- **Model** 欄位**必填**:custom provider 沒有內建預設模型,請填入該端點上實際可用的模型名稱。

## 常見問題

| 畫面訊息 | 代表意義 | 處理方式 |
|---|---|---|
| custom provider 需要填寫 baseUrl 選項 | Base URL 欄位是空的 | 填入端點網址後重新勾選 Submit |
| 此 provider 未提供預設模型,請在「Model」欄位填入模型名稱 | Model 欄位是空的 | 填入該端點實際可用的模型名稱 |
| 尚未設定 ... 的 API 金鑰 | 找不到 `LLM_API_KEY` | 依「設定金鑰」重新設定並重啟 jamovi(自架服務可填任意非空字串) |
| 金鑰無效或過期,請檢查 .Renviron | 金鑰不被端點接受 | 確認端點是否要求金鑰、格式是否正確 |
| 端點或模型名錯誤(model: ...) | Base URL 或 Model 名稱錯誤 | 確認端點是否已啟動、路徑是否含 `/v1` |
| 無法連線,請檢查網路 | 端點未啟動、網址錯誤或防火牆阻擋 | 確認自架服務正在執行,且網址/連接埠正確 |
