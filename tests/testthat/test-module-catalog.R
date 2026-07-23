# test-module-catalog.R
# 對應 specs/v1.1-module-aware.zh-TW.md §6 驗收情境 S1-S4、S6、S10-S12、S14
# (module-catalog 部分;S6 的 .runInner() 情境 c 由 test-brun.R 覆蓋)。

# ---- S1:掃描多目錄涵蓋全部模組與欄位 --------------------------------------

test_that('scan_modules reads modules from multiple dirs', {
    modules_a <- test_path('fixtures', 'modules', 'a')
    modules_b <- test_path('fixtures', 'modules', 'b')

    res <- scan_modules(dirs = c(modules_a, modules_b))

    names_found <- vapply(res$modules, function(m) m$name, character(1))
    expect_equal(length(res$modules), 3)
    expect_setequal(names_found, c('alpha', 'jmv', 'beta'))
    expect_equal(res$errors, character(0))

    alpha <- res$modules[[which(names_found == 'alpha')]]
    expect_equal(length(alpha$analyses), 2)   # 第三筆(hidden)已被過濾

    a1 <- alpha$analyses[[1]]
    expect_equal(a1$name, 'alphaOne')
    expect_equal(a1$menuGroup, 'Alpha')
    expect_equal(a1$menuSubgroup, 'Basic')
    expect_equal(a1$menuTitle, 'Alpha One')
    expect_equal(a1$menuSubtitle, 'First analysis')

    a2 <- alpha$analyses[[2]]
    expect_equal(a2$name, 'alphaTwo')
    expect_equal(a2$menuGroup, 'Alpha')
    expect_null(a2$menuSubgroup)
    expect_equal(a2$menuTitle, 'Alpha Two')
    expect_null(a2$menuSubtitle)
})

# ---- S2:hidden 分析與空模組被過濾 ------------------------------------------

test_that('hidden analyses and empty modules are filtered', {
    modules_a <- test_path('fixtures', 'modules', 'a')

    res <- scan_modules(dirs = modules_a)

    names_found <- vapply(res$modules, function(m) m$name, character(1))
    expect_false('ghost' %in% names_found)     # 唯一分析為 hidden -> 整模組剔除
    expect_false('hollow' %in% names_found)    # analyses: [] -> 整模組剔除

    alpha <- res$modules[[which(names_found == 'alpha')]]
    expect_equal(length(alpha$analyses), 2)    # hidden 分析被過濾,不計入
    expect_equal(res$errors, character(0))     # 過濾不是錯誤
})

# ---- S3:catalog_text 決定性 ------------------------------------------------

test_that('catalog_text is deterministic', {
    mk_an <- function(mt) list(list(name = 'x', menuGroup = 'G',
                                     menuSubgroup = NULL, menuTitle = mt,
                                     menuSubtitle = NULL))
    mk_mod <- function(name, an) list(name = name, title = name, analyses = an)

    # 名稱刻意含大小寫混排,測試 radix 排序;jmv 應恆居首
    catalog <- list(modules = list(
        mk_mod('Zeta', mk_an('T')),
        mk_mod('alpha', mk_an('T')),
        mk_mod('jmv', mk_an('T')),
        mk_mod('Beta', mk_an('T'))
    ), errors = character(0))

    out1 <- catalog_text(catalog)
    out2 <- catalog_text(catalog)
    expect_identical(out1, out2)

    out3 <- withr::with_locale(c(LC_COLLATE = 'C'), catalog_text(catalog))
    expect_identical(out1, out3)

    out4 <- catalog_text(catalog)
    expect_identical(out1, out4)

    blocks <- strsplit(out1, '\n\n', fixed = TRUE)[[1]]
    first_lines <- vapply(blocks, function(b) strsplit(b, '\n', fixed = TRUE)[[1]][1],
                           character(1), USE.NAMES = FALSE)
    names_order <- sub(' \\(.*', '', first_lines)

    expect_equal(names_order, c('jmv', sort(c('Zeta', 'alpha', 'Beta'), method = 'radix')))
})

# ---- S4:budget 以整模組區塊截斷、jmv 保底、尾標 ----------------------------

