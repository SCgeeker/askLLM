# test-action-output.R — Phase 2:.askllm_fill_output() 把計算欄寫回 jmvcore Output
#
# 契約:.askllm_fill_output(option, output, cc, rownums) — 照 Rj eval 模式:
#   1. option$value <- list(value=TRUE, ...) 啟用(否則 output$enabled=FALSE,
#      app 忽略 → 不建欄;此為 20260803 E2E「無計算欄」的根因)
#   2. output$set(keys, titles, descriptions, measureTypes) — 皆「字元」向量
#   3. output$setValues(key=<字元>, value) 逐欄
#   4. output$setRowNums(整數 rownums)
#   cc:exec_action 成功的 compute_column 結果清單。純函式(對注入的 R6 物件)。
#
# 用真 jmvcore Output(headless 可建構,Rj 的 eval 已證)直測。

skip_if_not_installed('jmvcore')

.mk_opt_out <- function() {
    opt <- jmvcore::OptionOutput$new('llmColumns')   # 預設 value=FALSE(bug 狀態)
    options <- jmvcore::Options$new(); options$.addOption(opt)
    out <- jmvcore::Output$new(options, 'llmColumns', initInRun = TRUE)
    list(opt = opt, out = out)
}

test_that('.askllm_fill_output 啟用 Output 並填值(enabled/isFilled)', {
    oo <- .mk_opt_out()
    expect_false(oo$out$enabled)                       # 前:未啟用(=E2E bug)
    cc <- list(
        list(column_name = 'dbl', measure_type = 'continuous',
             rationale = 'double', value = c(2, 4, 6)),
        list(column_name = 'sq', measure_type = 'continuous',
             rationale = 'square', value = c(1, 4, 9)))
    .askllm_fill_output(oo$opt, oo$out, cc, rownums = 1:3)
    expect_true(oo$out$enabled)                         # 後:已啟用(修復)
    expect_true(oo$out$isFilled())
})

test_that('.askllm_fill_output 空 cc:不啟用、不報錯', {
    oo <- .mk_opt_out()
    expect_error(.askllm_fill_output(oo$opt, oo$out, list(), rownums = 1:3), NA)
    expect_false(oo$out$enabled)
})

test_that('.askllm_fill_output rownums 含 NA:略過 setRowNums,仍填值不報錯', {
    oo <- .mk_opt_out()
    cc <- list(list(column_name = 'a', measure_type = 'continuous',
                    rationale = 'r', value = c(1, 2, 3)))
    expect_error(
        .askllm_fill_output(oo$opt, oo$out, cc, rownums = c(1L, NA, 3L)), NA)
    expect_true(oo$out$enabled)
})
