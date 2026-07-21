# test-brun.R — .b.R 的可測純函式決策表與 R6 類別載入斷言(零網路、離線)
#
# 策略:.run() 本體需要 jmvcore Options/Results 機制,難以離線實例化;
# 故把可測邏輯抽成檔案層級純函式(.askllm_*),在此測其決策表,
# R6 類別本體僅斷言「能正確載入且繼承正確」。

# ---- .askllm_build_payload:payload 組裝與分隔符不受內容干擾 -----------------

test_that('build_payload 對 NULL summary_text 視為空字串,不炸', {
    p <- .askllm_build_payload('Q', NULL, 'http://b', 'm')
    expect_true(is.character(p))
    expect_length(p, 1)
})

test_that('build_payload:欄位邊界不因內容黏連而產生歧義', {
    # 天真串接下 ('a','b',..) 與 ('ab','',..) 會相同;有分隔符則必不同
    p1 <- .askllm_build_payload('a', 'b', 'u', 'm')
    p2 <- .askllm_build_payload('ab', '', 'u', 'm')
    expect_false(identical(p1, p2))
})

test_that('build_payload:內容含換行與空白時仍為決定性且可比對', {
    q <- 'line1\nline2  with spaces'
    s <- 'summary\nwith\nnewlines'
    p_a <- .askllm_build_payload(q, s, 'http://b', 'm')
    p_b <- .askllm_build_payload(q, s, 'http://b', 'm')
    expect_identical(p_a, p_b)                      # 同輸入 → 同輸出
    # 任一欄位實質改變 → payload 改變
    expect_false(identical(p_a, .askllm_build_payload(q, s, 'http://b', 'm2')))
    expect_false(identical(p_a, .askllm_build_payload(q, s, 'http://OTHER', 'm')))
})

# ---- .askllm_decide:守門 / 快取命中 / 呼叫 三態決策表 -----------------------

test_that('decide:未勾 submit 一律 guide(即使問題非空、快取存在)', {
    expect_equal(.askllm_decide(FALSE, 'a real question', 'PAYLOAD', 'PAYLOAD'), 'guide')
    expect_equal(.askllm_decide(FALSE, 'q', NULL, 'P'), 'guide')
})

test_that('decide:勾了 submit 但問題空白 → guide', {
    expect_equal(.askllm_decide(TRUE, '', NULL, 'P'), 'guide')
    expect_equal(.askllm_decide(TRUE, '   ', NULL, 'P'), 'guide')
    expect_equal(.askllm_decide(TRUE, '\n\t ', NULL, 'P'), 'guide')
})

test_that('decide:勾了 submit、問題非空、快取為 NULL → call', {
    expect_equal(.askllm_decide(TRUE, 'q', NULL, 'NEW'), 'call')
})

test_that('decide:快取 payload 與新 payload 相同 → cached', {
    expect_equal(.askllm_decide(TRUE, 'q', 'SAME', 'SAME'), 'cached')
})

test_that('decide:快取 payload 與新 payload 不同 → call', {
    expect_equal(.askllm_decide(TRUE, 'q', 'OLD', 'NEW'), 'call')
})

# ---- .askllm_meta_line:模型名 · 耗時 格式 ----------------------------------

test_that('meta_line 格式為「模型 · 秒數s」且耗時四捨五入到 1 位', {
    line <- .askllm_meta_line('meta/llama-3.1-8b-instruct', 1.234)
    expect_true(grepl('meta/llama-3.1-8b-instruct', line, fixed = TRUE))
    expect_true(grepl('1.2s', line, fixed = TRUE))
    expect_true(grepl('·', line, fixed = TRUE))         # middle dot
})

# ---- .askllm_guide_text:引導文字含三步教學、Submit、隱私提醒 ---------------

test_that('guide_text 含教學關鍵字、Submit、隱私(摘要統計)提醒', {
    txt <- .askllm_guide_text()
    expect_true(is.character(txt))
    expect_length(txt, 1)
    expect_true(grepl('Submit', txt, fixed = TRUE))
    expect_true(grepl('摘要', txt))                  # 摘要
    expect_true(grepl('隱私', txt))                  # 隱私
})

# ---- R6 類別載入 / 繼承斷言 -------------------------------------------------

test_that('askllmClass 存在且為 R6 類別產生器,繼承 askllmBase', {
    expect_true(exists('askllmClass'))
    expect_true(inherits(askllmClass, 'R6ClassGenerator'))
    expect_equal(askllmClass$inherit, as.name('askllmBase'))
})

# ---- .askllm_waiting_text:送出後、回覆前顯示的等待訊息 ---------------------

test_that('waiting_text 含 provider 顯示名稱與模型名,並標明等候中', {
    txt <- .askllm_waiting_text('NVIDIA NIM', 'meta/llama-3.1-8b-instruct')
    expect_true(is.character(txt))
    expect_length(txt, 1)
    expect_true(grepl('NVIDIA NIM', txt, fixed = TRUE))
    expect_true(grepl('meta/llama-3.1-8b-instruct', txt, fixed = TRUE))
    expect_true(grepl('等候', txt))
    expect_true(grepl('Waiting', txt, ignore.case = TRUE))
})

test_that('waiting_text 對空模型名不炸', {
    expect_error(.askllm_waiting_text('Ollama (local)', ''), NA)
})

# ---- .askllm_caveat_text:回覆成功後顯示的查證提醒 -------------------------

test_that('caveat_text 提醒使用者查證,且中英雙語', {
    txt <- .askllm_caveat_text()
    expect_true(is.character(txt))
    expect_length(txt, 1)
    expect_true(grepl('查證|核對', txt))
    expect_true(grepl('選單路徑', txt))          # 實測最常出錯之處
    expect_true(grepl('verify', txt, ignore.case = TRUE))
    expect_true(grepl('menu path', txt, ignore.case = TRUE))
})
