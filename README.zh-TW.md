# askLLM

**在 jamovi 裡直接問 LLM 關於「你的資料」的問題。**

勾選你關心的變項,輸入問題(中英文皆可),askLLM 會把這些變項的摘要統計送給你選擇的 LLM,讓它針對你的資料集回答。askLLM 是一個模組、**兩個分析**——一個幫你挑該跑的 jamovi 分析,一個幫你寫該用的 R 程式碼。詳見下方[兩個分析](#兩個分析)。

**askLLM 是你的 copilot,不是自動駕駛。** 它只給建議:分析策略、jamovi 選單路徑、可貼進 Rj Editor 的 R 程式碼。資料、分析、程式碼一律由你自己執行——askLLM 不會替你跑分析,不會寫入欄位,也不會操作 jamovi 介面。

多階段的分析可以這樣迭代:在下一次提問時,自己把上一階段的執行結果摘要寫進提示詞,讓 LLM 據此給下一階段的操作或程式碼建議。askLLM 不讀取 jamovi 的分析輸出(平台限制,不是未實作的功能),所以每一步的結果都由你手動帶回來。操作示範見姊妹專案 `stat-skills-tutorials`。

<!--
備註(給開發者):動作模式的底層實作(R/action-*.R、.askllm_fill_output())原樣保留,但已休眠——UI 選項 enableActions/llmColumns 已從 a.yaml/r.yaml 撤下,見 R/askllm.b.R 的說明註解。上方的 copilot 邊界是明文原則,不是現況描述:該路徑目前保持休眠,要恢復接線仍須由使用者親自執行,不得變成代跑模組。裁決紀錄見 dev-notes/execution-plan.zh-TW.md 的 S1。
-->


## 三十秒看懂 askLLM

- **接地,不是亂猜** —— 建議被限制在你機器上真的裝了的東西:真實的 jamovi 選單路徑,以及你 Rj 環境真的有的 R 套件(v1.1 實測:選單路徑逐字命中 18/18,零虛構)。
- **你的資料還是你的** —— 只送摘要統計,API 金鑰不會寫進 `.omv` 檔;選 Ollama 則完全不外送。
- **是 copilot,不是自動駕駛** —— 只給建議(選單路徑、R 程式碼),分析永遠由你親手跑。

![勾選變項、輸入問題,LLM 針對你的資料回答,並給出具體的 jamovi 選單路徑](docs/img/hero.zh-TW.png)

[English README](README.md)

## 適合誰用

**如果你是這樣的人,askLLM 適合你 ——**

- 你用 jamovi 教統計或做研究,想教學生「怎麼跟 AI 協作又不被它唬」;
- 你不太寫 R,但想用 AI 當進 R 的階梯(這正是 R code tutor 的用途);
- 你的資料敏感、或機構禁止上雲——用 Ollama 讓一切都在本機執行。

**askLLM 刻意不做的事 ——**

- 它不會替你跑分析、不會寫入資料欄、不會操作 jamovi 介面(這是設計原則,不是缺功能);
- 若你想要「AI 全自動跑分析」,askLLM 不是那種工具。

## 兩個分析

askLLM 是一個模組,底下有兩個分析,都在 **Analyses ▸ askLLM** 下拉選單裡。看你要問的是哪一種,挑對應的那個。

| | **jamovi Module Guider** | **R code tutor** |
|---|---|---|
| 回答什麼 | 「我該跑哪個 jamovi 分析?」 | 「這個分析的 R 程式碼要怎麼寫?」 |
| 給出什麼 | 推薦的分析,並逐字引用選單路徑 | 可貼進 **Rj Editor** 自己執行的 R 程式碼 |
| 接地依據 | 你實際安裝的 jamovi 模組與其真實選單樹 | 你 Rj 環境實際隨附的 R 套件,加上 `data` |
| 問錯分析時 | 引導你改用 R code tutor | 引導你改用 jamovi Module Guider |

兩個分析都不會替你動手——Module Guider 告訴你去哪裡點,R code tutor 寫出程式碼讓*你*在 **Rj Editor** 裡執行;Rj 是**桌面版** jamovi 才有的模組(jamovi Cloud 沒有)。兩者都只送出你所選變項的摘要統計,絕不送原始資料列(詳見下方[隱私聲明](#隱私聲明))。想搭配 R code tutor 逛一輪、順便學一點 R,見**[跟著 Rj 學 R](https://scgeeker.github.io/askLLM/learn-r.html)**。

## 螢幕截圖

**一個模組、兩個 copilot——askLLM 選單**

![askLLM 分析選單,顯示 jamovi Module Guider 與 R code tutor](docs/img/menu.png)

**R code tutor——可貼進 Rj 的程式碼,接地於你的 Rj 套件**

![R code tutor 結果:程式碼區、解說、Open Rj 連結與 caveat](docs/img/r-code-tutor.png)

**完整迴圈——把程式碼貼進 Rj、自己執行**

![產出的程式碼貼進 Rj Editor,右側是 R 輸出](docs/img/rj-loop.png)

**同一題、三種語氣——Consultant／Tutor／Explainer**

![Consultant 人格回答遺漏值問題](docs/img/persona-consultant.png)

![Tutor 人格以引導式提示回答同一題](docs/img/persona-tutor.png)

![Explainer 人格以淺白方式回答同一題](docs/img/persona-explainer.png)

**用資料驅動人格——變數的 Description 當 system prompt**

`PS` 變數的 Description 寫著一句指示:**"You have to elaborate the reasons of your suggestions."**

![PS 變數的 Description 被用作 system prompt](docs/img/var-description-field.png)

在「Use a variable's Description as the system prompt」選它,回覆便逐項闡述理由。

![Module Guider 因變數 Description 成為 system prompt 而詳述理由](docs/img/var-description.png)

**Test Connection——不花一次呼叫就驗證金鑰**

![Test Connection 結果:金鑰有效、顯示金鑰來源、零計費](docs/img/test-connection.png)

## 安裝方式

askLLM 以側載(side-load)`.jmo` 檔的方式發佈。

**支援環境(目前版本):** Windows 64-bit、jamovi 28.2.0.0。

1. 在 jamovi 中點選右上角 `⊕` 圖示。
2. 切換到 **Side-load** 分頁。
3. 選擇 `.jmo` 檔(見本 repo 的 [`dist/`](dist/) 目錄)。
4. 等待安裝完成。

`.jmo` 檔綁定特定的**作業系統 × CPU 架構**(見檔名,如 `askLLM_1.3.0_win64.jmo`),只能安裝到相符的平台:為 Windows 建置的檔案無法安裝到 macOS 或 Linux。詳見 [`dist/README.zh-TW.md`](dist/README.zh-TW.md)。

## 快速開始(三步)

1. 在 jamovi 開啟資料集,從分析選單執行 **askLLM**,再從下拉選單挑 **jamovi Module Guider** 或 **R code tutor**。
2. 勾選要讓 LLM 知道的**變項(Variables to describe)**,並輸入你的**問題**。
3. 勾選 **Submit** 送出。數秒後即可看到回覆,並附上模型名稱與耗時。

修改問題前請先取消勾選 **Submit**,改好再重新勾選——避免每次改動都觸發一次新的(計費)呼叫。

**Include installed modules**(僅 jamovi Module Guider 有,預設開啟)會自動掃描你的 jamovi 模組並供給 LLM,讓路徑建議精準對應你安裝的分析;取消勾選此選項即回到 v1.0 行為。R code tutor 則是無條件掃描你的 Rj 環境,確保產出的程式碼只用你實際有的套件。

**Use a variable's Description as the system prompt**(在「LLM settings」內)可讓你直接用資料集本身驅動人格,不必在模組裡另外輸入:在 jamovi 變數的 Setup 面板中填入該變數的**Description**(如人格設定或任務指示),在此選取該變數,系統即會以它的 Description 作為 system prompt。在 jamovi Module Guider,優先序是:該變數的 Description(有選取且非空時)＞**Custom system prompt** 文字框 ＞ Persona 模板。R code tutor 沒有 Custom system prompt 文字框,優先序是:該變數的 Description(有選取且非空時)＞ Persona 模板。適合已在 codebook 中記錄好各變數情境、想直接讓 LLM 沿用的情境。

## 支援的 Provider

| Provider | 免費額度 / 免信用卡 | 執行位置 | 設定教學 |
|---|---|---|---|
| NVIDIA NIM | 有,免信用卡 | 雲端 | [SETUP-nim.zh-TW.md](docs/SETUP-nim.zh-TW.md) |
| Google Gemini | 有,免信用卡 | 雲端 | [SETUP-gemini.zh-TW.md](docs/SETUP-gemini.zh-TW.md) |
| OpenRouter | 有,免信用卡(`:free` 模型) | 雲端 | [SETUP-openrouter.zh-TW.md](docs/SETUP-openrouter.zh-TW.md) |
| GitHub Models | 有(需 GitHub 帳號) | 雲端 | [SETUP-github.zh-TW.md](docs/SETUP-github.zh-TW.md) |
| Ollama(本機) | 完全免費,無需金鑰 | 你的電腦 | [SETUP-ollama.zh-TW.md](docs/SETUP-ollama.zh-TW.md) |
| Custom(自訂端點) | 視端點而定 | 自訂 | [SETUP-custom.zh-TW.md](docs/SETUP-custom.zh-TW.md) |

只要有 GitHub 帳號就能免費使用 **35 個模型**(OpenAI、Meta Llama、Microsoft Phi、Mistral、DeepSeek、Cohere)——完整清單、免費額度與挑選建議見 **[GitHub Models 模型清單](docs/MODELS-github.zh-TW.md)**。

想比較不同模型回答的準確性與完整性,可用 [`tools/compare-models.R`](tools/compare-models.R):同一份資料與問題連續問多個模型,產出並排報告。

## 限制與使用建議

**LLM 會產生看似合理卻錯誤的內容。** v1.0 實測發現各家模型最常編造的是 **jamovi 選單路徑**(連 jamovi 沒有的選單都寫得很肯定);v1.1 已透過模組目錄掃描大幅緩解此問題(實測命中率 100%, 18/18 零虛構)。統計建議方向則大致合理,其他限制(統計建議適用性、數值查證)仍需自行判斷。

**兩個分析的查證方式不對等。** jamovi Module Guider 給的選單路徑可以拿你實際安裝的模組機械核對,如上所述。R code tutor 產的 R 程式碼就沒有等價的硬查證——R 是 Turing-complete,任何掃描都不可能證明任意生成的程式碼一定對。這正是 R code tutor 定位為「教學」的原因:它把程式碼交給你審閱、由你在 Rj 裡執行,絕不替你代跑。

完整的實測記錄與教學建議見 **[限制與使用建議](docs/LIMITATIONS.zh-TW.md)**。

## 隱私聲明

兩個分析共用同一套隱私設計:

- 送出給 LLM 的是**你所選變項的摘要統計**(如筆數、平均數、標準差、類別變項各水準次數等),**不是原始資料列**。
- API 金鑰只存於你本機的環境變數或 `.Renviron` 檔案,**不會寫入 `.omv` 檔案**,也不會出現在 jamovi 介面上任何地方。
- **jamovi Module Guider** 還會送出已安裝模組的名稱與選單清單(環境中繼資料,不含資料值),用以確保建議的路徑都真實存在;你可用「Include installed modules」選項關閉此功能。
- **R code tutor** 還會送出你 Rj 環境隨附的 R 套件**名稱**(絕不含套件內容),確保產出的程式碼只用你實際有的套件。它絕不替你執行 R——程式碼由你貼進 Rj、自己跑。
- 若你需要**完全零資料外送**,請選擇 **Ollama(本機)** 這個 provider——包含 LLM 本身在內,一切都在你自己的電腦上執行。

## 隱私設計 vs. 代理式 AI

JASP 0.98(2026-07-02 起)推出「完全整合 AI」,採取代理型設計:把分析結果與輸出本身完整送給 LLM 處理。askLLM 採取不同的資訊架構——諮詢型設計,兩個分析都**僅送摘要統計量,絕不送原始資料列**。兩種設計在面對敏感資料時的隱私風險有本質差異。

### askLLM vs. JASP 0.98 AI 比較

| 面向 | askLLM | JASP 0.98 代理型 AI |
|---|---|---|
| **送給 LLM 的資料** | 所選變項的摘要統計(筆數、平均、標準差、類別頻率等) | 分析結果與完整輸出(含所有細節) |
| **本機執行選項** | Ollama:完全本機,零外送;其他供應商則送雲端 | 僅限 JASP 內部;無完全本機選項 |
| **適用敏感資料情境** | ✓ 支援(尤其搭配 Ollama 本機執行) | ⚠ 需謹慎 |

### 為何敏感資料要特別留意?

**JASP 官方已公開警告**:許多免費 LLM 服務(包括免費層的商業模型)會將用戶輸入用於模型訓練或其他改進目的。這對**病患資料、公司機密、個人敏感資訊**等場景形成風險[^jasp-privacy-warning]。

- 如果你使用代理型 AI 搭配雲端服務,LLM 看到的是**完整的分析結果與統計輸出**,這些資訊經常包含足以識別個體或業務的細節。
- askLLM 的設計則不同:即使採用雲端服務,LLM 也僅看到**摘要統計量**(例如「平均值、標準差、樣本數」),足以建議分析方向,卻不足以重建個別觀測值。搭配 Ollama,你甚至可以**完全絕緣外網**,LLM 與你的資料都在本機運行。

### 建議

- **敏感資料優先使用 Ollama(本機)**:無需 API 金鑰、無外送任何資料。
- **如須使用雲端服務**:askLLM 的「摘要」特性天然降低風險,但建議先以非敏感資料測試、熟悉工具後再用在敏感場景。
- **嚴肅的敏感資料應用(病患、商業機密等)**:請諮詢貴機構的資料保護或隱私團隊,確認政策允許。

---

[^jasp-privacy-warning]: JASP Services BV. (2026). [Set up a Fully Integrated AI in JASP, and Run it for Freeeee](https://www.jasp-services.com/set-up-a-fully-integrated-ai-in-jasp-and-run-it-for-freeeee/); JASP team. (2026). [Free API Key Hunting](https://jasp-stats.org/2026/07/09/free-api-key-hunting/)

## 開發者資訊

從原始碼建置並安裝到指定的 jamovi 安裝路徑:

```r
jmvtools::install(home = "C:/Program Files/jamovi 28.2.0.0")
```

執行測試套件(純函式單元測試,以一般系統 R 執行,非 jamovi 內建 R):

```r
devtools::test()
```

## 授權

GPL-3(見 [`DESCRIPTION`](DESCRIPTION))。

## 致謝

- [ellmer](https://ellmer.tidyverse.org/) —— 本模組用來呼叫各家 LLM 的 R 套件。
- [jamovi](https://www.jamovi.org/) —— 本模組所依附的統計平台。
- [jmvtools](https://github.com/jamovi/jmvtools) —— 用來建置與打包本模組的工具鏈。
