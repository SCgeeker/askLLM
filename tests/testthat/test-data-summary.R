# test-data-summary.R
# 測試 summarize_data() 與 count_chars():統計正確性、型態處理、
# 截斷、edge cases、budget 控制、決定性、中文不亂碼。

# ---- count_chars ----------------------------------------------------------

test_that('count_chars 以「字元數」計(中文一字算一)', {
    expect_equal(count_chars('abc'), 3)
    expect_equal(count_chars('變項名稱'), 4)      # 4 個中文字 = 4 chars
    expect_true(count_chars('變項名稱') < nchar('變項名稱', type = 'bytes'))
})

# ---- 表頭 -----------------------------------------------------------------

test_that('表頭格式:Dataset: N rows. Variables described: k.', {
    out <- summarize_data(iris, c('Sepal.Length', 'Species'))
    expect_true(grepl('Dataset: 150 rows. Variables described: 2.', out, fixed = TRUE))
})

# ---- numeric 統計正確性 ---------------------------------------------------

test_that('numeric 段每個統計量正確(iris$Sepal.Length,signif 4)', {
    out <- summarize_data(iris, 'Sepal.Length')
    expect_true(grepl('n: 150', out, fixed = TRUE))
    expect_true(grepl('missing: 0', out, fixed = TRUE))
    expect_true(grepl('mean: 5.843', out, fixed = TRUE))
    expect_true(grepl('sd: 0.8281', out, fixed = TRUE))
    expect_true(grepl('median: 5.8', out, fixed = TRUE))
    expect_true(grepl('min: 4.3', out, fixed = TRUE))
    expect_true(grepl('max: 7.9', out, fixed = TRUE))
})

test_that('integer 欄視為 numeric 統計', {
    df <- data.frame(k = 1:10L)
    out <- summarize_data(df, 'k')
    expect_true(grepl('mean: 5.5', out, fixed = TRUE))
    expect_true(grepl('integer', out, fixed = TRUE))
})

test_that('缺失值以 na.rm 計算,missing 計數正確', {
    df <- data.frame(x = c(1, 2, 3, NA, NA))
    out <- summarize_data(df, 'x')
    expect_true(grepl('n: 3', out, fixed = TRUE))
    expect_true(grepl('missing: 2', out, fixed = TRUE))
    expect_true(grepl('mean: 2', out, fixed = TRUE))
})

# ---- factor ---------------------------------------------------------------

test_that('factor 次數降冪 name(count)', {
    df <- data.frame(g = factor(c('b', 'b', 'b', 'a', 'a', 'c')))
    out <- summarize_data(df, 'g')
    expect_true(grepl('3 levels', out, fixed = TRUE))
    # b(3) 在 a(2) 前、a(2) 在 c(1) 前
    expect_true(regexpr('b(3)', out, fixed = TRUE) <
                regexpr('a(2)', out, fixed = TRUE))
    expect_true(regexpr('a(2)', out, fixed = TRUE) <
                regexpr('c(1)', out, fixed = TRUE))
})

test_that('factor 超過 max_levels 併為 ... and J more levels', {
    df <- data.frame(g = factor(paste0('L', sprintf('%02d', 1:12))))
    out <- summarize_data(df, 'g', max_levels = 10)
    expect_true(grepl('12 levels', out, fixed = TRUE))
    expect_true(grepl('... and 2 more levels', out, fixed = TRUE))
})

test_that('水準名超過 40 字元截斷並附 …', {
    long <- paste(rep('x', 50), collapse = '')
    df <- data.frame(g = factor(c(long, 'short')))
    out <- summarize_data(df, 'g')
    cap40 <- paste(rep('x', 40), collapse = '')
    expect_true(grepl(paste0(cap40, '…'), out, fixed = TRUE))  # 40x + …
    expect_false(grepl(long, out, fixed = TRUE))                    # 完整 50x 不出現
})

test_that('ordered factor 標註 (ordered) 並列 level order(原順序)', {
    df <- data.frame(g = ordered(c('mid', 'lo', 'hi', 'lo'),
                                 levels = c('lo', 'mid', 'hi')))
    out <- summarize_data(df, 'g')
    expect_true(grepl('ordered', out, fixed = TRUE))
    expect_true(grepl('level order: lo < mid < hi', out, fixed = TRUE))
})

test_that('factor 含 NA 水準(addNA)不炸並計入', {
    f <- addNA(factor(c('a', 'b', NA, 'a')))
    df <- data.frame(g = f)
    expect_error(summarize_data(df, 'g'), NA)
    out <- summarize_data(df, 'g')
    expect_true(grepl('NA(1)', out, fixed = TRUE))
})

# ---- character ------------------------------------------------------------

test_that('character 報 distinct 數與 top 值(次數降冪)', {
    df <- data.frame(s = c('cat', 'cat', 'dog', 'bird'),
                     stringsAsFactors = FALSE)
    out <- summarize_data(df, 's')
    expect_true(grepl('character', out, fixed = TRUE))
    expect_true(grepl('3 distinct', out, fixed = TRUE))
    expect_true(grepl('cat(2)', out, fixed = TRUE))
})

