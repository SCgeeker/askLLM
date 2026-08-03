# action-schema.R — Phase 1 動作計畫解析(純函式)
#
# parse_plan():把 LLM 回傳(structured 路徑的已解析 R list,或降級路徑的 JSON
# 字串)正規化為統一結構,供 validate_plan()/執行器使用。只做「結構正規化」,
# 不做白名單(白名單留給 validate_plan)。
#
# 共同契約(比照 data-summary.R / module-catalog.R):純函式、永不 stop()
# (一切失敗以回傳值表達)、可離線單元測試。

#' 解析並正規化動作計畫
#'
#' @param raw structured 路徑的已解析 R list(其中 `action$args` 為 JSON 字串),
#'   或降級路徑的整包 JSON 字串。
#' @param max_actions 動作數上限(超過則截斷,防 prompt injection 濫炸)。
#' @return `list(ok, reply, actions, error)`。`actions` 每項為
#'   `list(type, analysis, args = <named list>, rationale)`。
parse_plan <- function(raw, max_actions = 3) {
    fail <- function(msg) list(ok = FALSE, reply = '', actions = list(), error = msg)

    # 1. 取得 plan list:字串→fromJSON;list→原樣;其餘型別→失敗
    if (is.character(raw) && length(raw) == 1L) {
        parsed <- tryCatch(
            jsonlite::fromJSON(raw, simplifyVector = FALSE),
            error = function(e) e)
        if (inherits(parsed, 'condition'))
            return(fail(paste0('動作計畫 JSON 解析失敗:', conditionMessage(parsed))))
        plan <- parsed
    } else if (is.list(raw)) {
        plan <- raw
    } else {
        return(fail('動作計畫格式不支援(需 list 或 JSON 字串)'))
    }
    if (!is.list(plan)) return(fail('動作計畫解析後非 list'))

    # 2. reply(缺或非單一字串→空字串)
    reply <- plan$reply %||% ''
    if (!is.character(reply) || length(reply) != 1L) reply <- ''

    # 3. actions(缺/空→合法純諮詢回覆)
    raw_actions <- plan$actions
    # ellmer chat_structured 對 type_array(type_object) 回 data.frame/tibble
    # (每列一動作,scalar 欄);須逐列轉 list,否則下方 lapply 會把「欄」誤當動作
    # (2026-08-02 E2E bug:4 欄被 max_actions 截成 3 個空動作)。
    if (is.data.frame(raw_actions))
        raw_actions <- lapply(seq_len(nrow(raw_actions)),
                              function(i) as.list(raw_actions[i, , drop = FALSE]))
    if (is.null(raw_actions) || !is.list(raw_actions) || length(raw_actions) == 0L)
        return(list(ok = TRUE, reply = reply, actions = list(), error = NULL))

    if (length(raw_actions) > max_actions)
        raw_actions <- raw_actions[seq_len(max_actions)]

    actions <- lapply(raw_actions, .normalize_action)
    list(ok = TRUE, reply = reply, actions = actions, error = NULL)
}

#' 正規化單一 action:type/analysis/rationale 轉字元,args 統一成 named list
#'
#' args 兩種來源:structured 路徑為 JSON 字串(fromJSON);降級整包解析後已是
#' nested list(原樣)。解析失敗或缺欄→空 list(由 validate_plan 因缺必要參數處理)。
#' @keywords internal
.normalize_action <- function(a) {
    if (!is.list(a)) a <- list()
    args_raw <- a$args
    args <- if (is.character(args_raw) && length(args_raw) == 1L) {
        tryCatch(jsonlite::fromJSON(args_raw, simplifyVector = FALSE),
                 error = function(e) list())
    } else if (is.list(args_raw)) {
        args_raw
    } else {
        list()
    }
    if (!is.list(args)) args <- list()
    list(
        type      = .yaml_chr(a$type) %||% '',
        analysis  = .yaml_chr(a$analysis) %||% '',
        args      = args,
        rationale = .yaml_chr(a$rationale) %||% '')
}

