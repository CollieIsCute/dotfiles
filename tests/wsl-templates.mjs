// Run with: node tests/wsl-templates.mjs (requires chezmoi and Bash).
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, readFileSync, readdirSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = fileURLToPath(new URL('../', import.meta.url));
const scratch = mkdtempSync(join(tmpdir(), 'chezmoi-wsl-test-'));
process.on('exit', () => rmSync(scratch, { recursive: true, force: true }));
function render(file, os, distro = 'ubuntu', kernel = '6.6.87.2-microsoft-standard-WSL2', workingTree = "C:/Users/O'Brien dotfiles") {
  return execFileSync('chezmoi', ['--source', repo, '--config', join(scratch, 'chezmoi.toml'),
    '--persistent-state', join(scratch, 'state.db'), '--cache', join(scratch, 'cache'), '--override-data', JSON.stringify({
    chezmoi: { os, osRelease: { id: distro }, kernel: { osrelease: kernel }, stdin: '',
      workingTree },
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
    assert.equal(/\bpacman\b/.test(packages), distro === 'arch');
    assert.equal(/\bapt-get\b/.test(packages), distro === 'ubuntu');
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
const workflow = readFileSync(`${repo}/.github/workflows/test-distros.yaml`, 'utf8');
assert.ok(workflow.includes('/scripts/bootstrap-wsl.ps1'));
assert.ok(workflow.includes('wsl --manage archlinux --set-default-user dev'));
assert.ok(!/wsl (?:--install|--set-default-version|--set-default )/.test(workflow));
assert.ok((workflow.match(/chezmoi.* -v/g) ?? []).length >= 5, 'Keep verbose installation logs');
if (process.platform === 'win32') {
  // Exercise the actual shared bootstrap through the rendered chezmoi entry.
  const checkout = join(scratch, "O'Brien dotfiles");
  mkdirSync(join(checkout, 'scripts'), { recursive: true });
  copyFileSync(`${repo}/scripts/bootstrap-wsl.ps1`, join(checkout, 'scripts/bootstrap-wsl.ps1'));
  const entry = render('.chezmoiscripts/run_after_7-apply-wsl.ps1.tmpl', 'windows', undefined, undefined, checkout);
  const scripts = readdirSync(`${repo}/home/.chezmoiscripts`).filter(f => /\.ps1(\.tmpl)?$/.test(f))
    .map(f => f.endsWith('.tmpl') ? render(`.chezmoiscripts/${f}`, 'windows') : readFileSync(`${repo}/home/.chezmoiscripts/${f}`, 'utf8'));
  const check = `
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
${scripts.map(s => `[void][scriptblock]::Create([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${Buffer.from(s).toString('base64')}')))`).join('\n')}
$entry = [scriptblock]::Create([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${Buffer.from(entry).toString('base64')}')))
$expectedCheckout = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${Buffer.from(checkout).toString('base64')}'))
function wsl.exe {
    $global:LASTEXITCODE = 0
    $wslCalls.Add($args -join ' ')
    switch ($args[0]) {
        '--install' {
            if (($args -join ' ') -eq '--install --no-distribution') {
                if ($case -eq 'engine-fail') { $global:LASTEXITCODE = 1 }
                if ($case -eq 'reboot') { $global:LASTEXITCODE = 3010 }
                return
            }
            if (($args -join ' ') -ne '--install --distribution archlinux --no-launch') { throw 'Unexpected install arguments' }
            if ($global:distroInstalled -or !$global:defaultVersionSet) { throw 'Distro must only be installed when absent, using WSL 2' }
            if ($case -eq 'install-fail') { $global:LASTEXITCODE = 1; return }
            $global:distroInstalled = $true
        }
        '--list' {
            if (($args -join ' ') -ne '--list --all --quiet') { throw 'Unexpected list arguments' }
            if ($case -eq 'list-fail') { $global:LASTEXITCODE = 1; return }
            if ($global:distroInstalled) { return ('A' + [char]0 + 'r' + [char]0 + 'c' + [char]0 + 'h') }
            return ([string][char]0)
        }
        '--set-default-version' {
            if ($args[1] -ne '2' -or $global:distroInstalled) { throw 'Do not change existing distributions' }
            if ($case -eq 'version-fail') { $global:LASTEXITCODE = 1; return }
            $global:defaultVersionSet = $true
        }
        '--user' {
            if ($args[3] -eq 'bash') {
                if ($args[4] -ne '-c' -or $args[5] -notlike '*$ID == arch*first-setup.sh*') { throw 'Unexpected first-login setup' }
                if ($case -eq 'first-login-fail') { $global:LASTEXITCODE = 1 }
                return
            }
            if (($args -join ' ') -ne '--user root --exec uname -r') { throw 'Root is only allowed for the kernel probe' }
            if ($case -eq 'launch-fail') { $global:LASTEXITCODE = 1; return }
            if ($case -eq 'wsl1') { return '4.4.0-Microsoft' }
            return '6.6.87.2-microsoft-standard-WSL2'
        }
        '--exec' {
            if ($args[1] -ne 'wslpath' -or $args[3] -ne $expectedCheckout) { throw 'Incorrect Windows path argument' }
            if ($case -eq 'path-fail') { $global:LASTEXITCODE = 1; return }
            return "/mnt/c/Users/O'Brien dotfiles"
        }
        '--cd' {
            if ($args.Count -ne 6 -or $args[4] -ne "/mnt/c/Users/O'Brien dotfiles/scripts/bootstrap-wsl.sh" -or $args[5] -ne "/mnt/c/Users/O'Brien dotfiles") { throw 'Incorrect WSL argv' }
            if ($env:WSLENV -notlike '*CHEZMOI_GITHUB_ACCESS_TOKEN/u*') { throw 'Missing WSL environment forwarding' }
            if ($case -eq 'apply-fail') { $global:LASTEXITCODE = 17 }
        }
        default { throw 'Unexpected WSL command' }
    }
}
foreach ($case in @('ok', 'fresh', 'engine-fail', 'reboot', 'list-fail', 'version-fail', 'install-fail', 'launch-fail', 'wsl1', 'first-login-fail', 'path-fail', 'apply-fail')) {
    $wslCalls = [Collections.Generic.List[string]]::new()
    $global:distroInstalled = $case -notin @('fresh', 'version-fail', 'install-fail')
    $global:defaultVersionSet = $false
    $env:WSLENV = 'EXISTING/p'
    $failure = ''
    try { & $entry } catch { $failure = $_.Exception.Message }
    $expected = switch ($case) {
        'ok' { '^$' }; 'fresh' { '^$' }; 'engine-fail' { 'WSL setup did not complete' }; 'reboot' { 'restart Windows' }
        'list-fail' { 'Cannot list' }; 'version-fail' { 'Cannot enable WSL 2' }; 'install-fail' { 'Arch installation failed' }
        'first-login-fail' { 'first-login setup failed' }
        'launch-fail' { 'Cannot start' }
        'wsl1' { 'must use WSL 2' }; 'path-fail' { 'Cannot access' }; 'apply-fail' { 'exit code 17' }
    }
    if ($failure -notmatch $expected) { throw "Case $case failed: $failure" }
    if ($env:WSLENV -ne 'EXISTING/p') { throw 'WSLENV was not restored' }
    if ($case -notin @('ok', 'fresh', 'apply-fail') -and @($wslCalls | Where-Object { $_ -like '--cd *' }).Count) { throw 'Apply must not run after bootstrap failure' }
    if ($case -eq 'fresh') {
        & $entry
        if (@($wslCalls | Where-Object { $_ -eq '--install --distribution archlinux --no-launch' }).Count -ne 1) { throw 'Repeat entry reinstalled the distro' }
    }
}
`;
  execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-EncodedCommand', Buffer.from(check, 'utf16le').toString('base64')]);
}
console.log('WSL/native templates, shared WSL 2 bootstrap and syntax checks passed.');
