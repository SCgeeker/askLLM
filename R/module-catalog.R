# module-catalog.R — 模組掃描核心(純函式)
#
# 掃描本機 jamovi 模組目錄,取得已安裝模組的分析選單結構,轉為決定性純文字
# 供上層嵌入 LLM prompt(治「編造選單路徑」的幻覺)。另提供已安裝模組排除
# 官方清單後的「可安裝」清單文字。
#
# 共同契約(比照 data-summary.R):決定性(同輸入同輸出,與 locale/時區無關)、
# 永不 stop()(一切失敗以回傳值表達)、可注入(路徑/資料皆可由參數覆寫供測試)。
#
# 對外:
#   default_module_dirs() -> character
#   scan_modules(dirs = NULL) -> list(modules = <list>, errors = <character>)
#   catalog_text(catalog, char_budget = 2500) -> character(1) 或 NULL
#   available_text(known, installed_names, char_budget = 900) -> character(1) 或 NULL

# ---- 自我定位/庫路徑:包成薄函式,供測試以 local_mocked_bindings 注入 -------

.askllm_pkg_path <- function() {
    system.file(package = 'askLLM')
}

.askllm_lib_paths <- function() {
    .libPaths()
}

# ---- default_module_dirs() 的四個信號子步驟 --------------------------------

# Windows 絕對路徑(如 'C:\...'、'\\server\share')或 POSIX 絕對路徑('/...')
.is_abs_path <- function(x) {
    grepl('^([A-Za-z]:[/\\\\]|[/\\\\]{1,2})', x)
}

.self_location_dir <- function() {
    p <- tryCatch(.askllm_pkg_path(), error = function(e) '')
    if (is.null(p) || length(p) != 1 || is.na(p) || !nzchar(p)) return(character(0))
    if (!identical(basename(dirname(p)), 'R')) return(character(0))
    up3 <- dirname(dirname(dirname(p)))
    if (!identical(basename(up3), 'modules')) return(character(0))
    up3
}

.env_var_dirs <- function() {
    mp <- Sys.getenv('JAMOVI_MODULES_PATH', unset = '')
    if (!nzchar(mp)) return(character(0))
    segs <- strsplit(mp, .Platform$path.sep, fixed = TRUE)[[1]]
    segs <- segs[nzchar(segs)]
    if (length(segs) == 0) return(character(0))
    home <- Sys.getenv('JAMOVI_HOME', unset = '')
    vapply(segs, function(seg) {
        if (!.is_abs_path(seg) && nzchar(home)) file.path(home, seg) else seg
    }, character(1), USE.NAMES = FALSE)
}

.platform_dirs <- function() {
    sysname <- tryCatch(Sys.info()[['sysname']], error = function(e) '')
    if (identical(sysname, 'Windows')) {
        return(file.path(Sys.getenv('APPDATA'), 'jamovi', 'modules'))
    }
    if (identical(sysname, 'Darwin')) {
        return(path.expand('~/Library/Application Support/jamovi/modules'))
    }
    # Linux(含未知平台的後備假設)
    c(path.expand('~/.jamovi/modules'),
      path.expand('~/.var/app/org.jamovi.jamovi/data/jamovi/modules'))
}

.libpath_dirs <- function() {
    lp <- tryCatch(.askllm_lib_paths(), error = function(e) character(0))
    if (length(lp) == 0) return(character(0))
    hit <- grepl('[/\\\\]modules[/\\\\][^/\\\\]+[/\\\\]R$', lp)
    lp <- lp[hit]
    if (length(lp) == 0) return(character(0))
    vapply(lp, function(x) dirname(dirname(x)), character(1), USE.NAMES = FALSE)
}

#' 探索候選 jamovi 模組根目錄
#'
#' 依「自我定位 > 環境變數 > 平台慣例路徑 > .libPaths() 後備」順序收集候選
#' 路徑,正規化、去重(保留首次出現)後,僅回傳實際存在的目錄。任何信號
#' 取得失敗一律靜默略過,函式本身永不 error。
#'
#' @return character 向量(可為 character(0))
#' @keywords internal
default_module_dirs <- function() {
    tryCatch({
        dirs <- c(
            .self_location_dir(),
            .env_var_dirs(),
            .platform_dirs(),
            .libpath_dirs()
        )
        dirs <- dirs[!is.na(dirs) & nzchar(dirs)]
        if (length(dirs) == 0) return(character(0))
        norm <- tryCatch(
            normalizePath(dirs, winslash = '/', mustWork = FALSE),
            error = function(e) character(0))
        norm <- unique(norm)
        norm[dir.exists(norm)]
    }, error = function(e) character(0))
}

