# action-validate.R — Phase 1 動作白名單驗證(純函式,安全核心)
#
# validate_plan():對 parse_plan() 的輸出逐 action 驗證。兩種處置分明:
#   - 參數名不在白名單               → 剝除該參數 + note(action 仍執行)
#   - 值致命錯(欄名不存在/型別錯/enum 非法) → 拒絕整個 action + reason
# 絕不 eval、絕不把 LLM 字串拼進 parse/呼叫;白名單是唯一放行依據。
#
# 共同契約:純函式、永不 stop()、回結構化 list、可離線測試。

# 白名單:分析名 → (參數名 → 值型別)。型別代碼:
#   'colnames' 至少一欄名;'colnames?' 可空;'colname' 單一欄名;
#   'flag' 單一 logical;'number' 單一數值;'pairs' ttestPS 配對;
#   長度>1 的 character 向量 = enum(允許值集合)。
.JMV_WHITELIST <- list(
    descriptives = list(vars = 'colnames', splitBy = 'colnames?', freq = 'flag'),
    ttestIS      = list(vars = 'colnames', group = 'colname',
                        welchs = 'flag', mann = 'flag'),
    ttestPS      = list(pairs = 'pairs'),
    ttestOneS    = list(vars = 'colnames', testValue = 'number'),
    anovaOneW    = list(deps = 'colnames', group = 'colname', welchs = 'flag',
                        phMethod = c('none', 'gamesHowell', 'tukey')),
    corrMatrix   = list(vars = 'colnames', pearson = 'flag',
                        spearman = 'flag', kendall = 'flag'),
    contTables   = list(rows = 'colname', cols = 'colname',
                        chiSq = 'flag', fisher = 'flag'))

# 驗證單一參數值 → list(ok, value, reason)。value 為清洗後可安全傳給 jmv 的值。
.validate_arg <- function(value, type, colnames) {
    bad <- function(msg) list(ok = FALSE, value = NULL, reason = msg)

    # enum:type 為長度>1 的 character 向量
    if (is.character(type) && length(type) > 1L) {
        v <- if (is.list(value)) unlist(value) else value
        if (!is.character(v) || length(v) != 1L || !(v %in% type))
            return(bad(paste0('列舉值非法(允許:', paste(type, collapse = '/'), ')')))
        return(list(ok = TRUE, value = v, reason = NULL))
    }
    if (identical(type, 'flag')) {
        if (!is.logical(value) || length(value) != 1L || is.na(value))
            return(bad('flag 需單一 TRUE/FALSE'))
        return(list(ok = TRUE, value = value, reason = NULL))
    }
    if (identical(type, 'number')) {
        if (!is.numeric(value) || length(value) != 1L)
            return(bad('需單一數值'))
        return(list(ok = TRUE, value = value, reason = NULL))
    }
    if (identical(type, 'colname')) {
        v <- if (is.list(value)) unlist(value) else value
        if (!is.character(v) || length(v) != 1L) return(bad('需單一欄名'))
        if (!(v %in% colnames)) return(bad(paste0('欄名不存在:', v)))
        return(list(ok = TRUE, value = v, reason = NULL))
    }
    if (identical(type, 'colnames') || identical(type, 'colnames?')) {
        v <- if (is.list(value)) unlist(value) else value
        if (is.null(v) || length(v) == 0L) {
            if (identical(type, 'colnames?'))
                return(list(ok = TRUE, value = list(), reason = NULL))
            return(bad('需至少一個欄名'))
        }
        if (!is.character(v)) return(bad('欄名需字元'))
        miss <- setdiff(v, colnames)
        if (length(miss) > 0L)
            return(bad(paste0('欄名不存在:', paste(miss, collapse = ', '))))
        # 回字元向量(jmv 分析選項要的型別),非 list
        return(list(ok = TRUE, value = unname(v), reason = NULL))
    }
    if (identical(type, 'pairs')) {
        if (!is.list(value) || length(value) == 0L) return(bad('pairs 需非空清單'))
        for (p in value) {
            i1 <- p$i1 %||% (if (is.list(p) && length(p) >= 1L) p[[1]] else NULL)
            i2 <- p$i2 %||% (if (is.list(p) && length(p) >= 2L) p[[2]] else NULL)
            if (is.null(i1) || is.null(i2) ||
                !(i1 %in% colnames) || !(i2 %in% colnames))
                return(bad('pairs 內欄名不存在或格式錯誤'))
        }
        return(list(ok = TRUE, value = value, reason = NULL))
    }
    bad(paste0('未知參數型別:', as.character(type)))
}

