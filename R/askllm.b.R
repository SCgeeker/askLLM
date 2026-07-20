
# This file is a generated template, your changes will not be overwritten

# =============================================================================
# 檔案層級純函式(非類別方法):.run() 的可測邏輯抽於此,供離線單元測試。
# 名稱以 '.' 開頭,不被 NAMESPACE 的 exportPattern 匯出,僅套件內部使用。
# =============================================================================

# NULL 預設運算子(jmvcore/base 未提供,自行定義)
`%||%` <- function(a, b) if (is.null(a)) b else a

# payload 欄位分隔符:單元分隔字元(U+001F),正常文字不會出現,
# 故問題/摘要含換行或空白也不會與相鄰欄位黏連而產生歧義。
.ASKLLM_SEP <- intToUtf8(31)

#' 組出防抖快取用的 payload 字串
#'
#' payload = 問題 + 摘要 + base_url + model,以控制字元分隔避免歧義。
#' summary_text 可為 NULL(視為空字串)。
.askllm_build_payload <- function(question, summary_text, base_url, model) {
    paste(
        question %||% '',
        summary_text %||% '',
        base_url %||% '',
        model %||% '',
        sep = .ASKLLM_SEP)
}

#' 三態決策:'guide' | 'cached' | 'call'
#'
#' 1. 未勾 submit 或問題(去空白後)為空 → 'guide'
#' 2. 快取 payload 與新 payload identical → 'cached'
#' 3. 其餘 → 'call'
.askllm_decide <- function(submit, question, cache_payload, new_payload) {
    if (!isTRUE(submit) || !nzchar(trimws(question %||% '')))
        return('guide')
    if (!is.null(cache_payload) && identical(cache_payload, new_payload))
        return('cached')
    'call'
}

#' meta 行:「模型 · 耗時s」,耗時四捨五入到 1 位小數
.askllm_meta_line <- function(model, elapsed) {
    paste0(model, ' · ', round(as.numeric(elapsed), 1), 's')
}

#' provider 代碼 → 顯示名稱(對應 a.yaml 選項標題)
.askllm_provider_name <- function(name) {
    switch(name,
        nim    = 'NVIDIA NIM',
        gemini = 'Google Gemini',
        github = 'GitHub Models',
        ollama = 'Ollama (local)',
        custom = 'Custom (OpenAI-compatible)',
        name)
}

#' 送給 LLM 的 system prompt(英文,措辭精簡)
.askllm_system_prompt <- function() {
    paste(
        'You are a statistical analysis assistant embedded in jamovi.',
        'Answer the user\'s questions about their dataset using the provided',
        'summary statistics. Be concise, accurate, and practical. If the',
        'summary is insufficient to answer, say so briefly rather than guessing.',
        sep = ' ')
}

#' 送出後、回覆前顯示的等待訊息(繁中 + 英文)
#'
#' 搭配 ResultsElement$setStatus('running') 與 private$.checkpoint() 推送到
#' 畫面,使用者才知道分析正在等 LLM,而不是當掉。
.askllm_waiting_text <- function(provider_name, model) {
    paste(
        sprintf('正在等候 %s 回覆…', provider_name),
        sprintf('Waiting for a response from %s…', provider_name),
        '',
        sprintf('模型 / model: %s', model %||% ''),
        '視模型與網路狀況,通常需要數秒至數十秒。',
        'This usually takes a few seconds, depending on the model and network.',
        sep = '\n')
}

#' 引導/教學文字(繁中 + 英文對照),零網路,供 .init() 與守門顯示
.askllm_guide_text <- function() {
    paste(
        '如何使用 Ask LLM / How to use Ask LLM',
        '',
        '1. 勾選要描述的變項(Variables to describe)。',
        '   Select the variables you want described.',
        '2. 輸入你的問題(英文或中文皆可)。',
        '   Type your question (English or Chinese both work).',
        '3. 勾選「Submit」送出,稍候即可看到回覆。',
        '   Tick "Submit" to send; the response appears in a moment.',
        '',
        '隱私提醒 / Privacy:',
        '勾選 Submit 後,所選變項的「摘要統計」(非原始資料列)將傳送到',
        '所選的 LLM 服務。若不希望任何資料外送,可改用 Ollama(本機)。',
        'After you tick Submit, the SUMMARY STATISTICS of the selected',
        'variables (never the raw data rows) are sent to the chosen LLM',
        'service. Use Ollama (local) if you prefer zero data to leave your machine.',
        '',
        '防抖提醒 / Debounce:',
        '修改問題前請先取消「Submit」勾選,改好後再重新勾選,',
        '以免每次改動都觸發一次呼叫(與計費)。',
        'Untick "Submit" before editing your question, then re-tick it,',
        'so that edits do not each trigger a new call (and billing).',
        sep = '\n')
}

