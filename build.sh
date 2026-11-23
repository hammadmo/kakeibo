#!/bin/zsh
# Builds Kakeibo and installs it to ~/Applications/Kakeibo.app.
# Build products live in ~/Library/Developer/Kakeibo, outside the repo
# (and outside Dropbox or iCloud, which would try to sync them).
#
# Usage: ./build.sh            release build, install
#        ./build.sh --debug    debug build, install
#        ./build.sh --open     install, then quit the running copy and open the new one
#        ./build.sh --notarize also send the app to Apple's notary and staple the ticket.
#                              Needs a Developer ID certificate and a saved notary login.
#                              Uses the `hachibu` profile (same team) unless NOTARY_PROFILE is set:
#                              xcrun notarytool store-credentials kakeibo
set -euo pipefail
here=${0:A:h}
name="Kakeibo"
scratch="$HOME/Library/Developer/$name/build"
config=release
[[ " $* " == *" --debug "* ]] && config=debug

# Sign with Developer ID when there is one, like Hachibu: a stable signature
# keeps the Keychain "Always Allow" for Claude Code's login across rebuilds,
# and it can be notarized later. Then Apple Development, then ad hoc.
identity="${SIGN_IDENTITY:-}"
if [[ -z "$identity" ]]; then
  ids=$(security find-identity -v -p codesigning 2>/dev/null || true)
  identity=$(print -r -- "$ids" | grep -m1 -o '"Developer ID Application: [^"]*"' | tr -d '"' || true)
  [[ -n "$identity" ]] || identity=$(print -r -- "$ids" | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"' || true)
fi
[[ -n "$identity" ]] || identity=-

swift build -c $config --package-path "$here" --scratch-path "$scratch" 2>&1 | grep -E "error|warning|Build complete" | grep -v "^\[" || true
bin="$scratch/$config/$name"
[[ -x "$bin" ]] || { echo "build failed"; exit 1; }
# swift build can report success while an edited file failed to compile. Catch that.
stale=$(find "$here/Sources" -name '*.swift' -newer "$bin" | head -1)
if [[ -n "$stale" ]]; then
  echo "build failed: binary is older than $stale"
  swift build -c $config --package-path "$here" --scratch-path "$scratch" 2>&1 | grep -E "error" | head -20
  exit 1
fi

app="$HOME/Applications/$name.app"
mkdir -p "$HOME/Applications"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/$name"
# Sparkle (self-updates): the framework goes in Contents/Frameworks, and the
# binary looks for it there instead of in the build folder.
sparkle="$scratch/$config/Sparkle.framework"
[[ -d "$sparkle" ]] || { echo "build failed: no Sparkle.framework in $scratch/$config"; exit 1; }
mkdir -p "$app/Contents/Frameworks"
ditto "$sparkle" "$app/Contents/Frameworks/Sparkle.framework"
for rpath in $(otool -l "$app/Contents/MacOS/$name" | awk '/LC_RPATH/ { getline; getline; print $2 }'); do
  [[ "$rpath" == /* ]] && install_name_tool -delete_rpath "$rpath" "$app/Contents/MacOS/$name" 2>/dev/null
done
install_name_tool -add_rpath @executable_path/../Frameworks "$app/Contents/MacOS/$name" 2>/dev/null || true
sed -e "s/__BUILD__/$(date +%Y%m%d%H%M)/" "$here/Info.plist.in" > "$app/Contents/Info.plist"
# The icon: Icon/AppIcon.icon -> Resources/Assets.car + AppIcon.icns, rebuilt when it changed.
if [[ -d "$here/Icon/AppIcon.icon" ]]; then
  car="$here/Resources/Assets.car"
  if [[ ! -f "$car" || -n "$(find "$here/Icon/AppIcon.icon" -newer "$car" | head -1)" ]]; then
    "$here/tools/make_icon.sh"
  fi
  cp -X "$car" "$here/Resources/AppIcon.icns" "$app/Contents/Resources/"
fi
xattr -cr "$app"
signing=(codesign --force --sign "$identity")
if [[ "$identity" != - ]]; then
  signing+=(--options runtime)
  [[ "$identity" == "Developer ID"* ]] && signing+=(--timestamp)
fi
sign() {
  local out
  out=$("${signing[@]}" "$@" 2>&1) || { print -r -- "$out"; echo "signing ${@[-1]:t} failed"; exit 1; }
}
# Inside out: Sparkle's helpers, the framework, then the app.
sp="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
sign "$sp/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$sp/XPCServices/Downloader.xpc"
sign "$sp/Autoupdate"
sign "$sp/Updater.app"
sign "$app/Contents/Frameworks/Sparkle.framework"
sign "$app"
codesign --verify --deep --strict "$app" || { echo "the signed app did not verify"; exit 1; }
echo "installed $app (signed: ${identity})"
# The CLI: the app binary under a short name on PATH (bama agent-cli skill).
mkdir -p "$HOME/.local/bin"
ln -sf "$app/Contents/MacOS/Kakeibo" "$HOME/.local/bin/kakeibo"

if [[ " $* " == *" --notarize "* ]]; then
  [[ "$identity" == "Developer ID"* ]] || { echo "notarizing needs a Developer ID Application certificate"; exit 1; }
  profile="${NOTARY_PROFILE:-hachibu}"
  xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1 ||
    { echo "no notary login \"$profile\": run xcrun notarytool store-credentials $profile"; exit 1; }
  codesign --verify --strict "$app" || { echo "the signed app did not verify"; exit 1; }
  zip="$scratch/$name.zip"
  rm -f "$zip"
  ditto -c -k --keepParent "$app" "$zip"
  xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait
  xcrun stapler staple "$app"
  spctl --assess --type execute --verbose "$app"
  echo "notarized $app"
fi

if [[ " $* " == *" --open "* ]]; then
  osascript -e "quit app \"$name\"" 2>/dev/null || true
  sleep 0.5
  open "$app"
fi
