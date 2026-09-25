# eval-score.R — prompt 品質評測的純函式(v1.4 項目 F)
#
# 目的:把「回覆是否命中真實選單路徑」(v1.1 的 catalog-hit-rate 機制,原本
# 只住在 tools/compare-models.R)升級為可重跑的多維評分,供 golden set
# (tools/golden/*.yaml)與 tools/run-golden.R 使用,也讓 testthat 能離線鎖住
# 評分規則本身。
#
# 共同契約(比照 data-summary.R / module-catalog.R):純函式、決定性、
# 永不 stop()(輸入格式錯誤以回傳值表達)、可離線單元測試。
#
# 評分不是「對錯裁判」而是回歸警示:規則過嚴會把合理回答判錯,故報告以
# 「警示」呈現各分項,總分只作趨勢比較(同題同模型跨版本)。

# ---- 路徑命中(自 tools/compare-models.R 搬入套件) --------------------------

#' 以 scan_modules() 的結果重建合法選單路徑字串
#'
#' 格式比照 `module-catalog.R` 的 `.catalog_analysis_line()`:
#' `Analyses > menuGroup [> menuSubgroup] > menuTitle`(不含 menuSubtitle)。
#' @param scanned `scan_modules()` 的回傳值(或 NULL)
#' @return character 向量(去重),掃不到任何模組時 `character(0)`
#' @keywords internal
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

#' 從 LLM 回覆文字逐行抽取 `Analyses > ...` 開頭的片段
#'
#' 先在常見的「路徑後接描述文字」邊界(粗體/code 結束符、行內 ' - '/' — '
#' 分隔、冒號)截斷,再去除尾端標點/粗體符號並壓縮空白後回傳(去重)。
#' @keywords internal
.askllm_extract_paths <- function(text) {
    if (is.null(text) || !nzchar(text)) return(character(0))
    # 先切成子句再逐句抓路徑:同一行可能列多條路徑(「A. Or B」、「A;B」、
    # 「A 或 B」),故以句界切開——換行、句號後空白/行尾、分號、「 or/Or 」、
    # 中文句讀與「或」。避免整串「Analyses > … . Or Analyses > …」被當成一條。
    lines <- unlist(strsplit(text, '\n'))
    clauses <- unlist(strsplit(lines,
        '\\.\\s+|\\.$|;\\s+|\\s+[Oo]r\\s+|，|。|；|、|或', perl = TRUE))
    clauses <- clauses[nzchar(clauses)]
    m <- regmatches(clauses, regexpr('Analyses\\s*>\\s*[^\n]+', clauses))
    m <- m[nzchar(m)]
    if (length(m) == 0) return(character(0))

    cleaned <- vapply(m, function(x) {
        cut_at <- regexpr('\\*\\*|`| [-–—] |: ', x)
        if (cut_at > 1) x <- substr(x, 1, cut_at - 1)
        x <- sub('[*_`[:space:]]+$', '', x)
        x <- sub('[.,;:)，。]+$', '', x)
        x <- gsub('[[:space:]]+', ' ', x)
        trimws(x)
    }, character(1), USE.NAMES = FALSE)
    unique(cleaned[nzchar(cleaned)])
}

#' 比對「回覆抽取到的路徑」與「本機實掃的合法路徑集合」
#'
#' @return `list(total, hits, misses)`
#' @keywords internal
.askllm_check_path_hits <- function(text, legal_paths) {
    extracted <- .askllm_extract_paths(text)
    legal_norm <- trimws(gsub('\\s+', ' ', legal_paths %||% character(0)))
    ok <- extracted %in% legal_norm
    list(total = length(extracted),
         hits  = sum(ok),
         misses = extracted[!ok])
}

# ---- 關鍵字比對 ----------------------------------------------------------------

#' 單一「關鍵字條目」是否命中回覆(不分大小寫;`|` 分隔的任一替代字即命中)
#'
#' 條目為固定字串(非 regex),以 `|` 表示替代:`'t-test|t test|Mann-Whitney'`。
#' @keywords internal
.askllm_kw_hit <- function(text, entry) {
    alts <- trimws(strsplit(entry %||% '', '|', fixed = TRUE)[[1]])
    alts <- alts[nzchar(alts)]
    if (length(alts) == 0) return(FALSE)
    low <- tolower(text %||% '')
    any(vapply(alts, function(a) grepl(tolower(a), low, fixed = TRUE), logical(1)))
}

