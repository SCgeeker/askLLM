# tools/compare-models.R
#
# 比較多個 LLM 對同一份資料與問題的回答,產出並排 markdown 報告,
# 用於評估回答的準確性與完整性。不隨套件安裝(位於 tools/)。
#
# Compare several LLMs on the same dataset and question, writing a
# side-by-side markdown report so you can judge accuracy and completeness.
#
# 用法 / Usage:
#   source('tools/compare-models.R')
#   compare_models(
#       models   = c('openai/gpt-4o-mini', 'openai/gpt-4.1-mini', 'microsoft/phi-4'),
#       provider = 'github')
#
#   # 換資料與問題 / different data and question:
#   compare_models(
#       models   = c('meta/llama-3.1-8b-instruct'),
#       provider = 'nim',
#       data     = mtcars,
#       vars     = c('mpg', 'hp', 'wt'),
#       question = '這份資料適合做哪些迴歸分析?')
#
# 需求 / Requirements:
#   - askLLM 已安裝(或以 pkgload::load_all() 載入原始碼)
#   - 對應 provider 的金鑰已設定(見 docs/SETUP-*.md)
#
# 注意 / Notes:
#   - 免費方案有每分鐘與每日請求上限;models 給太多會撞到限制,
#     腳本預設每次呼叫間隔 sleep_s 秒。
#   - 報告寫到 dev-notes/model-comparison-<時間戳>.md(可用 out 參數改)。

compare_models <- function(models,
                           provider = 'github',
                           data = datasets::iris,
                           vars = names(data),
                           question = paste('What analyses suit this dataset?',
                                            '請以繁體中文回答,並指出 jamovi 的選單路徑。'),
                           base_url_option = '',
                           max_tokens = 4096,
                           max_levels = 10,
                           sleep_s = 5,
                           out = NULL) {

    stopifnot(is.character(models), length(models) >= 1)

    # 允許套件已安裝或以原始碼載入兩種情境
    fn <- function(name) {
        if (requireNamespace('askLLM', quietly = TRUE) &&
            !is.null(getNamespace('askLLM')[[name]])) {
            return(getNamespace('askLLM')[[name]])
        }
        get(name, envir = globalenv())
    }
    provider_spec  <- fn('provider_spec')
    load_api_key   <- fn('load_api_key')
    summarize_data <- fn('summarize_data')
    ask_llm        <- fn('ask_llm')

    spec <- provider_spec(provider, base_url_option)
    if (!is.null(spec$error))
        stop(spec$error, call. = FALSE)

    api_key <- 'ollama'
    if (isTRUE(spec$needs_key)) {
        kv <- load_api_key(spec$env_vars)
        if (is.null(kv)) {
            stop('找不到 ', provider, ' 的金鑰,請先設定 ',
                 paste(spec$env_vars, collapse = ' 或 '), call. = FALSE)
        }
        api_key <- kv$key
        message('key source: ', kv$source)
    }

    summary_text <- summarize_data(data, vars, max_levels = max_levels)

    results <- vector('list', length(models))
    for (i in seq_along(models)) {
        m <- models[i]
        message(sprintf('[%d/%d] %s ...', i, length(models), m))
        res <- ask_llm(
            question     = question,
            summary_text = summary_text,
            base_url     = spec$base_url,
            model        = m,
            api_key      = api_key,
            max_tokens   = max_tokens)
        results[[i]] <- res
        message(sprintf('    ok=%s  %.1fs  %d chars',
            res$ok, res$elapsed_s %||% NA_real_,
            if (is.null(res$text)) 0L else nchar(res$text)))
        if (i < length(models) && sleep_s > 0)
            Sys.sleep(sleep_s)
    }

    # ---- 報告 ----------------------------------------------------------
    stamp <- format(Sys.time(), '%Y%m%d-%H%M%S')
    if (is.null(out)) {
        dir.create('dev-notes', showWarnings = FALSE)
        out <- file.path('dev-notes', paste0('model-comparison-', stamp, '.md'))
    }

    lines <- c(
        paste0('# 模型比較報告 / Model comparison — ', stamp),
        '',
        paste0('- provider: `', provider, '`  (', spec$base_url, ')'),
        paste0('- 資料 / data: ', nrow(data), ' 列 × ', length(vars), ' 變項 (',
               paste(vars, collapse = ', '), ')'),
        paste0('- 問題 / question: ', question),
        paste0('- max_tokens: ', max_tokens),
        '',
        '## 摘要 / Summary',
        '',
        '| 模型 / model | 成功 | 耗時 (s) | 回覆字數 |',
        '|---|---|---|---|')

    for (i in seq_along(models)) {
        r <- results[[i]]
        lines <- c(lines, sprintf('| `%s` | %s | %.1f | %d |',
            models[i],
            if (isTRUE(r$ok)) 'yes' else 'NO',
            r$elapsed_s %||% NA_real_,
            if (is.null(r$text)) 0L else nchar(r$text)))
    }

    lines <- c(lines, '',
        '> 字數只是完整性的粗略指標;請實際閱讀下方回覆評估準確性。',
        '> Length is only a rough proxy for completeness — read the answers below.',
        '',
        '## 送出的資料摘要 / Data summary sent',
        '', '```', strsplit(summary_text, '\n')[[1]], '```', '',
        '## 各模型回覆 / Responses', '')

    for (i in seq_along(models)) {
        r <- results[[i]]
        lines <- c(lines, paste0('### ', models[i]), '')
        if (isTRUE(r$ok)) {
            lines <- c(lines,
                sprintf('_%.1fs · %d 字_', r$elapsed_s, nchar(r$text)), '',
                strsplit(r$text, '\n')[[1]], '')
        } else {
            lines <- c(lines, '**失敗 / failed**', '', '```',
                strsplit(r$error %||% 'unknown error', '\n')[[1]], '```', '')
        }
    }

    writeLines(lines, out, useBytes = TRUE)
    message('報告已寫入 / report written: ', out)
    invisible(list(results = results, report = out))
}

`%||%` <- function(a, b) if (is.null(a)) b else a
