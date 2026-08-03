
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
#'
#' system_prompt_var 納入指紋(payload 格式 v1.3,項目:變數 Description 當
#' system prompt):換一個 systemPromptVar 變數,即使當下解析出的 custom
#' 字串剛好相同,也要視為新請求;而 system_prompt 欄位本身已放的是「解析後」
#' 的 custom 值(見 .askllm_resolve_custom()),故換變數或改該變數的
#' Description(解析結果因而改變)都會反映在 system_prompt 欄位上,兩者合計
#' 涵蓋所有防抖情境。預設值 '' 使舊呼叫方式(無此參數)輸出逐字相同。
.askllm_build_payload <- function(question, summary_text, base_url, model,
                                  context_text = '', role = 'consultant',
                                  prompt_lang = 'en', system_prompt = '',
                                  system_prompt_var = '', enable_actions = FALSE) {
    paste(
        question %||% '',
        summary_text %||% '',
        base_url %||% '',
        model %||% '',
        context_text %||% '',
        role %||% '',
        prompt_lang %||% '',
        system_prompt %||% '',
        system_prompt_var %||% '',
        as.character(isTRUE(enable_actions)),  # 格式 v1.4:動作開關納入指紋
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

#' 動作能力句(Phase 1:enable_actions=TRUE 時附加,治「捏造動作能力」幻覺)
#'
#' 按人格分工三份(對照 `.ASKLLM_PROMPTS` 亦 per-role)。三者在動作模式的區別軸:
#'   - `consultant`:自動動手 + **精簡執行摘要**(做了什麼、關鍵數字、一句實務結論)。
#'   - `explainer` :自動動手 + **教學式解讀**(逐步讀表、定義統計量、結論如何得出;
#'                  假設零基礎)——與 consultant 的差別在「結果呈現的教學深度」。
#'   - `tutor`     :**克制引導**——優先引導使用者自己跑,僅在其明確要求時才動手
#'                  (蘇格拉底式教學法與「自動執行」本質衝突,故不與前二者共用)。
#' 三版皆含誠實邊界(僅執行清單內分析、絕不聲稱做了未做的事)。persona 決定 reply
#' 語氣,action 本身為共通機械產物。
#' Phase 1 範圍只含「執行 jmv 分析」;filter/transform 的「只能給文字」邊界待
#' Phase 3 再併入本句。
.ASKLLM_ACTION_SUFFIX <- list(
    consultant = list(
        en = paste(
            'You can now act, not just advise: when the question can be answered',
            'by an analysis in the provided list, run it directly and report the',
            'result concisely — what you ran, the key numbers, and a one-line',
            'practical takeaway. Only run analyses from the provided list, and',
            'never claim to have run an analysis you did not. You can also create',
            'a computed column (a value snapshot) from a formula over existing',
            'variables. Write your reply in your consultant voice.',
            sep = ' '),
        zh = paste0(
            '你現在可以動手,不只是建議:當問題可用提供清單中的分析回答時,',
            '直接執行該分析並精簡回報——做了什麼分析、關鍵數字、',
            '以及一句實務結論。僅能執行提供清單中的分析,',
            '且絕不可聲稱執行了未實際執行的分析。你也可以依現有變數的公式建立',
            '計算欄(值快照)。回覆時請維持顧問的精簡語氣。')),
    explainer = list(
        en = paste(
            'You can now act, not just advise: when the question can be answered',
            'by an analysis in the provided list, run the appropriate analysis.',
            'After running it, walk the user through the result table step by',
            'step, defining each statistic you mention, and show how the',
            'conclusion follows — assume no statistics background. Only run',
            'analyses from the provided list, and never claim to have run an',
            'analysis you did not. You can also create a computed column (a value',
            'snapshot) from a formula over existing variables. Write your reply in',
            'your explainer voice.',
            sep = ' '),
        zh = paste0(
            '你現在可以動手,不只是建議:當問題可用提供清單中的分析回答時,',
            '直接執行適當的分析。執行後,請帶著使用者逐步解讀結果表,',
            '定義你提到的每個統計量,並說明結論如何得出——',
            '假設使用者沒有統計背景。僅能執行提供清單中的分析,',
            '且絕不可聲稱執行了未實際執行的分析。你也可以依現有變數的公式建立',
            '計算欄(值快照)。回覆時請維持解說員的淺白語氣。')),
    tutor = list(
        en = paste(
            'You may run analyses, but prefer guiding the user to choose and run',
            'the analysis themselves; only act when they explicitly ask you to,',
            'and give a brief rationale. Only run analyses from the provided list,',
            'and never claim to have run an analysis you did not. If the user asks,',
            'you can also create a computed column from a formula over existing',
            'variables. Keep your reply in your Socratic teaching voice.',
            sep = ' '),
        zh = paste0(
            '你可以執行分析,但請優先引導使用者自己選擇並執行分析;',
            '僅在使用者明確要求時才動手,並附上簡短理由。',
            '僅能執行提供清單中的分析,且絕不可聲稱執行了未實際執行的分析。',
            '若使用者要求,你也可以依現有變數的公式建立計算欄。',
            '回覆時請維持蘇格拉底式教學語氣。')))

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
                                  system_prompt = '', has_catalog = FALSE,
                                  enable_actions = FALSE) {
    if (is.null(role) || !role %in% names(.ASKLLM_PROMPTS)) role <- 'consultant'
    if (is.null(lang) || !lang %in% c('en', 'zh')) lang <- 'en'

    custom <- trimws(system_prompt %||% '')
    base <- if (nzchar(custom)) custom else .ASKLLM_PROMPTS[[role]][[lang]]

    # 降級保證:has_catalog=FALSE 且 enable_actions=FALSE 時回傳 base(逐字同 v1.1)
    out <- base
    if (isTRUE(has_catalog))
        out <- paste(out, .ASKLLM_CATALOG_SUFFIX[[lang]])
    if (isTRUE(enable_actions))
        out <- paste(out, .ASKLLM_ACTION_SUFFIX[[role]][[lang]])  # role 已落回三者之一
    out
}

#' 解析「custom system prompt」的優先序(項目:變數 Description 當 system prompt)
#'
#' 優先序(最高在前):
#'   1. var_desc(去空白後非空)→ 用它(來源:某變數的 jmv-desc attribute)
#'   2. text(去空白後非空)→ 用它(來源:systemPrompt TextBox)
#'   3. 皆空 → 回傳 ''(由呼叫端落回 role x lang 模板)
#'
#' 純函式,可離線單元測試。`jmv-desc` attribute 本身只在 jamovi engine 執行時
#' 才會掛在 self$data[[var]] 上(headless 測試環境不存在,已於真 jamovi 28.1
#' 實測確認),故 .runInner() 讀取該 attribute 的那一行改以防禦性
#' tryCatch(..., error = function(e) NULL) 處理,靠這個純函式涵蓋優先序邏輯。
.askllm_resolve_custom <- function(var_desc, text) {
    vd <- trimws(var_desc %||% '')
    if (nzchar(vd)) return(vd)
    trimws(text %||% '')
}

#' 送出後、回覆前顯示的等待訊息(先英文整段,再中文整段)
#'
#' 搭配 ResultsElement$setStatus('running') 與 private$.checkpoint() 推送到
#' 畫面,使用者才知道分析正在等 LLM,而不是當掉。
#' 排版:段落區塊文字語言一致,先英文再中文(見 dev-notes/gui-manual-test-checklist)。
.askllm_waiting_text <- function(provider_name, model) {
    paste(
        sprintf('Waiting for a response from %s…', provider_name),
        sprintf('Model: %s', model %||% ''),
        'This usually takes a few seconds, depending on the model and network.',
        '',
        sprintf('正在等候 %s 回覆…', provider_name),
        sprintf('模型:%s', model %||% ''),
        '視模型與網路狀況,通常需要數秒至數十秒。',
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

    # 排版:先英文整段,再中文整段(區塊內語言一致,見 dev-notes/gui-manual-test-checklist)
    paste(c(
        '⚠ This answer is generated by an LLM and may be wrong. Please verify:',
        first_en,
        '  • Judge the statistical advice against your own research question.',
        '  • Where numbers disagree with jamovi output, jamovi is correct.',
        '',
        '⚠ 回覆由 LLM 生成,可能有誤,請務必自行查證:',
        first_zh,
        '  • 統計建議請以你的研究問題與資料條件判斷是否適用。',
        '  • 回覆中的數值若與 jamovi 實際分析結果不符,以 jamovi 為準。'),
        collapse = '\n')
}

#' 引導/教學文字(先英文整段,再中文整段),零網路,供 .init() 與守門顯示
#'
#' 排版:段落區塊文字語言一致,先英文再中文(見 dev-notes/gui-manual-test-checklist)。
.askllm_guide_text <- function() {
    paste(
        'How to use Ask LLM',
        '',
        '1. Select the variables you want described.',
        '2. Type your question (English or Chinese both work).',
        '3. Tick "Submit" to send; the response appears in a moment.',
        '',
        'Privacy:',
        'After you tick Submit, the SUMMARY STATISTICS of the selected',
        'variables (never the raw data rows) are sent to the chosen LLM',
        'service. Use Ollama (local) if you prefer zero data to leave your machine.',
        'To ground suggestions in real menus, the NAMES AND MENU PATHS of your installed jamovi modules (environment metadata, none of your data) are also sent; untick "Include installed modules" to disable this.',
        '',
        'Debounce:',
        'Untick "Submit" before editing your question, then re-tick it,',
        'so that edits do not each trigger a new call (and billing).',
        '',
        '如何使用 Ask LLM',
        '',
        '1. 勾選要描述的變項(Variables to describe)。',
        '2. 輸入你的問題(英文或中文皆可)。',
        '3. 勾選「Submit」送出,稍候即可看到回覆。',
        '',
        '隱私提醒:',
        '勾選 Submit 後,所選變項的「摘要統計」(非原始資料列)將傳送到',
        '所選的 LLM 服務。若不希望任何資料外送,可改用 Ollama(本機)。',
        '為了讓建議指向真實選單,已安裝 jamovi 模組的「名稱與選單清單」(環境中繼資料,不含你的任何資料內容)也會一併傳送;取消勾選「Include installed modules」即可停用。',
        '',
        '防抖提醒:',
        '修改問題前請先取消「Submit」勾選,改好後再重新勾選,',
        '以免每次改動都觸發一次呼叫(與計費)。',
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

            # --- 0. Test Connection(非課金疎通檢查,優先於 submit)---------
            # 邏輯抽於 .askllm_test_connection_text()(檔案層級純函式,見
            # llm-ping.R),此處只負責寫入 instructions 並提前 return,
            # 絕不進入下方任何 submit/ask_llm 流程。
            if (isTRUE(opt$testConnection)) {
                self$results$instructions$setContent(
                    .askllm_test_connection_text(opt))
                return()
            }

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

            # --- 2c. 變數 Description 當 system prompt(項目:systemPromptVar)---
            # `jmv-desc` 是官方無文件的隱性通道:在真 jamovi 28.1 實測確認,
            # engine 執行 .b.R 時會把該變數在 Setup 面板填的 Description
            # 掛在 attr(self$data[[varName]], 'jmv-desc') 上,但這個機制沒有
            # 文件保證,headless/單元測試環境也不存在此 attribute,故全程
            # 防禦性處理:變數未選、attr 不存在、或讀取拋錯,一律靜默降級為 NULL。
            var_desc <- if (!is.null(opt$systemPromptVar) && nzchar(opt$systemPromptVar)) {
                tryCatch(
                    attr(self$data[[opt$systemPromptVar]], 'jmv-desc'),
                    error = function(e) NULL)
            } else {
                NULL
            }
            custom <- .askllm_resolve_custom(var_desc %||% '', opt$systemPrompt %||% '')

            payload <- .askllm_build_payload(
                question, summary_text, spec$base_url, model,
                context_text = context_text,
                role = opt$role, prompt_lang = opt$promptLang,
                system_prompt = custom,
                system_prompt_var = opt$systemPromptVar %||% '',
                enable_actions = isTRUE(opt$enableActions))

            # --- 3. state 快取比對 ----------------------------------------
            st <- self$results$answer$state
            decision <- .askllm_decide(
                opt$submit, question,
                if (is.null(st)) NULL else st$payload, payload)

            if (identical(decision, 'cached')) {
                self$results$answer$setContent(st$text)
                # 動作模式:state 有存動作結果時一併回放(否則表格會在重問時消失)
                if (!is.null(st$jmv_text) && nzchar(st$jmv_text))
                    self$results$jmvResults$setContent(st$jmv_text)
                if (!is.null(st$note_text) && nzchar(st$note_text))
                    self$results$actionNote$setContent(st$note_text)
                if (!is.null(st$plan_text) && nzchar(st$plan_text))
                    self$results$plan$setContent(st$plan_text)
                self$results$meta$setContent(paste0(st$meta_line, ' · cached'))
                self$results$instructions$setContent(paste0(
                    '(cache replay, no API call / 快取回放,未呼叫 API)\n\n',
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

            # --- 6*. 動作模式:結構化計畫 → 白名單驗證 → 執行 jmv → 呈現 ----
            # 整段包 tryCatch:任何 runtime 失敗降級為錯誤訊息,絕不 crash 分析。
            # 安全邊界在 validate_plan(白名單);exec_analysis 本地執行不課金。
            if (isTRUE(opt$enableActions)) {
                started_a <- Sys.time()
                out <- tryCatch({
                    sys <- .askllm_system_prompt(
                        role = opt$role, lang = opt$promptLang,
                        system_prompt = custom,
                        has_catalog = !is.null(catalog_text_value),
                        enable_actions = TRUE)
                    chat <- make_chat(base_url = spec$base_url, model = model,
                                      api_key = api_key, system_prompt = sys,
                                      max_tokens = 4096)
                    prompt <- build_prompt(question, summary_text,
                                           catalog_text = catalog_text_value,
                                           available_text = available_text_value)
                    plan <- ask_llm_structured(chat, prompt,
                                               action_type = .askllm_action_type())
                    validated <- validate_plan(plan, names(self$data))
                    exres <- lapply(validated$actions,
                                    function(a) exec_action(a, self$data))
                    list(ok = TRUE, reply = plan$reply %||% '',
                         rendered = .askllm_render_actions(validated, exres),
                         method = plan$method %||% 'text',
                         exres = exres)
                }, error = function(e) list(ok = FALSE, error = conditionMessage(e)))

                self$results$answer$setStatus('complete')
                self$results$meta$setStatus('complete')

                if (isTRUE(out$ok)) {
                    has_catalog <- !is.null(catalog_text_value)
                    elapsed_a <- as.numeric(
                        difftime(Sys.time(), started_a, units = 'secs'))
                    self$results$answer$setContent(out$reply)
                    if (nzchar(out$rendered$jmv_text))
                        self$results$jmvResults$setContent(out$rendered$jmv_text)
                    if (nzchar(out$rendered$note_text))
                        self$results$actionNote$setContent(out$rendered$note_text)
                    if (nzchar(out$rendered$plan_text))
                        self$results$plan$setContent(out$rendered$plan_text)
                    meta_line <- paste0(.askllm_meta_line(model, elapsed_a),
                                        ' · actions:', out$method)
                    self$results$meta$setContent(meta_line)

                    # Phase 2:compute_column 成功者寫回 Output 計算欄。
                    # 關鍵(Rj 模式):先啟用 Output 選項(value=TRUE)才能建欄,
                    # 見 .askllm_fill_output();整段防禦性,失敗不毀分析。
                    cc <- Filter(function(r) isTRUE(r$ok) &&
                                 identical(r$type, 'compute_column'), out$exres)
                    if (length(cc) > 0)
                        tryCatch(
                            .askllm_fill_output(
                                self$options$option('llmColumns'),
                                self$results$llmColumns, cc,
                                as.integer(rownames(self$data))),
                            error = function(e) NULL)

                    self$results$answer$setState(list(
                        payload = payload, text = out$reply, meta_line = meta_line,
                        has_catalog = has_catalog,
                        jmv_text = out$rendered$jmv_text,
                        note_text = out$rendered$note_text,
                        plan_text = out$rendered$plan_text))
                    self$results$instructions$setContent(
                        .askllm_caveat_text(has_catalog = has_catalog))
                } else {
                    self$results$instructions$setContent(paste0(
                        out$error %||% '動作執行失敗',
                        '\n\n修正後重新勾選 Submit。'))
                }
                return()
            }

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
                    system_prompt = custom,
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
