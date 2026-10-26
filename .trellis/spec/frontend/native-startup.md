# Native Startup and Flutter First Frame

## 1. Scope and Trigger

Read this before changing `lib/main.dart`, HarmonyOS `Index.ets`, the platform
channel in `EntryAbility.ets`, or shared `AppBootstrap`. The Lua shell follows
the native loading behavior in sibling `qfli_java` (JVMX).

## 2. Signatures

```dart
const MethodChannel('qflistudio/platform').invokeMethod<void>(
  'startupProgress',
  {'progress': progress},
);
```

`progress` is a finite number from 0 through 1. Native code clamps the value
and emits `EVENT_STARTUP_PROGRESS` through the ability's event hub. The splash
converts the fraction to the ArkUI progress bar's 0-through-100 scale.

## 3. Contracts

- Only native HarmonyOS defers the first engine frame. Other platforms keep
  the shared Flutter splash fallback.
- Native `FlutterPage.splashScreenView` contains the app icon and a linear
  progress bar. FlutterPage removes it on `onFirstFrame`, with an opacity
  transition. Progress reaching 1 is not the signal to remove the splash.
- Match JVMX's native icon presentation: 96vp square, `borderRadius(24)`, and
  `clip(true)`. Keep this product's own icon resource.
- Defer before `runApp`. Start local initialization after the first internal
  Flutter frame so the native surface can appear while the engine loads.
- The shared Flutter `SplashScreen` may exist in the internal widget tree
  during initialization. With engine frames deferred it is not composited
  onto the native surface; widget presence alone does not establish visible
  Flutter loading. Verify frame gating and native overlay removal together.
- Project/auth/settings loading reports completion fractions 1/3, 2/3 and 1.
  Individual configuration failures do not prevent home readiness.
- Preserve the reference shell's 1100ms minimum display, 160ms initial wait,
  and 320ms completion wait. Await `binding.endOfFrame` after home readiness
  and call `allowFirstFrame` in `finally` so errors cannot leave it deferred.
- Native window/page backgrounds use the existing light/dark surface colors.
  The splash subscribes on appearance and unsubscribes on disappearance.

## 4. Validation and Errors

| Condition | Outcome |
| --- | --- |
| Finite progress outside 0..1 | Clamp and acknowledge |
| Missing or nonfinite progress | Return `INVALID_PROGRESS` |
| Progress channel unavailable | Dart catches the platform/plugin error; startup continues |
| One local configuration fails | Bootstrap completes other loads and opens home |
| Startup completion throws | The first frame is released in `finally` |
| Splash disappears | Remove its exact progress listener |

## 5. Cases

- Base: launch with valid local data, show native progress, then render home.
- Good: a slow configuration load keeps the native surface visible until
  home is ready and laid out.
- Bad: treating progress 1 or a fixed timer as permission to remove the native
  surface can expose an engine background before Flutter has rendered.

## 6. Required Verification

- `test/startup_test.dart` calls the actual entry under the HarmonyOS platform
  override. Assert deferred engine frames, initial splash, progress fractions,
  home readiness before release, and home after release.
- Restore `debugDefaultTargetPlatformOverride` inside the test body, before
  Flutter's invariant check; ordinary teardown runs after that check.
- Shared `experience_test.dart` covers bootstrap configuration failure.
- Run app analysis/tests and a release arm64 HAP build. Inspect packaged
  ArkTS and matching `libapp.so`, `libflutter.so`, and `libqfli_lua.so` paths.
- Check the packaged `ets/modules.abc` against current loader output and the
  packaged icon against its source before blaming a cached or stale package.
- Device visual verification is separate from build/test verification.
  Respect the user's instruction to avoid device debugging or installation.

## 7. Wrong and Correct

Wrong: call `allowFirstFrame` immediately after `runApp`, or hide the native
splash when the progress bar is full.

Correct: keep the native splash bound to Flutter's actual first frame; allow
that frame only after local bootstrap and home layout have completed.