# ---- 評分 --------------------------------------------------------------------

#' 對單一回覆依 golden 條目的 `expect` 規則評分
#'
#' 規則欄位(皆選填;缺席的規則不計入總分):
#'   - `must_mention`:字串向量,每條可含 `|` 替代;逐條計命中率。
#'   - `must_not`:字串向量,任一命中即為「禁用字出現」(regression 警示)。
#'   - `redirect_expected`:TRUE 時要求回覆提到 sibling 分析(Module Guider
#'     期待 "R code tutor";R code tutor 期待 "Module Guider"),由
#'     `redirect_target` 指定字串(預設依 `analysis` 推得)。
#'   - `paths_expected`:TRUE 且 `legal_paths` 非空時,要求至少抽到一條路徑,
#'     且命中率計入總分(零抽取 → 該分項 0)。
#'   - `code_expected`:TRUE 時要求回覆含至少一個 fenced code block。
#'
#' @param text LLM 回覆全文(`NULL`/空字串視為空回覆,所有規則不通過)。
#' @param expect golden 條目的 `expect` list。
#' @param legal_paths `.askllm_legal_paths()` 的輸出;`character(0)` 時跳過
#'   路徑分項(工具在 jamovi 外執行時常掃不到模組)。
#' @param analysis `'askllm'` 或 `'askllmr'`,決定 redirect 預設目標。
#' @return `list(score = <0..100 或 NA>, components = <named numeric>,
#'   keyword_hits, keyword_missing, forbidden_hits, path = <check_path_hits>,
#'   redirect_ok = <lgl|NA>, code_ok = <lgl|NA>, warnings = <chr>)`
#' @keywords internal
.askllm_score_answer <- function(text, expect, legal_paths = character(0),
                                 analysis = 'askllm') {
    text <- text %||% ''
    expect <- expect %||% list()
    comps <- c()
    warnings <- character(0)

    # must_mention
    mm <- as.character(unlist(expect$must_mention %||% character(0)))
    kw_hit <- character(0); kw_miss <- character(0)
    if (length(mm) > 0) {
        hit <- vapply(mm, function(e) .askllm_kw_hit(text, e), logical(1))
        kw_hit <- mm[hit]; kw_miss <- mm[!hit]
        comps['keywords'] <- mean(hit)
        if (length(kw_miss) > 0)
            warnings <- c(warnings, paste0('missing: ', paste(kw_miss, collapse = '; ')))
    }

    # must_not
    mn <- as.character(unlist(expect$must_not %||% character(0)))
    forbidden <- character(0)
    if (length(mn) > 0) {
        bad <- vapply(mn, function(e) .askllm_kw_hit(text, e), logical(1))
        forbidden <- mn[bad]
        comps['forbidden_free'] <- as.numeric(!any(bad))
        if (any(bad))
            warnings <- c(warnings, paste0('forbidden: ', paste(forbidden, collapse = '; ')))
    }

    # redirect
    redirect_ok <- NA
    if (isTRUE(expect$redirect_expected)) {
        target <- expect$redirect_target %||%
            if (identical(analysis, 'askllmr')) 'Module Guider' else 'R code tutor'
        redirect_ok <- .askllm_kw_hit(text, target)
        comps['redirect'] <- as.numeric(redirect_ok)
        if (!redirect_ok)
            warnings <- c(warnings, paste0('no redirect to ', target))
    }

    # paths
    path <- .askllm_check_path_hits(text, legal_paths)
    if (isTRUE(expect$paths_expected) && length(legal_paths) > 0) {
        comps['paths'] <- if (path$total == 0) 0 else path$hits / path$total
        if (path$total == 0)
            warnings <- c(warnings, 'no Analyses > ... path found')
        if (length(path$misses) > 0)
            warnings <- c(warnings, paste0('path miss: ', paste(path$misses, collapse = '; ')))
    }

    # code block
    code_ok <- NA
    if (isTRUE(expect$code_expected)) {
        code_ok <- grepl('```', text, fixed = TRUE)
        comps['code'] <- as.numeric(code_ok)
        if (!code_ok) warnings <- c(warnings, 'no fenced code block')
    }

    score <- if (length(comps) == 0) NA_real_ else round(100 * mean(comps), 1)

    list(score = score, components = comps,
         keyword_hits = kw_hit, keyword_missing = kw_miss,
         forbidden_hits = forbidden, path = path,
         redirect_ok = redirect_ok, code_ok = code_ok,
         warnings = warnings)
}