# =============================================================================
# R6 分析類別:防抖狀態機。.run() 嚴格依序,全程 tryCatch 保底。
# =============================================================================

askllmClass <- if (requireNamespace('jmvcore', quietly=TRUE)) R6::R6Class(
    "askllmClass",
    inherit = askllmBase,
    private = list(

        # 只設定引導文字,零網路
        .init = function() {
            self$results$instructions$setContent(.askllm_guide_text())
        },

        # 狀態機外層:任何未預期 R error → instructions 顯示,不讓 jamovi 紅字
        .run = function() {
            tryCatch(
                private$.runInner(),
                error = function(e) {
                    self$results$instructions$setContent(
                        paste0('內部錯誤:', conditionMessage(e)))
                })
        },

        .runInner = function() {
            opt <- self$options

            # --- 1. 守門 ---------------------------------------------------
            question <- opt$question
            if (!isTRUE(opt$submit) || !nzchar(trimws(question %||% ''))) {
                self$results$instructions$setContent(.askllm_guide_text())
                return()
            }

            # --- 2. 組 payload --------------------------------------------
            summary_text <- NULL
            if (isTRUE(opt$includeSummary) && length(opt$vars) > 0) {
                summary_text <- summarize_data(
                    self$data, opt$vars, max_levels = opt$maxLevels)
            }

            spec <- provider_spec(opt$provider, opt$baseUrl)
            if (!is.null(spec$error)) {
                self$results$instructions$setContent(paste0(
                    spec$error, '\n\n',
                    '請在選項的「Base URL (custom provider)」欄位填入自訂端點,',
                    '再重新勾選 Submit。'))
                return()
            }

            model <- if (nzchar(opt$model)) opt$model else spec$default_model
            if (!nzchar(model)) {
                self$results$instructions$setContent(paste0(
                    '此 provider 未提供預設模型,請在「Model」欄位填入模型名稱後,',
                    '重新勾選 Submit。'))
                return()
            }

            payload <- .askllm_build_payload(
                question, summary_text, spec$base_url, model)

            # --- 3. state 快取比對 ----------------------------------------
            st <- self$results$answer$state
            decision <- .askllm_decide(
                opt$submit, question,
                if (is.null(st)) NULL else st$payload, payload)

            if (identical(decision, 'cached')) {
                self$results$answer$setContent(st$text)
                self$results$meta$setContent(paste0(st$meta_line, ' · cached'))
                self$results$instructions$setContent('(快取回放,未呼叫 API)')
                return()
            }

            # --- 4. 金鑰 --------------------------------------------------
            api_key <- 'ollama'   # ollama 免金鑰,用佔位 key
            if (isTRUE(spec$needs_key)) {
                kv <- load_api_key(spec$env_vars)
                if (is.null(kv)) {
                    self$results$instructions$setContent(key_setup_text(
                        .askllm_provider_name(opt$provider),
                        spec$env_vars[1],
                        spec$signup_url,
                        spec$key_example %||% '<your-api-key>'))
                    return()
                }
                api_key <- kv$key
            }

            # --- 5. 等待狀態:先把「等候中」推送到畫面 --------------------
            # ResultsElement$setStatus('running') 對應 jamovi 的
            # ANALYSIS_RUNNING(與 Bayes 類分析同一個等待指示);
            # private$.checkpoint() 立即序列化並送出當下結果,
            # 否則畫面要等 .run() 整個結束才更新。
            waiting <- .askllm_waiting_text(
                .askllm_provider_name(opt$provider), model)
            self$results$instructions$setContent(waiting)
            self$results$answer$setStatus('running')
            self$results$meta$setStatus('running')
            private$.checkpoint()

            # --- 6. 呼叫 --------------------------------------------------
            res <- ask_llm(
                question      = question,
                summary_text  = summary_text,
                base_url      = spec$base_url,
                model         = model,
                api_key       = api_key,
                system_prompt = .askllm_system_prompt(),
                max_tokens    = 4096)

            # --- 7. 呈現 --------------------------------------------------
            self$results$answer$setStatus('complete')
            self$results$meta$setStatus('complete')

            if (isTRUE(res$ok)) {
                self$results$answer$setContent(res$text)
                meta_line <- .askllm_meta_line(model, res$elapsed_s)
                self$results$meta$setContent(meta_line)
                self$results$answer$setState(list(
                    payload   = payload,
                    text      = res$text,
                    meta_line = meta_line))
                self$results$instructions$setContent('完成。')
            } else {
                # 失敗:保留上次成功的 answer/meta(不動),不 setState
                self$results$instructions$setContent(paste0(
                    res$error, '\n\n修正後重新勾選 Submit。'))
            }
        })
)
