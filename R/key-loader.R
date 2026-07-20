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
#' @param env_var 要設定的環境變數名稱
#' @param signup_url 金鑰申請網址
#' @param key_example 該 provider 的金鑰格式範例(見 [provider_spec()] 的
#'   `key_example`);未給時用通用佔位符
#' @return 中英雙語教學字串(與介面其他引導文字一致)
#' @export
key_setup_text <- function(provider_name, env_var, signup_url,
                           key_example = '<your-api-key>') {
    userprofile <- Sys.getenv('USERPROFILE', unset = '')
    path_root <- file.path(userprofile, '.Renviron')
    path_onedrive_wenjian <- file.path(userprofile, 'OneDrive', '文件', '.Renviron')
    path_onedrive_documents <- file.path(userprofile, 'OneDrive', 'Documents', '.Renviron')

    paste(
        sprintf('尚未設定 %s 的 API 金鑰。', provider_name),
        sprintf('No API key configured for %s.', provider_name),
        '',
        sprintf('1. 前往 %s 申請金鑰。', signup_url),
        sprintf('   Get a key at %s', signup_url),
        '',
        '2. 設定金鑰(兩種方式擇一,方法 A 較簡單)',
        '   Set the key (either way; Method A is simpler):',
        '',
        '   方法 A:Windows 環境變數(推薦)',
        '   Method A: Windows environment variable (recommended)',
        '   開啟 PowerShell,執行(引號內換成你的金鑰):',
        '   Run this in PowerShell, with your own key inside the quotes:',
        sprintf('       setx %s "%s"', env_var, key_example),
        '   或由「設定 > 系統 > 關於 > 進階系統設定 > 環境變數」新增使用者變數。',
        '   Or add a user variable via Settings > System > About >',
        '   Advanced system settings > Environment Variables.',
        '',
        '   方法 B:寫入 .Renviron 檔案',
        '   Method B: write it into an .Renviron file',
        '   用純文字編輯器開啟(若不存在則新建)以下其中一個檔案:',
        '   Open (or create) one of these files in a plain-text editor:',
        sprintf('   - %s', path_root),
        sprintf('   - %s', path_onedrive_wenjian),
        sprintf('   - %s', path_onedrive_documents),
        '   (視 OneDrive 語系資料夾名稱而定 / depending on your OneDrive folder name)',
        '   加入一行 / Add one line:',
        sprintf('       %s=%s', env_var, key_example),
        '',
        '3. 設定後,完全關閉並重啟 jamovi 才會生效。',
        '   Fully quit and restart jamovi for the change to take effect.',
        '',
        '隱私提醒:金鑰只會存在你的本機(環境變數或檔案),',
        '不會被上傳、分享,也不會寫入 .omv 檔。',
        'Privacy: the key stays on your machine (environment variable or file).',
        'It is never uploaded, shared, or saved into the .omv file.',
        sep = '\n')
}
