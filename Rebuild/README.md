# Rebuild the simulator framework

On an Apple silicon Mac with Xcode 27.1 selected, run:

```bash
bash build.sh
```

The script downloads the pinned sources and original framework, verifies archive checksums, builds arm64 iOS Simulator dependencies with a minimum iOS version of 15.0, and writes an unpacked candidate to `output/MailCore2.xcframework`. It also creates an unpacked local package under `output/package`.

The invocation order is `prepare-mailcore`, `build-ctemplate-tidy`, `build-libetpan-sasl` (which calls `build-sasl`), `build-mailcore`, then `package-framework`. Each recipe is under `scripts/`; compatibility patches are under `patches/`. Download and build caches remain local and ignored.

The packager copies the original device and macOS frameworks and checks that both directories remain byte-identical. Only the simulator framework is rebuilt. Packaging refuses to overwrite an existing candidate; move `output/MailCore2.xcframework` aside before repackaging. These recipes do not replace the checked-in ZIP automatically.
