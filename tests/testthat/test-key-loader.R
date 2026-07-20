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

test_that('第 2 段:Windows 使用者層登錄檔環境變數命中', {
    withr::local_envvar(ASKLLM_TEST_KEY_RU = NA, USERPROFILE = '', HOME = '')
    testthat::local_mocked_bindings(
        .read_registry_env = function(scope) {
            if (scope == 'user') list(ASKLLM_TEST_KEY_RU = 'sk-registry-user') else NULL
        })
    result <- load_api_key('ASKLLM_TEST_KEY_RU')
    expect_equal(result$key, 'sk-registry-user')
    expect_equal(result$source, 'registry:user')
})

test_that('第 3 段:Windows 系統層登錄檔命中(使用者層無值)', {
    withr::local_envvar(ASKLLM_TEST_KEY_RS = NA, USERPROFILE = '', HOME = '')
    testthat::local_mocked_bindings(
        .read_registry_env = function(scope) {
            if (scope == 'system') list(ASKLLM_TEST_KEY_RS = 'sk-registry-system') else NULL
        })
    result <- load_api_key('ASKLLM_TEST_KEY_RS')
    expect_equal(result$key, 'sk-registry-system')
    expect_equal(result$source, 'registry:system')
})

test_that('登錄檔段:多 env_vars 依序取第一個有值者', {
    withr::local_envvar(ASKLLM_TEST_KEY_RA = NA, ASKLLM_TEST_KEY_RB = NA,
        USERPROFILE = '', HOME = '')
    testthat::local_mocked_bindings(
        .read_registry_env = function(scope) {
            if (scope == 'user') list(ASKLLM_TEST_KEY_RB = 'sk-rb') else NULL
        })
    result <- load_api_key(c('ASKLLM_TEST_KEY_RA', 'ASKLLM_TEST_KEY_RB'))
    expect_equal(result$key, 'sk-rb')
    expect_equal(result$source, 'registry:user')
})

test_that('登錄檔讀取拋錯(如非 Windows)時靜默略過,落到 .Renviron 段', {
    withr::local_envvar(ASKLLM_TEST_KEY_RF = NA)
    tmp <- withr::local_tempdir()
    writeLines('ASKLLM_TEST_KEY_RF=sk-file-after-registry-fail',
        file.path(tmp, '.Renviron'))
    withr::local_envvar(USERPROFILE = tmp)
    testthat::local_mocked_bindings(
        .read_registry_env = function(scope) stop('registry unavailable'))
    result <- load_api_key('ASKLLM_TEST_KEY_RF')
    expect_equal(result$key, 'sk-file-after-registry-fail')
    expect_equal(result$source, file.path(tmp, '.Renviron'))
})

test_that('key_setup_text() 以 Windows 環境變數為主要設定方式', {
    txt <- key_setup_text('nim', 'NVIDIA_API_KEY', 'https://build.nvidia.com')
    expect_true(grepl('環境變數', txt))
    expect_true(grepl('setx', txt))
})

test_that('key_setup_text() 含金鑰申請網址、.Renviron 路徑、重啟提醒等關鍵字', {
    withr::local_envvar(USERPROFILE = 'C:\\Users\\testuser')
    txt <- key_setup_text('nim', 'NVIDIA_API_KEY', 'https://build.nvidia.com')

    expect_true(is.character(txt))
    expect_true(grepl('https://build.nvidia.com', txt, fixed = TRUE))
    expect_true(grepl('.Renviron', txt, fixed = TRUE))
    expect_true(grepl('NVIDIA_API_KEY', txt, fixed = TRUE))
    expect_true(grepl('your-api-key', txt, fixed = TRUE))  # 未給範例時用通用佔位
    expect_true(grepl('C:\\Users\\testuser', txt, fixed = TRUE))
    expect_true(grepl('重啟', txt))  # 重啟
    expect_true(grepl('本機', txt))  # 本機(隱私提醒)
})

test_that('key_setup_text() 為中英雙語(與介面其他文字一致)', {
    txt <- key_setup_text('NVIDIA NIM', 'NVIDIA_API_KEY',
        'https://build.nvidia.com', 'nvapi-xxxxxxxx')
    expect_true(grepl('環境變數', txt))
    expect_true(grepl('environment variable', txt, ignore.case = TRUE))
    expect_true(grepl('PowerShell', txt, fixed = TRUE))
    expect_true(grepl('restart jamovi', txt, ignore.case = TRUE))
    expect_true(grepl('Privacy', txt, ignore.case = TRUE))
})

test_that('key_setup_text() 使用傳入的金鑰範例,不寫死 NVIDIA 前綴', {
    txt <- key_setup_text('GitHub Models', 'GITHUB_TOKEN',
        'https://github.com/settings/tokens', 'ghp_xxxxxxxxxxxx')
    expect_true(grepl('ghp_xxxxxxxxxxxx', txt, fixed = TRUE))
    expect_false(grepl('nvapi-', txt, fixed = TRUE))
})
