# test-action-structured.R — Phase 1:ask_llm_structured() 三段降級鏈
#
# 契約:ask_llm_structured(chat, prompt, action_type = NULL, max_actions = 3)
#   段1:chat$chat_structured(prompt, type=action_type) -> R list -> parse_plan
#   段2:(無 chat_structured 或段1 失敗)chat$chat(prompt+JSON指示) -> 字串 -> parse_plan
#   段3:(段2 亦非合法 JSON)純文字降級:reply=該文字,actions 空(現行諮詢模式)
#   回傳 parse_plan 結構 + $method('structured'/'json'/'text')。永不 stop()。
#
# 以 ctor 注入假 chat(list of closures)離線測;不碰 ellmer/網路。

# ---- 段1:chat_structured 成功 ---------------------------------------------

test_that('段1:chat_structured 回合法 list → method=structured,actions 解析', {
    fake_chat <- list(
        chat_structured = function(prompt, type = NULL) list(
            reply = 'done',
            actions = list(list(type = 'run_analysis', analysis = 'descriptives',
                                args = '{"vars":["x"]}', rationale = 'r'))),
        chat = function(prompt) stop('should not reach chat()'))
    got <- ask_llm_structured(fake_chat, 'Q')
    expect_identical(got$method, 'structured')
    expect_true(got$ok)
    expect_length(got$actions, 1)
    expect_identical(got$actions[[1]]$analysis, 'descriptives')
})

# ---- 段2:無 chat_structured → 純文字 JSON --------------------------------

test_that('段2:chat 無 chat_structured,chat() 回 JSON 字串 → method=json', {
    fake_chat <- list(
        chat = function(prompt) paste0('{"reply":"ok","actions":[',
            '{"type":"run_analysis","analysis":"ttestIS",',
            '"args":{"vars":["y"],"group":"g"},"rationale":"r"}]}'))
    got <- ask_llm_structured(fake_chat, 'Q')
    expect_identical(got$method, 'json')
    expect_true(got$ok)
    expect_identical(got$actions[[1]]$analysis, 'ttestIS')
})

# ---- 段1 throw → 落段2 -----------------------------------------------------

test_that('段1 chat_structured throw → 落段2 JSON', {
    fake_chat <- list(
        chat_structured = function(prompt, type = NULL) stop('no json_schema support'),
        chat = function(prompt) '{"reply":"fallback","actions":[]}')
    got <- ask_llm_structured(fake_chat, 'Q')
    expect_identical(got$method, 'json')
    expect_true(got$ok)
    expect_identical(got$reply, 'fallback')
    expect_length(got$actions, 0)
})

# ---- 段3:兩段都非 JSON → 純文字降級 --------------------------------------

test_that('段3:chat 回純文字(非 JSON) → method=text,文字入 reply,actions 空', {
    fake_chat <- list(
        chat = function(prompt) '這是一段純文字建議,不是 JSON。')
    got <- ask_llm_structured(fake_chat, 'Q')
    expect_identical(got$method, 'text')
    expect_true(got$ok)
    expect_identical(got$reply, '這是一段純文字建議,不是 JSON。')
    expect_length(got$actions, 0)
})

# ---- 段1 與段2 皆 throw → 段3 空 reply,仍不 stop --------------------------

test_that('chat_structured 與 chat 皆 throw → method=text,ok=TRUE,reply 空', {
    fake_chat <- list(
        chat_structured = function(prompt, type = NULL) stop('boom1'),
        chat = function(prompt) stop('boom2'))
    got <- ask_llm_structured(fake_chat, 'Q')
    expect_identical(got$method, 'text')
    expect_true(got$ok)
    expect_identical(got$reply, '')
})

# ---- max_actions 透傳 ------------------------------------------------------

test_that('max_actions 透傳給 parse_plan(截斷)', {
    mk <- function(i) list(type = 'run_analysis', analysis = 'descriptives',
                           args = '{"vars":["x"]}', rationale = as.character(i))
    fake_chat <- list(
        chat_structured = function(prompt, type = NULL)
            list(reply = 'r', actions = lapply(1:5, mk)))
    got <- ask_llm_structured(fake_chat, 'Q', max_actions = 2)
    expect_length(got$actions, 2)
})

# ---- action_type schema 建構(smoke;依賴 ellmer) ---------------------------

test_that('.askllm_action_type():建構 ellmer schema 不報錯(smoke)', {
    skip_if_not_installed('ellmer')
    expect_error(t <- .askllm_action_type(), NA)
    expect_false(is.null(t))
})
