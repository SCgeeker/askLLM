# test-adapter.R — llm-adapter.R 離線測試(ctor 注入,零網路)

# 假 ctor:捕獲收到的參數,回傳一個有 $chat 方法的 list
fake_ctor <- function(captured, chat_fn) {
    function(base_url, model, api_key, system_prompt) {
        captured$base_url <- base_url
        captured$model <- model
        captured$api_key <- api_key
        captured$system_prompt <- system_prompt
        list(chat = chat_fn)
    }
}

test_that('make_chat 正確把參數轉發給 ctor', {
    captured <- new.env()
    ctor <- fake_ctor(captured, function(prompt) 'ok')
    obj <- make_chat(base_url = 'BASE', model = 'MODEL', api_key = 'KEY',
                     system_prompt = 'SYS', ctor = ctor)

    expect_equal(captured$base_url, 'BASE')
    expect_equal(captured$model, 'MODEL')
    expect_equal(captured$api_key, 'KEY')
    expect_equal(captured$system_prompt, 'SYS')
    expect_true(is.function(obj$chat))
})

test_that('ask_llm 成功路徑回傳結構化 list', {
    captured <- new.env()
    ctor <- fake_ctor(captured, function(prompt) 'The answer is 42.')
    res <- ask_llm(question = 'Q', base_url = 'B', model = 'M',
                   api_key = 'K', ctor = ctor)

    expect_true(res$ok)
    expect_equal(res$text, 'The answer is 42.')
    expect_equal(res$model, 'M')
    expect_type(res$elapsed_s, 'double')
    expect_true(res$elapsed_s >= 0)
    expect_null(res$error)
})

test_that('ask_llm 有 summary_text 時組出模板 prompt', {
    captured <- new.env()
    ctor <- fake_ctor(captured, function(prompt) { captured$prompt <- prompt; 'x' })
    ask_llm(question = 'What is the mean age?', summary_text = 'age: mean=30, sd=5',
            base_url = 'B', model = 'M', api_key = 'K', ctor = ctor)

    expect_match(captured$prompt, '<summary>', fixed = TRUE)
    expect_match(captured$prompt, '</summary>', fixed = TRUE)
    expect_match(captured$prompt, 'age: mean=30, sd=5', fixed = TRUE)
    expect_match(captured$prompt, 'THIS dataset')
    expect_match(captured$prompt, 'What is the mean age?', fixed = TRUE)
})

test_that('ask_llm 無 summary_text 時只送純問題', {
    captured <- new.env()
    ctor <- fake_ctor(captured, function(prompt) { captured$prompt <- prompt; 'x' })
    ask_llm(question = 'Just a plain question',
            base_url = 'B', model = 'M', api_key = 'K', ctor = ctor)

    expect_equal(captured$prompt, 'Just a plain question')
    expect_false(grepl('<summary>', captured$prompt, fixed = TRUE))
})

test_that('ask_llm 錯誤翻譯正確且 ok=FALSE、保留原始訊息', {
    throw_ctor <- function(errmsg) {
        function(base_url, model, api_key, system_prompt) {
            list(chat = function(prompt) stop(errmsg, call. = FALSE))
        }
    }
    call_with <- function(errmsg, model = 'bad-model') {
        ask_llm(question = 'Q', base_url = 'B', model = model,
                api_key = 'K', ctor = throw_ctor(errmsg))
    }

    r401 <- call_with('HTTP 401 Unauthorized')
    expect_false(r401$ok)
    expect_null(r401$text)
    expect_match(r401$error, '金鑰無效或過期')
    expect_match(r401$error, 'HTTP 401 Unauthorized', fixed = TRUE)

    # 403 是「金鑰有效但無權限」,與 401 分開(GitHub Models 實測)
    r403 <- call_with('HTTP 403 Forbidden')
    expect_match(r403$error, '權限')
    expect_false(grepl('金鑰無效或過期', r403$error, fixed = TRUE))

    r404 <- call_with('HTTP 404 Not Found', model = 'no-such-model')
    expect_match(r404$error, '端點或模型名錯誤')
    expect_match(r404$error, 'no-such-model', fixed = TRUE)

    r429 <- call_with('HTTP 429 Too Many Requests')
    expect_match(r429$error, '已達用量上限')

    rconn <- call_with('Could not resolve host: integrate.api.nvidia.com')
    expect_match(rconn$error, '無法連線')

    rtimeout <- call_with('Timeout was reached: Connection timed out')
    expect_match(rtimeout$error, '無法連線')

    rother <- call_with('Some unexpected weird failure')
    expect_false(rother$ok)
    expect_match(rother$error, 'Some unexpected weird failure', fixed = TRUE)
})

test_that('本機 ellmer 0.4.2 下 make_chat 不帶 ctor 能建構出物件(零網路)', {
    skip_if_not_installed('ellmer')
    # 隔離 OPENAI_API_KEY:make_chat 內部會 Sys.setenv,測試結束後還原,避免污染
    withr::local_envvar(c(OPENAI_API_KEY = NA))
    obj <- make_chat(base_url = 'https://integrate.api.nvidia.com/v1',
                     model = 'meta/llama-3.1-8b-instruct',
                     api_key = 'dummy-key-not-used-no-network',
                     system_prompt = 'test only, no call')
    expect_true(is.function(obj$chat))
})

# ---- 403 權限不足須與 401 金鑰無效分開(GitHub Models 實測踩到)-------------

test_that('403 no_access 譯為「權限不足」而非「金鑰無效」', {
    msg <- 'HTTP 403 Forbidden.\n{"error":{"code":"no_access","message":"No access to model: openai/gpt-4o-mini"}}'
    out <- translate_error(msg, 'openai/gpt-4o-mini')
    expect_true(grepl('權限', out))
    expect_false(grepl('金鑰無效或過期', out, fixed = TRUE))
    expect_true(grepl('no_access|Models', out))   # 保留原訊息供除錯
})

test_that('401 仍譯為金鑰無效', {
    out <- translate_error('HTTP 401 Unauthorized.', 'm')
    expect_true(grepl('金鑰', out))
    expect_false(grepl('權限不足', out, fixed = TRUE))
})
