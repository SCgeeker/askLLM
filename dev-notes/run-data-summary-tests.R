# 自製 runner:載入套件原始碼後單獨跑 data-summary 測試
# 用法:Rscript dev-notes/run-data-summary-tests.R
options(encoding = 'UTF-8')
suppressMessages(pkgload::load_all(
    file.path('D:', 'core', 'LAB', 'Analysis', 'jmv_modules', 'askLLM'),
    quiet = TRUE, export_all = TRUE, attach_testthat = TRUE))
res <- testthat::test_file(
    file.path('D:', 'core', 'LAB', 'Analysis', 'jmv_modules', 'askLLM',
              'tests', 'testthat', 'test-data-summary.R'),
    reporter = testthat::SummaryReporter$new())
df <- as.data.frame(res)
cat(sprintf('\nFAIL=%d  WARN=%d  SKIP=%d  PASS=%d\n',
    sum(df$failed), sum(df$warning), sum(df$skipped), sum(df$passed)))
if (sum(df$failed) > 0) quit(status = 1)
