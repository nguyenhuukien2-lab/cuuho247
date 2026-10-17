# Build & Release Packaging V1 - continuation

Date: 2026-10-16, Asia/Bangkok.

Status: packaging complete for the available unsigned release candidate.
READY TO TAG V1: **NO**. No deploy, commit, tag, dependency update, fake signing
credential, or application uninstall was performed.

## Recovered state and retained validation

The initial `git status --short` and `git diff --stat` showed 17 modified tracked
files (253 insertions, 26 deletions), plus existing untracked Monitoring,
Reconciliation, test-work and design-report files. All were preserved.
No `release/` directory existed at the start of this continuation.

Previous release work already completed the audit, config review, version
alignment for the Android apps, signing review, and the checks below. The
previous session transcript was inspected in addition to older gate logs.

| Check | Recovered result | Continuation action |
| --- | --- | --- |
| Customer analyze | PASS, zero issues | Retained; no Dart changes |
| Customer tests | PASS, 613 tests | Retained; no Dart changes |
| Customer release APK | PASS, 2329.7 seconds | Reused existing artifact; version and signature checked |
| Rescuer analyze | PASS, zero issues | Retained; no Dart changes |
| Rescuer tests | PASS, 207 tests | Retained; no Dart changes |
| Rescuer release APK | APK already present | Verbose rebuild PASS, exit 0 |
| Admin lint | PASS, existing temporary-work warning | Rechecked, exit 0 |
| Admin production build | PASS | Rebuilt with explicitly validated production env, exit 0 |
| Admin Playwright | Earlier 84/84; later 83 passed, 1 failed | Only failed test rerun: 1 passed, exit 0 |
| Signing | Missing real release configuration | Independently verified both APKs unsigned |
| Secret scan | Earlier audit passed | Fresh source, bundle and decompressed APK scan passed |

Current Playwright discovery confirms 84 tests in four files. Its last-run
record is now `passed`, with an empty failed-test list. This does not represent
a newly executed 84-test full run: 83 prior successes plus the successful retry
are retained. No product-code fix or timeout increase was necessary.

## Actual failure diagnosis

No `assembleRelease` failure is reproduced or supported by the recovered final
build evidence. Customer had already finished successfully. Rescuer's verbose
rebuild reports `:app:assembleRelease`, `BUILD SUCCESSFUL in 2m 29s`, 333
actionable tasks (18 executed, 315 up-to-date), and exit code 0.

The recovered `1 failed` belongs to Admin Playwright:

- Test: `responsive settings and fixed save bar at 1440px`.
- File: `admin_web/tests/system-config.spec.ts:187:68`.
- Error: `locator.click: Test timeout of 30000ms exceeded`, waiting for the
  Customer tab while `/settings` navigation finished.
- Rerun: `npx.cmd playwright test --last-failed`; PASS, test 3.3 seconds,
  total 14.4 seconds, exit code 0.

A separate earlier **debug** build failed during Gradle project configuration:
`:shared_preferences_android` referenced inaccessible/missing
`D:\FlutterCache\Pub\hosted\pub.dev\shared_preferences_android-2.4.28\android`.
Evidence: `D:\Android\Gradle\daemon\9.3.1\daemon-20024.out.log:746`, 10:24:12.
That cache problem had already been resolved by the previous session. Both app
package configurations now use the existing repository-local `.pub-cache`.
The verbose release rebuild preserved that cache using a process-local
`PUB_CACHE` setting. No dependency version or plugin implementation changed.

Restricted native access, Kotlin Gradle plugin and Gradle deprecation warnings
were nonfatal. There is no release compiler/resource exception or file/line to
report from the successful build.

## Production configuration

PASS for the packaged frontend configuration. Both actual Flutter input files
are `frontend/{customer_app,rescuer_app}/config/supabase.dev.json`. Their names
are misleading, but their inspected contents contain exactly `SUPABASE_URL`
and `SUPABASE_PUBLISHABLE_KEY`.

