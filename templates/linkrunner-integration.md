# LinkRunner integration pattern — end-to-end attribution for every Capacitor game

**Absorbed from the official LinkRunner Onboarding Guide 2026-04-23.** Applies to every Capacitor-wrapped game in the portfolio that needs install attribution + ad-revenue tracking. This shard exists so the factory does not re-read the PDF every time a game needs LinkRunner.

Companion pattern: [`templates/capacitor-native-sdk-pattern.md`](capacitor-native-sdk-pattern.md) — covers the Android init-observability contract that every native SDK (including LinkRunner) MUST follow.

---

## The 8 onboarding steps — who does what

| Step | Guide § | Who | Output |
|---|---|---|---|
| Sign up + create project | §1 | Ripon | One LinkRunner project per game. Copy `TOKEN`, `SECRET_KEY`, `KEY_ID` into password manager. Don't reuse one project across games — events mix. |
| Whitelabel subdomain | §2 | Ripon | DNS CNAME on stratos.games for branded deep links. Start early — propagation takes hours. Not blocking for initial ship, branded links work later. |
| Integrate SDK | §3 | **Factory** | npm install + init + **signup event** (MANDATORY). See Android + iOS + JS sections below. 2–4 hr implementation per game. |
| Configure custom + payment events | §4 | **Factory** | trackEvent + captureAdRevenue wired into AdMob callbacks. For IAP add capturePayment (Stratos has no IAP today). |
| Test integration | §5 | Ripon | Click test link → install → dashboard verify. Blocks UA spend. |
| Connect ad networks | §6 | Ripon | Meta + Google minimum for F1. Defer TikTok/Snapchat until budget exists. iOS = SKAN 4.0 wizard. |
| Connect analytics platform | §7 | Ripon | Forward events to Firebase/GA4 (Stratos standard). Optional but useful. |
| Go deeper | §8 | Later | Remarketing, deferred deep linking, data export. Post-F1. |

---

## Required secrets (per game, all tier-2)

Per `council/SECRETS.md`, Ripon sets via `gh secret set`:

- `LR_TOKEN`
- `LR_SECRET_KEY`
- `LR_KEY_ID`

The factory **NEVER** handles values. Code references them structurally only.

**Android (Kotlin/Gradle):** read via `local.properties` → `BuildConfig` fields. Pattern (copied from Bloxplode's `android/app/build.gradle`):

```gradle
def linkrunnerProps = new Properties()
def linkrunnerPropsFile = rootProject.file('local.properties')
if (linkrunnerPropsFile.exists()) {
    linkrunnerPropsFile.withInputStream { linkrunnerProps.load(it) }
}
def lrToken     = linkrunnerProps.getProperty('LR_TOKEN',      System.getenv('LR_TOKEN')      ?: '')
def lrSecretKey = linkrunnerProps.getProperty('LR_SECRET_KEY', System.getenv('LR_SECRET_KEY') ?: '')
def lrKeyId     = linkrunnerProps.getProperty('LR_KEY_ID',     System.getenv('LR_KEY_ID')     ?: '')
// ...then expose as buildConfigField 'String', 'LR_TOKEN', "\"${lrToken}\""
```

**iOS (Swift/xcconfig):** read via `.xcconfig` file with TODO comment for each secret slot. Ripon fills values on his Mac during `[secret-onboarding]` loop.

**CI:** `gh secret set` on each game repo. Verify with `gh secret list`.

---

## Android implementation (factory work)

### 1. Gradle

- `android/app/build.gradle`: `implementation 'io.linkrunner:android-sdk:2.1.5'` (bump version as LinkRunner releases — check their maven-central page).
- Expose `LR_TOKEN` / `LR_SECRET_KEY` / `LR_KEY_ID` as `BuildConfig` fields via the pattern above.

### 2. MainActivity — init with observability

Follow the Android native-init contract in [`capacitor-native-sdk-pattern.md`](capacitor-native-sdk-pattern.md). **Never swallow exceptions silently** — emit success AND failure via `window.__onNativeInit({sdk:"linkrunner", ok, error?})` using `bridge.getWebView().evaluateJavascript(...)`.

Minimum Kotlin shape:

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    CoroutineScope(Dispatchers.IO).launch {
        try {
            LinkRunner.getInstance().init(
                context = applicationContext,
                token = BuildConfig.LR_TOKEN,
                secretKey = BuildConfig.LR_SECRET_KEY,
                keyId = BuildConfig.LR_KEY_ID,
                debug = BuildConfig.DEBUG
            )
            emitInitStatus("linkrunner", true, null)
        } catch (e: Exception) {
            Log.e(TAG, "LinkRunner init failed", e)
            emitInitStatus("linkrunner", false, e.message)
        }
    }
}
```

Where `emitInitStatus` is the shared helper from `capacitor-native-sdk-pattern.md`.

---

## JS implementation (factory work — the PRIMARY path per guide §3)

Prefer the official `linkrunner` npm package over a hand-rolled Capacitor bridge plugin. The official SDK handles native + web unified, including signup attribution.

### 1. Install

`npm install linkrunner` in the game root. This is a **tier-2 forbidden-paths exception** — document in the build-request that `package.json` + `package-lock.json` edits are authorized for this specific PR.

### 2. Init (once on boot, BEFORE any tracking calls)

```js
import Linkrunner from 'linkrunner';

