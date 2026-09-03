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

# ---- Module Guider 精簡:a.yaml 選項集合不再含 enableActions/llmColumns/systemPrompt ----
#
# 對應「Module Guider 精簡 + 雙向 prompt 邊界」規劃:UI 撤掉 Enable actions 與
# Custom system prompt(底層 acting 程式碼原樣保留於 R/action-*.R 等檔案,
# 只是不再有選項驅動它們)。

test_that('M-精簡: jamovi/askllm.a.yaml 選項集合不再含 enableActions/llmColumns/systemPrompt', {
    path <- testthat::test_path('..', '..', 'jamovi', 'askllm.a.yaml')
    a <- yaml::read_yaml(path)
    option_names <- vapply(a$options, function(o) o$name %||% '', character(1))
    expect_false('enableActions' %in% option_names)
    expect_false('llmColumns' %in% option_names)
    expect_false('systemPrompt' %in% option_names)
    # systemPromptVar(變數 Description 通道)不受影響,仍應保留
    expect_true('systemPromptVar' %in% option_names)
})

test_that('M-精簡: jamovi/askllm.u.yaml 不再含 enableActions CheckBox / systemPrompt TextBox', {
    path <- testthat::test_path('..', '..', 'jamovi', 'askllm.u.yaml')
    txt <- paste(readLines(path, warn = FALSE), collapse = '\n')
    expect_false(grepl('name: enableActions', txt, fixed = TRUE))
    expect_false(grepl('name: systemPrompt\n', txt, fixed = TRUE))
})

test_that('M-精簡: R/askllm.b.R .runInner() 不再有 opt$enableActions 動作分支,但底層 acting 純函式原樣保留', {
    path <- testthat::test_path('..', '..', 'R', 'askllm.b.R')
    lines <- readLines(path, warn = FALSE)
    expect_false(any(grepl('opt\\$enableActions|opt\\$systemPrompt\\b', lines)))

    # 底層 acting 實作(休眠備用)不得被刪除:action-*.R 檔案仍在、
    # .askllm_fill_output/.ASKLLM_ACTION_SUFFIX/enable_actions 參數本體仍在
    expect_true(file.exists(testthat::test_path('..', '..', 'R', 'action-exec.R')))
    expect_true(exists('.askllm_fill_output'))
    expect_true(exists('.ASKLLM_ACTION_SUFFIX'))
    expect_true('enable_actions' %in% names(formals(.askllm_system_prompt)))
})
