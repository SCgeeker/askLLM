# test-role.R — 項目 1:人格選擇(role 選擇器)+ 顯式語言選單(promptLang)
#
# 降級保證(最重要的回歸鎖):role='consultant' + lang='en' + systemPrompt=''
# 時,.askllm_system_prompt() 回傳字串必須與 v1.1 現行字串逐字相同。

# ---- 回歸鎖:consultant/en/空自訂 ≡ 現行字串 ---------------------------------

test_that('consultant/en/空白自訂 prompt 與 v1.1 現行字串逐字相同(has_catalog=FALSE)', {
    legacy <- paste(
        'You are a statistical analysis assistant embedded in jamovi.',
        'Answer the user\'s questions about their dataset using the provided',
        'summary statistics. Be concise, accurate, and practical. If the',
        'summary is insufficient to answer, say so briefly rather than guessing.',
        sep = ' ')

    got <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                  system_prompt = '', has_catalog = FALSE)
    expect_identical(got, legacy)
})

test_that('consultant/en/空白自訂 prompt 與 v1.1 現行字串逐字相同(has_catalog=TRUE)', {
    legacy_base <- paste(
        'You are a statistical analysis assistant embedded in jamovi.',
        'Answer the user\'s questions about their dataset using the provided',
        'summary statistics. Be concise, accurate, and practical. If the',
        'summary is insufficient to answer, say so briefly rather than guessing.',
        sep = ' ')
    legacy_catalog <- paste(
        'When a list of installed analyses is provided, recommend analyses ONLY',
        'from that list and cite each menu path exactly as written. If nothing',
        'installed fits, suggest a module ONLY if its name appears literally in the',
        'provided available-modules list; never name a module that is not in that',
        'list, even one you believe exists, and never invent menu paths.',
        sep = ' ')
    legacy <- paste(legacy_base, legacy_catalog)

    got <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                  system_prompt = '', has_catalog = TRUE)
    expect_identical(got, legacy)
})

test_that('舊呼叫方式(僅 has_catalog 具名參數,無 role/lang)仍與現行字串相同', {
    # 呼叫點升級前的呼叫慣例,確認新簽章對舊用法向後相容
    expect_identical(
        .askllm_system_prompt(has_catalog = FALSE),
        .askllm_system_prompt(role = 'consultant', lang = 'en',
                              system_prompt = '', has_catalog = FALSE))
    expect_identical(
        .askllm_system_prompt(has_catalog = TRUE),
        .askllm_system_prompt(role = 'consultant', lang = 'en',
                              system_prompt = '', has_catalog = TRUE))
})

# ---- tutor / explainer:各人格含特徵句,has_catalog=TRUE 時皆含約束句 --------

test_that('tutor/en 含蘇格拉底式特徵句;has_catalog=TRUE 時仍含 catalog 約束句', {
    txt_off <- .askllm_system_prompt(role = 'tutor', lang = 'en', has_catalog = FALSE)
    expect_true(grepl('Socratic', txt_off, ignore.case = TRUE))

    txt_on <- .askllm_system_prompt(role = 'tutor', lang = 'en', has_catalog = TRUE)
    expect_true(grepl('recommend analyses ONLY', txt_on, fixed = TRUE))
})

test_that('tutor/zh 含蘇格拉底特徵句;has_catalog=TRUE 時含中文約束句', {
    txt_off <- .askllm_system_prompt(role = 'tutor', lang = 'zh', has_catalog = FALSE)
    expect_true(grepl('蘇格拉底', txt_off))

    txt_on <- .askllm_system_prompt(role = 'tutor', lang = 'zh', has_catalog = TRUE)
    expect_true(grepl('已安裝分析清單', txt_on))
})

test_that('explainer/en 含 beginner 特徵句;has_catalog=TRUE 時仍含 catalog 約束句', {
    txt_off <- .askllm_system_prompt(role = 'explainer', lang = 'en', has_catalog = FALSE)
    expect_true(grepl('beginner', txt_off, ignore.case = TRUE))

    txt_on <- .askllm_system_prompt(role = 'explainer', lang = 'en', has_catalog = TRUE)
    expect_true(grepl('recommend analyses ONLY', txt_on, fixed = TRUE))
})

test_that('explainer/zh 含初學者特徵句;has_catalog=TRUE 時含中文約束句', {
    txt_off <- .askllm_system_prompt(role = 'explainer', lang = 'zh', has_catalog = FALSE)
    expect_true(grepl('初學者', txt_off))

    txt_on <- .askllm_system_prompt(role = 'explainer', lang = 'zh', has_catalog = TRUE)
    expect_true(grepl('已安裝分析清單', txt_on))
})

