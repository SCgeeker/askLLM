# R/llm-providers.R
# provider 對照表:全 provider 統一走 OpenAI 相容端點。

#' 取得 provider 設定
#'
#' @param name provider 名稱:'nim'、'gemini'、'github'、'ollama'、'custom'
#' @param base_url_option custom provider 專用的 base URL(來自 baseUrl 選項)
#' @return list(base_url, env_vars, needs_key, default_model, signup_url);
#'   custom 缺 base_url_option 時多帶 error 欄位
#' @export
provider_spec <- function(name, base_url_option = '') {

    if (name == 'nim') {
        return(list(
            base_url = 'https://integrate.api.nvidia.com/v1',
            env_vars = 'NVIDIA_API_KEY',
            needs_key = TRUE,
            default_model = 'meta/llama-3.1-8b-instruct',
            signup_url = 'https://build.nvidia.com'))
    }

    if (name == 'gemini') {
        return(list(
            base_url = 'https://generativelanguage.googleapis.com/v1beta/openai',
            env_vars = c('GEMINI_API_KEY', 'GOOGLE_API_KEY'),
            needs_key = TRUE,
            default_model = 'gemini-2.0-flash',
            signup_url = 'https://aistudio.google.com/apikey'))
    }

    if (name == 'github') {
        return(list(
            base_url = 'https://models.github.ai/inference',
            env_vars = c('GITHUB_TOKEN', 'GITHUB_PAT'),
            needs_key = TRUE,
            default_model = 'openai/gpt-4o-mini',
            signup_url = 'https://github.com/settings/tokens'))
    }

    if (name == 'ollama') {
        return(list(
            base_url = 'http://localhost:11434/v1',
            env_vars = character(0),
            needs_key = FALSE,
            default_model = 'llama3.2',
            signup_url = 'https://ollama.com'))
    }

    if (name == 'custom') {
        if (!nzchar(base_url_option)) {
            return(list(
                base_url = '',
                env_vars = 'LLM_API_KEY',
                needs_key = TRUE,
                default_model = '',
                signup_url = '',
                error = 'custom provider 需要填寫 baseUrl 選項'))
        }
        return(list(
            base_url = base_url_option,
            env_vars = 'LLM_API_KEY',
            needs_key = TRUE,
            default_model = '',
            signup_url = ''))
    }

    stop(sprintf("provider_spec(): unknown provider name '%s'", name))
}
