
# This file is a generated template, your changes will not be overwritten

# =============================================================================
# askllmr(R code tutor)分析類別 —— M-A3:接上真邏輯。
#
# 可測邏輯(system prompt 組裝、code/explanation 拆分、caveat/links 文字)
# 皆為 R/r-tutor.R 的檔案層純函式(`.askllmr_*`);此檔只留 R6 類別本體與
# `.runInner()` 狀態機,plumbing(provider_spec/load_api_key/ask_llm/
# translate_error 等)與諮詢分析 askllm.b.R 共用,不重造。
# =============================================================================

askllmrClass <- if (requireNamespace('jmvcore', quietly=TRUE)) R6::R6Class(
    "askllmrClass",
    inherit = askllmrBase,
    private = list(

        # 靜態內容(S3):引導文字 + links 骨架(預設假設已裝 Rj,.run() 會依
        # 實際掃描結果修正)。零網路、不掃 Rj。
        .init = function() {
            self$results$instructions$setContent(.askllmr_guide_text())
            self$results$links$setContent(.askllmr_links_html(TRUE))
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
            # 與諮詢分析 askllm.b.R 共用同一函式(見 llm-ping.R),此處只負責
            # 寫入 instructions 並提前 return,絕不進入下方 submit/ask_llm 流程。
            if (isTRUE(opt$testConnection)) {
                self$results$instructions$setContent(
                    .askllm_test_connection_text(opt))
                return()
            }

            # --- Rj 掃描(強制,不設開關)------------------------------------
            # 提前於守門(1)執行:守門失敗時的引導文字與成功分支的 instructions
            # 前置句都需要知道 Rj 是否已裝(見下方步驟 1/10),故此處先掃一次,
            # 供全流程共用,不重複掃描。任何失敗一律降級為「未裝」,絕不 stop()。
            rj <- tryCatch(scan_rj(), error = function(e) NULL)
            rj_env_text_value <- if (is.null(rj)) NULL else rj_env_text(rj)
            has_rj_env <- !is.null(rj_env_text_value)
            rj_installed <- isTRUE(rj$installed)

            # --- 1. 守門 -----------------------------------------------------
            question <- opt$question
            if (!isTRUE(opt$submit) || !nzchar(trimws(question %||% ''))) {
                guide <- .askllmr_guide_text()
                if (!rj_installed)
                    guide <- paste(.askllmr_no_rj_text(), '', guide, sep = '\n')
                self$results$instructions$setContent(guide)
                self$results$links$setContent(.askllmr_links_html(rj_installed))
                return()
            }

            # --- 2. 摘要 -------------------------------------------------------
            summary_text <- NULL
            if (isTRUE(opt$includeSummary) && length(opt$vars) > 0) {
                summary_text <- summarize_data(
                    self$data, opt$vars, max_levels = 10)
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

            # --- 3.(rj 已於上方掃描)-------------------------------------------

            # --- 4. 變數 Description 當 system prompt(僅 systemPromptVar)------
            # askllmr 無 `systemPrompt` TextBox(M-A2 面板檢視後簽核),自訂
            # system prompt 只走這個管道;讀法與 askllm.b.R 相同(防禦性
            # tryCatch,headless 測試環境不存在 jmv-desc attribute)。
            var_desc <- if (!is.null(opt$systemPromptVar) && nzchar(opt$systemPromptVar)) {
                tryCatch(
                    attr(self$data[[opt$systemPromptVar]], 'jmv-desc'),
                    error = function(e) NULL)
            } else {
                NULL
            }
            custom <- .askllm_resolve_custom(var_desc %||% '', '')

            # --- 5. payload(rj 文字經 context_text 進指紋)----------------------
            payload <- .askllm_build_payload(
                question, summary_text, spec$base_url, model,
                context_text = rj_env_text_value %||% '',
                role = opt$role, prompt_lang = opt$promptLang,
                system_prompt = custom,
                system_prompt_var = opt$systemPromptVar %||% '')

            # --- 6. state 快取比對(state 存於 code 結果項)------------------------
            st <- self$results$code$state
            decision <- .askllm_decide(
                opt$submit, question,
                if (is.null(st)) NULL else st$payload, payload)

            if (identical(decision, 'cached')) {
                self$results$code$setContent(st$code)
                self$results$explanation$setContent(st$explanation)
                self$results$meta$setContent(paste0(st$meta_line, ' · cached'))
                self$results$caveat$setContent(
                    .askllmr_caveat_text(has_rj_env = st$has_rj_env))
                self$results$links$setContent(.askllmr_links_html(rj_installed))

                instr <- '(cache replay, no API call / 快取回放,未呼叫 API)'
                if (!rj_installed)
                    instr <- paste(.askllmr_no_rj_text(), '', instr, sep = '\n')
                self$results$instructions$setContent(instr)
                return()
            }

            # --- 7. 金鑰 ---------------------------------------------------------
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

            # --- 8. 等待狀態:先把「等候中」推送到畫面 --------------------------
            waiting <- .askllm_waiting_text(
                .askllm_provider_name(opt$provider), model)
            if (!rj_installed)
                waiting <- paste(.askllmr_no_rj_text(), '', waiting, sep = '\n')
            self$results$instructions$setContent(waiting)
            self$results$code$setStatus('running')
            self$results$meta$setStatus('running')
            private$.checkpoint()

            # --- 9. 呼叫 ---------------------------------------------------------
            # Rj 未裝分支不阻擋:has_rj_env=FALSE 時 rj_env_text_value 為 NULL,
            # LLM 依 .ASKLLM_RJ_COMMON 的規則改教 Syntax Mode(build_prompt/
            # .askllmr_system_prompt 對此已有降級處理,見 R/r-tutor.R)。
            res <- ask_llm(
                question       = question,
                summary_text   = summary_text,
                catalog_text   = NULL,
                available_text = NULL,
                rj_env_text    = rj_env_text_value,
                base_url       = spec$base_url,
                model          = model,
                api_key        = api_key,
                system_prompt  = .askllmr_system_prompt(
                    role          = opt$role,
                    lang          = opt$promptLang,
                    system_prompt = custom,
                    has_rj_env    = has_rj_env),
                max_tokens     = 4096)

            # --- 10. 呈現 --------------------------------------------------------
            self$results$code$setStatus('complete')
            self$results$meta$setStatus('complete')

            if (isTRUE(res$ok)) {
                parts <- .askllmr_split(res$text)
                self$results$code$setContent(parts$code)
                self$results$explanation$setContent(parts$explanation)
                meta_line <- .askllm_meta_line(model, res$elapsed_s)
                self$results$meta$setContent(meta_line)
                self$results$caveat$setContent(
                    .askllmr_caveat_text(has_rj_env = has_rj_env))
                self$results$links$setContent(.askllmr_links_html(rj_installed))

                self$results$code$setState(list(
                    payload     = payload,
                    code        = parts$code,
                    explanation = parts$explanation,
                    meta_line   = meta_line,
                    has_rj_env  = has_rj_env))

                # instructions 清空或放簡短成功提示;Rj 未裝時前置靜態提示
                success_msg <- if (rj_installed) '' else .askllmr_no_rj_text()
                self$results$instructions$setContent(success_msg)
            } else {
                # 失敗:保留上次成功的 code/explanation/meta(不動),不 setState
                instr <- paste0(res$error, '\n\n修正後重新勾選 Submit。')
                if (!rj_installed)
                    instr <- paste(.askllmr_no_rj_text(), '', instr, sep = '\n')
                self$results$instructions$setContent(instr)
            }
        })
)
