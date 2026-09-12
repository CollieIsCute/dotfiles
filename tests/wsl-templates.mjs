// Run with: node tests/wsl-templates.mjs (requires chezmoi and Bash).
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
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
for (const file of ['bootstrap-wsl.sh', 'bootstrap-wsl-user.sh']) {
  const script = readFileSync(`${repo}/scripts/${file}`, 'utf8');
  bashCheck(script);
  assert.ok(!script.includes('\r'));
}
// Run account logic with shell functions replacing every system mutation.
const userSetup = readFileSync(`${repo}/scripts/bootstrap-wsl-user.sh`, 'utf8');
const accountMocks = `
source() { ID=ubuntu; }
id() {
  if [[ $1 == -u ]]; then
    if [[ $# == 1 ]]; then echo 0; else echo "$TEST_UID"; fi
  else [[ $TEST_UID != new ]]; fi
}
apt-get() { :; }
useradd() { echo created; }
passwd() { echo prompted; }
chpasswd() { read -r entry; [[ $entry == 'newuser:test-password' ]]; echo password-set; }
visudo() { [[ $(< "$2") == 'newuser ALL=(ALL:ALL) ALL' ]]; }
install() { [[ $1 == -m && $2 == 0440 && $4 == /etc/sudoers.d/90-chezmoi-wsl-newuser ]]; echo sudo-configured; }
`;
for (const [uid, user, password, expected] of [
  ['new', 'newuser', 'test-password', 'created\npassword-set\nsudo-configured\n'],
  ['new', 'newuser', '', 'created\nprompted\nsudo-configured\n'],
  ['1000', 'newuser', 'test-password', 'sudo-configured\n'],
  ['999', 'newuser', '', null],
  ['new', 'root', '', null],
  ['new', 'bad;name', '', null],
  ['new', 'newuser', 'bad\npassword', null],
]) {
  const result = spawnSync('bash', ['-s', '--', user], { input: accountMocks + userSetup, encoding: 'utf8',
    env: { ...process.env, TEST_UID: uid, CHEZMOI_WSL_PASSWORD: password } });
  assert.ifError(result.error);
  if (expected === null) assert.notEqual(result.status, 0, 'Reject unsafe account input');
  else {
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, expected);
  }
}
const workflow = readFileSync(`${repo}/.github/workflows/test-distros.yaml`, 'utf8');
const windowsJob = workflow.split('\n  windows:')[1];
assert.ok(windowsJob.includes('& $chezmoi init collieiscute --branch "$env:CHEZMOI_BRANCH" --apply -v'));
assert.ok(!/bootstrap-wsl\.ps1|useradd|pacman|NOPASSWD|wsl --(?:install|manage|set-default)/.test(windowsJob),
  'CI must use the normal entry without pre-provisioning WSL or its user');