- URL: `https://mqnnzobfzbtolvmatuwr.supabase.co`.
- Project ref matches both the linked-project metadata and project-ref file
  under `backend/supabase/.temp` (linked project name: `cuuho24/7`).
- Keys have the public `sb_publishable_` format. Values are withheld here.
- Neither file contains service-role/private keys, localhost endpoints,
  database credentials, SePay test scope or unrelated defines.
- Admin `.env` URL/key were validated against the same production config;
  those values were explicitly supplied to the production build process.
- Actual Admin bundle and decompressed APKs were scanned for unexpected
  Supabase projects, the Admin test endpoint and SePay test scope.

This is a frontend configuration audit, not a new live backend certification.
The previous session's read-only preflight confirmed `sepay_live`, but its final
production gate remained FAIL: reconciliation migration `202610170001` was
local-only and required private-data checks were incomplete. No live production
state was changed or newly certified by this packaging continuation.

## Signing, versions and device

SIGNING_NOT_CONFIGURED for both Android apps. No `key.properties`, keystore or
signing environment configuration was found in the inspected release inputs.
Both existing release Gradle blocks intentionally omit debug signing.
`apksigner verify` exits 1 for both: `DOES NOT VERIFY`,
`ERROR: Missing META-INF/MANIFEST.MF`.

APK metadata verifies versionName `1.0.0`, versionCode `1` for both package IDs.
Admin is a private web package with npm metadata `0.0.0`; it is explicitly
recorded rather than silently relabeled in source.

AAB builds were skipped because real release signing is not configured.
`D:\Android\Sdk\platform-tools\adb.exe devices` returned an empty device list.
PHONE INSTALL: NOT RUN. No `INSTALL_FAILED_*` occurred because installation was
not attempted; the unsigned APKs must be signed/rebuilt before device use.

## Security and artifact boundaries

The fresh scan checks production Dart/TypeScript sources, Admin dist and APK ZIP
entries after decompression. It detects known local private credential values
and their base64 encodings, private-key markers, Supabase secret keys,
service-role JWTs and other credential patterns, without printing values.
Scope and exact hashes are in `SOURCE_AND_BUNDLE_SCAN.json`.

Three private-key header matches in Rescuer's
`org/apache/tika/mime/tika-mimetypes.xml` were inspected. They are exact XML
MIME magic-signature tags, not keys; no complete key body is present. Only those
three exact tags are exempted. The remainder of the resource is still scanned.

Packaging copies only the two explicitly named unsigned APKs and zips the
Admin dist directory. No keystore, `key.properties`, password, environment
file, private config, temporary test work, raw build/session log or
`STITCH_DESIGN_REPORT` is included. SHA256SUMS covers all release files other
than the checksum file itself. The final package scan is recorded alongside
the release output at `release/v1.0.0-package-scan.json` to avoid self-reference.

## Remaining release blockers

1. Provision and wire authentic release signing outside Git; rebuild signed
   APKs/AABs and verify the intended certificates.
2. Clear the previously recorded production migration/schema-alignment and
   authenticated read-only preflight blockers through a separately authorized
   process. This task does not authorize deployment.
3. Connect a device for signed APK installation and release smoke testing.

The implementation, migrations and pre-existing test/design artifacts remain
uncommitted. Packaging does not make the production backend release-ready.

## Reproduction

From repository root, run `powershell -File tools/package_release_v1.ps1` after
the validated builds and source scan exist. It refuses to overwrite different
APK/ZIP artifacts and verifies them against the scan inventory.

For the diagnostic build, use Rescuer's directory and set `PUB_CACHE` to the
existing repository `.pub-cache`, then run:

```text
flutter build apk --release --dart-define-from-file=config/supabase.dev.json -v
```

Verbose evidence remains in ignored `.tmp/release-rescuer-verbose.log`; Admin
build and retry logs remain in `.tmp/release-admin-{build,retry}.log`.
