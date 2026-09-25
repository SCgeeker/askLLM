# test-pii.R — v1.4 項目 C:識別碼型欄位守門與疑似個資偵測(純函式、離線)

# ---- .askllm_identifier_like ------------------------------------------------

test_that('identifier_like:k > 20 且 k/n > 0.9 才成立;邊界與空輸入', {
    expect_true(.askllm_identifier_like(25, 25))
    expect_true(.askllm_identifier_like(95, 100))
    expect_false(.askllm_identifier_like(20, 20))     # k 未超過 20
    expect_false(.askllm_identifier_like(22, 100))    # 22 個縣市重複出現:比例低
    expect_false(.askllm_identifier_like(90, 100))    # 0.9 不算 > 0.9
    expect_false(.askllm_identifier_like(0, 0))
    expect_false(.askllm_identifier_like(NA, 10))
})

# ---- summarize_data 守門:識別碼欄不列出值 ----------------------------------

test_that('character 識別碼欄:只回報 distinct 數,任何值都不進摘要', {
    names_v <- paste0('Person', sprintf('%02d', 1:30))
    df <- data.frame(Name = names_v, score = 1:30, stringsAsFactors = FALSE)
    out <- summarize_data(df, c('Name', 'score'))
    expect_true(grepl('30 distinct values', out, fixed = TRUE))
    expect_true(grepl('identifier-like; values withheld', out, fixed = TRUE))
    expect_false(any(vapply(names_v, function(v) grepl(v, out, fixed = TRUE), logical(1))))
    expect_false(grepl('top values', out, fixed = TRUE))
})

test_that('factor 識別碼欄同樣不列水準;ordered 亦不列 level order', {
    ids <- paste0('S', 1:40)
    df <- data.frame(sid = factor(ids), o = ordered(ids, levels = ids))
    out <- summarize_data(df, c('sid', 'o'))
    expect_equal(lengths(regmatches(out, gregexpr('values withheld', out, fixed = TRUE))), 2)
    expect_false(grepl('levels by count', out, fixed = TRUE))
    expect_false(grepl('level order', out, fixed = TRUE))
    expect_false(grepl('S17', out, fixed = TRUE))
})

test_that('真正的多水準類別(重複出現)不受守門影響,行為與 v1.3 相同', {
    df <- data.frame(city = factor(rep(paste0('C', 1:22), length.out = 200)))
    out <- summarize_data(df, 'city')
    expect_true(grepl('levels by count', out, fixed = TRUE))
    expect_true(grepl('... and 12 more levels', out, fixed = TRUE))
    expect_false(grepl('withheld', out, fixed = TRUE))
    # 小樣本(20 個各不同)仍列出:k 未超過門檻
    small <- data.frame(s = paste0('v', 1:20), stringsAsFactors = FALSE)
    expect_false(grepl('withheld', summarize_data(small, 's'), fixed = TRUE))
})

test_that('守門決定性,且 iris 摘要逐字不變(回歸鎖)', {
    df <- data.frame(Name = paste0('P', 1:30), stringsAsFactors = FALSE)
    expect_identical(summarize_data(df, 'Name'), summarize_data(df, 'Name'))
    ref <- summarize_data(iris, names(iris))
    expect_true(grepl('setosa(50)', ref, fixed = TRUE))
    expect_false(grepl('withheld', ref, fixed = TRUE))
})

# ---- .askllm_pii_flags ---------------------------------------------------------

test_that('pii_flags:欄名規則(整詞或分節),不誤判 paid/grid/Sepal.Width', {
    df <- data.frame(
        student_id = 1:5, Name = letters[1:5], `Email Address` = letters[1:5],
        電話 = 1:5, paid = 1:5, grid = 1:5, Sepal.Width = 1:5, valid = 1:5,
        check.names = FALSE, stringsAsFactors = FALSE)
    f <- .askllm_pii_flags(df, names(df))
    flagged <- sub(' \\(.*$', '', f)
    expect_setequal(flagged, c('student_id', 'Name', 'Email Address', '電話'))
    expect_true(all(grepl('identifier/personal field', f[flagged %in% c('student_id', 'Name')])))
})

test_that('pii_flags:值樣式(email / 電話)與識別碼基數', {
    df <- data.frame(
        contact = c('a@x.org', 'b@y.edu', 'c@z.com', NA),
        tel_no  = c('0912-345-678', '+886 2 1234 5678', '(02) 2345-6789', '0987654321'),
        code    = paste0('K', 1:4),
        stringsAsFactors = FALSE)
    f <- .askllm_pii_flags(df, c('contact', 'tel_no', 'code'))
    expect_true(any(grepl('^contact .*email', f)))
    expect_true(any(grepl('^tel_no .*phone', f)))    # 欄名 'tel' 分節 + 值樣式
    expect_false(any(grepl('^code', f)))            # 4 列不足以構成識別碼
    big <- data.frame(code = paste0('K', 1:50), stringsAsFactors = FALSE)
    expect_true(any(grepl('^code .*distinct value', .askllm_pii_flags(big, 'code'))))
})

