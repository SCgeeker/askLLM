# test-eval-score.R — v1.4 項目 F:評分純函式與 golden set schema(全部離線)

# ---- 路徑抽取(自 tools/compare-models.R 搬入套件,行為鎖定)------------------

test_that('.askllm_extract_paths 抽取 Analyses > ... 並去除粗體/描述/尾標點', {
    txt <- paste(
        'Use **Analyses > ANOVA > One-Way ANOVA** to compare groups.',
        '1. `Analyses > Exploration > Descriptives` - check distributions',
        'Then Analyses > T-Tests > Independent Samples T-Test: tick Welch.',
        'No path on this line.',
        sep = '\n')
    p <- .askllm_extract_paths(txt)
    expect_setequal(p, c('Analyses > ANOVA > One-Way ANOVA',
                         'Analyses > Exploration > Descriptives',
                         'Analyses > T-Tests > Independent Samples T-Test'))
    expect_equal(.askllm_extract_paths(NULL), character(0))
    expect_equal(.askllm_extract_paths(''), character(0))
})

test_that('.askllm_legal_paths 由 scan 結果重建路徑(含 subgroup)', {
    scanned <- list(modules = list(
        list(name = 'jmv', analyses = list(
            list(menuGroup = 'ANOVA', menuSubgroup = NULL, menuTitle = 'ANOVA'),
            list(menuGroup = 'Frequencies', menuSubgroup = 'Contingency Tables',
                 menuTitle = 'Independent Samples')))))
    lp <- .askllm_legal_paths(scanned)
    expect_setequal(lp, c('Analyses > ANOVA > ANOVA',
                          'Analyses > Frequencies > Contingency Tables > Independent Samples'))
    expect_equal(.askllm_legal_paths(NULL), character(0))
})

test_that('.askllm_check_path_hits 命中/未命中計數', {
    lp <- c('Analyses > ANOVA > ANOVA')
    h <- .askllm_check_path_hits('Go to Analyses > ANOVA > ANOVA. Or Analyses > Fake > Menu.', lp)
    expect_equal(h$total, 2L)
    expect_equal(h$hits, 1L)
    expect_equal(h$misses, 'Analyses > Fake > Menu')
})

# ---- 關鍵字 ---------------------------------------------------------------------

test_that('.askllm_kw_hit 不分大小寫,| 為替代字,固定字串非 regex', {
    expect_true(.askllm_kw_hit('Run an ANOVA here', 'anova'))
    expect_true(.askllm_kw_hit('use a t test', 't-test|t test'))
    expect_false(.askllm_kw_hit('nothing', 't-test|t test'))
    expect_true(.askllm_kw_hit('call lm(mpg ~ hp)', 'lm('))      # 括號不是 regex
    expect_false(.askllm_kw_hit('x', ''))
})

# ---- 評分 -------------------------------------------------------------------------

test_that('score_answer:全部命中 → 100;各分項正確', {
    txt <- 'Run a one-way ANOVA: Analyses > ANOVA > One-Way ANOVA. Check normality first.'
    ex <- list(must_mention = c('ANOVA|analysis of variance', 'normality'),
               must_not = c('Machine Learning'),
               paths_expected = TRUE)
    sc <- .askllm_score_answer(txt, ex, legal_paths = 'Analyses > ANOVA > One-Way ANOVA')
    expect_equal(sc$score, 100)
    expect_equal(unname(sc$components[c('keywords', 'forbidden_free', 'paths')]), c(1, 1, 1))
    expect_length(sc$warnings, 0)
})

test_that('score_answer:缺關鍵字、禁用字、路徑未命中各自扣分並產生警示', {
    txt <- 'Use Machine Learning > Classifier via Analyses > Fake > Menu.'
    ex <- list(must_mention = c('ANOVA', 'normality'),
               must_not = c('Machine Learning'),
               paths_expected = TRUE)
    sc <- .askllm_score_answer(txt, ex, legal_paths = 'Analyses > ANOVA > ANOVA')
    expect_equal(sc$score, 0)
    expect_setequal(sc$keyword_missing, c('ANOVA', 'normality'))
    expect_equal(sc$forbidden_hits, 'Machine Learning')
    expect_equal(sc$path$misses, 'Analyses > Fake > Menu')
    expect_true(any(grepl('forbidden', sc$warnings)))
    expect_true(any(grepl('path miss', sc$warnings)))
})