# ---- scan_modules() ---------------------------------------------------------

# yaml 純量欄位安全轉字元:NULL/NA/空字串一律回 NULL
.yaml_chr <- function(x) {
    if (is.null(x)) return(NULL)
    x <- as.character(x)[1]
    if (is.na(x) || !nzchar(x)) return(NULL)
    x
}

.scan_one_analysis <- function(a) {
    if (!is.list(a)) return(NULL)
    mg <- .yaml_chr(a$menuGroup)
    mt <- .yaml_chr(a$menuTitle)
    if (is.null(mg) || is.null(mt)) return(NULL)          # 缺 menuGroup/menuTitle 靜默剔除
    if (identical(tolower(mg), 'hidden')) return(NULL)    # hidden 分析剔除
    list(
        name         = .yaml_chr(a$name) %||% '',
        menuGroup    = mg,
        menuSubgroup = .yaml_chr(a$menuSubgroup),
        menuTitle    = mt,
        menuSubtitle = .yaml_chr(a$menuSubtitle)
    )
}

.scan_one_module <- function(yml) {
    parsed <- tryCatch(yaml::read_yaml(yml), error = function(e) e)
    if (inherits(parsed, 'condition')) {
        return(list(error = paste0(yml, ': ', conditionMessage(parsed))))
    }
    if (!is.list(parsed)) {
        return(list(error = paste0(yml, ': invalid jamovi.yaml structure')))
    }
    name <- .yaml_chr(parsed$name)
    if (is.null(name)) {
        return(list(error = paste0(yml, ': missing name')))
    }
    title <- .yaml_chr(parsed$title) %||% name

    raw_an <- parsed$analyses
    an_list <- list()
    if (is.list(raw_an)) {
        for (a in raw_an) {
            one <- .scan_one_analysis(a)
            if (!is.null(one)) an_list[[length(an_list) + 1]] <- one
        }
    }
    if (length(an_list) == 0) return(list(error = NULL, module = NULL))  # 空模組:靜默剔除,非錯誤

    list(error = NULL, module = list(name = name, title = title, analyses = an_list))
}

#' 掃描本機 jamovi 模組目錄
#'
#' @param dirs 模組根目錄向量;`NULL` 時使用 [default_module_dirs()]。
#' @return `list(modules = <list>, errors = <character>)`
#' @keywords internal
scan_modules <- function(dirs = NULL) {
    if (is.null(dirs)) dirs <- default_module_dirs()
    dirs <- dirs[!is.na(dirs) & nzchar(dirs)]

    modules <- list()
    errors <- character(0)
    seen <- character(0)

    for (d in dirs) {
        if (!dir.exists(d)) next
        subdirs <- tryCatch(sort(list.dirs(d, recursive = FALSE), method = 'radix'),
                             error = function(e) character(0))
        for (sd in subdirs) {
            yml <- file.path(sd, 'jamovi.yaml')
            if (!file.exists(yml)) next

            res <- tryCatch(.scan_one_module(yml),
                             error = function(e) list(error = paste0(yml, ': ', conditionMessage(e))))

            if (!is.null(res$error)) {
                errors <- c(errors, res$error)
                next
            }
            if (is.null(res$module)) next  # 空模組(analyses 過濾後為空),靜默剔除

            key <- tolower(res$module$name)
            if (key %in% seen) next
            seen <- c(seen, key)
            modules[[length(modules) + 1]] <- res$module
        }
    }

    list(modules = modules, errors = errors)
}

# ---- catalog_text() ---------------------------------------------------------

