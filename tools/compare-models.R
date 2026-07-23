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
#   # catalog 模式(v1.1):附上本機真實掃描的模組選單樹 / with the real
#   # locally-scanned module menu tree attached to the prompt:
#   compare_models(
#       models      = c('openai/gpt-4o-mini'),
#       provider    = 'github',
#       with_catalog = TRUE)
#
# 需求 / Requirements:
#   - askLLM 已安裝(或以 pkgload::load_all() 載入原始碼)
#   - 對應 provider 的金鑰已設定(見 docs/SETUP-*.md)
#
# 注意 / Notes:
#   - 免費方案有每分鐘與每日請求上限;models 給太多會撞到限制,
#     腳本預設每次呼叫間隔 sleep_s 秒。
#   - 報告寫到 dev-notes/model-comparison-<時間戳>.md(可用 out 參數改)。
#   - with_catalog = TRUE 時,以套件內部函式 scan_modules()/catalog_text()/
#     available_text() 組出真實選單樹文字,連同 known-modules.yaml 的
#     available 清單一併送給模型(對照 v1.1 規格 §5.3 情形 B/C)。
#   - scan_dirs 可覆寫 scan_modules() 掃描的模組根目錄(預設 NULL,交給
#     default_module_dirs() 自動偵測)。在 jamovi engine 之外執行本腳本
#     (如純 Rscript)時,自我定位/`.libPaths()` 訊號偵測不到 jmv 等隨
#     jamovi 主程式安裝的內建模組,只給到 %APPDATA%\jamovi\modules 底下的
#     使用者自裝模組;若要讓「合法路徑」涵蓋 jmv 本身,需手動傳入 jamovi
#     安裝目錄下的 modules 路徑,例如:
#       scan_dirs = c(file.path(Sys.getenv('APPDATA'), 'jamovi', 'modules'),
#                     'C:/Program Files/jamovi <版本>/Resources/modules')
#   - 不論 with_catalog 為何,只要能取得本機掃描結果,都會用它檢核回覆中
#     `Analyses > ...` 路徑是否命中真實選單(check_paths,預設開),
#     藉此比較 v1.0(無 catalog)與 v1.1(有 catalog)prompt 下模型是否
#     編造選單路徑。

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
                           out = NULL,
                           with_catalog = FALSE,
                           known_path = NULL,
                           check_paths = TRUE,
                           scan_dirs = NULL) {

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

    # ---- catalog 模式(v1.1):真實選單樹 + available 清單 ------------------
    catalog_text_value   <- NULL
    available_text_value <- NULL
    system_prompt_value  <- NULL

    # 不論 with_catalog 與否,只要 check_paths 開啟就掃一次本機,取得
    # 「合法選單路徑集合」作為 v1.0/v1.1 回覆的共同檢核基準。
    scanned <- NULL
    if (isTRUE(with_catalog) || isTRUE(check_paths)) {
        scan_modules_fn <- tryCatch(fn('scan_modules'), error = function(e) NULL)
        if (!is.null(scan_modules_fn))
            scanned <- tryCatch(scan_modules_fn(dirs = scan_dirs), error = function(e) NULL)
    }

    if (isTRUE(with_catalog)) {
        catalog_text_fn   <- fn('catalog_text')
        available_text_fn <- fn('available_text')
        system_prompt_fn  <- fn('.askllm_system_prompt')

        catalog_text_value <- tryCatch(catalog_text_fn(scanned), error = function(e) NULL)

        if (!is.null(catalog_text_value)) {
            available_text_value <- tryCatch({
                kp <- known_path %||% system.file(
                    'catalog', 'known-modules.yaml', package = 'askLLM')
                if (!nzchar(kp)) return(NULL)
                known <- yaml::read_yaml(kp)
                installed_names <- vapply(
                    scanned$modules %||% list(), function(m) m$name %||% '',
                    character(1))
                available_text_fn(known, installed_names)
            }, error = function(e) NULL)
        }

        system_prompt_value <- system_prompt_fn(
            has_catalog = !is.null(catalog_text_value))

        message(sprintf(
            'catalog: %d modules scanned, catalog_text=%s, available_text=%s',
            length(scanned$modules %||% list()),
            if (is.null(catalog_text_value)) 'NULL' else paste0(nchar(catalog_text_value), ' chars'),
            if (is.null(available_text_value)) 'NULL' else paste0(nchar(available_text_value), ' chars')))
    }

    legal_paths <- .askllm_legal_paths(scanned)
    if (isTRUE(check_paths) && length(legal_paths) == 0)
        message('check_paths: 本機掃描不到任何模組,略過路徑命中檢核')

    results  <- vector('list', length(models))
    hit_info <- vector('list', length(models))
    for (i in seq_along(models)) {
        m <- models[i]
        message(sprintf('[%d/%d] %s ...', i, length(models), m))
        res <- ask_llm(
            question       = question,
            summary_text   = summary_text,
            catalog_text   = catalog_text_value,
            available_text = available_text_value,
            base_url       = spec$base_url,
            model          = m,
            api_key        = api_key,
            system_prompt  = system_prompt_value,
            max_tokens     = max_tokens)
        results[[i]] <- res
        message(sprintf('    ok=%s  %.1fs  %d chars',
            res$ok, res$elapsed_s %||% NA_real_,
            if (is.null(res$text)) 0L else nchar(res$text)))

        if (isTRUE(res$ok) && length(legal_paths) > 0) {
            hit_info[[i]] <- .askllm_check_path_hits(res$text, legal_paths)
            message(sprintf('    paths: total=%d hits=%d misses=%d',
                hit_info[[i]]$total, hit_info[[i]]$hits,
                length(hit_info[[i]]$misses)))
        } else {
            hit_info[[i]] <- list(total = 0L, hits = 0L, misses = character(0))
        }

        if (i < length(models) && sleep_s > 0)
            Sys.sleep(sleep_s)
    }

    # ---- 報告 ----------------------------------------------------------
    stamp <- format(Sys.time(), '%Y%m%d-%H%M%S')
    if (is.null(out)) {
        dir.create('dev-notes', showWarnings = FALSE)
        out <- file.path('dev-notes', paste0('model-comparison-', stamp, '.md'))
    }

    has_hit_check <- length(legal_paths) > 0

    lines <- c(
        paste0('# 模型比較報告 / Model comparison — ', stamp),
        '',
        paste0('- provider: `', provider, '`  (', spec$base_url, ')'),
        paste0('- 資料 / data: ', nrow(data), ' 列 × ', length(vars), ' 變項 (',
               paste(vars, collapse = ', '), ')'),
        paste0('- 問題 / question: ', question),
        paste0('- max_tokens: ', max_tokens),
        paste0('- with_catalog: ', with_catalog,
               if (isTRUE(with_catalog))
                   sprintf(' (catalog_text=%s, available_text=%s)',
                       !is.null(catalog_text_value), !is.null(available_text_value))
               else ''),
        if (has_hit_check)
            paste0('- 合法選單路徑數(本機實掃)/ legal paths from local scan: ',
                   length(legal_paths))
        else
            '- 路徑命中檢核 / path hit-check: 略過(本機掃不到模組)',
        '',
        '## 摘要 / Summary',
        '')

    if (has_hit_check) {
        lines <- c(lines,
            '| 模型 / model | 成功 | 耗時 (s) | 回覆字數 | 提取路徑數 | 命中數 | 命中率 |',
            '|---|---|---|---|---|---|---|')
    } else {
        lines <- c(lines,
            '| 模型 / model | 成功 | 耗時 (s) | 回覆字數 |',
            '|---|---|---|---|')
    }

    for (i in seq_along(models)) {
        r <- results[[i]]
        h <- hit_info[[i]]
        if (has_hit_check) {
            rate <- if (h$total > 0) sprintf('%.0f%%', 100 * h$hits / h$total) else 'n/a'
            lines <- c(lines, sprintf('| `%s` | %s | %.1f | %d | %d | %d | %s |',
                models[i],
                if (isTRUE(r$ok)) 'yes' else 'NO',
                r$elapsed_s %||% NA_real_,
                if (is.null(r$text)) 0L else nchar(r$text),
                h$total, h$hits, rate))
        } else {
            lines <- c(lines, sprintf('| `%s` | %s | %.1f | %d |',
                models[i],
                if (isTRUE(r$ok)) 'yes' else 'NO',
                r$elapsed_s %||% NA_real_,
                if (is.null(r$text)) 0L else nchar(r$text)))
        }
    }

    lines <- c(lines, '',
        '> 字數只是完整性的粗略指標;請實際閱讀下方回覆評估準確性。',
        '> Length is only a rough proxy for completeness — read the answers below.',
        '',
        '## 送出的資料摘要 / Data summary sent',
        '', '```', strsplit(summary_text, '\n')[[1]], '```', '')

    if (isTRUE(with_catalog) && !is.null(catalog_text_value)) {
        lines <- c(lines,
            '## 送出的 catalog 文字 / Catalog text sent',
            '', '```', strsplit(catalog_text_value, '\n')[[1]], '```', '')
        if (!is.null(available_text_value)) {
            lines <- c(lines,
                '## 送出的 available 文字 / Available text sent',
                '', '```', strsplit(available_text_value, '\n')[[1]], '```', '')
        }
    }

    lines <- c(lines, '## 各模型回覆 / Responses', '')

    for (i in seq_along(models)) {
        r <- results[[i]]
        h <- hit_info[[i]]
        lines <- c(lines, paste0('### ', models[i]), '')
        if (isTRUE(r$ok)) {
            lines <- c(lines,
                sprintf('_%.1fs · %d 字_', r$elapsed_s, nchar(r$text)), '')
            if (has_hit_check) {
                lines <- c(lines, sprintf(
                    '_路徑:提取 %d、命中 %d%s_', h$total, h$hits,
                    if (length(h$misses) > 0)
                        paste0('、未命中:', paste(h$misses, collapse = '; '))
                    else ''), '')
            }
            lines <- c(lines, strsplit(r$text, '\n')[[1]], '')
        } else {
            lines <- c(lines, '**失敗 / failed**', '', '```',
                strsplit(r$error %||% 'unknown error', '\n')[[1]], '```', '')
        }
    }

    writeLines(lines, out, useBytes = TRUE)
    message('報告已寫入 / report written: ', out)
    invisible(list(results = results, hit_info = hit_info, report = out,
                   legal_paths = legal_paths))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---- 路徑命中檢核 helper -----------------------------------------------------
#
# 這兩個函式只服務本工具腳本(非套件內部函式的替身):從掃描結果建立「合法
# 選單路徑集合」,並從 LLM 回覆文字抽取 `Analyses > ...` 路徑後與之比對。

# 以 scan_modules() 的結果重建合法選單路徑字串(格式比照
# R/module-catalog.R 的 .catalog_analysis_line():'Analyses > menuGroup
# [> menuSubgroup] > menuTitle',不含 menuSubtitle 後綴)。
.askllm_legal_paths <- function(scanned) {
    modules <- scanned$modules %||% list()
    if (length(modules) == 0) return(character(0))

    paths <- character(0)
    for (m in modules) {
        for (a in m$analyses %||% list()) {
            parts <- c('Analyses', a$menuGroup)
            if (!is.null(a$menuSubgroup) && nzchar(a$menuSubgroup))
                parts <- c(parts, a$menuSubgroup)
            parts <- c(parts, a$menuTitle)
            paths <- c(paths, paste(parts, collapse = ' > '))
        }
    }
    unique(paths)
}

# 從 LLM 回覆文字逐行抽取 `Analyses > ...` 開頭的片段。先在常見的「路徑後
# 接描述文字」邊界(粗體/code 結束符、行內 ' - '/' — ' 分隔、冒號)截斷,
# 再去除尾端標點/粗體符號並壓縮空白後回傳(去重)。
.askllm_extract_paths <- function(text) {
    if (is.null(text) || !nzchar(text)) return(character(0))
    lines <- strsplit(text, '\n')[[1]]
    m <- regmatches(lines, regexpr('Analyses\\s*>\\s*[^\n]+', lines))
    m <- m[nzchar(m)]
    if (length(m) == 0) return(character(0))

    cleaned <- vapply(m, function(x) {
        # 路徑常被包在 **粗體** 或 `code` 裡,或後面接 ' - 描述'/': 描述'——
        # 在最早出現的邊界處截斷,只留路徑本身。
        cut_at <- regexpr('\\*\\*|`| [-–—] |: ', x)
        if (cut_at > 1) x <- substr(x, 1, cut_at - 1)
        x <- sub('[*_`[:space:]]+$', '', x)          # 尾端粗體/斜體/code 符號
        x <- sub('[.,;:)，。]+$', '', x)     # 尾端標點(含全形逗號句點)
        x <- gsub('[[:space:]]+', ' ', x)             # 壓縮空白
        trimws(x)
    }, character(1), USE.NAMES = FALSE)
    unique(cleaned[nzchar(cleaned)])
}

# 比對「LLM 回覆抽取到的路徑」與「本機實掃的合法路徑集合」。
#
# @param text LLM 回覆全文
# @param legal_paths .askllm_legal_paths() 的輸出
# @return list(total = 提取路徑數, hits = 命中數, misses = 未命中路徑字元向量)
.askllm_check_path_hits <- function(text, legal_paths) {
    extracted <- .askllm_extract_paths(text)
    legal_norm <- trimws(gsub('\\s+', ' ', legal_paths))
    ok <- extracted %in% legal_norm
    list(total = length(extracted),
         hits  = sum(ok),
         misses = extracted[!ok])
}
