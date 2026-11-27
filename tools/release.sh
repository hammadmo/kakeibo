#!/bin/zsh
# One command for a whole Kakeibo release:
#   1. checks that everything is ready (changelog entry, clean main, tools, keys)
#   2. sets the version, builds, notarizes, staples, and zips the app
#   3. writes appcast.xml, signed with the update key (account "kakeibo" in the
#      login Keychain), and updates the README's badge and zip names
#   4. after you confirm: creates the GitHub release with the zip, commits and
#      pushes Info.plist.in, CHANGELOG.md, README.md, and appcast.xml, and bumps
#      the Homebrew cask in hammadmo/homebrew-tap
#   5. checks the live feed and that the download matches its checksum
#
#   tools/release.sh 0.3             everything, asks before publishing
#   tools/release.sh 0.3 --yes       everything, without asking
#   tools/release.sh 0.3 --local     steps 1 to 3 only; nothing leaves this Mac
#   tools/release.sh 0.3 --dry-run   step 1 only
#
# Before: add "## 0.3" with its changes at the top of CHANGELOG.md (leave it
# uncommitted or commit it; nothing else may be uncommitted).
# TAP_DIR picks the homebrew-tap checkout (default: a clone it keeps in
# ~/Library/Developer/Kakeibo/homebrew-tap).
set -euo pipefail
here=${0:A:h:h}
repo=hammadmo/kakeibo
tap_repo=hammadmo/homebrew-tap
tap_dir=${TAP_DIR:-$HOME/Library/Developer/Kakeibo/homebrew-tap}
sparkle_bin="$HOME/Library/Developer/Kakeibo/build/artifacts/sparkle/Sparkle/bin"
dist="$HOME/Library/Developer/Kakeibo/dist"

version=${1:?usage: tools/release.sh <version> [--yes | --local | --dry-run]}
shift
mode=publish; confirm=ask
for arg in "$@"; do
  case $arg in
    --yes) confirm=yes ;;
    --local) mode=local ;;
    --dry-run) mode=dry ;;
    *) echo "unknown option $arg"; exit 2 ;;
  esac
done

step() { print -P "%B==> $*%b"; }
fail() { echo "release: $*" >&2; exit 1; }

# MARK: 1. Ready?

step "Checking that $version is ready"
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || fail "version must look like 0.3 or 1.0.1"
grep -q "^## $version\$" "$here/CHANGELOG.md" || fail "add '## $version' and its changes to the top of CHANGELOG.md first"
cd "$here"
[[ "$(git branch --show-current)" == main ]] || fail "release from main (now on $(git branch --show-current))"
dirty=$(git status --porcelain | grep -v ' CHANGELOG.md$' || true)
[[ -z "$dirty" ]] || fail "commit or stash these first:
$dirty"
[[ -x "$sparkle_bin/generate_appcast" ]] || fail "no Sparkle tools: run ./build.sh once"
"$sparkle_bin/generate_keys" --account kakeibo -p >/dev/null 2>&1 || fail "no update key \"kakeibo\" in the login Keychain"
if [[ $mode != local ]]; then
  command -v gh >/dev/null && gh auth status >/dev/null 2>&1 || fail "gh is not signed in: run gh auth login"
  git fetch -q origin main
  [[ "$(git rev-list --count HEAD..origin/main)" == 0 ]] || fail "main is behind origin/main: pull first"
  ! gh release view "v$version" --repo $repo >/dev/null 2>&1 || fail "GitHub already has a release v$version"
  ! git rev-parse -q --verify "refs/tags/v$version" >/dev/null || fail "the tag v$version already exists here"
  if [[ ! -d "$tap_dir/.git" ]]; then
    [[ $mode == dry ]] && echo "would clone $tap_repo to $tap_dir" || gh repo clone $tap_repo "$tap_dir" -- -q
  fi
  if [[ -d "$tap_dir/.git" ]]; then
    [[ -z "$(git -C "$tap_dir" status --porcelain)" ]] || fail "$tap_dir has uncommitted changes"
    git -C "$tap_dir" pull -q --ff-only
    [[ -f "$tap_dir/Casks/kakeibo.rb" ]] || fail "no Casks/kakeibo.rb in $tap_dir"
  fi
fi
if [[ $mode == dry ]]; then
  echo "ready: $version would be built, notarized, zipped, and $( [[ $mode == local ]] && echo kept local || echo published to $repo and $tap_repo )"
  exit 0
fi

# MARK: 2. Build, notarize, zip

step "Building and notarizing $version"
sed -i '' -E "s|(<key>CFBundleShortVersionString</key><string>)[^<]*|\1$version|" Info.plist.in
# The README's download badge and zip names follow the version.
sed -i '' -E -e "s|badge/download-[0-9.]+-|badge/download-$version-|" -e "s|alt=\"Download [0-9.]+\"|alt=\"Download $version\"|" \
  -e "s|Kakeibo-[0-9]+(\.[0-9]+)+\.zip|Kakeibo-$version.zip|g" README.md
