# test-ping.R — 項目 3(Test Connection)離線測試,假 transport 注入,零網路
#
# ping_endpoint() 永不 stop();結構化回傳 list(ok, status, kind, body, message)。
# kind ∈ {'reachable','valid_key','invalid_key','forbidden','no_service','network'}。
# 判讀規則見 dev-notes/execution-plan.zh-TW.md 項目 3(2026-07-29 spike 結果表)。

fake_transport <- function(status, body = '', error = NULL, capture = NULL) {
    function(url, headers, timeout = 10) {
        if (!is.null(capture)) {
            capture$url <- url
            capture$headers <- headers
            capture$timeout <- timeout
        }
        list(status = status, body = body, error = error)
    }
}

# ---- 共用預設判讀:200/401/403/連線失敗/timeout ------------------------------

test_that('200 對「不驗證金鑰」provider(custom) → ok=TRUE, kind=reachable', {
    res <- ping_endpoint('custom', 'https://x/v1', 'k', TRUE,
        transport = fake_transport(200, '{"data":[]}'))
    expect_true(res$ok)
    expect_equal(res$kind, 'reachable')
    expect_equal(res$status, 200)
})

test_that('401 → ok=FALSE, kind=invalid_key(預設)', {
    res <- ping_endpoint('custom', 'https://x/v1', 'bad', TRUE,
        transport = fake_transport(401, '{"error":"Unauthorized"}'))
    expect_false(res$ok)
    expect_equal(res$kind, 'invalid_key')
})

test_that('403 → ok=FALSE, kind=forbidden(預設)', {
    res <- ping_endpoint('custom', 'https://x/v1', 'k', TRUE,
        transport = fake_transport(403, '{"error":"forbidden"}'))
    expect_false(res$ok)
    expect_equal(res$kind, 'forbidden')
    expect_true(grepl('權限', res$message))
})

test_that('連線失敗(非 ollama) → ok=FALSE, kind=network', {
    res <- ping_endpoint('nim', 'https://x/v1', 'k', TRUE,
        transport = fake_transport(NA_integer_, NULL, error = 'Could not resolve host'))
    expect_false(res$ok)
    expect_equal(res$kind, 'network')
    expect_true(grepl('無法連線', res$message))
})

test_that('timeout → ok=FALSE, kind=network', {
    res <- ping_endpoint('nim', 'https://x/v1', 'k', TRUE,
        transport = fake_transport(NA_integer_, NULL, error = 'Timeout was reached'))
    expect_false(res$ok)
    expect_equal(res$kind, 'network')
})

# ---- github override:404=通(不 fallback catalog),401=未授權 ---------------

test_that('github 404 page not found → ok=TRUE, kind=valid_key', {
    res <- ping_endpoint('github', 'https://models.github.ai/inference', 'tok', TRUE,
        transport = fake_transport(404, '{"message":"page not found"}'))
    expect_true(res$ok)
    expect_equal(res$kind, 'valid_key')
})

test_that('github 401 → ok=FALSE, kind=invalid_key', {
    res <- ping_endpoint('github', 'https://models.github.ai/inference', 'bad', TRUE,
        transport = fake_transport(401, '{"message":"Unauthorized"}'))
    expect_false(res$ok)
    expect_equal(res$kind, 'invalid_key')
})

# ---- gemini override:400 且 body 含 api key → invalid_key(非 401 桶) -------

test_that('gemini 400 body含 api key → ok=FALSE, kind=invalid_key', {
    res <- ping_endpoint('gemini',
        'https://generativelanguage.googleapis.com/v1beta/openai', 'bad', TRUE,
        transport = fake_transport(400,
            '{"error":{"message":"API key not valid. Please pass a valid API key."}}'))
    expect_false(res$ok)
    expect_equal(res$kind, 'invalid_key')
})

test_that('gemini 200 → ok=TRUE, kind=valid_key', {
    res <- ping_endpoint('gemini',
        'https://generativelanguage.googleapis.com/v1beta/openai', 'good', TRUE,
        transport = fake_transport(200, '{"data":[]}'))
    expect_true(res$ok)
    expect_equal(res$kind, 'valid_key')
})

# ---- nim/openrouter 200 → reachable(非 valid_key,/models 不驗證金鑰) ------

test_that('nim 200 → ok=TRUE, kind=reachable', {
    res <- ping_endpoint('nim', 'https://integrate.api.nvidia.com/v1', 'any', TRUE,
        transport = fake_transport(200, '{"data":[]}'))
    expect_true(res$ok)
    expect_equal(res$kind, 'reachable')
})

