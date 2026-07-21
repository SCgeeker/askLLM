# GitHub Models:免費可用的模型清單

只要有 **GitHub 帳號**(Copilot Free 即可,不需信用卡),把權杖設定好之後(見 [SETUP-github.zh-TW.md](SETUP-github.zh-TW.md)),下列模型都能在 askLLM 的 **Model** 欄位直接填入使用。

本頁資料以 GitHub Models 目錄 API(`https://models.github.ai/catalog/models`)於 **2026-07-21** 查詢所得,共 37 個模型(含 2 個 embedding,askLLM 用不到,未列出)。清單會隨 GitHub 調整而變動,最新內容請見 <https://github.com/marketplace/models>。

## 免費額度(Copilot Free)

額度取決於模型的 **tier**,與模型大小無關:

| Tier | 每分鐘請求 | 每日請求 | 單次 token 上限 | 併發數 |
|---|---|---|---|---|
| **low** | 15 | 150 | 8000 in / 4000 out | 5 |
| **high** | 10 | 50 | 8000 in / 4000 out | 2 |
| **custom** | 依模型而定,免費方案通常不開放或額度極少 | | | |

> 官方額度說明:<https://docs.github.com/en/github-models/use-github-models/prototyping-with-ai-models>
>
> ⚠️ 單次輸入上限 **8000 tokens** 對 askLLM 有實際影響:勾選的變項太多、`Max factor levels shown` 設太大時,資料摘要可能超過上限。若遇到用量相關錯誤,先減少勾選的變項數。

## low tier —— 額度最寬鬆,**建議教學與日常使用**

| 模型 ID | 發行者 | 備註 |
|---|---|---|
| `openai/gpt-4o-mini` | OpenAI | **askLLM 預設值**,速度與品質平衡 |
| `openai/gpt-4.1-mini` | OpenAI | 較新一代,指令遵循較佳 |
| `openai/gpt-4.1-nano` | OpenAI | 最輕量、最快 |
| `mistral-ai/mistral-medium-2505` | Mistral AI | 中型通用 |
| `mistral-ai/mistral-small-2503` | Mistral AI | 小型通用 |
| `mistral-ai/ministral-3b` | Mistral AI | 極小型,速度優先 |
| `mistral-ai/codestral-2501` | Mistral AI | 偏程式碼用途 |
| `cohere/cohere-command-a` | Cohere | 通用 |
| `meta/meta-llama-3.1-8b-instruct` | Meta | ⚠ 目錄有列但呼叫回 400 `Unknown model`(2026-07-21 實測) |
| `meta/llama-3.2-11b-vision-instruct` | Meta | 支援影像輸入 |
| `microsoft/phi-4` | Microsoft | 推理能力佳,但**實測回應要 5 分鐘**,不適合課堂 |
| `microsoft/phi-4-mini-instruct` | Microsoft | 更輕量 |
| `microsoft/phi-4-mini-reasoning` | Microsoft | 偏推理 |
| `microsoft/phi-4-reasoning` | Microsoft | 偏推理 |
| `microsoft/phi-4-multimodal-instruct` | Microsoft | 多模態 |

## high tier —— 能力較強,但每日僅 50 次

| 模型 ID | 發行者 | 備註 |
|---|---|---|
| `openai/gpt-4.1` | OpenAI | 長脈絡(輸入上限百萬級),綜合能力強 |
| `openai/gpt-4o` | OpenAI | 通用旗艦 |
| `meta/llama-3.3-70b-instruct` | Meta | 大型開源模型 |
| `meta/meta-llama-3.1-405b-instruct` | Meta | 超大型開源模型 |
| `meta/llama-4-scout-17b-16e-instruct` | Meta | Llama 4 系列 |
| `meta/llama-4-maverick-17b-128e-instruct-fp8` | Meta | Llama 4 系列 |
| `meta/llama-3.2-90b-vision-instruct` | Meta | 大型視覺模型 |
| `deepseek/deepseek-v3-0324` | DeepSeek | 大型通用 |

## custom tier —— 進階/推理模型,免費方案多半不開放

`openai/gpt-5`、`openai/gpt-5-chat`、`openai/gpt-5-mini`、`openai/gpt-5-nano`、`openai/o1`、`openai/o1-mini`、`openai/o1-preview`、`openai/o3`、`openai/o3-mini`、`openai/o4-mini`、`deepseek/deepseek-r1`、`deepseek/deepseek-r1-0528`

> 這些模型即使出現在目錄中,免費帳號呼叫時仍可能回 403(權限不足)或很快用盡額度。askLLM 會顯示對應的友善訊息。

## 用 askLLM 比較不同模型

repo 內附比較腳本,可用同一份資料與問題連續問多個模型,產出並排報告以評估回答的**準確性與完整性**:

```r
# 在 R console(需已安裝 askLLM 與設好權杖)
source('tools/compare-models.R')
compare_models(
    models = c('openai/gpt-4o-mini', 'openai/gpt-4.1-mini',
               'openai/gpt-4.1', 'mistral-ai/mistral-medium-2505'),
    provider = 'github')
```

詳見 [`tools/compare-models.R`](../tools/compare-models.R) 檔頭說明。

## 挑選建議(針對 askLLM 的用途)

askLLM 的任務是「讀懂資料摘要 → 給統計分析建議」,需要**良好的指令遵循**與**中文表達能力**:

- **教學示範、學生自用**:先用 low tier 的 `openai/gpt-4o-mini` 或 `openai/gpt-4.1-mini`——額度足夠一整堂課反覆嘗試。
- **要求回答最完整**:改用 high tier 的 `openai/gpt-4.1`,但注意每日 50 次。
- **想比較開源模型**:`meta/llama-3.3-70b-instruct`(high)與 `microsoft/phi-4`(low)是有趣的對照。
- **中文回答品質**差異在小模型上較明顯,建議實際比較後再決定要教學生用哪一個。
