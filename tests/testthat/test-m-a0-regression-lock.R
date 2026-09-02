# test-m-a0-regression-lock.R — M-A0 退場里程碑的回歸鎖 L5、L6
#
# 對應 dev-notes/r-tutor-bridge-plan.zh-TW.md §1.2:
# L5:R/askllm.b.R 原始碼不再出現 opt$rCode / rj_env_text / r_code 任一字樣
# L6:jamovi/askllm.a.yaml 選項集合不再含 rCode
#
# 皆為廉價的 source-scan 測試,防止日後不慎又把 R-code 意圖接回諮詢分析。

test_that('L5: R/askllm.b.R 原始碼不再引用 opt$rCode / rj_env_text / r_code', {
    path <- testthat::test_path('..', '..', 'R', 'askllm.b.R')
    lines <- readLines(path, warn = FALSE)
    expect_false(any(grepl('opt\\$rCode|rj_env_text|r_code', lines)))
})

test_that('L6: jamovi/askllm.a.yaml 選項集合不再含 rCode', {
    path <- testthat::test_path('..', '..', 'jamovi', 'askllm.a.yaml')
    a <- yaml::read_yaml(path)
    option_names <- vapply(a$options, function(o) o$name %||% '', character(1))
    expect_false('rCode' %in% option_names)
})
