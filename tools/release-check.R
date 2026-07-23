# tools/release-check.R
#
# 發佈前後的一鍵檢查流程。不隨套件安裝(位於 tools/)。
# One-command release checklist for building and verifying the .jmo.
#
# 解決三個實際踩過的問題 / Fixes three problems hit in practice:
#   1. jmvtools::install() 產出的 .jmo 位置會飄(有時在模組目錄、有時在當時
#      的工作目錄),容易搬錯或發佈到舊檔。
#      The .jmo lands in different directories depending on the working
#      directory, so it is easy to ship a stale build.
#   2. DESCRIPTION / jamovi/0000.yaml / 檔名三處版本號可能不同步。
#      Version numbers can drift between DESCRIPTION, 0000.yaml, filename.
#   3. GitHub Release 上的檔案未必等於本機最新建置。
#      The release asset may not match the current local build.
#
# ⚠ 重要:.jmo 是 ZIP,內含建置時間戳,因此**相同原始碼每次建置的位元組都不同**。
#   雜湊比對能證明「Release 上的檔案就是我上傳的那一個」,但**不能**用來證明
#   「Release 內容與現在的原始碼相同」——後者要靠「建置後立即上傳」的流程保證。
#   故預設不重建;要重建就走 release_publish()(建置→上傳→驗證一氣呵成)。
#
#   The .jmo is a ZIP with embedded timestamps, so identical source produces
#   different bytes on every build. Hash comparison proves the release asset is
#   the artifact you uploaded — it cannot prove the release matches current
#   source. That is why building and uploading are kept in one step.
#
# 用法 / Usage:
#   setwd('D:/core/LAB/Analysis/jmv_modules/askLLM')
#   source('tools/release-check.R')
#
#   release_check()                  # 檢查現況:版本、測試、git、dist 雜湊
#   release_check(verify = TRUE)     # 另外下載 Release 附件比對是否為同一檔
#   release_check(build = TRUE)      # 重建並捕捉 .jmo(之後需自行上傳)
#   release_publish()                # 完整發佈:檢查→重建→上傳→驗證
#
# 需求 / Requirements:
#   devtools、jmvtools、openssl(或 digest);verify/publish 另需 gh CLI。

JAMOVI_HOME   <- 'C:/Program Files/jamovi 2.7.37.0'
JAMOVI_SERIES <- '2.7'
PLATFORM_TAG  <- 'win64'

# ---- 內部工具 ---------------------------------------------------------------

.rc_msg <- function(status, label, detail = '') {
    mark <- switch(status, ok = 'PASS', warn = 'WARN', fail = 'FAIL', '....')
    cat(sprintf('[%s] %-34s %s\n', mark, label, detail))
    invisible(identical(status, 'ok'))
}

.rc_sha256 <- function(path) {
    if (requireNamespace('openssl', quietly = TRUE)) {
        con <- file(path, 'rb'); on.exit(close(con))
        return(toupper(as.character(openssl::sha256(con))))
    }
    if (requireNamespace('digest', quietly = TRUE))
        return(toupper(digest::digest(file = path, algo = 'sha256')))
    stop('需要 openssl 或 digest 套件才能計算 SHA-256', call. = FALSE)
}

.rc_desc_version <- function(root) {
    d <- read.dcf(file.path(root, 'DESCRIPTION'))
    as.character(d[1, 'Version'])
}

.rc_yaml_version <- function(root) {
    p <- file.path(root, 'jamovi', '0000.yaml')
    if (!file.exists(p)) return(NA_character_)
    ln <- grep('^version:', readLines(p, warn = FALSE), value = TRUE)
    if (!length(ln)) return(NA_character_)
    trimws(sub('^version:\\s*', '', ln[1]))
}