# ---- golden set 載入與驗證 ---------------------------------------------------

#' 允許的 golden 條目欄位與規則欄位(schema 驗證用)
#' @keywords internal
.ASKLLM_GOLDEN_FIELDS <- c('id', 'analysis', 'dataset', 'vars', 'question',
                           'role', 'lang', 'expect', 'note')
.ASKLLM_GOLDEN_EXPECT_FIELDS <- c('must_mention', 'must_not', 'redirect_expected',
                                  'redirect_target', 'paths_expected', 'code_expected')

#' 讀入並驗證 golden set YAML
#'
#' 檢查:頂層 `items` 為 list;每條有唯一 `id`、`analysis` ∈ askllm/askllmr、
#' `dataset` 可由 `datasets::` 取得且 `vars` 全部存在、`question` 非空、
#' `expect` 只含已知欄位。任何問題寫進 `errors`,不 stop()。
#'
#' @param path YAML 路徑
#' @return `list(ok = <lgl>, items = <list>, errors = <chr>)`
#' @keywords internal
.askllm_load_golden <- function(path) {
    fail <- function(msg) list(ok = FALSE, items = list(), errors = msg)
    if (!file.exists(path)) return(fail(paste0('golden file not found: ', path)))
    y <- tryCatch(yaml::read_yaml(path), error = function(e) e)
    if (inherits(y, 'condition')) return(fail(paste0('yaml parse error: ', conditionMessage(y))))
    items <- y$items
    if (!is.list(items) || length(items) == 0) return(fail('no `items` in golden file'))

    errors <- character(0)
    ids <- character(0)
    for (i in seq_along(items)) {
        it <- items[[i]]
        tag <- paste0('item ', i, if (!is.null(it$id)) paste0(' (', it$id, ')') else '')
        if (!is.list(it)) { errors <- c(errors, paste0(tag, ': not a mapping')); next }
        unknown <- setdiff(names(it), .ASKLLM_GOLDEN_FIELDS)
        if (length(unknown) > 0)
            errors <- c(errors, paste0(tag, ': unknown field(s) ', paste(unknown, collapse = ', ')))
        if (is.null(it$id) || !nzchar(it$id)) errors <- c(errors, paste0(tag, ': missing id'))
        else if (it$id %in% ids) errors <- c(errors, paste0(tag, ': duplicate id'))
        ids <- c(ids, it$id %||% '')
        if (!(it$analysis %||% '') %in% c('askllm', 'askllmr'))
            errors <- c(errors, paste0(tag, ': analysis must be askllm or askllmr'))
        if (is.null(it$question) || !nzchar(trimws(it$question)))
            errors <- c(errors, paste0(tag, ': empty question'))
        ds <- .askllm_golden_dataset(it$dataset %||% '')
        if (is.null(ds)) {
            errors <- c(errors, paste0(tag, ': unknown dataset ', it$dataset %||% '(none)'))
        } else {
            missing_vars <- setdiff(as.character(unlist(it$vars %||% character(0))), names(ds))
            if (length(missing_vars) > 0)
                errors <- c(errors, paste0(tag, ': vars not in dataset: ',
                                           paste(missing_vars, collapse = ', ')))
        }
        ex <- it$expect
        if (!is.null(ex)) {
            if (!is.list(ex)) errors <- c(errors, paste0(tag, ': expect must be a mapping'))
            else {
                unk <- setdiff(names(ex), .ASKLLM_GOLDEN_EXPECT_FIELDS)
                if (length(unk) > 0)
                    errors <- c(errors, paste0(tag, ': unknown expect field(s) ',
                                               paste(unk, collapse = ', ')))
            }
        }
    }
    list(ok = length(errors) == 0, items = items, errors = errors)
}

#' 依名稱取得 `datasets::` 內建資料集(golden 只允許內建資料,零檔案 I/O)
#'
#' @return data.frame 或 NULL(不存在/非 data.frame)
#' @keywords internal
.askllm_golden_dataset <- function(name) {
    if (is.null(name) || !nzchar(name)) return(NULL)
    obj <- tryCatch(getExportedValue('datasets', name), error = function(e) NULL)
    if (!is.data.frame(obj)) return(NULL)
    obj
}
