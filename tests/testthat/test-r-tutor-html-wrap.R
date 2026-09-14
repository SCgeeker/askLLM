# test-r-tutor-html-wrap.R — 修 Preformatted 長行溢出 bug:
#
# 三個 LLM 輸出結果項(askllm 的 answer;askllmr 的 code、explanation)由
# Preformatted 改為 Html,靠 CSS white-space:pre-wrap 視覺換行,絕不插入
# 真正的 `\n`(code 需保持可原樣複製貼回 Rj Editor 執行)。
#
# 涵蓋 .askllm_html_escape()、.askllm_wrap_html()(定義於 R/r-tutor.R)。

# ---- .askllm_html_escape:& 必須最先轉,才不會把 &lt; 的 & 再轉一次 --------

test_that('html_escape:同時含 & < > 時,順序正確(& 最先轉)', {
    expect_identical(
        .askllm_html_escape('<a> & <b>'),
        '&lt;a&gt; &amp; &lt;b&gt;')
})

test_that('html_escape:NULL 輸入回傳空字串', {
    expect_identical(.askllm_html_escape(NULL), '')
})

test_that('html_escape:無特殊字元時原樣返回', {
    txt <- 'plain text with 中文 and numbers 123'
    expect_identical(.askllm_html_escape(txt), txt)
})

test_that('html_escape:單獨的 & 會轉成 &amp;,不誤傷其餘文字', {
    expect_identical(.askllm_html_escape('x & y'), 'x &amp; y')
})

# ---- .askllm_wrap_html:CSS 換行,絕不插入真正的 \n --------------------------

test_that('wrap_html:輸出以 <pre 開頭、</pre> 結尾,含 pre-wrap 與 overflow-wrap 行內樣式', {
    out <- .askllm_wrap_html('hello')
    expect_true(startsWith(out, '<pre'))
    expect_true(endsWith(out, '</pre>'))
    expect_true(grepl('white-space:pre-wrap', out, fixed = TRUE))
    expect_true(grepl('overflow-wrap:anywhere', out, fixed = TRUE))
})

test_that('wrap_html:內容經 HTML-escape', {
    out <- .askllm_wrap_html('x<y & z>1')
    expect_true(grepl('x&lt;y &amp; z&gt;1', out, fixed = TRUE))
})

test_that('wrap_html:不插入真正的換行 —— wrap 前後換行數相同', {
    multi <- 'line1\nline2\nline3'
    out <- .askllm_wrap_html(multi)
    n_before <- lengths(regmatches(multi, gregexpr('\n', multi)))
    n_after  <- lengths(regmatches(out, gregexpr('\n', out)))
    expect_identical(n_after, n_before)
})

test_that('wrap_html:單行長字串(無 \\n)wrap 後仍是單行(換行數為 0)', {
    long_line <- paste(rep('x', 400), collapse = '')
    out <- .askllm_wrap_html(long_line)
    expect_identical(lengths(regmatches(out, gregexpr('\n', out))), 0L)
})

test_that('wrap_html:NULL 輸入不報錯,回傳合法的空 <pre></pre>', {
    out <- .askllm_wrap_html(NULL)
    expect_true(startsWith(out, '<pre'))
    expect_true(endsWith(out, '</pre>'))
})

test_that('wrap_html:R code 經 escape 後,實體可在瀏覽器複製還原為原字元(往返驗證)', {
    code <- 'if (x < 10 && y > 5) {\n  print("a<b>c")\n}'
    out <- .askllm_wrap_html(code)
    # 模擬瀏覽器把 HTML 實體還原回文字(複製貼上後的行為)
    inner <- sub('^<pre[^>]*>', '', out)
    inner <- sub('</pre>$', '', inner)
    restored <- inner
    restored <- gsub('&lt;', '<', restored, fixed = TRUE)
    restored <- gsub('&gt;', '>', restored, fixed = TRUE)
    restored <- gsub('&amp;', '&', restored, fixed = TRUE)
    expect_identical(restored, code)
})
