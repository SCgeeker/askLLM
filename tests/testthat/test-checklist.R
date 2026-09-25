# test-checklist.R — v1.4 項目 D:「Before you report」後記檢查表(離線)

# ---- system prompt ------------------------------------------------------------

test_that('checklist 預設 FALSE:既有呼叫輸出逐字不變(回歸鎖)', {
    for (role in c('consultant', 'tutor', 'explainer')) for (lang in c('en', 'zh'))
        for (hc in c(TRUE, FALSE)) {
            expect_identical(
                .askllm_system_prompt(role, lang, has_catalog = hc),
                .askllm_system_prompt(role, lang, has_catalog = hc, checklist = FALSE),
                info = paste(role, lang, hc))
            expect_false(grepl('Before you report', .askllm_system_prompt(role, lang, has_catalog = hc),
                               fixed = TRUE))
        }
})

test_that('checklist=TRUE:附加對應語言的檢查表句,且仍以雙向邊界句結尾', {
    en <- .askllm_system_prompt('consultant', 'en', has_catalog = TRUE, checklist = TRUE)
    zh <- .askllm_system_prompt('consultant', 'zh', has_catalog = TRUE, checklist = TRUE)
    expect_true(grepl(.ASKLLM_CHECKLIST_SUFFIX$en, en, fixed = TRUE))
    expect_true(grepl(.ASKLLM_CHECKLIST_SUFFIX$zh, zh, fixed = TRUE))
    expect_false(grepl(.ASKLLM_CHECKLIST_SUFFIX$zh, en, fixed = TRUE))
    # 順序:catalog 約束句 < 檢查表 < 邊界句(邊界句恆在最末)
    expect_true(regexpr(.ASKLLM_CATALOG_SUFFIX$en, en, fixed = TRUE) <
                regexpr(.ASKLLM_CHECKLIST_SUFFIX$en, en, fixed = TRUE))
    expect_true(endsWith(en, .ASKLLM_R_REDIRECT_SUFFIX$en))
    expect_true(endsWith(zh, .ASKLLM_R_REDIRECT_SUFFIX$zh))
    # 基底 = 未開檢查表的版本去掉邊界句
    off <- .askllm_system_prompt('consultant', 'en', has_catalog = TRUE)
    base <- substr(off, 1, nchar(off) - nchar(.ASKLLM_R_REDIRECT_SUFFIX$en) - 1)
    expect_true(startsWith(en, base))
})

test_that('檢查表句內容:四項(前提/效果量/缺失值/樣本數)+ 零捏造規則', {
    for (lang in c('en', 'zh')) {
        s <- .ASKLLM_CHECKLIST_SUFFIX[[lang]]
        expect_true(grepl('Before you report', s, fixed = TRUE), info = lang)
        expect_true(grepl('<installed_analyses>|清單', s), info = lang)
        expect_true(grepl('<summary>', s, fixed = TRUE), info = lang)
    }
    expect_true(grepl('assumption', .ASKLLM_CHECKLIST_SUFFIX$en, fixed = TRUE))
    expect_true(grepl('effect size', .ASKLLM_CHECKLIST_SUFFIX$en, fixed = TRUE))
    expect_true(grepl('missing', .ASKLLM_CHECKLIST_SUFFIX$en, fixed = TRUE))
    expect_true(grepl('sample size', .ASKLLM_CHECKLIST_SUFFIX$en, fixed = TRUE))
    expect_true(grepl('ONLY if it appears literally', .ASKLLM_CHECKLIST_SUFFIX$en, fixed = TRUE))
    expect_true(grepl('前提檢驗', .ASKLLM_CHECKLIST_SUFFIX$zh, fixed = TRUE))
    expect_true(grepl('效果量', .ASKLLM_CHECKLIST_SUFFIX$zh, fixed = TRUE))
    expect_true(grepl('缺失值', .ASKLLM_CHECKLIST_SUFFIX$zh, fixed = TRUE))
    expect_true(grepl('樣本數', .ASKLLM_CHECKLIST_SUFFIX$zh, fixed = TRUE))
})

