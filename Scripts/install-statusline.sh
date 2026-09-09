#!/bin/bash
# ChibiDeck statusline feed installer (spec 2026-09-07 Plan 3 §8.2).
#
# Adds one marked line after `input=$(cat)` in the Claude Code statusline script so that every statusline
# update is mirrored to "$HOME/Library/Application Support/ChibiDeck/statusline/<session_id>.json".
# Prints the diff and asks before writing anything. Idempotent. `--uninstall` removes the line again.
#
#   install-statusline.sh [--yes] [--dry-run] [--uninstall]
#
# Exit codes: 0 applied or already in the requested state, 1 declined, 2 no usable statusLine script,
# 3 anchor line missing (the hook line is printed for manual placement), 64 bad option.
set -u

MODE=install
YES=0
DRY=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) MODE=uninstall ;;
    --yes) YES=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 64 ;;
  esac
done

MARKER='# chibideck-feed'
LEGACY_MARKER='# corsairdisplay-feed'   # the hook line before the 2026-09-08 rename; replaced in place
FEED_DIR="$HOME/Library/Application Support/ChibiDeck/statusline"
SETTINGS="$HOME/.claude/settings.json"
HOOK=$(cat <<'HOOK_EOF'
( d="$HOME/Library/Application Support/ChibiDeck/statusline"; mkdir -p "$d"; sid=$(printf '%s' "$input" | jq -r '.session_id // empty'); [ -n "$sid" ] && printf '%s' "$input" > "$d/.$sid.$$.tmp" && mv -f "$d/.$sid.$$.tmp" "$d/$sid.json"; ) >/dev/null 2>&1 || true  # chibideck-feed
HOOK_EOF
)

command -v jq >/dev/null 2>&1 || { echo "jq is required by the hook and is not installed (brew install jq)" >&2; exit 2; }
[ -f "$SETTINGS" ] || { echo "no $SETTINGS; configure a statusLine in Claude Code first" >&2; exit 2; }
CMD=$(jq -r '.statusLine.command // empty' "$SETTINGS" 2>/dev/null)
[ -n "$CMD" ] || { echo "$SETTINGS has no statusLine.command; add one first (see the 2026-09-06 spec §5.2)" >&2; exit 2; }
SCRIPT=""
TOKENS=()                       # bash 3.2 leaves the array unset for a whitespace-only command, and `set -u` would abort
read -ra TOKENS <<<"$CMD"
for tok in "${TOKENS[@]}"; do
  case "$tok" in
    *.sh) SCRIPT="${tok/#\~/$HOME}"; break ;;
  esac
done
if [ -z "$SCRIPT" ] || [ ! -f "$SCRIPT" ]; then
  echo "statusLine.command ($CMD) does not name a readable .sh file; add the hook by hand after the line that reads stdin:" >&2
  echo "$HOOK" >&2
  exit 2
fi

if [ "$MODE" = install ]; then
  if grep -qF "$MARKER" "$SCRIPT"; then
    echo "already installed in $SCRIPT"
    mkdir -p "$FEED_DIR"
    exit 0
  fi
  if grep -qF "$LEGACY_MARKER" "$SCRIPT"; then
    PROPOSED=$(awk -v hook="$HOOK" -v legacy="$LEGACY_MARKER" 'index($0, legacy) { print hook; next } { print }' "$SCRIPT")
  elif ! grep -qE '^input=\$\(cat\)' "$SCRIPT"; then
    echo "no 'input=\$(cat)' line in $SCRIPT; add this line right after the one that reads stdin:" >&2
    echo "$HOOK" >&2
    exit 3
  else
    PROPOSED=$(awk -v hook="$HOOK" 'BEGIN { done = 0 } { print } !done && /^input=\$\(cat\)/ { print hook; done = 1 }' "$SCRIPT")
  fi
else
  if ! grep -qF "$MARKER" "$SCRIPT" && ! grep -qF "$LEGACY_MARKER" "$SCRIPT"; then
    echo "not installed in $SCRIPT"
    exit 0
  fi
  PROPOSED=$(grep -vF "$MARKER" "$SCRIPT" | grep -vF "$LEGACY_MARKER")
fi

diff -u -L "$SCRIPT (current)" -L "$SCRIPT (proposed)" "$SCRIPT" <(printf '%s\n' "$PROPOSED") || true
if [ "$DRY" = 1 ]; then
  echo "(dry run: nothing written)"
  exit 0
fi
if [ "$YES" != 1 ]; then
  printf 'Apply? [y/N] '
  read -r answer
  case "$answer" in
    y|Y) ;;
    *) echo "not applied"; exit 1 ;;
  esac
fi

BACKUP="$SCRIPT.bak-$(date +%Y%m%d-%H%M%S)"
# Every step below is checked: a full disk (or any other failure) must not leave a truncated backup, a
# truncated temp file, or a half-replaced script. `mv` is the only step that touches "$SCRIPT", and it runs
# only once the backup and the new text are both complete on disk.
abort() { echo "$1; $SCRIPT is unchanged" >&2; [ -n "${TMP:-}" ] && rm -f "$TMP"; exit 2; }
cp -p "$SCRIPT" "$BACKUP" || abort "backup to $BACKUP failed; nothing written"
TMP=$(mktemp "$SCRIPT.tmp.XXXXXX") || abort "could not create a temp file beside $SCRIPT"
printf '%s\n' "$PROPOSED" > "$TMP" || abort "writing $TMP failed"
MODE_BITS=$(stat -f '%Lp' "$SCRIPT") || abort "could not read the mode bits of $SCRIPT"
chmod "$MODE_BITS" "$TMP" || abort "could not set mode $MODE_BITS on $TMP"
mv -f "$TMP" "$SCRIPT" || abort "replacing $SCRIPT failed"
mkdir -p "$FEED_DIR"
find "$FEED_DIR" -name '*.json' -mmin +1440 -delete 2>/dev/null
if [ "$MODE" = install ]; then
  echo "installed: $SCRIPT (backup: $BACKUP)"
else
  echo "removed: $SCRIPT (backup: $BACKUP)"
fi
