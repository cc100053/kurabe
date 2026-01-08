 以下係 RC（RevenueCat）完整 setup 步驟（配合你依家 Flutter + iOS 訂閱）：

  1. 建立 RevenueCat Project / App

  - RC Dashboard → New Project
  - Add App → 選 iOS
  - 填 Bundle ID（同 Xcode/App Store Connect 一致）

  2. 連 App Store Connect（自動同步 IAP）

  - RC → App settings → App Store Connect → Add API Key
  - 用 App Store Connect 的 API Key (.p8)、Issuer ID、Key ID
    -（建議）填 App-Specific Shared Secret（自動續期訂閱需要）

  3. App Store Connect 建 IAP（訂閱）

  - 新建 Subscription Group
  - 建三個產品（Auto‑Renewable Subscriptions）
      - 產品 ID（你自己定，例如 com.kurabe.pro.monthly）
      - 期間：Monthly / Quarterly / Annual
      - 價格、地區、審核資料、截圖
  - 等待「Ready to Submit」狀態

  4. RC 建 Entitlement + Offering

  - Entitlement：カイログ Pro（要同 app 內一致）
  - Offering：建立 Default Offering
  - 在 Offering 內新增 Packages：
      - Package identifiers 用 monthly / quarterly / annual（你 app UI 依賴呢三
        個）
      - 將每個 package 綁定到對應 App Store 產品 ID

  5. App 端設定（Flutter）

  - .env 內填 iOS Public SDK Key（RC 提供）
  - 確保 REVENUECAT_API_KEY 已換成 RC Dashboard → Public SDK Key
  - 你 app 已經會同步 profiles.is_pro，無需 webhook

  6. 測試

  - 用 Xcode StoreKit config 或 TestFlight sandbox tester
  - RC Dashboard 會顯示 sandbox 收據
  - 確認 paywall 顯示 3 個 packages、購買/restore 正常

  如果你想我幫你核對：

  - RC Dashboard 入面嘅 Entitlement/Offering/Package IDs
  - App Store Connect 產品 ID 命名
  - .env 是否已填正確 Public SDK Key

  你而家係用同一個 RevenueCat project 做測試定係另外一個？

做法（App Store Connect）：

  1. My Apps → 你個 App → In‑App Purchases → Subscriptions
  2. 入 Subscription Group → 揀該個產品（monthly/quarterly/annual）
  3. Subscription Prices → Add Introductory Offer
  4. 選 Free Trial，期間揀 1 month（等同 30 日）
  5. 儲存、準備審核資料

  重點：

  - 只對「新用戶/合資格用戶」有效（Apple 會自動判斷，不需要你寫額外邏輯）。
  - RevenueCat 會自動讀取 Apple 的試用設定，不需要 RC 另外設定。
  - 你個 app 想顯示「30 日試用」字樣，就可喺 paywall 文案補上（可選）。

修復一個bug, Guest user 撳入pay wall嘅button,會有錯誤發生, 所以我想修改guest user撳入pay wall嘅button，會跳轉去profile page並提示佢guest 無法購買,要先log in。

flutter: [SubscriptionService] purchasePackage called with: Promonthly
flutter: [SubscriptionService] Fetching offerings...
DEBUG: ℹ️ No cached Offerings, fetching from network
DEBUG: ℹ️ Offerings cache is stale, updating from network in foreground
DEBUG: ℹ️ GetOfferingsOperation: Started
DEBUG: ℹ️ There are no requests currently running, starting request GET /v1/subscribers/599cfe49-d128-4855-9828-f596a67f6e96/offerings
DEBUG: ℹ️ API request started: GET '/v1/subscribers/599cfe49-d128-4855-9828-f596a67f6e96/offerings'
DEBUG: ℹ️ API request completed: GET '/v1/subscribers/599cfe49-d128-4855-9828-f596a67f6e96/offerings' (304)
DEBUG: ℹ️ No existing products cached, starting store products request for: ["Proannual", "Promonthly"]
DEBUG: ℹ️ GetOfferingsOperation: Finished
DEBUG: ℹ️ Serial request done: GET /v1/subscribers/599cfe49-d128-4855-9828-f596a67f6e96/offerings, 0 requests left in the queue
DEBUG: 😻 Store products request received response
DEBUG: ℹ️ Store products request finished
ERROR: 🍎‼️ Error fetching offerings - The operation couldn’t be completed. (RevenueCat.OfferingsManager.Error error 1.)
There's a problem with your configuration. None of the products registered in the RevenueCat dashboard could be fetched from App Store Connect (or the StoreKit Configuration file if one is being used). 
More information: https://rev.cat/why-are-offerings-empty
ERROR: 😿‼️ There is an issue with your configuration. Check the underlying error for more details. There's a problem with your configuration. None of the products registered in the RevenueCat dashboard could be fetched from App Store Connect (or the StoreKit Configuration file if one is being used). 
More information: https://rev.cat/why-are-offerings-empty