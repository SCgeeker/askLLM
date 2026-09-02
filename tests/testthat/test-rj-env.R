# test-rj-env.R — 對應 dev-notes/r-tutor-bridge-plan.zh-TW.md「構件 1」
#
# scan_rj()/rj_env_text() 契約比照 module-catalog.R:決定性、永不 stop()、可注入。

# ---- scan_rj:已裝(欄位齊、套件 radix 排序去重)-----------------------------

test_that('scan_rj 讀到已裝的 Rj:欄位齊全,套件 radix 排序', {
    dir_a <- test_path('fixtures', 'modules', 'rj-a')

    res <- scan_rj(dirs = dir_a)

    expect_true(res$installed)
    expect_equal(res$version, '1.2.3')
    expect_equal(res$r_version, '4.9.9-x64')
    expect_equal(res$min_app, '1.0.0')
    expect_equal(res$packages, c('pkgA', 'pkgB'))     # radix 排序
    expect_equal(res$editors, c('Rj', 'Rjp'))
    expect_equal(res$errors, character(0))
})

# ---- scan_rj:未裝(無 Rj/jamovi.yaml)---------------------------------------

test_that('scan_rj 找不到 Rj 時 installed=FALSE、packages 空、無 error', {
    dir_none <- test_path('fixtures', 'modules', 'rj-none')

    res <- scan_rj(dirs = dir_none)

    expect_false(res$installed)
    expect_equal(res$packages, character(0))
    expect_equal(res$errors, character(0))
    expect_null(res$version)
})

test_that('scan_rj 對缺失目錄不 stop、視同未裝', {
    missing_dir <- test_path('fixtures', 'modules', 'does-not-exist')

    expect_no_error(res <- scan_rj(dirs = missing_dir))
    expect_false(res$installed)
})

# ---- scan_rj:yaml 損毀 -------------------------------------------------------

test_that('scan_rj 對損毀 yaml 記錄 errors、不 stop、installed=FALSE', {
    dir_broken <- test_path('fixtures', 'modules', 'rj-broken')

    expect_no_error(res <- scan_rj(dirs = dir_broken))
    expect_false(res$installed)
    expect_equal(res$packages, character(0))
    expect_true(length(res$errors) > 0)
    expect_true(grepl('jamovi.yaml', res$errors[1], fixed = TRUE))
})

# ---- scan_rj:多目錄重複時取第一個 -------------------------------------------

test_that('scan_rj 多目錄皆有 Rj 時只取第一個命中', {
    dir_a <- test_path('fixtures', 'modules', 'rj-a')
    dir_b <- test_path('fixtures', 'modules', 'rj-b')

    res <- scan_rj(dirs = c(dir_a, dir_b))

    expect_equal(res$version, '1.2.3')      # 來自 dir_a,非 dir_b 的 9.9.9
    expect_equal(res$packages, c('pkgA', 'pkgB'))
})

# ---- scan_rj:dirs=NULL 使用 default_module_dirs() ---------------------------

test_that('scan_rj(dirs=NULL) 呼叫 default_module_dirs()', {
    called <- FALSE
    testthat::local_mocked_bindings(
        default_module_dirs = function() { called <<- TRUE; character(0) })

    res <- scan_rj(dirs = NULL)

    expect_true(called)
    expect_false(res$installed)
})

# ---- rj_env_text:同輸入同輸出(決定性)---------------------------------------

test_that('rj_env_text 決定性:同輸入同輸出', {
    scan <- list(installed = TRUE, version = '1.2.3', r_version = '4.9.9-x64',
                 min_app = '1.0.0', packages = c('pkgA', 'pkgB'),
                 editors = c('Rj', 'Rjp'), errors = character(0))

    out1 <- rj_env_text(scan)
    out2 <- rj_env_text(scan)
    expect_identical(out1, out2)

    out3 <- withr::with_locale(c(LC_COLLATE = 'C'), rj_env_text(scan))
    expect_identical(out1, out3)
})

test_that('rj_env_text 含固定行與套件清單', {
    scan <- list(installed = TRUE, version = '1.2.3', r_version = '4.9.9-x64',
                 min_app = '1.0.0', packages = c('pkgA', 'pkgB'),
                 editors = c('Rj', 'Rjp'), errors = character(0))

    txt <- rj_env_text(scan)

    expect_true(is.character(txt))
    expect_length(txt, 1)
    expect_true(grepl('Rj Editor 1.2.3 is installed', txt, fixed = TRUE))
    expect_true(grepl("named 'data'", txt, fixed = TRUE))
    expect_true(grepl('bundled R 4.9.9-x64', txt, fixed = TRUE))
    expect_true(grepl('System R', txt, fixed = TRUE))
    expect_true(grepl('Rj Editor + can write columns back.', txt, fixed = TRUE))
    expect_true(grepl('Packages bundled with Rj: pkgA, pkgB', txt, fixed = TRUE))
})

# ---- rj_env_text:未裝 -> NULL ------------------------------------------------

test_that('rj_env_text 對未裝的 scan 回傳 NULL', {
    scan_not_installed <- list(installed = FALSE, version = NULL, r_version = NULL,
                               min_app = NULL, packages = character(0),
                               editors = character(0), errors = character(0))
    expect_null(rj_env_text(scan_not_installed))
    expect_null(rj_env_text(NULL))
    expect_null(rj_env_text(list()))
})

# ---- rj_env_text:套件清單超預算時截斷 ---------------------------------------

test_that('rj_env_text 套件清單超預算時以 .greedy_truncate 同型截斷', {
    many_pkgs <- sprintf('pkg%03d', 1:100)
    scan <- list(installed = TRUE, version = '1.0.0', r_version = '4.0.0',
                 min_app = '1.0.0', packages = many_pkgs,
                 editors = c('Rj'), errors = character(0))

    txt <- rj_env_text(scan, char_budget = 300)

    expect_true(count_chars(txt) <= 300 || startsWith(txt, 'Rj Editor 1.0.0'))
    expect_true(grepl('pkg001', txt, fixed = TRUE))          # 首項保底
    expect_true(grepl('\\[\\+\\d+ more\\]', txt))            # 截斷標記同型
})

test_that('rj_env_text 套件清單為空時仍輸出區塊(不出現截斷標記)', {
    scan <- list(installed = TRUE, version = '1.0.0', r_version = '4.0.0',
                 min_app = '1.0.0', packages = character(0),
                 editors = character(0), errors = character(0))

    txt <- rj_env_text(scan)
    expect_true(grepl('Packages bundled with Rj:', txt, fixed = TRUE))
    expect_false(grepl('\\[\\+\\d+ more\\]', txt))
})

# ---- rj_env_text:不含 locale 相依格式(數字/日期格式化)----------------------

test_that('rj_env_text 不含 locale 相依格式', {
    scan <- list(installed = TRUE, version = '1.2.3', r_version = '4.9.9-x64',
                 min_app = '1.0.0', packages = c('zeta', 'Alpha', 'beta'),
                 editors = c('Rj'), errors = character(0))

    out_default <- rj_env_text(scan)
    out_c <- withr::with_locale(c(LC_COLLATE = 'C'), rj_env_text(scan))
    expect_identical(out_default, out_c)
})
