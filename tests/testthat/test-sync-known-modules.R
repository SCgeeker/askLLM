# test-sync-known-modules.R
#
# 測試 tools/sync-known-modules.R(離線開發工具,不隨套件安裝)與
# tools/release-check.R 新增的 check_known_modules_freshness()。
# S15、S16(specs/v1.1-module-aware.zh-TW.md §6)。
#
# tools/ 不隨套件安裝,故手動 source 進本檔的環境。

local({
    root <- normalizePath(file.path(testthat::test_path(), '..', '..'),
                          winslash = '/', mustWork = TRUE)
    source(file.path(root, 'tools', 'sync-known-modules.R'), local = FALSE)
    source(file.path(root, 'tools', 'release-check.R'), local = FALSE)
})

# ---- S15:sync_known_modules 決定性與容錯 -----------------------------------

.sync_fixture_fetch <- function(url) {
    dir <- testthat::test_path('fixtures', 'sync', 'known-modules')
    read_fixture <- function(f)
        paste(readLines(file.path(dir, f), warn = FALSE, encoding = 'UTF-8'),
              collapse = '\n')

    if (grepl('modules\\.yaml$', url)) return(read_fixture('modules.yaml'))
    if (grepl('/alpha/', url, fixed = TRUE)) return(read_fixture('alpha-0000.yaml'))
    if (grepl('/gamma/', url, fixed = TRUE)) return(read_fixture('gamma-0000.yaml'))

    # beta 被標為 hidden,絕不應該走到這裡被抓取
    stop('fixture_fetch: unexpected url (should not be fetched): ', url)
}

test_that('sync regenerates deterministically', {
    tmp1 <- tempfile(fileext = '.yaml')
    tmp2 <- tempfile(fileext = '.yaml')
    on.exit(unlink(c(tmp1, tmp2)), add = TRUE)

    suppressWarnings(sync_known_modules(fetch = .sync_fixture_fetch, dest = tmp1,
                                        retrieved_date = '2026-01-01'))
    suppressWarnings(sync_known_modules(fetch = .sync_fixture_fetch, dest = tmp2,
                                        retrieved_date = '2026-01-01'))

    b1 <- readBin(tmp1, 'raw', n = file.info(tmp1)$size)
    b2 <- readBin(tmp2, 'raw', n = file.info(tmp2)$size)
    expect_identical(b1, b2)

    doc <- yaml::read_yaml(tmp1)
    expect_equal(doc$source_url,
                'https://raw.githubusercontent.com/jonathon-love/jamovi-library/master/modules.yaml')
    expect_equal(doc$retrieved_date, '2026-01-01')

    names <- vapply(doc$modules, function(m) m$name, character(1))
    expect_true('alpha' %in% names)
    expect_false('beta' %in% names)     # hidden
    expect_false('gamma' %in% names)    # 缺 description -> 跳過

    alpha <- doc$modules[[which(names == 'alpha')]]
    expect_equal(alpha$title, 'Alpha Module')
    expect_equal(alpha$provides, 'Alpha module does alpha things.')
    expect_equal(alpha$tags, 'regression')   # hidden 分析不計入
})

test_that('sync skips entries with missing fields with a warning', {
    tmp <- tempfile(fileext = '.yaml')
    on.exit(unlink(tmp), add = TRUE)

    expect_warning(
        sync_known_modules(fetch = .sync_fixture_fetch, dest = tmp,
                           retrieved_date = '2026-01-01'),
        'gamma'
    )

    # 呼叫本身不應丟出其他 error/中斷整體流程
    expect_true(file.exists(tmp))
})

test_that('sync source_url fetch failure is fatal (stop)', {
    boom <- function(url) stop('network down')
    tmp <- tempfile(fileext = '.yaml')
    on.exit(unlink(tmp), add = TRUE)

    expect_error(
        sync_known_modules(fetch = boom, dest = tmp, retrieved_date = '2026-01-01'),
        'sync_known_modules'
    )
})

# ---- S16:release-check freshness -------------------------------------------

test_that('freshness check warns when stale', {
    fixture <- tempfile(fileext = '.yaml')
    writeLines(c('source_url: http://example.com/modules.yaml',
                "retrieved_date: '2026-01-01'",
                'modules: []'),
              fixture, useBytes = TRUE)
    on.exit(unlink(fixture), add = TRUE)

    out_fresh <- capture.output(
        check_known_modules_freshness(fixture, today = as.Date('2026-01-15')))
    expect_false(any(grepl('^WARN:', out_fresh)))

    out_stale <- capture.output(
        check_known_modules_freshness(fixture, today = as.Date('2026-06-01')))
    expect_true(any(grepl('^WARN:.*sync-known-modules', out_stale)))

    out_missing <- capture.output(
        check_known_modules_freshness(file.path(tempdir(), 'no-such-known-modules.yaml'),
                                      today = as.Date('2026-06-01')))
    expect_true(any(grepl('^WARN:.*sync-known-modules', out_missing)))

    # 三種情形皆不 stop()
    expect_error(check_known_modules_freshness(fixture, today = as.Date('2026-01-15')), NA)
    expect_error(check_known_modules_freshness(fixture, today = as.Date('2026-06-01')), NA)
    expect_error(
        check_known_modules_freshness(file.path(tempdir(), 'no-such-known-modules.yaml')),
        NA)
})
