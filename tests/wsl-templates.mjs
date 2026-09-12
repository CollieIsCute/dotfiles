// Run with: node tests/wsl-templates.mjs (requires chezmoi and Bash).
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync, readdirSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = fileURLToPath(new URL('../', import.meta.url));
const scratch = mkdtempSync(join(tmpdir(), 'chezmoi-wsl-test-'));
process.on('exit', () => rmSync(scratch, { recursive: true, force: true }));
function render(file, os, distro = 'ubuntu', kernel = '6.6.87.2-microsoft-standard-WSL2') {
  return execFileSync('chezmoi', ['--source', repo, '--config', join(scratch, 'chezmoi.toml'),
    '--persistent-state', join(scratch, 'state.db'), '--cache', join(scratch, 'cache'), '--override-data', JSON.stringify({
    chezmoi: { os, osRelease: { id: distro }, kernel: { osrelease: kernel }, stdin: '',
      workingTree: "C:/Users/O'Brien dotfiles" },
  }), 'execute-template', '--file', `${repo}/home/${file}`], { encoding: 'utf8' });
}
function bashCheck(script) {
  execFileSync('bash', ['-n'], { input: script });
}

for (const distro of ['ubuntu', 'arch']) {
  for (const kernel of ['6.6.87.2-microsoft-standard-WSL2', '6.12.1-generic']) {
    const wsl = kernel.includes('microsoft');
    const args = ['linux', distro, kernel];
    const ignore = render('.chezmoiignore', ...args);
    const packages = render('.chezmoiscripts/run_onchange_after_0-install-packages.sh.tmpl', ...args);
    const setup = render('.chezmoiscripts/run_once_before_0-setup-package-manager.sh.tmpl', ...args);
    assert.equal(ignore.split(/\r?\n/).includes('.config/hypr'), wsl);
    assert.equal(ignore.includes('.chezmoiscripts/4-configure-greetd-noctalia.sh'), wsl);
    assert.ok(ignore.includes('.chezmoiscripts/*.ps1'));
    assert.ok(!ignore.includes('.chezmoiscripts/*.sh'));
    assert.ok(/\bfish\b/.test(packages) && /\btmux\b/.test(packages));
    assert.equal(/\bhyprland\b/.test(packages), !wsl);
    assert.equal(/\bsddm\b/.test(packages), !wsl);
    if (distro === 'arch') assert.ok(packages.includes('--mflags "--syncdeps --noconfirm"'));
    if (distro === 'ubuntu') assert.equal(setup.includes('pkg.noctalia.dev'), !wsl);
    if (wsl) {
      assert.equal(render('.chezmoiexternal.toml', ...args).trim(), '');
      assert.equal(JSON.parse(render('dot_config/opencode/tui.json.tmpl', ...args)).theme, 'system');
      assert.ok(render('dot_config/btop/modify_btop.conf', ...args).includes('"Default"'));
    }
    for (const file of readdirSync(`${repo}/home/.chezmoiscripts`).filter(f => f.endsWith('.sh.tmpl'))) {
      bashCheck(render(`.chezmoiscripts/${file}`, ...args));
    }
  }
}
// WSL detection must not leak into native Windows or macOS rendering.
for (const os of ['windows', 'darwin']) {
  const ignore = render('.chezmoiignore', os);
  assert.ok(ignore.includes(os === 'windows' ? '.chezmoiscripts/*.sh' : '.chezmoiscripts/*.ps1'));
  assert.equal(JSON.parse(render('dot_config/opencode/tui.json.tmpl', os)).theme, 'matugen');
}
const windowsPackages = render('.chezmoiscripts/run_onchange_after_0-install-packages.ps1.tmpl', 'windows');
assert.ok(!windowsPackages.includes('main/claude-code'));
assert.ok(!windowsPackages.includes('main/opencode'));
assert.ok(windowsPackages.includes('extras/alacritty'));
bashCheck(readFileSync(`${repo}/scripts/bootstrap-wsl.sh`, 'utf8'));
assert.ok(!readFileSync(`${repo}/scripts/bootstrap-wsl.sh`, 'utf8').includes('\r'));
if (process.platform === 'win32') {
  const entry = render('.chezmoiscripts/run_after_7-apply-wsl.ps1.tmpl', 'windows');
  const scripts = readdirSync(`${repo}/home/.chezmoiscripts`).filter(f => /\.ps1(\.tmpl)?$/.test(f))
    .map(f => f.endsWith('.tmpl') ? render(`.chezmoiscripts/${f}`, 'windows') : readFileSync(`${repo}/home/.chezmoiscripts/${f}`, 'utf8'));
  const check = `
$ErrorActionPreference = 'Stop'
${scripts.map(s => `[void][scriptblock]::Create([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${Buffer.from(s).toString('base64')}')))`).join('\n')}
$entry = [scriptblock]::Create([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${Buffer.from(entry).toString('base64')}')))
function wsl.exe {
    $global:LASTEXITCODE = 0
    switch ($args[0]) {
        '--exec' {
            if ($args[1] -eq 'uname') {
                if ($case -in @('missing', 'install-fail')) { $global:LASTEXITCODE = 50; return }
                if ($case -eq 'wsl1') { return '4.4.0-Microsoft' }
                return '6.6.87.2-microsoft-standard-WSL2'
            }
            if ($args[1] -ne 'wslpath' -or $args[3] -ne "C:/Users/O'Brien dotfiles") { throw 'Incorrect Windows path argument' }
            if ($case -eq 'path-fail') { $global:LASTEXITCODE = 1; return }
            return "/mnt/c/Users/O'Brien dotfiles"
        }
        '--install' { if ($case -eq 'install-fail') { $global:LASTEXITCODE = 1 } }
        '--cd' {
            if ($args.Count -ne 6 -or $args[4] -ne "/mnt/c/Users/O'Brien dotfiles/scripts/bootstrap-wsl.sh" -or $args[5] -ne "/mnt/c/Users/O'Brien dotfiles") { throw 'Incorrect WSL argv' }
            if ($env:WSLENV -notlike '*CHEZMOI_GITHUB_ACCESS_TOKEN/u*') { throw 'Missing WSL environment forwarding' }
            if ($case -eq 'apply-fail') { $global:LASTEXITCODE = 17 }
        }
        default { throw 'Unexpected WSL command' }
    }
}
foreach ($case in @('ok', 'missing', 'install-fail', 'wsl1', 'path-fail', 'apply-fail')) {
    $env:WSLENV = 'EXISTING/p'
    $failure = ''
    try { & $entry } catch { $failure = $_.Exception.Message }
    $expected = switch ($case) {
        'ok' { '^$' }; 'missing' { 'WSL installed' }; 'install-fail' { 'WSL setup failed' }
        'wsl1' { 'must use WSL 2' }; 'path-fail' { 'Cannot access' }; 'apply-fail' { 'exit code 17' }
    }
    if ($failure -notmatch $expected) { throw "Case $case failed: $failure" }
    if ($env:WSLENV -ne 'EXISTING/p') { throw 'WSLENV was not restored' }
}
`;
  execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-EncodedCommand', Buffer.from(check, 'utf16le').toString('base64')]);
}
console.log('WSL/native template routing and Bash syntax checks passed.');
