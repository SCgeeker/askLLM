# test-strip-fences.R — 對應 dev-notes/r-tutor-bridge-plan.zh-TW.md「構件 4」
#
# .askllm_strip_fences(text):純函式,把 ``` 圍欄行(含語言標記,如 ```r)
# 改為空行,保留內部縮排,讓 Preformatted 顯示乾淨;無圍欄輸入原樣返回。

test_that('strip_fences:無語言標記的圍欄改為空行,內容保留', {
    input <- '```\nx <- 1\ny <- 2\n```'
    out <- .askllm_strip_fences(input)

    expect_false(grepl('```', out, fixed = TRUE))
    expect_true(grepl('x <- 1', out, fixed = TRUE))
    expect_true(grepl('y <- 2', out, fixed = TRUE))
})

test_that('strip_fences:有語言標記(```r)的圍欄也改為空行', {
    input <- '```r\nx <- 1\n```'
    out <- .askllm_strip_fences(input)

    expect_false(grepl('```', out, fixed = TRUE))
    expect_true(grepl('x <- 1', out, fixed = TRUE))
})

test_that('strip_fences:巢狀縮排的圍欄與內容,內容縮排不受影響', {
    input <- '- step 1\n  ```r\n  x <- 1\n    y <- 2\n  ```\n- step 2'
    out <- .askllm_strip_fences(input)

    expect_false(grepl('```', out, fixed = TRUE))
    expect_true(grepl('  x <- 1', out, fixed = TRUE))       # 內容縮排原樣保留
    expect_true(grepl('    y <- 2', out, fixed = TRUE))     # 巢狀更深的縮排也保留
    expect_true(grepl('- step 1', out, fixed = TRUE))
    expect_true(grepl('- step 2', out, fixed = TRUE))
})

test_that('strip_fences:無圍欄輸入原樣返回', {
    input <- 'plain text\nwith multiple lines\nno fences here'
    expect_identical(.askllm_strip_fences(input), input)
})

test_that('strip_fences:多個 code block 都被處理', {
    input <- paste(
        'First block:', '```r', 'a <- 1', '```', '',
        'Second block:', '```', 'b <- 2', '```',
        sep = '\n')
    out <- .askllm_strip_fences(input)

    expect_false(grepl('```', out, fixed = TRUE))
    expect_true(grepl('a <- 1', out, fixed = TRUE))
    expect_true(grepl('b <- 2', out, fixed = TRUE))
    expect_true(grepl('First block:', out, fixed = TRUE))
    expect_true(grepl('Second block:', out, fixed = TRUE))
})

test_that('strip_fences:對 NULL 輸入不炸,回傳 NULL', {
    expect_null(.askllm_strip_fences(NULL))
})

test_that('strip_fences:對空字串不炸', {
    expect_identical(.askllm_strip_fences(''), '')
})

test_that('strip_fences:圍欄前後有空白也視為圍欄行', {
    input <- '```r  \ncode()\n  ```'
    out <- .askllm_strip_fences(input)
    expect_false(grepl('```', out, fixed = TRUE))
    expect_true(grepl('code()', out, fixed = TRUE))
})
