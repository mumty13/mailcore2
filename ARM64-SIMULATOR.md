# Native iOS Simulator package

This package branch starts directly at upstream commit `5fb0f93010ff7af426e72e9066db8cb19b8154be` (July 31, 2020). It excludes later upstream changes and the fork's custom source commits. The existing `src/`, `build-mac/`, upstream README and license are unchanged.

`Package.swift` exposes the existing `MailCore2` product and target from the checked-in `bin/MailCore2.xcframework.zip`; the framework module remains `MailCore`. New simulator binaries target arm64 and minimum iOS 15.0. The existing x86_64 simulator code/data is retained with a refreshed combined-framework signature.

The artifact preserves the original device framework's 217 files and macOS framework's 683 files byte-for-byte. All 213 public headers, provider data and 5,865 exported device symbols match the rebuilt arm64 simulator framework. The old binary contains no source revision, so this agreement does not prove its exact original implementation provenance. Details and dependency source versions are recorded in `binary-provenance.json`.

Treat the ZIP as immutable. Its SHA256 is recorded in `bin/SHA256SUMS` and the provenance file; changing it requires a new reviewed package commit. The preserved device binary SHA256 is `f1d17949bc6445314b1d7a8cffc7d1d8a848077387f48c6b31a88f5e4d1f725f`.

To rebuild a candidate on an Apple silicon Mac with Xcode 27.1 selected:

```bash
bash Rebuild/build.sh
```

The portable recipes download pinned sources, apply the recorded compatibility patches, build only the simulator slice and verify that the original device/macOS framework trees remain unchanged. They write an unpacked candidate to `Rebuild/output/MailCore2.xcframework`; they do not replace the committed ZIP. Before updating `bin/`, package the candidate with `MailCore2.xcframework` at the ZIP root, rerun platform/API/device-preservation checks, then update both checksum records. Dependency license notices are retained in `Notices/`.
