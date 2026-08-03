# action-formula.R — Phase 2 R 公式 AST 白名單驗證 + 受限環境求值(安全核心)
#
# Phase 2 的 compute variable 是「值快照」:LLM 產生 R 運算式,我方以 AST 白名單
# 驗證後,在 emptyenv 為 parent 的受限環境求值,結果 setValues 回 Output 欄。
# 這不是 jamovi 活公式(engine 碰不到,見 dev-notes v1.2 §2)。
#
# 鐵則:絕不 eval(parse()) 任意碼;只放行白名單函式 + 現有欄名 + 字面常數。
# 共同契約:純函式、永不 stop()、回結構化 list。

# 公式可用的 R 函式/運算子白名單(運算子在 AST 中亦為 call)。
.FORMULA_FN_WHITELIST <- c(
    '+', '-', '*', '/', '^', '(',
    '==', '!=', '<', '>', '<=', '>=', '&', '|', '!',
    'ifelse', 'log', 'log2', 'log10', 'exp', 'sqrt', 'abs',
    'round', 'floor', 'ceiling', 'scale',
    'mean', 'sd', 'median', 'min', 'max', 'sum', 'is.na',
    'as.numeric', 'as.integer', 'as.factor', 'as.character', 'paste0')

# 遞迴走訪 AST;回 NULL=通過,否則回拒絕原因字串。
.formula_walk <- function(node, colnames) {
    # 字面常數:單一 atomic(numeric/integer/logical/character/complex)
    if (is.numeric(node) || is.logical(node) ||
        is.character(node) || is.complex(node)) {
        if (length(node) == 1L) return(NULL)
        return('不允許向量常數')
    }
    # 變數:symbol 必須是現有欄名
    if (is.symbol(node)) {
        nm <- as.character(node)
        if (nm %in% colnames) return(NULL)
        return(paste0('未知變數或不允許的符號:', nm))
    }
    # 呼叫:函式名必須是白名單內的具名符號;引數遞迴
    if (is.call(node)) {
        fn <- node[[1]]
        if (!is.symbol(fn))
            return('不允許的呼叫形式(函式非具名符號)')
        fname <- as.character(fn)
        if (!(fname %in% .FORMULA_FN_WHITELIST))
            return(paste0('未白名單的函式/運算子:', fname))
        if (length(node) > 1L)
            for (i in 2:length(node)) {
                sub <- .formula_walk(node[[i]], colnames)
                if (!is.null(sub)) return(sub)
            }
        return(NULL)
    }
    # 其他(pairlist、function 定義、公式 ~、{ 區塊等)一律拒
    paste0('不允許的語法節點:', class(node)[1])
}

#' 驗證 R 公式(值快照用):AST 白名單,絕不 eval
#'
#' @param formula LLM 產生的 R 運算式字串。
#' @param colnames 現有資料集欄名向量(公式只能引用這些)。
#' @return `list(ok, reason)`。
validate_formula <- function(formula, colnames) {
    f <- trimws(formula %||% '')
    if (!nzchar(f)) return(list(ok = FALSE, reason = '公式為空'))
    expr <- tryCatch(str2lang(f), error = function(e) e)
    if (inherits(expr, 'condition'))
        return(list(ok = FALSE,
                    reason = paste0('公式無法解析:', conditionMessage(expr))))
    reason <- .formula_walk(expr, colnames)
    if (is.null(reason)) list(ok = TRUE, reason = NULL)
    else list(ok = FALSE, reason = reason)
}

#' 在受限環境求值 R 公式(值快照);絕不 eval 任意碼
#'
#' 先過 [validate_formula()](雙保險),再在 `parent = emptyenv()` 的環境求值——
#' 環境只放白名單函式(原 base 物件)與資料欄,故公式頂層符號解析不到任何呼叫端
#' 或 base 的危險物件。白名單函式各自的 closure env 仍是 base,其內部依賴不受影響。
#'
#' @param formula LLM 產生的 R 運算式字串。
#' @param data 資料框。
#' @return `list(ok, value, error)`;`value` 長度== `nrow(data)`、型別為
#'   numeric/logical/factor/character。
eval_formula <- function(formula, data) {
    v <- validate_formula(formula, names(data))
    if (!isTRUE(v$ok)) return(list(ok = FALSE, value = NULL, error = v$reason))

    env <- new.env(parent = emptyenv())
    for (fn in .FORMULA_FN_WHITELIST) {
        obj <- tryCatch(get(fn, envir = baseenv()), error = function(e) NULL)
        if (!is.null(obj)) assign(fn, obj, envir = env)
    }
    for (nm in names(data)) assign(nm, data[[nm]], envir = env)

    val <- tryCatch(eval(str2lang(formula), envir = env),
                    error = function(e) e)
    if (inherits(val, 'condition'))
        return(list(ok = FALSE, value = NULL,
                    error = paste0('公式求值失敗:', conditionMessage(val))))
    if (length(val) != nrow(data))
        return(list(ok = FALSE, value = NULL,
                    error = paste0('公式結果長度(', length(val),
                                   ')與列數(', nrow(data), ')不符')))
    if (!(is.numeric(val) || is.logical(val) || is.factor(val) ||
          is.character(val)))
        return(list(ok = FALSE, value = NULL,
                    error = paste0('公式結果型別不支援:', class(val)[1])))
    list(ok = TRUE, value = val, error = NULL)
}
