# test-key-loader.R
# 測試 load_api_key() 五段查找鏈與 key_setup_text()

test_that('第 1 段:env_vars 直接有值時回傳,來源標為 env', {
    withr::local_envvar(ASKLLM_TEST_KEY_1 = 'sk-direct-value')
    result <- load_api_key('ASKLLM_TEST_KEY_1')
    expect_equal(result$key, 'sk-direct-value')
    expect_equal(result$source, 'env')
})

test_that('多個 env_vars 時,第一個有值者勝', {
    withr::local_envvar(
        ASKLLM_TEST_KEY_A = NA,
        ASKLLM_TEST_KEY_B = 'sk-second-wins')
    result <- load_api_key(c('ASKLLM_TEST_KEY_A', 'ASKLLM_TEST_KEY_B'))
    expect_equal(result$key, 'sk-second-wins')
    expect_equal(result$source, 'env')
})

test_that('第 2 段:USERPROFILE/.Renviron 命中', {
    withr::local_envvar(ASKLLM_TEST_KEY_2 = NA)
    tmp <- withr::local_tempdir()
    writeLines('ASKLLM_TEST_KEY_2=sk-userprofile-root', file.path(tmp, '.Renviron'))
    withr::local_envvar(USERPROFILE = tmp)

    result <- load_api_key('ASKLLM_TEST_KEY_2')
    expect_equal(result$key, 'sk-userprofile-root')
    expect_equal(result$source, file.path(tmp, '.Renviron'))
})

test_that('第 3 段:USERPROFILE/OneDrive/文件/.Renviron 命中', {
    withr::local_envvar(ASKLLM_TEST_KEY_3 = NA)
    tmp <- withr::local_tempdir()
    dir.create(file.path(tmp, 'OneDrive', '文件'), recursive = TRUE)
    writeLines('ASKLLM_TEST_KEY_3=sk-onedrive-wenjian',
        file.path(tmp, 'OneDrive', '文件', '.Renviron'))
    withr::local_envvar(USERPROFILE = tmp)

    result <- load_api_key('ASKLLM_TEST_KEY_3')
    expect_equal(result$key, 'sk-onedrive-wenjian')
    expect_equal(result$source, file.path(tmp, 'OneDrive', '文件', '.Renviron'))
})

test_that('第 4 段:USERPROFILE/OneDrive/Documents/.Renviron 命中', {
    withr::local_envvar(ASKLLM_TEST_KEY_4 = NA)
    tmp <- withr::local_tempdir()
    dir.create(file.path(tmp, 'OneDrive', 'Documents'), recursive = TRUE)
    writeLines('ASKLLM_TEST_KEY_4=sk-onedrive-documents',
        file.path(tmp, 'OneDrive', 'Documents', '.Renviron'))
    withr::local_envvar(USERPROFILE = tmp)

    result <- load_api_key('ASKLLM_TEST_KEY_4')
    expect_equal(result$key, 'sk-onedrive-documents')
    expect_equal(result$source, file.path(tmp, 'OneDrive', 'Documents', '.Renviron'))
})

test_that('第 5 段:~/.Renviron 墊底命中(USERPROFILE 全段落空)', {
    withr::local_envvar(ASKLLM_TEST_KEY_5 = NA, USERPROFILE = '')
    tmp <- withr::local_tempdir()
    withr::local_envvar(HOME = tmp)
    writeLines('ASKLLM_TEST_KEY_5=sk-home-fallback', file.path(tmp, '.Renviron'))

    result <- load_api_key('ASKLLM_TEST_KEY_5')
    expect_equal(result$key, 'sk-home-fallback')
    expect_equal(result$source, file.path(tmp, '.Renviron'))
})

test_that('全段皆未命中時回傳 NULL', {
    withr::local_envvar(ASKLLM_TEST_KEY_NONE = NA, USERPROFILE = '', HOME = '')
    result <- load_api_key('ASKLLM_TEST_KEY_NONE')
    expect_null(result)
})

test_that('USERPROFILE 為空字串時不炸,直接跳過 2-4 段', {
    withr::local_envvar(ASKLLM_TEST_KEY_EMPTY_UP = NA, USERPROFILE = '')
    expect_error(load_api_key('ASKLLM_TEST_KEY_EMPTY_UP'), NA)
})

test_that('不存在的 .Renviron 檔案不會造成 readRenviron 出錯', {
    withr::local_envvar(ASKLLM_TEST_KEY_NOFILE = NA)
    tmp <- withr::local_tempdir()
    withr::local_envvar(USERPROFILE = file.path(tmp, 'does-not-exist'))
    expect_error(load_api_key('ASKLLM_TEST_KEY_NOFILE'), NA)
})

test_that('key_setup_text() 含金鑰申請網址、.Renviron 路徑、重啟提醒等關鍵字', {
    withr::local_envvar(USERPROFILE = 'C:\\Users\\testuser')
    txt <- key_setup_text('nim', 'NVIDIA_API_KEY', 'https://build.nvidia.com')

    expect_true(is.character(txt))
    expect_true(grepl('https://build.nvidia.com', txt, fixed = TRUE))
    expect_true(grepl('.Renviron', txt, fixed = TRUE))
    expect_true(grepl('NVIDIA_API_KEY', txt, fixed = TRUE))
    expect_true(grepl('nvapi-', txt, fixed = TRUE))
    expect_true(grepl('C:\\Users\\testuser', txt, fixed = TRUE))
    expect_true(grepl('重啟', txt))  # 重啟
    expect_true(grepl('本機', txt))  # 本機(隱私提醒)
})
