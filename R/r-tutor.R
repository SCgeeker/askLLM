
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

#' R code tutor 的三人格 base 身分句(M-A3,3 x 2 短句)
#'
#' 與 `.ASKLLM_PROMPTS`(諮詢分析)平行,但定位為「內嵌於 jamovi 的 R
#' 程式撰寫家教」,而非統計顧問。三人格語氣差異(consultant 直接給碼、
#' tutor 蘇格拉底式引導、explainer 零基礎逐步解說)在此只點出定位,
#' 實際教學規則(單一 code block、`data`、不建議 install.packages() 等)
#' 由 `.ASKLLM_RJ_SUFFIX` 承擔(見 `.askllmr_system_prompt()`)。
.ASKLLM_R_PROMPTS <- list(
    consultant = list(
        en = paste(
            'You are an R coding tutor embedded in jamovi. The user writes R',
            'in jamovi\'s Rj Editor and asks you for code that works on the',
            'dataset described below.',
            sep = ' '),
        zh = paste0(
            '你是內嵌於 jamovi 的 R 程式撰寫家教。',
            '使用者會在 jamovi 的 Rj Editor 中撰寫 R 程式碼,',
            '並向你詢問能處理下方所述資料集的程式碼。')),
    tutor = list(
        en = paste(
            'You are an R coding tutor embedded in jamovi, teaching through',
            'Socratic dialogue. The user writes R in jamovi\'s Rj Editor and',
            'asks you for code that works on the dataset described below;',
            'guide them to write it themselves rather than handing over a',
            'finished solution.',
            sep = ' '),
        zh = paste0(
            '你是內嵌於 jamovi 的 R 程式撰寫家教,採用蘇格拉底式教學法。',
            '使用者會在 jamovi 的 Rj Editor 中撰寫 R 程式碼,',
            '並向你詢問能處理下方所述資料集的程式碼;',
            '請引導他們自己寫出程式碼,而非直接給出完整解答。')),
    explainer = list(
        en = paste(
            'You are an R coding tutor embedded in jamovi, helping complete',
            'beginners write R. The user writes R in jamovi\'s Rj Editor and',
            'asks you for code that works on the dataset described below;',
            'assume no prior background in R.',
            sep = ' '),
        zh = paste0(
            '你是內嵌於 jamovi 的 R 程式撰寫家教,協助完全沒有程式基礎的初學者。',
            '使用者會在 jamovi 的 Rj Editor 中撰寫 R 程式碼,',
            '並向你詢問能處理下方所述資料集的程式碼;',
            '請假設使用者沒有 R 背景。')))

#' 雙向 prompt 邊界句(對稱於諮詢分析 `.ASKLLM_R_REDIRECT_SUFFIX`):恆附加
#'
#' R code tutor(`askllmr`)的定位是提供貼進 Rj Editor 的 R 程式碼——不是
#' jamovi 選單導覽員。若使用者其實是想知道「該用哪個 jamovi 分析／選單
#' 路徑」,應引導改用 sibling 分析「jamovi Module Guider」,而不是自行
#' 猜測、捏造選單路徑。與 `.ASKLLM_RJ_SUFFIX`(R 家教規則,per-role)不同,
#' 此句與人格無關、恆定附加,故獨立成一個常數。
.ASKLLM_JAMOVI_REDIRECT_SUFFIX <- list(
    en = paste(
        'If the user is actually asking which jamovi analysis or menu path',
        'to use (not R code), do not guess menu paths yourself; redirect',
        'them to the "jamovi Module Guider" analysis instead.',
        sep = ' '),
    zh = paste0(
        '若使用者其實是想知道該使用哪個 jamovi 分析或選單路徑(而非 R 程式碼),',
        '請不要自行猜測選單路徑,請引導其改用「jamovi Module Guider」分析。'))

