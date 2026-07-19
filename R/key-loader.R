# R/key-loader.R
# 金鑰查找鏈:jamovi engine 不繼承環境變數,且 engine 的 HOME 為建置期垃圾值
# (見 dev-notes/M0-result.zh-TW.md),因此查找鏈一律以 USERPROFILE 為錨,
# ~/.Renviron 只作最後墊底。

# 內部:讀取 Windows 登錄檔中的環境變數(scope: 'user' = HKCU\Environment,
# 'system' = HKLM Session Manager\Environment)。jamovi engine 會清洗行程環境
# 變數,但登錄檔存有使用者/系統層環境變數的真正值,不受行程環境影響。
# 非 Windows 回 NULL;呼叫端負責 tryCatch。獨立成函式以便測試 mock。
#' @keywords internal
.read_registry_env <- function(scope) {
    if (.Platform$OS.type != 'windows') return(NULL)
    if (identical(scope, 'user')) {
        utils::readRegistry('Environment', hive = 'HCU')
    } else {
        utils::readRegistry(
            'SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment',
            hive = 'HLM')
    }
}

#' 依查找鏈載入 API 金鑰
#'
#' @param env_vars 字元向量,依序嘗試的環境變數名稱(第一個有值者勝)
#' @return list(key = <字串>, source = <'env'、'registry:user'、'registry:system'
#'   或命中的 .Renviron 路徑>);全段皆未命中則回傳 NULL
#' @export
load_api_key <- function(env_vars) {

    .first_hit <- function() {
        for (v in env_vars) {
            val <- Sys.getenv(v, unset = '')
            if (nzchar(val)) return(val)
        }
        ''
    }

    # 第 1 段:行程環境變數直接有值
    val <- .first_hit()
    if (nzchar(val)) return(list(key = val, source = 'env'))

    # 第 2-3 段:Windows 登錄檔環境變數(使用者層 → 系統層)
    for (scope in c('user', 'system')) {
        vals <- tryCatch(.read_registry_env(scope), error = function(e) NULL)
        if (is.list(vals)) {
            for (v in env_vars) {
                item <- vals[[v]]
                if (is.character(item) && length(item) == 1 && nzchar(item)) {
                    return(list(key = item, source = paste0('registry:', scope)))
                }
            }
        }
    }

    # 後續段:以 USERPROFILE 為錨的候選 .Renviron 路徑
    userprofile <- Sys.getenv('USERPROFILE', unset = '')
    if (nzchar(userprofile)) {
        candidates <- c(
            file.path(userprofile, '.Renviron'),
            file.path(userprofile, 'OneDrive', '文件', '.Renviron'),
            file.path(userprofile, 'OneDrive', 'Documents', '.Renviron'))

        for (p in candidates) {
            if (file.exists(p)) {
                readRenviron(p)
                val <- .first_hit()
                if (nzchar(val)) return(list(key = val, source = p))
            }
        }
    }

    # 第 5 段:~/.Renviron 墊底(HOME 可能是垃圾值,readRenviron 對不存在檔案無害)。
    # 注意:R 的 path.expand('~') 只在行程啟動時解析一次,執行期改 Sys.setenv('HOME', ...)
    # 不會反映;因此改用 Sys.getenv('HOME') 直接組路徑,語意等價且可測試。
    home <- Sys.getenv('HOME', unset = '')
    if (nzchar(home)) {
        home_renviron <- file.path(home, '.Renviron')
        if (file.exists(home_renviron)) {
            readRenviron(home_renviron)
            val <- .first_hit()
            if (nzchar(val)) return(list(key = val, source = home_renviron))
        }
    }

    NULL
}

#' 產生金鑰申請與設定教學文字(繁體中文)
#'
#' @param provider_name provider 顯示名稱
#' @param env_var 要寫入 .Renviron 的環境變數名稱
#' @param signup_url 金鑰申請網址
#' @return 繁體中文教學字串
#' @export
key_setup_text <- function(provider_name, env_var, signup_url) {
    userprofile <- Sys.getenv('USERPROFILE', unset = '')
    path_root <- file.path(userprofile, '.Renviron')
    path_onedrive_wenjian <- file.path(userprofile, 'OneDrive', '文件', '.Renviron')
    path_onedrive_documents <- file.path(userprofile, 'OneDrive', 'Documents', '.Renviron')

    paste(
        sprintf('尚未設定 %s 的 API 金鑰。', provider_name),
        '',
        sprintf('1. 前往 %s 申請金鑰。', signup_url),
        '',
        '2. 設定金鑰(擇一,方法 A 較簡單):',
        '',
        '   方法 A:設定 Windows 環境變數(推薦)',
        '   開啟 PowerShell,執行(引號內換成你的金鑰):',
        sprintf('       setx %s "nvapi-xxxxxxxxxxxxxxxxxxxxxxxx"', env_var),
        '   或由「設定 > 系統 > 關於 > 進階系統設定 > 環境變數」新增',
        sprintf('   使用者變數 %s。', env_var),
        '',
        '   方法 B:寫入 .Renviron 檔案',
        '   用純文字編輯器開啟(若不存在則新建)以下其中一個檔案:',
        sprintf('   - %s', path_root),
        sprintf('   - %s', path_onedrive_wenjian),
        sprintf('   - %s(視 OneDrive 語系資料夾名稱而定)', path_onedrive_documents),
        '   加入一行:',
        sprintf('       %s=nvapi-xxxxxxxxxxxxxxxxxxxxxxxx', env_var),
        '',
        '3. 設定後,完全關閉並重啟 jamovi 才會生效。',
        '',
        '隱私提醒:金鑰只會存在你的本機(環境變數或檔案),不會被上傳或分享。',
        sep = '\n')
}
