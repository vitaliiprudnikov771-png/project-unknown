# Repository and cloud build setup

Target repository: https://github.com/vitaliiprudnikov771-png/project-unknown

The source is being developed on the isolated branch `codex/project-bootstrap-0.9.0`. The default `main` branch is not changed by this work.

## Current repository visibility
The existing `project-unknown` repository is public. This project does not change repository visibility automatically. Keep only source that is safe to publish there; never commit secrets, personal information or private signing material.

## Android debug build
The workflow is `.github/workflows/android-debug.yml`. It is configured for pushes to `main` and manual dispatch. Once the source is reviewed and merged into `main`, pushes to `main` run the build automatically. For a branch test, use **Actions → Android Debug APK → Run workflow** and select `codex/project-bootstrap-0.9.0`.

Download artifact `project-unknown-android-debug` from the completed workflow run. It is a debug APK only. Each run uses a fresh temporary debug key, so uninstall an older debug build before installing a newer one.

## Safe release boundaries
- No production release keystore is configured.
- The workflow does not require Supabase secrets and does not deploy backend resources.
- The SQL migration and Edge Functions are source artifacts only until separately reviewed and deployed.
- Do not expose the unencrypted development ENet server publicly.