#' 送給 LLM 的 R code tutor system prompt(M-A3;雙向邊界句見下方說明)
#'
#' 優先序:`system_prompt`(去空白後非空)＞ `.ASKLLM_R_PROMPTS[[role]][[lang]]`。
#' **恆**接 `.ASKLLM_RJ_SUFFIX[[role]][[lang]]`——R 家教規則(單一 code block、
#' `data`、Rj 未裝時改教 Syntax Mode 等)是這個分析的主體,不是可關閉的後綴,
#' 故不像諮詢分析的 `has_catalog`/`enable_actions` 那樣是條件式附加。
#' 最後**恆**接 `.ASKLLM_JAMOVI_REDIRECT_SUFFIX[[lang]]`(雙向邊界,對稱於
#' 諮詢分析 `askllm` 的 `.ASKLLM_R_REDIRECT_SUFFIX`)。
#' 未知 role/lang 防禦性落回 `consultant`/`en`。
#'
#' `has_rj_env` 目前保留參數、不改變輸出字串(`<rj_environment>` 缺席時的
#' 教學行為已寫在 `.ASKLLM_RJ_COMMON` 裡),供未來視接地狀態切換文案時使用。
#'
#' @param custom 已解析過的自訂 system prompt(見 `.askllm_resolve_custom()`),
#'   `askllmr` 無 `systemPrompt` TextBox,只能來自 `systemPromptVar`(變數
#'   Description)。
.askllmr_system_prompt <- function(role = 'consultant', lang = 'en',
                                   system_prompt = '', has_rj_env = FALSE) {
    if (is.null(role) || !role %in% names(.ASKLLM_R_PROMPTS)) role <- 'consultant'
    if (is.null(lang) || !lang %in% c('en', 'zh')) lang <- 'en'

    custom <- trimws(system_prompt %||% '')
    base <- if (nzchar(custom)) custom else .ASKLLM_R_PROMPTS[[role]][[lang]]

    paste(base, .ASKLLM_RJ_SUFFIX[[role]][[lang]],
          .ASKLLM_JAMOVI_REDIRECT_SUFFIX[[lang]])
}

#' 把 LLM 回覆拆成「程式碼」與「說明」(M-A3)
#'
#' 決定性、不依賴 structured output:抓**第一個** fenced code block(```` ``` ````
#' 或 ```` ```r ```` 等語言標記皆可)的內容為 `code`(去圍欄、保留內部縮排原樣),
#' 其餘文字(去圍欄,經 `.askllm_strip_fences()`)為 `explanation`。
#' 無 fenced block 時 `code = ''`、`explanation` 為去圍欄全文。
#' `NULL`/空字串輸入 → 兩者皆 `''`。
#'
#' @param text LLM 回覆全文
#' @return `list(code = <chr(1)>, explanation = <chr(1)>)`
.askllmr_split <- function(text) {
    if (is.null(text) || !nzchar(text)) return(list(code = '', explanation = ''))

    pattern <- '(?s)```[A-Za-z0-9_+-]*[ \t]*\r?\n(.*?)\r?\n?```'
    m <- regexpr(pattern, text, perl = TRUE)
    if (m[1] == -1)
        return(list(code = '', explanation = .askllm_strip_fences(text)))

    full <- regmatches(text, m)
    inner <- regmatches(text, regexec(pattern, text, perl = TRUE))[[1]][2]

    rest <- sub(full, '', text, fixed = TRUE)
    list(code = inner, explanation = .askllm_strip_fences(rest))
}

#' R code tutor 常青教材頁網址(M-A3;檔案層常數,字面測試防誤刪)
.ASKLLMR_LEARN_R_URL <- 'https://scgeeker.github.io/askLLM/learn-r.html'

#' `links` 結果項的字面 HTML(M-A3;無 htmltools 依賴)
#'
#' 內容:開啟 Rj 的選單路徑 + 常青教材頁連結;`installed = FALSE`(Rj 未裝)
#' 時額外加一行「從 jamovi library 安裝 Rj」的提示。
#'
#' @param installed 本機是否已裝 Rj(`scan_rj()$installed`)。
#' @param url 教材頁網址,預設 `.ASKLLMR_LEARN_R_URL`(測試可覆寫)。
#' @return `character(1)` 字面 HTML。
.askllmr_links_html <- function(installed, url = .ASKLLMR_LEARN_R_URL) {
    install_line <- if (!isTRUE(installed))
        '<p>Install Rj: Modules ▸ jamovi library</p>'
    else
        ''
    paste0(
        '<p>Open Rj: Analyses ▸ R ▸ Rj ▸ Rj Editor</p>',
        install_line,
        '<p><a href="', url, '" target="_blank" rel="noopener noreferrer">',
        'Learn R with Rj</a></p>')
}

