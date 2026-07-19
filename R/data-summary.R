# data-summary.R — 資料摘要器(純函式)
#
# 把使用者勾選的變項轉成一段純文字摘要,供上層嵌入 LLM prompt。
# 只呈現「聚合統計」(不含原始列),兼顧統計正確性與 token 效率。
#
# 對外:
#   summarize_data(df, vars, max_levels = 10, char_budget = 4000) -> character(1)
#   count_chars(x) -> integer  # 以字元數估算 token 成本

#' 以「字元數」計長度
#'
#' budget 是給 LLM token 的粗估。中文欄名/水準名以「字元數」較貼近 token 量
#' (byte 數會把單一中文字算成 3,嚴重高估),故一律用 type = 'chars'。
count_chars <- function(x) {
    nchar(x, type = 'chars')
}

# 單一水準/值名稱截斷:超過 cap 字元則截並附 '…'(NA 轉為字面 'NA')
.trunc_label <- function(s, cap = 40) {
    s <- as.character(s)
    s[is.na(s)] <- 'NA'
    long <- count_chars(s) > cap
    s[long] <- paste0(substr(s[long], 1, cap), '…')
    s
}

# 依次數降冪列出 name(count),超過 max_levels 併為 "... and J more levels"
.format_counts <- function(counts, max_levels, order_by_count = TRUE) {
    if (length(counts) == 0) return('(none)')
    if (order_by_count) {
        # 穩定排序:次數相同者維持原順序(決定性)
        ord <- order(-as.integer(counts), seq_along(counts))
        counts <- counts[ord]
    }
    nm <- .trunc_label(names(counts))
    shown <- seq_len(min(length(counts), max_levels))
    parts <- paste0(nm[shown], '(', as.integer(counts[shown]), ')')
    line <- paste(parts, collapse = ', ')
    extra <- length(counts) - length(shown)
    if (extra > 0)
        line <- paste0(line, ', ... and ', extra, ' more levels')
    line
}

# signif 4 呈現;NA/NaN/Inf 一律呈現為字面 'NA'(不讓 NaN/Inf 外洩到 prompt)
.fmt_num <- function(x) {
    if (length(x) != 1 || is.na(x) || is.nan(x) || is.infinite(x)) return('NA')
    format(signif(x, 4), trim = TRUE, scientific = FALSE)
}

# ---- 各型態的單變項摘要(回傳多行字串,不含前導空行)----------------------

.summ_numeric <- function(name, x, cls) {
    x2 <- x[!is.na(x)]
    n <- length(x2); miss <- sum(is.na(x))
    if (n == 0) {
        m <- s <- md <- mn <- mx <- NA_real_
    } else {
        m  <- mean(x2)
        s  <- if (n < 2) NA_real_ else stats::sd(x2)
        md <- stats::median(x2)
        mn <- min(x2); mx <- max(x2)
    }
    paste0(
        name, ' [', cls, ']:\n',
        '  n: ', n, ', missing: ', miss, '\n',
        '  mean: ', .fmt_num(m), ', sd: ', .fmt_num(s),
        ', median: ', .fmt_num(md),
        ', min: ', .fmt_num(mn), ', max: ', .fmt_num(mx))
}

.summ_factor <- function(name, x, max_levels) {
    ordered <- is.ordered(x)
    cls <- if (ordered) 'ordered factor' else 'factor'
    miss <- sum(is.na(x))
    n <- sum(!is.na(x))
    k <- nlevels(x)
    counts <- table(x)                 # 依宣告水準製表(addNA 的 NA 水準也計入)
    line_counts <- .format_counts(counts, max_levels, order_by_count = TRUE)
    out <- paste0(
        name, ' [', cls, ']:\n',
        '  n: ', n, ', missing: ', miss, ', ', k, ' levels\n',
        '  levels by count: ', line_counts)
    if (ordered) {
        ord_line <- paste(.trunc_label(levels(x)), collapse = ' < ')
        out <- paste0(out, '\n  level order: ', ord_line)
    }
    out
}

