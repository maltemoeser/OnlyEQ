# Releasing OnlyEQ

Releases are built and signed by the GitHub Actions workflow in `.github/workflows/build.yml`. Sparkle 2 delivers them to installed copies through the appcast attached to the latest GitHub Release.

The Ed25519 signing key is stored in the macOS login Keychain under the account `maltemoeser.OnlyEQ` and, for the workflow, in the repository secret `SPARKLE_PRIVATE_KEY`. Never commit an exported private key. The public key is `SUPublicEDKey` in `Resources/Info.plist`. Losing the private key means every installed copy needs a manual reinstall, so keep a backup outside this machine.

For each release:

1. Increment both `CFBundleVersion` and `CFBundleShortVersionString` in `Resources/Info.plist`. Sparkle compares `CFBundleVersion`, so it must go up every time.
2. Add `release-notes/VERSION.md`. It becomes the GitHub release notes and is embedded in the appcast.
3. Merge to `main`, then tag and push:

   ```sh
   git tag v1.3.0 && git push fork v1.3.0
   ```

The workflow refuses a tag that does not match the Info.plist version. On success it publishes `OnlyEQ.app.zip` and `appcast.xml` as release assets. The app's feed URL is `https://github.com/maltemoeser/OnlyEQ/releases/latest/download/appcast.xml`, which GitHub redirects to the newest release, so nothing is committed back to `main`.

OnlyEQ is ad-hoc signed rather than Developer ID signed or notarized. The Sparkle signature authenticates updates; `scripts/install.sh` strips the quarantine flag for first installs.