test_that('custom system prompt 覆蓋 base 時,checklist 仍附加', {
    s <- .askllm_system_prompt('tutor', 'en', system_prompt = 'CUSTOM', checklist = TRUE)
    expect_true(startsWith(s, 'CUSTOM '))
    expect_true(grepl('Before you report', s, fixed = TRUE))
})

# ---- payload 指紋(格式 v1.5)------------------------------------------------------

test_that('build_payload:checklist=FALSE 與舊呼叫逐字相同;TRUE 產生不同 payload', {
    base <- .askllm_build_payload('q', 's', 'http://x', 'm')
    expect_identical(base, .askllm_build_payload('q', 's', 'http://x', 'm', checklist = FALSE))
    on <- .askllm_build_payload('q', 's', 'http://x', 'm', checklist = TRUE)
    expect_false(identical(base, on))
    expect_true(startsWith(on, base))
    expect_identical(on, .askllm_build_payload('q', 's', 'http://x', 'm', checklist = TRUE))
})

# ---- 摘要 skew --------------------------------------------------------------------

test_that('.skewness:對稱 → ~0;右偏 → 正;n<3 或零變異 → NA', {
    expect_equal(.skewness(c(1, 2, 3, 4, 5)), 0)
    expect_true(.skewness(c(1, 1, 1, 1, 10)) > 1)
    expect_true(.skewness(c(-10, 1, 1, 1, 1)) < -1)
    expect_true(is.na(.skewness(c(1, 2))))
    expect_true(is.na(.skewness(c(3, 3, 3, 3))))
    expect_true(is.na(.skewness(c(NA, NA))))
})

test_that('summarize_data numeric 段附 skew;NA 情境顯示 NA;iris 其餘統計量不變', {
    out <- summarize_data(iris, 'Sepal.Length')
    expect_true(grepl(', skew: ', out, fixed = TRUE))
    expect_true(grepl('mean: 5.843', out, fixed = TRUE))
    sk <- as.numeric(sub('.*skew: ([-0-9.]+).*', '\\1', out))
    expect_equal(sk, round(.skewness(iris$Sepal.Length), 4), tolerance = 1e-3)
    expect_true(grepl('skew: NA', summarize_data(data.frame(x = c(4, 4, 4)), 'x'), fixed = TRUE))
    expect_true(grepl('skew: NA', summarize_data(data.frame(x = 42), 'x'), fixed = TRUE))
})

# ---- a.yaml / 接線 ----------------------------------------------------------------

test_that('askllm.a.yaml 有 addChecklist(Bool, default TRUE);R code tutor 沒有', {
    a <- yaml::read_yaml(file.path('..', '..', 'jamovi', 'askllm.a.yaml'))
    opt <- Filter(function(o) o$name == 'addChecklist', a$options)
    expect_length(opt, 1)
    expect_equal(opt[[1]]$type, 'Bool')
    expect_true(isTRUE(opt[[1]]$default))
    r <- yaml::read_yaml(file.path('..', '..', 'jamovi', 'askllmr.a.yaml'))
    expect_length(Filter(function(o) o$name == 'addChecklist', r$options), 0)
    u <- paste(readLines(file.path('..', '..', 'jamovi', 'askllm.u.yaml'), warn = FALSE), collapse = '\n')
    expect_true(grepl('name: addChecklist', u, fixed = TRUE))
})

test_that('.runInner 原始碼:checklist 進 payload 指紋,且預覽與真呼叫兩處 system prompt 都帶它', {
    src <- readLines(file.path('..', '..', 'R', 'askllm.b.R'), warn = FALSE)
    expect_true(any(grepl("checklist <- isTRUE(opt$addChecklist)", src, fixed = TRUE)))
    expect_true(any(grepl('checklist = checklist)', src, fixed = TRUE)))        # payload + 預覽
    expect_equal(sum(grepl('checklist\\s*=\\s*checklist', src)), 3)              # payload、預覽、真呼叫
})