.summ_character <- function(name, x, max_levels) {
    miss <- sum(is.na(x))
    x2 <- x[!is.na(x)]
    n <- length(x2)
    counts <- table(x2)
    distinct <- length(counts)
    line_counts <- .format_counts(counts, max_levels, order_by_count = TRUE)
    paste0(
        name, ' [character]:\n',
        '  n: ', n, ', missing: ', miss, ', ', distinct, ' distinct values\n',
        '  top values: ', line_counts)
}

.summ_logical <- function(name, x) {
    nt <- sum(x, na.rm = TRUE)
    nf <- sum(!x, na.rm = TRUE)
    na <- sum(is.na(x))
    paste0(
        name, ' [logical]:\n',
        '  n: ', nt + nf, ', missing: ', na, '\n',
        '  TRUE: ', nt, ', FALSE: ', nf, ', NA: ', na)
}

.summ_other <- function(name, x) {
    cls <- class(x)[1]
    miss <- sum(is.na(x))
    n <- sum(!is.na(x))
    paste0(
        name, ' [', cls, ']:\n',
        '  type: ', cls, '\n',
        '  n: ', n, ', missing: ', miss)
}

.summ_one <- function(name, x, max_levels) {
    if (is.logical(x))                       return(.summ_logical(name, x))
    if (is.factor(x))                        return(.summ_factor(name, x, max_levels))
    if (is.character(x))                     return(.summ_character(name, x, max_levels))
    if (is.integer(x))                       return(.summ_numeric(name, x, 'integer'))
    if (is.numeric(x))                       return(.summ_numeric(name, x, 'numeric'))
    .summ_other(name, x)
}

#' 產生資料摘要純文字
#'
#' @param df data.frame(engine 傳入,欄位可能帶 jmvcore 屬性)
#' @param vars 欲摘要的欄名向量
#' @param max_levels factor/character 最多列出的水準數
#' @param char_budget 總字元預算;超過時逐變項截斷
#' @return character(1) UTF-8 摘要字串
summarize_data <- function(df, vars, max_levels = 10, char_budget = 4000) {
    vars <- as.character(vars)
    if (length(vars) == 0)
        return('No variables selected.')

    present <- vars %in% names(df)
    missing_vars <- vars[!present]
    use_vars <- vars[present]

    n_rows <- nrow(df)
    header <- paste0('Dataset: ', n_rows, ' rows. Variables described: ',
                     length(use_vars), '.')

    blocks <- vapply(use_vars, function(v) {
        .summ_one(v, df[[v]], max_levels)
    }, character(1), USE.NAMES = FALSE)

    skip_note <- if (length(missing_vars) > 0)
        paste0('[skipped missing: ', paste(missing_vars, collapse = ', '), ']')
    else NULL

    pieces <- c(header, blocks, skip_note)
    full <- paste(pieces, collapse = '\n\n')

    if (count_chars(full) <= char_budget)
        return(full)

    # ---- 超 budget:逐變項截斷(決定性)------------------------------------
    final_marker <- '[summary truncated to fit budget]'
    tmark <- ' [truncated]'
    fixed_len <- count_chars(header) + count_chars(final_marker) +
        (if (!is.null(skip_note)) count_chars(skip_note) else 0L) +
        3L * (length(blocks) + 1L)          # 分隔用 '\n\n' 的粗估
    nb <- max(length(blocks), 1L)
    quota <- max(20L, as.integer(floor((char_budget - fixed_len) / nb)))

    blocks_trunc <- vapply(blocks, function(b) {
        if (count_chars(b) <= quota) return(b)
        keep <- max(1L, quota - count_chars(tmark))
        paste0(substr(b, 1, keep), tmark)
    }, character(1), USE.NAMES = FALSE)

    pieces2 <- c(header, blocks_trunc, skip_note)
    body <- paste(pieces2, collapse = '\n\n')
    out <- paste0(body, '\n\n', final_marker)

    # 硬性保證:仍超過 budget*1.1 時直接截字元(附標記)
    cap <- as.integer(floor(char_budget * 1.1))
    if (count_chars(out) > cap) {
        room <- max(1L, cap - count_chars(final_marker) - 2L)
        out <- paste0(substr(out, 1, room), '\n', final_marker)
    }
    out
}
