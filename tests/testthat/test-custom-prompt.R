# test-custom-prompt.R — 項目:以資料變數的 Description 當 system prompt
#
# 背景:jamovi 28.1 實測確認 .b.R runtime 可用
# attr(self$data[[varName]], 'jmv-desc') 讀到該變數在 Setup 面板填的 Description。
# 這是官方無文件的隱性通道,無法在 headless 單元測試中重現(engine 才會掛
# 這個 attribute),故 .runInner() 讀 attr 那行不強求單元測試,改由
# .askllm_resolve_custom() 這個純函式涵蓋優先序邏輯,搭配真 GUI 驗證。
#
# 優先序(最高在前):
#   1. systemPromptVar 的 jmv-desc(去空白後非空)
#   2. systemPrompt(去空白後非空)
#   3. ''(落回 role x lang 模板,由 .askllm_system_prompt() 處理)

# ---- .askllm_resolve_custom:純函式優先序 -----------------------------------

test_that('resolve_custom: var_desc 非空時優先於 text', {
    expect_identical(.askllm_resolve_custom('A', 'B'), 'A')
})

test_that('resolve_custom: var_desc 空、text 非空時回 text', {
    expect_identical(.askllm_resolve_custom('', 'B'), 'B')
})

test_that('resolve_custom: 兩者皆空回空字串', {
    expect_identical(.askllm_resolve_custom('', ''), '')
})

test_that('resolve_custom: var_desc 純空白視為空,落回 text', {
    expect_identical(.askllm_resolve_custom('  ', 'B'), 'B')
})

test_that('resolve_custom: text 空、var_desc 非空時回 var_desc', {
    expect_identical(.askllm_resolve_custom('A', ''), 'A')
})

test_that('resolve_custom: 兩者皆為純空白時回空字串', {
    expect_identical(.askllm_resolve_custom('  ', '\t\n'), '')
})

test_that('resolve_custom: var_desc 前後有空白時會被 trim', {
    expect_identical(.askllm_resolve_custom('  A  ', 'B'), 'A')
})

test_that('resolve_custom: NULL 輸入視為空字串,不炸', {
    expect_identical(.askllm_resolve_custom(NULL, 'B'), 'B')
    expect_identical(.askllm_resolve_custom(NULL, NULL), '')
})

# ---- .askllm_build_payload:systemPromptVar 名稱與解析後 custom 需納入指紋 ---

test_that('build_payload: systemPromptVar 名稱不同 → payload 不同(防抖區辨)', {
    p1 <- .askllm_build_payload('Q', 'S', 'http://b', 'm', system_prompt_var = 'varA')
    p2 <- .askllm_build_payload('Q', 'S', 'http://b', 'm', system_prompt_var = 'varB')
    expect_false(identical(p1, p2))
})

test_that('build_payload: system_prompt_var 為 NULL/空 與現行呼叫逐字相同(降級保證)', {
    p_old <- .askllm_build_payload('Q', 'S', 'http://b', 'm', system_prompt = 'custom')
    p_new <- .askllm_build_payload('Q', 'S', 'http://b', 'm', system_prompt = 'custom',
                                    system_prompt_var = '')
    expect_identical(p_old, p_new)
})

test_that('build_payload: 同一 systemPromptVar 名稱但解析後 custom 不同(變數 Description 被改) → payload 不同', {
    # 模擬:varName 相同,但該變數的 Description 已變更 → resolve_custom 結果不同
    # → 呼叫端應以新的 custom 值組 payload(經 system_prompt 欄位反映)
    custom_old <- .askllm_resolve_custom('Old description', '')
    custom_new <- .askllm_resolve_custom('New description', '')

    p1 <- .askllm_build_payload('Q', 'S', 'http://b', 'm',
                                 system_prompt = custom_old, system_prompt_var = 'descVar')
    p2 <- .askllm_build_payload('Q', 'S', 'http://b', 'm',
                                 system_prompt = custom_new, system_prompt_var = 'descVar')
    expect_false(identical(p1, p2))
})

# ---- 回歸鎖:consultant/en/空 時仍與 v1.1 逐字相同 --------------------------

test_that('build_payload: 全預設參數(不含 system_prompt_var)與升版前逐字相同', {
    p_old <- .askllm_build_payload('Q', 'S', 'http://b', 'm', context_text = 'X')
    p_new <- .askllm_build_payload('Q', 'S', 'http://b', 'm', context_text = 'X',
                                    role = 'consultant', prompt_lang = 'en',
                                    system_prompt = '')
    expect_identical(p_old, p_new)
})

test_that('resolve_custom 搭配 .askllm_system_prompt: 空 var_desc 與空 systemPrompt 時仍降級為模板', {
    custom <- .askllm_resolve_custom('', '')
    txt <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                  system_prompt = custom, has_catalog = FALSE)
    legacy <- paste(
        'You are a statistical analysis assistant embedded in jamovi.',
        'Answer the user\'s questions about their dataset using the provided',
        'summary statistics. Be concise, accurate, and practical. If the',
        'summary is insufficient to answer, say so briefly rather than guessing.',
        sep = ' ')
    expect_identical(txt, legacy)
})
