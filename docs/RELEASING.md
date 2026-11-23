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
2. Run one command:

   ```bash
   tools/release.sh <version>
   ```

   It checks that the release is ready (changelog entry, clean `main` up to date with GitHub, no release
   with that version yet, the update key, `gh` signed in), then sets the version, builds, notarizes and
   staples, zips with `ditto`, writes `appcast.xml` signed with the update key, and updates the README's
   badge and zip names. It then shows what it will publish and asks. On yes it creates the GitHub release
   `v<version>` with the zip and its sha256, commits and pushes `Info.plist.in`, `CHANGELOG.md`,
   `README.md`, and `appcast.xml`, bumps `Casks/kakeibo.rb` in `hammadmo/homebrew-tap`, and checks that the
   live feed shows the version and that the download matches its checksum.

   - `--dry-run`: only the checks.
   - `--local`: build, notarize, zip, and appcast; nothing leaves the Mac.
   - `--yes`: publish without asking. Without a terminal it never publishes unless `--yes` is given.
   - `TAP_DIR=<path>`: the homebrew-tap checkout to use (default: a clone kept in
     `~/Library/Developer/Kakeibo/homebrew-tap`).

Installed copies find the new version within a day, or at once with Settings > About > Check for Updates….

Sparkle compares build numbers, which `build.sh` makes from the date and time, so a later build is always newer.
