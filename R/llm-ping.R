# R/llm-ping.R — 項目 3:Test Connection 非課金疎通檢查(單一職責,純函式)
#
# 一律對 {base_url}/models 發 GET(OpenAI 相容目錄端點,任何 provider 皆零計費)。
# 判讀規則(規格見 dev-notes/execution-plan.zh-TW.md 項目 3,2026-07-29 spike
# 結果表定案):共用預設 + per-provider override。
#
#   共用預設:200 → 通(needs_key 時視為金鑰有效,否則僅通);
#             401 → 金鑰無效;403 → 權限不足;連線失敗/timeout → 網路問題
#   github override:404(body 含 "page not found")→ 視為金鑰有效,通;
#                    401 → 未授權。不 fallback 到 catalog URL。
#   gemini override:400 且 body 含 "api key"(不分大小寫)→ 金鑰無效,
#                    而非落入預設的「其他狀態碼」桶。
#   nim/openrouter/custom override:/models 公開、不驗證金鑰,200 只代表
#                    「端點可連線」,絕不可宣稱「金鑰有效」。
#   ollama override:needs_key=FALSE,連線失敗 → 「本機服務未啟動」
#                    (kind='no_service',與其他 provider 的 'network' 分開)。
#
# 設計原則:ping_endpoint() 永不 stop();對外一律回傳結構化 list。

#' 真實 transport(httr2 實作,供 ping_endpoint() 預設使用)
#'
#' @param url 完整請求 URL
#' @param headers 具名 list,將逐一附加為 request header
#' @param timeout 逾時秒數
#' @return list(status = <int|NA>, body = <chr|NULL>, error = <chr|NULL>)
#' @keywords internal
.ping_transport <- function(url, headers, timeout = 10) {
    req <- httr2::request(url)
    req <- httr2::req_timeout(req, timeout)
    # 4xx/5xx 不拋例外,直接讀 status(判讀邏輯需要區分 401/403/404 等)
    req <- httr2::req_error(req, is_error = function(resp) FALSE)
    if (length(headers) > 0) {
        req <- do.call(httr2::req_headers, c(list(req), headers))
    }

    tryCatch({
        resp <- httr2::req_perform(req)
        status <- httr2::resp_status(resp)
        body <- tryCatch(httr2::resp_body_string(resp), error = function(e) NULL)
        list(status = status, body = body, error = NULL)
    }, error = function(e) {
        list(status = NA_integer_, body = NULL, error = conditionMessage(e))
    })
}

#' 把 status/body 組成適合 [translate_error()] 既有 regex 判讀的合成訊息
#' @keywords internal
.ping_synthesize_msg <- function(status, body) {
    if (is.na(status)) return(body %||% '連線失敗')
    paste0('HTTP ', status, if (!is.null(body) && nzchar(body)) paste0(' - ', body) else '')
}

#' 共用預設 + per-provider override 判讀表
#'
#' @return list(ok = <lgl>, kind = <chr(1)>)
#' @keywords internal
.ping_classify <- function(provider, needs_key, status, body) {
    low_body <- tolower(body %||% '')

    if (identical(provider, 'github')) {
        if (!is.na(status) && status == 404 && grepl('page not found', low_body)) {
            return(list(ok = TRUE, kind = 'valid_key'))
        }
        if (!is.na(status) && status == 401) {
            return(list(ok = FALSE, kind = 'invalid_key'))
        }
    } else if (identical(provider, 'gemini')) {
        if (!is.na(status) && status == 400 && grepl('api key', low_body)) {
            return(list(ok = FALSE, kind = 'invalid_key'))
        }
    } else if (provider %in% c('nim', 'openrouter', 'custom')) {
        if (!is.na(status) && status == 200) {
            return(list(ok = TRUE, kind = 'reachable'))
        }
    } else if (identical(provider, 'ollama')) {
        if (is.na(status)) return(list(ok = FALSE, kind = 'no_service'))
        if (status == 200) return(list(ok = TRUE, kind = 'reachable'))
    }

    # 共用預設(未被上面任何 override 攔截時落到這裡)
    if (is.na(status)) return(list(ok = FALSE, kind = 'network'))
    if (status == 200) {
        return(list(ok = TRUE, kind = if (isTRUE(needs_key)) 'valid_key' else 'reachable'))
    }
    if (status == 401) return(list(ok = FALSE, kind = 'invalid_key'))
    if (status == 403) return(list(ok = FALSE, kind = 'forbidden'))
    list(ok = FALSE, kind = 'network')
}