#' R code tutor 的 caveat 文字(M-A3;先英文整段,再中文整段)
#'
#' 固定句(R code 由 LLM 生成、執行前請查證)+ `.askllm_rj_caveat_lines()`
#' 的三態句(依 `has_rj_env` 而異)+ 末句(數值與 jamovi 輸出不符時以 jamovi
#' 為準)。與諮詢分析的 `.askllm_caveat_text()` 平行,但主題是「程式碼」而
#' 非「選單路徑」。
#'
#' @param has_rj_env 見 `.askllm_rj_caveat_lines()`:`TRUE`/`FALSE` 兩態各附
#'   一句,`NA`(預設)不附加。
.askllmr_caveat_text <- function(has_rj_env = NA) {
    lines <- .askllm_rj_caveat_lines(has_rj_env)

    paste(c(
        '⚠ This code is generated by an LLM and may be wrong.',
        '  Please verify it before running:',
        lines$en,
        '  • Where numbers disagree with jamovi output, jamovi is correct.',
        '',
        '⚠ 程式碼由 LLM 生成,可能有誤,執行前請務必自行查證:',
        lines$zh,
        '  • 數值與 jamovi 輸出不符時,以 jamovi 為準。'),
        collapse = '\n')
}

#' R code tutor 的引導文字(先英文整段,再中文整段),零網路,供 .init() 與守門顯示
#'
#' M-A3:接上真邏輯後的正式雙語引導,取代 M-A2 骨架階段的佔位文字。
#' 含隱私揭露句:只送出摘要統計 + 已安裝 Rj 隨附套件的**名稱**(環境中繼
#' 資料,並非你的資料本身)。下方 `links` 連到的教材為模組內建靜態文字,
#' 不由 askLLM 主動連網抓取。排版比照 `.askllm_guide_text()`:段落區塊
#' 文字語言一致,先英文再中文。
.askllmr_guide_text <- function() {
    paste(
        'R code tutor — pick variables, describe what the R code should do,',
        'and tick Submit to get code you can paste into the Rj Editor.',
        '',
        '1. Select the variables the code should work on.',
        '2. Describe what the code should do (English or Chinese both work).',
        '3. Tick "Submit" to send; the code appears in a moment.',
        '',
        'Privacy:',
        'After you tick Submit, the SUMMARY STATISTICS of the selected',
        'variables (never the raw data rows) are sent to the chosen LLM',
        'service, together with the NAMES of the R packages bundled with',
        'your installed Rj (environment metadata, none of your data) so the',
        'code fits what you actually have. Use Ollama (local) if you prefer',
        'zero data to leave your machine.',
        '',
        'The guidance text on this panel is bundled with the module;',
        'askLLM does not fetch teaching material over the network on your',
        'behalf.',
        '',
        'Debounce:',
        'Untick "Submit" before editing your question, then re-tick it,',
        'so that edits do not each trigger a new call (and billing).',
        '',
        'R code tutor —— 選擇變項、描述你想要的 R 程式碼,',
        '勾選 Submit 即可取得可貼進 Rj Editor 的程式碼。',
        '',
        '1. 勾選程式碼要處理的變項。',
        '2. 描述你想要的 R 程式碼(英文或中文皆可)。',
        '3. 勾選「Submit」送出,稍候即可看到程式碼。',
        '',
        '隱私提醒:',
        '勾選 Submit 後,所選變項的「摘要統計」(非原始資料列)',
        '將傳送到所選的 LLM 服務,連同你已安裝 Rj 隨附套件的「名稱」',
        '(環境中繼資料,不含你的任何資料內容),讓程式碼符合你實際擁有的環境。',
        '若不希望任何資料外送,可改用 Ollama(本機)。',
        '',
        '本面板的引導文字為模組內建的靜態內容;',
        'askLLM 不會自動連網抓取教材。',
        '',
        '防抖提醒:',
        '修改問題前請先取消「Submit」勾選,改好後再重新勾選,',
        '以免每次改動都觸發一次呼叫(與計費)。',
        sep = '\n')
}

#' Rj 未裝時的靜態提示(M-A3;先英文整段,再中文整段,零 LLM)
#'
#' 前置於 `instructions` 顯示:說明改教 jamovi 的 Syntax Mode,並提及可從
#' jamovi library 安裝 Rj 以取得完整 R 程式碼產生能力。
.askllmr_no_rj_text <- function() {
    paste(
        'Rj is not installed on this machine, so R code cannot be grounded',
        'in a real R environment here. Code will instead be adapted to',
        'jamovi\'s Syntax Mode (open Syntax Mode to see the `jmv::` code',
        'jamovi itself generates); you can install Rj from the jamovi',
        'library to unlock full R code generation.',
        '',
        '本機尚未安裝 Rj,因此無法針對真實 R 環境產生接地的程式碼。',
        '將改為教你使用 jamovi 的 Syntax Mode',
        '(開啟 Syntax Mode 即可看到 jamovi 自動產生的 `jmv::` 程式碼);',
        '你可以從 jamovi library 安裝 Rj 以取得完整的 R 程式碼產生功能。',
        sep = '\n')
}
