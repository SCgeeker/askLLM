# test-role.R — 項目 1:人格選擇(role 選擇器)+ 顯式語言選單(promptLang)
#
# 「Module Guider 精簡 + 雙向 prompt 邊界」(見 dev-notes)打破了 v1.1 的逐字
# 降級保證:.askllm_system_prompt() 現在**恆**在末尾附加
# .ASKLLM_R_REDIRECT_SUFFIX[[lang]](把 R 程式碼請求導向 sibling 分析
# 「R code tutor」)。以下回歸鎖改為「base/catalog 內容不變 + 含邊界句」,
# 不再是與 v1.1 逐字相同。

# ---- 回歸鎖:consultant/en/空自訂 ≡ v1.1 base + 邊界句 -----------------------

test_that('consultant/en/空白自訂 prompt = v1.1 現行字串 + R 導引邊界句(has_catalog=FALSE)', {
    legacy <- paste(
        'You are a statistical analysis assistant embedded in jamovi.',
        'Answer the user\'s questions about their dataset using the provided',
        'summary statistics. Be concise, accurate, and practical. If the',
        'summary is insufficient to answer, say so briefly rather than guessing.',
        sep = ' ')
    want <- paste(legacy, .ASKLLM_R_REDIRECT_SUFFIX$en)

    got <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                  system_prompt = '', has_catalog = FALSE)
    expect_identical(got, want)
    # 明確斷言邊界句存在(而非僅逐字比對整段組成)
    expect_true(grepl('R code tutor', got, fixed = TRUE))
})

