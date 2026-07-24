# Reply to Jonathon (English — the version to send)

> Finalized from the author's Chinese draft, translated and rhetorically
> optimized with the P-CSO workflow (pinker-syntax + pinker-coherence).
> Decisions applied: no hit-rate numbers in the body (point to the report);
> keep the security-review test-case offer; consultative framing on the
> community proposal.

---

Subject: Re: askLLM — following up on your point about value

Hi Jonathon,

Thanks for the thoughtful reply. Your best point was that a user could paste those numbers into a chat window themselves. It settled how I now think about the module: a statistical-method consultant living inside jamovi.

Before that, I'd been testing several LLMs, including GPT-4o-mini, the GPT-4.1 family, Gemini, and Phi-4, to see what they suggest as analyses and jamovi steps for a dataset. The statistical suggestions were mostly reasonable. But every model invented jamovi menu paths: not just wrong locations, but features jamovi doesn't have. So I moved toward what a module can do that a chat window can't. Version 1.1 scans the modules actually installed on the user's machine, rebuilds the real menu tree into the prompt, and tells the model to recommend only from that list. For analyses the user hasn't installed, it can only suggest installing from the official library list. Otherwise it says it doesn't know.

The test report is in the GitHub repo, in case it helps as you think through security guidance for module-LLM integration. And if it's useful when you get to defining that review, I'm glad to be a test case.

One more thing I'd value your view on: I'm considering sharing askLLM through the community and inviting interested jamovi module developers to iterate on it together. That could surface more useful feedback. The idea connects to your own aim of figuring out AI integrations properly, so I'd rather ask first than move ahead of you. What do you think? Either way, I'll keep sharing whatever I learn.

Cheers,
Sau-Chin

---

> Notes for the author (not part of the email):
> - The repo (github.com/SCgeeker/askLLM) has the write-up (docs/LIMITATIONS)
>   and the test report (dev-notes/v1.1-e2e); link whichever you prefer.
> - No hit-rate figure is stated in the body, by choice — the sample is small
>   and the report carries the honest detail.
> - No mention of library resubmission, deliberately — the ball stays in his court.
