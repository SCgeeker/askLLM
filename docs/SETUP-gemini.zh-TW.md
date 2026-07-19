# 設定 Google Gemini API 金鑰

## 這是什麼

Google Gemini 由 Google AI Studio 提供,**有免費額度、不需信用卡**即可取得金鑰。金鑰經雲端 API 呼叫,問題與資料摘要會傳送到 Google 伺服器。

## 取得金鑰

1. 前往 <https://aistudio.google.com/apikey>,以 Google 帳號登入。
2. 點選「Create API key」(或「建立 API 金鑰」)。
3. 複製產生的金鑰。

## 設定金鑰

askLLM 依序嘗試環境變數 **`GEMINI_API_KEY`**、**`GOOGLE_API_KEY`**(有一個即可)。以下擇一方法設定,方法 A 較簡單。

### 方法 A:Windows 環境變數(推薦)

開啟 PowerShell,執行(引號內換成你的金鑰):

```powershell
setx GEMINI_API_KEY "你的金鑰"
```

或由「設定 > 系統 > 關於 > 進階系統設定 > 環境變數」新增使用者變數 `GEMINI_API_KEY`。

### 方法 B:寫入 .Renviron 檔案

用純文字編輯器開啟(若不存在則新建)以下其中一個檔案:

- `%USERPROFILE%\.Renviron`
- `%USERPROFILE%\OneDrive\文件\.Renviron`
- `%USERPROFILE%\OneDrive\Documents\.Renviron`(視 OneDrive 語系資料夾名稱而定,兩者擇一存在即可)

加入一行:

```
GEMINI_API_KEY=你的金鑰
```

**設定後,務必完全關閉並重新啟動 jamovi,新的環境變數才會生效。**

## 在 askLLM 中使用

- **Provider** 下拉選單選「Google Gemini (free tier)」。
- **Model** 欄位預設為 `gemini-flash-latest`(Google 伺服器端自動解析到最新的 flash 模型,不會因版本退役而失效);可依需要更換。

## 常見問題

| 畫面訊息 | 代表意義 | 處理方式 |
|---|---|---|
| 尚未設定 ... 的 API 金鑰 | 找不到 `GEMINI_API_KEY` 或 `GOOGLE_API_KEY` | 依「設定金鑰」重新設定並重啟 jamovi |
| 金鑰無效或過期,請檢查 .Renviron | 金鑰打錯字或已失效 | 回 aistudio.google.com/apikey 重新建立金鑰 |
| 端點或模型名錯誤(model: ...) | Model 欄位打的模型名稱不存在 | 檢查拼字,或改回預設值 |
| 已達用量上限,稍後再試 | 免費額度用盡或觸發速率限制 | 稍候再試,或於 AI Studio 查看用量 |
| 無法連線,請檢查網路 | 網路或防火牆阻擋 | 檢查網路連線,或稍後再試 |
