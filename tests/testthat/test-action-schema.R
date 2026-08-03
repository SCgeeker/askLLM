# test-action-schema.R — Phase 1:parse_plan() 動作計畫正規化(純函式)
#
# 契約:parse_plan(raw, max_actions = 3) -> list(ok, reply, actions, error)
#   raw 兩種來源:
#     (1) structured:已解析 R list,action$args 為 JSON 字串(我方 fromJSON)
#     (2) 降級:整包 JSON 字串(整包 fromJSON,action$args 為 nested list)
#   正規化 action: list(type, analysis, args=<named list>, rationale)
#   缺 actions -> 空清單(合法純諮詢);缺 reply -> "";非法 JSON -> ok=FALSE;
#   動作數 > max_actions -> 截斷。parse 不做白名單(留給 validate_plan)。
#
# 設計原則(比照本套件):純函式、永不 stop()、對外回傳結構化 list。

# ---- structured 路徑:已解析 list,args 為 JSON 字串 ------------------------

test_that('structured list + args(JSON 字串):正確正規化,args 被 fromJSON', {
    raw <- list(
        version = 1L,
        reply = '我幫你比較了兩組平均數。',
        actions = list(list(
            type = 'run_analysis',
            analysis = 'ttestIS',
            args = '{"vars":["score"],"group":"gender","welchs":true}',
            rationale = '兩組獨立樣本')))
    got <- parse_plan(raw)
    expect_true(got$ok)
    expect_identical(got$reply, '我幫你比較了兩組平均數。')
    expect_length(got$actions, 1)
    a <- got$actions[[1]]
    expect_identical(a$type, 'run_analysis')
    expect_identical(a$analysis, 'ttestIS')
    expect_identical(a$args$group, 'gender')
    expect_true(isTRUE(a$args$welchs))
    expect_identical(a$args$vars, list('score'))  # jsonlite 預設 array→list
})

# ---- 降級路徑:整包 JSON 字串,args 為 nested list --------------------------

test_that('整包 JSON 字串:整包 fromJSON,args 為 nested 物件亦正確', {
    raw <- paste0('{"reply":"ok","actions":[{"type":"run_analysis",',
                  '"analysis":"descriptives","args":{"vars":["age"]},',
                  '"rationale":"看分布"}]}')
    got <- parse_plan(raw)
    expect_true(got$ok)
    expect_identical(got$reply, 'ok')
    expect_length(got$actions, 1)
    expect_identical(got$actions[[1]]$analysis, 'descriptives')
    expect_identical(got$actions[[1]]$args$vars, list('age'))
})

# ---- 缺欄位的容忍 ----------------------------------------------------------

test_that('缺 actions:ok=TRUE 且 actions 為空清單(純諮詢合法)', {
    got <- parse_plan(list(reply = '只是文字回答'))
    expect_true(got$ok)
    expect_length(got$actions, 0)
    expect_identical(got$reply, '只是文字回答')
})

test_that('缺 reply:reply 落為空字串', {
    got <- parse_plan(list(actions = list()))
    expect_true(got$ok)
    expect_identical(got$reply, '')
})

# ---- 非法輸入 --------------------------------------------------------------

test_that('非法 JSON 字串:ok=FALSE 且 error 非空,永不 stop()', {
    got <- parse_plan('this is not json {{{')
    expect_false(got$ok)
    expect_true(is.character(got$error) && nzchar(got$error))
})

test_that('NULL 或不支援型別:ok=FALSE', {
    expect_false(parse_plan(NULL)$ok)
    expect_false(parse_plan(42)$ok)
})

# ---- 動作數上限 ------------------------------------------------------------

test_that('動作數超過 max_actions:截斷到上限', {
    mk <- function(i) list(type = 'run_analysis', analysis = 'descriptives',
                            args = '{"vars":["x"]}', rationale = as.character(i))
    raw <- list(reply = 'r', actions = lapply(1:5, mk))
    got <- parse_plan(raw, max_actions = 3)
    expect_true(got$ok)
    expect_length(got$actions, 3)
})

