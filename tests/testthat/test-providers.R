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
    expect_equal(spec$default_model, 'gemini-flash-latest')
    expect_equal(spec$signup_url, 'https://aistudio.google.com/apikey')
})

test_that('github provider 全欄位正確', {
    spec <- provider_spec('github')
    expect_equal(spec$base_url, 'https://models.github.ai/inference')
    expect_equal(spec$env_vars,
        c('GITHUB_MODELS_TOKEN', 'GITHUB_PAT', 'GITHUB_TOKEN'))
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

test_that('每個 provider 都提供 key_example(供設定教學顯示正確格式)', {
    expect_true(grepl('^nvapi-', provider_spec('nim')$key_example))
    expect_true(grepl('^AIza', provider_spec('gemini')$key_example))
    # fine-grained token(github_pat_)是 GitHub 目前推薦的形式
    expect_true(grepl('^github_pat_', provider_spec('github')$key_example))
    expect_true(is.character(provider_spec('ollama')$key_example))
    expect_true(nzchar(provider_spec('custom', 'http://x/v1')$key_example))
})

test_that('github 首選變數名不與 gh CLI/git 的 GITHUB_TOKEN 相撞', {
    ev <- provider_spec('github')$env_vars
    # gh CLI 與 git credential helper 會優先讀 GITHUB_TOKEN;若使用者把只有
    # Models 權限的 token 設在該變數,會癱瘓自己的 git 推送。故首選專用名稱。
    expect_equal(ev[1], 'GITHUB_MODELS_TOKEN')
    expect_true('GITHUB_TOKEN' %in% ev)      # 仍相容既有設定
    expect_true(which(ev == 'GITHUB_TOKEN') == length(ev))   # 但排最後
})

test_that('openrouter provider 全欄位正確(項目 2:升為一級供應商)', {
    spec <- provider_spec('openrouter')
    expect_equal(spec$base_url, 'https://openrouter.ai/api/v1')
    expect_equal(spec$env_vars, c('OPENROUTER_API_KEY', 'LLM_API_KEY'))
    expect_true(spec$needs_key)
    expect_equal(spec$default_model, 'openai/gpt-oss-20b:free')
    expect_equal(spec$signup_url, 'https://openrouter.ai/keys')
    expect_true(grepl('^sk-or-v1-', spec$key_example))
})

test_that('openrouter env_vars 順序:OPENROUTER_API_KEY 優先,LLM_API_KEY 墊底相容', {
    ev <- provider_spec('openrouter')$env_vars
    expect_equal(ev[1], 'OPENROUTER_API_KEY')
    expect_equal(ev[length(ev)], 'LLM_API_KEY')
})

test_that('既有 5 個 provider spec 全部不變(回歸鎖,新增 openrouter 不應動到既有欄位)', {
    nim <- provider_spec('nim')
    expect_equal(nim$base_url, 'https://integrate.api.nvidia.com/v1')
    expect_equal(nim$env_vars, 'NVIDIA_API_KEY')
    expect_equal(nim$default_model, 'meta/llama-3.1-8b-instruct')

    gemini <- provider_spec('gemini')
    expect_equal(gemini$base_url, 'https://generativelanguage.googleapis.com/v1beta/openai')
    expect_equal(gemini$env_vars, c('GEMINI_API_KEY', 'GOOGLE_API_KEY'))
    expect_equal(gemini$default_model, 'gemini-flash-latest')

    github <- provider_spec('github')
    expect_equal(github$base_url, 'https://models.github.ai/inference')
    expect_equal(github$env_vars, c('GITHUB_MODELS_TOKEN', 'GITHUB_PAT', 'GITHUB_TOKEN'))
    expect_equal(github$default_model, 'openai/gpt-4o-mini')

    ollama <- provider_spec('ollama')
    expect_equal(ollama$base_url, 'http://localhost:11434/v1')
    expect_equal(ollama$env_vars, character(0))
    expect_false(ollama$needs_key)
    expect_equal(ollama$default_model, 'llama3.2')

    custom <- provider_spec('custom', base_url_option = 'https://my-endpoint.example.com/v1')
    expect_equal(custom$base_url, 'https://my-endpoint.example.com/v1')
    expect_equal(custom$env_vars, 'LLM_API_KEY')
    expect_equal(custom$default_model, '')
})

test_that('a.yaml 的 provider options 名單與 provider_spec 支援的名單完全一致', {
    a_yaml <- yaml::read_yaml(
        file.path('..', '..', 'jamovi', 'askllm.a.yaml'))
    provider_opt <- Filter(function(o) o$name == 'provider', a_yaml$options)[[1]]
    yaml_names <- vapply(provider_opt$options, function(o) o$name, character(1))

    known_providers <- c('nim', 'gemini', 'github', 'ollama', 'custom', 'openrouter')
    for (p in known_providers) {
        expect_error(provider_spec(p, base_url_option = 'https://x/v1'), NA)
    }
    expect_equal(sort(yaml_names), sort(known_providers))
})
