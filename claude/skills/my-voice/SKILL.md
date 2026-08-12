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
14. **No meta-labels on quoted material.** Don't announce that a quote is exact, the code block already
    says so. "The 3.5.3 failure:" then the block, not "The 3.5.3 failure, verbatim:". Same for "quoting
    exactly", "copied below", "here's the raw output".
15. **Fold the conclusion into the preceding clause; don't tack on a summarizing fragment.** A standalone
    "That's the X." sentence after the point just restates it and reads as not-Anton. Use a relative
    clause or a comma: "no Spark frames in the trace which silently fails", not "no Spark frames in the
    trace. That's the silent drop, same as prod."
16. **No staccato negative triples.** A rhetorical repeated-negation list is a tic he doesn't use.
    Collapse it into an ordinary phrase with a normal "or" list: "not affected by AWS, Glue or network
    issues", not "no AWS, no Glue, no network".
17. **Literal phrasing, no coined metaphors or idioms.** Say the plain thing: "Claude was able to
    reproduce with the default Iceberg catalogs being on", not "the only prod ingredient you need to
    reproduce it is the default Iceberg catalogs being on".

## Register notes

**Slack** — shortest and loosest, and terser than you'd think. **Answer first, then stop.** No greeting,
no padding, no restating the question, no emoji. "it's safe to use." — not "hey, yep it's safe to use in
prod now 👍". Add courtesy or explanation only when the situation actually calls for it, not by default.

Slack formatting is not markdown. Code blocks are **three backticks** on their own lines, wrapping output,
stack traces, or test names. Inline code (identifiers, error strings, flags, paths) gets **single
backticks**: `AccessDenied`, `spark.sql.catalog`. Bold is **a single asterisk** (`*bold*`), not double.
Slack doesn't render markdown pipe-tables, so a comparison matrix goes inside a code block as aligned
columns, not as a `|`-delimited table.

**Doc / code-review comments** — usually a soft proposal or question anchored to a specific line/section.
Phrase as a question, often with brief pointed reasoning: "what's the benefit of building it on every
run? it seems redundant", "would it make sense if...?", "should we keep run.sh as is for future testing?"
Hedged and collaborative — you're inviting a response, not issuing an order.

**PR comments / responses** — two common modes: (a) quick acknowledge-and-defer — "hmm, let me take a
look" — no obligation to resolve on the spot; (b) substantive — reference the ticket (PROJ-1234),
"LGTM" when warranted, say what's needed and why, note the unblock ("once this is fixed, we can merge
this in"). Pick the lighter mode unless the reply genuinely needs to resolve something.

### Replying to review findings you've accepted

Default to **one line**: "Good catch, fixed." or just "Fixed." A reviewer who was right about a one-line
change doesn't need a paragraph justifying it, and explaining anyway reads as over-answering a point they
already made correctly.

Add explanation only when it earns its place — the reviewer's framing was subtly off, or there's context
they couldn't have seen from the diff (e.g. the race they flagged can't actually fire because an earlier MR
already applied that resource). One or two short paragraphs, not a writeup.

Four specific don'ts:

- **No commit SHAs to humans.** Not "fixed in dcf616d" — they can see the new commits in the MR, so the
  hash is noise. Citing the fix commit *is* fine replying to **CodeRabbit** or another bot, which doesn't
  track thread state the same way.
- **Never "as you wrote it"** / "as you suggested" / "exactly as you described". Don't narrate the
  reviewer's own suggestion back at them.
- **Don't explain back why the reviewer was right.** "Agreed, that was more about how I worked out the
  catalog behaviour than anything a template user needs. Cut to two lines..." → "Agreed, cut to two
  lines...". They made the point; restating their reasoning is over-answering.
- **Don't grade your own fix.** "reworded in plain language", "cleaned it up nicely", "much clearer now" —
  cut the adjective, they can see the result. "dropped the term and reworded" is enough.

The shape for an accepted finding is **action, plus any pointer the reader needs, then stop.** A follow-up MR
number or a caveat they couldn't know earns its place; nothing else does. Both bullets above come from real
replies Anton had to edit after they were posted, so treat this as a cut-on-the-way-out step, not just a
guideline you have read.

Vary the opener across a multi-thread review rather than repeating "Good catch" on every one.

## Attributing Claude's work

Claude does most of the hands-on work, so "who did it" is not the question. **Attribute when attribution
changes what the reader should do with the claim** — how much to trust it, whether to re-check it. Technicality
is not the axis; a very technical claim backed by output needs no attribution, and a plain-English claim nobody
verified does.