# gh CLI 會優先讀 GITHUB_TOKEN 環境變數;若使用者把「只有 Models 權限」的
# token 設在該名稱下,gh 會用它而權限不足。呼叫期間暫時清掉再還原。
.rc_with_gh <- function(expr) {
    saved <- Sys.getenv('GITHUB_TOKEN', unset = NA)
    if (!is.na(saved)) {
        Sys.unsetenv('GITHUB_TOKEN')
        on.exit(Sys.setenv(GITHUB_TOKEN = saved), add = TRUE)
    }
    force(expr)
}

# jmvtools 產出的 .jmo 位置會飄:搜尋模組目錄、其上層、以及當時工作目錄,
# 只接受「建置開始之後才產生」的檔案,避免誤把舊檔當成新建置。
.rc_find_jmo <- function(root, since) {
    dirs <- unique(c(root, dirname(root), getwd()))
    hits <- character(0)
    for (d in dirs) {
        f <- list.files(d, pattern = '\\.jmo$', full.names = TRUE)
        hits <- c(hits, f)
    }
    hits <- unique(normalizePath(hits, winslash = '/', mustWork = FALSE))
    hits <- hits[!grepl('/dist/', hits, fixed = TRUE)]
    if (!length(hits)) return(NULL)
    info <- file.info(hits)
    fresh <- rownames(info)[info$mtime >= since]
    if (!length(fresh)) return(NULL)
    fresh[order(file.info(fresh)$mtime, decreasing = TRUE)][1]
}

# ---- known-modules.yaml 新鮮度(提醒閘,不是硬閘;永不 stop()) --------------
#
# inst/catalog/known-modules.yaml 是 tools/sync-known-modules.R 抓取官方
# jamovi library 產生的快照,會隨上游更新而過時。此檢查只提醒重跑同步腳本,
# 從不阻擋發佈。規格依據:specs/v1.1-module-aware.zh-TW.md §4.5。

check_known_modules_freshness <- function(path = 'inst/catalog/known-modules.yaml',
                                          today = Sys.Date(), threshold_days = 60) {
    warn_line <- function(detail) {
        msg <- sprintf('WARN: %s -- run tools/sync-known-modules.R (sync-known-modules) to refresh',
                       detail)
        cat(msg, '\n', sep = '')
        invisible(msg)
    }

    if (!file.exists(path))
        return(warn_line(sprintf('known-modules.yaml not found (%s)', path)))

    doc <- tryCatch(yaml::read_yaml(path), error = function(e) NULL)
    rd <- if (!is.null(doc)) doc$retrieved_date else NULL
    d <- if (!is.null(rd))
        suppressWarnings(tryCatch(as.Date(as.character(rd)), error = function(e) NA))
    else
        NA

    if (is.null(doc) || is.null(rd) || is.na(d))
        return(warn_line(sprintf(
            'known-modules.yaml retrieved_date unreadable (%s)', path)))

    age <- as.integer(as.Date(today) - d)
    if (age > threshold_days)
        return(warn_line(sprintf(
            'known-modules.yaml is %d days old (> %d)', age, threshold_days)))

    msg <- sprintf('OK: known-modules.yaml retrieved %d day(s) ago (<= %d)',
                   age, threshold_days)
    cat(msg, '\n', sep = '')
    invisible(msg)
}

# ---- 主流程 -----------------------------------------------------------------

