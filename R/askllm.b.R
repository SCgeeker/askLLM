
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
#' payload = 問題 + 摘要 + base_url + model + context_text + role + prompt_lang
#' + system_prompt,以控制字元分隔避免歧義。summary_text/context_text 可為
#' NULL(視為空字串)。context_text/role/prompt_lang/system_prompt 均有預設值,
#' 舊呼叫方式(四或五參數)輸出與升版前逐位相同。
#'
#' role/prompt_lang/system_prompt 三者納入指紋(payload 格式 v1.2):
#' 切換人格、切換語言、或修改自訂 system prompt 都必須被視為「新請求」,
#' 否則防抖快取會誤判為 cached、畫面顯示舊人格/舊語言的回覆。
.askllm_build_payload <- function(question, summary_text, base_url, model,
                                  context_text = '', role = 'consultant',
                                  prompt_lang = 'en', system_prompt = '') {
    paste(
        question %||% '',
        summary_text %||% '',
        base_url %||% '',
        model %||% '',
        context_text %||% '',
        role %||% '',
        prompt_lang %||% '',
        system_prompt %||% '',
        sep = .ASKLLM_SEP)
}

#' includeCatalog 為 TRUE 時掃描本機模組並組出 catalog/available 文字
#'
#' 檔案層級純函式,供 `.runInner()` 呼叫,亦供測試以
#' `testthat::local_mocked_bindings()` 注入 `scan_modules` 直接驗證
#' (S7:includeCatalog=FALSE 時完全不呼叫 scan_modules)。
#'
#' 任一環節失敗(掃描失敗、known-modules 遺失/解析失敗)都靜默降級為
#' NULL,絕不 `stop()`。available 只在 catalog 存在時才可能組出。
#'
#' @param includeCatalog 選項值(非 TRUE 時完全不呼叫 scan_modules)。
#' @param known_path `known-modules.yaml` 路徑;NULL 時以
#'   `system.file('catalog', 'known-modules.yaml', package = 'askLLM')` 定位
#'   (測試以此參數注入 fixture 路徑)。
#' @return `list(catalog_text = <chr(1) 或 NULL>, available_text = <chr(1) 或 NULL>)`
.askllm_gather_context <- function(includeCatalog, known_path = NULL) {
    if (!isTRUE(includeCatalog))
        return(list(catalog_text = NULL, available_text = NULL))

    scanned <- tryCatch(scan_modules(), error = function(e) NULL)
    ct <- tryCatch(catalog_text(scanned), error = function(e) NULL)

    at <- NULL
    if (!is.null(ct)) {
        at <- tryCatch({
            kp <- known_path %||% system.file(
                'catalog', 'known-modules.yaml', package = 'askLLM')
            if (!nzchar(kp)) return(NULL)
            known <- yaml::read_yaml(kp)
            installed_names <- vapply(
                scanned$modules %||% list(), function(m) m$name %||% '',
                character(1))
            available_text(known, installed_names)
        }, error = function(e) NULL)
    }

    list(catalog_text = ct, available_text = at)
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
        nim        = 'NVIDIA NIM',
        gemini     = 'Google Gemini',
        openrouter = 'OpenRouter',
        github     = 'GitHub Models',
        ollama     = 'Ollama (local)',
        custom     = 'Custom (OpenAI-compatible)',
        name)
}