.MEASURE_TYPES <- c('continuous', 'ordinal', 'nominal')

# 驗證 compute_column 動作(Phase 2:值快照計算欄)→ list(ok, action, reason, notes)
.validate_compute_column <- function(a, colnames) {
    name <- .yaml_chr(a$column_name) %||% ''
    if (!nzchar(name))
        return(list(ok = FALSE, reason = 'compute_column:欄名為空'))
    if (!grepl('^[A-Za-z.][A-Za-z0-9_.]*$', name))
        return(list(ok = FALSE,
                    reason = paste0('compute_column:欄名非法識別字:', name)))
    mt <- .yaml_chr(a$measure_type) %||% ''
    if (!nzchar(mt)) mt <- 'continuous'          # 空 → 預設 continuous
    if (!(mt %in% .MEASURE_TYPES))
        return(list(ok = FALSE,
                    reason = paste0('compute_column:measureType 非法:', mt)))
    fml <- .yaml_chr(a$formula) %||% ''
    fv <- validate_formula(fml, colnames)         # AST 白名單,絕不 eval
    if (!isTRUE(fv$ok))
        return(list(ok = FALSE, reason = paste0('compute_column 公式:', fv$reason)))
    list(ok = TRUE,
         action = list(type = 'compute_column', column_name = name,
                       measure_type = mt, formula = fml,
                       rationale = a$rationale %||% ''),
         notes = character(0))
}

# 驗證單一 action → list(ok, action, reason, notes)
.validate_action <- function(a, colnames) {
    if (identical(a$type, 'compute_column'))
        return(.validate_compute_column(a, colnames))
    if (!identical(a$type, 'run_analysis'))
        return(list(ok = FALSE,
                    reason = paste0('僅支援 run_analysis / compute_column(收到:',
                                    a$type %||% '', ')')))
    spec <- .JMV_WHITELIST[[a$analysis %||% '']]
    if (is.null(spec))
        return(list(ok = FALSE,
                    reason = paste0('分析不在白名單:', a$analysis %||% '')))

    clean <- list(); notes <- character(0)
    args <- a$args %||% list()
    for (nm in names(args)) {
        if (!nm %in% names(spec)) {
            notes <- c(notes, paste0(a$analysis, ':剝除未知參數 ', nm))
            next
        }
        chk <- .validate_arg(args[[nm]], spec[[nm]], colnames)
        if (!isTRUE(chk$ok))
            return(list(ok = FALSE,
                        reason = paste0(a$analysis, '.', nm, ':', chk$reason)))
        clean[[nm]] <- chk$value
    }
    list(ok = TRUE,
         action = list(type = 'run_analysis', analysis = a$analysis,
                       args = clean, rationale = a$rationale %||% ''),
         notes = notes)
}

#' 驗證動作計畫(白名單制)
#'
#' @param plan `parse_plan()` 輸出(或含 `$actions` 的 list;亦容忍直接傳
#'   actions 清單)。
#' @param colnames 資料集欄名向量(`names(self$data)`)。
#' @return `list(actions, rejected, notes)`:`actions` 為清洗後可安全執行者;
#'   `rejected` 每項為 `list(action, reason)`;`notes` 為剝除等說明字串向量。
validate_plan <- function(plan, colnames) {
    actions_in <-
        if (is.list(plan) && !is.null(plan$actions)) plan$actions
        else if (is.list(plan)) plan
        else list()

    clean <- list(); rejected <- list(); notes <- character(0)
    for (a in actions_in) {
        res <- .validate_action(a, colnames)
        if (isTRUE(res$ok)) {
            clean[[length(clean) + 1L]] <- res$action
            notes <- c(notes, res$notes)
        } else {
            rejected[[length(rejected) + 1L]] <- list(action = a, reason = res$reason)
        }
    }
    list(actions = clean, rejected = rejected, notes = notes)
}
