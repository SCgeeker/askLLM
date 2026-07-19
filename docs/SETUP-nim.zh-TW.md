# 設定 NVIDIA NIM API 金鑰

## 這是什麼

NVIDIA NIM 是 NVIDIA 提供的雲端 LLM API 服務,涵蓋多款開源與商用模型。註冊時通常附贈一定額度的免費用量,**不需信用卡**即可取得金鑰、立即測試。金鑰經雲端 API 呼叫,問題與資料摘要會傳送到 NVIDIA 伺服器。

## 取得金鑰

1. 前往 <https://build.nvidia.com>,以 Google、GitHub 或 Email 帳號註冊或登入。
2. 進入任一模型頁面(例如 `meta/llama-3.1-8b-instruct`),找到「Get API Key」按鈕並點選。
3. 複製產生的金鑰(格式通常以 `nvapi-` 開頭)。

## 設定金鑰

askLLM 讀取環境變數 **`NVIDIA_API_KEY`**。以下擇一方法設定,方法 A 較簡單。

### 方法 A:Windows 環境變數(推薦)

開啟 PowerShell,執行(引號內換成你的金鑰):

```powershell
setx NVIDIA_API_KEY "nvapi-xxxxxxxxxxxxxxxxxxxxxxxx"
```

或由「設定 > 系統 > 關於 > 進階系統設定 > 環境變數」新增使用者變數 `NVIDIA_API_KEY`。

### 方法 B:寫入 .Renviron 檔案

用純文字編輯器開啟(若不存在則新建)以下其中一個檔案:

- `%USERPROFILE%\.Renviron`
- `%USERPROFILE%\OneDrive\文件\.Renviron`
- `%USERPROFILE%\OneDrive\Documents\.Renviron`(視 OneDrive 語系資料夾名稱而定,兩者擇一存在即可)

加入一行:

```
NVIDIA_API_KEY=nvapi-xxxxxxxxxxxxxxxxxxxxxxxx
```

**設定後,務必完全關閉並重新啟動 jamovi,新的環境變數才會生效。**

## 在 askLLM 中使用

- **Provider** 下拉選單選「NVIDIA NIM」。
- **Model** 欄位預設為 `meta/llama-3.1-8b-instruct`;可依需要換成 NIM 上其他可用模型名稱。

## 常見問題

| 畫面訊息 | 代表意義 | 處理方式 |
|---|---|---|
| 尚未設定 ... 的 API 金鑰 | 找不到 `NVIDIA_API_KEY` | 依「設定金鑰」重新設定並重啟 jamovi |
| 金鑰無效或過期,請檢查 .Renviron | 金鑰打錯字或已失效 | 回 build.nvidia.com 重新複製一次金鑰 |
| 端點或模型名錯誤(model: ...) | Model 欄位打的模型名稱不存在 | 檢查拼字,或改回預設值 |
| 已達用量上限,稍後再試 | 免費額度用盡或觸發速率限制 | 稍候再試,或於 build.nvidia.com 查看用量 |
| 無法連線,請檢查網路 | 網路或防火牆阻擋 | 檢查網路連線,或稍後再試 |
