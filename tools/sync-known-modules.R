# tools/sync-known-modules.R
#
# 離線開發工具:自官方 jamovi library 來源(modules.yaml + 各模組的
# jamovi/0000.yaml)產生 inst/catalog/known-modules.yaml 快照,供
# R/module-catalog.R 的 available_text() 在執行期讀取。
#
# 不隨套件安裝(位於 tools/)、不在 jamovi 執行期使用。
# 規格依據:specs/v1.1-module-aware.zh-TW.md §4.4、§4.6。
#
# 用法 / Usage:
#   setwd('D:/core/LAB/Analysis/jmv_modules/askLLM')
#   source('tools/sync-known-modules.R')
#   sync_known_modules()          # 預設寫到 inst/catalog/known-modules.yaml
#
# 決定性(規範性):同一組輸入(含固定 retrieved_date)重跑任意次,輸出
# byte-identical。條目依 name 的 radix 排序輸出(不依來源順序)。
#
# 容錯(規範性):單一模組第二段(0000.yaml)抓取失敗、或 title/description
# 缺漏 → warning() 記錄該模組名後跳過該筆,不中斷整體。第一段
# modules.yaml 抓取或解析失敗才 stop()——這是 v1.1 中唯一允許 stop() 的
# 元件,因其不在 jamovi 執行期。

# ---- 純函式(可離線測試) ----------------------------------------------------

# 字元數(與 R/data-summary.R 的 count_chars 同定義,但本檔獨立於套件
# 而自成一體,不依賴 devtools::load_all() 已載入的套件內部函式)。
.sync_count_chars <- function(x) nchar(x, type = 'chars')

# 由 `https://github.com/<owner>/<repo>.git` 解析 owner/repo
.sync_repo_info <- function(url) {
    u <- sub('\\.git$', '', url)
    u <- sub('/+$', '', u)
    parts <- strsplit(u, '/', fixed = TRUE)[[1]]
    parts <- parts[nzchar(parts)]
    if (length(parts) < 2)
        stop('cannot parse owner/repo from url: ', url, call. = FALSE)
    list(owner = parts[length(parts) - 1], repo = parts[length(parts)])
}

# 組出釘選 commit 的 0000.yaml raw url(subdir 存在且非空時插入)
.sync_raw_0000_url <- function(entry) {
    info <- .sync_repo_info(entry$url)
    subdir <- entry$subdir
    subpath <- if (!is.null(subdir) && nzchar(subdir))
        paste0(subdir, '/jamovi/0000.yaml')
    else
        'jamovi/0000.yaml'
    sprintf('https://raw.githubusercontent.com/%s/%s/%s/%s',
            info$owner, info$repo, entry$commit, subpath)
}

# description -> provides:去 HTML 標籤、壓空白、trimws、截至第一個句號
# (". " 或字串尾)為止;結果超過 160 字元時截為 159 字元 + '…'。
# description 缺漏或去空白後為空 -> NA_character_(呼叫端據此跳過該筆)。
.sync_provides <- function(description) {
    if (is.null(description)) return(NA_character_)
    x <- trimws(as.character(description))
    if (!nzchar(x)) return(NA_character_)

    x <- gsub('<[^>]+>', '', x)
    x <- gsub('\\s+', ' ', x)
    x <- trimws(x)
    if (!nzchar(x)) return(NA_character_)

    pos <- regexpr('. ', x, fixed = TRUE)
    if (pos > 0) x <- substr(x, 1, pos)

    if (.sync_count_chars(x) > 160)
        x <- paste0(substr(x, 1, 159), '\u2026')

    x
}

# analyses -> tags:非 hidden(analysis 條目的 hidden: true)的 menuGroup
# 值,tolower() 後 unique()、radix 排序。無分析者 character(0)。
.sync_tags <- function(analyses) {
    if (is.null(analyses) || !length(analyses)) return(character(0))
    groups <- vapply(analyses, function(a) {
        if (!is.list(a)) return(NA_character_)
        if (isTRUE(a$hidden)) return(NA_character_)
        mg <- a$menuGroup
        if (is.null(mg) || !nzchar(mg)) return(NA_character_)
        tolower(mg)
    }, character(1))
    groups <- groups[!is.na(groups)]
    sort(unique(groups), method = 'radix')
}

# 由解析後的 0000.yaml(info0000)與模組名組出一筆輸出條目。
# title 或 provides 缺漏 -> NULL(呼叫端據此發 warning() 並跳過)。
.sync_module_entry <- function(name, info0000) {
    title <- info0000$title
    if (is.null(title) || !nzchar(trimws(as.character(title)))) return(NULL)

    provides <- .sync_provides(info0000$description)
    if (is.na(provides)) return(NULL)

    list(name = name, title = trimws(as.character(title)), provides = provides,
         tags = .sync_tags(info0000$analyses))
}

