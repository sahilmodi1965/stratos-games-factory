# AdMob integration brain — patterns + gotchas

The factory has integrated AdMob on Bloxplode (live, G3) and Arrow Puzzle (PR #195, pending). This doc consolidates the lessons so the next integration (House Mafia, future games) doesn't repeat the same investigations.

Source issues: #77 (config-path conventions), #78 (NPA-default behavior), #80 (event-name semantics), #82 (debug-build = test ads default).

---

## 1. Per-game config-path conventions (#77)

The "where do AdMob IDs live in source" question depends on game shape. There is no single right answer — pick by repo convention:

| Game shape | Config path | Pattern |
|---|---|---|
| Plain `www/` (Bloxplode) | `www/global-settings.js` | `window.ADMOB_IDS = { android: {...}, ios: {...} }` — assigned before any module that reads it loads. |
| Vite + ESM (Arrow Puzzle) | `games/<game>/src/config/admob-config.js` | `export const ADMOB_IDS = Object.freeze({ android: {...}, ios: {...} })` plus `export function getAdMobIds()` that reads `import.meta.env.DEV` and `window.__APP_BUILD_TYPE__` to switch between TEST and PROD. |
| Future bundler (House Mafia / new games) | Match the existing module pattern | Check what config files already exist before inventing a new one. |

**Anti-pattern** the factory already hit (issue #189 / PR #195): the issue body said "create `www/global-settings.js`" because that's the Bloxplode pattern, but Arrow Puzzle uses `games/arrow-puzzle/src/`. Subagent correctly adapted to AP's layout. The factory now files this as a known mismatch — when filing AdMob integration issues for new games, leave the config path TBD and let the subagent pick based on repo shape.

## 2. Debug-build = test ads (#82) — default in template

**Standard AdMob convention: debug builds → test ads always; release builds → real ads.** Anything else risks Google flagging the account, real-impression counts on unreleased apps, no-fill serves, accidental dev revenue.

**The Vite-DEV-only gate is too coarse.** `import.meta.env.DEV` is true ONLY for `vite dev` server. Any `vite build` output (including a debug-built APK) sets DEV to false → real ads serve from a debug APK. This was the AP #189 bug filed as #201 / fixed in PR #195's added commit.

The factory's required pattern (Option A from #201):

1. `android/app/build.gradle`:
   ```gradle
   buildFeatures { buildConfig true }
   buildTypes {
     release { buildConfigField "boolean", "DEBUG_BUILD", "false" }
     debug   { buildConfigField "boolean", "DEBUG_BUILD", "true"  }
   }
   ```

2. `android/.../MainActivity.{kt,java}` — inject the flag into the WebView before bundle JS runs:
   ```java
   webView.evaluateJavascript(
     "window.__APP_BUILD_TYPE__ = '" + (BuildConfig.DEBUG_BUILD ? "debug" : "release") + "';",
     null
   );
   ```
   Best wired through Capacitor's `WebViewListener.onPageStarted` so it lands before any window-reading config init.

3. Game-side `getAdMobIds()`:
   ```js
   const isDev = import.meta.env?.DEV ?? false;
   const isDebugBuild = window.__APP_BUILD_TYPE__ === 'debug';
   const isCapacitor = !!window.Capacitor?.isNativePlatform?.();
   const isUnflaggedNative = isCapacitor && window.__APP_BUILD_TYPE__ !== 'release';

   // Fail-closed: any unset / unflagged Capacitor build defaults to TEST_IDS.
   return (isDev || isDebugBuild || isUnflaggedNative) ? TEST_IDS : PROD_IDS;
   ```

4. iOS-side equivalent (when iOS shell exists per game):
   - In a Swift bridge or `AppDelegate`: `webView.evaluateJavaScript("window.__APP_BUILD_TYPE__ = '\(buildType)'", ...)` where `buildType` is `"debug"` under `#if DEBUG` else `"release"`.

**The fail-closed default is non-negotiable.** If the BuildConfig flag is missing or misconfigured, the code MUST default to TEST_IDS, never PROD. Real ads must never fire from an unintended path.

## 3. AdMob plugin event-name semantics (#80)

The `@capacitor-community/admob` plugin's TypeScript event names don't always match what their underlying native callback fires at. **Read the native source, not the TS comments.** The factory got bitten on Bloxplode #46 → #52 because PR #49 guessed an event name and shipped broken.

### Verified mappings (Bloxplode #52 native-source audit)

| JS event name (`RewardAdPluginEvents.*`) | Android Kotlin maps to | When it fires (player-perceptible) |
|---|---|---|
| `Reward` | `OnUserEarnedRewardListener.onUserEarnedReward` | When reward is granted to the user. **Can fire BEFORE the ad surface tears down.** Don't use this alone to gate post-ad UI. |
| `Dismissed` | `FullScreenContentCallback.onAdDismissedFullScreenContent` | After the ad's native view fully tears down — i.e. **after the user taps the X-close button**. This is the "ad is gone, player is back" event. Per Google docs spec. |
| `FailedToShow` | `FullScreenContentCallback.onAdFailedToShowFullScreenContent` | Ad attempted to show but couldn't. |

**Verified mapping path:** `node_modules/@capacitor-community/admob/android/src/main/java/com/getcapacitor/community/admob/helpers/FullscreenPluginCallback.kt`

### The right gate for post-ad UI

For animations / state changes that should happen AFTER the ad is fully gone (Bloxplode 4×4 blast, AP hint highlight):

- **Primary:** listen for `Dismissed` (the verified post-X-tap event).
- **Belt + suspenders:** also listen for `document.visibilitychange → visible` (catches devices/SDKs where Dismissed misses).
- **Race resolution:** fire on whichever of Dismissed / visibilitychange arrives **last**.
- **One `requestAnimationFrame` defer** before spawning the post-ad animation so the WebView has painted the empty post-ad state at least once.
- **NO safety timer.** A safety timer that fires before the ad dismisses is worse than no safety timer (PR #49 had a 1500ms safety timer that was the actual bug — fired blast behind the ad). If the SDK ever fails to emit BOTH events, prefer "stuck on dimmed grid (recoverable)" over "ghost-success (invisible)".

Reference: Bloxplode PR #54 (issue #52). Same pattern shipped on Arrow Puzzle PR #195's hint logic with a 50ms defer (acceptable for CSS-toggle highlights since paint frame is instant, not 620ms animation).

## 4. NPA-default behavior pre-consent-banner (#78)

When the game has NO consent-banner UI yet (e.g. Arrow Puzzle pre-#159) but ships AdMob, the factory's `getAdMobIds()` flow defaults to **non-personalized ads** (`npa=1` request flag) until a consent banner reads `consent.ads === true` and flips to personalized.

This is the GDPR/CCPA-compliant default. AdMob still serves ads (no fill rate impact for low-volume games), but they're contextual rather than profile-targeted. Revenue is typically 30-50% lower than personalized but consent compliance is the dominant constraint pre-Play Store launch.

**Document this in the game's analytics integration PR.** Don't ship AdMob personalized as the default — that's a compliance miss waiting for a Google account flag.

When the consent banner ships:
- Accept → flip `consent.ads = true` → `npa=0` (personalized) on next ad request.
- Decline → `consent.ads = false` → keep `npa=1` permanently for the install.
- Unset (banner not yet shown / dismissed without choosing) → keep `npa=1`.

## 5. Cross-cutting: factory-improvement issues these patterns close

- **#77** — config-path conventions (this doc, section 1).
- **#78** — NPA-default behavior documented (this doc, section 4).
- **#80** — event-name semantics with verified mapping (this doc, section 3).
- **#82** — debug-build = test ads default (this doc, section 2).

These can be closed once this doc lands. The patterns become permanent factory knowledge — the next AdMob integration on a new game references this doc instead of re-investigating from scratch.

## 6. What this doc does NOT cover

- **Mediation layers** (AppLovin MAX, ironSource, etc.) — Bloxplode #22 is the open work; will get its own doc when it lands.
- **MMP attribution** (LinkRunner) — covered by `council/SECRETS.md` + Bloxplode #26 diagnosis.
- **Reporting API** (`ADMOB_API_SECRET`) — currently unused; covered by `council/SECRETS.md` when needed.
- **iOS App Tracking Transparency (ATT)** — covered by `Info.plist`'s `NSUserTrackingUsageDescription` per game; AP #195 + BX #48 set this.
- **Banner placements** — current factory convention is no banners (puzzle-pacing decision per AP #189). Re-evaluate per genre.

## Source

Filed from Bloxplode #44/#46/#52 + Arrow Puzzle #189/#201 post-mortems. Keep this doc updated as new SDKs / events / gotchas surface.