#' 以三段降級鏈向 LLM 取得動作計畫
#'
#' 段1 `chat$chat_structured()`(需 provider 支援 json_schema)→ 段2 純文字
#' 要求 JSON → 段3 純文字降級(當現行諮詢回覆)。無論走哪條路,安全邊界都在
#' 後續 validate_plan,不在此。永不 stop()。
#'
#' @param chat 具 `$chat(prompt)`、可能具 `$chat_structured(prompt, type)` 的物件。
#' @param prompt user prompt。
#' @param action_type ellmer type 物件(段1 用);由呼叫端建構後傳入。
#' @param max_actions 透傳 [parse_plan()]。
#' @return `list(ok, reply, actions, error, method)`,`method` ∈
#'   `structured`/`json`/`text`。
ask_llm_structured <- function(chat, prompt, action_type = NULL, max_actions = 3) {
    # 段1:chat_structured(provider 支援時)
    cs <- tryCatch(chat$chat_structured, error = function(e) NULL)
    if (is.function(cs)) {
        r <- tryCatch(cs(prompt, type = action_type), error = function(e) e)
        if (!inherits(r, 'condition')) {
            p <- parse_plan(r, max_actions = max_actions)
            if (isTRUE(p$ok)) { p$method <- 'structured'; return(p) }
        }
    }
    # 段2:純文字要求 JSON
    json_prompt <- paste0(prompt,
        '\n\nRespond ONLY with a single JSON object matching the action-plan ',
        'schema (keys: reply, actions). No prose outside the JSON.')
    r2 <- tryCatch(chat$chat(json_prompt), error = function(e) e)
    if (!inherits(r2, 'condition')) {
        txt <- tryCatch(as.character(r2), error = function(e) '')
        p <- parse_plan(txt, max_actions = max_actions)
        if (isTRUE(p$ok)) { p$method <- 'json'; return(p) }
        # 段3:段2 文字非合法 JSON → 當純文字諮詢回覆
        return(list(ok = TRUE, reply = txt, actions = list(),
                    error = NULL, method = 'text'))
    }
    # 段2 亦 throw:段3 空 reply(仍不 stop)
    list(ok = TRUE, reply = '', actions = list(), error = NULL, method = 'text')
}

#' Phase 1 動作計畫的 ellmer 結構化輸出 schema
#'
#' 扁平設計(見 dev-notes v1.2 §4.2):`args` 因各分析不同,以 JSON 物件字串傳
#' (parse_plan 再 fromJSON),避免 ellmer 對 open-ended object 的相容性問題。
#' Phase 1 `type` 僅 `run_analysis`。ellmer 0.4.x type API:
#'   type_object(.description, ...properties)、type_array(items)、
#'   type_enum(values)、type_string(description, required)。
#' @return ellmer type 物件,供 `chat$chat_structured(type = ...)`。
.askllm_action_type <- function() {
    ellmer::type_object(
        .description = "An assistant reply plus zero or more actions.",
        reply = ellmer::type_string(
            "A concise reply to the user, in the assistant's persona voice."),
        actions = ellmer::type_array(
            description = "Actions to take; empty if the reply alone suffices.",
            items = ellmer::type_object(
                type = ellmer::type_enum(
                    values = c('run_analysis', 'compute_column'),
                    description = "Action type."),
                analysis = ellmer::type_string(
                    "For run_analysis: jmv function name, e.g. descriptives, ttestIS.",
                    required = FALSE),
                args = ellmer::type_string(
                    "For run_analysis: arguments as a JSON object string, e.g. {\"vars\":[\"x\"]}.",
                    required = FALSE),
                column_name = ellmer::type_string(
                    "For compute_column: the new column's name (a valid identifier).",
                    required = FALSE),
                measure_type = ellmer::type_enum(
                    values = c('continuous', 'ordinal', 'nominal'),
                    description = "For compute_column: the column's measure type.",
                    required = FALSE),
                formula = ellmer::type_string(
                    "For compute_column: an R expression over EXISTING column names only.",
                    required = FALSE),
                rationale = ellmer::type_string(
                    "Why this action answers the question.",
                    required = FALSE))))
}
