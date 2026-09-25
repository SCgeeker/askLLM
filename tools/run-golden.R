# tools/run-golden.R — 以 golden set 對單一 provider/model 跑一輪評測(v1.4 項目 F)
#
# 用法 / Usage(需對應 provider 的金鑰;不隨套件安裝):
#   pkgload::load_all()            # 或 library(askLLM)
#   source('tools/run-golden.R')
#   run_golden(provider = 'gemini')                       # 預設模型
#   run_golden(provider = 'openrouter', model = 'openai/gpt-oss-20b:free',
#              analysis = 'askllm')                       # 只跑 Module Guider 題
#   run_golden(provider = 'ollama', model = 'llama3.2', with_catalog = FALSE)
#
# 輸出:dev-notes/golden-<provider>-<model>-<時間戳>.md(可用 out= 改)與同名 .json
# (每題分項分數,供 CI artifact 與跨版本比較)。
#
# 評分規則見 R/eval-score.R(.askllm_score_answer);規則是回歸警示,總分只作
# 同題同模型跨版本的趨勢比較。路徑分項只在本機掃得到 jamovi 模組時計分
# (純 Rscript 環境通常只掃到使用者自裝模組,見 tools/compare-models.R 註解)。

run_golden <- function(provider = 'gemini',
                       model = NULL,
                       golden = 'tools/golden/golden-set.yaml',
                       analysis = c('askllm', 'askllmr'),
                       ids = NULL,
                       base_url_option = '',
                       with_catalog = TRUE,
                       checklist = TRUE,   # v1.4 D:與 UI 預設(addChecklist=TRUE)一致
                       scan_dirs = NULL,
                       max_tokens = 4096,
                       sleep_s = 3,
                       out = NULL) {

    fn <- function(name) {
        if (requireNamespace('askLLM', quietly = TRUE) &&
            !is.null(getNamespace('askLLM')[[name]])) {
            return(getNamespace('askLLM')[[name]])
        }
        get(name, envir = globalenv())
    }
    `%||%` <- function(a, b) if (is.null(a)) b else a

    g <- fn('.askllm_load_golden')(golden)
    if (!isTRUE(g$ok))
        stop('golden set invalid:\n  ', paste(g$errors, collapse = '\n  '), call. = FALSE)
    items <- Filter(function(it) it$analysis %in% analysis, g$items)
    if (!is.null(ids)) items <- Filter(function(it) it$id %in% ids, items)
    if (length(items) == 0) stop('no golden items selected', call. = FALSE)

    spec <- fn('provider_spec')(provider, base_url_option)
    if (!is.null(spec$error)) stop(spec$error, call. = FALSE)
    model <- model %||% spec$default_model
    if (!nzchar(model)) stop('this provider has no default model; pass model=', call. = FALSE)

    api_key <- 'ollama'
    if (isTRUE(spec$needs_key)) {
        kv <- fn('load_api_key')(spec$env_vars)
        if (is.null(kv))
            stop('key not found for ', provider, ': set ',
                 paste(spec$env_vars, collapse = ' or '), call. = FALSE)
        api_key <- kv$key
        message('key source: ', kv$source)
    }

    # ---- 接地素材(與 .runInner() 同源:catalog / available / rj)-------------
    scanned <- tryCatch(fn('scan_modules')(dirs = scan_dirs), error = function(e) NULL)
    legal_paths <- fn('.askllm_legal_paths')(scanned)
    catalog_text_value <- NULL; available_text_value <- NULL
    if (isTRUE(with_catalog)) {
        ctx <- tryCatch(fn('.askllm_gather_context')(TRUE), error = function(e) list())
        catalog_text_value <- ctx$catalog_text
        available_text_value <- ctx$available_text
    }
    rj <- tryCatch(fn('scan_rj')(), error = function(e) NULL)
    rj_env_text_value <- if (is.null(rj)) NULL else fn('rj_env_text')(rj)
    message(sprintf('grounding: legal paths=%d, catalog=%s, rj=%s',
        length(legal_paths), !is.null(catalog_text_value), !is.null(rj_env_text_value)))

    summarize_data <- fn('summarize_data')
    ask_llm        <- fn('ask_llm')
    score_fn       <- fn('.askllm_score_answer')
    sys_guider     <- fn('.askllm_system_prompt')
    sys_rtutor     <- fn('.askllmr_system_prompt')
    dataset_fn     <- fn('.askllm_golden_dataset')

    rows <- vector('list', length(items))
    for (i in seq_along(items)) {
        it <- items[[i]]
        role <- it$role %||% 'consultant'
        lang <- it$lang %||% 'en'
        df <- dataset_fn(it$dataset)
        vars <- as.character(unlist(it$vars %||% character(0)))
        summary_text <- summarize_data(df, vars)
        message(sprintf('[%d/%d] %s (%s) ...', i, length(items), it$id, it$analysis))

        if (identical(it$analysis, 'askllmr')) {
            res <- ask_llm(question = it$question, summary_text = summary_text,
                           rj_env_text = rj_env_text_value,
                           base_url = spec$base_url, model = model, api_key = api_key,
                           system_prompt = sys_rtutor(role = role, lang = lang,
                               has_rj_env = !is.null(rj_env_text_value)),
                           max_tokens = max_tokens)
        } else {
            res <- ask_llm(question = it$question, summary_text = summary_text,
                           catalog_text = catalog_text_value,
                           available_text = available_text_value,
                           base_url = spec$base_url, model = model, api_key = api_key,
                           system_prompt = sys_guider(role = role, lang = lang,
                               has_catalog = !is.null(catalog_text_value),
                               checklist = checklist),
                           max_tokens = max_tokens)
        }

        sc <- if (isTRUE(res$ok)) score_fn(res$text, it$expect, legal_paths, it$analysis)
              else list(score = NA_real_, components = c(), warnings = 'call failed',
                        keyword_missing = character(0), forbidden_hits = character(0),
                        path = list(total = 0L, hits = 0L, misses = character(0)))
        message(sprintf('    ok=%s  %.1fs  score=%s  %s',
            res$ok, res$elapsed_s %||% NA_real_,
            if (is.na(sc$score)) 'n/a' else sc$score,
            paste(sc$warnings, collapse = ' | ')))
        rows[[i]] <- list(item = it, res = res, score = sc)
        if (i < length(items) && sleep_s > 0) Sys.sleep(sleep_s)
    }

    # ---- 報告 ------------------------------------------------------------------
    stamp <- format(Sys.time(), '%Y%m%d-%H%M%S')
    safe_model <- gsub('[^A-Za-z0-9._-]+', '_', model)
    if (is.null(out)) {
        dir.create('dev-notes', showWarnings = FALSE)
        out <- file.path('dev-notes', paste0('golden-', provider, '-', safe_model, '-', stamp, '.md'))
    }
    json_out <- sub('\\.md$', '.json', out)

    scores <- vapply(rows, function(r) r$score$score, numeric(1))
    lines <- c(
        paste0('# Golden set report — ', provider, ' / `', model, '` — ', stamp),
        '',
        paste0('- checklist suffix (v1.4 D): ', checklist),
        paste0('- items: ', length(rows), '; mean score (scored items): ',
               if (all(is.na(scores))) 'n/a' else round(mean(scores, na.rm = TRUE), 1)),
        paste0('- legal paths from local scan: ', length(legal_paths),
               if (length(legal_paths) == 0) ' (path component skipped)' else ''),
        paste0('- catalog attached: ', !is.null(catalog_text_value),
               '; rj env attached: ', !is.null(rj_env_text_value)),
        '',
        '| id | analysis | ok | s | score | warnings |',
        '|---|---|---|---|---|---|')
    for (r in rows) {
        lines <- c(lines, sprintf('| %s | %s | %s | %.1f | %s | %s |',
            r$item$id, r$item$analysis, if (isTRUE(r$res$ok)) 'yes' else 'NO',
            r$res$elapsed_s %||% NA_real_,
            if (is.na(r$score$score)) 'n/a' else r$score$score,
            paste(r$score$warnings, collapse = '; ')))
    }
    lines <- c(lines, '', '## Responses', '')
    for (r in rows) {
        lines <- c(lines, paste0('### ', r$item$id), '',
                   paste0('_Q: ', r$item$question, '_'), '')
        if (isTRUE(r$res$ok)) lines <- c(lines, strsplit(r$res$text, '\n')[[1]], '')
        else lines <- c(lines, '**failed**', '', '```', r$res$error %||% 'unknown', '```', '')
    }
    writeLines(lines, out, useBytes = TRUE)

    summary <- lapply(rows, function(r) list(
        id = r$item$id, analysis = r$item$analysis, ok = isTRUE(r$res$ok),
        elapsed_s = r$res$elapsed_s %||% NA_real_, score = r$score$score,
        components = as.list(r$score$components), warnings = r$score$warnings))
    writeLines(jsonlite::toJSON(list(provider = provider, model = model, stamp = stamp,
                                     checklist = checklist,
                                     legal_paths = length(legal_paths), items = summary),
                                auto_unbox = TRUE, pretty = TRUE, na = 'null'),
               json_out, useBytes = TRUE)
    message('report: ', out, '\njson:   ', json_out)
    invisible(list(rows = rows, report = out, json = json_out))
}
