# Deployment

## Prerequisites

- Cloudflare account (free tier works for low volume)
- `wrangler` CLI installed (`npm i -g wrangler`)
- Flutter 3.24+ (stable)
- `dart_eval` CLI (`dart pub global activate dart_eval`)

## Deploy the Worker

### 1. Create resources

```bash
cd packages/roitelet_worker

# Create D1 database
wrangler d1 create roitelet
# Note the database_id

# Create R2 bucket
wrangler r2 bucket create roitelet-patches

# Create KV namespace
wrangler kv namespace create ROITELET_META
# Note the id
```

### 2. Update wrangler.toml

Replace the placeholder IDs in `wrangler.toml` with the values from step 1:

```toml
[[d1_databases]]
binding = "DB"
database_name = "roitelet"
database_id = "YOUR_D1_DATABASE_ID"

[[kv_namespaces]]
binding = "ROITELET_META"
id = "YOUR_KV_NAMESPACE_ID"
```

### 3. Apply database migration

```bash
wrangler d1 migrations apply roitelet --remote
```

### 4. Set secrets

```bash
# Master key for app registration (generate a strong random value)
echo -n "$(openssl rand -hex 32)" | wrangler secret put ADMIN_KEY

# Public base URL where the Worker is reachable
echo -n "https://your-patches.workers.dev" | wrangler secret put PUBLIC_BASE
```

### 5. Deploy

```bash
wrangler deploy
```

### 6. Verify

```bash
curl -s -o /dev/null -w "%{http_code}" https://your-patches.workers.dev/v1/test/manifest/1.0.0
# Expected: 204
```

## Register an app

```bash
# Generate a per-app admin key
APP_ADMIN_KEY=$(openssl rand -hex 32)

# Register the app via the super-admin endpoint
curl -X POST https://your-patches.workers.dev/admin/apps \
  -H "Authorization: Bearer YOUR_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"app_id\": \"my-app\",
    \"name\": \"My App\",
    \"pubkey\": \"YOUR_PUBKEY_FROM_ROITELET_INIT\",
    \"admin_key\": \"$APP_ADMIN_KEY\"
  }"

# Store APP_ADMIN_KEY in your CI secrets
```

## Integrate with your Flutter app

### 1. Add dependencies

```yaml
dependencies:
  roitelet_client:
    path: /path/to/roitelet/packages/roitelet_client
  flutter_eval:
    path: /path/to/roitelet/packages/flutter_eval
  eval_annotation: ^0.8.1
```

### 2. Initialize roitelet in your app

```bash
cd my_flutter_app
dart /path/to/roitelet_cli/bin/roitelet.dart init \
  --app-id my-app \
  --worker-url https://your-patches.workers.dev \
  --release-version 1.0.0
```

This generates `roitelet.yaml` and `roitelet_private.key`. Add the private key to `.gitignore` and store it in your CI secrets.

### 3. Wrap your app

```dart
import 'package:roitelet_client/roitelet.dart';

void main() => runApp(
  RoiteletRoot(
    config: RoiteletConfig(
      appId: 'my-app',
      releaseVersion: '1.0.0',
      manifestUrl: 'https://your-patches.workers.dev/v1/my-app/manifest/1.0.0',
      pubkeyBase64: 'YOUR_PUBKEY',
    ),
    child: MyApp(),
  ),
);
```

### 4. Wrap screens in HotSwap

```dart
import 'package:flutter_eval/flutter_eval.dart';
import 'package:flutter_eval/widgets.dart';

class CriticalScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HotSwap(
      id: '#critical_screen',
      args: const [],
      childBuilder: (_) => _buildOriginalUI(),
    );
  }
}
```

### 5. Create a hot_update package

```bash
flutter create --template=package hot_update
cd hot_update && flutter pub add eval_annotation
mkdir -p .dart_eval/bindings
# Generate bindings from the flutter_eval fork:
cd ../packages/flutter_eval && flutter test test/gen_bindings_test.dart
cp .dart_eval/bindings/flutter_eval.json ../../hot_update/.dart_eval/bindings/
```

Write override functions:

```dart
// hot_update/lib/main.dart
import 'package:eval_annotation/eval_annotation.dart';
import 'package:flutter/material.dart';

@RuntimeOverride('#critical_screen')
Widget criticalScreenPatched() {
  return Scaffold(
    body: Center(child: Text('Temporarily unavailable')),
  );
}
```

### 6. Push a patch

```bash
cd hot_update && dart_eval compile -o patch.evc

ROITELET_ADMIN_KEY=$APP_ADMIN_KEY \
dart /path/to/roitelet_cli/bin/roitelet.dart patch \
  --hot-update-dir . --patch-number 1
```

### 7. Rollback

```bash
# Upload an empty patch (no overrides) to restore original UI
ROITELET_ADMIN_KEY=$APP_ADMIN_KEY \
dart /path/to/roitelet_cli/bin/roitelet.dart patch \
  --hot-update-dir . --patch-number 2
```

## CI integration

Add to your CI pipeline after each build:

```bash
ROITELET_ADMIN_KEY=$ROITELET_ADMIN_KEY \
dart /path/to/roitelet_cli/bin/roitelet.dart patch \
  --hot-update-dir hot_update \
  --patch-number $BUILD_NUMBER
```

Store `ROITELET_ADMIN_KEY` as a CI secret. The `roitelet_private.key` should also be a CI secret for signing patches.