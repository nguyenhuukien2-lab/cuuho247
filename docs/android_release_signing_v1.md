# Android release signing - verified 2026-10-16

Both apps use Kotlin Gradle scripts at `frontend/{customer_app,rescuer_app}/android/app/build.gradle.kts`.
Each script loads its own `android/key.properties` using Java Properties and
assigns a dedicated `release` signing configuration to the release build type.
Relative `storeFile` paths resolve from the app's `android` directory; the
provided files use absolute paths to the repository-root `release-key.jks`.
No password or alias value is embedded in source or recorded here.

Debug signing was not modified. Missing local signing configuration does not
fall back to debug credentials for a release build.

## Completed checks

- Keystore loading, configured private-key entry, both passwords and certificate
  validity verified successfully for both apps without printing credentials.
- Keystore and both `key.properties` files are ignored and untracked by Git;
  existing ignore rules already covered them, so no ignore edit was needed.
- Both release APK and AAB builds exited 0 for each app.
- Builds reused the audited production `config/supabase.dev.json` files and
  repository-local `.pub-cache`; no dependency update or Dart change was needed.
- APK verification: `apksigner verify --verbose --print-certs`, valid v2
  signatures, one signer, certificate matches the supplied keystore.
- APK alignment: `zipalign -c -P 16 -v 4`, PASS for both.
- AAB verification: `jarsigner -verify`, PASS for both. Independent Java JAR
  verification read every entry and checked all 403 non-META-INF payload
  entries per bundle against the expected signer. Required bundle metadata and
  base manifest are present.
- APK package IDs and versions verified: `vn.cuuho247.cuu_ho_247` and
  `vn.cuuho247.rescuer`, each versionName `1.0.0`, versionCode `1`.
- Decompressed secret scan: PASS, four artifacts and 1,589 archive entries.
  Tika's three MIME recognition strings in the Rescuer AAB are byte-identical
  to the previously reviewed APK resource; only exact signature tags are
  excluded from private-key marker detection.
- `git diff --check`: PASS. No deploy, commit or tag was performed.

Public signing certificate SHA-256:

```text
a5e5a9be3059fa8faaca9f56d5bcd2f46d92cd235c0c8da4f9e4c7405e2f2313
```

## Signed artifacts

All paths below are relative to `D:\DAndroidStudioProjects\flutter_app`.

| App | Format | Path | Bytes |
| --- | --- | --- | ---: |
| Customer | APK | `frontend/customer_app/build/app/outputs/flutter-apk/app-release.apk` | 59,748,597 |
| Customer | AAB | `frontend/customer_app/build/app/outputs/bundle/release/app-release.aab` | 57,782,505 |
| Rescuer | APK | `frontend/rescuer_app/build/app/outputs/flutter-apk/app-release.apk` | 57,440,194 |
| Rescuer | AAB | `frontend/rescuer_app/build/app/outputs/bundle/release/app-release.aab` | 56,276,440 |

SHA-256 values, in the same order:

```text
5ad48da58d93a6da4ef7096466fc310f46770fe6a899df11a6df794b88abf03b
c3667d694b0b3c88665664e66a6ca97e45f735acd9551f8941303fcef90dc702
1bb969e56cb9d023ec1e19dafa8588cbc6a40b5c46251a052304be5e928d07eb
960e66700b2aaf54926164be2058e469b366769f8ea561491f85eb98c5473b08
```

The earlier unsigned packaging snapshot under `release/v1.0.0` is preserved;
its APK names, manifest and checksums still describe that older snapshot.
Use the signed build paths above for these new artifacts. Backend production
readiness, Play Console acceptance and device smoke testing were not changed
or certified by this signing task.

Build logs and credential-free verification helpers remain in ignored `.tmp`.
The secret scanner was extended only to recognize the reviewed Tika resource
at its AAB path as well as its APK path.