test_that('catalog_text truncates whole module blocks under budget', {
    mk_an <- function(mt) list(list(name = 'x', menuGroup = 'G',
                                     menuSubgroup = NULL, menuTitle = mt,
                                     menuSubtitle = NULL))
    mk_mod <- function(name, an) list(name = name, title = name, analyses = an)

    jmv_mod <- mk_mod('jmv', mk_an('JmvAnalysisWithALongTitleToMakeThisBlockBig'))
    mod_a   <- mk_mod('moda', mk_an('T'))
    mod_b   <- mk_mod('modb', mk_an('T'))
    mod_c   <- mk_mod('modc', mk_an('T'))
    mod_d   <- mk_mod('modd', mk_an('T'))

    catalog <- list(modules = list(jmv_mod, mod_a, mod_b, mod_c, mod_d), errors = character(0))

    full <- catalog_text(catalog, char_budget = 100000)
    blocks <- strsplit(full, '\n\n', fixed = TRUE)[[1]]
    len_jmv   <- count_chars(blocks[1])
    len_other <- count_chars(blocks[2])   # moda..modd 皆同長

    # (a) 預算只夠 jmv + 1 個其他模組區塊 + 尾標
    marker3 <- '[+3 more modules omitted]'
    budget_a <- len_jmv + 2 + len_other + 2 + count_chars(marker3)
    out_a <- catalog_text(catalog, char_budget = budget_a)
    blocks_a <- strsplit(out_a, '\n\n', fixed = TRUE)[[1]]

    expect_equal(length(blocks_a), 3)
    expect_true(startsWith(blocks_a[1], 'jmv ('))
    expect_true(startsWith(blocks_a[2], 'moda ('))
    expect_equal(blocks_a[3], marker3)
    expect_false(grepl('modb (', out_a, fixed = TRUE))   # 不納入半塊/後續模組

    # (b) 預算小於 jmv 區塊本身長度 -> jmv 仍完整保留(唯一允許超 budget 情形)
    budget_b <- len_jmv - 1
    out_b <- catalog_text(catalog, char_budget = budget_b)
    blocks_b <- strsplit(out_b, '\n\n', fixed = TRUE)[[1]]

    expect_equal(length(blocks_b), 2)
    expect_identical(blocks_b[1], blocks[1])              # jmv 區塊完整無截斷
    expect_equal(blocks_b[2], '[+4 more modules omitted]')
})

# ---- S6:壞目錄/壞 yaml 降級(scan_modules 部分)-----------------------------

test_that('scan_modules skips missing dirs', {
    modules_a   <- test_path('fixtures', 'modules', 'a')
    missing_dir <- test_path('fixtures', 'modules', 'does-not-exist')

    res <- scan_modules(dirs = c(missing_dir, modules_a))

    names_found <- vapply(res$modules, function(m) m$name, character(1))
    expect_setequal(names_found, c('alpha', 'jmv'))
    expect_equal(res$errors, character(0))
})

test_that('scan_modules records broken yaml in errors', {
    modules_broken <- test_path('fixtures', 'modules', 'broken')

    res <- scan_modules(dirs = modules_broken)

    expect_equal(length(res$modules), 0)
    expect_equal(length(res$errors), 1)
    expect_true(grepl('badmod', res$errors[1], fixed = TRUE))
    expect_true(grepl('jamovi.yaml', res$errors[1], fixed = TRUE))
})

# ---- S10:目錄解析多信號 -----------------------------------------------------

test_that('default dirs resolve relative env path', {
    env_home     <- test_path('fixtures', 'modules', 'env-home')
    appdata_root <- test_path('fixtures', 'modules', 'appdata-root')
    libpath_root <- test_path('fixtures', 'modules', 'libpath-root')
    lib_r_dir    <- file.path(libpath_root, 'modules', 'x', 'R')

    withr::local_envvar(c(
        JAMOVI_MODULES_PATH = 'rel',
        JAMOVI_HOME          = env_home,
        APPDATA               = appdata_root
    ))
    testthat::local_mocked_bindings(
        .askllm_lib_paths = function() lib_r_dir,
        .askllm_pkg_path  = function() ''   # 中性化自我定位信號,避免受實際安裝路徑干擾
    )

    dirs <- default_module_dirs()

    expect_true(all(dir.exists(dirs)))
    expect_equal(length(dirs), length(unique(dirs)))

    expect_true(normalizePath(file.path(env_home, 'rel'), winslash = '/', mustWork = TRUE) %in% dirs)
    expect_true(normalizePath(file.path(libpath_root, 'modules'), winslash = '/', mustWork = TRUE) %in% dirs)
    expect_true(normalizePath(file.path(appdata_root, 'jamovi', 'modules'), winslash = '/', mustWork = TRUE) %in% dirs)

    # dirs 非 NULL 時,scan_modules() 的注入覆寫不經過 default_module_dirs()
    called <- FALSE
    testthat::local_mocked_bindings(.askllm_lib_paths = function() { called <<- TRUE; character(0) })
    scan_modules(dirs = character(0))
    expect_false(called)
})

