# jamovi library 投稿回覆記錄與解讀

日期:2026-07-27|來源:Jonathon Love(jamovi 專案負責人)電郵|結果:**暫不上架,非拒絕**

## 決定摘要

askLLM 暫不納入 jamovi library。明確聲明「not because of anything wrong with the module」;隱私設計(摘要統計不含原始列、金鑰不寫入存檔、Ollama 本機選項)與防抖、錯誤處理獲逐項肯定。

## 核心團隊的三層關切(解讀)

1. **價值天花板(效益)**:jamovi 平台目前不讓模組取得分析輸出,LLM 模組只能拿到變項摘要——使用者自己貼數字進聊天視窗也能得到類似結果,效益不足以合理化新風險。**他們想先修平台限制**("the thing we'd want to fix first")。
2. **信任邊界(安全)**:「使用者資料 → 任意外部端點 + 使用者自備金鑰」是 library 從未收過的模組類型,上架等於官方背書該資料流;custom provider 的 arbitrary endpoint 是審查上最棘手處。
3. **先例(治理)**:第一個上架的 LLM 模組會成為事實標準;他們要先建立安全審查政策,「rather build this properly than let the first version in and figure out the policy afterward」。

## Roadmap 訊號

- jamovi 計畫讓模組取得「比變項摘要更有意義的東西」(即分析輸出)
- 將建立 LLM/外部端點模組的安全審查流程
- 兩者完成前不要求開發者投入("work we need to do ourselves before we ask developers to build against it")
- 主動承諾後續聯繫("I'll reach out once we've made progress")並保持討論

## 對本專案的意涵

- **sideload 分發不受影響**:GitHub Release 照常,教學使用照常
- **升級路徑已定**:分析輸出 API 開放後,askLLM 的殺手級功能是「解讀剛跑出的分析結果」——恰好跨過對方定義的價值門檻
- **可貢獻的素材**:docs/LIMITATIONS 的幻覺實測、provider 設計(curated vs arbitrary)的取捨經驗,正是對方制定審查政策需要的證據
- 已有的隱私設計與未來政策方向一致,不需返工

## 後續行動

- [ ] 回信:致謝、分享 LIMITATIONS 實測、表達願任 security review 測試案例、願參與模組端 API 設計討論
- [ ] 追蹤 jamovi 對「模組取得分析輸出」的進展(升級 jamovi 版本時檢查 release notes)
- [ ] README 安裝節維持 sideload 為主,「上架後」措辭不變(仍是計畫)


## Human Author responses

- 同意core team的第一點關切，這也是目前開發MCP遇到的限制。所以重心轉向迭代askLLM。
- 目前的迭代方向是讓askLLM成為駐在jamovi內的統計諮詢員：使用者載入資料，LLM根據提示詞給予適配的統計分析方法建議。如果askLLM能將各筆資料變項描述，以及已上架的模組資訊與使用者的提示詞一起包裝給LLM處理，也許能給予更適合使用者需要的建議。
- 長期迭代想法(可能之後會改變)：雖然askLLM不能讀取jamovi的Results，askLLM可以幫助模組開發者優化Results的輸出設計，讓使用者可以更容易理解報表與如何選擇進一步的分析方法或報告。
- 以上迭代需要收集大量使用資訊，如果在網路社群推廣jamovi使用者與開發者協助測試及回饋，適切表達我與core team的想法及立場是重點。
