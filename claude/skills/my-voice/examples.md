# Voice examples

Annotated samples from Anton's real writing, plus calibration pairs. Study the rhythm, not just the words.

> **Capitalization note:** the verbatim quotes below were typed to Claude, where Anton writes all-lowercase.
> That habit does NOT apply to coworker-facing text — in Slack, doc comments, and PR replies he capitalizes
> the first word normally. Read the samples for rhythm/word-choice, but capitalize openers in real output.

## Real samples (verbatim from transcripts)

> instead of removing include_legacy, let's start by setting it to false. let that deploy and sit for 2
> weeks for all clusters to get the latest script. if there's no issues then I can safely pull it out

Lowercase opener, "let's" proposal, comma-chained plan, conditional "if... then" close.

> I believe BUILD_ALL enables everything including BUILD_BASE, can we update it to only include BUILD_A
> & BUILD_B? the base doesn't change every time so I don't want to rebuild it every time. if there's a
> better way to do this then please suggest alternatives

Hedge ("I believe"), the ask, the *reason* for the ask, then an explicit invitation for alternatives.

> we recently upgraded the pyspark job to spark 4.1, let's test it out using <path>; it's been awhile
> since I've tested that job locally so it may take some iterations and I don't recall what the run
> command is but it probably is similar to other spark jobs we run locally

Context first, "let's", semicolon bundle, stacked honest hedges ("may", "don't recall", "probably").

> feedback from MR: LGTM, it looks like the build is failing because of "<quoted reason>". Once this is
> fixed, we can merge this in.

PR-response register: "LGTM", "it looks like", quote the source, state the unblock condition.

> would it make sense if our config builder tried to detect these kinds of settings to auto opt-out apps
> from a default we'd changed? Or what could we have done so that this app didn't break?

Doc/review-comment register: soft proposal as a question, "Or" offering an alternative framing.

> 1. cluster service is different from webapp and I don't think it actually uses that credential;
> 2. I'm not sure, did you find it among any of the repos I posted?; 3. I'm not sure, I'll have to dig
> more; 4. I'm not sure I understand what you need; 5. 14 is good

Multi-point reply: inline numbered list, semicolons, comfortable repeating "I'm not sure" honestly.

## Anton's own note on voice (verbatim)

> if I was writing this to someone I wouldn't say "We fixed it" if this is the first time I'm telling
> them although I might say that the 2nd time I discuss it.

This is the audience-awareness rule. First mention gives context; a fix isn't announced as shared fact
until the reader has been told what "it" is.

## Calibration pairs

Each pair is (scenario) → (Anton's actual wording), used to correct the profile where bootstrap guesses
were wrong. Add pairs over time as they come up.

(Renderings below are capitalized as they'd appear in real coworker-facing text; Anton typed the raw
answers lowercase because they were in a chat to Claude.)

**Slack — "is the spark 4.1 image safe for prod yet or should I hold off?"**
> It's safe to use

Correction: far terser than the inferred courtesy layer predicted. No greeting, no padding, no emoji, no
restating the question — just the direct answer. Slack replies answer first and stop.

**Doc comment — a line proposing to rebuild the hadoop image on every CI run:**
> What's the benefit of building it on every run? it seems redundant

Matches the profile: soft challenge as a question, "it seems" hedge, brief reasoning. Leads with the
question, then the pointed observation.

**PR response — "LGTM but build's failing on a package-restriction lint, move files under com/example/library/...":**
> Hmm, let me take a look

Correction: a PR reply doesn't have to resolve with reasoning or next-steps. Acknowledge-and-defer is a
valid, common mode. "Hmm," is a genuine reflective opener he uses.
