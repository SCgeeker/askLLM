# action-exec.R — Phase 1 執行已驗證的 jmv 分析(對注入的 jmv_get 為純函式)
#
# exec_analysis():對 validate_plan() 清洗後的 run_analysis 動作,實際呼叫
# jmv 分析函式並取其文字結果。設計原則:永不 stop()(失敗以 ok=FALSE 表達)、
# 提供 jmv_get 注入點供離線測試(比照 make_chat 的 ctor)。

# libPaths 墊片:確保 jmv 可載入。開發機 jmv 已在系統 lib → requireNamespace
# 直接成功;jamovi engine 內(預設 lib path 僅 base)才需從已解析為絕對路徑的
# base/R 反推 modules root、追加 <modules>/jmv/R(見 dev-notes v1.2 附錄 A)。
.ensure_jmv_libpath <- function() {
    if (requireNamespace('jmv', quietly = TRUE)) return(TRUE)
    base_lib <- grep('[/\\\\]modules[/\\\\]base[/\\\\]R[/\\\\]?$',
                     .libPaths(), value = TRUE)
    if (length(base_lib) >= 1L) {
        root <- dirname(dirname(base_lib[1]))
        jmv_lib <- file.path(root, 'jmv', 'R')
        if (dir.exists(jmv_lib)) .libPaths(c(.libPaths(), jmv_lib))
    }
    requireNamespace('jmv', quietly = TRUE)
}

# jmv 結果物件 → 純文字。jmvcore ResultsElement$asString() 遞迴組整個結果;
# 後備以 capture.output(print())。
.results_to_string <- function(res) {
    s <- tryCatch({
        f <- res$asString
        if (is.function(f)) f() else NULL
    }, error = function(e) NULL)
    if (!is.null(s) && length(s) && nzchar(paste(s, collapse = '')))
        return(paste(s, collapse = '\n'))
    tryCatch(paste(utils::capture.output(print(res)), collapse = '\n'),
             error = function(e) '')
}

#' 執行單一已驗證的 run_analysis 動作
#'
#' @param action `validate_plan()` 清洗後的 action(type/analysis/args/rationale)。
#' @param data 資料框(`self$data`)。
#' @param jmv_get 測試注入:`fn(analysis)` 回 jmv 分析函式;`NULL` 時套 libPaths
#'   墊片後從 jmv namespace 取。
#' @return `list(ok, analysis, output, error)`。永不 `stop()`。
exec_analysis <- function(action, data, jmv_get = NULL) {
    analysis <- action$analysis %||% ''
    args <- action$args %||% list()

    fn <- tryCatch({
        if (!is.null(jmv_get)) jmv_get(analysis)
        else {
            if (!.ensure_jmv_libpath()) stop('jmv 套件無法載入')
            getExportedValue('jmv', analysis)
        }
    }, error = function(e) e)
    if (inherits(fn, 'condition') || !is.function(fn))
        return(list(ok = FALSE, analysis = analysis, output = NULL,
                    error = paste0('無法載入 jmv 分析 ', analysis, ':',
                        if (inherits(fn, 'condition')) conditionMessage(fn)
                        else '取得的不是函式')))

    res <- tryCatch(do.call(fn, c(list(data = data), args)),
                    error = function(e) e)
    if (inherits(res, 'condition'))
        return(list(ok = FALSE, analysis = analysis, output = NULL,
                    error = paste0('執行 ', analysis, ' 失敗:',
                                   conditionMessage(res))))

    list(ok = TRUE, analysis = analysis,
         output = .results_to_string(res), error = NULL)
}

#' 把驗證後動作 + 執行結果組成報表三段文字(純函式)
#'
#' @param validated `validate_plan()` 輸出 `list(actions, rejected, notes)`。
#' @param exec_results 與 `validated$actions` 同順序的 `exec_analysis()` 輸出清單。
#' @return `list(jmv_text, note_text, plan_text)`:
#'   `jmv_text` 成功分析的表格輸出;`note_text` 逐動作做了什麼/理由/失敗原因
#'   + 剝除說明;`plan_text` 被拒動作稽核。
.askllm_render_actions <- function(validated, exec_results) {
    actions  <- validated$actions  %||% list()
    rejected <- validated$rejected %||% list()
    notes    <- validated$notes    %||% character(0)

    ok_parts <- character(0)
    note_lines <- character(0)
    for (i in seq_along(actions)) {
        a <- actions[[i]]
        r <- if (i <= length(exec_results)) exec_results[[i]]
             else list(ok = FALSE, error = '(無執行結果)')
        rat <- if (nzchar(a$rationale %||% '')) paste0(' — ', a$rationale) else ''
        if (identical(a$type, 'compute_column')) {
            # 計算欄:值寫回試算表,報表只在 note 記錄「建了什麼欄」,不進表格區
            label <- paste0('計算欄 ', a$column_name %||% '')
            if (isTRUE(r$ok))
                note_lines <- c(note_lines, paste0('✓ 建立', label,
                    ' (', a$measure_type %||% 'continuous', ')', rat))
            else
                note_lines <- c(note_lines,
                    paste0('✗ ', label, rat, ' (', r$error %||% '', ')'))
        } else if (isTRUE(r$ok)) {
            ok_parts <- c(ok_parts, paste0('### ', a$analysis, '\n', r$output %||% ''))
            note_lines <- c(note_lines, paste0('✓ ', a$analysis, rat))
        } else {
            note_lines <- c(note_lines,
                paste0('✗ ', a$analysis, rat, ' (', r$error %||% '', ')'))
        }
    }
    note_lines <- c(note_lines, notes)

    rej_lines <- vapply(rejected, function(x) {
        nm <- x$action$analysis %||% x$action$type %||% '?'
        paste0('✗ ', nm, ': ', x$reason %||% '')
    }, character(1))

    list(
        jmv_text  = paste(ok_parts, collapse = '\n\n'),
        note_text = paste(note_lines, collapse = '\n'),
        plan_text = if (length(rej_lines) == 0L) ''
                    else paste0('Rejected actions:\n',
                                paste(rej_lines, collapse = '\n')))
}

#' 依 type 分派執行單一已驗證動作
#'
#' run_analysis → [exec_analysis()];compute_column → [eval_formula()]。
#' 回傳統一含 `$ok`/`$type`/`$error` 的結構(compute_column 另帶 value/column_name
#' /measure_type 供 .runInner 寫回 Output 欄;run_analysis 帶 analysis/output)。
#' @return list;永不 stop()。
exec_action <- function(action, data, jmv_get = NULL) {
    if (identical(action$type, 'compute_column')) {
        ev <- eval_formula(action$formula %||% '', data)
        return(list(ok = ev$ok, type = 'compute_column',
                    column_name  = action$column_name %||% '',
                    measure_type = action$measure_type %||% 'continuous',
                    value = ev$value, error = ev$error,
                    rationale = action$rationale %||% ''))
    }
    r <- exec_analysis(action, data, jmv_get = jmv_get)
    c(list(type = 'run_analysis', rationale = action$rationale %||% ''), r)
}
