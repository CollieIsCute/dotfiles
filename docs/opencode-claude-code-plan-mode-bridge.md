# OpenCode Claude Code Plan Mode Bridge Fix Plan

## Problem Statement

`@khalilgharbaoui/opencode-claude-code-plugin@0.5.1` currently renders Claude Code's `ExitPlanMode` tool use as plain assistant text:

```markdown
**Do you want to proceed with this plan?** (yes/no)
```

In OpenCode, replying `yes` becomes ordinary user text. Native Claude Code expects an `ExitPlanMode` `tool_result` plus a plan-mode state transition, so the session can remain stuck in plan mode or repeatedly ask for approval.

## Investigation Summary

Evidence from the current machine:

- `home/dot_config/opencode/opencode.json.tmpl` only loads `@khalilgharbaoui/opencode-claude-code-plugin@0.5.1`; it does not set `permissionMode: "plan"`.
- The installed plugin implementation renders `ExitPlanMode` to plain text in `dist/index.js` at the three handling paths for non-stream and stream events.
- The plugin explicitly excludes `ExitPlanMode` from normal tool-call forwarding, so OpenCode never receives a real tool call that it can approve or reject.
- Native Claude Code transcripts show plan approval as a `tool_result` with content like `User has approved your plan. You can now start coding...`, followed by a `plan_mode_exit` attachment.
- Claude project memory for some C++ workspaces tells Claude to use `EnterPlanMode` / `ExitPlanMode`, which makes this failure more likely in those projects.

## Goals

- Prevent OpenCode sessions using the Claude Code provider from getting stuck at `Do you want to proceed with this plan? (yes/no)`.
- Preserve the user's review-before-edit workflow for C++ projects.
- Keep tests low-cost and prefer static/unit coverage before any live Claude Code provider test.
- Prefer OpenAI subscription-backed OpenCode models for investigation, orchestration, and non-Claude validation.

## Non-Goals

- Do not change unrelated OpenCode plugins.
- Do not enable `dangerously-skip-permissions` or bypass company policy.
- Do not make Claude Code auto-approve plans silently unless the user explicitly chooses that behavior.
- Do not rely on a long live-Claude test loop as the primary verification method.

## Implementation Status

Current path: B. Local plugin patch.

Completed:

- `home/dot_config/opencode/opencode.json.tmpl` points OpenCode at the patched local build: `file://{{ .chezmoi.homeDir }}/syncfolder/opencode-claude-code-plugin/dist/index.js`.
- `ExitPlanMode` now renders the plan text plus a native OpenCode `question` tool-call instead of a plain markdown yes/no prompt.
- The `question` result is converted back into a Claude `tool_result` for the original `ExitPlanMode` tool-use id.
- Approval uses Claude Code's native approval text.
- Rejection, custom text, and execution-denied answers use Claude Code's rejection-style `is_error` tool result.
- Pending question state is scoped by the same session key used for the Claude subprocess and cleared on new sessions or after the matching answer is consumed.
- `AskUserQuestion` remains out of scope for this patch.

Superseded by the native `question` bridge:

- The Phase 1 markdown-only instruction workaround is not needed while the patched plugin is loaded.
- Natural-language parsing of `y`, `approve`, or ambiguous phrases is intentionally not implemented. The native OpenCode question answer is the machine-readable approval signal.

Verification performed:

- `npm test`: 181 tests passed.
- `npm run typecheck`: passed.
- `npm run build`: passed.
- Built plugin smoke test: `dist/index.js` imports and `default.server` registers the `claude-code` provider.
- `chezmoi apply /home/collie/.config/opencode/opencode.json`: applied.
- `chezmoi diff`: clean.
- OpenCode was restarted by the user after the config apply.

Rollback:

- Revert `home/dot_config/opencode/opencode.json.tmpl` to `@khalilgharbaoui/opencode-claude-code-plugin@0.5.1`.
- Run `chezmoi apply /home/collie/.config/opencode/opencode.json`.
- Restart OpenCode.

## Decision Point

Choose one execution path before implementing.

| Path | Scope | When to choose |
|---|---|---|
| A. Dotfiles workaround | Add instructions that forbid native Claude Code plan tools under OpenCode | Fastest, lowest risk, no fork maintenance |
| B. Local plugin patch | Fork or vendor the plugin and bridge `ExitPlanMode` correctly | Best UX, but requires maintaining plugin code |
| C. Hybrid | Add workaround now, patch plugin later | Recommended if this blocks daily work now |

Recommended path: C. Land the dotfiles workaround first, then patch the plugin when there is time to test it carefully.

## Phase 1: Dotfiles Workaround

### Task 1.1: Add OpenCode Instruction Guard