test_that('openrouter 200 → ok=TRUE, kind=reachable', {
    res <- ping_endpoint('openrouter', 'https://openrouter.ai/api/v1', 'any', TRUE,
        transport = fake_transport(200, '{"data":[]}'))
    expect_true(res$ok)
    expect_equal(res$kind, 'reachable')
})

# ---- ollama:needs_key=FALSE → 不附 Authorization header --------------------

test_that('ollama needs_key=FALSE 時不附 Authorization header', {
    cap <- new.env()
    ping_endpoint('ollama', 'http://localhost:11434/v1', '', FALSE,
        transport = fake_transport(200, '{"models":[]}', capture = cap))
    expect_false('Authorization' %in% names(cap$headers))
})

test_that('needs_key=TRUE 時附 Authorization header(Bearer)', {
    cap <- new.env()
    ping_endpoint('nim', 'https://x/v1', 'MYKEY', TRUE,
        transport = fake_transport(200, '{}', capture = cap))
    expect_true('Authorization' %in% names(cap$headers))
    expect_match(cap$headers[['Authorization']], 'MYKEY', fixed = TRUE)
})

test_that('ollama 連線失敗 → kind=no_service(非 network)', {
    res <- ping_endpoint('ollama', 'http://localhost:11434/v1', '', FALSE,
        transport = fake_transport(NA_integer_, NULL,
            error = 'Failed to connect to localhost port 11434'))
    expect_false(res$ok)
    expect_equal(res$kind, 'no_service')
})

test_that('ollama 200 → ok=TRUE, kind=reachable', {
    res <- ping_endpoint('ollama', 'http://localhost:11434/v1', '', FALSE,
        transport = fake_transport(200, '{"models":[]}'))
    expect_true(res$ok)
    expect_equal(res$kind, 'reachable')
})

# ---- URL 組裝:一律打 {base_url}/models -------------------------------------

test_that('ping_endpoint 打 {base_url}/models', {
    cap <- new.env()
    ping_endpoint('nim', 'https://integrate.api.nvidia.com/v1', 'k', TRUE,
        transport = fake_transport(200, '{}', capture = cap))
    expect_equal(cap$url, 'https://integrate.api.nvidia.com/v1/models')
})

test_that('ping_endpoint 對尾端已有斜線的 base_url 不重複斜線', {
    cap <- new.env()
    ping_endpoint('nim', 'https://integrate.api.nvidia.com/v1/', 'k', TRUE,
        transport = fake_transport(200, '{}', capture = cap))
    expect_equal(cap$url, 'https://integrate.api.nvidia.com/v1/models')
})

# ---- ping_endpoint 永不 stop() ----------------------------------------------

test_that('ping_endpoint 對任何 transport 例外皆不 stop()', {
    boom <- function(url, headers, timeout = 10) stop('boom')
    expect_error(
        result <- tryCatch(ping_endpoint('nim', 'https://x/v1', 'k', TRUE,
            transport = boom), error = function(e) e),
        NA)
})

# ---- .askllm_ping_text:雙語文案 --------------------------------------------

test_that('nim/openrouter/custom 成功文案不含「金鑰有效」,只講端點可連線', {
    ok_res <- list(ok = TRUE, status = 200, kind = 'reachable', body = '{}', message = NULL)
    for (p in c('nim', 'openrouter', 'custom')) {
        txt <- .askllm_ping_text(ok_res, p, .askllm_provider_name(p),
            needs_key = TRUE, key_source = 'env')
        expect_false(grepl('金鑰有效', txt, fixed = TRUE))
        expect_true(grepl('端點可連線', txt, fixed = TRUE))
        expect_true(grepl('reachable', txt, ignore.case = TRUE))
    }
})

test_that('gemini 成功/失敗文案(400)', {
    ok_res <- list(ok = TRUE, status = 200, kind = 'valid_key', body = '{}', message = NULL)
    fail_res <- list(ok = FALSE, status = 400, kind = 'invalid_key', body = '...',
        message = '金鑰無效或過期(原始訊息:...)')
    ok_txt <- .askllm_ping_text(ok_res, 'gemini', 'Google Gemini', TRUE, key_source = 'env')
    fail_txt <- .askllm_ping_text(fail_res, 'gemini', 'Google Gemini', TRUE, key_source = 'env')
    expect_true(grepl('金鑰有效', ok_txt, fixed = TRUE))
    expect_true(grepl('金鑰無效', fail_txt, fixed = TRUE))
    expect_true(grepl('400', fail_txt, fixed = TRUE))
})

