# llm-adapter.R — ellmer 版本適應層(純函式)
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
#' 有 summary_text 時以模板包裹資料摘要;否則純問題。
#' summary_text 是已格式化的純文字,本函式只負責嵌進模板。
build_prompt <- function(question, summary_text = NULL) {
    if (!is.null(summary_text) && nzchar(summary_text)) {
        paste0(
            'Here is a summary of the dataset:\n',
            '<summary>\n', summary_text, '\n</summary>\n\n',
            'Answer the user question about THIS dataset. Be concise.\n\n',
            'Question: ', question
        )
    } else {
        question
    }
}

#' 把底層錯誤訊息翻成友善繁中訊息
#'
#' 已知類別給定制文案;其餘給前綴。一律於尾端括號附原始訊息供除錯。
translate_error <- function(msg, model) {
    lower <- tolower(msg)

    if (grepl('401|403|unauthor|forbidden|invalid.*(api.?)?key|incorrect api key', lower)) {
        friendly <- '金鑰無效或過期,請檢查 .Renviron'
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
#' @return list(ok, text, model, elapsed_s, error);永不 stop()
ask_llm <- function(question, summary_text = NULL, base_url, model, api_key,
                    system_prompt = NULL, max_tokens = 1024, ctor = NULL) {
    started <- Sys.time()
    elapsed <- function() as.numeric(difftime(Sys.time(), started, units = 'secs'))

    tryCatch({
        chat <- make_chat(base_url = base_url, model = model, api_key = api_key,
                          system_prompt = system_prompt, ctor = ctor,
                          max_tokens = max_tokens)
        prompt <- build_prompt(question, summary_text)
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
