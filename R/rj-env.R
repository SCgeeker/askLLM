# rj-env.R — Rj 環境本機接地(純函式)
#
# 掃描本機 jamovi 模組目錄中的 Rj(Rj Editor)模組,取得安裝狀態、版本、
# 隨附套件、可用編輯器,轉為決定性純文字供上層嵌入 LLM prompt(讓 LLM
# 產出的 R code 只用「使用者機器上真的有的東西」,治「捏造套件/環境」的幻覺)。
#
# 共同契約(比照 module-catalog.R):決定性(同輸入同輸出,與 locale/時區
# 無關)、永不 stop()(一切失敗以回傳值表達)、可注入(dirs 可由參數覆寫供測試)。
#
# 對外:
#   scan_rj(dirs = NULL) -> list(installed, version, r_version, min_app,
#                                packages, editors, errors)
#   rj_env_text(scan, char_budget = 900) -> character(1) 或 NULL

# ---- scan_rj() ---------------------------------------------------------

# 依序找第一個「<dir>/Rj/jamovi.yaml」存在的候選目錄,回傳其 Rj 子目錄路徑;
# 找不到回 NULL。任何存取失敗一律回 NULL,不 stop。
.scan_rj_hit <- function(dirs) {
    for (d in dirs) {
        yml <- file.path(d, 'Rj', 'jamovi.yaml')
        if (isTRUE(tryCatch(file.exists(yml), error = function(e) FALSE)))
            return(file.path(d, 'Rj'))
    }
    NULL
}

# 「未裝」的統一回傳形狀,errors 可選填(損毀 yaml 時記錄原因)
.scan_rj_not_installed <- function(errors = character(0)) {
    list(installed = FALSE, version = NULL, r_version = NULL, min_app = NULL,
         packages = character(0), editors = character(0), errors = errors)
}

#' 掃描本機 Rj(Rj Editor)模組
#'
#' @param dirs 模組根目錄向量;`NULL` 時使用 [default_module_dirs()]。
#' @return `list(installed, version, r_version, min_app, packages, editors, errors)`。
#'   `installed = FALSE` 時 `version`/`r_version`/`min_app` 皆為 `NULL`,
#'   `packages`/`editors` 皆為 `character(0)`。任何失敗(找不到 Rj、yaml
#'   損毀、目錄不存在)皆降級為 `installed = FALSE`,絕不 `stop()`。
#' @keywords internal
scan_rj <- function(dirs = NULL) {
    if (is.null(dirs)) dirs <- tryCatch(default_module_dirs(), error = function(e) character(0))
    dirs <- dirs[!is.na(dirs) & nzchar(dirs)]

    hit <- tryCatch(.scan_rj_hit(dirs), error = function(e) NULL)
    if (is.null(hit)) return(.scan_rj_not_installed())

    yml <- file.path(hit, 'jamovi.yaml')
    parsed <- tryCatch(yaml::read_yaml(yml), error = function(e) e)
    if (inherits(parsed, 'condition'))
        return(.scan_rj_not_installed(paste0(yml, ': ', conditionMessage(parsed))))
    if (!is.list(parsed))
        return(.scan_rj_not_installed(paste0(yml, ': invalid jamovi.yaml structure')))

    editors <- tryCatch({
        raw_an <- parsed$analyses
        if (!is.list(raw_an)) {
            character(0)
        } else {
            nm <- vapply(raw_an, function(a) {
                if (!is.list(a)) return('')
                .yaml_chr(a$name) %||% ''
            }, character(1))
            nm[nzchar(nm)]
        }
    }, error = function(e) character(0))

    packages <- tryCatch({
        pkg_dir <- file.path(hit, 'R')
        if (!dir.exists(pkg_dir)) {
            character(0)
        } else {
            sub <- list.dirs(pkg_dir, recursive = FALSE)
            sort(unique(basename(sub)), method = 'radix')
        }
    }, error = function(e) character(0))

    list(
        installed = TRUE,
        version   = .yaml_chr(parsed$version),
        r_version = .yaml_chr(parsed$rVersion),
        min_app   = .yaml_chr(parsed$minApp),
        packages  = packages,
        editors   = editors,
        errors    = character(0)
    )
}

# ---- rj_env_text() -----------------------------------------------------

#' 把 scan_rj() 結果轉為決定性純文字
#'
#' @param scan [scan_rj()] 的回傳值(或同構 list)。
#' @param char_budget 字元預算(僅套用於套件清單那一行;固定說明行不截斷)。
#' @return `character(1)`,或 `NULL`(未安裝/無效時,代表上游應完全省略
#'   `<rj_environment>` 區塊)。
#' @keywords internal
rj_env_text <- function(scan, char_budget = 900) {
    if (is.null(scan) || !is.list(scan) || !isTRUE(scan$installed)) return(NULL)

    version   <- .yaml_chr(scan$version) %||% 'unknown'
    r_version <- .yaml_chr(scan$r_version) %||% 'unknown'

    fixed_lines <- c(
        sprintf('Rj Editor %s is installed (Analyses > R > Rj > Rj Editor).', version),
        "The open dataset is available as a data.frame named 'data'.",
        sprintf("R modes: 'jamovi R' (bundled R %s) or 'System R' (needs jmvconnect).", r_version),
        'Rj Editor + can write columns back.'
    )

    packages <- scan$packages
    if (is.null(packages) || !is.character(packages)) packages <- character(0)

    prefix <- 'Packages bundled with Rj: '
    used <- count_chars(paste(fixed_lines, collapse = '\n')) + 1L + count_chars(prefix)
    pkg_budget <- max(char_budget - used, 0L)

    pkg_body <- if (length(packages) == 0) {
        '(none)'
    } else {
        .greedy_truncate(packages, pkg_budget, ', ', '[+%d more]')
    }

    paste(c(fixed_lines, paste0(prefix, pkg_body)), collapse = '\n')
}
