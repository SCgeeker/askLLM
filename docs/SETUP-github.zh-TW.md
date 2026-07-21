# 設定 GitHub Models API 金鑰

## 這是什麼

GitHub Models 讓擁有 GitHub 帳號的使用者以個人存取權杖(Personal Access Token)呼叫多款模型(含 OpenAI GPT 系列)。**有免費用量、不需另外的信用卡**,但需要一個 GitHub 帳號。金鑰經雲端 API 呼叫,問題與資料摘要會傳送到 GitHub/Azure 的伺服器。

## 取得金鑰

1. 前往 <https://github.com/settings/tokens>(需先登入 GitHub 帳號)。
2. 建立一個新的 Personal Access Token。
3. ⚠️ **務必勾選 Models 權限**——這是最常見的失敗原因:
   - **Fine-grained token**(`github_pat_...`):在 **Account permissions** 區塊找到 **Models**,設為 **Read-only**。沒有這一步,權杖雖然能通過認證、也查得到模型清單,但實際呼叫會回 **HTTP 403 `no_access`**。
   - **Classic token**(`ghp_...`):勾選 `read:user`(GitHub Models 目前以此判定存取權)。
4. 複製產生的權杖(僅顯示一次,請立即保存)。

> 已經建好但忘了勾權限?回到權杖頁面點該權杖 → 編輯權限 → 加上 Models(Read-only)→ 儲存,不必重新產生。

## 設定金鑰

askLLM 依序嘗試環境變數 **`GITHUB_MODELS_TOKEN`** → **`GITHUB_PAT`** → **`GITHUB_TOKEN`**(有一個即可)。

> ⚠️ **請用 `GITHUB_MODELS_TOKEN`,不要用 `GITHUB_TOKEN`。**
> `GITHUB_TOKEN` 是 git 與 GitHub CLI(`gh`)會優先讀取的變數名。若你把「只有 Models 權限」的權杖設在這個名稱下,你自己的 `git push`、`gh` 指令會改用這顆權杖而被拒絕(`Permission to ... denied`)。用專用名稱可完全避開這個衝突。
>
> 已經設成 `GITHUB_TOKEN` 了?改名即可:
> ```powershell
> setx GITHUB_MODELS_TOKEN "你的權杖"
> reg delete "HKCU\Environment" /v GITHUB_TOKEN /f
> ```

以下擇一方法設定,方法 A 較簡單。

### 方法 A:Windows 環境變數(推薦)

開啟 PowerShell,執行(引號內換成你的權杖):

```powershell
setx GITHUB_MODELS_TOKEN "你的權杖"
```

或由「設定 > 系統 > 關於 > 進階系統設定 > 環境變數」新增使用者變數 `GITHUB_MODELS_TOKEN`。

### 方法 B:寫入 .Renviron 檔案

用純文字編輯器開啟(若不存在則新建)以下其中一個檔案:

- `%USERPROFILE%\.Renviron`
- `%USERPROFILE%\OneDrive\文件\.Renviron`
- `%USERPROFILE%\OneDrive\Documents\.Renviron`(視 OneDrive 語系資料夾名稱而定,兩者擇一存在即可)

加入一行:

```
GITHUB_MODELS_TOKEN=你的權杖
```

**設定後,務必完全關閉並重新啟動 jamovi,新的環境變數才會生效。**

## 在 askLLM 中使用

- **Provider** 下拉選單選「GitHub Models」。
- **Model** 欄位預設為 `openai/gpt-4o-mini`;可依需要更換為 GitHub Models 目錄中其他可用模型名稱。

## 常見問題

| 畫面訊息 | 代表意義 | 處理方式 |
|---|---|---|
| 尚未設定 ... 的 API 金鑰 | 找不到 `GITHUB_MODELS_TOKEN`、`GITHUB_PAT` 或 `GITHUB_TOKEN` | 依「設定金鑰」重新設定並重啟 jamovi |
| 金鑰有效,但沒有使用此模型的權限 | 權杖缺少 Models 權限(最常見) | 編輯權杖,在 Account permissions 加上 Models(Read-only) |
| 金鑰無效或過期 | 權杖打錯字或已過期 | 回 github.com/settings/tokens 重新建立權杖 |
| 端點或模型名錯誤(model: ...) | Model 欄位打的模型名稱不存在 | 檢查拼字,或改回預設值 |
| 已達用量上限,稍後再試 | 免費用量用盡或觸發速率限制 | 稍候再試 |
| 無法連線,請檢查網路 | 網路或防火牆阻擋 | 檢查網路連線,或稍後再試 |