.catalog_analysis_line <- function(a) {
    parts <- c('Analyses', a$menuGroup)
    if (!is.null(a$menuSubgroup) && nzchar(a$menuSubgroup)) parts <- c(parts, a$menuSubgroup)
    parts <- c(parts, a$menuTitle)
    line <- paste0('  ', paste(parts, collapse = ' > '))
    if (!is.null(a$menuSubtitle) && nzchar(a$menuSubtitle))
        line <- paste0(line, ' \u2014 ', a$menuSubtitle)
    line
}

.catalog_module_block <- function(m) {
    header <- paste0(m$name, ' (', m$title, '):')
    lines <- vapply(m$analyses, .catalog_analysis_line, character(1))
    paste(c(header, lines), collapse = '\n')
}

# 以「整區塊」為單位貪婪納入,首區塊(排序後第一個)無條件保底
.greedy_truncate <- function(items, char_budget, join, marker_fmt) {
    n <- length(items)
    full <- paste(items, collapse = join)
    if (count_chars(full) <= char_budget)
        return(full)

    included <- character(0)
    for (i in seq_len(n)) {
        trial <- c(included, items[i])
        remaining_after <- n - length(trial)
        trial_text <- paste(trial, collapse = join)
        if (remaining_after > 0)
            trial_text <- paste0(trial_text, join, sprintf(marker_fmt, remaining_after))
        if (i == 1L || count_chars(trial_text) <= char_budget) {
            included <- trial
        } else {
            break
        }
    }

    omitted <- n - length(included)
    body <- paste(included, collapse = join)
    if (omitted > 0)
        body <- paste0(body, join, sprintf(marker_fmt, omitted))
    body
}

#' 把 scan_modules() 結果轉為決定性純文字
#'
#' @param catalog [scan_modules()] 的回傳值(或同構 list;以 `catalog$modules` 存取)。
#' @param char_budget 字元預算。
#' @return `character(1)`,或 `NULL`(catalog 為空/無效時,代表上游應完全省略 catalog 區塊)。
#' @keywords internal
catalog_text <- function(catalog, char_budget = 2500) {
    if (is.null(catalog) || !is.list(catalog)) return(NULL)
    modules <- catalog$modules
    if (is.null(modules) || !is.list(modules) || length(modules) == 0) return(NULL)

    nm <- vapply(modules, function(m) .yaml_chr(m$name) %||% '', character(1))
    lower_nm <- tolower(nm)
    jmv_idx <- which(lower_nm == 'jmv')
    rest_idx <- setdiff(seq_along(modules), jmv_idx)
    if (length(rest_idx) > 0)
        rest_idx <- rest_idx[order(nm[rest_idx], method = 'radix')]
    ord <- c(jmv_idx, rest_idx)
    modules <- modules[ord]

    blocks <- vapply(modules, .catalog_module_block, character(1))
    .greedy_truncate(blocks, char_budget, '\n\n', '[+%d more modules omitted]')
}

# ---- available_text() -------------------------------------------------------

.available_entry_line <- function(m) {
    paste0('- ', m$name, ' (', m$title, '): ', m$provides)
}

#' 排除已安裝模組後,產出官方 library「可安裝」清單文字
#'
#' @param known `known-modules.yaml` 經 `yaml::read_yaml()` 的解析結果(以 `known$modules` 存取)。
#' @param installed_names 已安裝模組名 character 向量。
#' @param char_budget 字元預算。
#' @return `character(1)`,或 `NULL`。
#' @keywords internal
available_text <- function(known, installed_names, char_budget = 900) {
    if (is.null(known) || !is.list(known)) return(NULL)
    modules <- known$modules
    if (is.null(modules) || !is.list(modules) || length(modules) == 0) return(NULL)

    installed_lower <- tolower(as.character(installed_names))
    keep <- vapply(modules, function(m) {
        nm <- tolower(.yaml_chr(m$name) %||% '')
        !(nm %in% installed_lower)
    }, logical(1))
    modules <- modules[keep]
    if (length(modules) == 0) return(NULL)

    nm <- vapply(modules, function(m) .yaml_chr(m$name) %||% '', character(1))
    modules <- modules[order(nm, method = 'radix')]

    lines <- vapply(modules, .available_entry_line, character(1))
    .greedy_truncate(lines, char_budget, '\n', '[+%d more \u2014 browse the full jamovi library]')
}