#' 人格 x 語言 system prompt 模板(項目 1:role 選擇器)
#'
#' `consultant`/`en` 為 v1.0 逐字原句(降級保證,見 `.askllm_system_prompt()`)。
#' 其餘五格為新撰寫:`tutor` 蘇格拉底式引導、`explainer` 面向初學者逐步解說。
#' 以 named list `prompts[[role]][[lang]]` 組織,方便日後在此擴充其他語言。
.ASKLLM_PROMPTS <- list(
    consultant = list(
        en = paste(
            'You are a statistical analysis assistant embedded in jamovi.',
            'Answer the user\'s questions about their dataset using the provided',
            'summary statistics. Be concise, accurate, and practical. If the',
            'summary is insufficient to answer, say so briefly rather than guessing.',
            sep = ' '),
        zh = paste0(
            '你是內嵌於 jamovi 的統計分析助理。請根據系統提供的摘要統計量,',
            '精簡、準確、務實地回答使用者關於資料集的問題。',
            '若摘要資訊不足以回答,請直接簡短說明,不要臆測。')),
    tutor = list(
        en = paste(
            'You are a statistics tutor embedded in jamovi, teaching through',
            'Socratic dialogue. Given the user\'s question and the provided',
            'summary statistics, do not give the final answer directly. Instead,',
            'ask guiding questions and offer hints that help the user reason',
            'through the problem themselves, checking their understanding step',
            'by step. If the summary is insufficient, say so briefly rather than',
            'guessing.',
            sep = ' '),
        zh = paste0(
            '你是內嵌於 jamovi 的統計導師,採用蘇格拉底式教學法。',
            '面對使用者的問題與系統提供的摘要統計量,請不要直接給出最終答案,',
            '而是透過提問與提示,引導使用者一步步自己推理出答案,',
            '並適時確認其理解是否正確。',
            '若摘要資訊不足,請直接簡短說明,不要臆測。')),
    explainer = list(
        en = paste(
            'You are a statistics explainer embedded in jamovi, helping beginners',
            'understand their data. Given the user\'s question and the provided',
            'summary statistics, explain the answer step by step in plain language,',
            'defining any statistical terms you use. Assume no prior background in',
            'statistics. If the summary is insufficient to answer, say so briefly',
            'rather than guessing.',
            sep = ' '),
        zh = paste0(
            '你是內嵌於 jamovi 的統計解說員,協助初學者理解自己的資料。',
            '請針對使用者的問題與系統提供的摘要統計量,以淺顯易懂的語言逐步說明,',
            '並解釋所使用的統計名詞的定義。假設使用者沒有統計學背景。',
            '若摘要資訊不足以回答,請直接簡短說明,不要臆測。')))

#' catalog 約束句(防路徑捏造),依語言分岐;三種人格、兩種語言皆附加相同句
#'
#' en 版與 v1.0 逐字相同(降級保證);zh 版為對應翻譯。
.ASKLLM_CATALOG_SUFFIX <- list(
    en = paste(
        'When a list of installed analyses is provided, recommend analyses ONLY',
        'from that list and cite each menu path exactly as written. If nothing',
        'installed fits, suggest a module ONLY if its name appears literally in the',
        'provided available-modules list; never name a module that is not in that',
        'list, even one you believe exists, and never invent menu paths.',
        sep = ' '),
    zh = paste0(
        '當系統提供已安裝分析清單時,建議的分析僅能出自該清單,',
        '並逐字引用選單路徑。若清單中沒有合適的分析,',
        '僅在該模組名稱明確出現於提供的「可用模組清單」中時才可建議該模組;',
        '絕不可提及不在清單中的模組(即使你認為它存在),也絕不可捏造選單路徑。'))