assert.ok((workflow.match(/chezmoi.* -v/g) ?? []).length >= 5, 'Keep verbose installation logs');
if (process.platform === 'win32') {
  // Exercise the actual shared bootstrap through the rendered chezmoi entry.
  const checkout = join(scratch, "O'Brien dotfiles");
  mkdirSync(join(checkout, 'scripts'), { recursive: true });
  for (const file of ['bootstrap-wsl.ps1', 'bootstrap-wsl-user.sh']) {
    copyFileSync(`${repo}/scripts/${file}`, join(checkout, 'scripts', file));
  }
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
            if ($args[1] -ne 'root' -or $args[2] -ne '--exec') { throw 'Unexpected root command' }
            switch ($args[3]) {
                'uname' {
                    if ($args[4] -ne '-r') { throw 'Unexpected kernel probe' }
                    if ($case -eq 'launch-fail') { $global:LASTEXITCODE = 1; return }
                    if ($case -eq 'wsl1') { return '4.4.0-Microsoft' }
                    return '6.6.87.2-microsoft-standard-WSL2'
                }
                'printenv' {
                    if ($args[4] -ne 'WSL_DISTRO_NAME') { throw 'Unexpected environment query' }
                    if ($case -eq 'distro-name-fail') { $global:LASTEXITCODE = 1; return }
                    return 'Arch Linux'
                }
                'wslpath' {
                    if ($args[5] -ne (Join-Path $expectedCheckout 'scripts/bootstrap-wsl-user.sh')) { throw 'Incorrect user bootstrap path' }
                    if ($case -eq 'user-path-fail') { $global:LASTEXITCODE = 1; return }
                    return "/mnt/c/Users/O'Brien dotfiles/scripts/bootstrap-wsl-user.sh"
                }
                'bash' {
                    if ($global:defaultUid -ne 0 -or $args.Count -ne 6 -or $args[4] -ne "/mnt/c/Users/O'Brien dotfiles/scripts/bootstrap-wsl-user.sh" -or $args[5] -ne 'newuser') { throw 'Incorrect user setup arguments' }
                    if ($env:WSLENV -notlike '*CHEZMOI_WSL_PASSWORD/u*') { throw 'Missing bootstrap input forwarding' }
                    if ($case -eq 'user-setup-fail') { $global:LASTEXITCODE = 1; return }
                    $global:userCreated = $true
                    return
                }
                default { throw 'Unexpected root command' }
            }
        }
        '--manage' {
            if (!$global:userCreated -or $args.Count -ne 4 -or $args[1] -ne 'Arch Linux' -or $args[2] -ne '--set-default-user' -or $args[3] -ne 'newuser') { throw 'Incorrect default user setup' }
            if ($case -eq 'default-user-fail') { $global:LASTEXITCODE = 1; return }
            $global:defaultUid = 1000
        }
        '--exec' {
            if (($args -join ' ') -eq '--exec id -u') {
                if ($case -eq 'uid-fail') { $global:LASTEXITCODE = 1; return }
                return [string]$global:defaultUid
            }
            if ($args[1] -ne 'wslpath' -or $args[3] -ne $expectedCheckout) { throw 'Incorrect Windows path argument' }
            if ($case -eq 'path-fail') { $global:LASTEXITCODE = 1; return }
            return "/mnt/c/Users/O'Brien dotfiles"
        }
        '--cd' {
            if ($global:defaultUid -eq 0) { throw 'Apply must use the configured non-root user' }
            if ($args.Count -ne 6 -or $args[4] -ne "/mnt/c/Users/O'Brien dotfiles/scripts/bootstrap-wsl.sh" -or $args[5] -ne "/mnt/c/Users/O'Brien dotfiles") { throw 'Incorrect WSL argv' }
            if ($env:WSLENV -notlike '*CHEZMOI_GITHUB_ACCESS_TOKEN/u*') { throw 'Missing WSL environment forwarding' }
            if ($case -eq 'apply-fail') { $global:LASTEXITCODE = 17 }
        }
        default { throw 'Unexpected WSL command' }
    }
}
foreach ($case in @('ok', 'fresh', 'engine-fail', 'reboot', 'list-fail', 'version-fail', 'install-fail', 'launch-fail', 'wsl1', 'uid-fail', 'invalid-user', 'distro-name-fail', 'user-path-fail', 'user-setup-fail', 'default-user-fail', 'path-fail', 'apply-fail')) {
    $wslCalls = [Collections.Generic.List[string]]::new()
    $global:distroInstalled = $case -notin @('fresh', 'version-fail', 'install-fail')
    $global:defaultVersionSet = $false
    $global:defaultUid = if ($case -in @('fresh', 'invalid-user', 'distro-name-fail', 'user-path-fail', 'user-setup-fail', 'default-user-fail')) { 0 } else { 1000 }
    $global:userCreated = $false
    $env:USERNAME = 'NewUser'
    $env:CHEZMOI_WSL_USER = if ($case -eq 'invalid-user') { 'root' } else { '' }
    $env:WSLENV = 'EXISTING/p'
    $failure = ''
    try { & $entry } catch { $failure = $_.Exception.Message }
    $expected = switch ($case) {
        'ok' { '^$' }; 'fresh' { '^$' }; 'engine-fail' { 'WSL setup did not complete' }; 'reboot' { 'restart Windows' }
        'list-fail' { 'Cannot list' }; 'version-fail' { 'Cannot enable WSL 2' }; 'install-fail' { 'Arch installation failed' }
        'uid-fail' { 'Cannot determine the default WSL user' }; 'invalid-user' { 'valid non-root Linux username' }
        'distro-name-fail' { 'Cannot determine the default WSL distribution' }; 'user-path-fail' { 'Cannot access the WSL user bootstrap' }
        'user-setup-fail' { 'WSL user setup failed' }; 'default-user-fail' { 'Cannot set the default WSL user' }
        'launch-fail' { 'Cannot start' }
        'wsl1' { 'must use WSL 2' }; 'path-fail' { 'Cannot access' }; 'apply-fail' { 'exit code 17' }
    }
    if ($failure -notmatch $expected) { throw "Case $case failed: $failure" }
    if ($env:WSLENV -ne 'EXISTING/p') { throw 'WSLENV was not restored' }
    if ($case -notin @('ok', 'fresh', 'apply-fail') -and @($wslCalls | Where-Object { $_ -like '--cd *' }).Count) { throw 'Apply must not run after bootstrap failure' }
    if ($case -eq 'fresh') {
        & $entry
        if (@($wslCalls | Where-Object { $_ -eq '--install --distribution archlinux --no-launch' }).Count -ne 1) { throw 'Repeat entry reinstalled the distro' }
        if (@($wslCalls | Where-Object { $_ -like '--user root --exec bash *' }).Count -ne 1) { throw 'Repeat entry recreated the user' }
    }
    if ($case -eq 'ok' -and $global:userCreated) { throw 'Existing default user was changed' }
}
`;
  execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned',
    '-Command', '& ([scriptblock]::Create([Console]::In.ReadToEnd()))'], { input: check });
}
console.log('WSL/native templates, shared WSL 2 bootstrap and syntax checks passed.');
