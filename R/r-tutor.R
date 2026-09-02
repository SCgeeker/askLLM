
# =============================================================================
# R code tutor(`askllmr`)分析專用的檔案層純函式。
# M-A1 從 askllm.b.R 搬來;供 M-A3 的 askllmr.b.R 重用。
# =============================================================================

#' R 教學共通句(構件 4:人格與 prompt 接線)
#'
#' 三人格皆附加的共通約束,置於各 per-role 後綴之前。涵蓋:使用者自行貼進
#' Rj Editor 執行(askLLM 絕不執行)、單一 fenced code block、資料一律用
#' `data`、`library()` 僅限 `<rj_environment>` 清單或 base R、絕不建議
#' `install.packages()`/`read.csv()`/`setwd()`/檔案路徑/`system()`、
#' `<rj_environment>` 缺席時(Rj 未裝)改教 Syntax Mode、結尾提醒貼上執行並
#' 回報錯誤。
.ASKLLM_RJ_COMMON <- list(
    en = paste(
        'The user will paste your R code into jamovi\'s Rj Editor and run it',
        'themselves; you never execute it. Put all runnable code in a single',
        'fenced code block. Use `data` for the dataset. Only `library()`',
        'packages listed in `<rj_environment>` or base R. Never suggest',
        '`install.packages()`, `read.csv()`, `setwd()`, file paths, or `system()`.',
        'If `<rj_environment>` is absent, say Rj is not installed, teach jamovi\'s',
        'Syntax Mode instead (open Syntax Mode to see the `jmv::` code jamovi',
        'itself generated), and mention Rj can be installed from the jamovi',
        'library. End with one line telling the user to paste the code into the',
        'Rj Editor and press Run, and to report back any error.',
        sep = ' '),
    zh = paste0(
        '使用者會把你提供的 R code 貼進 jamovi 的 Rj Editor 自己執行,',
        '你絕不會執行它。',
        '請把所有可執行的程式碼放在單一個 fenced code block 中,',
        '資料一律使用 `data`。',
        '`library()` 只能載入 `<rj_environment>` 中列出的套件或 base R 套件,',
        '絕不可建議 `install.packages()`、`read.csv()`、`setwd()`、',
        '任何檔案路徑,或 `system()`。',
        '若提示中沒有 `<rj_environment>`(代表 Rj 未安裝),',
        '請說明 Rj 尚未安裝,改教使用者使用 jamovi 的 Syntax Mode',
        '(開啟 Syntax Mode 即可看到 jamovi 自動產生的 `jmv::` 程式碼),',
        '並提及可從 jamovi library 安裝 Rj。',
        '結尾請以一行文字提醒使用者把程式碼貼進 Rj Editor 並按下 Run,',
        '並回報任何錯誤訊息。'))

#' R 教學 per-role 後綴(構件 4,比照 `.ASKLLM_ACTION_SUFFIX`)
#'
#' M-A0:此常數保留於此(M-A1 才搬到 `R/r-tutor.R`),諮詢分析
#' `.askllm_system_prompt()` 已不再呼叫;供未來的 R code tutor 分析
#' (`askllmr`,M-A3)重用。
#'
#'   - `consultant`:完整、最小、可直接貼上執行的程式碼片段,附一句說明用途。
#'   - `tutor`     :只給骨架與 `# TODO` 佔位、提示該用哪個函式;使用者明確
#'                  要求才給完整碼(蘇格拉底式教學延伸至寫碼情境)。
#'   - `explainer` :每行附 `#` 註解、先定義用到的統計名詞,假設零基礎。
#' 三者皆以 `.ASKLLM_RJ_COMMON` 開頭,人格差異只在後段。
.ASKLLM_RJ_SUFFIX <- list(
    consultant = list(
        en = paste(.ASKLLM_RJ_COMMON$en,
            'Give a complete, minimal, ready-to-paste snippet, followed by',
            'one sentence explaining what it does.'),
        zh = paste0(.ASKLLM_RJ_COMMON$zh,
            '請給出完整、最小、可直接貼上執行的程式碼片段,',
            '並附上一句話說明這段程式碼在做什麼。')),
    tutor = list(
        en = paste(.ASKLLM_RJ_COMMON$en,
            'Give only a skeleton with `# TODO` placeholders and a hint of',
            'which function to use — not a complete working solution;',
            'provide the full code only if the user explicitly asks for it.'),
        zh = paste0(.ASKLLM_RJ_COMMON$zh,
            '請只給出程式碼骨架與 `# TODO` 佔位提示,並提示應該使用哪個函式,',
            '不要給出完整可執行的解答;只有在使用者明確要求時才提供完整程式碼。')),
    explainer = list(
        en = paste(.ASKLLM_RJ_COMMON$en,
            'Comment every line with `#`, define any statistical terms you',
            'use before the code, and assume the user has zero prior',
            'background in R.'),
        zh = paste0(.ASKLLM_RJ_COMMON$zh,
            '請逐行為程式碼加上 `#` 註解,在程式碼之前先定義用到的統計名詞,',
            '並假設使用者完全沒有 R 背景。')))