# --open restarts Kakeibo, so the running copy is the one just installed (a copy left
# running on the old bundle fails its own update check).
./build.sh --notarize --open

mkdir -p "$dist"
# Keep only this version's zip: generate_appcast gives every zip it finds the same URL prefix.
find "$dist" -name 'Kakeibo-*.zip' -o -name 'Kakeibo-*.html' | while read -r old; do mv "$old" "$old.old"; done
zip="$dist/Kakeibo-$version.zip"
ditto -c -k --keepParent "/Applications/Kakeibo.app" "$zip"
sha=$(shasum -a 256 "$zip" | cut -d' ' -f1)
size=$(stat -f %z "$zip")

# MARK: 3. Appcast

step "Writing appcast.xml"
changes=$(awk -v v="## $version" '$0==v {on=1; next} /^## / && on {exit} on' CHANGELOG.md)
# The update window's notes: escape &, <, and > first, so changelog text never
# becomes markup; then `code` becomes <code>, and "- item" lines list items.
print -r -- "$changes" |
  sed -E -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
         -e 's/`([^`]+)`/<code>\1<\/code>/g' \
         -e 's/^- (.*)$/<li>\1<\/li>/' |
  { echo "<ul>"; grep "<li>"; echo "</ul>"; } > "$dist/Kakeibo-$version.html"
"$sparkle_bin/generate_appcast" --account kakeibo --maximum-deltas 0 \
  --download-url-prefix "https://github.com/$repo/releases/download/v$version/" -o appcast.xml "$dist"
grep -q "v$version/Kakeibo-$version.zip\" length=\"$size\"" appcast.xml || fail "appcast.xml has no entry for this zip"

echo
echo "Kakeibo $version is built: $zip"
echo "sha256: $sha"
if [[ $mode == local ]]; then
  echo "Local only: nothing was uploaded, committed, or pushed."
  exit 0
fi

# MARK: 4. Publish

if [[ $confirm != yes ]]; then
  [[ -t 0 ]] || fail "not publishing without a terminal to confirm; add --yes, or --local"
  echo
  echo "This will publish Kakeibo $version:"
  echo "  - GitHub release v$version on $repo with Kakeibo-$version.zip"
  echo "  - commit and push Info.plist.in, CHANGELOG.md, README.md, appcast.xml to $repo"
  echo "  - bump Casks/kakeibo.rb in $tap_repo and push"
  read -r "answer?Publish? [y/N] "
  [[ "$answer" == [yY]* ]] || { echo "Not published. The build and appcast.xml are ready here; run again with --yes, or revert with git checkout ."; exit 1; }
fi

step "Creating the GitHub release v$version"
notes=$(mktemp)
{ print -r -- "$changes"; echo
  echo "Signed with Developer ID and notarized by Apple. Requires an Apple silicon Mac with macOS 26. Installed copies update themselves (Settings > About > Check for Updates…)."
  echo; echo "SHA-256 of Kakeibo-$version.zip: \`$sha\`"; } > "$notes"
gh release create "v$version" "$zip" --repo $repo --title "Kakeibo $version" --notes-file "$notes" --target main
rm -f "$notes"

step "Pushing the release files"
git add Info.plist.in CHANGELOG.md README.md appcast.xml
git commit -q -m "Release $version"
git push -q origin main

step "Bumping the Homebrew cask"
cask="$tap_dir/Casks/kakeibo.rb"
sed -i '' -E -e "s|^  version \"[^\"]*\"|  version \"$version\"|" -e "s|^  sha256 \"[0-9a-f]*\"|  sha256 \"$sha\"|" "$cask"
grep -q "version \"$version\"" "$cask" && grep -q "sha256 \"$sha\"" "$cask" || fail "could not update $cask"
if command -v brew >/dev/null; then brew style "$cask" >/dev/null || fail "brew style found problems in $cask"; fi
git -C "$tap_dir" add Casks/kakeibo.rb
git -C "$tap_dir" commit -q -m "kakeibo $version"
git -C "$tap_dir" push -q origin main

# MARK: 5. Check

step "Checking the live release"
feed="https://raw.githubusercontent.com/$repo/main/appcast.xml"
for i in {1..12}; do
  curl -fs "$feed?n=$RANDOM" | grep -q "v$version/Kakeibo-$version.zip" && break
  [[ $i == 12 ]] && fail "the feed does not show $version after 3 minutes: check $feed"
  sleep 15
done
check=$(mktemp)
curl -fsL -o "$check" "https://github.com/$repo/releases/download/v$version/Kakeibo-$version.zip"
[[ "$(shasum -a 256 "$check" | cut -d' ' -f1)" == "$sha" ]] || fail "the downloaded zip does not match $sha"
rm -f "$check"

echo
echo "Kakeibo $version is out:"
echo "  https://github.com/$repo/releases/tag/v$version"
echo "  feed and download checked; brew install --cask hammadmo/tap/kakeibo gets $version"
