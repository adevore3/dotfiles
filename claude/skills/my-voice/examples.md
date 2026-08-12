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

**PR response opener — draft led with "First thing worth stating up front is ...":**
> First thing is ...   (or "First thing is that ...")

Correction: "worth stating up front" is stiff filler he wouldn't use. When he leads with "first" it's the
plain "first thing is" / "first thing is that". And enumeration is consistent: if he opens a point with
"first", he continues "second", "third" — not "first ..." then unlabeled follow-ons.

### From a Slack draft about a Spark 3.5.3 / Iceberg repro (five corrections in one pass)

**Meta-label on a quote — draft introduced a code block with "verbatim":**
> Before: The 3.5.3 failure, verbatim: <code block>
> After:  The 3.5.3 failure: <code block>

Demonstrates: don't announce that a quote is exact. The code block already conveys it, so the label is dead
words. Applies to "quoting exactly", "copied below", "here's the raw output" too.

**Slack formatting — draft used markdown conventions:**
> Code blocks are three backticks, inline code is single backticks (`AccessDenied`), bold is `*bold*`.
> A comparison matrix goes inside a code block as aligned columns, since Slack won't render a pipe-table.

Demonstrates: the Slack register's formatting rules, called out by Anton directly ("for slack is 3
backticks").

**Tacked-on summarizing fragment:**
> Before: ...no Spark frames in the trace. That's the silent drop, same as prod.
> After:  ...no Spark frames in the trace which silently fails.

Demonstrates: fold the conclusion into the preceding clause with a relative clause or comma. The standalone
"That's the X." sentence restates what was just said and reads as not-Anton.

**Staccato negative triple:**
> Before: no AWS, no Glue, no network
> After:  not affected by AWS, Glue or network issues

Demonstrates: the rhetorical repeated-negation list is a tic he doesn't use. Collapse it into an ordinary
phrase with a normal "or" list.

**Coined metaphor, plus attributing the work to Claude:**
> Before: The only prod ingredient you need to reproduce it is the default Iceberg catalogs being on.
> After:  Claude was able to reproduce with the default Iceberg catalogs being on.

Demonstrates two things: (a) "prod ingredient" is an invented figure of speech, say it literally; (b) here
the claim is an unverified repro assertion with no artifact attached, so naming Claude as the actor is doing
real work. Contrast the next two pairs.

**Attributing Claude's analysis — a root-cause paragraph that came from Claude reading bytecode:**
> Claude says, <root-cause paragraph, in Claude's own explanatory voice>

Demonstrates: a derived explanation nobody independently checked. The reader can't eyeball whether it's right,
and if it's wrong he reasons from a false mechanism, so the provenance marker earns its place. The attributed
paragraph stays in Claude's register and isn't forced through Anton's voice rules; everything outside the
attribution stays in his voice.

**Reproducible evidence — do NOT attribute:**
> Before: Claude ran the tests and they failed on 3.5.3.
> After:  <paste the test-failure code block>

Demonstrates: the artifact is the proof and anyone can re-run it, so who typed the command is irrelevant.
Attribution here is strictly weaker than the output itself and faintly undercuts a solid result.

**Vouching — keep the first person, cut the false method:**
> Before: For DIRP-4667 I also confirmed it by hand on top of the unit tests, ...
> After:  For DIRP-4667 I also confirmed it on top of the unit tests, ...

Demonstrates: "I confirmed" is a vouch and stays true regardless of who drove the terminal, since Anton read
the numbers and believes them. "by hand" is the false part, it claims a specific manual method. Watch the
verb, not the pronoun, and don't hand the whole sentence to Claude to fix two words.

### From two MR thread replies to a reviewer (both padded the same way)

Anton edited both notes in GitLab after they were posted. The rule they violate is already in the SKILL
(accepted findings get one line), which is the point: knowing the rule isn't enough, the padding has to be
cut on the way out.

**Self-praise about your own fix:**
> Before: ...so I dropped the term and reworded in plain language.
> After:  ...so I dropped the term and reworded.

Demonstrates: "in plain language" characterizes the quality of the change. The reviewer can see what it reads
like now, so grading your own edit is dead weight.

**Explaining back why the reviewer was right:**
> Before: Agreed, that was more about how I worked out the catalog behaviour than anything a template user
>         needs. Cut to two lines saying use the helper rather than your own `DROP TABLE`, with the ticket
>         left in for the detail. Also in !106.
> After:  Agreed, cut to two lines saying use the helper rather than your own `DROP TABLE`, with the ticket
>         left in for the detail. Also in !106.

Demonstrates: the reviewer's comment was "most of the context here isnt meaningful to users of the template",
so the cut clause restates his own point back at him. What survives is the action plus the pointer to the
follow-up MR, which is the whole reply.

The general shape for an accepted finding: **action, plus any pointer the reader needs, and stop.** A
follow-up MR number or a caveat they couldn't know earns its place; a justification of their point does not.