# 依 name 的 radix 排序(不依來源/輸入順序)
.sync_sort_modules <- function(modules) {
    if (!length(modules)) return(modules)
    nm <- vapply(modules, function(m) m$name, character(1))
    modules[order(nm, method = 'radix')]
}

# ---- 網路層(薄層,不含邏輯) -------------------------------------------------

# 預設下載器:function(url) -> character(1)(整份檔案內容,UTF-8)。
# 測試一律以 fetch 參數注入 fixture 讀取器,不經過此函式。
# 內建 0.3 秒禮貌性間隔,避免對 GitHub raw 造成密集請求。
.sync_default_fetch <- function(url) {
    Sys.sleep(0.3)
    con <- url(url, open = 'rb')
    on.exit(close(con), add = TRUE)
    paste(readLines(con, warn = FALSE, encoding = 'UTF-8'), collapse = '\n')
}

# ---- 主流程 -----------------------------------------------------------------

#' 自官方 jamovi library 來源生成 inst/catalog/known-modules.yaml
#'
#' @param source_url 官方 modules.yaml 的 raw url
#' @param fetch function(url) -> character(1);NULL 時用內建下載器。
#'   測試注入讀取 fixture 的函式。
#' @param dest 輸出檔路徑
#' @param retrieved_date 記錄於檔頭的抓取日期(ISO 8601);測試注入固定值
#'   以驗證決定性
sync_known_modules <- function(
    source_url = 'https://raw.githubusercontent.com/jonathon-love/jamovi-library/master/modules.yaml',
    fetch = NULL,
    dest = 'inst/catalog/known-modules.yaml',
    retrieved_date = format(Sys.Date())) {

    if (is.null(fetch)) fetch <- .sync_default_fetch

    # 第一段:modules.yaml——唯一允許 stop() 的環節
    src_text <- tryCatch(fetch(source_url), error = function(e) e)
    if (inherits(src_text, 'error'))
        stop(sprintf('sync_known_modules: failed to fetch source_url "%s": %s',
                     source_url, conditionMessage(src_text)), call. = FALSE)

    src_parsed <- tryCatch(yaml::yaml.load(src_text), error = function(e) e)
    if (inherits(src_parsed, 'error') || is.null(src_parsed) ||
        is.null(src_parsed$modules))
        stop(sprintf('sync_known_modules: failed to parse modules.yaml from "%s"',
                     source_url), call. = FALSE)

    entries <- src_parsed$modules

    out_modules <- list()
    seen <- character(0)

    for (e in entries) {
        if (!is.list(e)) next
        if (isTRUE(e$hidden)) next

        nm <- e$name
        if (is.null(nm) || !nzchar(nm)) next
        if (tolower(nm) %in% seen) next   # 同名分平台兩筆 -> 首次出現者勝

        # 第二段:單一模組的 0000.yaml——容錯環節,失敗只 warning() 並跳過
        raw_url <- tryCatch(.sync_raw_0000_url(e), error = function(err) err)
        if (inherits(raw_url, 'error')) {
            warning(sprintf(
                'sync_known_modules: skipping "%s" (cannot build 0000.yaml url: %s)',
                nm, conditionMessage(raw_url)), call. = FALSE)
            next
        }

        info_text <- tryCatch(fetch(raw_url), error = function(err) err)
        if (inherits(info_text, 'error')) {
            warning(sprintf('sync_known_modules: skipping "%s" (fetch failed: %s)',
                            nm, conditionMessage(info_text)), call. = FALSE)
            next
        }

        info0000 <- tryCatch(yaml::yaml.load(info_text), error = function(err) err)
        if (inherits(info0000, 'error') || is.null(info0000)) {
            warning(sprintf('sync_known_modules: skipping "%s" (0000.yaml parse failed)',
                            nm), call. = FALSE)
            next
        }

        entry <- .sync_module_entry(nm, info0000)
        if (is.null(entry)) {
            warning(sprintf(
                'sync_known_modules: skipping "%s" (missing title/description)',
                nm), call. = FALSE)
            next
        }

        seen <- c(seen, tolower(nm))
        out_modules[[length(out_modules) + 1L]] <- entry
    }

    out_modules <- .sync_sort_modules(out_modules)

    doc <- list(source_url = source_url,
               retrieved_date = as.character(retrieved_date),
               modules = out_modules)

    yaml_text <- yaml::as.yaml(doc)

    dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
    con <- file(dest, open = 'wb')
    on.exit(close(con), add = TRUE)
    writeBin(charToRaw(enc2utf8(yaml_text)), con)

    invisible(doc)
}
