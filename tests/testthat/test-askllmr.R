# test-askllmr.R — M-A3:R code tutor(askllmr)專用純函式測試
#
# 對應 dev-notes/r-tutor-bridge-plan.zh-TW.md §2.4;函式定義於 R/r-tutor.R。
# 涵蓋:.ASKLLM_R_PROMPTS 三人格身分句、.askllmr_system_prompt()、
# .askllmr_split()、.askllmr_links_html()。

# ---- .ASKLLM_R_PROMPTS:3 人格 x 2 語言 base 身分句 --------------------------

test_that('.ASKLLM_R_PROMPTS 具三人格 x 兩語言共六格,皆為非空字元', {
    roles <- c('consultant', 'tutor', 'explainer')
    langs <- c('en', 'zh')
    expect_true(all(roles %in% names(.ASKLLM_R_PROMPTS)))
    for (r in roles) {
        expect_true(all(langs %in% names(.ASKLLM_R_PROMPTS[[r]])))
        for (l in langs) {
            txt <- .ASKLLM_R_PROMPTS[[r]][[l]]
            expect_true(is.character(txt) && length(txt) == 1 && nzchar(txt))
        }
    }
})

test_that('.ASKLLM_R_PROMPTS:consultant/en 為 R coding tutor 定位句', {
    txt <- .ASKLLM_R_PROMPTS$consultant$en
    expect_true(grepl('R coding tutor', txt, fixed = TRUE))
    expect_true(grepl('Rj Editor', txt, fixed = TRUE))
})

test_that('.ASKLLM_R_PROMPTS:tutor 語氣含蘇格拉底式關鍵字(en/zh)', {
    expect_true(grepl('Socratic', .ASKLLM_R_PROMPTS$tutor$en, ignore.case = TRUE))
    expect_true(grepl('蘇格拉底', .ASKLLM_R_PROMPTS$tutor$zh, fixed = TRUE))
})

test_that('.ASKLLM_R_PROMPTS:explainer 語氣含零基礎關鍵字(en/zh)', {
    expect_true(grepl('beginner', .ASKLLM_R_PROMPTS$explainer$en, ignore.case = TRUE))
    expect_true(grepl('零基礎|沒有.*背景', .ASKLLM_R_PROMPTS$explainer$zh))
})

test_that('.ASKLLM_R_PROMPTS:六格彼此不同(人格語氣有差異)', {
    all_txt <- unlist(.ASKLLM_R_PROMPTS[c('consultant', 'tutor', 'explainer')])
    expect_equal(length(unique(all_txt)), 6)
})

# ---- .askllmr_system_prompt:base 選擇 + 恆附 RJ_SUFFIX ---------------------

# 「Module Guider 精簡 + 雙向 prompt 邊界」:.askllmr_system_prompt() 現在恆在
# 末尾附加 .ASKLLM_JAMOVI_REDIRECT_SUFFIX[[lang]](導向 sibling 分析「jamovi
# Module Guider」),故組成公式改為「base + RJ_SUFFIX + JAMOVI_REDIRECT_SUFFIX」。
test_that('system_prompt:六格皆為 base + RJ_SUFFIX + 邊界句 的組合(公式驗證)', {
    roles <- c('consultant', 'tutor', 'explainer')
    langs <- c('en', 'zh')
    for (r in roles) for (l in langs) {
        got <- .askllmr_system_prompt(role = r, lang = l)
        want <- paste(.ASKLLM_R_PROMPTS[[r]][[l]], .ASKLLM_RJ_SUFFIX[[r]][[l]],
                      .ASKLLM_JAMOVI_REDIRECT_SUFFIX[[l]])
        expect_identical(got, want, info = paste(r, l))
    }
})

