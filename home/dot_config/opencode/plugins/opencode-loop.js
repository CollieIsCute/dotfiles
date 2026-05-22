import { promises as fs } from "node:fs"
import path from "node:path"
import { spawn } from "node:child_process"

const SERVICE = "opencode-loop"
const STATE_DIR = ".opencode/opencode-loop"
const DEFAULT_ACTIVE_GUARD_MS = 60_000
const MAX_SCAN_FILES = 200
const MAX_SCAN_BYTES = 2_000_000

const activeRuns = new Map()
const handledCommands = new Map()

const DEFAULT_PROGRESS_MD = `# Progress

## Current Goal
Describe the current project goal here.

## Agent Rules
- Do not ask questions unless truly blocked.
- Make reasonable assumptions and continue.
- Work on unfinished TODOs in order.
- Mark completed TODOs with [x].
- Add new bugs, ideas, and follow-up work as TODOs.
- Run tests, lint, or build when available.
- Do not run destructive commands, force pushes, production deploys, or database resets.

## Active TODO
- [ ] Review the project structure and pick the next safe improvement.

## Completed
- [x] Created progress.md.

## Backlog Ideas
- [ ] Add more project-specific tasks here.

## Blocked
- None.
`

function now() {
  return Date.now()
}

function safeID(value) {
  return String(value || "job")
    .replace(/[^a-zA-Z0-9_.-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80) || "job"
}

function parseDuration(value) {
  const input = String(value || "").trim()
  if (input === "0") return 0
  const match = input.match(/^(\d+)\s*(ms|s|sec|secs|second|seconds|m|min|mins|minute|minutes|h|hr|hrs|hour|hours|d|day|days)$/i)
  if (!match) return null
  const amount = Number.parseInt(match[1], 10)
  const unit = match[2].toLowerCase()
  if (!Number.isFinite(amount) || amount < 0) return null
  if (unit === "ms") return amount
  if (unit.startsWith("s")) return amount * 1000
  if (unit.startsWith("m")) return amount * 60_000
  if (unit.startsWith("h")) return amount * 3_600_000
  if (unit.startsWith("d")) return amount * 86_400_000
  return null
}

function durationToText(ms) {
  if (ms === 0) return "every idle"
  if (!Number.isFinite(ms)) return "unknown"
  if (ms % 86_400_000 === 0) return `${ms / 86_400_000}d`
  if (ms % 3_600_000 === 0) return `${ms / 3_600_000}h`
  if (ms % 60_000 === 0) return `${ms / 60_000}m`
  if (ms % 1000 === 0) return `${ms / 1000}s`
  return `${ms}ms`
}

function splitFirst(input) {
  const match = String(input || "").trim().match(/^(\S+)\s*([\s\S]*)$/)
  if (!match) return ["", ""]
  return [match[1], (match[2] || "").trim()]
}

function stripOuterQuotes(value) {
  const input = String(value || "").trim()
  if ((input.startsWith('"') && input.endsWith('"')) || (input.startsWith("'") && input.endsWith("'"))) {
    return input.slice(1, -1)
  }
  return input
}

function escapeRegExp(value) {
  return String(value).replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&")
}

function takeFlag(rest, flag) {
  const pattern = new RegExp(`(^|\\s)${escapeRegExp(flag)}(?=\\s|$)`, "i")
  const found = pattern.test(rest)
  return [found, rest.replace(pattern, " ").replace(/\s+/g, " ").trim()]
}

function takeFlagValue(rest, flag) {
  const pattern = new RegExp(`(^|\\s)${escapeRegExp(flag)}\\s+(?:\"([^\"]*)\"|'([^']*)'|(\\S+))`, "i")
  const match = rest.match(pattern)
  if (!match) return [undefined, rest]
  const value = match[2] ?? match[3] ?? match[4]
  return [value, rest.replace(pattern, " ").replace(/\s+/g, " ").trim()]
}

function takeAllFlagValues(rest, flag) {
  const values = []
  let current = rest
  while (true) {
    const [value, next] = takeFlagValue(current, flag)
    if (value === undefined) return [values, current]
    values.push(value)
    current = next
  }
}

function parsePositiveInt(value, fallback = 0) {
  const parsed = Number.parseInt(String(value || ""), 10)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback
}

function parseCompactEvery(value) {
  const duration = parseDuration(value)
  if (duration !== null) return { compactEveryMs: duration }
  const runs = parsePositiveInt(value, 0)
  return runs > 0 ? { compactEveryRuns: runs } : {}
}

function parseLoopArgs(raw, defaults = {}) {
  let input = String(raw || "").trim()
  let first = ""
  let rest = input
  let intervalMs = defaults.intervalMs ?? null

  if (!input && defaults.action) {
    rest = defaults.action
  } else {
    ;[first, rest] = splitFirst(input)
    if (first === "--watch") {
      intervalMs = defaults.intervalMs ?? 0
      rest = input
    } else if (first) {
      const parsedDuration = parseDuration(first)
      if (parsedDuration !== null) intervalMs = parsedDuration
      else if (intervalMs === null) return { ok: false, error: "Usage: /loop 0s <prompt> | /loop 5m <prompt> | /loop 200m /compact | /loop 10m !npm test | /loop --watch progress.md <prompt>" }
      else rest = input
    }
  }

  if (intervalMs === null) intervalMs = 0

  const job = {
    id: `${now().toString(36)}-${Math.random().toString(16).slice(2, 8)}`,
    name: defaults.name,
    action: defaults.action || "",
    intervalMs,
    immediate: defaults.immediate ?? true,
    maxRuns: defaults.maxRuns ?? 0,
    maxRuntimeMs: defaults.maxRuntimeMs ?? 0,
    maxFailures: defaults.maxFailures ?? 0,
    timeoutMs: defaults.timeoutMs ?? 0,
    until: defaults.until,
    stopFile: defaults.stopFile,
    progressFile: defaults.progressFile,
    promptFile: defaults.promptFile,
    includeFiles: Array.isArray(defaults.includeFiles) ? [...defaults.includeFiles] : [],
    watchPaths: Array.isArray(defaults.watchPaths) ? [...defaults.watchPaths] : [],
    compactEveryRuns: defaults.compactEveryRuns ?? 0,
    compactEveryMs: defaults.compactEveryMs ?? 0,
    testCommand: defaults.testCommand,
    verifyCommand: defaults.verifyCommand,
    preflightCommand: defaults.preflightCommand,
    postrunCommand: defaults.postrunCommand,
    notifyCommand: defaults.notifyCommand,
    branch: defaults.branch,
    branchDone: false,
    noOverlap: defaults.noOverlap ?? true,
    safe: defaults.safe ?? false,
    quiet: defaults.quiet ?? false,
    askNever: defaults.askNever ?? false,
    pauseOnVerifyFail: defaults.pauseOnVerifyFail ?? false,
    gitCheckpoint: defaults.gitCheckpoint ?? false,
    checkpointOnly: defaults.checkpointOnly ?? false,
    dryRun: defaults.dryRun ?? false,
    multi: defaults.multi ?? false,
    batch: defaults.batch ?? 0,
    runCount: 0,
    failureCount: 0,
    lastRunAt: 0,
    lastCompactAt: 0,
    lastCompactRunCount: 0,
    watchSnapshot: {},
    createdAt: new Date().toISOString(),
    enabled: true,
    paused: false,
  }

  let found
  let value

  ;[found, rest] = takeFlag(rest, "--no-now"); if (found) job.immediate = false
  ;[found, rest] = takeFlag(rest, "--now"); if (found) job.immediate = true
  ;[found, rest] = takeFlag(rest, "--no-overlap"); if (found) job.noOverlap = true
  ;[found, rest] = takeFlag(rest, "--allow-overlap"); if (found) job.noOverlap = false
  ;[found, rest] = takeFlag(rest, "--safe"); if (found) job.safe = true
  ;[found, rest] = takeFlag(rest, "--quiet"); if (found) job.quiet = true
  ;[found, rest] = takeFlag(rest, "--ask-never"); if (found) job.askNever = true
  ;[found, rest] = takeFlag(rest, "--git-checkpoint"); if (found) job.gitCheckpoint = true
  ;[found, rest] = takeFlag(rest, "--checkpoint-only"); if (found) job.checkpointOnly = true
  ;[found, rest] = takeFlag(rest, "--pause-on-verify-fail"); if (found) job.pauseOnVerifyFail = true
  ;[found, rest] = takeFlag(rest, "--dry-run"); if (found) job.dryRun = true
  ;[found, rest] = takeFlag(rest, "--multi"); if (found) job.multi = true
  ;[found, rest] = takeFlag(rest, "--replace"); if (found) job.multi = false

  ;[value, rest] = takeFlagValue(rest, "--name"); if (value !== undefined) job.name = value.trim()
  ;[value, rest] = takeFlagValue(rest, "--max-runs"); if (value !== undefined) job.maxRuns = parsePositiveInt(value, 0)
  ;[value, rest] = takeFlagValue(rest, "--timeout"); if (value !== undefined) job.timeoutMs = parseDuration(value) ?? 0
  ;[value, rest] = takeFlagValue(rest, "--max-runtime"); if (value !== undefined) job.maxRuntimeMs = parseDuration(value) ?? 0
  ;[value, rest] = takeFlagValue(rest, "--max-failures"); if (value !== undefined) job.maxFailures = parsePositiveInt(value, 0)
  ;[value, rest] = takeFlagValue(rest, "--until"); if (value !== undefined) job.until = stripOuterQuotes(value)
  ;[value, rest] = takeFlagValue(rest, "--stop-file"); if (value !== undefined) job.stopFile = stripOuterQuotes(value)
  ;[value, rest] = takeFlagValue(rest, "--progress-file"); if (value !== undefined) job.progressFile = stripOuterQuotes(value)
  ;[value, rest] = takeFlagValue(rest, "--prompt-file"); if (value !== undefined) job.promptFile = stripOuterQuotes(value)
  ;[value, rest] = takeFlagValue(rest, "--test"); if (value !== undefined) job.testCommand = stripOuterQuotes(value)
  ;[value, rest] = takeFlagValue(rest, "--verify"); if (value !== undefined) job.verifyCommand = stripOuterQuotes(value)
  ;[value, rest] = takeFlagValue(rest, "--preflight"); if (value !== undefined) job.preflightCommand = stripOuterQuotes(value)
  ;[value, rest] = takeFlagValue(rest, "--postrun"); if (value !== undefined) job.postrunCommand = stripOuterQuotes(value)
  ;[value, rest] = takeFlagValue(rest, "--notify"); if (value !== undefined) job.notifyCommand = stripOuterQuotes(value)
  ;[value, rest] = takeFlagValue(rest, "--branch"); if (value !== undefined) job.branch = stripOuterQuotes(value)
  ;[value, rest] = takeFlagValue(rest, "--batch"); if (value !== undefined) job.batch = parsePositiveInt(value, 0)
  ;[value, rest] = takeFlagValue(rest, "--compact-every")
  if (value !== undefined) Object.assign(job, parseCompactEvery(value))

  const watch = takeAllFlagValues(rest, "--watch")
  job.watchPaths.push(...watch[0].map(stripOuterQuotes).filter(Boolean))
  rest = watch[1]

  const includes = takeAllFlagValues(rest, "--include-file")
  job.includeFiles.push(...includes[0].map(stripOuterQuotes).filter(Boolean))
  rest = includes[1]

  job.action = stripOuterQuotes(rest || job.action || "")
  job.watchPaths = [...new Set(job.watchPaths)]
  job.includeFiles = [...new Set(job.includeFiles)]
  job.lastRunAt = job.immediate ? 0 : now()

  if (!job.action && !job.promptFile) return { ok: false, error: "Missing action. Example: /loop 0s continue from progress.md or /loop 0s --prompt-file loop-prompt.md" }
  return { ok: true, job }
}

function stateDir(directory) { return path.join(directory, STATE_DIR) }
function statePath(directory, sessionID) { return path.join(stateDir(directory), `${safeID(sessionID)}.json`) }
async function ensureDir(directory) { await fs.mkdir(directory, { recursive: true }) }
async function pathExists(filePath) { try { await fs.access(filePath); return true } catch { return false } }

async function readState(directory, sessionID) {
  try {
    const parsed = JSON.parse(await fs.readFile(statePath(directory, sessionID), "utf8"))
    return { version: 3, jobs: Array.isArray(parsed.jobs) ? parsed.jobs : [] }
  } catch {
    return { version: 3, jobs: [] }
  }
}

async function writeState(directory, sessionID, state) {
  await ensureDir(stateDir(directory))
  await fs.writeFile(statePath(directory, sessionID), JSON.stringify({ version: 3, jobs: state.jobs || [] }, null, 2))
}

async function removeState(directory, sessionID) { try { await fs.unlink(statePath(directory, sessionID)) } catch {} }

async function log(client, level, message, extra) {
  try { await client.app.log({ body: extra === undefined ? { service: SERVICE, level, message } : { service: SERVICE, level, message, extra } }) } catch {}
}
async function toast(client, message, variant = "info") { try { await client.tui.showToast({ body: { message, variant } }) } catch {} }
async function say(client, sessionID, text) { try { await client.session.prompt({ path: { id: sessionID }, body: { noReply: true, parts: [{ type: "text", text }] } }) } catch {} }

function commandKey(sessionID, name, args) { return `${sessionID || "no-session"}:${name || ""}:${args || ""}` }
function markHandled(sessionID, name, args) {
  handledCommands.set(commandKey(sessionID, name, args), now())
  for (const [key, time] of handledCommands.entries()) if (now() - time > 30_000) handledCommands.delete(key)
}
function wasHandled(sessionID, name, args) {
  const time = handledCommands.get(commandKey(sessionID, name, args))
  return typeof time === "number" && now() - time < 30_000
}

function commandName(name) { return String(name || "") }
function isPreset(name) { return ["loop-dev", "loop-testfix", "loop-compact", "loop-progress", "loop-safe-dev"].includes(name) }
function presetDefaults(name, args) {
  const [maybeDuration, rest] = splitFirst(args)
  const parsed = parseDuration(maybeDuration)
  const intervalMs = parsed === null ? 0 : parsed
  const extra = parsed === null ? String(args || "").trim() : rest
  if (name === "loop-compact") return { intervalMs: intervalMs || parseDuration("200m"), action: extra || "/compact", name: "compact", immediate: false }
  if (name === "loop-testfix") return { intervalMs, name: "testfix", safe: true, askNever: true, verifyCommand: extra || "npm test", action: `Run the project tests. Fix failures. Re-run the tests. Test command hint: ${extra || "npm test"}` }
  if (name === "loop-progress") return { intervalMs, name: "progress", safe: true, askNever: true, progressFile: "progress.md", action: extra || "Read progress.md and continue the next unfinished TODO. Mark completed TODOs with [x]. Add useful TODOs when you discover them." }
  if (name === "loop-safe-dev") return { intervalMs, name: "safe-dev", safe: true, askNever: true, noOverlap: true, checkpointOnly: true, batch: 5, progressFile: "progress.md", action: extra || "Develop the project from progress.md. Work in small safe batches. Mark completed TODOs with [x]. Add new ideas to progress.md. Run tests/lint/build if available." }
  return { intervalMs, name: "dev", askNever: true, progressFile: "progress.md", action: extra || "Continue developing the project from progress.md. Mark completed TODOs with [x]. Add new ideas to progress.md. Run tests/lint/build if available." }
}

function jobLabel(job) {
  const title = job.name ? `${job.name}: ` : ""
  const limit = job.maxRuns > 0 ? `, max ${job.maxRuns}` : ""
  const runtime = job.maxRuntimeMs > 0 ? `, runtime ${durationToText(job.maxRuntimeMs)}` : ""
  const timeout = job.timeoutMs > 0 ? `, timeout ${durationToText(job.timeoutMs)}` : ""
  const compact = job.compactEveryRuns > 0 ? `, compact every ${job.compactEveryRuns} runs` : job.compactEveryMs > 0 ? `, compact every ${durationToText(job.compactEveryMs)}` : ""
  const verify = job.verifyCommand ? ", verify" : ""
  const preflight = job.preflightCommand ? ", preflight" : ""
  const failures = job.maxFailures > 0 ? `, max failures ${job.maxFailures}` : ""
  const stopFile = job.stopFile ? ", stop-file" : ""
  const watch = job.watchPaths?.length ? `, watch ${job.watchPaths.join(",")}` : ""
  const paused = job.paused ? ", paused" : ""
  return `${title}${durationToText(job.intervalMs)} -> ${job.action || `[prompt-file: ${job.promptFile}]`}${limit}${runtime}${timeout}${compact}${verify}${preflight}${failures}${stopFile}${watch}${paused}`
}

function matchJob(job, target, index) {
  const text = String(target || "").trim()
  if (!text || text.toLowerCase() === "all") return true
  return job.id === text || job.name === text || String(index + 1) === text
}

async function appendLoopLog(directory, line, extra = {}) {
  try {
    await ensureDir(stateDir(directory))
    await fs.appendFile(path.join(stateDir(directory), "loop.log"), JSON.stringify({ time: new Date().toISOString(), line, ...extra }) + "\n")
  } catch {}
}

async function readSmallTextFile(filePath, maxBytes = 120_000) {
  try {
    const stat = await fs.stat(filePath)
    if (!stat.isFile() || stat.size > maxBytes) return ""
    return await fs.readFile(filePath, "utf8")
  } catch { return "" }
}

async function runProcess(command, args, cwd, timeoutMs = 60_000) {
  return await new Promise((resolve) => {
    const child = spawn(command, args, { cwd, shell: false, windowsHide: true })
    const stdout = []
    const stderr = []
    const timer = setTimeout(() => { try { child.kill("SIGTERM") } catch {} }, timeoutMs)
    child.stdout?.on("data", (data) => stdout.push(Buffer.from(data)))
    child.stderr?.on("data", (data) => stderr.push(Buffer.from(data)))
    child.on("error", (error) => { clearTimeout(timer); resolve({ code: -1, stdout: "", stderr: String(error) }) })
    child.on("close", (code) => { clearTimeout(timer); resolve({ code: code ?? 0, stdout: Buffer.concat(stdout).toString("utf8"), stderr: Buffer.concat(stderr).toString("utf8") }) })
  })
}

async function runShellCommand(command, cwd, timeoutMs = 120_000) {
  return await new Promise((resolve) => {
    const child = spawn(command, [], { cwd, shell: true, windowsHide: true })
    const stdout = []
    const stderr = []
    const timer = setTimeout(() => { try { child.kill("SIGTERM") } catch {} }, timeoutMs)
    child.stdout?.on("data", (data) => stdout.push(Buffer.from(data)))
    child.stderr?.on("data", (data) => stderr.push(Buffer.from(data)))
    child.on("error", (error) => { clearTimeout(timer); resolve({ code: -1, stdout: "", stderr: String(error) }) })
    child.on("close", (code) => { clearTimeout(timer); resolve({ code: code ?? 0, stdout: Buffer.concat(stdout).toString("utf8"), stderr: Buffer.concat(stderr).toString("utf8") }) })
  })
}

async function notifyJob(directory, job, reason) {
  if (!job.notifyCommand) return
  const command = String(job.notifyCommand).replace(/\{reason\}/g, String(reason || "")).replace(/\{job\}/g, String(job.name || job.id || ""))
  await runShellCommand(command, directory, 60_000)
}

function dangerousShell(command) {
  const text = String(command || "").toLowerCase()
  return [/\brm\s+-rf\b/, /\bgit\s+reset\b/, /\bgit\s+clean\b/, /\bgit\s+push\b/, /\bdel\s+\/s\b/, /\brmdir\s+\/s\b/, /\bformat\b/, /\bterraform\s+destroy\b/, /\bkubectl\s+delete\b/, /\bdeploy\b.*\bproduction\b/].some((pattern) => pattern.test(text))
}

function actionKind(action) {
  const text = String(action || "").trim()
  if (text === "/compact" || text === "/summarize") return "compact"
  if (text.startsWith("/")) return "command"
  if (text.startsWith("!") || text.startsWith("$")) return "shell"
  return "prompt"
}

function decoratePrompt(job) {
  const additions = []
  if (job.progressFile) additions.push(`Use ${job.progressFile} as the main progress/TODO state file. Read it before choosing the next task and update it after work.`)
  if (job.lastVerifyFailure) additions.push("Previous verify command failed. Fix this before moving on. Failure summary: " + String(job.lastVerifyFailure).slice(0, 1200))
  if (job.askNever) additions.push("Do not ask the user questions. Make reasonable assumptions and continue. Only write a short BLOCKED note if truly blocked.")
  if (job.safe) additions.push("Safety rules: do not run destructive commands such as git reset, git clean, rm -rf, del /s, rmdir /s, force push, production deploys, production migrations, terraform destroy, or deleting user data. If such an action seems needed, write a BLOCKED note instead.")
  if (job.batch > 0) additions.push(`Batch rule: in this run, work on at most ${job.batch} unfinished TODO item(s). Mark completed items with [x].`)
  if (job.quiet) additions.push("Keep replies short. Summarize only what changed, tests run, and next step.")
  if (job.testCommand) additions.push(`After making changes, run this test/check command if applicable: ${job.testCommand}. If it fails, fix the failure and try again.`)
  if (job.checkpointOnly || job.gitCheckpoint) additions.push("Keep changes incremental and easy to review because the loop will create a checkpoint after the run.")
  if (!additions.length) return job.action
  return `${job.action}\n\nOpenCode loop instructions:\n- ${additions.join("\n- ")}`
}

async function buildPrompt(directory, job) {
  const sections = []
  if (job.promptFile) {
    const text = await readSmallTextFile(path.resolve(directory, job.promptFile))
    if (text.trim()) sections.push(`Instructions from ${job.promptFile}:\n${text.trim()}`)
    else sections.push(`Prompt file ${job.promptFile} was requested but could not be read. Continue from the regular action instead.`)
  }
  if (job.action) sections.push(decoratePrompt(job))
  for (const file of job.includeFiles || []) {
    const text = await readSmallTextFile(path.resolve(directory, file), 80_000)
    if (text.trim()) sections.push(`Context from ${file}:\n${text.trim().slice(0, 20_000)}`)
  }
  return sections.join("\n\n---\n\n") || decoratePrompt(job)
}

async function ensureBranch(directory, job, client, sessionID) {
  if (!job.branch || job.branchDone) return job
  const branch = safeID(job.branch)
  const inRepo = await runProcess("git", ["rev-parse", "--is-inside-work-tree"], directory, 10_000)
  if (inRepo.code !== 0) { job.branchDone = true; return job }
  let result = await runProcess("git", ["switch", branch], directory, 30_000)
  if (result.code !== 0) result = await runProcess("git", ["switch", "-c", branch], directory, 30_000)
  job.branchDone = true
  await toast(client, result.code === 0 ? `Loop branch active: ${branch}` : `Could not switch/create branch: ${branch}`, result.code === 0 ? "success" : "warning")
  await appendLoopLog(directory, "branch", { sessionID, branch, code: result.code })
  return job
}

async function maybeCompact(client, sessionID, job) {
  const dueRuns = job.compactEveryRuns > 0 && (job.runCount || 0) > 0 && (job.runCount || 0) % job.compactEveryRuns === 0 && job.lastCompactRunCount !== job.runCount
  const dueTime = job.compactEveryMs > 0 && (!job.lastCompactAt || now() - job.lastCompactAt >= job.compactEveryMs)
  if (!dueRuns && !dueTime) return job
  try {
    await client.session.summarize({ path: { id: sessionID }, body: {} })
    job.lastCompactAt = now()
    job.lastCompactRunCount = job.runCount || 0
  } catch {}
  return job
}

async function snapshotPaths(directory, files) {
  const snapshot = {}
  for (const file of files || []) {
    try {
      const stat = await fs.stat(path.resolve(directory, file))
      snapshot[file] = `${stat.mtimeMs}:${stat.size}`
    } catch { snapshot[file] = "missing" }
  }
  return snapshot
}

async function watchChanged(directory, job) {
  if (!job.watchPaths?.length) return false
  const next = await snapshotPaths(directory, job.watchPaths)
  const previous = job.watchSnapshot || {}
  const changed = job.watchPaths.some((file) => previous[file] !== next[file])
  if (changed) job.watchSnapshot = next
  return changed
}

async function fileContains(filePath, needle) {
  try {
    const stat = await fs.stat(filePath)
    if (!stat.isFile() || stat.size > MAX_SCAN_BYTES) return false
    return (await fs.readFile(filePath, "utf8")).includes(needle)
  } catch { return false }
}

async function untilReached(directory, job) {
  if (!job.until) return false
  const files = ["progress.md", "PROGRESS.md", "todo.md", "TODO.md", "todolist.md", "TODOLIST.md", path.join(".opencode", "opencode-loop", "until.txt")]
  for (const file of files) if (await fileContains(path.resolve(directory, file), job.until)) return true
  let scanned = 0
  async function walk(current) {
    if (scanned >= MAX_SCAN_FILES) return false
    let entries
    try { entries = await fs.readdir(current, { withFileTypes: true }) } catch { return false }
    for (const entry of entries) {
      if (scanned >= MAX_SCAN_FILES) return false
      if ([".git", "node_modules", "dist", "build", ".next", "coverage"].includes(entry.name)) continue
      const full = path.join(current, entry.name)
      if (entry.isDirectory()) { if (await walk(full)) return true }
      else if (entry.isFile() && /\.(md|txt|json|yaml|yml)$/i.test(entry.name)) { scanned++; if (await fileContains(full, job.until)) return true }
    }
    return false
  }
  return await walk(directory)
}

async function createCheckpoint(directory, sessionID, job, client) {
  if (!job.checkpointOnly && !job.gitCheckpoint) return
  const inRepo = await runProcess("git", ["rev-parse", "--is-inside-work-tree"], directory, 10_000)
  if (inRepo.code !== 0) return
  const status = await runProcess("git", ["status", "--short"], directory, 30_000)
  if (!status.stdout.trim()) return
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-")
  const checkpointDir = path.join(stateDir(directory), "checkpoints", safeID(sessionID))
  await ensureDir(checkpointDir)
  const diff = await runProcess("git", ["diff", "--binary"], directory, 120_000)
  const staged = await runProcess("git", ["diff", "--cached", "--binary"], directory, 120_000)
  const prefix = `${timestamp}-${safeID(job.name || job.id)}`
  await fs.writeFile(path.join(checkpointDir, `${prefix}.status.txt`), status.stdout + status.stderr)
  await fs.writeFile(path.join(checkpointDir, `${prefix}.patch`), `${diff.stdout}\n${staged.stdout}`)
  if (job.gitCheckpoint) {
    await runProcess("git", ["add", "-A"], directory, 120_000)
    await runProcess("git", ["commit", "-m", `chore: opencode loop checkpoint ${timestamp}`], directory, 120_000)
  }
  await toast(client, `Loop checkpoint saved: ${prefix}`, "success")
}

function getIdleSessionID(event) {
  const sessionID = event?.properties?.sessionID
  if (event?.type === "session.idle" && typeof sessionID === "string") return sessionID
  const status = event?.properties?.status
  if (event?.type === "session.status" && typeof sessionID === "string" && status && typeof status === "object" && status.type === "idle") return sessionID
  return undefined
}

function dueJobs(state, force = false) {
  const current = now()
  return (state.jobs || []).filter((job) => {
    if (!job.enabled || job.paused) return false
    if (job.maxRuns > 0 && (job.runCount || 0) >= job.maxRuns) return false
    if (job.maxRuntimeMs > 0 && current - Date.parse(job.createdAt || new Date().toISOString()) >= job.maxRuntimeMs) return true
    if (force) return true
    if (job.watchPaths?.length) return false
    return job.intervalMs === 0 || !job.lastRunAt || current - job.lastRunAt >= job.intervalMs
  })
}

function clearActiveRun(sessionID) {
  const active = activeRuns.get(sessionID)
  if (active?.timer) clearTimeout(active.timer)
  activeRuns.delete(sessionID)
}

async function finalizeActiveRun(directory, client, sessionID) {
  const active = activeRuns.get(sessionID)
  if (!active) return
  clearActiveRun(sessionID)
  const state = await readState(directory, sessionID)
  const job = (state.jobs || []).find((candidate) => candidate.id === active.jobId)
  if (!job) return
  job.lastFinishedAt = now()

  if (job.verifyCommand) {
    const verify = await runShellCommand(job.verifyCommand, directory, job.timeoutMs || 300_000)
    job.lastVerifyAt = now()
    job.lastVerifyCode = verify.code
    if (verify.code === 0) {
      job.failureCount = 0
      job.lastVerifyFailure = ""
      await toast(client, "Loop verify passed: " + job.verifyCommand, "success")
    } else {
      job.failureCount = (job.failureCount || 0) + 1
      job.lastVerifyFailure = (job.verifyCommand + "\nexit=" + verify.code + "\n" + verify.stdout + "\n" + verify.stderr).slice(0, 4000)
      await toast(client, "Loop verify failed: " + job.verifyCommand, "warning")
      if (job.pauseOnVerifyFail || (job.maxFailures > 0 && job.failureCount >= job.maxFailures)) {
        job.paused = true
        await notifyJob(directory, job, "verify_failed")
      }
    }
    await appendLoopLog(directory, "verify", { sessionID, job: job.name || job.id, command: job.verifyCommand, code: verify.code, failures: job.failureCount || 0 })
  }

  if (job.postrunCommand) {
    if (job.safe && dangerousShell(job.postrunCommand)) await appendLoopLog(directory, "postrun-blocked", { sessionID, job: job.name || job.id, command: job.postrunCommand })
    else {
      const postrun = await runShellCommand(job.postrunCommand, directory, job.timeoutMs || 300_000)
      job.lastPostrunCode = postrun.code
      job.lastPostrunAt = now()
      if (postrun.code !== 0) {
        job.failureCount = (job.failureCount || 0) + 1
        job.lastPostrunFailure = (job.postrunCommand + "\nexit=" + postrun.code + "\n" + postrun.stdout + "\n" + postrun.stderr).slice(0, 4000)
        if (job.maxFailures > 0 && job.failureCount >= job.maxFailures) {
          job.paused = true
          await notifyJob(directory, job, "postrun_failed")
        }
      }
      await appendLoopLog(directory, "postrun", { sessionID, job: job.name || job.id, command: job.postrunCommand, code: postrun.code })
    }
  }

  state.jobs = (state.jobs || []).map((candidate) => candidate.id === job.id ? job : candidate).filter((candidate) => candidate.enabled !== false)
  await writeState(directory, sessionID, state)
  await createCheckpoint(directory, sessionID, job, client)
}

async function fireAction(directory, client, sessionID, job) {
  const action = String(job.action || "").trim()
  const kind = actionKind(action)
  if (kind === "compact") {
    await client.session.summarize({ path: { id: sessionID }, body: {} })
    return { startsAssistantTurn: false }
  }
  if (kind === "command") {
    const [command, argumentsText] = splitFirst(action.slice(1))
    client.session.command({ path: { id: sessionID }, body: { command, arguments: argumentsText } }).catch(() => {})
    return { startsAssistantTurn: true }
  }
  if (kind === "shell") {
    const command = action.slice(1).trim()
    if (job.safe && dangerousShell(command)) {
      await toast(client, `Blocked dangerous shell command in safe mode: ${command}`, "error")
      await appendLoopLog(directory, "blocked", { sessionID, job: job.name || job.id, command })
      return { startsAssistantTurn: false }
    }
    client.session.shell({ path: { id: sessionID }, body: { command } }).catch(() => {})
    return { startsAssistantTurn: true }
  }
  const prompt = await buildPrompt(directory, job)
  client.session.prompt({ path: { id: sessionID }, body: { parts: [{ type: "text", text: `AUTONOMOUS OPENCODE LOOP ITERATION. Continue the configured task now. Do not explain the /loop command. Do not search for documentation about this plugin. Do not create scheduler files. Do not ask questions. Make reasonable assumptions and work directly.\n\n${prompt}` }] } }).catch(() => {})
  return { startsAssistantTurn: true }
}

async function maybeRunDueJobs(directory, client, sessionID, options = {}) {
  const active = activeRuns.get(sessionID)
  if (active && active.job?.noOverlap !== false && now() - active.startedAt < (active.job?.timeoutMs || DEFAULT_ACTIVE_GUARD_MS)) return

  const state = await readState(directory, sessionID)
  for (const job of state.jobs || []) {
    if (job.watchPaths?.length && !job.paused && job.enabled && await watchChanged(directory, job)) job.lastRunAt = 0
  }
  let due = dueJobs(state, options.force)
  if (!due.length) { await writeState(directory, sessionID, state); return }
  let job = due[0]

  if (job.maxRuntimeMs > 0 && now() - Date.parse(job.createdAt || new Date().toISOString()) >= job.maxRuntimeMs) {
    state.jobs = (state.jobs || []).filter((candidate) => candidate.id !== job.id)
    await writeState(directory, sessionID, state)
    await notifyJob(directory, job, "max_runtime_reached")
    await toast(client, `Loop stopped by --max-runtime: ${job.name || job.id}`, "success")
    await appendLoopLog(directory, "max-runtime", { sessionID, job: job.name || job.id })
    return
  }
  if (job.stopFile && await pathExists(path.resolve(directory, job.stopFile))) {
    state.jobs = (state.jobs || []).filter((candidate) => candidate.id !== job.id)
    await writeState(directory, sessionID, state)
    await notifyJob(directory, job, "stop_file")
    await toast(client, "Loop stopped by --stop-file: " + job.stopFile, "success")
    return
  }
  if (await untilReached(directory, job)) {
    state.jobs = (state.jobs || []).filter((candidate) => candidate.id !== job.id)
    await writeState(directory, sessionID, state)
    await notifyJob(directory, job, "until_reached")
    await toast(client, `Loop stopped by --until: ${job.until}`, "success")
    return
  }

  if (job.preflightCommand) {
    if (job.safe && dangerousShell(job.preflightCommand)) {
      job.paused = true
      await writeState(directory, sessionID, state)
      await notifyJob(directory, job, "preflight_blocked")
      await toast(client, "Preflight blocked in safe mode and loop paused: " + job.preflightCommand, "error")
      return
    }
    const preflight = await runShellCommand(job.preflightCommand, directory, job.timeoutMs || 300_000)
    await appendLoopLog(directory, "preflight", { sessionID, job: job.name || job.id, command: job.preflightCommand, code: preflight.code })
    if (preflight.code !== 0) {
      job.paused = true
      job.failureCount = (job.failureCount || 0) + 1
      job.lastPreflightFailure = (job.preflightCommand + "\nexit=" + preflight.code + "\n" + preflight.stdout + "\n" + preflight.stderr).slice(0, 4000)
      state.jobs = (state.jobs || []).map((candidate) => candidate.id === job.id ? job : candidate)
      await writeState(directory, sessionID, state)
      await notifyJob(directory, job, "preflight_failed")
      await toast(client, "Preflight failed and loop paused: " + job.preflightCommand, "warning")
      return
    }
  }

  job = await ensureBranch(directory, job, client, sessionID)
  job = await maybeCompact(client, sessionID, job)
  job.lastRunAt = now()
  job.runCount = (job.runCount || 0) + 1
  if (job.maxRuns > 0 && job.runCount >= job.maxRuns) {
    job.enabled = false
    await notifyJob(directory, job, "max_runs_reached")
  }
  state.jobs = (state.jobs || []).map((candidate) => candidate.id === job.id ? job : candidate)
  await writeState(directory, sessionID, state)
  await appendLoopLog(directory, "run", { sessionID, job: job.name || job.id, runCount: job.runCount })
  await toast(client, `Loop running: ${job.name || job.id}`, "info")

  try {
    const result = await fireAction(directory, client, sessionID, job)
    if (!result.startsAssistantTurn) {
      const fresh = await readState(directory, sessionID)
      fresh.jobs = (fresh.jobs || []).filter((candidate) => candidate.enabled !== false)
      await writeState(directory, sessionID, fresh)
    }
    if (result.startsAssistantTurn) {
      let timer
      if (job.timeoutMs > 0) timer = setTimeout(() => { client.session.abort?.({ path: { id: sessionID }, body: {} }).catch(() => {}); toast(client, `Loop timeout fired: ${job.name || job.id}`, "warning").catch(() => {}) }, job.timeoutMs)
      activeRuns.set(sessionID, { jobId: job.id, job, startedAt: now(), timer })
    }
  } catch (error) {
    clearActiveRun(sessionID)
    await toast(client, `Loop job failed: ${error instanceof Error ? error.message : String(error)}`, "error")
    await appendLoopLog(directory, "error", { sessionID, job: job.name || job.id, error: error instanceof Error ? error.message : String(error) })
  }
}

function normalizeActionForCompare(value) {
  return String(value || "").replace(/\s+/g, " ").trim()
}

function sameLoopDefinition(a, b) {
  if (!a || !b) return false
  return (a.name || "") === (b.name || "") &&
    Number(a.intervalMs || 0) === Number(b.intervalMs || 0) &&
    normalizeActionForCompare(a.action) === normalizeActionForCompare(b.action) &&
    normalizeActionForCompare(a.promptFile) === normalizeActionForCompare(b.promptFile)
}

async function addLoop(directory, client, sessionID, args, defaults = {}) {
  const parsed = parseLoopArgs(args, defaults)
  if (!parsed.ok) { await toast(client, parsed.error, "warning"); return }
  if (parsed.job.watchPaths.length) parsed.job.watchSnapshot = await snapshotPaths(directory, parsed.job.watchPaths)
  if (parsed.job.dryRun) { await toast(client, `Loop dry run: ${jobLabel(parsed.job)}`, "info"); await say(client, sessionID, "OpenCode loop dry run:\n```json\n" + JSON.stringify(parsed.job, null, 2) + "\n```"); return }
  const state = await readState(directory, sessionID)
  const jobs = Array.isArray(state.jobs) ? state.jobs : []

  // Default behavior is replace/upsert, not append forever. This prevents duplicate
  // loops when OpenCode emits both command.execute.before and command.executed,
  // and it matches the common expectation that /loop configures the current loop.
  let replaced = false
  if (!parsed.job.multi) {
    const targetName = parsed.job.name || "default"
    parsed.job.name = targetName
    state.jobs = jobs.filter((existing) => {
      const existingName = existing.name || "default"
      const shouldReplace = existingName === targetName || sameLoopDefinition(existing, parsed.job)
      if (shouldReplace) replaced = true
      return !shouldReplace
    })
  } else {
    state.jobs = jobs
  }

  state.jobs.push(parsed.job)
  await writeState(directory, sessionID, state)
  await toast(client, `${replaced ? "Loop replaced" : "Loop added"}: ${jobLabel(parsed.job)}`, "success")
  await appendLoopLog(directory, replaced ? "replace" : "add", { sessionID, job: parsed.job.name || parsed.job.id, label: jobLabel(parsed.job) })
}

async function stopLoop(directory, client, sessionID, args) {
  const target = String(args || "").trim()
  if (!target || target.toLowerCase() === "all") { await removeState(directory, sessionID); clearActiveRun(sessionID); await toast(client, "All loops stopped for this session.", "success"); return }
  const state = await readState(directory, sessionID)
  const before = state.jobs.length
  state.jobs = state.jobs.filter((job, index) => !matchJob(job, target, index))
  await writeState(directory, sessionID, state)
  await toast(client, `Stopped ${before - state.jobs.length} loop(s).`, "success")
}

async function updateJobState(directory, client, sessionID, args, updater, message) {
  const target = String(args || "").trim() || "all"
  const state = await readState(directory, sessionID)
  let count = 0
  state.jobs = (state.jobs || []).map((job, index) => matchJob(job, target, index) ? (count++, updater(job)) : job)
  await writeState(directory, sessionID, state)
  await toast(client, `${message}: ${count} loop(s).`, count ? "success" : "warning")
}

async function statusLoop(directory, client, sessionID) {
  const state = await readState(directory, sessionID)
  const jobs = state.jobs || []
  const lines = jobs.length ? jobs.map((job, index) => {
    const dueIn = Math.max(0, job.intervalMs - (now() - (job.lastRunAt || 0)))
    const flags = [job.paused ? "paused" : "active", job.safe ? "safe" : undefined, job.askNever ? "ask-never" : undefined, job.noOverlap ? "no-overlap" : undefined, job.checkpointOnly ? "checkpoint-only" : undefined, job.gitCheckpoint ? "git-checkpoint" : undefined].filter(Boolean).join(",")
    return `${index + 1}. ${job.id}${job.name ? ` (${job.name})` : ""}: ${jobLabel(job)} | runs=${job.runCount || 0} | failures=${job.failureCount || 0} | due in ${durationToText(dueIn)} | ${flags}`
  }) : ["No active loop jobs."]
  await toast(client, jobs.length ? `${jobs.length} loop job(s).` : "No active loop jobs.", jobs.length ? "info" : "warning")
  await say(client, sessionID, "OpenCode loop status:\n" + lines.join("\n"))
}

async function logsLoop(directory, client, sessionID) {
  let text = "No loop log found."
  try { text = (await fs.readFile(path.join(stateDir(directory), "loop.log"), "utf8")).trim().split(/\r?\n/).slice(-80).join("\n") || text } catch {}
  await say(client, sessionID, "OpenCode loop logs:\n" + text)
}

async function helpLoop(client, sessionID) {
  await say(client, sessionID, [
    "OpenCode Loop help:",
    "/loop 0s <prompt>                                Claude Code style auto-continue",
    "/loop 5m --ask-never --safe <prompt>              interval autonomous loop",
    "/loop 200m --no-now /compact                      compact/summarize loop",
    "/loop 10m !npm test                               shell loop",
    "/loop 0s --verify \"npm test\" <prompt>            verify after each assistant turn",
    "/loop 0s --prompt-file loop-prompt.md             load prompt from a file",
    "/loop 0s --max-runtime 6h --max-failures 3 <task> stop safely after limits",
    "/loop-doctor | /loop-init | /loop-export",
  ].join("\n"))
}

async function runNow(directory, client, sessionID, args) {
  const target = String(args || "").trim() || "all"
  const state = await readState(directory, sessionID)
  let count = 0
  for (const [index, job] of (state.jobs || []).entries()) if (matchJob(job, target, index)) { job.lastRunAt = 0; job.paused = false; count++ }
  await writeState(directory, sessionID, state)
  await toast(client, `Marked ${count} loop job(s) due now.`, count ? "success" : "warning")
  await maybeRunDueJobs(directory, client, sessionID, { force: true })
}

async function doctorLoop(directory, client, sessionID) {
  const state = await readState(directory, sessionID)
  await say(client, sessionID, [
    "OpenCode Loop doctor:",
    `- plugin: ${SERVICE}`,
    `- project directory: ${directory}`,
    `- state directory: ${stateDir(directory)}`,
    `- active jobs: ${(state.jobs || []).length}`,
    `- node: ${process.version}`,
    `- platform: ${process.platform}`,
    "- smoke test: /loop 0s --max-runs 1 --dry-run continue from progress.md",
  ].join("\n"))
}

async function initLoop(directory, client, sessionID, args) {
  const target = String(args || "").trim() || "progress.md"
  const full = path.resolve(directory, target)
  if (await pathExists(full)) { await toast(client, `${target} already exists.`, "warning"); return }
  await fs.writeFile(full, DEFAULT_PROGRESS_MD, "utf8")
  await toast(client, `Created ${target}.`, "success")
  await appendLoopLog(directory, "init", { sessionID, file: target })
}

async function exportLoop(directory, client, sessionID) {
  const state = await readState(directory, sessionID)
  await say(client, sessionID, "OpenCode loop state export:\n```json\n" + JSON.stringify(state, null, 2) + "\n```")
}

async function handleCommand(directory, client, input, fallbackName, fallbackArgs) {
  const name = commandName(input?.command ?? input?.name ?? fallbackName)
  const sessionID = input?.sessionID
  const args = input?.arguments ?? fallbackArgs ?? ""
  if (!sessionID || !name) return false
  if (wasHandled(sessionID, name, args)) return true
  markHandled(sessionID, name, args)

  if (name === "loop") return await addLoop(directory, client, sessionID, args), true
  if (isPreset(name)) return await addLoop(directory, client, sessionID, args, presetDefaults(name, args)), true
  if (name === "loop-stop" || name === "loop-remove") return await stopLoop(directory, client, sessionID, args), true
  if (name === "loop-clear") return await stopLoop(directory, client, sessionID, "all"), true
  if (name === "loop-status") return await statusLoop(directory, client, sessionID), true
  if (name === "loop-logs") return await logsLoop(directory, client, sessionID), true
  if (name === "loop-help") return await helpLoop(client, sessionID), true
  if (name === "loop-now") return await runNow(directory, client, sessionID, args), true
  if (name === "loop-pause") return await updateJobState(directory, client, sessionID, args, (job) => ({ ...job, paused: true }), "Paused"), true
  if (name === "loop-resume") return await updateJobState(directory, client, sessionID, args, (job) => ({ ...job, paused: false, lastRunAt: 0 }), "Resumed"), true
  if (name === "loop-doctor") return await doctorLoop(directory, client, sessionID), true
  if (name === "loop-init") return await initLoop(directory, client, sessionID, args), true
  if (name === "loop-export") return await exportLoop(directory, client, sessionID), true
  handledCommands.delete(commandKey(sessionID, name, args))
  return false
}

export const OpenCodeLoopPlugin = async ({ client, directory }) => {
  await log(client, "info", "Plugin initialized", { directory })
  return {
    "command.execute.before": async (input) => { await handleCommand(directory, client, input) },
    event: async ({ event }) => {
      if (event.type === "command.executed") {
        const props = event.properties || {}
        await handleCommand(directory, client, props, props.name, props.arguments)
      }
      const idleSessionID = getIdleSessionID(event)
      if (idleSessionID) {
        await finalizeActiveRun(directory, client, idleSessionID)
        await maybeRunDueJobs(directory, client, idleSessionID)
      }
    },
  }
}

export default OpenCodeLoopPlugin
