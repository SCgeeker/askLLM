
# This file is a generated template, your changes will not be overwritten

# =============================================================================
# askllmr(R code tutor)分析類別 —— M-A2 骨架階段。
# `.run()` 只顯示引導文字(`.askllmr_guide_text()`,定義於 R/r-tutor.R),
# 不接 LLM 呼叫、不掃 Rj、不組 prompt。真邏輯留給 M-A3。
# =============================================================================

askllmrClass <- if (requireNamespace('jmvcore', quietly=TRUE)) R6::R6Class(
    "askllmrClass",
    inherit = askllmrBase,
    private = list(

        # 只設定引導文字,零網路
        .init = function() {
            self$results$instructions$setContent(.askllmr_guide_text())
        },

        # 骨架階段:.run() 只重申引導文字,不做任何運算或呼叫
        .run = function() {
            self$results$instructions$setContent(.askllmr_guide_text())
        }
    )
)