#' 疎通檢查(對 {base_url}/models 發 GET,不產生 completion 計費)
#'
#' @param provider provider 代碼('nim'/'gemini'/'openrouter'/'github'/'ollama'/'custom')
#' @param base_url OpenAI 相容端點(不含 /models)
#' @param api_key 金鑰字串;needs_key=FALSE 時可為空字串,不會被使用
#' @param needs_key 此 provider 是否需要金鑰(決定是否附 Authorization header)
#' @param timeout 逾時秒數(預設 10)
#' @param transport 可注入的 transport 函式,測試以假實作繞過真實網路;
#'   簽名須為 `function(url, headers, timeout)`,回傳
#'   `list(status, body, error)`
#' @return list(ok = <lgl>, status = <int|NA>, kind = <chr(1)>,
#'   body = <chr|NULL>, message = <chr|NULL,僅 ok=FALSE 時給友善訊息>)
#' @export
ping_endpoint <- function(provider, base_url, api_key, needs_key,
                          timeout = 10, transport = .ping_transport) {
    url <- paste0(sub('/+$', '', base_url %||% ''), '/models')

    headers <- list()
    if (isTRUE(needs_key) && nzchar(api_key %||% '')) {
        headers[['Authorization']] <- paste('Bearer', api_key)
    }

    raw <- tryCatch(
        transport(url, headers, timeout),
        error = function(e) list(status = NA_integer_, body = NULL,
                                 error = conditionMessage(e)))

    cls <- .ping_classify(provider, needs_key, raw$status, raw$body)

    message <- NULL
    if (!isTRUE(cls$ok)) {
        synth <- if (!is.null(raw$error) && nzchar(raw$error)) {
            raw$error
        } else {
            .ping_synthesize_msg(raw$status, raw$body)
        }
        message <- translate_error(synth, base_url %||% '')
    }

    list(ok = isTRUE(cls$ok), status = raw$status, kind = cls$kind,
        body = raw$body, message = message)
}

#' provider 分組:是否屬於「/models 公開、不驗證金鑰」一類
#' @keywords internal
.ping_unverified_providers <- c('nim', 'openrouter', 'custom')

#' 把 [ping_endpoint()] 結果組成雙語顯示文字(繁中 + 英文對照)
#'
#' 誠實分級(作者裁決,見 dev-notes/execution-plan.zh-TW.md 項目 3):
#'   - nim/openrouter/custom:成功只能說「端點可連線」,嚴禁寫「金鑰有效」
#'   - gemini/github:成功可明確說「金鑰有效」(400/404 各自的鑑別力已由
#'     spike 驗證)
#'   - ollama:免金鑰,只問本機服務是否可連線
#'   - 其餘未特別文案的組合(forbidden/network 等)沿用 [translate_error()]
#'     產出的中文訊息(與既有錯誤訊息文案風格一致,不強行雙語化)
#'
#' @param res [ping_endpoint()] 的回傳值
#' @param provider provider 代碼
#' @param provider_name 顯示名稱(見 `.askllm_provider_name()`)
#' @param needs_key 此 provider 是否需要金鑰
#' @param key_source 金鑰來源(`load_api_key()$source`);needs_key=FALSE 時忽略
#' @return `character(1)` 雙語結果文字
.askllm_ping_text <- function(res, provider, provider_name, needs_key,
                              key_source = NULL) {
    result_line <- .askllm_ping_result_line(res, provider)

    key_line <- if (!isTRUE(needs_key)) {
        paste('金鑰來源:免金鑰', 'Key source: no API key required', sep = '\n')
    } else {
        src <- key_source %||% '未知'
        paste(sprintf('金鑰來源:%s', src), sprintf('Key source: %s', src), sep = '\n')
    }

    paste(result_line, '', key_line, sep = '\n')
}