#' 送給 LLM 的 system prompt
#'
#' 優先序:`system_prompt`(去空白後非空)＞ `prompts[[role]][[lang]]`。
#' 未知 role/lang 防禦性落回 `consultant`/`en`。
#' has_catalog = TRUE 時,不論走模板或自訂 system_prompt,一律以單一空白
#' 接續附加對應語言的 catalog 約束句。
#'
#' 降級保證:role='consultant'、lang='en'、system_prompt=''、
#' has_catalog=FALSE 時,回傳字串與 v1.0/v1.1 逐字相同。
.askllm_system_prompt <- function(role = 'consultant', lang = 'en',
                                  system_prompt = '', has_catalog = FALSE) {
    if (is.null(role) || !role %in% names(.ASKLLM_PROMPTS)) role <- 'consultant'
    if (is.null(lang) || !lang %in% c('en', 'zh')) lang <- 'en'

    custom <- trimws(system_prompt %||% '')
    base <- if (nzchar(custom)) custom else .ASKLLM_PROMPTS[[role]][[lang]]

    if (!isTRUE(has_catalog)) return(base)

    paste(base, .ASKLLM_CATALOG_SUFFIX[[lang]])
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

#' 回覆成功後顯示的查證提醒
#'
#' 實測(見 docs/LIMITATIONS)顯示各家模型最常編造的是 **jamovi 選單路徑**
#' ——連 jamovi 沒有的選單(如「分類 > 判別分析」、「視覺 > 分類圖形」)都
#' 寫得很有把握。統計建議本身通常合理,但路徑與具體數值必須自行核對。
#'
#' 第一點依 `has_catalog` 誠實描述:附上本機模組清單時(includeCatalog 開)
#' 才說「已比對」;未附時(includeCatalog 關或掃描失敗)明說「未經比對」,
#' 不得謊稱比對過——這是模組可信度的一部分。
#'
#' @param has_catalog 本次呼叫是否附上了本機已安裝模組清單。
.askllm_caveat_text <- function(has_catalog = TRUE) {
    first_zh <- if (isTRUE(has_catalog))
        '  • 選單路徑已比對本機安裝清單,仍請以實際介面為準。'
    else
        '  • 選單路徑未經比對(未附上已安裝模組清單),請以實際介面為準。'
    first_en <- if (isTRUE(has_catalog))
        c('  • Menu paths are checked against your locally installed modules;',
          '    still verify them in the actual interface.')
    else
        c('  • Menu paths were NOT verified (the installed-module list was',
          '    not attached); verify them in the actual interface.')

    paste(c(
        '⚠ 回覆由 LLM 生成,可能有誤,請務必自行查證:',
        first_zh,
        '  • 統計建議請以你的研究問題與資料條件判斷是否適用。',
        '  • 回覆中的數值若與 jamovi 實際分析結果不符,以 jamovi 為準。',
        '',
        '⚠ This answer is generated by an LLM and may be wrong. Please verify:',
        first_en,
        '  • Judge the statistical advice against your own research question.',
        '  • Where numbers disagree with jamovi output, jamovi is correct.'),
        collapse = '\n')
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
        '為了讓建議指向真實選單,已安裝 jamovi 模組的「名稱與選單清單」(環境中繼資料,不含你的任何資料內容)也會一併傳送;取消勾選「Include installed modules」即可停用。',
        'After you tick Submit, the SUMMARY STATISTICS of the selected',
        'variables (never the raw data rows) are sent to the chosen LLM',
        'service. Use Ollama (local) if you prefer zero data to leave your machine.',
        'To ground suggestions in real menus, the NAMES AND MENU PATHS of your installed jamovi modules (environment metadata, none of your data) are also sent; untick "Include installed modules" to disable this.',
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

            # --- 2b. 模組目錄掃描(includeCatalog 開時才做;任一環節失敗皆
            #         靜默降級為 NULL,絕不 stop()、絕不中斷主流程) ---------
            ctx <- .askllm_gather_context(opt$includeCatalog)
            catalog_text_value <- ctx$catalog_text
            available_text_value <- ctx$available_text

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

            context_text <- if (is.null(catalog_text_value) && is.null(available_text_value)) {
                ''
            } else {
                paste(catalog_text_value %||% '', available_text_value %||% '', sep = '\n')
            }
            payload <- .askllm_build_payload(
                question, summary_text, spec$base_url, model,
                context_text = context_text,
                role = opt$role, prompt_lang = opt$promptLang,
                system_prompt = opt$systemPrompt)

            # --- 3. state 快取比對 ----------------------------------------
            st <- self$results$answer$state
            decision <- .askllm_decide(
                opt$submit, question,
                if (is.null(st)) NULL else st$payload, payload)

            if (identical(decision, 'cached')) {
                self$results$answer$setContent(st$text)
                self$results$meta$setContent(paste0(st$meta_line, ' · cached'))
                self$results$instructions$setContent(paste0(
                    '(快取回放,未呼叫 API / cache replay, no API call)\n\n',
                    .askllm_caveat_text(has_catalog = isTRUE(st$has_catalog))))
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
                question       = question,
                summary_text   = summary_text,
                catalog_text   = catalog_text_value,
                available_text = available_text_value,
                base_url       = spec$base_url,
                model          = model,
                api_key        = api_key,
                system_prompt  = .askllm_system_prompt(
                    role          = opt$role,
                    lang          = opt$promptLang,
                    system_prompt = opt$systemPrompt,
                    has_catalog   = !is.null(catalog_text_value)),
                max_tokens     = 4096)

            # --- 7. 呈現 --------------------------------------------------
            self$results$answer$setStatus('complete')
            self$results$meta$setStatus('complete')

            if (isTRUE(res$ok)) {
                self$results$answer$setContent(res$text)
                meta_line <- .askllm_meta_line(model, res$elapsed_s)
                self$results$meta$setContent(meta_line)
                has_catalog <- !is.null(catalog_text_value)
                self$results$answer$setState(list(
                    payload     = payload,
                    text        = res$text,
                    meta_line   = meta_line,
                    has_catalog = has_catalog))
                self$results$instructions$setContent(
                    .askllm_caveat_text(has_catalog = has_catalog))
            } else {
                # 失敗:保留上次成功的 answer/meta(不動),不 setState
                self$results$instructions$setContent(paste0(
                    res$error, '\n\n修正後重新勾選 Submit。'))
            }
        })
)
