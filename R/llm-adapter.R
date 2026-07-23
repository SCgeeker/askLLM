# llm-adapter.R — ellmer 版本適應層(純函式)
#
# ---------------------------------------------------------------------------
# 交接給 W4(askllm.b.R 所有者)的定稿文字 —— v1.1 規格 §4.3.3 與 caveat:
#
# 1. `.askllm_system_prompt(has_catalog = FALSE)`(askllm.b.R):
#    has_catalog = TRUE 時,於 v1.0 system prompt 字串之後以「單一空白」接續
#    附加下列英文句(規格 §4.3.3 逐字,規範性):
#
#    When a list of installed analyses is provided, recommend analyses ONLY
#    from that list and cite each menu path exactly as written. If nothing
#    installed fits, suggest a module ONLY from the provided available-modules
#    list. Never invent module names, menus, or menu paths.
#
#    (實作時為單一行字串,句間各一空白、無換行。)
#    `.runInner()` 以 has_catalog = !is.null(catalog_text_value) 呼叫。
#
# 2. `.askllm_caveat_text()`(askllm.b.R)v1.1 警語第一點改為:
#    中文:「選單路徑已比對本機安裝清單,仍請以實際介面為準。」
#    英文:"Menu paths are checked against your locally installed modules;
#           still verify them in the actual interface."
# ---------------------------------------------------------------------------
#
# 同一份程式碼要在兩種環境正確運作:
#   - jamovi 內:ellmer 0.2.0 —— chat_openai(base_url=, api_key=, model=)
#   - 開發機  :ellmer 0.4.2 —— chat_openai_compatible(base_url=, model=),
#               金鑰須以 OPENAI_API_KEY 環境變數供給(api_key 參數已不生效)
#
# 設計原則:永不 stop();對外一律回傳結構化 list。

#' 依 ellmer 版本建立 chat 物件
#'
#' @param base_url OpenAI 相容端點
#' @param model 模型名(0.2.0 必須明給,否則預設 gpt-4o)
#' @param api_key 金鑰字串
#' @param system_prompt 系統提示
#' @param ctor 測試注入點;非 NULL 時直接呼叫,不碰 ellmer
#' @param max_tokens 回覆長度上限(透過 api_args 傳入,兩版皆支援)
#' @return 具 `$chat(prompt)` 方法的物件
make_chat <- function(base_url, model, api_key, system_prompt,
                      ctor = NULL, max_tokens = 1024) {
    if (!is.null(ctor)) {
        return(ctor(base_url = base_url, model = model,
                    api_key = api_key, system_prompt = system_prompt))
    }

    api_args <- list(max_tokens = max_tokens)

    if (utils::packageVersion('ellmer') >= '0.4.0') {
        # 0.4.x:金鑰只認 OPENAI_API_KEY 環境變數。
        # 取捨:此處 Sys.setenv 後「不」還原——engine/session 為短生命週期
        # 的獨立行程,每次呼叫都會在建構前重設,故重複設定無害;不還原可讓
        # chat_openai_compatible 的預設金鑰查找順利命中。若要避免污染呼叫端
        # 行程(如測試/互動 session),由呼叫端以 withr::local_envvar 包裹。
        Sys.setenv(OPENAI_API_KEY = api_key)
        ellmer::chat_openai_compatible(
            base_url      = base_url,
            model         = model,
            system_prompt = system_prompt,
            api_args      = api_args,
            echo          = 'none'
        )
    } else {
        # 0.2.0:api_key 參數有效;model 必須明給
        ellmer::chat_openai(
            base_url      = base_url,
            api_key       = api_key,
            model         = model,
            system_prompt = system_prompt,
            api_args      = api_args,
            echo          = 'none'
        )
    }
}

