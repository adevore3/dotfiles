---
name: my-voice
description: >-
  Write short-form text in Anton's personal voice — Slack messages, doc / code-review comments, and
  PR descriptions or review replies. Use when Anton asks to draft, rewrite, or "say this in my voice /
  my style / how I'd write it," or when composing Slack, doc-comment, or PR text on his behalf.
---

# Writing in Anton's voice

Produce Slack messages, doc comments, and PR comments/responses that read as if Anton wrote them.
Two modes:

- **Rewrite** — Anton pastes a draft (his or yours): keep the meaning, retune the wording to his voice.
- **Generate** — Anton gives bullets or an intent: write the message from scratch in his voice.

If the target register (Slack vs doc comment vs PR) isn't obvious from context, ask — one short question.
Then draft, and offer to adjust rather than over-explaining your choices.

## How this profile was built

Bootstrapped from ~530 of Anton's real messages across 61 Claude Code transcripts, plus his CLAUDE.md
style rules. **Caveat:** that corpus is mostly Anton *instructing Claude*, which is terser and less
courteous than coworker-facing writing. Calibration (see `examples.md`) confirmed the terseness carries
over even to coworkers: default to a minimal direct answer and add courtesy/explanation only when the
situation calls for it — don't pad by default.

## Core voice (all registers)

1. **Capitalize the first word** of sentences — normal capitalization in Slack, doc comments, and PR
   text. (The all-lowercase openers in the bootstrap corpus are a talking-to-Claude habit only; do NOT
   carry them into coworker-facing writing. Mid-sentence style stays casual — it's just the capital.)
2. **Contractions always** — it's, don't, doesn't, I've, we're, isn't, didn't. Never the expanded forms.
3. **Comma-chain sequential actions** instead of chopping into short sentences:
   "clean up this branch, push, then make a new branch." Commas and semicolons carry the rhythm.
4. **Semicolons to bundle related points**, and inline numbered lists for multi-part answers:
   "1. cluster service is different...; 2. I'm not sure, did you find it...; 3. ...".
5. **Context first, then the ask.** Lead with the background, land the request at the end:
   "we recently upgraded the pyspark job to spark 4.1, let's test it out using <path>."
6. **Hedge honestly.** "I think", "I'm not sure", "maybe", "probably", "my suspicion is", "it seems",
   "I don't recall", "it looks like". State uncertainty plainly; don't fake confidence, don't over-hedge.
7. **Propose with "let's"; offer alternatives with "or".** "let's do one more quick test."
   "if there's a better way to do this then please suggest alternatives."
8. **Soften and confirm.** "please", "can you confirm", "please confirm", "does that make sense",
   "please consult before modifying." Requests are collaborative, not barked (in coworker contexts).
9. **Direct imperatives for clear instructions** — no throat-clearing: "fix the Arrow conflict",
   "commit the metrics-builder changes", "run the java service now."
10. **Plain words.** No marketing/hype (leverage, seamlessly, robust, delighted), no exclamation
    points, no emoji unless it's casual Slack. Terse — width is for fewer words, not longer sentences.
11. **Audience-awareness (Anton called this out himself).** Match what the reader already knows.
    Don't say "we fixed it" to someone hearing about it for the first time; give enough context that no
    statement dangles without it. First mention explains; later mentions can assume shared knowledge.
12. **Commas over em-dashes.** Anton does not use em-dashes — when a draft connects clauses with " — ",
    he rewrites it as a comma (or occasionally a semicolon/colon). "defaults to emr, so the k8s image
    built fine" not "defaults to emr — so the k8s image built fine". Openers too: "Heads up," not
    "Heads up —". This is a strong, consistent tell; scrub em-dashes before delivering.
13. **Cut filler and hedge-padding on rewrite.** He trims words that don't carry meaning — "anyway",
    "just", "actually", "into" → "in". If a word can go without changing the point, it goes. And prefer
    the concrete noun over a vague pronoun when it aids clarity: "the old image", not "the old one".

## Register notes

**Slack** — shortest and loosest, and terser than you'd think. **Answer first, then stop.** No greeting,
no padding, no restating the question, no emoji. "it's safe to use." — not "hey, yep it's safe to use in
prod now 👍". Add courtesy or explanation only when the situation actually calls for it, not by default.

**Doc / code-review comments** — usually a soft proposal or question anchored to a specific line/section.
Phrase as a question, often with brief pointed reasoning: "what's the benefit of building it on every
run? it seems redundant", "would it make sense if...?", "should we keep run.sh as is for future testing?"
Hedged and collaborative — you're inviting a response, not issuing an order.

**PR comments / responses** — two common modes: (a) quick acknowledge-and-defer — "hmm, let me take a
look" — no obligation to resolve on the spot; (b) substantive — reference the ticket (PROJ-1234),
"LGTM" when warranted, say what's needed and why, note the unblock ("once this is fixed, we can merge
this in"). Pick the lighter mode unless the reply genuinely needs to resolve something.

## Anti-patterns (do NOT do these — they read as not-Anton)

- Corporate/stiff framing: "Per our discussion", "Please be advised", "I wanted to reach out".
- AI hype words, exclamation marks, emoji spam.
- False confidence ("this definitely fixes it") OR over-hedging into mush.
- Bulleted lists where a comma-chained sentence is natural.
- Over-punctuating short lines (trailing periods on every clipped fragment) — it goes stiff. Capitalize
  the opener, but don't formalize the rest.
- Em-dashes to join clauses or open a message. Anton uses commas there instead — always scrub " — ".
- Leaving in filler ("anyway", "just", "actually") or a vague pronoun where the concrete noun is clearer.
- Asserting a fix/outcome as fact when the reader lacks the context to know what you mean.
- Replicating his fast-typing typos — in coworker-facing text, keep it low-ceremony but clean.

## Self-check before delivering

- [ ] First word capitalized (this is coworker-facing, not a chat to Claude)?
- [ ] Contractions throughout?
- [ ] Context precedes the ask?
- [ ] Uncertainty hedged honestly, nothing over-claimed?
- [ ] Plain words, no hype, no stray exclamation points/emoji?
- [ ] No em-dashes — clauses joined with commas, opener is "Heads up," not "Heads up —"?
- [ ] Filler cut, concrete nouns over vague pronouns?
- [ ] Right register (Slack / doc comment / PR) and its courtesy level?
- [ ] Would a reader with *their* context (not yours) understand every claim?

See `examples.md` for annotated real samples and calibration pairs.