Description: Add a global OpenCode instruction telling agents that when using Claude Code through OpenCode, they must not call native Claude Code `EnterPlanMode` or `ExitPlanMode`. They should present plans as normal markdown and wait for an explicit next user message.

Acceptance criteria:

- [ ] Instruction is tracked by chezmoi.
- [ ] Instruction clearly names `EnterPlanMode` and `ExitPlanMode`.
- [ ] Instruction preserves the review-before-edit workflow.
- [ ] Instruction does not affect native Claude Code outside OpenCode.

Likely files:

- `home/dot_config/opencode/instructions/zh-tw.md`
- Or a new instruction file under `home/dot_config/opencode/instructions/` plus an `opencode.json.tmpl` entry.

Verification:

- [ ] Run `chezmoi diff` and confirm only intended OpenCode instruction changes appear.
- [ ] Restart OpenCode, because config and instruction files are loaded at startup.
- [ ] In a new OpenCode session with an OpenAI model, ask for a C++ implementation plan and verify it uses markdown, not Claude Code plan tools.

### Task 1.2: Adjust Claude Project Memory If Needed

Description: For C++ project memories that say `Use EnterPlanMode ... Only edit files after ExitPlanMode approval`, add a qualifier: use native plan mode only in native Claude Code; inside OpenCode, use plain markdown plans.

Acceptance criteria:

- [ ] The memory still requires plan review before edits.
- [ ] The memory no longer forces OpenCode Claude provider sessions into native Claude Code plan mode.

Likely files outside this repo:

- `~/.claude/projects/-home-collie-syncfolder-threatsonar-plus/memory/feedback_plan_before_edit.md`

Verification:

- [ ] Start a fresh C++ project session and confirm the model does not call `EnterPlanMode` when operating through OpenCode.

## Phase 2: Plugin Patch Design

### Task 2.1: Create a Local Fork or Vendor Copy

Description: Make the plugin patchable without editing OpenCode's npm cache directly.

Acceptance criteria:

- [ ] The source lives in a stable tracked location or in a dedicated fork repository.
- [ ] `opencode.json.tmpl` can reference it via `file://` or a pinned npm package.
- [ ] The original upstream package version remains documented for rollback.

Likely options:

- Fork upstream and publish a scoped package.
- Vendor a local plugin under this repo only if the maintenance cost is acceptable.
- Use a checked-out external path and reference it via `file://` for testing only.

Verification:

- [ ] OpenCode starts with the local plugin reference.
- [ ] Existing Claude Code provider models still appear.
- [ ] No unrelated provider or MCP behavior changes.

### Task 2.2: Preserve Pending `ExitPlanMode` State

Description: When Claude emits `ExitPlanMode`, store the pending tool-use id, plan text, session key, and timestamp instead of treating it as stateless text.

Acceptance criteria:

- [ ] Pending plan state is keyed by the same session affinity used for the Claude subprocess.
- [ ] Pending state is cleared on approval, rejection, abort, session eviction, or timeout.
- [ ] Multiple sessions do not cross-contaminate pending approvals.

Likely files in plugin source:

- `src/claude-code-language-model.ts`
- Any session manager module if pending state should live outside the language model class.

Verification:

- [ ] Unit test: two sessions can each hold a different pending plan.
- [ ] Unit test: approving one session does not approve another.

### Task 2.3: Convert Plan Approval Into a Claude Tool Result

Description: On the next user turn, if there is a pending `ExitPlanMode` and the user answers yes/no, send Claude CLI a `tool_result` for the original `ExitPlanMode` tool-use id instead of ordinary text.

Approval content should mirror native Claude Code as closely as possible:

```text
User has approved your plan. You can now start coding. Start with updating your todo list if applicable.
```

Rejection content should mirror native rejection behavior:

```text
The user doesn't want to proceed with this tool use. The tool use was rejected. To tell you how to proceed, the user said:
<user feedback>
```

Acceptance criteria:

- [ ] `yes`, `y`, `approve`, and explicit approval phrases become approval `tool_result`.
- [ ] `no`, `n`, `reject`, and feedback text become rejection `tool_result`.
- [ ] Ambiguous answers are treated as normal text or ask for clarification; they are not auto-approved.
- [ ] The original `ExitPlanMode` tool-use id is preserved.

Verification:

- [ ] Unit test: `yes` produces a Claude stream-json user message containing `tool_result` with the pending tool id.
- [ ] Unit test: rejection feedback produces an error-style rejection message.
- [ ] Unit test: unrelated user text while no pending plan remains normal user text.

### Task 2.4: Render a Real OpenCode Question If Feasible

