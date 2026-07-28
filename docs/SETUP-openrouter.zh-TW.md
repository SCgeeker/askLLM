# 設定 OpenRouter API 金鑰

## 這是什麼

OpenRouter 是一個統一的雲端 LLM 閘道,一個帳號、一組金鑰就能呼叫數十家廠商(OpenAI、Anthropic、Meta、Google、DeepSeek 等)的模型,其中多款提供 **`:free`** 免費額度、**不需信用卡**即可取得金鑰。金鑰經雲端 API 呼叫,問題與資料摘要會傳送到 OpenRouter 與其上游模型供應商的伺服器。

## 取得金鑰

1. 前往 <https://openrouter.ai/keys>,以 Google、GitHub 或 Email 帳號註冊或登入。
2. 點選「Create Key」,為金鑰命名(例如 `askLLM`)。
3. 複製產生的金鑰(格式以 `sk-or-v1-` 開頭)。

## `:free` 後綴規則(重要)

OpenRouter 上同一個模型常同時有付費與免費兩個版本。**免費版必須在模型名稱後面加上 `:free` 後綴**,例如:

```
openai/gpt-oss-20b:free
```

若漏掉 `:free`,同名模型會改走付費版,實際呼叫會產生費用(或因未綁付款方式而失敗)。可在 <https://openrouter.ai/models?max_price=0> 瀏覽目前所有免費模型清單——清單會隨時間變動,askLLM 內建的預設值僅供起步參考,请以該頁面為準。

## 免費額度

| 帳戶狀態 | 每日請求上限 |
|---|---|
| 未儲值 | 50 requests/日 |
| 已儲值 **US$10 以上**(一次性,終身有效) | 1000 requests/日 |

額度以「請求數」計,與模型大小無關;儲值門檻是終身一次性的,不是訂閱制。詳細規則請以 OpenRouter 官方文件為準,因供應商政策可能調整。

## 設定金鑰

askLLM 依序嘗試環境變數 **`OPENROUTER_API_KEY`**、**`LLM_API_KEY`**(有一個即可;前者優先)。以下擇一方法設定,方法 A 較簡單。

### 方法 A:Windows 環境變數(推薦)

開啟 PowerShell,執行(引號內換成你的金鑰):

```powershell
setx OPENROUTER_API_KEY "sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxx"
```

或由「設定 > 系統 > 關於 > 進階系統設定 > 環境變數」新增使用者變數 `OPENROUTER_API_KEY`。

### 方法 B:寫入 .Renviron 檔案

用純文字編輯器開啟(若不存在則新建)以下其中一個檔案:

- `%USERPROFILE%\.Renviron`
- `%USERPROFILE%\OneDrive\文件\.Renviron`
- `%USERPROFILE%\OneDrive\Documents\.Renviron`(視 OneDrive 語系資料夾名稱而定,兩者擇一存在即可)

加入一行:

```
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxx
```

**設定後,務必完全關閉並重新啟動 jamovi,新的環境變數才會生效。**

## 在 askLLM 中使用

- **Provider** 下拉選單選「OpenRouter」。
- **Model** 欄位預設為 `openai/gpt-oss-20b:free`(2026-07-29 實測可正常對話、零費用);可依需要換成其他 `:free` 模型,**記得保留 `:free` 後綴**。

## 隱私標記

雲端服務——問題與資料摘要會離開你的電腦,送到 OpenRouter 與其上游模型供應商。若需完全零資料外送,請改用 **Ollama(本機)** provider。

## 常見問題

| 畫面訊息 | 代表意義 | 處理方式 |
|---|---|---|
| 尚未設定 ... 的 API 金鑰 | 找不到 `OPENROUTER_API_KEY` 或 `LLM_API_KEY` | 依「設定金鑰」重新設定並重啟 jamovi |
| 金鑰無效或過期,請檢查 .Renviron | 金鑰打錯字或已失效 | 回 openrouter.ai/keys 重新建立金鑰 |
| 端點或模型名錯誤(model: ...) | Model 欄位打的模型名稱不存在,或漏了 `:free` 導致誤觸付費版 | 檢查拼字與 `:free` 後綴,或改回預設值 |
| 已達用量上限,稍後再試 | 免費額度用盡(未儲值 50/日、已儲值 1000/日)或觸發速率限制 | 稍候再試,或於 openrouter.ai 查看用量與儲值 |
| 無法連線,請檢查網路 | 網路或防火牆阻擋 | 檢查網路連線,或稍後再試 |