#' @keywords internal
.askllm_ping_result_line <- function(res, provider) {
    ok <- isTRUE(res$ok)
    kind <- res$kind

    if (provider %in% .ping_unverified_providers && ok && identical(kind, 'reachable')) {
        return(paste(
            '✓ 端點可連線(此供應商的 /models 不驗證金鑰,無法確認金鑰本身有效)',
            "✓ Endpoint reachable (this provider's /models endpoint does not",
            '  validate the key, so key validity cannot be confirmed)',
            sep = '\n'))
    }

    if (identical(provider, 'gemini')) {
        if (ok && identical(kind, 'valid_key')) {
            return(paste('✓ 金鑰有效', '✓ API key is valid', sep = '\n'))
        }
        if (!ok && identical(kind, 'invalid_key')) {
            status_disp <- if (is.null(res$status) || is.na(res$status)) '400' else res$status
            return(paste(
                sprintf('✗ 金鑰無效(%s)', status_disp),
                sprintf('✗ Invalid API key (%s)', status_disp),
                sep = '\n'))
        }
    }

    if (identical(provider, 'github')) {
        if (ok && identical(kind, 'valid_key')) {
            status_disp <- if (is.null(res$status) || is.na(res$status)) '404' else res$status
            return(paste(
                sprintf('✓ 金鑰有效(%s)', status_disp),
                sprintf('✓ API key is valid (%s)', status_disp),
                sep = '\n'))
        }
        if (!ok && identical(kind, 'invalid_key')) {
            status_disp <- if (is.null(res$status) || is.na(res$status)) '401' else res$status
            return(paste(
                sprintf('✗ 未授權(%s)', status_disp),
                sprintf('✗ Unauthorized (%s)', status_disp),
                sep = '\n'))
        }
    }

    if (identical(provider, 'ollama')) {
        if (ok && identical(kind, 'reachable')) {
            return(paste('✓ 本機服務可連線',
                         '✓ Local service is reachable', sep = '\n'))
        }
        if (!ok && identical(kind, 'no_service')) {
            return(paste('✗ 服務未啟動',
                         '✗ Service is not running', sep = '\n'))
        }
    }

    # 通用後備(forbidden / network,或未預期組合):沿用 translate_error 訊息
    msg <- res$message %||% '連線檢查失敗'
    paste0('✗ ', msg)
}

#' Test Connection 分支的組裝流程(供 `.runInner()` 呼叫,亦供測試離線驗證)
#'
#' 依序:1) 解析 provider spec(custom 缺 baseUrl 時直接回錯誤說明);
#' 2) needs_key 時載入金鑰(找不到則回 `key_setup_text()`,ollama 免金鑰跳過);
#' 3) 呼叫 [ping_endpoint()] 並組成雙語結果文字。全程不 stop()。
#'
#' @param opt 具 `provider`/`baseUrl`/`model` 欄位的 list(或 jmvcore Options)
#' @return `character(1)` 供 `instructions$setContent()` 顯示的文字
.askllm_test_connection_text <- function(opt) {
    spec <- provider_spec(opt$provider, opt$baseUrl)
    if (!is.null(spec$error)) {
        return(paste0(spec$error, '\n\n',
            '請在選項的「Base URL (custom provider)」欄位填入自訂端點,',
            '再重新勾選 Test Connection。'))
    }

    provider_name <- .askllm_provider_name(opt$provider)

    api_key <- ''
    key_source <- NULL
    if (isTRUE(spec$needs_key)) {
        kv <- load_api_key(spec$env_vars)
        if (is.null(kv)) {
            return(key_setup_text(provider_name, spec$env_vars[1],
                spec$signup_url, spec$key_example %||% '<your-api-key>'))
        }
        api_key <- kv$key
        key_source <- kv$source
    }

    res <- ping_endpoint(opt$provider, spec$base_url, api_key, spec$needs_key)
    .askllm_ping_text(res, opt$provider, provider_name, spec$needs_key, key_source)
}
