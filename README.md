# roitelet

Self-hosted OTA code push for Flutter. Push UI patches to your app without waiting for App Store review.

Built on [flutter_eval](https://pub.dev/packages/flutter_eval), an open-source Dart bytecode interpreter for Flutter. Roitelet adds the distribution layer: a Cloudflare Worker for serving patches, ed25519 signing for integrity, a CLI for compile-and-upload, and a Flutter client that checks for updates on launch.

## How it works

```
Developer machine                Cloudflare Worker              User device
┌──────────┐    compile+sign    ┌──────────┐    fetch manifest ┌──────────┐
│  CLI     │ ────────────────── │  Worker   │ <───────────────  │  App     │
│          │    upload .evc     │  + R2     │                  │          │
└──────────┘                    └──────────┘    download .evc  │  verify  │
                                  ↑   ↑       ──────────────> │  sig     │
                                  │   │                        │  apply   │
                             D1 registry                       │  patch   │
                             (apps table)                      └──────────┘
```

1. **CLI** compiles Dart to `.evc` bytecode via `dart_eval`, signs it with ed25519, uploads to the Worker
2. **Worker** stores the `.evc` in R2, updates a manifest JSON with the patch number, signature, and hash
3. **App** checks the manifest on launch, downloads the `.evc`, verifies the signature against a public key baked into the binary, caches it on disk
4. On next launch, the app promotes the cached patch and `HotSwapLoader` loads it. `HotSwap` widgets render the patched UI instead of the original

## What it does

- **UI hotfixes**: replace a screen's widget tree with a patched version (e.g. hide a broken feature, show "temporarily unavailable")
- **Graceful degradation**: when an external dependency breaks, swap the UI that exposes it for a message instead of letting users hit errors
- **OTA translations**: push signed JSON translation overrides that merge over bundled ARB files and apply instantly, no restart needed

## What it doesn't do

- **Full code push**: the interpreter only swaps UI widgets. It cannot change your service layer, API calls, or business logic
- **Any widget**: `flutter_eval` supports a subset of Flutter's widget catalog (~60 widgets). Check the [supported widgets list](https://pub.dev/packages/flutter_eval#supported-widgets-and-classes)
- **Native code**: no Java/Kotlin/Swift changes. Pure Dart UI only
- **Zero performance impact**: patched code runs interpreted (10-50x slower than AOT). Fine for UI, not for hot loops

## Quick start

### 1. Deploy the Worker

```bash
cd packages/roitelet_worker
wrangler d1 create roitelet
wrangler r2 bucket create roitelet-patches
wrangler kv namespace create ROITELET_META
# Update wrangler.toml with the IDs from the above commands
wrangler d1 migrations apply roitelet --remote
echo -n "your-master-key" | wrangler secret put ADMIN_KEY
echo -n "https://your-patches.workers.dev" | wrangler secret put PUBLIC_BASE
wrangler deploy
```

### 2. Register your app

```bash
APP_ADMIN_KEY=$(openssl rand -hex 32)
curl -X POST https://your-patches.workers.dev/admin/apps \
  -H "Authorization: Bearer your-master-key" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\":\"my-app\",\"name\":\"My App\",\"pubkey\":\"YOUR_PUBKEY\",\"admin_key\":\"$APP_ADMIN_KEY\"}"
```

### 3. Install the CLI

```bash
dart pub global activate dart_eval
# Clone this repo, then:
cd packages/roitelet_cli && dart pub get
```

### 4. Initialize in your Flutter app

```bash
cd my_flutter_app
dart /path/to/roitelet_cli/bin/roitelet.dart init \
  --app-id my-app \
  --worker-url https://your-patches.workers.dev \
  --release-version 1.0.0
```

This generates two files:
- `roitelet.yaml` — config with your `app_id`, worker URL, and the **public key** (safe to commit)
- `roitelet_private.key` — the ed25519 private key (add to `.gitignore`, store in CI secrets)

Note the public key printed in the output, e.g. `Public key (bake into app): aBcDeF...=`. You'll use it in step 5.

### 5. Add roitelet to your app

```yaml
# pubspec.yaml
dependencies:
  roitelet_client:
    path: /path/to/roitelet/packages/roitelet_client
  flutter_eval:
    path: /path/to/roitelet/packages/flutter_eval
```

Wrap your app in `RoiteletRoot`:

```dart
import 'package:roitelet_client/roitelet.dart';

void main() => runApp(
  RoiteletRoot(
    config: RoiteletConfig(
      appId: 'my-app',
      releaseVersion: '1.0.0',
      manifestUrl: 'https://your-patches.workers.dev/v1/my-app/manifest/1.0.0',
      pubkeyBase64: 'YOUR_PUBKEY_FROM_INIT',
    ),
    child: MyApp(),
  ),
);
```

Wrap screens in `HotSwap`:

```dart
import 'package:flutter_eval/flutter_eval.dart';
import 'package:flutter_eval/widgets.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HotSwap(
      id: '#my_screen',
      args: const [],
      childBuilder: (_) => _buildOriginalUI(),
    );
  }
}
```

### 6. Push a patch

Create a `hot_update` package with override functions:

```dart
// hot_update/lib/main.dart
import 'package:eval_annotation/eval_annotation.dart';
import 'package:flutter/material.dart';

@RuntimeOverride('#my_screen')
Widget myScreenPatched() {
  return Scaffold(
    appBar: AppBar(title: const Text('Patched')),
    body: const Center(child: Text('updated via roitelet')),
  );
}
```

Compile and upload:

```bash
cd hot_update && dart_eval compile -o patch.evc
ROITELET_ADMIN_KEY=$APP_ADMIN_KEY dart /path/to/roitelet_cli/bin/roitelet.dart patch \
  --hot-update-dir . --patch-number 1
```

Users get the patch on next launch.

## OTA translations

Translations don't need the interpreter. They're just JSON data served from the same Worker, signed with the same ed25519 keypair. The app loads them on launch, merges them over the bundled ARB files, and applies instantly. No restart, no `.evc`, no `flutter_eval` runtime involved.

### How it works

```
hot_update/app_es.json  ──sign──>  Worker  ──serve──>  App
  {"hello": "Hola"}                                      │
                                                          ↓
                                          RoiteletLocalizationsDelegate
                                                          │
                                    merges over bundled app_es.arb
                                                          │
                                          AppLocalizations.reload()
                                                          │
                                          all screens update instantly
```

### Setup in your Flutter app

Your app already uses Flutter's standard `gen-l10n` with `AppLocalizations`. Roitelet adds a delegate that wraps the generated one and overlays JSON overrides:

1. Generate an override class from your ARB file:

```bash
# Run this script (included in example/tool/gen_override_class.dart)
# It reads app_en.arb and produces a class with one @override getter per key
dart tool/gen_override_class.dart lib/l10n/app_en.arb > lib/config/app_localizations_override.dart
```

2. Add the roitelet translations delegate to your `MaterialApp`:

```dart
import 'package:roitelet_client/roitelet.dart';
import 'config/roitelet_translations.dart';

// In _bootstrap, before runApp:
await RoiteletTranslations.init(
  manifestUrl: 'https://your-patches.workers.dev/v1/my-app/translations/manifest/1.0.0',
  pubkeyBase64: 'YOUR_PUBKEY',
);

// In MaterialApp:
localizationsDelegates: [
  const RoiteletLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
],
```

The `RoiteletLocalizationsDelegate` loads the base `AppLocalizations` via the standard generated delegate, then wraps it in `OverrideAppLocalizations` which checks the OTA override map for each key. If a key is overridden, the new string is used. If not, the bundled string is used. Plurals and parameterized messages are handled via `intl.MessageFormat`.

### Push a translation update

Create a JSON file with just the keys you want to override:

```json
// translations/es.json
{
  "appTitle": "Mi App",
  "welcomeMessage": "Bienvenido de vuelta",
  "doseReminder": "Es hora de tomar tu medicamento"
}
```

Sign and upload:

```bash
ROITELET_ADMIN_KEY=$APP_ADMIN_KEY \
dart /path/to/roitelet_cli/bin/roitelet.dart translate \
  --locale es \
  --file translations/es.json
```

Users on the next launch see the updated Spanish strings instantly across all screens. No App Store review, no binary update, no restart. Keys not included in the JSON file keep their bundled values.

## Using slang instead of gen-l10n

If your app uses [slang](https://pub.dev/packages/slang) for i18n instead of Flutter's built-in `gen-l10n`, roitelet has a dedicated integration that's even simpler. Slang has native `translation_overrides` support, so no override class generation is needed.

### Setup

1. Enable translation overrides in your slang config (`slang.yaml` or `build.yaml`):

```yaml
translation_overrides: true
```

2. Initialize roitelet slang overrides in your bootstrap:

```dart
import 'package:roitelet_client/roitelet.dart';
import 'path/to/strings.g.dart'; // your generated slang file

late RoiteletSlangOverrides roiteletSlang;

Future<void> _bootstrap() async {
  roiteletSlang = RoiteletSlangOverrides(
    manifestUrl: 'https://your-patches.workers.dev/v1/my-app/translations/manifest/1.0.0',
    pubkeyBase64: 'YOUR_PUBKEY',
  );
  await roiteletSlang.loadOverrides();

  // Apply each locale's overrides to slang
  await roiteletSlang.applyOverrides((locale, map) async {
    await LocaleSettings.overrideTranslationsFromMap(
      locale: AppLocale.valueOf(locale),
      isFlatMap: true,
      map: map,
    );
  });

  runApp(MyApp());
}
```

3. Push a translation update (same JSON format, flat map keys):

```json
{
  "mainScreen.title": "Hola",
  "login.success": "Inicio de sesion exitoso",
  "items(n=1)": "Tienes un elemento",
  "items(n=other)": "Tienes {n} elementos"
}
```

```bash
ROITELET_ADMIN_KEY=$APP_ADMIN_KEY \
dart /path/to/roitelet_cli/bin/roitelet.dart translate \
  --locale es --file translations/es.json
```

The overrides apply instantly. Slang handles plurals, linked translations, and L10n formatting internally. No restart needed, no generated override class, no `AppLocalizations` delegate swapping.

### What you can override

- Any string from your ARB files (simple getters)
- Plural messages (ICU format, e.g. `"{count, plural, =1{1 dose} other{{count} doses}}"`)
- Parameterized messages (e.g. `welcomeWithName`: `"Welcome, {name}"`)
- Any locale your app supports (add a new language by uploading a JSON for a new locale code)
- Copy fixes, tone changes, emergency corrections (e.g. fixing a misleading medication instruction)

## Project structure

```
roitelet/
├── packages/
│   ├── roitelet_client/    Flutter SDK: updater, verifier, storage, RoiteletRoot widget
│   ├── roitelet_cli/       Dart CLI: init, patch, rollback, translate
│   ├── roitelet_worker/    Cloudflare Worker: manifest, evc serving, admin upload, D1 registry
│   └── flutter_eval/       Fork of flutter_eval with bug fixes (see below)
├── example/                Sandbox app showing the full setup
└── docs/
    ├── architecture.md     Data flow, components, signing
    └── deployment.md       Worker setup, app registration, CI integration
```

## flutter_eval fork

This repo includes a fork of `flutter_eval` with three fixes not yet in the upstream:

1. **Container.isAntiAlias**: Flutter 3.32+ added `isAntiAlias` to `Container`. The wrapper class now implements it.
2. **URI path decoding**: `_loadFromFile` used `Uri.parse(uri).path` which doesn't decode `%20` in paths like `Application%20Support`. Fixed to use `Uri.parse(uri).toFilePath()`.
3. **HotSwap try/catch**: `HotSwap.build` now wraps `runtimeOverride` in try/catch so a broken override falls back to `childBuilder` instead of rendering Flutter's `ErrorWidget`.

The fork also includes a binding generator (`tool/gen_bindings.dart`) that produces `flutter_eval.json` from the vendored source via `BridgeSerializer`, ensuring the compiler's bridge indices match the runtime's.

## License

MIT. The `flutter_eval` fork retains its original BSD-3 license.