test_that('consultant/en/空白自訂 prompt = v1.1 現行字串 + catalog 約束句 + 邊界句(has_catalog=TRUE)', {
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
    want <- paste(legacy_base, legacy_catalog, .ASKLLM_R_REDIRECT_SUFFIX$en)

    got <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                  system_prompt = '', has_catalog = TRUE)
    expect_identical(got, want)
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

test_that('systemPrompt 非空時整段覆蓋 role x lang 模板(但雙向邊界句恆附加)', {
    custom <- 'Custom instructions: only answer in bullet points.'
    txt <- .askllm_system_prompt(role = 'tutor', lang = 'en',
                                  system_prompt = custom, has_catalog = FALSE)
    expect_identical(txt, paste(custom, .ASKLLM_R_REDIRECT_SUFFIX$en))
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

# ---- 構件 4 → M-A3:.askllmr_system_prompt() 回歸鎖(改指向新分析) ----------
#
# M-A0 已把 .askllm_system_prompt() 退回原簽名(無 r_code/has_rj_env 參數,
# 諮詢分析 askllm 不再有 R-code 意圖)。以下案例 M-A3 改指向 R code tutor
# (askllmr)的 .askllmr_system_prompt()(定義於 R/r-tutor.R):它恆附加
# .ASKLLM_RJ_SUFFIX(R 家教是主體,不是可關閉的後綴),故不再有「r_code=FALSE
# 逐字相同」的降級案例,改測「六格皆為 base + RJ_SUFFIX」的組成公式。
#
# 「Module Guider 精簡 + 雙向 prompt 邊界」再加一層:.askllmr_system_prompt()
# 現在恆在末尾附加 .ASKLLM_JAMOVI_REDIRECT_SUFFIX[[lang]](對稱於 askllm 的
# .ASKLLM_R_REDIRECT_SUFFIX),故組成公式改為「base + RJ_SUFFIX + JAMOVI_REDIRECT_SUFFIX」。

test_that('askllmr_system_prompt:六種 (role, lang) 皆為 base + RJ_SUFFIX + 邊界句 的組合', {
    roles <- c('consultant', 'tutor', 'explainer')
    langs <- c('en', 'zh')
    for (r in roles) for (l in langs) {
        got <- .askllmr_system_prompt(role = r, lang = l)
        want <- paste(.ASKLLM_R_PROMPTS[[r]][[l]], .ASKLLM_RJ_SUFFIX[[r]][[l]],
                      .ASKLLM_JAMOVI_REDIRECT_SUFFIX[[l]])
        expect_identical(got, want, info = paste('role =', r, ', lang =', l))
    }
})

test_that('askllmr_system_prompt:custom system_prompt 覆蓋 base,但恆附 RJ_SUFFIX', {
    custom <- 'Custom instructions: only use base R.'
    txt <- .askllmr_system_prompt(role = 'consultant', lang = 'en',
                                   system_prompt = custom)
    expect_true(grepl(custom, txt, fixed = TRUE))
    expect_false(grepl('You are an R coding tutor', txt, fixed = TRUE))
    expect_true(grepl('Rj Editor and run it', txt, fixed = TRUE))
})

test_that('askllmr_system_prompt:未傳 system_prompt 與傳空字串逐字相同(預設值)', {
    old_style <- .askllmr_system_prompt(role = 'tutor', lang = 'zh')
    new_style <- .askllmr_system_prompt(role = 'tutor', lang = 'zh',
                                         system_prompt = '')
    expect_identical(old_style, new_style)
})

# ---- 構件 4:六格 .ASKLLM_RJ_SUFFIX 特徵句(經 .askllmr_system_prompt) -----

test_that('askllmr_system_prompt:六格皆含共通句關鍵字(data、install.packages、Rj)', {
    roles <- c('consultant', 'tutor', 'explainer')
    langs <- c('en', 'zh')
    for (r in roles) for (l in langs) {
        txt <- .askllmr_system_prompt(role = r, lang = l)
        expect_true(grepl('data', txt, fixed = TRUE), info = paste(r, l))
        expect_true(grepl('install.packages', txt, fixed = TRUE), info = paste(r, l))
        expect_true(grepl('Rj', txt, fixed = TRUE), info = paste(r, l))
    }
})

test_that('askllmr_system_prompt:tutor(en/zh)含 TODO 佔位提示', {
    expect_true(grepl('TODO',
        .askllmr_system_prompt(role = 'tutor', lang = 'en'), fixed = TRUE))
    expect_true(grepl('TODO',
        .askllmr_system_prompt(role = 'tutor', lang = 'zh'), fixed = TRUE))
})

test_that('askllmr_system_prompt:explainer(en/zh)含逐行註解要求', {
    txt_en <- .askllmr_system_prompt(role = 'explainer', lang = 'en')
    expect_true(grepl('comment', txt_en, ignore.case = TRUE))
    expect_true(grepl('#', txt_en, fixed = TRUE))

    txt_zh <- .askllmr_system_prompt(role = 'explainer', lang = 'zh')
    expect_true(grepl('逐行', txt_zh, fixed = TRUE))
    expect_true(grepl('#', txt_zh, fixed = TRUE))
})

test_that('askllmr_system_prompt:consultant(en/zh)含單一 code block 語意', {
    txt_en <- .askllmr_system_prompt(role = 'consultant', lang = 'en')
    expect_true(grepl('single fenced code block', txt_en, fixed = TRUE))

    txt_zh <- .askllmr_system_prompt(role = 'consultant', lang = 'zh')
    expect_true(grepl('單一', txt_zh, fixed = TRUE))
    expect_true(grepl('code block', txt_zh, fixed = TRUE))
})

test_that('askllmr_system_prompt:三版皆說明 Rj 未安裝時改教 Syntax Mode', {
    for (r in c('consultant', 'tutor', 'explainer')) {
        txt <- .askllmr_system_prompt(role = r, lang = 'en')
        expect_true(grepl('Syntax Mode', txt, fixed = TRUE), info = r)
    }
})

# ---- 構件 4:順序 base(人格身分) -> RJ_SUFFIX(共通句 -> per-role 句) -------

test_that('askllmr_system_prompt:base 身分句在前,RJ_COMMON 在中,per-role 句在後', {
    txt <- .askllmr_system_prompt(role = 'consultant', lang = 'en')
    pos_base   <- regexpr('You are an R coding tutor', txt, fixed = TRUE)
    pos_common <- regexpr('paste your R code', txt, fixed = TRUE)
    pos_role   <- regexpr('complete, minimal, ready-to-paste', txt, fixed = TRUE)

    expect_true(pos_base > 0 && pos_common > 0 && pos_role > 0)
    expect_true(pos_base < pos_common)
    expect_true(pos_common < pos_role)
})

# ---- 構件 4:未知 role 落回 consultant,仍附 rj suffix -----------------------

test_that('askllmr_system_prompt:未知 role 落回 consultant 且仍含 rj suffix', {
    txt <- .askllmr_system_prompt(role = 'unknown-role', lang = 'en')
    expect_identical(txt,
        .askllmr_system_prompt(role = 'consultant', lang = 'en'))
    expect_true(grepl('Rj Editor and run it', txt, fixed = TRUE))
})

# ---- 雙向 prompt 邊界:Module Guider(askllm)↔ R code tutor(askllmr) -------
#
# 真機發現 Module Guider 被問「give me R」時會傾倒 R 碼、越界。作者定案:
# 兩分析的 system prompt 皆恆附加一句邊界,把對方領域的請求導去 sibling
# 分析。以下鎖住邊界句在六種 (role, lang) 組合下皆存在,且中英皆備。

test_that('askllm(Module Guider):六種 (role, lang) 皆含「導向 R code tutor」邊界句(英文關鍵字)', {
    roles <- c('consultant', 'tutor', 'explainer')
    langs <- c('en', 'zh')
    for (r in roles) for (l in langs) {
        txt <- .askllm_system_prompt(role = r, lang = l, has_catalog = FALSE)
        expect_true(grepl('R code tutor', txt, fixed = TRUE),
                    info = paste('role =', r, ', lang =', l))
    }
})

test_that('askllm(Module Guider):英文邊界句提及 sibling 選單路徑,中文邊界句提及對應中文句', {
    txt_en <- .askllm_system_prompt(role = 'consultant', lang = 'en', has_catalog = FALSE)
    expect_true(grepl('Analyses ▸ askLLM ▸ R code tutor', txt_en, fixed = TRUE))
    expect_true(grepl('do not write R code yourself here', txt_en, fixed = TRUE))

    txt_zh <- .askllm_system_prompt(role = 'consultant', lang = 'zh', has_catalog = FALSE)
    expect_true(grepl('R code tutor', txt_zh, fixed = TRUE))
    expect_true(grepl('不要在此自行撰寫 R 程式碼', txt_zh, fixed = TRUE))
})

test_that('askllm(Module Guider):邊界句在 has_catalog/enable_actions 任意組合下皆存在(恆附加,不可降級關閉)', {
    combos <- expand.grid(has_catalog = c(FALSE, TRUE),
                          enable_actions = c(FALSE, TRUE))
    for (i in seq_len(nrow(combos))) {
        txt <- .askllm_system_prompt(role = 'consultant', lang = 'en',
                                      has_catalog = combos$has_catalog[i],
                                      enable_actions = combos$enable_actions[i])
        expect_true(grepl('R code tutor', txt, fixed = TRUE),
                    info = paste(combos[i, ], collapse = ','))
    }
})

test_that('askllmr(R code tutor):六種 (role, lang) 皆含「導向 jamovi Module Guider」邊界句', {
    roles <- c('consultant', 'tutor', 'explainer')
    langs <- c('en', 'zh')
    for (r in roles) for (l in langs) {
        txt <- .askllmr_system_prompt(role = r, lang = l)
        expect_true(grepl('jamovi Module Guider', txt, fixed = TRUE),
                    info = paste('role =', r, ', lang =', l))
    }
})

test_that('askllmr(R code tutor):英文邊界句提及 sibling 分析名稱,中文邊界句提及對應中文句', {
    txt_en <- .askllmr_system_prompt(role = 'consultant', lang = 'en')
    expect_true(grepl('jamovi Module Guider', txt_en, fixed = TRUE))
    expect_true(grepl('redirect them to the "jamovi Module Guider"', txt_en, fixed = TRUE))

    txt_zh <- .askllmr_system_prompt(role = 'consultant', lang = 'zh')
    expect_true(grepl('jamovi Module Guider', txt_zh, fixed = TRUE))
    expect_true(grepl('請引導其改用「jamovi Module Guider」分析', txt_zh, fixed = TRUE))
})

test_that('askllmr(R code tutor):邊界句在自訂 system_prompt 覆蓋 base 時仍恆附加', {
    custom <- 'Custom instructions: only use base R.'
    txt <- .askllmr_system_prompt(role = 'consultant', lang = 'en',
                                   system_prompt = custom)
    expect_true(grepl('jamovi Module Guider', txt, fixed = TRUE))
})
