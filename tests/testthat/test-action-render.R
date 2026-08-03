# test-action-render.R — Phase 1:.askllm_render_actions() 組報表文字(純函式)
#
# 契約:.askllm_render_actions(validated, exec_results) -> list(jmv_text, note_text, plan_text)
#   - jmv_text :成功執行的分析 asString 輸出(含分析標題)
#   - note_text:每動作「狀態 + 分析 + rationale(+失敗原因)」+ 剝除說明
#   - plan_text:被拒動作稽核(分析 + reason)
#   exec_results 與 validated$actions 同順序同長度。純函式、永不 stop()。

.vr <- function(actions = list(), rejected = list(), notes = character(0))
    list(actions = actions, rejected = rejected, notes = notes)

.ex <- function(ok, analysis, output = NULL, error = NULL)
    list(ok = ok, analysis = analysis, output = output, error = error)

# ---- 成功動作:jmv_text 含輸出,note 含 ✓ + rationale ----------------------

test_that('單一成功動作:jmv_text 含分析輸出,note 標記成功與理由', {
    validated <- .vr(actions = list(
        list(type = 'run_analysis', analysis = 'descriptives',
             args = list(vars = 'score'), rationale = '看分布')))
    exres <- list(.ex(TRUE, 'descriptives', output = 'TABLE-BODY-HERE'))
    got <- .askllm_render_actions(validated, exres)
    expect_true(grepl('descriptives', got$jmv_text, fixed = TRUE))
    expect_true(grepl('TABLE-BODY-HERE', got$jmv_text, fixed = TRUE))
    expect_true(grepl('看分布', got$note_text))
})

# ---- 失敗動作:note 含錯誤,jmv_text 不含該輸出 ----------------------------

test_that('失敗動作:note 標記失敗與 error,jmv_text 不納入', {
    validated <- .vr(actions = list(
        list(type = 'run_analysis', analysis = 'ttestIS',
             args = list(), rationale = 'r')))
    exres <- list(.ex(FALSE, 'ttestIS', error = 'jmv 執行失敗:xyz'))
    got <- .askllm_render_actions(validated, exres)
    expect_true(grepl('ttestIS', got$note_text, fixed = TRUE))
    expect_true(grepl('xyz', got$note_text, fixed = TRUE))
    expect_false(grepl('TABLE', got$jmv_text, fixed = TRUE))
})

# ---- 被拒動作:plan_text 含 reason -----------------------------------------

test_that('被拒動作:plan_text 含分析名與 reason', {
    validated <- .vr(
        rejected = list(list(
            action = list(type = 'run_analysis', analysis = 'linReg'),
            reason = '分析不在白名單:linReg')))
    got <- .askllm_render_actions(validated, list())
    expect_true(grepl('linReg', got$plan_text, fixed = TRUE))
    expect_true(grepl('白名單', got$plan_text))
})

# ---- 剝除 notes 併入 note_text --------------------------------------------

test_that('validate 的剝除 notes 併入 note_text', {
    validated <- .vr(
        actions = list(list(type = 'run_analysis', analysis = 'descriptives',
                            args = list(vars = 'score'), rationale = 'r')),
        notes = 'descriptives:剝除未知參數 bogus')
    exres <- list(.ex(TRUE, 'descriptives', output = 'X'))
    got <- .askllm_render_actions(validated, exres)
    expect_true(grepl('剝除未知參數 bogus', got$note_text))
})

# ---- 空計畫:三段皆空字串,不報錯 ------------------------------------------

test_that('無動作無被拒:三段皆空字串', {
    got <- .askllm_render_actions(.vr(), list())
    expect_identical(got$jmv_text, '')
    expect_identical(got$plan_text, '')
})

# ---- compute_column 呈現(Phase 2):計算欄進 note,不進表格區 ----------------

test_that('compute_column 成功:note 標記建立計算欄,jmv_text 不納入', {
    validated <- .vr(actions = list(list(
        type = 'compute_column', column_name = 'bmi',
        measure_type = 'continuous', formula = 'weight/(height/100)^2',
        rationale = '算 BMI')))
    exres <- list(list(ok = TRUE, type = 'compute_column', column_name = 'bmi',
                       measure_type = 'continuous', value = c(22, 24), error = NULL))
    got <- .askllm_render_actions(validated, exres)
    expect_true(grepl('計算欄 bmi', got$note_text))
    expect_true(grepl('算 BMI', got$note_text))
    expect_identical(got$jmv_text, '')          # 計算欄不進表格區
})

test_that('compute_column 失敗:note 標記失敗與 error', {
    validated <- .vr(actions = list(list(
        type = 'compute_column', column_name = 'z',
        measure_type = 'continuous', formula = 'mean(w)', rationale = 'r')))
    exres <- list(list(ok = FALSE, type = 'compute_column',
                       column_name = 'z', error = '結果長度不符'))
    got <- .askllm_render_actions(validated, exres)
    expect_true(grepl('z', got$note_text))
    expect_true(grepl('結果長度不符', got$note_text))
})
