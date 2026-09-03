#!/bin/sh
set -eu

repo=${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
template=$repo/home/.chezmoitemplates/openwhispr_env

render() {
    printf %s "$1" | chezmoi execute-template --with-stdin -f "$template"
}

input='KEEP=value
DICTATION_KEY=F13
VOICE_AGENT_KEY=Control+F13
ACTIVATION_MODE=toggle'
expected='KEEP=value
DICTATION_KEY=Shift+F13
VOICE_AGENT_KEY=Meta+F13
ACTIVATION_MODE=push'

actual=$(render "$input")
test "$actual" = "$expected"
test "$(render "$actual")" = "$expected"
test "$(render '')" = 'DICTATION_KEY=Shift+F13
VOICE_AGENT_KEY=Meta+F13
ACTIVATION_MODE=push'