#' 組出最終送給 LLM 的 user prompt
#'
#' 有 summary_text 時以模板包裹資料摘要;否則純問題。三段文字皆為已格式化
#' 純文字,本函式只負責組版(格式規範見規格 §5.3)。
#'
#' 降級保證(規格 §4.2.1,規範性):`catalog_text` 為 `NULL` 或空字串時,
#' 忽略 `available_text`,輸出與 v1.0 `build_prompt(question, summary_text)`
#' 逐字(byte-identical)相同。`available_text` 區塊只在 catalog 區塊存在時
#' 才可能出現(available 依賴掃描結果排除已安裝;掃描全失敗即整體降級)。
#'
#' @param question 使用者問題(必要)。
#' @param summary_text 資料摘要純文字;`NULL`/空字串時省略 summary 段。
#' @param catalog_text 已安裝分析清單純文字([catalog_text()] 輸出)。
#' @param available_text 可安裝模組清單純文字([available_text()] 輸出)。
#' @return `character(1)` user prompt。
build_prompt <- function(question, summary_text = NULL,
                         catalog_text = NULL, available_text = NULL) {
    has_catalog   <- !is.null(catalog_text) && nzchar(catalog_text)
    has_available <- has_catalog &&
        !is.null(available_text) && nzchar(available_text)

    # 情形 A(catalog 為 NULL/空):v1.0 逐字相同
    if (!has_catalog) {
        if (!is.null(summary_text) && nzchar(summary_text)) {
            return(paste0(
                'Here is a summary of the dataset:\n',
                '<summary>\n', summary_text, '\n</summary>\n\n',
                'Answer the user question about THIS dataset. Be concise.\n\n',
                'Question: ', question
            ))
        }
        return(question)
    }

    # 情形 B / C:段與段之間恰一個空行,Question 恆為最末行,無尾隨換行
    segments <- character(0)

    if (!is.null(summary_text) && nzchar(summary_text)) {
        segments <- c(segments, paste0(
            'Here is a summary of the dataset:\n',
            '<summary>\n', summary_text, '\n</summary>'))
    }

    segments <- c(segments, paste0(
        'Installed jamovi analyses on this machine (real menu paths):\n',
        '<installed_analyses>\n', catalog_text, '\n</installed_analyses>'))

    if (has_available) {
        segments <- c(segments, paste0(
            'Official jamovi library modules NOT currently installed:\n',
            '<available_modules>\n', available_text, '\n</available_modules>'))
    }

    # 指令段:前兩行 B/C 共用,第三行依有無 available 區塊切換(規格 §5.3 逐字)
    third_line <- if (has_available) {
        paste0('If no installed analysis fits, suggest installing a module ',
               'ONLY from <available_modules> (Modules > jamovi library in jamovi). ',
               'If neither list has a suitable option, say plainly that you do not know. ',
               'NEVER invent module names or menu paths.')
    } else {
        paste0('If no installed analysis fits the question, say so plainly. ',
               'NEVER invent module names or menu paths.')
    }
    segments <- c(segments, paste0(
        'Answer the user question about THIS dataset. Be concise.\n',
        'Recommend analyses ONLY from <installed_analyses> and quote each ',
        'menu path EXACTLY as written there.\n',
        third_line))

    segments <- c(segments, paste0('Question: ', question))
    paste(segments, collapse = '\n\n')
}

#' 把底層錯誤訊息翻成友善繁中訊息
#'
#' 已知類別給定制文案;其餘給前綴。一律於尾端括號附原始訊息供除錯。
translate_error <- function(msg, model) {
    lower <- tolower(msg)

    # 403 與 401 意義不同:401 是金鑰本身不被接受;403 是金鑰有效但缺少
    # 使用該模型/端點的權限(如 GitHub fine-grained token 未勾 Models 權限)。
    # 混為一談會讓使用者一直去檢查金鑰,卻找不到真正原因。
    if (grepl('403|forbidden|no_access|permission|not authorized|access denied', lower)) {
        friendly <- paste0(
            '金鑰有效,但沒有使用此模型的權限(model: ', model, ')。',
            'GitHub Models:到 github.com/settings/tokens 開啟該 token,',
            '在「Account permissions」(不是 Repository permissions)加入 ',
            'Models = Read-only,再按 Update,然後重啟 jamovi;',
            '其他服務請確認帳號已開通此模型')
    } else if (grepl('401|unauthor|invalid.*(api.?)?key|incorrect api key', lower)) {
        friendly <- '金鑰無效或過期,請檢查環境變數或 .Renviron 設定'
    } else if (grepl('404|not found', lower)) {
        friendly <- paste0('端點或模型名錯誤(model: ', model, ')')
    } else if (grepl('429|rate.?limit|quota|too many request', lower)) {
        friendly <- '已達用量上限,稍後再試'
    } else if (grepl('timeout|timed out|could not resolve|could not connect|failed to connect|connection|network|resolve host', lower)) {
        friendly <- '無法連線,請檢查網路'
    } else {
        # 其他:原訊息附上前綴(不重複附括號原訊息)
        return(paste0('LLM 呼叫失敗:', msg))
    }

    paste0(friendly, '(原始訊息:', msg, ')')
}

#' 問 LLM(對外主入口)
#'
#' `catalog_text`/`available_text` 原樣透傳給 [build_prompt()](參數位置依
#' 規格 §4.2.2:置於 `summary_text` 之後、`base_url` 之前,既有具名呼叫不受
#' 影響)。
#'
#' @return list(ok, text, model, elapsed_s, error);永不 stop()
ask_llm <- function(question, summary_text = NULL,
                    catalog_text = NULL, available_text = NULL,
                    base_url, model, api_key,
                    system_prompt = NULL, max_tokens = 1024, ctor = NULL) {
    started <- Sys.time()
    elapsed <- function() as.numeric(difftime(Sys.time(), started, units = 'secs'))

    tryCatch({
        chat <- make_chat(base_url = base_url, model = model, api_key = api_key,
                          system_prompt = system_prompt, ctor = ctor,
                          max_tokens = max_tokens)
        prompt <- build_prompt(question, summary_text,
                               catalog_text = catalog_text,
                               available_text = available_text)
        raw <- chat$chat(prompt)
        text <- as.character(raw)
        list(ok = TRUE, text = text, model = model,
             elapsed_s = elapsed(), error = NULL)
    }, error = function(e) {
        list(ok = FALSE, text = NULL, model = model,
             elapsed_s = elapsed(),
             error = translate_error(conditionMessage(e), model))
    })
}
