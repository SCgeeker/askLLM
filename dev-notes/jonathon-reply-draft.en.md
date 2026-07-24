# Draft reply to Jonathon (English — the version to send)

> Status: DRAFT for the author's review. Do not send as-is without reading.
> Numbers below come from dev-notes/catalog-hit-rate.md (8 live calls, 2026-07-23).

---

Subject: Re: askLLM — took your point about value, here's what came of it

Hi Jonathon,

Thanks for your thoughtful reply, and especially for the frank framing of the value question. "A user could paste those numbers into a chat window themselves" was exactly the right challenge, and it sent us somewhere useful.

First, we (I and claude code) did some systematic testing of what LLMs actually get wrong in this setting. Across every model we tried (GPT-4o-mini, GPT-4.1 family, Gemini, Phi-4), the statistical suggestions themselves were broadly sensible, but every single model invented jamovi menu paths, confidently. Not just wrong locations: menus that don't exist at all ("Classification > Discriminant Analysis", "Visualise > Categorical plots", SPSS-style menu trees). The write-up is in the repo (docs/LIMITATIONS.en.md) if it's useful for your policy thinking.

That finding pointed at something a module *can* do that pasting into a chat window can't: the module now scans the locally installed modules (their jamovi.yaml files — builtin and user-side), builds the real menu tree, and attaches it to the prompt with strict instructions to only recommend from that list. For analyses the user doesn't have, it suggests only from the official library listing (synced from jamovi-library's modules.yaml at release time), or says plainly that it doesn't know.

The effect was bigger than we expected. In an A/B comparison over the same questions and models: with the catalog attached, **18 out of 18 cited menu paths were quoted exactly from the real menu tree — zero fabrications**. Without it, the models produced the usual invented submenus. The raw transcripts are in the repo too.

On the caution side, nothing has changed: still no access to Results (we know that boundary is yours to move), the installed-modules list is environment metadata only (no data values), it's disclosed in the in-app privacy text, and there's an off switch.

Two standing offers, no urgency attached: if it helps when you get to defining the security review for this category, we're glad to be the test case; and if a module-facing API for analysis output (or an official module-catalog query) reaches the design stage, we'd love to contribute a real use case. Happy to keep sharing whatever we learn in the meantime.

Cheers,
Sau-Chin

---

> Notes for the author (not part of the email):
> - Attach or link: docs/LIMITATIONS.en.md and dev-notes/catalog-hit-rate.md (both on GitHub: SCgeeker/askLLM).
> - If you prefer to soften the numbers claim, "18/18 across 8 calls on 2 models × 2 datasets" is the precise scope — small sample, honestly labelled.
> - v1.1 is released on GitHub; no mention of library resubmission is made deliberately — the ball stays in their court, as he asked.