test_that('pii_flags:iris/mtcars 無任何旗標;不存在的變項忽略;空 vars 回 character(0)', {
    expect_equal(.askllm_pii_flags(iris, names(iris)), character(0))
    expect_equal(.askllm_pii_flags(mtcars, names(mtcars)), character(0))
    expect_equal(.askllm_pii_flags(iris, c('NoSuch', 'Species')), character(0))
    expect_equal(.askllm_pii_flags(iris, character(0)), character(0))
    expect_equal(.askllm_pii_flags(iris, NULL), character(0))
})

# ---- 預覽與 caveat 文字 ----------------------------------------------------------

test_that('preview_text 原文照排 system/user prompt(不改內容)', {
    txt <- .askllm_preview_text('SYS <x>', 'USER & y')
    expect_true(grepl('=== System prompt', txt, fixed = TRUE))
    expect_true(grepl('SYS <x>', txt, fixed = TRUE))
    expect_true(grepl('=== User prompt', txt, fixed = TRUE))
    expect_true(grepl('USER & y', txt, fixed = TRUE))
    expect_true(regexpr('SYS <x>', txt, fixed = TRUE) < regexpr('USER & y', txt, fixed = TRUE))
})

test_that('preview_instructions:零呼叫聲明、字元數、雙語;有旗標時附個資提示', {
    txt <- .askllm_preview_instructions('Google Gemini', 'gemini-flash-latest', 1234)
    expect_true(grepl('PREVIEW ONLY', txt, fixed = TRUE))
    expect_true(grepl('no API call', txt, fixed = TRUE))
    expect_true(grepl('1234 chars', txt, fixed = TRUE))
    expect_true(grepl('僅預覽', txt, fixed = TRUE))
    expect_false(grepl('Possible personal data', txt, fixed = TRUE))
    with_pii <- .askllm_preview_instructions('Google Gemini', 'm', 10, pii_flags = 'Name (x)')
    expect_true(grepl('Possible personal data', with_pii, fixed = TRUE))
    expect_true(grepl('• Name (x)', with_pii, fixed = TRUE))
    expect_true(grepl('疑似含個人資料', with_pii, fixed = TRUE))
    expect_true(grepl('preview only · 0 API calls', .askllm_preview_meta_line('m'), fixed = TRUE))
})

test_that('caveat_text / askllmr_caveat_text:pii_flags 為 NULL/空時逐字不變,有值時附提示', {
    expect_identical(.askllm_caveat_text(TRUE), .askllm_caveat_text(TRUE, pii_flags = NULL))
    expect_identical(.askllm_caveat_text(TRUE), .askllm_caveat_text(TRUE, pii_flags = character(0)))
    withp <- .askllm_caveat_text(TRUE, pii_flags = c('Name (a)', 'tel (b)'))
    expect_true(grepl('• Name (a)', withp, fixed = TRUE))
    expect_true(grepl('• tel (b)', withp, fixed = TRUE))
    expect_true(startsWith(withp, .askllm_caveat_text(TRUE)))

    expect_identical(.askllmr_caveat_text(TRUE), .askllmr_caveat_text(TRUE, pii_flags = NULL))
    rp <- .askllmr_caveat_text(FALSE, pii_flags = 'Name (a)')
    expect_true(grepl('Possible personal data', rp, fixed = TRUE))
    expect_true(startsWith(rp, .askllmr_caveat_text(FALSE)))
})

test_that('兩個分析的 a.yaml 都有 previewPayload(Bool, default FALSE);u.yaml 有對應 CheckBox', {
    for (f in c('askllm', 'askllmr')) {
        a <- yaml::read_yaml(file.path('..', '..', 'jamovi', paste0(f, '.a.yaml')))
        opt <- Filter(function(o) o$name == 'previewPayload', a$options)
        expect_length(opt, 1)
        expect_equal(opt[[1]]$type, 'Bool')
        expect_false(isTRUE(opt[[1]]$default))
        u <- paste(readLines(file.path('..', '..', 'jamovi', paste0(f, '.u.yaml')), warn = FALSE),
                   collapse = '\n')
        expect_true(grepl('name: previewPayload', u, fixed = TRUE), info = f)
    }
})

test_that('.runInner 原始碼:預覽分支在快取比對之前、且不呼叫 ask_llm(source scan)', {
    for (f in c('askllm.b.R', 'askllmr.b.R')) {
        src <- readLines(file.path('..', '..', 'R', f), warn = FALSE)
        i_prev <- grep('if (preview) {', src, fixed = TRUE)
        i_cache <- grep('state 快取比對', src, fixed = TRUE)
        i_call <- grep('res <- ask_llm(', src, fixed = TRUE)
        expect_length(i_prev, 1)
        expect_true(i_prev < i_cache[1] && i_cache[1] < i_call[1], info = f)
        # 預覽分支內(到下一個 '# ---' 區段前)沒有 ask_llm / load_api_key
        blk <- src[i_prev:(i_cache[1] - 1)]
        expect_false(any(grepl('ask_llm\\(|load_api_key\\(', blk)), info = f)
        expect_true(any(grepl('return()', blk, fixed = TRUE)), info = f)
    }
})
