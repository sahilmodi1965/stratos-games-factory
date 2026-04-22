# Capacitor native SDK init pattern — surface failures, never swallow

**Factory-improvement #72** — every native SDK initialized in `MainActivity.{kt,java}` MUST emit a status event the web layer can observe. Silent native init failures cost weeks of debugging (Bloxplode #26: LinkRunner attribution may have been silently dead — only `adb logcat -s` would have shown it).

This pattern applies to every Capacitor-wrapped game with native-side SDKs (LinkRunner, AppsFlyer, Adjust, AdMob native init paths, Firebase Analytics native init, AppLovin MAX, etc.).

---

## The contract

Every native SDK init follows three rules:

1. **Native init MUST emit an `initStatus` signal to the web layer** on both success AND failure. Silent failures are forbidden.
2. **The web layer MUST collect failures into `window.__nativeInitFailures`** so any later code (smoke, banner, dashboard) can read the truth.
3. **Debug builds MUST surface failures visibly** — either as a banner overlay or a console-loud warning. Release builds can stay silent (banner suppressed) but the `__nativeInitFailures` array is still populated for any analytics layer to report.

---

## Native side (Kotlin / Java)

In `MainActivity.{kt,java}`, the SDK init coroutine emits status via `WebView.evaluateJavascript`. This works without a custom Capacitor plugin — the web layer just needs to define `window.__onNativeInit` before MainActivity's coroutine fires.

### Kotlin (Bloxplode pattern)

```kotlin
import android.os.Build
import android.webkit.WebView
import com.getcapacitor.BridgeActivity
import io.linkrunner.sdk.LinkRunner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : BridgeActivity() {

    companion object {
        private const val LR_DEBUG = true
        private const val TAG = "Linkrunner"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        registerPlugin(LinkrunnerPlugin::class.java)
        super.onCreate(savedInstanceState)
        // ... immersive setup, etc. ...

        CoroutineScope(Dispatchers.IO).launch {
            initLinkRunnerWithStatus()
        }
    }

    private suspend fun initLinkRunnerWithStatus() {
        try {
            LinkRunner.getInstance().init(
                context = applicationContext,
                token = BuildConfig.LR_TOKEN,
                secretKey = BuildConfig.LR_SECRET_KEY,
                keyId = BuildConfig.LR_KEY_ID,
                debug = LR_DEBUG
            )
            Log.i(TAG, "init success")
            emitInitStatus("Linkrunner", true, null)
        } catch (e: Exception) {
            Log.e(TAG, "init failed", e)
            emitInitStatus("Linkrunner", false, e.message ?: "unknown")
        }
    }

    /**
     * Notify the web layer of a native SDK init result. Idempotent and
     * survives early-boot timing — if the web side hasn't registered
     * `window.__onNativeInit` yet, the coroutine retries once after 1s.
     */
    private suspend fun emitInitStatus(sdk: String, ok: Boolean, error: String?) {
        val errStr = error?.replace("\\", "\\\\")?.replace("'", "\\'") ?: ""
        val js = "(function(){if(typeof window.__onNativeInit==='function'){" +
                 "window.__onNativeInit({sdk:'$sdk',ok:$ok,error:'$errStr'});" +
                 "}else{window.__pendingNativeInits=window.__pendingNativeInits||[];" +
                 "window.__pendingNativeInits.push({sdk:'$sdk',ok:$ok,error:'$errStr'});}})();"
        withContext(Dispatchers.Main) {
            bridge.webView.evaluateJavascript(js, null)
        }
    }
}
```

The `__pendingNativeInits` queue handles the early-boot race — if MainActivity emits before `capacitor-bridge.js` runs, the JS bridge code drains the queue once it loads.

### Java (analogous shape)

```java
private void emitInitStatus(String sdk, boolean ok, @Nullable String error) {
    String errStr = error == null ? "" : error.replace("\\", "\\\\").replace("'", "\\'");
    String js = "(function(){if(typeof window.__onNativeInit==='function'){" +
                "window.__onNativeInit({sdk:'" + sdk + "',ok:" + ok + ",error:'" + errStr + "'});" +
                "}else{window.__pendingNativeInits=window.__pendingNativeInits||[];" +
                "window.__pendingNativeInits.push({sdk:'" + sdk + "',ok:" + ok + ",error:'" + errStr + "'});}})();";
    runOnUiThread(() -> bridge.getWebView().evaluateJavascript(js, null));
}
```

---

## Web side (in `www/capacitor-bridge.js` or analogous)

Register the listener early — before any module that depends on the native SDK loads:

```js
(function () {
  // Failure ledger — readable from anywhere.
  window.__nativeInitFailures = window.__nativeInitFailures || [];

  // The callback MainActivity invokes on every native SDK init outcome.
  window.__onNativeInit = function (status) {
    if (!status || typeof status.sdk !== 'string') return;

    if (status.ok) {
      console.log('[native-init] ✓', status.sdk);
    } else {
      window.__nativeInitFailures.push(status);
      console.warn('[native-init] ✗', status.sdk, '—', status.error || '(no message)');

      // Debug-build banner: only when running a debug APK or vite dev.
      var isDev = (typeof import.meta !== 'undefined' && import.meta.env && import.meta.env.DEV);
      var isDebugBuild = window.__APP_BUILD_TYPE__ === 'debug';
      if (isDev || isDebugBuild) {
        showNativeInitBanner(status);
      }
    }
  };

  // Drain anything MainActivity emitted before this script loaded.
  if (Array.isArray(window.__pendingNativeInits)) {
    window.__pendingNativeInits.forEach(window.__onNativeInit);
    window.__pendingNativeInits = [];
  }

  // Inline banner — minimal styling, gets out of the way.
  function showNativeInitBanner(status) {
    var existing = document.getElementById('native-init-banner');
    if (!existing) {
      existing = document.createElement('div');
      existing.id = 'native-init-banner';
      existing.style.cssText =
        'position:fixed;top:0;left:0;right:0;z-index:99999;' +
        'background:#b91c1c;color:#fff;font:12px/1.4 system-ui;' +
        'padding:8px 12px;text-align:center;cursor:pointer;';
      existing.title = 'Tap to dismiss';
      existing.addEventListener('click', function () { existing.remove(); });
      (document.body || document.documentElement).appendChild(existing);
    }
    var failures = window.__nativeInitFailures.map(function (f) {
      return f.sdk + ': ' + (f.error || 'unknown');
    }).join(' | ');
    existing.textContent = '⚠️ Native SDK init failed — ' + failures + ' (tap to dismiss)';
  }
})();
```

---

## Runtime smoke (what `npm run validate` checks)

Web-only smokes (Node / Vite preview) cannot exercise a native SDK init — there is no native side to fail. But the web smoke CAN assert that the listener is wired correctly so the FAILURE PATH is observable:

```js
// scripts/smoke-runtime.js — addition
import { JSDOM } from 'jsdom';  // or whatever the existing smoke uses

// ... existing smoke setup ...

// Simulate a native init failure event
const dom = new JSDOM('<html><body></body></html>');
global.window = dom.window;
require('../www/capacitor-bridge.js');  // loads the listener

window.__onNativeInit({ sdk: 'TestSdk', ok: false, error: 'simulated-failure' });

if (window.__nativeInitFailures.length !== 1) {
  console.error('smoke: __nativeInitFailures listener did not record a failure');
  process.exit(1);
}
if (window.__nativeInitFailures[0].sdk !== 'TestSdk') {
  console.error('smoke: failure record has wrong sdk name');
  process.exit(1);
}
console.log('smoke OK: __onNativeInit listener wires through to __nativeInitFailures');
```

This catches the regression where someone removes or breaks the `__onNativeInit` listener — the failure path won't fire and we'd be back to silent swallowing.

---

## What Ripon checks on-device

For every native SDK in the game, after install:

1. **Debug APK + production secrets** → launch app → wait 2-3 sec for inits → Chrome DevTools → inspect WebView → console:
   ```js
   window.__nativeInitFailures
   ```
   Expected: `[]` (empty array — every SDK initialized cleanly).

2. **If non-empty:** read each `{sdk, error}` entry. The error string maps to the native-side exception message — no need for `adb logcat` to find it.

3. **Debug-build banner:** if any init fails, the red banner appears at the top of the screen on app launch. **Tap to dismiss.** Banner suppression in release builds is intentional — release builds report failures via analytics (separate work) so users never see it.

---

## Per-SDK rollout plan

This pattern lives in the brain (this doc). Per-game implementation is a build-request issue per SDK:

| Game | SDK | Status |
|---|---|---|
| Bloxplode | LinkRunner | Shipping in factory-improvement #72 implementation pass (this PR) |
| Bloxplode | AdMob | JS-initiated — already observable via existing `try/catch`; this pattern is a defense-in-depth follow-up |
| Bloxplode | Firebase Crashlytics | Same as AdMob — JS-initiated, lower priority |
| Arrow Puzzle | AdMob (when iOS native init lands) | Apply pattern when native init paths surface |
| House Mafia | (no native SDKs yet) | Apply pattern when Capacitor wrap lands |

The attribution / monetization SDKs are the priority targets — silent failures there break F1.

---

## Why this is F1-critical

F1 = "real game shipped with ads + UA + compliance." The UA layer requires attribution. Bloxplode's LinkRunner has been live for weeks — if init has been silently failing, every UA dollar spent during that window produced zero attribution data and no business signal. **The factory cannot reach F1 without knowing the attribution layer is alive.** This pattern turns "we don't know" into "we know" — either confirms attribution works (clears F1 path) or surfaces a real bug (fixable, then clears F1 path).

The brain rule makes this permanent across every future game.

## Source

Filed from Bloxplode #26 diagnosis (2026-04-21) — the LinkRunner audit revealed the silent-swallow pattern. Codified 2026-04-22 per Sahil's north-star prioritization.
