# Releasing Kakeibo

Kakeibo updates itself with [Sparkle](https://sparkle-project.org), like Hachibu.

- Feed: `appcast.xml` at the top of `github.com/hammadmo/kakeibo` (`SUFeedURL` in `Info.plist.in`).
- Downloads: the zip attached to each GitHub release `v<version>`.
- Update key: made once with `generate_keys --account kakeibo`. The private half lives only in the
  login Keychain; the public half is `SUPublicEDKey` in `Info.plist.in`. Every installed copy refuses
  an update not signed with it. **Back it up** (`generate_keys --account kakeibo -x <file>`, kept
  somewhere safe and private): without it no update can reach installed copies.

## Steps

1. Add `## <version>` with its changes at the top of `CHANGELOG.md`.
2. `tools/release.sh <version>`: sets the version, builds, notarizes and staples, zips with `ditto`,
   and writes `appcast.xml`, signed with the update key.
3. Create the GitHub release `v<version>` on `hammadmo/kakeibo` with the zip (put its sha256 in the notes).
4. Commit `Info.plist.in`, `CHANGELOG.md`, `README.md` (its badge and zip names follow the version), and `appcast.xml`, and push. Installed copies find it within a day,
   or at once with Settings > About > Check for Updates….

5. Bump `version` and `sha256` in `Casks/kakeibo.rb` in `hammadmo/homebrew-tap`, and push.

Sparkle compares build numbers, which `build.sh` makes from the date and time, so a later build is always newer.
