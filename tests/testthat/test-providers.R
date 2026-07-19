# test-providers.R
# 測試 provider_spec() 五表全欄位

test_that('nim provider 全欄位正確', {
    spec <- provider_spec('nim')
    expect_equal(spec$base_url, 'https://integrate.api.nvidia.com/v1')
    expect_equal(spec$env_vars, 'NVIDIA_API_KEY')
    expect_true(spec$needs_key)
    expect_equal(spec$default_model, 'meta/llama-3.1-8b-instruct')
    expect_equal(spec$signup_url, 'https://build.nvidia.com')
})

test_that('gemini provider 全欄位正確', {
    spec <- provider_spec('gemini')
    expect_equal(spec$base_url, 'https://generativelanguage.googleapis.com/v1beta/openai')
    expect_equal(spec$env_vars, c('GEMINI_API_KEY', 'GOOGLE_API_KEY'))
    expect_true(spec$needs_key)
    expect_equal(spec$default_model, 'gemini-2.0-flash')
    expect_equal(spec$signup_url, 'https://aistudio.google.com/apikey')
})

test_that('github provider 全欄位正確', {
    spec <- provider_spec('github')
    expect_equal(spec$base_url, 'https://models.github.ai/inference')
    expect_equal(spec$env_vars, c('GITHUB_TOKEN', 'GITHUB_PAT'))
    expect_true(spec$needs_key)
    expect_equal(spec$default_model, 'openai/gpt-4o-mini')
    expect_equal(spec$signup_url, 'https://github.com/settings/tokens')
})

test_that('ollama provider 全欄位正確,免金鑰', {
    spec <- provider_spec('ollama')
    expect_equal(spec$base_url, 'http://localhost:11434/v1')
    expect_equal(spec$env_vars, character(0))
    expect_false(spec$needs_key)
    expect_equal(spec$default_model, 'llama3.2')
    expect_equal(spec$signup_url, 'https://ollama.com')
})

test_that('custom provider 帶有效 base_url_option 時正確', {
    spec <- provider_spec('custom', base_url_option = 'https://my-endpoint.example.com/v1')
    expect_equal(spec$base_url, 'https://my-endpoint.example.com/v1')
    expect_equal(spec$env_vars, 'LLM_API_KEY')
    expect_true(spec$needs_key)
    expect_equal(spec$default_model, '')
    expect_equal(spec$signup_url, '')
})

test_that('custom provider 缺 base_url_option 時回傳含 error 欄位的 list', {
    spec <- provider_spec('custom', base_url_option = '')
    expect_true(!is.null(spec$error))
    expect_true(is.character(spec$error))
})

test_that('custom provider 未給 base_url_option 參數(用預設值)也視為缺少', {
    spec <- provider_spec('custom')
    expect_true(!is.null(spec$error))
})

test_that('未知 provider 名稱時 stop()(程式錯誤)', {
    expect_error(provider_spec('not-a-real-provider'))
})