test_that('system_prompt:custom system_prompt 非空時覆蓋 base,但仍恆附 RJ_SUFFIX', {
    custom <- 'Only ever use base R, no tidyverse.'
    txt <- .askllmr_system_prompt(role = 'tutor', lang = 'en', system_prompt = custom)
    expect_true(grepl(custom, txt, fixed = TRUE))
    expect_false(grepl('R coding tutor', txt, fixed = TRUE))  # base 模板未混入
    expect_true(grepl('Rj Editor', txt, fixed = TRUE))        # RJ_SUFFIX 恆附加
})

test_that('system_prompt:system_prompt 僅空白視為空(落回模板)', {
    txt <- .askllmr_system_prompt(role = 'consultant', lang = 'en', system_prompt = '  \n\t')
    expect_identical(txt,
        .askllmr_system_prompt(role = 'consultant', lang = 'en', system_prompt = ''))
})

test_that('system_prompt:未傳 system_prompt 與傳空字串逐字相同(預設值)', {
    expect_identical(
        .askllmr_system_prompt(role = 'tutor', lang = 'zh'),
        .askllmr_system_prompt(role = 'tutor', lang = 'zh', system_prompt = ''))
})

test_that('system_prompt:未知 role 落回 consultant,仍含 RJ_SUFFIX', {
    txt <- .askllmr_system_prompt(role = 'nope', lang = 'en')
    expect_identical(txt, .askllmr_system_prompt(role = 'consultant', lang = 'en'))
})

test_that('system_prompt:未知 lang 落回 en', {
    txt <- .askllmr_system_prompt(role = 'consultant', lang = 'fr')
    expect_identical(txt, .askllmr_system_prompt(role = 'consultant', lang = 'en'))
})

test_that('system_prompt:base 身分句在前,RJ_SUFFIX 內容在後(順序)', {
    txt <- .askllmr_system_prompt(role = 'tutor', lang = 'en')
    pos_base <- regexpr('R coding tutor', txt, fixed = TRUE)
    pos_common <- regexpr('paste your R code', txt, fixed = TRUE)
    pos_suffix <- regexpr('TODO', txt, fixed = TRUE)
    expect_true(pos_base > 0 && pos_common > 0 && pos_suffix > 0)
    expect_true(pos_base < pos_common)
    expect_true(pos_common < pos_suffix)
})

# ---- .askllmr_split:第一個 fenced code block 為 code,其餘為 explanation ----

test_that('split:單一 code block,取出 code 與其餘 explanation', {
    text <- 'Here is your code:\n```r\nx <- 1\ny <- x + 1\n```\nThis stores y.'
    parts <- .askllmr_split(text)
    expect_identical(parts$code, 'x <- 1\ny <- x + 1')
    expect_true(grepl('Here is your code', parts$explanation, fixed = TRUE))
    expect_true(grepl('This stores y', parts$explanation, fixed = TRUE))
    expect_false(grepl('```', parts$explanation, fixed = TRUE))
})

test_that('split:多個 code block 只取第一個為 code,其餘留在 explanation(去圍欄)', {
    text <- paste(
        'First:', '```r', 'a <- 1', '```',
        'Second (not used as code):', '```r', 'b <- 2', '```',
        sep = '\n')
    parts <- .askllmr_split(text)
    expect_identical(parts$code, 'a <- 1')
    expect_true(grepl('b <- 2', parts$explanation, fixed = TRUE))
    expect_false(grepl('```', parts$explanation, fixed = TRUE))
})

test_that('split:無 fenced code block 時,code 為空字串,explanation 為去圍欄全文', {
    text <- 'Just plain prose, no code block here.'
    parts <- .askllmr_split(text)
    expect_identical(parts$code, '')
    expect_identical(parts$explanation, .askllm_strip_fences(text))
})

test_that('split:NULL 輸入 → code/explanation 皆為空字串', {
    parts <- .askllmr_split(NULL)
    expect_identical(parts$code, '')
    expect_identical(parts$explanation, '')
})

test_that('split:空字串輸入 → code/explanation 皆為空字串', {
    parts <- .askllmr_split('')
    expect_identical(parts$code, '')
    expect_identical(parts$explanation, '')
})