Description: Prefer using OpenCode's native question/permission UX instead of plain markdown text if the provider stream format supports it cleanly. If not, keep markdown but make the next-turn bridge robust.

Acceptance criteria:

- [ ] The user sees a clear approve/reject prompt.
- [ ] The answer is machine-readable enough to drive the approval bridge.
- [ ] The prompt does not look like a normal assistant question that can be lost in a long response.

Verification:

- [ ] Manual OpenCode session shows the prompt clearly.
- [ ] Approval and rejection both resume the same Claude subprocess.

### Task 2.5: Avoid Auto-Continue Loops Around Plan Approval

Description: Ensure the plugin's smart auto-continuation does not send `Continue the task...` after rendering an `ExitPlanMode` prompt.

Acceptance criteria:

- [ ] A pending plan approval stops auto-continuation.
- [ ] The stream closes cleanly and waits for the user's next message.
- [ ] No repeated `Do you want to proceed...` prompt appears unless Claude emits a new plan.

Verification:

- [ ] Unit test: `shouldAutoContinueIncompleteTurn` returns stop reason for pending plan prompt.
- [ ] Manual test: one plan approval prompt appears, then the session waits.

## Phase 3: Low-Cost Verification Strategy

### Task 3.1: Static and Unit Tests First

Description: Validate message transformation without calling Claude.

Acceptance criteria:

- [ ] Tests cover approval, rejection, ambiguity, session isolation, and timeout cleanup.
- [ ] Tests run locally without network.

Suggested commands in the plugin fork:

```bash
bun test
bun run build
```

### Task 3.2: OpenCode Startup Smoke Test

Description: Verify OpenCode can load the patched plugin.

Acceptance criteria:

- [ ] OpenCode starts without config validation errors.
- [ ] Claude Code provider still registers models.
- [ ] Existing MCP bridge and proxy tools still load.

Suggested check:

```bash
opencode
```

Manual verification is acceptable here because this is primarily config/plugin loading.

### Task 3.3: Minimal Live Claude Provider Test

Description: Run only one live Claude Code provider scenario after static tests pass.

Prompt constraints:

- Use a small C++-related prompt.
- Do not ask it to edit files.
- Do not run builds.
- Do not use secrets or network.
- Keep output short.

Example prompt:

```text
In this C++ context, propose a 3-step read-only plan to inspect why a function named GetNetworkMountPoint might skip GPFS. Do not edit files. If you need approval, ask once.
```

Acceptance criteria:

- [ ] Claude emits a plan approval prompt once.
- [ ] Replying `yes` resumes the same Claude session.
- [ ] Claude proceeds after approval instead of asking the same yes/no again.
- [ ] Replying `no, revise X` causes plan revision, not execution.

Cost control:

- [ ] Use the cheapest Claude Code model that can trigger plan mode.
- [ ] Use OpenAI subscription models for all non-Claude comparison sessions.
- [ ] Stop after one approval and one rejection path unless a failure needs reproduction.

## Phase 4: Rollout and Rollback

### Task 4.1: Land Dotfiles Changes

Acceptance criteria:

- [ ] `chezmoi diff` is clean except expected files.
- [ ] `chezmoi apply` succeeds.
- [ ] OpenCode is restarted.

### Task 4.2: Roll Out Patched Plugin

Acceptance criteria:

- [ ] `opencode.json.tmpl` points to the patched plugin source or pinned package.
- [ ] README documents why the fork exists.
- [ ] The upstream version and rollback command are documented.

Rollback:

- Revert `opencode.json.tmpl` to `@khalilgharbaoui/opencode-claude-code-plugin@0.5.1`.
- Restart OpenCode.
- Keep the Phase 1 instruction guard if it still helps avoid the bug.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Incorrect `tool_result` shape | Claude remains stuck or errors | Compare against native Claude transcript and unit-test serialization |
| Session cross-talk | Wrong plan gets approved | Key pending state by Claude session key and OpenCode session affinity |
| Silent auto-approval | Unsafe edits | Require explicit yes-like answer; treat ambiguity as non-approval |
| Plugin fork drifts from upstream | Maintenance cost | Keep patch minimal and document upstream base version |
| OpenCode schema/config breakage | OpenCode fails to start | Validate config and keep rollback path simple |

## Done Criteria

- [x] OpenCode no longer sends plan approval as ordinary user text; it bridges native `question` replies back to Claude `tool_result` messages.
- [x] C++ review-before-edit workflow is preserved by asking for explicit approval through OpenCode's native question UI.
- [x] Approval and rejection paths are covered by unit tests.
- [x] The patched plugin and local OpenCode plugin path are documented in this repo.
- [x] Rollback path is documented.
