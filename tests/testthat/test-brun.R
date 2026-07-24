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

# ---- S8:payload 指紋含 catalog(第五欄 context_text) -----------------------

test_that('payload fingerprint includes catalog', {
    q <- 'Q'; s <- 'S'; u <- 'http://b'; m <- 'm'

    # (a) 四參數呼叫與 context_text = '' 五參數呼叫 identical(舊行為不變)
    p4 <- .askllm_build_payload(q, s, u, m)
    p5_empty <- .askllm_build_payload(q, s, u, m, context_text = '')
    expect_identical(p4, p5_empty)

    # (b) context_text 不同 → payload 不同
    p_x <- .askllm_build_payload(q, s, u, m, context_text = 'X')
    p_y <- .askllm_build_payload(q, s, u, m, context_text = 'Y')
    expect_false(identical(p_x, p_y))

    # (c) 以 (b) 兩者作 cache/new payload → 'call';相同時 → 'cached'
    expect_equal(.askllm_decide(TRUE, q, p_x, p_y), 'call')
    expect_equal(.askllm_decide(TRUE, q, p_x, p_x), 'cached')
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

# ---- S9:引導文字新隱私句(逐字,規格 §9.3 定稿) ----------------------------

test_that('guide text mentions catalog metadata', {
    txt <- .askllm_guide_text()

    zh_new <- paste0(
        '為了讓建議指向真實選單,',
        '已安裝 jamovi 模組的「名稱與選單清單」',
        '(環境中繼資料,不含你的任何資料內容)',
        '也會一併傳送;取消勾選「Include installed modules」即可停用。')
    en_new <- paste0(
        'To ground suggestions in real menus, the NAMES AND MENU PATHS of your ',
        'installed jamovi modules (environment metadata, none of your data) are ',
        'also sent; untick "Include installed modules" to disable this.')

    expect_true(grepl(zh_new, txt, fixed = TRUE))
    expect_true(grepl(en_new, txt, fixed = TRUE))

    # v1.0 原隱私段兩句仍在
    expect_true(grepl('摘要統計', txt, fixed = TRUE))
    expect_true(grepl('SUMMARY STATISTICS', txt, fixed = TRUE))
})

# ---- S7:includeCatalog=FALSE 完全跳過掃描 ----------------------------------

test_that('includeCatalog off skips catalog', {
    called <- FALSE
    testthat::local_mocked_bindings(
        scan_modules = function(dirs = NULL) { called <<- TRUE; list(modules = list(), errors = character(0)) })

    ctx <- .askllm_gather_context(FALSE)

    expect_false(called)
    expect_null(ctx$catalog_text)
    expect_null(ctx$available_text)

    # payload 第五欄為 ''(空字串)——比照 .runInner() 的組法
    context_text <- if (is.null(ctx$catalog_text) && is.null(ctx$available_text)) {
        ''
    } else {
        paste(ctx$catalog_text %||% '', ctx$available_text %||% '', sep = '\n')
    }
    expect_identical(context_text, '')

    # 送出的 prompt 不含子字串 <installed_analyses>/<available_modules>
    prompt <- build_prompt('Q', 'S', catalog_text = ctx$catalog_text,
                           available_text = ctx$available_text)
    expect_false(grepl('<installed_analyses>', prompt, fixed = TRUE))
    expect_false(grepl('<available_modules>', prompt, fixed = TRUE))
})

# ---- S6(半邊):works when catalog empty(掃描全失敗時降級) -----------------

test_that('works when catalog empty', {
    testthat::local_mocked_bindings(
        scan_modules = function(dirs = NULL) list(modules = list(), errors = character(0)))

    ctx <- .askllm_gather_context(TRUE)

    expect_null(ctx$catalog_text)      # catalog_text() 對空 modules 回 NULL
    expect_null(ctx$available_text)    # catalog 為 NULL 時 available 不組

    # prompt 與 v1.0 逐字相同(降級)
    prompt <- build_prompt('Q', 'S', catalog_text = ctx$catalog_text,
                           available_text = ctx$available_text)
    expect_identical(prompt, build_prompt('Q', 'S'))
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

test_that('caveat_text 依 has_catalog 誠實描述是否比對過清單', {
    # has_catalog = TRUE(預設):路徑已比對本機安裝清單
    on <- .askllm_caveat_text(has_catalog = TRUE)
    expect_true(grepl('已比對', on))
    expect_true(grepl('checked against', on, ignore.case = TRUE))

    # has_catalog = FALSE:未送清單、未比對——不得謊稱已比對
    off <- .askllm_caveat_text(has_catalog = FALSE)
    expect_false(grepl('已比對', off))
    expect_false(grepl('checked against', off, ignore.case = TRUE))
    expect_true(grepl('未經比對|未比對', off))
    expect_true(grepl('not verified', off, ignore.case = TRUE))
    # 兩種情形都仍提醒以實際介面為準
    expect_true(grepl('實際介面|實際', off))
    expect_true(grepl('actual interface', off, ignore.case = TRUE))

    # 無參數呼叫維持向後相容(預設 has_catalog = TRUE 的內容)
    expect_identical(.askllm_caveat_text(), on)
})
