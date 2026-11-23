#!/bin/zsh
# Makes a Kakeibo release: sets the version, builds, notarizes, zips, and
# writes appcast.xml signed with the update key (account "kakeibo" in the
# login Keychain). It never uploads or pushes: those steps are printed.
#   tools/release.sh 0.2
# Before: add "## 0.2" with its changes at the top of CHANGELOG.md.
set -euo pipefail
here=${0:A:h:h}
version=${1:?usage: tools/release.sh <version>, like 0.2}
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "version must look like 0.2 or 1.0.1"; exit 1; }
grep -q "^## $version\$" "$here/CHANGELOG.md" || { echo "add '## $version' and its changes to CHANGELOG.md first"; exit 1; }

sed -i '' -E "s|(<key>CFBundleShortVersionString</key><string>)[^<]*|\1$version|" "$here/Info.plist.in"
# The README's download badge and zip names follow the version.
sed -i '' -E -e "s|badge/download-[0-9.]+-|badge/download-$version-|" -e "s|alt=\"Download [0-9.]+\"|alt=\"Download $version\"|" \
  -e "s|Kakeibo-[0-9]+(\.[0-9]+)+\.zip|Kakeibo-$version.zip|g" "$here/README.md"
"$here/build.sh" --notarize

dist="$HOME/Library/Developer/Kakeibo/dist"
mkdir -p "$dist"
# Keep only this version's zip: generate_appcast gives every zip it finds the same URL prefix.
find "$dist" -name 'Kakeibo-*.zip' -o -name 'Kakeibo-*.html' | while read -r old; do mv "$old" "$old.old"; done
zip="$dist/Kakeibo-$version.zip"
ditto -c -k --keepParent "$HOME/Applications/Kakeibo.app" "$zip"

# The version's changes, as HTML for the update window.
# Escape &, <, and > first, so changelog text never becomes markup; then
# `code` becomes <code>code</code>, and "- item" lines become list items.
awk -v v="## $version" '$0==v {on=1; next} /^## / && on {exit} on' "$here/CHANGELOG.md" |
  sed -E -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
         -e 's/`([^`]+)`/<code>\1<\/code>/g' \
         -e 's/^- (.*)$/<li>\1<\/li>/' |
  { echo "<ul>"; grep "<li>"; echo "</ul>"; } > "$dist/Kakeibo-$version.html"

"$HOME/Library/Developer/Kakeibo/build/artifacts/sparkle/Sparkle/bin/generate_appcast" --account kakeibo --maximum-deltas 0 \
  --download-url-prefix "https://github.com/hammadmo/kakeibo/releases/download/v$version/" -o "$here/appcast.xml" "$dist"

echo
echo "Kakeibo $version is ready: $zip"
echo "sha256: $(shasum -a 256 "$zip" | cut -d' ' -f1)"
echo "Next, by hand:"
echo "  1. Create the GitHub release v$version on hammadmo/kakeibo and attach Kakeibo-$version.zip"
echo "  2. Commit Info.plist.in, CHANGELOG.md, README.md, and appcast.xml, then push"
echo "  3. Bump version and sha256 in hammadmo/homebrew-tap Casks/kakeibo.rb"
