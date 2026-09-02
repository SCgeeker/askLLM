# test-rj-caveat-lines.R — .askllm_rj_caveat_lines(has_rj_env) 純函式測試
#
# 對應 dev-notes/r-tutor-bridge-plan.zh-TW.md §1.3:從 M-R1 的
# .askllm_caveat_text() 抽出的 rj 三態邏輯(未執行提醒 + TRUE/FALSE/NA 兩態句),
# 暫留在 askllm.b.R(M-A1 才搬到 r-tutor.R)。此刻諮詢分析不呼叫此函式,
# 但保留供未來 R code tutor(askllmr)重用,故離線單元測試先行覆蓋三態。
#
# 回傳 list(en = <chr>, zh = <chr>)。

test_that('rj_caveat_lines: has_rj_env=NA 時只有「未執行」提醒,無兩態句', {
    out <- .askllm_rj_caveat_lines(NA)

    expect_type(out, 'list')
    expect_true(all(c('en', 'zh') %in% names(out)))

    expect_true(any(grepl('NOT executed', out$en, fixed = TRUE)))
    expect_true(any(grepl('並未由 askLLM 執行', out$zh, fixed = TRUE)))

    expect_false(any(grepl('grounded', out$en, ignore.case = TRUE)))
    expect_false(any(grepl('接地', out$zh, fixed = TRUE)))
    expect_false(any(grepl('No Rj environment', out$en, fixed = TRUE)))
    expect_false(any(grepl('未附上 Rj 環境', out$zh, fixed = TRUE)))
})

test_that('rj_caveat_lines: has_rj_env=TRUE 時附加「已接地」句', {
    out <- .askllm_rj_caveat_lines(TRUE)

    expect_true(any(grepl('NOT executed', out$en, fixed = TRUE)))
    expect_true(any(grepl('grounded', out$en, ignore.case = TRUE)))
    expect_true(any(grepl('接地', out$zh, fixed = TRUE)))
})

test_that('rj_caveat_lines: has_rj_env=FALSE 時附加「未附上 Rj 環境」句', {
    out <- .askllm_rj_caveat_lines(FALSE)

    expect_true(any(grepl('NOT executed', out$en, fixed = TRUE)))
    expect_true(any(grepl('No Rj environment', out$en, fixed = TRUE)))
    expect_true(any(grepl('未附上 Rj 環境', out$zh, fixed = TRUE)))
})

test_that('rj_caveat_lines: 三態彼此互斥(TRUE 不含 FALSE 句、FALSE 不含 TRUE 句)', {
    on  <- .askllm_rj_caveat_lines(TRUE)
    off <- .askllm_rj_caveat_lines(FALSE)

    expect_false(any(grepl('No Rj environment', on$en, fixed = TRUE)))
    expect_false(any(grepl('未附上 Rj 環境', on$zh, fixed = TRUE)))

    expect_false(any(grepl('grounded', off$en, ignore.case = TRUE)))
    expect_false(any(grepl('接地', off$zh, fixed = TRUE)))
})