await Linkrunner.init({
  token: LR_TOKEN,          // exposed via env at build time
  secretKey: LR_SECRET_KEY,
  keyId: LR_KEY_ID,
  debug: false              // true in debug builds
});
```

### 3. Signup event — MANDATORY (§3)

**This is the #1 most-missed step.** If `signup` never fires, install attribution still records but post-install conversion events won't attribute correctly. Fire once per install, guard on localStorage:

```js
const SIGNUP_KEY = 'lr_signup_fired';
if (!localStorage.getItem(SIGNUP_KEY)) {
  await Linkrunner.signup({ userId: getOrCreateDeviceId() });
  localStorage.setItem(SIGNUP_KEY, '1');
}
```

### 4. Revenue capture (§4)

Two APIs, both should fire from the same call site for dedup:

```js
// Custom event — used for ad-revenue and any domain event
await Linkrunner.trackEvent({
  eventName: 'ad_revenue',
  data: { adUnitId, revenue, currency, network: 'AdMob' }
});

// Payment event — for IAP revenue (Stratos has none today; stub for future)
await Linkrunner.capturePayment({ amount, currency, paymentId });
```

Call `trackEvent({ eventName: 'ad_revenue', ... })` from **every** AdMob reward/interstitial/banner success callback. Revenue signal back to Meta/Google UAC is what lets them optimize against LTV instead of installs.

### 5. SDK + API dedup (guide §4 recommendation)

LinkRunner dedupes on their side. Fire the same event via the SDK AND via the server-side Event Tracking API / Revenue Capture API when possible — increases reliability against dropped events. Low priority for F1; implement after a shipping game reveals dropped-event issues.

---

## iOS implementation (factory scaffolds, Ripon finishes)

### Factory

1. Add LinkRunner iOS pod to `ios/App/Podfile`: `pod 'LinkRunner'` (verify exact pod name against LinkRunner iOS docs).
2. Scaffold `AppDelegate.swift` init block — mirrors MainActivity pattern, emits status via `WKWebView.evaluateJavaScript` so the web layer observes init success/failure identically on iOS + Android.
3. Add `.xcconfig` entries for `LR_TOKEN` / `LR_SECRET_KEY` / `LR_KEY_ID` with TODO comments pointing Ripon at the secret-onboarding loop.

### Ripon (his Mac — required for iOS)

1. `cd ios/App && pod install` (needs full Xcode, not just Command Line Tools).
2. Open `.xcworkspace`, verify bundle ID matches `capacitor.config.json` appId.
3. Register bundle ID at developer.apple.com if new.
4. Set signing team.
5. Fill `.xcconfig` with real LR_* values.
6. Build on iOS Simulator, confirm init emits success event to web layer.
7. Archive + submit to TestFlight.

---

## Testing (§5 — Ripon, blocks UA spend)

End-to-end test that MUST pass before any paid ad spend:

1. Uninstall app if previously installed.
2. Click a test deep link from LinkRunner dashboard.
3. Install fresh APK / TestFlight build.
4. Open app.
5. LinkRunner dashboard → within 60s confirm:
   - **Install** event recorded with correct attribution source
   - **Signup** event recorded
6. Play one level with a rewarded ad.
7. Dashboard confirms **ad_revenue** event with correct revenue value.

Failure → LinkRunner dashboard has Attribution troubleshooting section. Do not ship paid UA without all 3 events verified.

---

## Ad network connect (§6 — Ripon, dashboard only)

**F1 minimum:** Meta Ads + Google Ads / UAC. These are where the portfolio will spend first.

**Defer:** TikTok, Snapchat — connect when we have active budget for those channels. No need to wire integrations we're not using.

**iOS-specific:** SKAN 4.0 wizard required. Run once iOS ships to TestFlight.

---

## Analytics forward (§7 — Ripon, dashboard only)

LinkRunner can forward attribution events into the analytics platform Stratos already uses (Firebase / GA4). Connect this so ad attribution and product events show up in one place for weekly dashboard reads.

Stratos standard: Firebase Analytics on every game. Target: GA4 forward.

---

## Anti-patterns — what to NOT do

1. **Shipping without the signup event (§3).** Attribution partially broken. Most-missed step in the guide. Every LinkRunner build-request must explicitly list the signup event in its acceptance criteria.
2. **Storing LR secrets in any committed file.** Never. Not in `.env.example`, not in README, not in test fixtures. Structural references only.
3. **Skipping §5 end-to-end test before paid ads.** You cannot debug attribution retroactively — the first install that attributes wrong poisons the entire campaign's data.
4. **Connecting every ad network upfront.** Connect only what you're actively spending on. More postback endpoints = more things that can misconfigure.
5. **Hand-rolling the JS SDK when the official package exists.** Bloxplode's `www/global-settings.js` `initLinkrunnerForwarder()` was a pre-SDK workaround. Once `linkrunner` npm package lands, the forwarder should be removed (or kept only if dedup is desired and explicitly scoped).
6. **Filing a LinkRunner build-request without the paired `[secret-onboarding]` issue.** CLAUDE.md Step 5 enforces this — tier-2 secret, Ripon must set values.

---

## References

- LinkRunner docs: docs.linkrunner.io
- Guide PDF: absorbed from `/Users/sahilmodi/Desktop/Linkrunner Onboarding Guide.pdf` 2026-04-23
- Init observability pattern: [`capacitor-native-sdk-pattern.md`](capacitor-native-sdk-pattern.md)
- Secret management: [`council/SECRETS.md`](../council/SECRETS.md)
- Reference implementation (partial — Android only, pre-SDK): Bloxplode `android/app/src/main/java/com/stratos/bloxplode/LinkrunnerPlugin.kt` + `MainActivity.kt` + `www/global-settings.js` forwarder block