# ---- args 解析失敗的防禦 ---------------------------------------------------

test_that('action$args JSON 壞掉:該 action args 落為空 list,整體仍 ok', {
    raw <- list(reply = 'r', actions = list(list(
        type = 'run_analysis', analysis = 'descriptives',
        args = '{bad json', rationale = 'x')))
    got <- parse_plan(raw)
    expect_true(got$ok)
    expect_length(got$actions, 1)
    expect_identical(got$actions[[1]]$args, list())
})

test_that('action 無 args 欄:args 落為空 list', {
    raw <- list(reply = 'r', actions = list(list(
        type = 'run_analysis', analysis = 'descriptives', rationale = 'x')))
    got <- parse_plan(raw)
    expect_true(got$ok)
    expect_identical(got$actions[[1]]$args, list())
})

# ---- 回歸(E2E bug):ellmer chat_structured 對 type_array(type_object) 回 -----
#      data.frame(tibble),每列一動作,type 可能是 factor。parse_plan 須逐列解析,
#      不可把「欄」當動作(2026-08-02 E2E:3 空動作 = 4 欄截成 3 之誤)。

test_that('actions 為 data.frame(ellmer 實際回傳):逐列解析,factor type 轉字元', {
    raw <- list(reply = 'done', actions = data.frame(
        type      = factor(c('run_analysis', 'run_analysis')),
        analysis  = c('ttestIS', 'descriptives'),
        args      = c('{"vars":["len"],"group":"supp"}', '{"vars":["len"]}'),
        rationale = c('比較兩組', '看分布'),
        stringsAsFactors = FALSE))
    got <- parse_plan(raw)
    expect_true(got$ok)
    expect_length(got$actions, 2)
    expect_identical(got$actions[[1]]$type, 'run_analysis')   # factor → 字元
    expect_identical(got$actions[[1]]$analysis, 'ttestIS')
    expect_identical(got$actions[[1]]$args$group, 'supp')     # args JSON 字串已解析
    expect_identical(got$actions[[2]]$analysis, 'descriptives')
})

test_that('actions 為 data.frame 且列數超過 max_actions:截「列」非「欄」', {
    raw <- list(reply = 'r', actions = data.frame(
        type      = rep('run_analysis', 5),
        analysis  = rep('descriptives', 5),
        args      = rep('{"vars":["x"]}', 5),
        rationale = as.character(1:5),
        stringsAsFactors = FALSE))
    got <- parse_plan(raw, max_actions = 3)
    expect_length(got$actions, 3)
    expect_identical(got$actions[[1]]$analysis, 'descriptives')
})

# ---- 回歸(Phase 2 E2E bug):parse_plan 須保留 compute_column 專屬欄位 --------
#      .normalize_action 原只留 type/analysis/args/rationale,漏 column_name/
#      measure_type/formula → LLM 產的計算欄被 validate 當「欄名為空」拒。

test_that('parse_plan 保留 compute_column 欄位(list 來源)', {
    raw <- list(reply = 'r', actions = list(list(
        type = 'compute_column', column_name = 'bmi',
        measure_type = 'continuous', formula = 'weight/(height/100)^2',
        rationale = '算 BMI')))
    a <- parse_plan(raw)$actions[[1]]
    expect_identical(a$type, 'compute_column')
    expect_identical(a$column_name, 'bmi')
    expect_identical(a$measure_type, 'continuous')
    expect_identical(a$formula, 'weight/(height/100)^2')
})

test_that('parse_plan 保留 compute_column 欄位(data.frame 來源,含 NA 欄)', {
    raw <- list(reply = 'r', actions = data.frame(
        type = factor('compute_column'), analysis = NA_character_,
        args = NA_character_, column_name = 'dose_sq',
        measure_type = 'continuous', formula = 'dose^2', rationale = 'r',
        stringsAsFactors = FALSE))
    a <- parse_plan(raw)$actions[[1]]
    expect_identical(a$column_name, 'dose_sq')
    expect_identical(a$formula, 'dose^2')
    expect_identical(a$measure_type, 'continuous')
})
