# Amazon Price Monitor — Android

Native Android port of the iOS app, written in **Kotlin + Jetpack Compose**.
Monitors price drops on items in your Amazon.com.br cart and notifies you when a
tracked item gets cheaper.

## How it mirrors the iOS app

| Concern | iOS | Android |
| --- | --- | --- |
| UI | SwiftUI | Jetpack Compose |
| Cart scraping | hidden `WKWebView` + injected JS | hidden `WebView` + `evaluateJavascript` |
| Scraping script | `CartParser.parserScript` | `app/src/main/assets/cart_parser.js` (**identical JS**) |
| Login detection | `WKWebsiteDataStore` cookies | `CookieManager` cookies (`AmazonAuth`) |
| Persistence | `UserDefaults` + `Codable` | `SharedPreferences` + `kotlinx.serialization` (`PriceStore`) |
| Notifications | `UNUserNotificationCenter` | `NotificationManagerCompat` |
| History / anomaly / 10% drop alert | `PriceStore` | `PriceStore` (same rules) |
| Background refresh | *(none)* | **`WorkManager`** every ~6h (`RefreshWorker`) |

The scraping logic — the hard part — is shared JavaScript and lives in
`assets/cart_parser.js`. Keep it in sync with the iOS `CartParser.parserScript`.

## Project layout

```
app/src/main/
├── assets/cart_parser.js            # shared cart-parsing JS
├── java/com/vacantaurora/pricemonitor/
│   ├── PriceMonitorApp.kt           # Application: notif channel + WorkManager
│   ├── MainActivity.kt              # Compose nav host
│   ├── PriceViewModel.kt            # UI state + refresh orchestration
│   ├── model/CartItem.kt            # data models + price formatting
│   ├── data/CartParser.kt           # hidden WebView scraper
│   ├── data/AmazonAuth.kt           # cookie-based login state
│   ├── data/PriceStore.kt           # persistence + history + notifications
│   ├── work/RefreshWorker.kt        # periodic background refresh
│   └── ui/                          # Dashboard / ItemDetail / Login + theme
└── res/                             # strings (EN + PT), theme, icons
```

## Build & run

Requires a 2026 Android Studio (Otter+) or a local JDK 17 + Android SDK 36.
Toolchain: AGP 9.2.0, Gradle 9.4.1, Kotlin 2.2.10, Compose BOM 2026.06.00.

```bash
# Generate the Gradle wrapper (one-time; not committed):
gradle wrapper --gradle-version 9.4.1

./gradlew installDebug
```

Then open the app, tap the account icon to log in to Amazon, and hit **Refresh**.

## Notes

- `minSdk 26`, `targetSdk 35`.
- Localized in English and Portuguese (`values/` and `values-pt/`).
- To preview with sample data, call `viewModel.enableDemoData()` (the analog of
  the iOS `-demoMode` launch argument).