test_that('consultant/zh 為中文版本且與 en 版不同', {
    txt <- .askllm_system_prompt(role = 'consultant', lang = 'zh', has_catalog = FALSE)
    expect_true(grepl('統計分析助理', txt))
    expect_false(identical(txt,
        .askllm_system_prompt(role = 'consultant', lang = 'en', has_catalog = FALSE)))
})

# ---- systemPrompt 自訂覆蓋:非空時整段覆蓋模板,但 catalog 約束句仍附加 ------

test_that('systemPrompt 非空時整段覆蓋 role x lang 模板', {
    custom <- 'Custom instructions: only answer in bullet points.'
    txt <- .askllm_system_prompt(role = 'tutor', lang = 'en',
                                  system_prompt = custom, has_catalog = FALSE)
    expect_identical(txt, custom)
    # 不應混入 tutor 模板內容
    expect_false(grepl('Socratic', txt, ignore.case = TRUE))
})

test_that('systemPrompt 非空且 has_catalog=TRUE 時,仍附加 catalog 約束句(英文)', {
    custom <- 'Custom instructions: only answer in bullet points.'
    txt <- .askllm_system_prompt(role = 'tutor', lang = 'en',
                                  system_prompt = custom, has_catalog = TRUE)
    expect_true(grepl(custom, txt, fixed = TRUE))
    expect_true(grepl('recommend analyses ONLY', txt, fixed = TRUE))
})

test_that('systemPrompt 非空且 lang=zh、has_catalog=TRUE 時,附加中文約束句', {
    custom <- '自訂指示:只用條列式回答。'
    txt <- .askllm_system_prompt(role = 'explainer', lang = 'zh',
                                  system_prompt = custom, has_catalog = TRUE)
    expect_true(grepl(custom, txt, fixed = TRUE))
    expect_true(grepl('已安裝分析清單', txt))
})

test_that('systemPrompt 僅空白字元視為空(不覆蓋模板)', {
    txt <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                  system_prompt = '   \n\t', has_catalog = FALSE)
    expect_identical(txt,
        .askllm_system_prompt(role = 'consultant', lang = 'en',
                              system_prompt = '', has_catalog = FALSE))
})

# ---- 防禦性:未知 role / lang 落回 consultant / en ---------------------------

test_that('未知 role 落回 consultant', {
    txt <- .askllm_system_prompt(role = 'unknown-role', lang = 'en', has_catalog = FALSE)
    expect_identical(txt,
        .askllm_system_prompt(role = 'consultant', lang = 'en', has_catalog = FALSE))
})

test_that('未知 lang 落回 en', {
    txt <- .askllm_system_prompt(role = 'consultant', lang = 'fr', has_catalog = FALSE)
    expect_identical(txt,
        .askllm_system_prompt(role = 'consultant', lang = 'en', has_catalog = FALSE))
})

# ---- .askllm_build_payload:role / promptLang / systemPrompt 需納入指紋 -----

test_that('build_payload:role 不同 → payload 不同(防抖區辨)', {
    p1 <- .askllm_build_payload('Q', 'S', 'http://b', 'm', role = 'consultant')
    p2 <- .askllm_build_payload('Q', 'S', 'http://b', 'm', role = 'tutor')
    expect_false(identical(p1, p2))
})

test_that('build_payload:promptLang 不同 → payload 不同', {
    p1 <- .askllm_build_payload('Q', 'S', 'http://b', 'm', prompt_lang = 'en')
    p2 <- .askllm_build_payload('Q', 'S', 'http://b', 'm', prompt_lang = 'zh')
    expect_false(identical(p1, p2))
})

test_that('build_payload:systemPrompt 不同 → payload 不同', {
    p1 <- .askllm_build_payload('Q', 'S', 'http://b', 'm', system_prompt = '')
    p2 <- .askllm_build_payload('Q', 'S', 'http://b', 'm', system_prompt = 'custom')
    expect_false(identical(p1, p2))
})

test_that('build_payload:role/promptLang/systemPrompt 皆用預設值時,與舊五參數呼叫逐字相同', {
    p_old <- .askllm_build_payload('Q', 'S', 'http://b', 'm', context_text = 'X')
    p_new <- .askllm_build_payload('Q', 'S', 'http://b', 'm', context_text = 'X',
                                    role = 'consultant', prompt_lang = 'en',
                                    system_prompt = '')
    expect_identical(p_old, p_new)
})