test_that('score_answer:legal_paths 為空時跳過路徑分項(工具在 jamovi 外執行)', {
    sc <- .askllm_score_answer('Analyses > Whatever > X', list(paths_expected = TRUE),
                               legal_paths = character(0))
    expect_true(is.na(sc$score))
    expect_false('paths' %in% names(sc$components))
})

test_that('score_answer:redirect 依 analysis 推得預設目標', {
    g <- .askllm_score_answer('Please use the R code tutor analysis instead.',
                              list(redirect_expected = TRUE), analysis = 'askllm')
    expect_true(g$redirect_ok); expect_equal(g$score, 100)
    r <- .askllm_score_answer('Try jamovi Module Guider for menu paths.',
                              list(redirect_expected = TRUE), analysis = 'askllmr')
    expect_true(r$redirect_ok)
    bad <- .askllm_score_answer('Here is code: aov(...)', list(redirect_expected = TRUE))
    expect_false(bad$redirect_ok); expect_equal(bad$score, 0)
})

test_that('score_answer:code_expected 看 fenced block;空回覆全數不通過', {
    ok <- .askllm_score_answer("```r\nlm(mpg ~ hp, data)\n```", list(code_expected = TRUE))
    expect_true(ok$code_ok)
    no <- .askllm_score_answer('lm(mpg ~ hp, data)', list(code_expected = TRUE))
    expect_false(no$code_ok)
    empty <- .askllm_score_answer(NULL, list(must_mention = 'x', code_expected = TRUE))
    expect_equal(empty$score, 0)
})

test_that('score_answer:無規則 → score NA、無警示;決定性', {
    a <- .askllm_score_answer('anything', list())
    expect_true(is.na(a$score)); expect_length(a$warnings, 0)
    ex <- list(must_mention = 'a', must_not = 'b')
    expect_identical(.askllm_score_answer('a', ex), .askllm_score_answer('a', ex))
})

# ---- golden set 載入與 schema --------------------------------------------------

.golden_path <- file.path('..', '..', 'tools', 'golden', 'golden-set.yaml')

test_that('隨附 golden set 通過 schema 驗證,且每題規則非空', {
    g <- .askllm_load_golden(.golden_path)
    expect_true(g$ok, info = paste(g$errors, collapse = '\n'))
    expect_gte(length(g$items), 10)
    for (it in g$items) {
        expect_true(length(it$expect) > 0, info = it$id)
        expect_true(it$analysis %in% c('askllm', 'askllmr'), info = it$id)
    }
    # 兩個分析都有題;兩個方向的 redirect 各至少一題
    an <- vapply(g$items, `[[`, character(1), 'analysis')
    expect_true(all(c('askllm', 'askllmr') %in% an))
    redirect <- vapply(g$items, function(it) isTRUE(it$expect$redirect_expected), logical(1))
    expect_true(any(redirect & an == 'askllm'))
    expect_true(any(redirect & an == 'askllmr'))
})

test_that('load_golden:缺檔、壞 YAML、未知欄位、重複 id、壞資料集/變數 皆回 errors 不 stop', {
    expect_false(.askllm_load_golden(file.path(tempdir(), 'nope.yaml'))$ok)

    bad <- tempfile(fileext = '.yaml')
    writeLines(c(
        'items:',
        '  - id: a',
        '    analysis: askllm',
        '    dataset: iris',
        '    vars: [Sepal.Length, NoSuchVar]',
        '    question: q',
        '    bogus: 1',
        '    expect: {must_mention: [x], nope: 1}',
        '  - id: a',
        '    analysis: other',
        '    dataset: not_a_dataset',
        '    question: ""'), bad)
    g <- .askllm_load_golden(bad)
    expect_false(g$ok)
    expect_true(any(grepl('unknown field', g$errors)))
    expect_true(any(grepl('NoSuchVar', g$errors)))
    expect_true(any(grepl('unknown expect field', g$errors)))
    expect_true(any(grepl('duplicate id', g$errors)))
    expect_true(any(grepl('analysis must be', g$errors)))
    expect_true(any(grepl('unknown dataset', g$errors)))
    expect_true(any(grepl('empty question', g$errors)))

    broken <- tempfile(fileext = '.yaml')
    writeLines('items: [', broken)
    expect_false(.askllm_load_golden(broken)$ok)
})

test_that('.askllm_golden_dataset 只回傳 datasets:: 的 data.frame', {
    expect_true(is.data.frame(.askllm_golden_dataset('iris')))
    expect_null(.askllm_golden_dataset('no_such_dataset_xyz'))
    expect_null(.askllm_golden_dataset('euro'))   # 存在但是 numeric 向量
    expect_null(.askllm_golden_dataset(''))
})
