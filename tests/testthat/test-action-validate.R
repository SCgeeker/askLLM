# test-action-validate.R — Phase 1:validate_plan() jmv 白名單驗證(純函式)
#
# 契約:validate_plan(plan, colnames) -> list(actions, rejected, notes)
#   兩種處置分明:
#     - 參數名不在白名單     → 剝除該參數 + note(action 仍執行)
#     - 值致命錯(欄名不存在、flag 給字串、enum 非法) → 拒絕整個 action + reason
#   白名單 7 分析:descriptives/ttestIS/ttestPS/ttestOneS/anovaOneW/
#                 corrMatrix/contTables。絕不 eval、絕不拼字串進 parse。
#
# 設計原則:純函式、永不 stop()、對外回傳結構化 list。

cn <- c('score', 'age', 'gender', 'group')  # 測試用資料集欄名

.mk_action <- function(analysis, args, type = 'run_analysis')
    list(type = type, analysis = analysis, args = args, rationale = 'r')

.mk_plan <- function(...) list(ok = TRUE, reply = 'r',
                               actions = list(...), error = NULL)

# ---- 全通過:clean args 逐項正確 -------------------------------------------

test_that('合法 ttestIS(vars/group/welchs):通過,clean args 正確', {
    plan <- .mk_plan(.mk_action('ttestIS',
        list(vars = list('score'), group = 'gender', welchs = TRUE)))
    got <- validate_plan(plan, cn)
    expect_length(got$actions, 1)
    expect_length(got$rejected, 0)
    a <- got$actions[[1]]
    expect_identical(a$analysis, 'ttestIS')
    expect_identical(a$args$group, 'gender')
    expect_true(isTRUE(a$args$welchs))
})

# ---- 分析不在白名單 → 拒絕 -------------------------------------------------

test_that('分析不在白名單(linReg):整個 action 被拒', {
    plan <- .mk_plan(.mk_action('linReg', list(dep = 'score')))
    got <- validate_plan(plan, cn)
    expect_length(got$actions, 0)
    expect_length(got$rejected, 1)
    expect_true(nzchar(got$rejected[[1]]$reason))
})

# ---- 未知參數 → 剝除(action 仍執行) ---------------------------------------

test_that('未知參數(bogusOpt)被剝除,合法參數保留,action 仍通過', {
    plan <- .mk_plan(.mk_action('descriptives',
        list(vars = list('score'), bogusOpt = TRUE)))
    got <- validate_plan(plan, cn)
    expect_length(got$actions, 1)
    expect_null(got$actions[[1]]$args$bogusOpt)          # 已剝除
    expect_identical(got$actions[[1]]$args$vars, 'score')  # colnames→字元向量(jmv 就緒)
    expect_true(length(got$notes) >= 1)                  # 有剝除 note
})

# ---- 欄名不存在 → 拒絕 -----------------------------------------------------

test_that('colname 型參數指向不存在欄(group=nope):整個 action 被拒', {
    plan <- .mk_plan(.mk_action('ttestIS',
        list(vars = list('score'), group = 'nope')))
    got <- validate_plan(plan, cn)
    expect_length(got$actions, 0)
    expect_length(got$rejected, 1)
})

test_that('colnames 型參數含不存在欄(vars 含 nope):整個 action 被拒', {
    plan <- .mk_plan(.mk_action('descriptives',
        list(vars = list('score', 'nope'))))
    got <- validate_plan(plan, cn)
    expect_length(got$actions, 0)
    expect_length(got$rejected, 1)
})

# ---- flag 給非 logical → 拒絕 ----------------------------------------------

test_that('flag 參數給字串(welchs="yes"):整個 action 被拒', {
    plan <- .mk_plan(.mk_action('ttestIS',
        list(vars = list('score'), group = 'gender', welchs = 'yes')))
    got <- validate_plan(plan, cn)
    expect_length(got$actions, 0)
    expect_length(got$rejected, 1)
})

# ---- enum 驗證 -------------------------------------------------------------