test_that('github 成功(404)/失敗(401)文案', {
    ok_res <- list(ok = TRUE, status = 404, kind = 'valid_key', body = 'page not found',
        message = NULL)
    fail_res <- list(ok = FALSE, status = 401, kind = 'invalid_key', body = 'Unauthorized',
        message = NULL)
    ok_txt <- .askllm_ping_text(ok_res, 'github', 'GitHub Models', TRUE, key_source = 'env')
    fail_txt <- .askllm_ping_text(fail_res, 'github', 'GitHub Models', TRUE, key_source = 'env')
    expect_true(grepl('金鑰有效', ok_txt, fixed = TRUE))
    expect_true(grepl('404', ok_txt, fixed = TRUE))
    expect_true(grepl('未授權', fail_txt, fixed = TRUE))
    expect_true(grepl('401', fail_txt, fixed = TRUE))
})

test_that('ollama 成功/失敗文案且標明「免金鑰」', {
    ok_res <- list(ok = TRUE, status = 200, kind = 'reachable', body = '{}', message = NULL)
    fail_res <- list(ok = FALSE, status = NA_integer_, kind = 'no_service', body = NULL,
        message = NULL)
    ok_txt <- .askllm_ping_text(ok_res, 'ollama', 'Ollama (local)', FALSE)
    fail_txt <- .askllm_ping_text(fail_res, 'ollama', 'Ollama (local)', FALSE)
    expect_true(grepl('本機服務可連線', ok_txt, fixed = TRUE))
    expect_true(grepl('服務未啟動', fail_txt, fixed = TRUE))
    expect_true(grepl('免金鑰', ok_txt, fixed = TRUE))
    expect_true(grepl('免金鑰', fail_txt, fixed = TRUE))
})

test_that('金鑰來源顯示在文案中(keyed provider)', {
    ok_res <- list(ok = TRUE, status = 200, kind = 'valid_key', body = '{}', message = NULL)
    txt <- .askllm_ping_text(ok_res, 'gemini', 'Google Gemini', TRUE, key_source = 'env')
    expect_true(grepl('金鑰來源', txt))
    expect_true(grepl('env', txt, fixed = TRUE))
})

# ---- .askllm_test_connection_text:組裝(spec/金鑰/ping)三段流程 -------------

test_that('custom provider 缺 baseUrl → 顯示 spec 錯誤,不呼叫 ping', {
    opt <- list(provider = 'custom', baseUrl = '', model = '')
    txt <- .askllm_test_connection_text(opt)
    expect_true(grepl('custom provider 需要填寫', txt, fixed = TRUE))
})

test_that('缺金鑰的 provider → 顯示 key_setup_text,不呼叫 ping', {
    opt <- list(provider = 'nim', baseUrl = '', model = '')
    testthat::local_mocked_bindings(
        load_api_key = function(env_vars) NULL)
    txt <- .askllm_test_connection_text(opt)
    expect_true(grepl('尚未設定', txt, fixed = TRUE))
})

test_that('金鑰存在 → 呼叫 ping_endpoint 並回傳雙語結果(mock 金鑰與 ping)', {
    opt <- list(provider = 'nim', baseUrl = '', model = '')
    testthat::local_mocked_bindings(
        load_api_key = function(env_vars) list(key = 'FAKEKEY', source = 'env'),
        ping_endpoint = function(...) list(ok = TRUE, status = 200, kind = 'reachable',
                                            body = '{}', message = NULL))
    txt <- .askllm_test_connection_text(opt)
    expect_true(grepl('端點可連線', txt, fixed = TRUE))
    expect_true(grepl('env', txt, fixed = TRUE))
})

test_that('ollama 免金鑰 → 不呼叫 load_api_key,直接 ping', {
    opt <- list(provider = 'ollama', baseUrl = '', model = '')
    called_load_key <- FALSE
    testthat::local_mocked_bindings(
        load_api_key = function(env_vars) { called_load_key <<- TRUE; NULL },
        ping_endpoint = function(...) list(ok = TRUE, status = 200, kind = 'reachable',
                                            body = '{}', message = NULL))
    txt <- .askllm_test_connection_text(opt)
    expect_false(called_load_key)
    expect_true(grepl('本機服務可連線', txt, fixed = TRUE))
    expect_true(grepl('免金鑰', txt, fixed = TRUE))
})
