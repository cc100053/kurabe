# 重構方案名稱
Kurabe 全域模組化與捕捉流程穩定化方案

# 當前架構瓶頸分析
- `lib/screens/add_edit_screen.dart` 單檔近 3k 行，混雜相機、圧縮、Gemini 解析、課稅計算、Google Places、Supabase 保存，多重責任加上全域 `setState` 造成過度重繪且難測。
- 價格/單價計算與 Map 基礎資料處理分散於 `SupabaseService`、Catalog/Category/ProductDetail/Tile，多處重複與型別風險。
- 位置權限與快取邏輯分散（`location_service.dart`、CategoryDetail、ProductDetailSheet 等各自呼叫 Geolocator），導致重複請求與權限提示不一致。
- 狀態管理割裂：Riverpod 僅訂閱，其他仍是 `ChangeNotifier` + StatefulWidget；本地 SQLite 與 Supabase 並行、未同步，`AppState` 只服務一處。
- 服務邊界模糊：`SupabaseService` 同時負責清洗、最安値判定、去重；`GeminiService` 直接被 UI 呼叫；`YahooPlaceService` 未使用（死碼）。
- UI 元件重複且樣式漂移（CommunityProductTile vs ShoppingCard），錯誤訊息/Snackbar 邏輯散落。
- 測試缺口：缺少對稅計算、Supabase 去重、位置快取、訂閱流程的單元/整合測試。

- # 分模組重構計劃
- （完成✅）Step 1 基礎分層與狀態治理：建立 data/domain/presentation 分層；Riverpod `AsyncNotifier` 取代 `ChangeNotifier` `AppState`；Env/Key 注入集中化。
- （完成✅）Step 2 價格與資料模型統一：抽出 `PriceCalculator`，建立 typed models/mapper，拆 `SupabaseService` 為 data source + repository，去重與最安値判定集中（數量以 int 上傳避免 Supabase insert 失敗）。
- （完成✅）Step 3 位置・店舗取得統一：擴充 `location_service.dart` 為 LocationRepository，統一權限/快取/降級；Places 補全。
- （完成✅）Step 4 捕捉畫面拆解：Add/Edit 拆為 ViewModel + 分段 Widgets；OCR/圧縮/Gemini 置於 use case；保存流程封裝為單步；Shop 補全與 Insight 改用 cancellable `FutureProvider`。
- （完成✅）Step 5 Catalog/Timeline/Detail：改用 `StreamProvider`/共用 Tile，日期分組 helper，共用最小單價標記與 repository 快取。
- （完成✅）Step 6 認證與訂閱：共用 `AuthErrorMapper` + `AppSnackbar`；`SubscriptionController` 整合購買/復元/Paywall；移除 RC 測試 key 依賴，缺鍵時友善提示。
- Step 7 UI 可重用性：合併 CommunityProductTile/ShoppingCard，抽出 Category 卡片/Price Summary/Insight 卡；Theme 構建 memoization 減少重建。
- Step 8 清理與死碼：標記或移除未用的 `YahooPlaceService` 等；評估逐步下線本地 SQLite，改用 Supabase 歷史。
- Step 9 測試與驗證：單元測試（稅/折扣/單價、去重/最安値、位置快取、訂閱錯誤映射）、Widget/Golden（Add/Edit 片段、共用 Tile）、整合測試（保存流程 stub）。

# 性能與維護性預期收益
- Add/Edit 局部重建 + 位置/補全快取減少重繪與 API 次數。
- 統一計算與模型降低重複與型別錯誤，功能新增影響面可控。
- Riverpod + 分層提高測試友好度與回歸覆蓋。
- 共用 UI 元件降低樣式漂移，Theme memoization 減少初次繪製成本。

# 安全性與邏輯一致性聲明
- 保持現有業務流程、課金 gate、價格計算與 UI 行為不變。
- 重構採漸進式包裝替換並附測試驗證；不改後端 schema。
- 移除/替換遺留組件前先以 facade 確保輸出等價，並以 `flutter analyze`/`flutter test` 回歸確認。