test_that('enum 合法值(phMethod=tukey)通過;非法值(bogus)被拒', {
    ok_plan <- .mk_plan(.mk_action('anovaOneW',
        list(deps = list('score'), group = 'gender', phMethod = 'tukey')))
    expect_length(validate_plan(ok_plan, cn)$actions, 1)

    bad_plan <- .mk_plan(.mk_action('anovaOneW',
        list(deps = list('score'), group = 'gender', phMethod = 'bogus')))
    got <- validate_plan(bad_plan, cn)
    expect_length(got$actions, 0)
    expect_length(got$rejected, 1)
})

# ---- 非 run_analysis 類型 → 拒絕(Phase 1 只支援執行分析) -------------------

test_that('type 非 run_analysis(compute_column):Phase 1 拒絕', {
    plan <- .mk_plan(.mk_action('descriptives', list(vars = list('score')),
                                type = 'compute_column'))
    got <- validate_plan(plan, cn)
    expect_length(got$actions, 0)
    expect_length(got$rejected, 1)
})

# ---- 混合:一拒一過,各就各位 ----------------------------------------------

test_that('多動作混合:合法者入 actions,非法者入 rejected', {
    plan <- .mk_plan(
        .mk_action('descriptives', list(vars = list('age'))),      # 過
        .mk_action('ttestIS', list(vars = list('score'), group = 'nope')))  # 拒
    got <- validate_plan(plan, cn)
    expect_length(got$actions, 1)
    expect_length(got$rejected, 1)
    expect_identical(got$actions[[1]]$analysis, 'descriptives')
})

# ---- 空動作清單(純諮詢)---------------------------------------------------

test_that('空動作清單:actions 與 rejected 皆空,不報錯', {
    got <- validate_plan(.mk_plan(), cn)
    expect_length(got$actions, 0)
    expect_length(got$rejected, 0)
})

# ---- compute_column(Phase 2):公式 AST + 欄名 + measureType 驗證 -----------

test_that('合法 compute_column 通過,clean 欄位正確', {
    cc <- list(type = 'compute_column', column_name = 'bmi',
               measure_type = 'continuous',
               formula = 'weight / (height / 100)^2', rationale = '算 BMI')
    got <- validate_plan(.mk_plan(cc), c('weight', 'height'))
    expect_length(got$actions, 1)
    expect_length(got$rejected, 0)
    a <- got$actions[[1]]
    expect_identical(a$type, 'compute_column')
    expect_identical(a$column_name, 'bmi')
    expect_identical(a$formula, 'weight / (height / 100)^2')
    expect_identical(a$measure_type, 'continuous')
})

test_that('compute_column 公式含未知變數 → 拒', {
    cc <- list(type = 'compute_column', column_name = 'x',
               measure_type = 'continuous',
               formula = 'weight / nonexist', rationale = 'r')
    got <- validate_plan(.mk_plan(cc), c('weight'))
    expect_length(got$actions, 0)
    expect_length(got$rejected, 1)
})

test_that('compute_column 危險公式 → 拒', {
    cc <- list(type = 'compute_column', column_name = 'x',
               measure_type = 'continuous',
               formula = 'system("rm -rf")', rationale = 'r')
    expect_length(validate_plan(.mk_plan(cc), c('weight'))$actions, 0)
})

test_that('compute_column 欄名空或非法識別字 → 拒', {
    cc1 <- list(type = 'compute_column', column_name = '',
                measure_type = 'continuous', formula = 'weight * 2', rationale = 'r')
    expect_length(validate_plan(.mk_plan(cc1), c('weight'))$actions, 0)
    cc2 <- list(type = 'compute_column', column_name = '1 bad!',
                measure_type = 'continuous', formula = 'weight * 2', rationale = 'r')
    expect_length(validate_plan(.mk_plan(cc2), c('weight'))$actions, 0)
})

test_that('compute_column measure_type 非法 → 拒;空 → 預設 continuous', {
    bad <- list(type = 'compute_column', column_name = 'x',
                measure_type = 'bogus', formula = 'weight * 2', rationale = 'r')
    expect_length(validate_plan(.mk_plan(bad), c('weight'))$actions, 0)
    empty <- list(type = 'compute_column', column_name = 'x',
                  measure_type = '', formula = 'weight * 2', rationale = 'r')
    g <- validate_plan(.mk_plan(empty), c('weight'))
    expect_length(g$actions, 1)
    expect_identical(g$actions[[1]]$measure_type, 'continuous')
})
