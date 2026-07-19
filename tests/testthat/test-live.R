# test-live.R — opt-in 真實 NIM 呼叫
# 需環境變數 ASKLLM_LIVE_TESTS=1 且 NVIDIA_API_KEY 已設定才會執行

test_that('live NIM 呼叫回傳 PONG', {
    skip_if(Sys.getenv('ASKLLM_LIVE_TESTS') != '1' ||
            !nzchar(Sys.getenv('NVIDIA_API_KEY')))

    res <- ask_llm(
        question = 'Say PONG and nothing else.',
        base_url = 'https://integrate.api.nvidia.com/v1',
        model    = 'meta/llama-3.1-8b-instruct',
        api_key  = Sys.getenv('NVIDIA_API_KEY')
    )

    expect_true(res$ok)
    expect_false(is.null(res$text))
    expect_match(res$text, 'PONG')
    expect_lt(res$elapsed_s, 30)
})