# ---- S11:自我定位信號 -------------------------------------------------------

test_that('self-location derives modules root', {
    root <- test_path('fixtures', 'modules', 'self-location')
    fake_pkg_path <- file.path(root, 'modules', 'askLLM', 'R', 'askLLM')

    withr::local_envvar(c(JAMOVI_MODULES_PATH = '', JAMOVI_HOME = '', APPDATA = ''))

    # (a) 自我定位讀到 <root>/modules/askLLM/R/askLLM -> 收入 <root>/modules
    testthat::local_mocked_bindings(
        .askllm_pkg_path  = function() fake_pkg_path,
        .askllm_lib_paths = function() character(0)
    )
    dirs_a <- default_module_dirs()
    expect_true(normalizePath(file.path(root, 'modules'), winslash = '/', mustWork = TRUE) %in% dirs_a)

    # (b) 自我定位讀到一般 library 安裝路徑 -> 此信號不產生路徑,亦無 error/warning
    testthat::local_mocked_bindings(
        .askllm_pkg_path  = function() file.path(root, 'lib', 'askLLM'),
        .askllm_lib_paths = function() character(0)
    )
    expect_no_error(dirs_b <- default_module_dirs())
    expect_false(normalizePath(file.path(root, 'modules'), winslash = '/', mustWork = TRUE) %in% dirs_b)
})

# ---- S12:available 排除已安裝(不分大小寫)----------------------------------

test_that('available_text excludes installed (case-insensitive)', {
    known <- yaml::read_yaml(test_path('fixtures', 'modules', 'known-modules-abc.yaml'))

    # (a) 排除 alpha,剩 Beta、Gamma,radix 序
    out_a <- available_text(known, c('alpha'))
    lines_a <- strsplit(out_a, '\n', fixed = TRUE)[[1]]
    expect_equal(length(lines_a), 2)
    expect_true(startsWith(lines_a[1], '- Beta ('))
    expect_true(startsWith(lines_a[2], '- Gamma ('))
    expect_false(grepl('Alpha (', out_a, fixed = TRUE))

    # (b) 全部已裝 -> NULL
    out_b <- available_text(known, c('alpha', 'BETA', 'gamma'))
    expect_null(out_b)

    # (c) known 為 NULL -> NULL
    out_c <- available_text(NULL, c('x'))
    expect_null(out_c)
})

# ---- S14:known-modules.yaml schema 驗證 ------------------------------------

test_that('known-modules yaml is valid', {
    path <- system.file('catalog', 'known-modules.yaml', package = 'askLLM')
    if (!nzchar(path))
        path <- file.path('..', '..', 'inst', 'catalog', 'known-modules.yaml')

    if (!file.exists(path)) {
        skip('inst/catalog/known-modules.yaml 尚未由平行任務(sync-known-modules)產出,略過')
    }

    known <- yaml::read_yaml(path)

    expect_true(is.character(known$source_url) && length(known$source_url) == 1 && nzchar(known$source_url))
    expect_true(grepl('^\\d{4}-\\d{2}-\\d{2}$', known$retrieved_date))

    modules <- known$modules
    expect_true(is.list(modules) && length(modules) > 0)

    names_all <- character(0)
    for (m in modules) {
        expect_true(all(c('name', 'title', 'provides', 'tags') %in% names(m)))
        expect_true(is.character(m$name) && nzchar(m$name))
        expect_true(is.character(m$title) && nzchar(m$title))
        expect_true(is.character(m$provides) && nzchar(m$provides))
        expect_true(count_chars(m$provides) <= 160)
        expect_true(length(m$tags) == 0 || is.character(m$tags))
        names_all <- c(names_all, tolower(m$name))
    }
    expect_equal(length(names_all), length(unique(names_all)))
})
