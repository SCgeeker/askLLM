
# This file is a generated template, your changes will not be overwritten

askllmClass <- if (requireNamespace('jmvcore', quietly=TRUE)) R6::R6Class(
    "askllmClass",
    inherit = askllmBase,
    private = list(
        .run = function() {
            if (!self$options$run) {
                self$results$text$setContent(
                    'M0 network smoke test.\n勾選 "Run smoke test" 後會呼叫 NVIDIA NIM 一次。')
                return()
            }

            lines <- c(
                paste('R:', R.version.string),
                paste('ellmer:', tryCatch(as.character(utils::packageVersion('ellmer')),
                    error = function(e) paste('NOT AVAILABLE:', conditionMessage(e)))),
                paste('HOME:', Sys.getenv('HOME')),
                paste('USERPROFILE:', Sys.getenv('USERPROFILE')))

            key <- Sys.getenv('NVIDIA_API_KEY')
            if (!nzchar(key)) {
                up <- Sys.getenv('USERPROFILE')
                for (p in c(file.path(up, '.Renviron'),
                            file.path(up, 'OneDrive', '文件', '.Renviron'))) {
                    if (file.exists(p)) {
                        readRenviron(p)
                        key <- Sys.getenv('NVIDIA_API_KEY')
                        if (nzchar(key)) {
                            lines <- c(lines, paste('key source:', p))
                            break
                        }
                    }
                }
            } else {
                lines <- c(lines, 'key source: inherited env')
            }

            if (!nzchar(key)) {
                self$results$text$setContent(paste(
                    paste(lines, collapse = '\n'),
                    'NVIDIA_API_KEY not found in any .Renviron.', sep = '\n'))
                return()
            }

            result <- tryCatch({
                chat <- ellmer::chat_openai(
                    base_url = 'https://integrate.api.nvidia.com/v1',
                    api_key = key,
                    model = 'meta/llama-3.1-8b-instruct',
                    system_prompt = 'Reply in one short sentence.',
                    echo = 'none')
                t0 <- Sys.time()
                reply <- chat$chat('Say PONG and nothing else.')
                paste0('LLM reply: ', as.character(reply),
                       '\nelapsed: ',
                       round(as.numeric(difftime(Sys.time(), t0, units = 'secs')), 1), 's')
            }, error = function(e) paste('LLM CALL FAILED:', conditionMessage(e)))

            self$results$text$setContent(paste(
                paste(lines, collapse = '\n'), result, sep = '\n\n'))
        })
)
