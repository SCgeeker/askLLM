# jamovi Library Submission — Response Record and Reading

Date: 2026-07-27 | Source: email from Jonathon Love (jamovi project lead) | Outcome: **not accepted yet — explicitly not a rejection**

## Decision summary

askLLM will not enter the jamovi library for now, "not because of anything wrong with the module." The privacy design (summary statistics only, never raw rows; keys never written into the saved file; local Ollama option) plus the debouncing and error handling were each explicitly praised.

## The core team's three concerns (our reading)

1. **Value ceiling (benefit)**: the jamovi platform does not expose analysis output to modules, so an LLM module can only ever see variable summaries — a user could paste those numbers into a chat window themselves. The benefit does not yet justify the new risk, and **they want to fix the platform limitation first** ("the thing we'd want to fix first").
2. **Trust boundary (security)**: "user data → arbitrary external endpoint + user-supplied API key" is a module category the library has never carried; inclusion would mean jamovi endorsing that data flow. The custom provider's arbitrary endpoint is the hardest part for any review.
3. **Precedent (governance)**: the first LLM module admitted becomes the de facto standard. They want a security-review policy in place first — "rather build this properly than let the first version in and figure out the policy afterward."

## Roadmap signals

- jamovi intends to give modules "something more meaningful to work with than variable summaries" (i.e., analysis output)
- A security-review process for LLM / external-endpoint modules will be defined
- They will not ask developers to build against either until ready ("work we need to do ourselves")
- Explicit commitment to follow up ("I'll reach out once we've made progress") and keep talking

## Implications for this project

- **Sideload distribution is unaffected**: GitHub Releases and teaching use continue as-is
- **The upgrade path is set**: once the analysis-output API lands, askLLM's killer feature is "interpret the analysis you just ran" — exactly clearing the value bar Jonathon described
- **We hold material they will need**: the hallucination test notes in docs/LIMITATIONS and our provider-design trade-offs (curated vs arbitrary endpoints) are the kind of evidence a review policy needs
- The existing privacy design already matches the direction of the future policy; no rework required

## Follow-ups

- [ ] Reply: thanks; share the LIMITATIONS findings; offer to serve as a security-review test case; offer to join design discussions for the module-facing analysis-output API
- [ ] Track jamovi progress on exposing analysis output to modules (check release notes on each jamovi upgrade)
- [ ] Keep README installation section sideload-first; the "once published" wording stays (still the plan)
