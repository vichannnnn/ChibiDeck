#!/bin/bash
# Installs "build/Chibi Deck.app" to ~/Applications with a RunAtLoad LaunchAgent (spec 2026-09-07 Plan 3 §10.3).
#   Scripts/install.sh              build the app if build/ has none (Scripts/bundle.sh, ad-hoc unless IDENTITY is set), copy, write the LaunchAgent, start
#   Scripts/install.sh --build      build even if build/ already has an app
#   Scripts/install.sh --statusline  …then run the statusline feed installer (diff + y/N)
#   Scripts/install.sh --skills     …and copy the repo's Claude Code skills (.claude/skills/*) into ~/.claude/skills, skipping names already there
#   Scripts/install.sh --uninstall  stop, remove the LaunchAgent and the app copy (skills and the statusline hook stay)
#   Scripts/install.sh --dry-run    print what would happen and the LaunchAgent plist; touch nothing
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=me.himaa.chibideck
SRC="build/Chibi Deck.app"
DEST="$HOME/Applications/Chibi Deck.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
SKILLS_SRC=.claude/skills
SKILLS_DEST="$HOME/.claude/skills"
MODE=install
DRY=0
BUILD=0
STATUSLINE=0
SKILLS=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) MODE=uninstall ;;
    --dry-run) DRY=1 ;;
    --build) BUILD=1 ;;
    --statusline) STATUSLINE=1 ;;
    --skills) SKILLS=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 64 ;;
  esac
done

plist_body() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$DEST/Contents/MacOS/ChibiDeck</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<false/>
	<key>ProcessType</key>
	<string>Interactive</string>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
</dict>
</plist>
EOF
}

# A clone has no build/ yet: build the bundle first, while the installed app (if any) keeps running.
NEED_BUILD=0
[ "$MODE" = install ] && { [ "$BUILD" = 1 ] || [ ! -d "$SRC" ]; } && NEED_BUILD=1

# Skills are copied, not linked, so the clone can move or go; a name already in ~/.claude/skills is the user's and is left alone.
install_skills() {
  local dir name dest
  mkdir -p "$SKILLS_DEST"
  for dir in "$SKILLS_SRC"/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    name=$(basename "$dir")
    dest="$SKILLS_DEST/$name"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      echo "skill $name: $dest already exists, left alone"
    else
      cp -R "${dir%/}" "$dest"
      echo "installed skill $name to $dest"
    fi
  done
}

if [ "$DRY" = 1 ]; then
  [ "$NEED_BUILD" = 1 ] && echo "would build $SRC with Scripts/bundle.sh, signed as: ${IDENTITY:-- (ad-hoc)}"
  echo "would $MODE: app at $DEST, LaunchAgent at $PLIST (domain $DOMAIN)"
  [ "$SKILLS" = 1 ] && for dir in "$SKILLS_SRC"/*/; do
    [ -f "$dir/SKILL.md" ] && echo "would copy skill $(basename "$dir") to $SKILLS_DEST/$(basename "$dir") (unless it already exists)"
  done
  plist_body
  exit 0
fi

if [ "$NEED_BUILD" = 1 ]; then
  echo "building $SRC (Scripts/bundle.sh, signed as: ${IDENTITY:-- (ad-hoc)})"
  Scripts/bundle.sh
fi

# Plan 4 §8.5: ask nicely first so the burn index is flushed; pkill only if the app is still there after 5 s.
pgrep -x ChibiDeck >/dev/null && osascript -e 'tell application id "me.himaa.chibideck" to quit' >/dev/null 2>&1 || true   # never launch a stopped bundle just to quit it
for _ in $(seq 1 10); do pgrep -x ChibiDeck >/dev/null || break; sleep 0.5; done
pkill -x ChibiDeck 2>/dev/null || true
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true

# Rename of 2026-09-08: retire a CorsairDisplay install (old label, old app copy) if it is still there.
LEGACY_LABEL=me.himaa.corsairdisplay
LEGACY_PLIST="$HOME/Library/LaunchAgents/$LEGACY_LABEL.plist"
LEGACY_APP="$HOME/Applications/CorsairDisplay.app"
if [ -f "$LEGACY_PLIST" ] || [ -d "$LEGACY_APP" ] || pgrep -x CorsairDisplay >/dev/null; then
  pgrep -x CorsairDisplay >/dev/null && osascript -e "tell application id \"$LEGACY_LABEL\" to quit" >/dev/null 2>&1 || true
  for _ in $(seq 1 10); do pgrep -x CorsairDisplay >/dev/null || break; sleep 0.5; done
  pkill -x CorsairDisplay 2>/dev/null || true
  launchctl bootout "$DOMAIN/$LEGACY_LABEL" 2>/dev/null || true
  rm -f "$LEGACY_PLIST"
  rm -rf "$LEGACY_APP"
  echo "retired the old CorsairDisplay install ($LEGACY_APP, $LEGACY_PLIST)"
fi
# The 1.0.0 bundle was ~/Applications/ChibiDeck.app (no space) for a day; same bundle id, so only the copy goes.
[ -d "$HOME/Applications/ChibiDeck.app" ] && rm -rf "$HOME/Applications/ChibiDeck.app" && echo "removed ~/Applications/ChibiDeck.app (now Chibi Deck.app)"

if [ "$MODE" = uninstall ]; then
  rm -f "$PLIST"
  rm -rf "$DEST"
  echo "the statusline hook (if installed) stays; remove it with Scripts/install-statusline.sh --uninstall from a checkout"
  echo "removed $DEST and $PLIST"
  exit 0
fi

[ -d "$SRC" ] || { echo "no $SRC; run Scripts/bundle.sh first" >&2; exit 2; }
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$DEST"
ditto "$SRC" "$DEST"
plist_body > "$PLIST"
plutil -lint "$PLIST"
launchctl bootstrap "$DOMAIN" "$PLIST"
echo "installed $DEST; LaunchAgent $LABEL loaded and started"

[ "$SKILLS" = 1 ] && install_skills

if [ "$STATUSLINE" = 1 ]; then
  exec "$DEST/Contents/Resources/Scripts/install-statusline.sh"
fi
