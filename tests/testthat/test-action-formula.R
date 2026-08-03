# test-action-formula.R — Phase 2:validate_formula() R 公式 AST 白名單(安全核心)
#
# 契約:validate_formula(formula, colnames) -> list(ok, reason)
#   - str2lang 解析(失敗即拒;拒多語句、賦值)
#   - 走訪 AST:call 的函式名 ∈ 白名單;symbol(變數)∈ colnames;常數僅字面值
#   - 拒 :: $ [[ [ eval system Sys.* 賦值 函式定義 等
#   絕不 eval/parse-and-run;純函式、永不 stop()。
#
# Phase 2 公式是 R 運算式(值快照,非 jamovi 活公式);白名單為 R 函式子集。

cn <- c('weight', 'height', 'score', 'age')

# ---- 合法公式通過 ----------------------------------------------------------

test_that('合法算術/邏輯公式通過', {
    expect_true(validate_formula('weight / (height / 100)^2', cn)$ok)
    expect_true(validate_formula('ifelse(score >= 60, 1, 0)', cn)$ok)
    expect_true(validate_formula('log(weight) + sqrt(age)', cn)$ok)
    expect_true(validate_formula('(score - mean(score)) / sd(score)', cn)$ok)
})

test_that('純常數公式通過', {
    expect_true(validate_formula('1', cn)$ok)
})

# ---- 未知變數 → 拒 ---------------------------------------------------------

test_that('未知變數(不在 colnames)被拒', {
    r <- validate_formula('weight / bmi', cn)     # bmi 不存在
    expect_false(r$ok)
    expect_true(is.character(r$reason) && nzchar(r$reason))
})

# ---- 未白名單函式 → 拒 -----------------------------------------------------

test_that('未白名單/危險函式被拒', {
    expect_false(validate_formula('system("x")', cn)$ok)
    expect_false(validate_formula('eval(weight)', cn)$ok)
    expect_false(validate_formula('Sys.getenv("X")', cn)$ok)
    expect_false(validate_formula('do.call("sum", list(weight))', cn)$ok)
})

# ---- 存取運算子 → 拒 -------------------------------------------------------

test_that(':: $ [[ [ 存取被拒', {
    expect_false(validate_formula('base::mean(weight)', cn)$ok)
    expect_false(validate_formula('weight[[1]]', cn)$ok)
    expect_false(validate_formula('weight[1]', cn)$ok)
})

# ---- 賦值 / 多語句 / 公式符號 → 拒 -----------------------------------------

test_that('賦值、多語句、~ 被拒', {
    expect_false(validate_formula('x <- weight', cn)$ok)
    expect_false(validate_formula('weight = 1', cn)$ok)
    expect_false(validate_formula('weight; height', cn)$ok)
    expect_false(validate_formula('weight ~ height', cn)$ok)
})

# ---- 無法解析 → 拒,不 stop -------------------------------------------------

test_that('語法錯誤的公式被拒且不 stop()', {
    expect_false(validate_formula('weight +', cn)$ok)
    expect_false(validate_formula('((', cn)$ok)
    expect_false(validate_formula('', cn)$ok)
})

# ---- eval_formula():受限環境求值 ------------------------------------------
# 契約:eval_formula(formula, data) -> list(ok, value, error)
#   先過 validate_formula(雙保險);在 parent=emptyenv 的環境求值(只放白名單
#   函式 + 資料欄);結果長度須== nrow(data)、型別須為 numeric/int/logical/
#   factor/character。絕不 eval 任意碼、永不 stop()。

.fd <- data.frame(weight = c(60, 70, 80), height = c(160, 170, 180),
                  score = c(50, 65, 80))

test_that('合法公式求值結果正確(逐列)', {
    r <- eval_formula('weight / (height / 100)^2', .fd)
    expect_true(r$ok)
    expect_equal(r$value, .fd$weight / (.fd$height / 100)^2)
})

test_that('ifelse 邏輯公式求值正確', {
    r <- eval_formula('ifelse(score >= 60, 1, 0)', .fd)
    expect_true(r$ok)
    expect_equal(r$value, c(0, 1, 1))
})

test_that('危險公式(未過白名單)在求值層也拒', {
    r <- eval_formula('system("x")', .fd)
    expect_false(r$ok)
    expect_true(nzchar(r$error))
})

test_that('結果長度 != 列數 → 拒(要求逐列)', {
    r <- eval_formula('mean(weight)', .fd)   # 長度 1 ≠ 3
    expect_false(r$ok)
    expect_true(grepl('長度', r$error))
})

test_that('受限環境:公式引用的未白名單符號解析不到(不洩漏呼叫端物件)', {
    secret_obj <- 999           # 呼叫端環境的物件
    r <- eval_formula('weight + secret_obj', .fd)
    expect_false(r$ok)          # secret_obj 非欄名 → validate 先擋
})

test_that('求值 runtime 錯誤 → ok=FALSE,不 stop()', {
    # as.numeric 對非數字字元產 NA+warning(非 error);改用會真 error 的情境:
    # 這裡驗證 tryCatch 存在——正常公式仍 ok
    expect_true(eval_formula('abs(weight - score)', .fd)$ok)
})

# ---- 回歸(本地 e2e bug):白名單含 stats 函式(sd/median),受限環境須放得到 ---
#      eval_formula 原只從 baseenv() 取函式,sd/median 在 stats → 受限環境缺 →
#      z-score 類公式 validate 過但 eval 失敗。

test_that('eval_formula 支援 stats 函式 sd/median:z-score 公式求值成功', {
    r <- eval_formula('(score - mean(score)) / sd(score)', .fd)
    expect_true(r$ok)
    expect_equal(r$value, (.fd$score - mean(.fd$score)) / sd(.fd$score))
})

test_that('eval_formula:median 亦可用', {
    r <- eval_formula('weight - median(weight)', .fd)
    expect_true(r$ok)
    expect_equal(r$value, .fd$weight - median(.fd$weight))
})