test_that('split:巢狀縮排的程式碼內容原樣保留', {
    text <- paste(
        'Code:', '```r', 'f <- function(x) {', '  if (x > 0) {', '    x * 2',
        '  } else {', '    0', '  }', '}', '```', 'Done.',
        sep = '\n')
    parts <- .askllmr_split(text)
    expect_true(grepl('  if (x > 0) {', parts$code, fixed = TRUE))
    expect_true(grepl('    x * 2', parts$code, fixed = TRUE))
})

test_that('split:語言標記缺失(純 ```)也能正確擷取', {
    text <- 'code:\n```\nz <- 3\n```\nend'
    parts <- .askllmr_split(text)
    expect_identical(parts$code, 'z <- 3')
})

# ---- .ASKLLMR_LEARN_R_URL / .askllmr_links_html ----------------------------

test_that('.ASKLLMR_LEARN_R_URL 為固定常青頁網址', {
    expect_identical(.ASKLLMR_LEARN_R_URL,
        'https://scgeeker.github.io/askLLM/learn-r.html')
})

test_that('links_html:installed=TRUE 時不含安裝提示,含開啟 Rj 與連結', {
    html <- .askllmr_links_html(TRUE)
    expect_true(grepl('Analyses', html, fixed = TRUE))
    expect_true(grepl('Rj Editor', html, fixed = TRUE))
    expect_true(grepl(.ASKLLMR_LEARN_R_URL, html, fixed = TRUE))
    expect_true(grepl('Learn R with Rj', html, fixed = TRUE))
    expect_true(grepl('choose-model.html', html, fixed = TRUE))
    expect_true(grepl('Choose a model', html, fixed = TRUE))
    expect_false(grepl('jamovi library', html, fixed = TRUE))
})

test_that('links_html:installed=FALSE 時加入安裝提示', {
    html <- .askllmr_links_html(FALSE)
    expect_true(grepl('Install Rj', html, fixed = TRUE))
    expect_true(grepl('jamovi library', html, fixed = TRUE))
    expect_true(grepl(.ASKLLMR_LEARN_R_URL, html, fixed = TRUE))
})

test_that('links_html:url 參數可覆寫連結目的地', {
    html <- .askllmr_links_html(TRUE, url = 'http://example.test/x.html')
    expect_true(grepl('http://example.test/x.html', html, fixed = TRUE))
    expect_false(grepl(.ASKLLMR_LEARN_R_URL, html, fixed = TRUE))
})

test_that('links_html:回傳合法 <a href> 標籤', {
    html <- .askllmr_links_html(TRUE)
    expect_true(grepl('<a href="https://scgeeker.github.io/askLLM/learn-r.html"',
        html, fixed = TRUE))
})

# ---- .askllmr_guide_text / .askllmr_no_rj_text:雙語靜態文字 ----------------

test_that('guide_text:含隱私揭露(摘要統計 + Rj 套件名稱,非資料本身)', {
    txt <- .askllmr_guide_text()
    expect_true(grepl('SUMMARY STATISTICS', txt, fixed = TRUE))
    expect_true(grepl('摘要統計', txt, fixed = TRUE))
    expect_true(grepl('none of your data', txt, fixed = TRUE))
})

test_that('guide_text:英文區塊在中文區塊之前', {
    txt <- .askllmr_guide_text()
    expect_true(regexpr('Privacy:', txt) < regexpr('隱私提醒', txt))
    expect_true(regexpr('SUMMARY STATISTICS', txt) < regexpr('摘要統計', txt))
})

test_that('no_rj_text:雙語提示改教 Syntax Mode、可從 jamovi library 安裝 Rj', {
    txt <- .askllmr_no_rj_text()
    expect_true(grepl('Syntax Mode', txt, fixed = TRUE))
    expect_true(grepl('jamovi library', txt, fixed = TRUE))
    expect_true(grepl('尚未安裝 Rj|未安裝 Rj', txt))
    expect_true(grepl('jamovi library', txt, fixed = TRUE))
})
