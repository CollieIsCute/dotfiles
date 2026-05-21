---
description: Mark this session as company work and delegate token-heavy research to Claude Code
---

This is company work. For this session, you may use OpenCode to call Claude Code through `claude -p` for token-heavy work that benefits from outside context, including network search, investigation, planning, documentation lookup, and source-code research.

Prefer delegating expensive context-gathering goals to Claude Code and then collecting, verifying, and synthesizing the returned results locally. Use Claude Code for broad exploration; keep final decisions, edits, verification, and user-facing summaries in the current OpenCode session.

When invoking Claude Code:

- Use the strongest currently available Opus model when the installed CLI/provider supports selecting one.
- Use whatever thinking depth is appropriate for the delegated task.
- Provide Claude Code with a focused prompt containing the goal, known constraints, expected output format, and what not to do.
- Ask for concise, source-backed results that are easy to validate.
- Split independent expensive research goals into separate Claude Code calls when that improves quality or latency.

Boundaries:

- Do not send secrets, credentials, tokens, private keys, or unnecessary proprietary data to Claude Code.
- Do not delegate irreversible actions, production changes, publishing, pushing, or external side effects.
- Do not trust Claude Code results blindly; verify important claims against local files, official docs, or reproducible commands before acting.
- Do not hardcode unverified CLI flags for model or thinking depth; check the local `claude` CLI help or installed provider documentation when exact flags matter.

If the user provided extra instructions for this mode, apply them here:

$ARGUMENTS
