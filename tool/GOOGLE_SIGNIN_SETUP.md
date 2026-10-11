# Google sign-in — one-time setup (console)

Everything code-side is done: sign-in flow, account linking, release signing,
SHA-1 fingerprints. What remains is **Google's console**, which no code can do
for you. It takes about 5 minutes.

## Fingerprints (already verified with `gradlew :app:signingReport`)

| Build | Keystore | SHA-1 |
|---|---|---|
| debug / profile | `~/.android/debug.keystore` | `ED:EF:7C:0D:E9:17:C9:74:98:85:71:C0:71:6F:C9:F0:01:CA:22:A4` |
| release | `android/app/upload-keystore.jks` | `DA:CF:8C:E2:AE:56:FE:60:EA:8D:00:8C:22:3E:97:FE:B9:45:EF:05` |

Re-print them any time with `pwsh tool/get-sha1.ps1`.

> **Back up `android/app/upload-keystore.jks` and `android/key.properties`
> outside this repo** (password manager / another drive). Losing the keystore
> means you cannot update the app on Play Store again.

## Steps

1. **Firebase console → Project settings (gear) → Your apps → Android app
   (`com.example.bluff`) → Add fingerprint** → paste both SHA-1 values above →
   Save.

2. **Firebase console → Authentication → Sign-in method → Google → Enable**
   → set a support email → Save.
   (If it was already enabled, do it again after step 1 so the config is
   regenerated.)

3. **Download the new `google-services.json`** from the same page and replace
   `android/app/google-services.json`.
   This is the critical one: the current file has `"oauth_client": []`, which
   means no web client ID exists → `default_web_client_id` is missing →
   `GoogleSignIn` throws immediately, no matter what else is correct.

4. Run `flutter clean && flutter run` **on a phone that is signed into a
   Google account**. Settings → Profile → **Sign in with Google** should now
   show the account picker.
   (The emulator cannot test this: it has no Google account added and its
   Play services image is unreliable.)

## Testing in Chrome (Flutter web)

Web has no `google-services.json`, so the app passes the `client_type: 3`
(web) client id (`149296809595-a2ka0oagfl1g24utoc8n5tap08f4gj0p...`) to
`GoogleSignIn.initialize()` in code. One console step remains, because Google
checks the page's **origin** before opening the picker:

1. **Google Cloud console → APIs & Credentials → Credentials → the Web
   client (`…a2ka0oagfl1g24utoc8n5tap08f4gj0p`) → Authorized JavaScript
   origins → Add origin** → add `http://localhost:8080` (and
   `http://127.0.0.1:8080`) → Save.
2. Run with a fixed port so the origin never changes:
   `flutter run -d chrome --web-port=8080`.
   (`flutter run -d chrome` uses a random port each run → origin mismatch.)

Without this you get an `origin_mismatch`/400 error from the Google popup —
the app-side config errors (`ClientID not set`, `init() has already been
called`) are already fixed and should no longer appear.

## Why these two SHA-1s

The app signs releases with the new upload keystore created in this change
(`android/app/build.gradle.kts` loads `android/key.properties`). Firebase
rejects any request whose signing fingerprint it has not seen, so debug *and*
release must both be registered — otherwise sign-in works in development and
breaks the day you ship.

## Note on the package name

`applicationId` is still `com.example.bluff` (the Flutter template default) and
`google-services.json` matches it. Changing it later means re-registering the
app in Firebase and downloading a fresh config — do it before launch, not after.
