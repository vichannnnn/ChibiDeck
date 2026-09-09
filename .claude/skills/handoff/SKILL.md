---
name: handoff
description: Use when the user says "handoff", "hand off", "something I can bring to the next session", "continue this in a new session", "pick this up later", or says context is running out while work is unfinished.
---

# Handoff

## Overview

A handoff is a prompt for the next session, delivered as text the user copies out of this chat. The next assistant starts with zero memory of this session. The block is the only thing it gets. Anything not in the block is lost.

Core principle: **the pasteable block is the deliverable. A file is at most a copy of it.**

## What to produce

Your reply has three parts, in this order:

1. One line before the block, at most. Example: `Handoff below. Paste it as the first message of the new session.`
2. ONE fenced code block containing the full handoff prompt (template below).
3. At most one line after the block, only if you also wrote a file: `Also saved to <path>.`

That is the whole reply.

## The block

Written to the next assistant, not to the user. The user is "the user" in the block, never "you". Fill every slot. A slot with nothing to say gets `none` so the reader knows it was checked.

```
You are continuing work from a previous session. Project root: <absolute path>.
Branch: <branch>. Read this whole message before touching anything.

GOAL
<What we are building or fixing, 1 to 3 lines.>

REFERENCE DOCS (read these first, in this order)
- <path> : <what it is, e.g. the plan being executed and which tasks it covers>
- <path> : <spec, design, prior handoff, etc.>

STATE
Done and committed:
- <item> : <file paths> : <how verified, e.g. "npm test green">
In progress (uncommitted):
- <item> : <file:line> : <what exists, what is missing>
Not started:
- <item>

DECISIONS (made by the user; do not relitigate)
- <decision> : <reason>
Rejected:
- <alternative> : <why rejected>

FACTS THE NEXT SESSION WOULD OTHERWISE HAVE TO REDISCOVER
- <exact error text, flaky test name and failure rate, undocumented flag, exact command that worked>
  Mark each VERIFIED or UNVERIFIED.

OPEN QUESTIONS / HYPOTHESES (unverified)
- <hypothesis> : <evidence for it> : <how to test it>

CONSTRAINTS
- <things the user said to skip, avoid, or leave for others>

GIT
- Last commit: <message or hash>
- Uncommitted: <file list>

FIRST ACTION
<One command or edit to do first, copy-pasteable.>

THEN, IN ORDER
1. <step>
2. <step>
3. <step>
```

## Filling it in

- **Detail beats brevity.** Every fact from this session that the next session would otherwise have to rediscover goes in: exact error strings, exact commands, file:line, numbers ("fails ~1 in 5"), who decided what. Length is not a limit inside the block. Omission is the failure.
- **Facts vs guesses.** A hypothesis goes under OPEN QUESTIONS, marked unverified. A guess never appears as a fact.
- **Doc pointers carry content.** List the plan or spec path, and still put the state and decisions it implies inline. The next session must be able to work from the block alone if the file is missing.
- **Check the repo before writing.** Run `git status` and `git log -3 --oneline`, and reread any referenced doc, so GIT and STATE reflect reality, not memory. If you cannot verify, say so inside the block.
- **Files are optional.** Write a handoff file only if the user asks for one. If you do, it holds the same block, and the block still appears in full in the chat.

## Common mistakes

| Mistake | Fix |
|---|---|
| Writing `HANDOFF.md` and replying with its path | The block goes in the chat. The file is a copy. |
| A recap addressed to the user ("you decided...") | Address the next assistant ("the user decided..."). |
| "Suggested next steps" with no first action | FIRST ACTION is one runnable command or edit. |
| Presenting the current hypothesis as fact | It goes under OPEN QUESTIONS, marked unverified. |
| Omitting git state | Committed vs uncommitted, always. |
