# test-action-exec.R — Phase 1:exec_analysis() 執行已驗證的 jmv 分析
#
# 契約:exec_analysis(action, data, jmv_get = NULL) -> list(ok, analysis, output, error)
#   - jmv_get:測試注入點(比照 make_chat 的 ctor);fn(analysis) -> jmv 分析函式。
#     預設從 jmv namespace 取(必要時先套 libPaths 墊片,附錄 A 定位法)。
#   - do.call(fn, c(list(data=data), args)) 包 tryCatch;取結果 asString() 拼裝。
#   - 永不 stop():一切失敗以 ok=FALSE + error 表達。
#
# 純函式(對注入的 jmv_get 而言);離線以假 jmv 驗證,另備 live 實跑(預設 skip)。

# ---- 核心:do.call 帶正確參數,asString 拼裝 -------------------------------

test_that('exec_analysis:do.call 帶 data + args,輸出含 asString 結果', {
    action <- list(type = 'run_analysis', analysis = 'descriptives',
                   args = list(vars = list('score', 'age')), rationale = 'r')
    fake_get <- function(name) {
        function(data, ...) {
            a <- list(...)
            list(asString = function()
                paste0('RES:', name, '|nrow=', nrow(data),
                       '|vars=', paste(unlist(a$vars), collapse = ',')))
        }
    }
    got <- exec_analysis(action, data.frame(score = 1:3, age = 4:6),
                         jmv_get = fake_get)
    expect_true(got$ok)
    expect_identical(got$analysis, 'descriptives')
    expect_true(grepl('RES:descriptives', got$output, fixed = TRUE))
    expect_true(grepl('vars=score,age', got$output, fixed = TRUE))
    expect_true(grepl('nrow=3', got$output, fixed = TRUE))
})

# ---- jmv 函式 throw → 降級 -------------------------------------------------

test_that('exec_analysis:jmv 執行 throw → ok=FALSE,error 非空,永不 stop', {
    action <- list(type = 'run_analysis', analysis = 'ttestIS',
                   args = list(vars = list('x')))
    boom_get <- function(name) function(data, ...) stop('boom inside jmv')
    got <- exec_analysis(action, data.frame(x = 1:3), jmv_get = boom_get)
    expect_false(got$ok)
    expect_true(is.character(got$error) && nzchar(got$error))
    expect_true(grepl('boom inside jmv', got$error))
})

test_that('exec_analysis:無法取得分析函式 → ok=FALSE', {
    action <- list(type = 'run_analysis', analysis = 'descriptives', args = list())
    null_get <- function(name) stop('not found')
    got <- exec_analysis(action, data.frame(x = 1), jmv_get = null_get)
    expect_false(got$ok)
    expect_true(nzchar(got$error))
})

# ---- live:真跑 jmv(預設 skip,設 ASKLLM_LIVE_JMV=1 才跑) -------------------

test_that('exec_analysis(live):真跑 jmv::descriptives(iris)', {
    skip_if(Sys.getenv('ASKLLM_LIVE_JMV') == '',
            'set ASKLLM_LIVE_JMV=1 to run the live jmv test')
    skip_if_not_installed('jmv')
    action <- list(type = 'run_analysis', analysis = 'descriptives',
                   args = list(vars = list('Sepal.Length')), rationale = 'r')
    got <- exec_analysis(action, iris)
    expect_true(got$ok)
    expect_true(nchar(got$output) > 0)
    expect_true(grepl('Sepal', got$output))
})

# ---- exec_action 分派(Phase 2):依 type 分派 --------------------------------

test_that('exec_action:compute_column → eval_formula,回 value/column_name', {
    action <- list(type = 'compute_column', column_name = 'dbl',
                   measure_type = 'continuous', formula = 'x * 2', rationale = 'r')
    got <- exec_action(action, data.frame(x = c(1, 2, 3)))
    expect_true(got$ok)
    expect_identical(got$type, 'compute_column')
    expect_identical(got$column_name, 'dbl')
    expect_identical(got$measure_type, 'continuous')
    expect_equal(got$value, c(2, 4, 6))
})

test_that('exec_action:run_analysis → 委派 exec_analysis', {
    action <- list(type = 'run_analysis', analysis = 'descriptives',
                   args = list(vars = 'x'), rationale = 'r')
    fake_get <- function(name) function(data, ...)
        list(asString = function() paste0('T:', name))
    got <- exec_action(action, data.frame(x = 1:3), jmv_get = fake_get)
    expect_true(got$ok)
    expect_identical(got$type, 'run_analysis')
    expect_true(grepl('T:descriptives', got$output, fixed = TRUE))
})

test_that('exec_action:compute_column 求值失敗(長度不符)→ ok=FALSE', {
    action <- list(type = 'compute_column', column_name = 'm',
                   measure_type = 'continuous', formula = 'mean(x)', rationale = 'r')
    got <- exec_action(action, data.frame(x = c(1, 2, 3)))
    expect_false(got$ok)
    expect_identical(got$type, 'compute_column')
    expect_true(nzchar(got$error))
})
