# R/llm-providers.R
# provider 對照表:全 provider 統一走 OpenAI 相容端點。

#' 取得 provider 設定
#'
#' @param name provider 名稱:'nim'、'gemini'、'openrouter'、'github'、'ollama'、'custom'
#' @param base_url_option custom provider 專用的 base URL(來自 baseUrl 選項)
#' @return list(base_url, env_vars, needs_key, default_model, signup_url, key_example);
#'   custom 缺 base_url_option 時多帶 error 欄位
#' @export
provider_spec <- function(name, base_url_option = '') {

    if (name == 'nim') {
        return(list(
            base_url = 'https://integrate.api.nvidia.com/v1',
            env_vars = 'NVIDIA_API_KEY',
            needs_key = TRUE,
            default_model = 'meta/llama-3.1-8b-instruct',
            signup_url = 'https://build.nvidia.com',
            key_example = 'nvapi-xxxxxxxxxxxxxxxxxxxxxxxx'))
    }

    if (name == 'gemini') {
        return(list(
            base_url = 'https://generativelanguage.googleapis.com/v1beta/openai',
            env_vars = c('GEMINI_API_KEY', 'GOOGLE_API_KEY'),
            needs_key = TRUE,
            default_model = 'gemini-flash-latest',
            signup_url = 'https://aistudio.google.com/apikey',
            key_example = 'AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXX'))
    }

    if (name == 'openrouter') {
        return(list(
            base_url = 'https://openrouter.ai/api/v1',
            # OPENROUTER_API_KEY 優先;LLM_API_KEY 墊底,相容既有 custom 設定習慣。
            env_vars = c('OPENROUTER_API_KEY', 'LLM_API_KEY'),
            needs_key = TRUE,
            # :free 後綴為 OpenRouter 免費模型的必要標記(見 SETUP-openrouter)。
            # 2026-07-29 以真金鑰對 /models 端點實測確認存在且可正常對話。
            default_model = 'openai/gpt-oss-20b:free',
            signup_url = 'https://openrouter.ai/keys',
            key_example = 'sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxx'))
    }

    if (name == 'github') {
        # GitHub Models 已於 2026-07-30 由 GitHub 全面退役(playground、
        # catalog、inference API 一併關閉;ellmer 0.5.0 亦將 chat_github()
        # 標為 defunct)。v1.3.2 起此 provider 只回傳 `error`,呼叫端
        # (.runInner() / .askllm_test_connection_text())看到 error 即顯示
        # 並提前 return,絕不發出任何網路請求。
        #
        # 選項值 'github' 刻意保留在 a.yaml 的 provider 清單中(標題改為
        # retired),以免既存 .omv 存檔載入時 provider 值不在 enum 內而失效;
        # 其餘欄位維持退役前的值,供既有測試與文件對照,實際不再被使用。
        return(list(
            base_url = 'https://models.github.ai/inference',
            env_vars = c('GITHUB_MODELS_TOKEN', 'GITHUB_PAT', 'GITHUB_TOKEN'),
            needs_key = TRUE,
            default_model = 'openai/gpt-4o-mini',
            signup_url = 'https://github.com/settings/tokens',
            key_example = 'github_pat_xxxxxxxxxxxxxxxxxxxxxxxx',
            retired = TRUE,
            error = .askllm_github_retired_text()))
    }

    if (name == 'ollama') {
        return(list(
            base_url = 'http://localhost:11434/v1',
            env_vars = character(0),
            needs_key = FALSE,
            default_model = 'llama3.2',
            signup_url = 'https://ollama.com',
            key_example = '(not required)'))
    }

    if (name == 'custom') {
        if (!nzchar(base_url_option)) {
            return(list(
                base_url = '',
                env_vars = 'LLM_API_KEY',
                needs_key = TRUE,
                default_model = '',
                signup_url = '',
            key_example = '<your-api-key>',
                error = 'custom provider 需要填寫 baseUrl 選項'))
        }
        return(list(
            base_url = base_url_option,
            env_vars = 'LLM_API_KEY',
            needs_key = TRUE,
            default_model = '',
            signup_url = '',
            key_example = '<your-api-key>'))
    }

    stop(sprintf("provider_spec(): unknown provider name '%s'", name))
}

#' GitHub Models 退役說明(先英文整段,再中文整段;零網路)
#'
#' 供 [provider_spec()] 的 `error` 欄位使用;呼叫端直接顯示於 instructions。
#' 替代供應商依 docs/choose-model.html 的「免信用卡」分組列出。
#' @keywords internal
.askllm_github_retired_text <- function() {
    paste(
        'GitHub Models was retired by GitHub on 2026-07-30 and can no longer',
        'be used. Please switch Provider to OpenRouter, NVIDIA NIM, or Google',
        'Gemini (all offer a free tier without a credit card), then re-tick',
        'Submit. Which one to pick:',
        'https://scgeeker.github.io/askLLM/choose-model.html',
        '',
        'GitHub Models 已於 2026-07-30 由 GitHub 停止服務,無法再使用。',
        '請將 Provider 改為 OpenRouter、NVIDIA NIM 或 Google Gemini',
        '(皆有免信用卡的免費額度),再重新勾選 Submit。挑選指南:',
        'https://scgeeker.github.io/askLLM/choose-model.html',
        sep = '\n')
}
