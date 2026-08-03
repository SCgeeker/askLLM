# test-action-prompt.R — Phase 1:動作模式的 system prompt 疊加層(action_suffix)
#
# 設計(見 dev-notes/v1.2-actionable-research §「persona × action」與本 session
# 討論):
#   system_prompt = base[role][lang]
#                 + catalog_suffix (if has_catalog)
#                 + action_suffix  (if enable_actions)   ← 本檔新增層
#
# 降級保證:enable_actions 預設 FALSE,不傳時輸出與 v1.1 逐字相同
#   (test-role.R 全部既有測試不傳此參數,連帶構成回歸保護)。
# 人格分工:consultant / explainer 共用「鼓勵動手」版;tutor 用「克制引導」版。
# reply 語氣仍歸 persona,action 為共通機械產物(見 suffix 文案)。

# ---- 回歸鎖:enable_actions 預設 FALSE ≡ 不傳該參數 --------------------------

test_that('enable_actions 預設 FALSE:與不傳該參數逐字相同(consultant/en)', {
    expect_identical(
        .askllm_system_prompt(role = 'consultant', lang = 'en',
                              system_prompt = '', has_catalog = FALSE),
        .askllm_system_prompt(role = 'consultant', lang = 'en',
                              system_prompt = '', has_catalog = FALSE,
                              enable_actions = FALSE))
})

test_that('enable_actions=FALSE 不附加任何動作句(即使 has_catalog=TRUE)', {
    txt <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                  has_catalog = TRUE, enable_actions = FALSE)
    expect_false(grepl('run it directly', txt, fixed = TRUE))
})

# ---- consultant / explainer:共用「鼓勵動手」action_suffix ------------------

test_that('consultant/en + enable_actions:精簡結論導向(concisely/takeaway),base 保留', {
    txt <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                  has_catalog = FALSE, enable_actions = TRUE)
    expect_true(grepl('run it directly', txt, fixed = TRUE))
    expect_true(grepl('takeaway', txt, fixed = TRUE))
    expect_false(grepl('step by step', txt, fixed = TRUE))   # 無教學解讀句
    expect_true(grepl('statistical analysis assistant', txt, fixed = TRUE))
})

test_that('explainer/en + enable_actions:教學式解讀(step by step),與 consultant 明確區別', {
    exp <- .askllm_system_prompt(role = 'explainer', lang = 'en',
                                  has_catalog = FALSE, enable_actions = TRUE)
    con <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                  has_catalog = FALSE, enable_actions = TRUE)
    expect_true(grepl('step by step', exp, fixed = TRUE))
    expect_true(grepl('beginners', exp, fixed = TRUE))       # explainer base 保留
    expect_false(grepl('takeaway', exp, fixed = TRUE))       # 非 consultant 精簡句
    expect_false(identical(exp, con))                         # 兩者確實不同
})

# ---- tutor:克制/引導變體(與 consultant 版不同) ----------------------------

test_that('tutor/en + enable_actions:用克制引導版(explicitly ask),非 consultant 動手句', {
    txt <- .askllm_system_prompt(role = 'tutor', lang = 'en',
                                  has_catalog = FALSE, enable_actions = TRUE)
    expect_true(grepl('explicitly ask', txt, fixed = TRUE))
    expect_false(grepl('run it directly', txt, fixed = TRUE))
    expect_true(grepl('Socratic', txt, ignore.case = TRUE))
})

# ---- 三段疊加順序:base → catalog → action ---------------------------------

test_that('has_catalog=TRUE + enable_actions=TRUE:三段皆在且依序 base<catalog<action', {
    txt <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                  has_catalog = TRUE, enable_actions = TRUE)
    p_base   <- regexpr('statistical analysis assistant', txt, fixed = TRUE)
    p_cat    <- regexpr('recommend analyses ONLY', txt, fixed = TRUE)
    p_action <- regexpr('run it directly', txt, fixed = TRUE)
    expect_true(p_base > 0 && p_cat > 0 && p_action > 0)
    expect_true(p_base < p_cat && p_cat < p_action)
})

# ---- 中文版 ----------------------------------------------------------------

test_that('consultant/zh + enable_actions:含中文動手句', {
    txt <- .askllm_system_prompt(role = 'consultant', lang = 'zh',
                                  has_catalog = FALSE, enable_actions = TRUE)
    expect_true(grepl('直接執行', txt))
})

test_that('tutor/zh + enable_actions:含中文克制句(明確要求),非 consultant 動手句', {
    txt <- .askllm_system_prompt(role = 'tutor', lang = 'zh',
                                  has_catalog = FALSE, enable_actions = TRUE)
    expect_true(grepl('明確要求', txt))
    expect_false(grepl('直接執行', txt))
})

test_that('explainer/zh + enable_actions:含逐步解讀句,與 consultant/zh 不同', {
    exp <- .askllm_system_prompt(role = 'explainer', lang = 'zh',
                                  has_catalog = FALSE, enable_actions = TRUE)
    con <- .askllm_system_prompt(role = 'consultant', lang = 'zh',
                                  has_catalog = FALSE, enable_actions = TRUE)
    expect_true(grepl('逐步解讀', exp))
    expect_false(identical(exp, con))
})

# ---- 疊在 custom system_prompt 上 ------------------------------------------

test_that('custom system_prompt + enable_actions:custom 與 action 句並存', {
    custom <- 'Custom: bullet points only.'
    txt <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                  system_prompt = custom, has_catalog = FALSE,
                                  enable_actions = TRUE)
    expect_true(grepl(custom, txt, fixed = TRUE))
    expect_true(grepl('run it directly', txt, fixed = TRUE))
})

# ---- build_payload:enableActions 納入指紋(payload 格式 v1.4)---------------
# 翻轉動作開關必須視為新請求(否則防抖快取誤判為 cached,不觸發新呼叫)。

test_that('build_payload:enable_actions 不同 → payload 不同(防抖區辨)', {
    p1 <- .askllm_build_payload('Q', 'S', 'http://b', 'm', enable_actions = FALSE)
    p2 <- .askllm_build_payload('Q', 'S', 'http://b', 'm', enable_actions = TRUE)
    expect_false(identical(p1, p2))
})

test_that('build_payload:enable_actions 預設 FALSE,與明給 FALSE 一致', {
    expect_identical(
        .askllm_build_payload('Q', 'S', 'http://b', 'm'),
        .askllm_build_payload('Q', 'S', 'http://b', 'm', enable_actions = FALSE))
})
