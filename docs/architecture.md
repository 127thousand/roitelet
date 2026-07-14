# Architecture

## Data flow

```
Developer                  Worker (Cloudflare)              Device
─────────                  ──────────────────              ──────

roitelet patch
  │
  ├─ dart_eval compile     ┌──────────────────┐
  │  → patch.evc           │  D1: apps table   │
  │                        │  (app_id, pubkey, │
  ├─ sign with ed25519     │   admin_key_hash) │
  │  (private key)         │                   │
  │                        │  R2:              │
  ├─ upload via HTTPS ──→  │   evc/<app>/      │
  │   (Bearer admin key)   │    <ver>/<n>.evc  │
  │                        │   manifest/<app>/ │
  │                        │    <ver>.json     │
  │                        └──────────────────┘
  │                                  │
  │                                  │ GET /v1/:app_id/manifest/:ver
  │                                  ↓
  │                          ┌──────────────┐
  │                          │  App launch   │
  │                          │              │
  │                          │ 1. Roitelet   │
  │                          │    .init()    │
  │                          │ 2. promote    │
  │                          │    pending→   │
  │                          │    current    │
  │                          │ 3. checkFor   │
  │                          │    Updates()  │
  │                          │    → download │
  │                          │    → verify   │
  │                          │    → cache    │
  │                          │ 4. HotSwap    │
  │                          │    Loader     │
  │                          │    loads .evc │
  │                          │ 5. HotSwap    │
  │                          │    calls      │
  │                          │    override   │
  │                          └──────────────┘
```

## Components

### roitelet_client (Flutter SDK)

- **`PatchManifest`**: data class for the manifest JSON (patch_number, evc_url, signature, hash, min_store_version)
- **`verifyPatch` / `verifyHash`**: ed25519 signature verification + SHA-256 hash check
- **`RoiteletStorage`**: on-disk cache for patch files + state.json (current/pending patch numbers) + blocklist.json (failed patches)
- **`RoiteletUpdater`**: checks manifest, downloads .evc, verifies, caches. Returns `UpdateResult` enum
- **`IoPatchHttpClient`**: real HTTP adapter for the updater (10s timeout)
- **`Roitelet`**: facade that wires storage + updater + path_provider
- **`RoiteletRoot`**: widget that wraps the app, boots Roitelet on init, promotes pending patches, wraps child in HotSwapLoader when a patch is current
- **`RoiteletLocalizations`**: loads signed JSON translation overrides, merges over bundled ARB

### roitelet_cli (Dart CLI)

- **`init`**: generates `roitelet.yaml` + ed25519 keypair
- **`patch`**: compiles hot_update package via `dart_eval compile`, signs, uploads to Worker
- **`rollback`**: re-uploads a prior patch at a new patch number (effective rollback)
- **`translate`**: signs and uploads a JSON translation override

### roitelet_worker (Cloudflare Worker)

- **D1 `apps` table**: per-app registry (app_id, name, pubkey, admin_key_hash, min_store_version)
- **R2 storage**: `.evc` files and manifest JSON, keyed by `app_id` + `release_version`
- **Endpoints**:
  - `GET /v1/:app_id/manifest/:release_version` — public, returns manifest or 204
  - `GET /v1/:app_id/evc/:release_version/:patch_number.evc` — public, returns binary
  - `POST /admin/v1/:app_id/patch` — per-app auth, accepts multipart upload
  - `POST /admin/v1/:app_id/translate` — per-app auth, accepts translation JSON
  - `POST /admin/apps` — super-admin auth, registers a new app
  - Translation endpoints under `/v1/:app_id/translations/...`

## Security model

- Every `.evc` is signed with ed25519. The private key stays on the developer machine / CI. The public key is baked into the app binary.
- The app verifies the signature before applying a patch. Even if the Worker is compromised, an attacker can't push code that runs (they don't have the private key).
- Admin API keys are per-app, stored as SHA-256 hashes in D1. The Worker never stores the raw key.
- The manifest endpoint is public (no auth). This is by design: the manifest contains no PII, and the `.evc` is signed so tampering is detected client-side.
- App registration (`POST /admin/apps`) requires a master key (Worker secret), separate from per-app admin keys.

## Patch lifecycle

1. **Launch N**: app checks manifest, downloads patch (if newer than current), verifies, caches as `pending`
2. **Launch N+1**: app promotes `pending` → `current`, `HotSwapLoader` loads the `.evc`, `HotSwap` widgets render the override
3. If a patch fails to launch, the app blocklists that patch number and refuses to apply it again (prevents crash loops)