release_check <- function(root = getwd(),
                          home = JAMOVI_HOME,
                          verify = FALSE,
                          tag = NULL,
                          skip_tests = FALSE,
                          build = FALSE) {

    root <- normalizePath(root, winslash = '/', mustWork = TRUE)
    cat('\n=== askLLM release check ===\n')
    cat('模組 / module: ', root, '\n\n', sep = '')
    problems <- character(0)
    note <- function(x) problems <<- c(problems, x)

    # 1. 版本號三處一致
    dv <- .rc_desc_version(root)
    yv <- .rc_yaml_version(root)
    if (identical(dv, yv)) {
        .rc_msg('ok', '版本號一致 (DESCRIPTION/0000.yaml)', dv)
    } else {
        .rc_msg('fail', '版本號不一致', sprintf('DESCRIPTION=%s  0000.yaml=%s', dv, yv))
        note('版本號不一致:請對齊 DESCRIPTION 與 jamovi/0000.yaml')
    }

    # 2. 測試
    if (skip_tests) {
        .rc_msg('warn', '測試', '已跳過(skip_tests = TRUE)')
        note('測試被跳過,發佈前請補跑 devtools::test()')
    } else {
        res <- as.data.frame(devtools::test(root, reporter = 'silent'))
        nfail <- sum(res$failed) + sum(res$error)
        npass <- sum(res$passed)
        if (nfail == 0) {
            .rc_msg('ok', '測試', sprintf('%d passed, 0 failed', npass))
        } else {
            .rc_msg('fail', '測試', sprintf('%d passed, %d failed', npass, nfail))
            note(sprintf('%d 個測試失敗,不應發佈', nfail))
        }
    }

    # 3. git 工作區乾淨(確保建置內容 = 已提交內容)
    st <- tryCatch(
        system2('git', c('-C', shQuote(root), 'status', '--porcelain'),
                stdout = TRUE, stderr = TRUE),
        error = function(e) NA_character_)
    if (length(st) == 0) {
        .rc_msg('ok', 'git 工作區', 'clean')
    } else if (identical(st, NA_character_)) {
        .rc_msg('warn', 'git 工作區', '無法檢查(git 不可用?)')
    } else {
        .rc_msg('warn', 'git 工作區', sprintf('%d 個未提交變更', length(st)))
        note('工作區有未提交變更:建置內容可能與 repo 不符')
    }

    # 4. 重建並捕捉 .jmo
    dist_dir <- file.path(root, 'dist')
    dir.create(dist_dir, showWarnings = FALSE)
    target <- file.path(dist_dir, sprintf('askLLM_%s_%s_jamovi-%s.jmo',
                                          dv, PLATFORM_TAG, JAMOVI_SERIES))

    if (!build) {
        .rc_msg('....', '建置', '未重建(build = TRUE 可重建)')
    } else {
        started <- Sys.time() - 2   # 容忍時鐘誤差
        old <- getOption('jamovi_home')
        options(jamovi_home = home)
        on.exit(options(jamovi_home = old), add = TRUE)

        cat('\n--- jmvtools::install() ---\n')
        t0 <- Sys.time()
        jmvtools::install(root)
        mins <- round(as.numeric(difftime(Sys.time(), t0, units = 'mins')), 1)
        cat('--- 建置完成,', mins, '分鐘 ---\n\n', sep = '')

        found <- .rc_find_jmo(root, started)
        if (is.null(found)) {
            .rc_msg('fail', '捕捉 .jmo', '找不到新產生的 .jmo')
            note('建置後找不到 .jmo;請確認 jmvtools::install() 是否成功')
        } else {
            ok <- file.rename(found, target)
            if (!ok) ok <- file.copy(found, target, overwrite = TRUE) &&
                           file.remove(found)
            if (ok) {
                .rc_msg('ok', '捕捉 .jmo → dist/', basename(target))
            } else {
                .rc_msg('fail', '捕捉 .jmo', paste('搬移失敗(檔案被佔用?):', found))
                note('無法搬移 .jmo:請關閉 jamovi 後重試')
            }
        }
    }

    # 5. 雜湊
    local_hash <- NULL
    if (file.exists(target)) {
        local_hash <- .rc_sha256(target)
        .rc_msg('ok', '本機 .jmo SHA-256',
                sprintf('%s… (%s bytes)', substr(local_hash, 1, 16),
                        format(file.info(target)$size, big.mark = ',')))
    } else {
        .rc_msg('fail', '本機 .jmo', '不存在')
        note('dist/ 下沒有對應版本的 .jmo')
    }

    # 6. 與 GitHub Release 比對
    if (verify && !is.null(local_hash)) {
        tg <- if (is.null(tag)) paste0('v', dv) else tag
        tmp <- tempfile(fileext = '.jmo')
        dl <- .rc_with_gh(tryCatch(
            system2('gh', c('release', 'download', tg,
                            '--repo', 'SCgeeker/askLLM',
                            '--pattern', shQuote('*.jmo'),
                            '--output', shQuote(tmp), '--clobber'),
                    stdout = TRUE, stderr = TRUE),
            error = function(e) NA_character_))

        if (!file.exists(tmp)) {
            .rc_msg('warn', paste('下載 Release', tg), '失敗(尚未發佈或 gh 未登入)')
            note(sprintf('無法下載 Release %s 比對', tg))
        } else {
            remote_hash <- .rc_sha256(tmp)
            if (identical(local_hash, remote_hash)) {
                .rc_msg('ok', paste('Release', tg, '比對'), '一致(同一個檔案)')
            } else {
                .rc_msg('fail', paste('Release', tg, '比對'),
                        sprintf('本機 %s… vs 遠端 %s…',
                                substr(local_hash, 1, 12), substr(remote_hash, 1, 12)))
                note(sprintf(paste0(
                    'Release %s 的附件與 dist/ 下的檔案不同。\n',
                    '    若 dist/ 是較新的建置,執行:\n',
                    '      gh release upload %s "%s" --clobber\n',
                    '    (提醒:.jmo 含時間戳,重建必然改變雜湊,',
                    '不代表原始碼有變)'),
                    tg, tg, target))
            }
            unlink(tmp)
        }
    }

    # ---- 總結 ----
    cat('\n')
    if (!length(problems)) {
        cat('全部通過 / all checks passed\n')
    } else {
        cat('需處理事項 / action required:\n')
        for (p in problems) cat('  - ', p, '\n', sep = '')
    }
    cat('\n')

    invisible(list(version = dv, jmo = target, sha256 = local_hash,
                   problems = problems))
}