# ---- logical --------------------------------------------------------------

test_that('logical 報 TRUE/FALSE/NA 三計數', {
    df <- data.frame(b = c(TRUE, TRUE, FALSE, NA, TRUE))
    out <- summarize_data(df, 'b')
    expect_true(grepl('logical', out, fixed = TRUE))
    expect_true(grepl('TRUE: 3', out, fixed = TRUE))
    expect_true(grepl('FALSE: 1', out, fixed = TRUE))
    expect_true(grepl('NA: 1', out, fixed = TRUE))
})

# ---- 其他型態 (Date) ------------------------------------------------------

test_that('Date 型態報 type/n/missing', {
    df <- data.frame(d = as.Date(c('2020-01-01', '2020-02-01', NA)))
    out <- summarize_data(df, 'd')
    expect_true(grepl('type: Date', out, fixed = TRUE))
    expect_true(grepl('n: 2', out, fixed = TRUE))
    expect_true(grepl('missing: 1', out, fixed = TRUE))
})

# ---- edge cases -----------------------------------------------------------

test_that('全 NA 數值欄:n 0、統計顯示 NA、不炸', {
    df <- data.frame(x = c(NA_real_, NA_real_, NA_real_))
    expect_error(summarize_data(df, 'x'), NA)
    out <- summarize_data(df, 'x')
    expect_true(grepl('n: 0', out, fixed = TRUE))
    expect_true(grepl('mean: NA', out, fixed = TRUE))
    expect_false(grepl('NaN', out, fixed = TRUE))
    expect_false(grepl('Inf', out, fixed = TRUE))
})

test_that('零變異欄:sd 顯示 0', {
    df <- data.frame(x = c(4, 4, 4, 4))
    out <- summarize_data(df, 'x')
    expect_true(grepl('sd: 0', out, fixed = TRUE))
})

test_that('單一觀測:sd 顯示 NA 不炸', {
    df <- data.frame(x = 42)
    expect_error(summarize_data(df, 'x'), NA)
    out <- summarize_data(df, 'x')
    expect_true(grepl('n: 1', out, fixed = TRUE))
    expect_true(grepl('sd: NA', out, fixed = TRUE))
})

test_that('零列 df 不炸', {
    df <- data.frame(x = numeric(0), g = factor(character(0)))
    expect_error(summarize_data(df, c('x', 'g')), NA)
    out <- summarize_data(df, c('x', 'g'))
    expect_true(grepl('Dataset: 0 rows', out, fixed = TRUE))
})

test_that('空 vars 回傳 No variables selected.', {
    expect_equal(summarize_data(iris, character(0)), 'No variables selected.')
})

test_that('vars 含不存在欄名:跳過並在尾註記', {
    out <- summarize_data(iris, c('Sepal.Length', 'NoSuch', 'AlsoMissing'))
    expect_true(grepl('Sepal.Length', out, fixed = TRUE))
    expect_true(grepl('Variables described: 1.', out, fixed = TRUE))
    expect_true(grepl('[skipped missing: NoSuch, AlsoMissing]', out, fixed = TRUE))
})

# ---- budget ---------------------------------------------------------------

test_that('縮小 budget:出現截斷標記且總長 <= budget*1.1', {
    out <- summarize_data(iris, names(iris), char_budget = 300)
    expect_true(grepl('[summary truncated to fit budget]', out, fixed = TRUE))
    expect_true(count_chars(out) <= 300 * 1.1)
})

test_that('寬鬆 budget:不出現截斷標記', {
    out <- summarize_data(iris, c('Sepal.Length'), char_budget = 4000)
    expect_false(grepl('[summary truncated to fit budget]', out, fixed = TRUE))
})

# ---- 決定性 ---------------------------------------------------------------

test_that('同輸入兩次呼叫 identical', {
    a <- summarize_data(iris, names(iris))
    b <- summarize_data(iris, names(iris))
    expect_identical(a, b)
    # budget 路徑也決定性
    c1 <- summarize_data(iris, names(iris), char_budget = 300)
    c2 <- summarize_data(iris, names(iris), char_budget = 300)
    expect_identical(c1, c2)
})

# ---- 中文不亂碼 -----------------------------------------------------------

test_that('中文欄名/水準名正確呈現不亂碼', {
    df <- data.frame(
        年齡 = c(20, 25, 30, NA),
        性別 = factor(c('男', '女', '女', '男')))
    out <- summarize_data(df, c('年齡', '性別'))
    expect_true(grepl('年齡', out, fixed = TRUE))
    expect_true(grepl('性別', out, fixed = TRUE))
    expect_true(grepl('女(2)', out, fixed = TRUE))
    expect_true(grepl('男(2)', out, fixed = TRUE))
})
