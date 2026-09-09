#!/bin/bash
# Exercises install-statusline.sh against a throwaway HOME (Plan 3 Task 12). Never touches the real ~/.claude.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/chibideck-feed-test.XXXXXX")
trap 'rm -rf "$T"' EXIT
export HOME="$T"
mkdir -p "$T/.claude"
printf '#!/bin/bash\ninput=$(cat)\nprintf "%%s %%s" "$(printf %%s "$input" | jq -r .model.id)" "${sid:-unset}"\n' > "$T/.claude/statusline-command.sh"
chmod 755 "$T/.claude/statusline-command.sh"
printf '{"statusLine":{"type":"command","command":"bash ~/.claude/statusline-command.sh"}}\n' > "$T/.claude/settings.json"
FEED="$T/Library/Application Support/ChibiDeck/statusline"
fail() { echo "FAIL: $1"; exit 1; }

echo "--- dry run"
# Captured, not piped: `grep -q` exits at the match and the installer's next line ("(dry run: …)") would
# then die of SIGPIPE, which `pipefail` reports as a failed check.
DRY_OUT=$("$HERE/install-statusline.sh" --dry-run)
grep -q '^+.*chibideck-feed' <<<"$DRY_OUT" || fail "dry run shows no added hook line"
grep -q chibideck-feed "$T/.claude/statusline-command.sh" && fail "dry run wrote the file"

echo "--- install"
"$HERE/install-statusline.sh" --yes | grep -q '^installed' || fail "install"
[ "$(grep -c chibideck-feed "$T/.claude/statusline-command.sh")" = 1 ] || fail "hook line count"
sed -n '3p' "$T/.claude/statusline-command.sh" | grep -q chibideck-feed || fail "hook is not right after input=\$(cat)"
ls "$T/.claude/statusline-command.sh.bak-"* >/dev/null || fail "no backup"
[ "$(stat -f '%Lp' "$T/.claude/statusline-command.sh")" = 755 ] || fail "mode bits changed"

echo "--- idempotent"
"$HERE/install-statusline.sh" --yes | grep -q '^already installed' || fail "second install"

echo "--- the hook writes a feed file and the script still prints its line"
OUT=$(printf '{"session_id":"abc-123","model":{"id":"claude-fable-5-1"}}' | bash "$T/.claude/statusline-command.sh")
[ "$OUT" = "claude-fable-5-1 unset" ] || fail "statusline output changed or the hook leaked a variable: $OUT"
[ -f "$FEED/abc-123.json" ] || fail "no feed file"
[ "$(jq -r .session_id "$FEED/abc-123.json")" = "abc-123" ] || fail "feed content"
printf 'not json' | bash "$T/.claude/statusline-command.sh" >/dev/null 2>&1 || true
[ "$(ls "$FEED" | wc -l | tr -d ' ')" = 1 ] || fail "bad input created a file"

echo "--- uninstall"
"$HERE/install-statusline.sh" --uninstall --yes | grep -q '^removed' || fail "uninstall"
grep -q chibideck-feed "$T/.claude/statusline-command.sh" && fail "hook still present"
"$HERE/install-statusline.sh" --uninstall --yes | grep -q '^not installed' || fail "second uninstall"

echo "--- a CorsairDisplay-era hook line is replaced in place"
printf '#!/bin/bash\ninput=$(cat)\n( d="$HOME/Library/Application Support/CorsairDisplay/statusline"; mkdir -p "$d"; ) || true  # corsairdisplay-feed\necho done\n' > "$T/.claude/statusline-command.sh"
"$HERE/install-statusline.sh" --yes | grep -q '^installed' || fail "legacy install"
grep -q corsairdisplay-feed "$T/.claude/statusline-command.sh" && fail "legacy hook still present"
[ "$(grep -c chibideck-feed "$T/.claude/statusline-command.sh")" = 1 ] || fail "legacy: hook line count"
sed -n '3p' "$T/.claude/statusline-command.sh" | grep -q chibideck-feed || fail "legacy: hook not in the old line's place"
[ "$(wc -l < "$T/.claude/statusline-command.sh" | tr -d ' ')" = 4 ] || fail "legacy: line count changed"
"$HERE/install-statusline.sh" --uninstall --yes | grep -q '^removed' || fail "legacy uninstall"

echo "--- no statusLine"
printf '{}' > "$T/.claude/settings.json"
if "$HERE/install-statusline.sh" --yes >/dev/null 2>&1; then fail "expected exit 2"; fi

echo "--- missing anchor"
printf '{"statusLine":{"type":"command","command":"bash ~/.claude/statusline-command.sh"}}\n' > "$T/.claude/settings.json"
printf '#!/bin/bash\ncat >/dev/null\n' > "$T/.claude/statusline-command.sh"
set +e; "$HERE/install-statusline.sh" --yes >/dev/null 2>&1; RC=$?; set -e
[ "$RC" = 3 ] || fail "expected exit 3, got $RC"

echo "all install-statusline checks passed"