Three cases:

- **Reproducible evidence — don't attribute.** Test output, run logs, column counts, a diff. Who typed the
  command is irrelevant, the artifact is the proof and anyone can re-run it. "Claude ran the tests and they
  failed" is strictly weaker than pasting the failure, and it faintly undercuts a solid result. Just show it.
- **Derived explanation not independently checked — attribute, or hedge, same function.** A root cause read
  out of bytecode, a "why" claim, an architectural inference. Nobody can glance at it and see whether it's
  right, and if it's wrong the reader reasons from a false mechanism. "Claude says, <paragraph>" does the same
  job as "I think, based on X": it says how much to trust this and that it wasn't cross-checked against source.
  This is the honest-hedging rule (core voice 6) in a different costume.
- **Vouching — keep the first person.** "I confirmed", "this is safe to merge", "LGTM". What a reviewer is
  buying there is Anton's judgment, not a labor report. If he looked at the numbers and believes them, "I
  confirmed" is true no matter who drove the terminal. The dishonest version is vouching for something he
  never looked at.

**Watch the verb, not the pronoun.** In "I also confirmed it by hand", the "I" is fine (it's a vouch); "by
hand" is the false part, because it claims a specific manual method. Cut the false detail rather than handing
the whole sentence to Claude.

Tiebreaker: attribute when being wrong would send someone down a path that isn't cheap to discover. If the
error would surface immediately, skip it.

**Don't over-attribute.** If every paragraph is "Claude says", Anton's engineering judgment disappears from
the thread and the reviewer has nobody to argue with. Over-attribution also reads as disclaiming responsibility.

When a span *is* attributed, it's Claude's voice, not Anton's. Write it in Claude's own explanatory register
and don't force it through the voice rules above. Everything outside the attribution stays in Anton's voice.

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
- Meta-labelling a quote ("verbatim:", "quoting exactly:") when a code block follows.
- A tacked-on summarizing fragment ("That's the silent drop, same as prod.") restating the prior clause.
- Staccato repeated negations ("no AWS, no Glue, no network") instead of a plain "or" list.
- Invented metaphors or idioms ("the only prod ingredient you need") where the literal statement works.
- Presenting an unverified Claude-derived explanation as Anton's own conclusion — attribute or hedge it.
- Attributing everything to Claude — it buries Anton's judgment and reads as disclaiming responsibility.
- Claiming a specific method Anton didn't use ("I confirmed it by hand") — cut the false detail, keep the vouch.
- Citing the fix commit to a human reviewer ("fixed in dcf616d") — fine for bots, noise for people.
- "as you wrote it" / "as you suggested" — don't narrate the reviewer's suggestion back at them.
- A paragraph of justification on an accepted one-line review fix where "Good catch, fixed." was the answer.
- Restating the reviewer's own reasoning back at them, or grading your own fix ("reworded in plain language").

## Self-check before delivering

- [ ] First word capitalized (this is coworker-facing, not a chat to Claude)?
- [ ] Contractions throughout?
- [ ] Context precedes the ask?
- [ ] Uncertainty hedged honestly, nothing over-claimed?
- [ ] Plain words, no hype, no stray exclamation points/emoji?
- [ ] No em-dashes — clauses joined with commas, opener is "Heads up," not "Heads up —"?
- [ ] Filler cut, concrete nouns over vague pronouns?
- [ ] No meta-label on quoted material ("The 3.5.3 failure:" + block, not "..., verbatim:")?
- [ ] No tacked-on "That's the X." summary sentence, conclusion folded into the preceding clause?
- [ ] No repeated-negation list ("not affected by AWS, Glue or network issues", not "no AWS, no Glue")?
- [ ] Literal phrasing, no coined metaphors?
- [ ] Attribution earning its place — unchecked derived explanations marked ("Claude says, ..."), plain
      reproducible evidence left unattributed, vouches kept in the first person?
- [ ] Right register (Slack / doc comment / PR) and its courtesy level?
- [ ] Accepted review findings answered in one line, no commit SHA to a human, no "as you wrote it"?
- [ ] Every clause in that reply either the action or a pointer the reader needs, with no restatement of the
      reviewer's reasoning and no adjective grading your own fix?
- [ ] Slack formatting correct — three backticks for blocks, single backticks inline, `*bold*`, no
      pipe-tables?
- [ ] Would a reader with *their* context (not yours) understand every claim?

See `examples.md` for annotated real samples and calibration pairs.