#' 把 fenced code block 的圍欄行(``` 或 ```r 等語言標記)改為空行(構件 4)
#'
#' 純函式,不改內容行的縮排,只清空「整行只有圍欄標記(可含前導空白/語言
#' 標記/尾隨空白)」的那幾行,讓 `Preformatted` 顯示時不留下 ``` 殘留。
#' 無圍欄的輸入原樣返回;`NULL` 輸入回傳 `NULL`(不 stop)。
.askllm_strip_fences <- function(text) {
    if (is.null(text)) return(NULL)
    gsub('(?m)^[ \t]*```[A-Za-z0-9_+-]*[ \t]*$', '', text, perl = TRUE)
}

#' R code tutor 的 caveat 三態句(構件 4,M-A0 §1.3 抽出)
#'
#' 從 `.askllm_caveat_text()` 抽出的純函式:R code 未由 askLLM 執行的提醒,
#' 加上依 `has_rj_env` 而異的兩態句(`TRUE`=已接地、`FALSE`=未附上 Rj 環境;
#' `NA`=不附加兩態句,僅保留「未執行」提醒)。
#'
#' 此刻(M-A0)諮詢分析 `askllm` 不再呼叫此函式——諮詢分析已無 R-code 意圖;
#' 保留在 `askllm.b.R`(M-A1 才搬到 `R/r-tutor.R`),供未來的 R code tutor
#' 分析(`askllmr`,M-A3)重用。內容與升版前 R 教學開關開啟時曾產生的字句
#' 逐字相同。
#'
#' @param has_rj_env 本次呼叫是否附上了 `<rj_environment>`。`TRUE`/`FALSE`
#'   兩態各附一句;`NA` 不附加該句。
#' @return `list(en = <chr>, zh = <chr>)`;每個元素為字元向量(每行一元素)。
.askllm_rj_caveat_lines <- function(has_rj_env = NA) {
    r_en <- c('  • R code was NOT executed by askLLM. Paste it into the',
               '    Rj Editor and run it yourself; report any error back.')
    r_zh <- c('  • R 程式碼並未由 askLLM 執行,請自行貼進 Rj Editor 執行,',
               '    並回報任何錯誤訊息。')

    if (isTRUE(has_rj_env)) {
        r_en <- c(r_en,
            '  • The code above was grounded in your installed Rj',
            '    environment (only packages actually available were suggested).')
        r_zh <- c(r_zh,
            '  • 以上程式碼已依你安裝的 Rj 環境接地',
            '    (僅建議實際可用的套件)。')
    } else if (identical(has_rj_env, FALSE)) {
        r_en <- c(r_en,
            '  • No Rj environment was attached (Rj is not installed, or',
            '    the scan failed); verify package availability yourself.')
        r_zh <- c(r_zh,
            '  • 本次未附上 Rj 環境(Rj 未安裝,或掃描失敗),',
            '    套件可用性請自行查證。')
    }
    # has_rj_env = NA:不附加上述兩態句,僅保留「未執行」提醒

    list(en = r_en, zh = r_zh)
}