#' 完整發佈流程:檢查 → 重建 → 上傳 → 驗證
#'
#' 建置與上傳綁在一起,是因為 .jmo 含時間戳、無法用雜湊反推原始碼;
#' 唯有「建完立刻傳」才能保證 Release 上的檔案就是這份原始碼建出來的。
#'
#' @param dry_run TRUE 時只做檢查與建置,不真的上傳。
release_publish <- function(root = getwd(),
                            home = JAMOVI_HOME,
                            tag = NULL,
                            dry_run = FALSE) {

    res <- release_check(root = root, home = home, build = TRUE, verify = FALSE)

    blocking <- grep('測試失敗|版本號不一致|找不到|不存在', res$problems, value = TRUE)
    if (length(blocking)) {
        cat('發佈中止 / publish aborted:\n')
        for (b in blocking) cat('  - ', b, '\n', sep = '')
        return(invisible(res))
    }

    tg <- if (is.null(tag)) paste0('v', res$version) else tag
    if (dry_run) {
        cat('dry_run:略過上傳。實際指令為 / would run:\n')
        cat(sprintf('  gh release upload %s "%s" --clobber\n\n', tg, res$jmo))
        return(invisible(res))
    }

    cat('上傳到 Release ', tg, ' …\n', sep = '')
    out <- .rc_with_gh(system2('gh',
        c('release', 'upload', tg, '--repo', 'SCgeeker/askLLM',
          shQuote(res$jmo), '--clobber'),
        stdout = TRUE, stderr = TRUE))
    if (!is.null(attr(out, 'status')) && attr(out, 'status') != 0) {
        cat('上傳失敗 / upload failed:\n'); cat(out, sep = '\n')
        return(invisible(res))
    }

    cat('\n--- 上傳後驗證 / verifying ---\n')
    release_check(root = root, home = home, build = FALSE, verify = TRUE,
                  tag = tg, skip_tests = TRUE)
}
