# Google AdMob Integration - Implementation Summary

## 📱 Các loại ads đã được implement

### 1. **Banner Ads** ✅
**Vị trí:**
- [HomeScreen](lib/features/home/presentation/screens/home_screen.dart) - Giữa banner carousel và danh sách tokens
- [NotificationsScreen](lib/features/notifications/presentation/notifications_screen.dart) - Đầu danh sách notifications

**Cách hoạt động:**
- Chỉ hiển thị ở **release builds** (không hiện ở debug mode)
- Kích thước: 320x60px
- Auto fallback: Remote config → Debug test ID → Release production ID

**States:**
- Loading: "Loading banner ad..."
- Loaded: Hiển thị AdWidget
- Failed: "Banner ad failed to load"

---

### 2. **Interstitial Ads** ✅
**Vị trí:** Hiển thị khi navigate giữa các screens

**File quản lý:** 
- [InterstitialAdManager](lib/core/ads/interstitial_ad_manager.dart)
- [AdNavigationHelper](lib/core/utils/ad_navigation_helper.dart)

**Cách sử dụng:**
```dart
// Thay vì Navigator.pushNamed
AdNavigationHelper.navigateWithAd(
  context,
  routeName: AppRoutes.tokenInfo,
  arguments: token,
);
```

**Logic hiển thị:**
- Mỗi **3 lần navigation** → hiển thị 1 lần ad
- Auto retry khi load failed (tối đa 3 lần)
- Preload ad tiếp theo sau khi dismissed

**Ví dụ đã áp dụng:**
- NotificationsScreen → TokenInfoScreen (khi click vào notification)

---

### 3. **App Open Ads** ✅
**Vị trí:** Hiển thị khi app được mở lại từ background

**File quản lý:**
- [AppOpenAdManager](lib/core/ads/app_open_ad_manager.dart)
- [AppLifecycleReactor](lib/core/ads/app_lifecycle_reactor.dart)

**Cách hoạt động:**
- Tự động khởi tạo trong [main.dart](lib/main.dart)
- Listen app lifecycle changes
- Chỉ hiện khi app bị pause **> 3 giây**
- Ads có thời hạn **4 tiếng** (tự động refresh nếu stale)

---

### 4. **Rewarded Ads** ⚪
**Status:** Config sẵn sàng, chưa implement UI

**Ad Unit IDs:**
- Android: `ca-app-pub-1555215290851782/9299900084`
- iOS: `ca-app-pub-1555215290851782/5910155697`

**Gợi ý sử dụng:**
- Unlock premium features
- Xem full analysis report
- Remove ads for 24h

---

### 5. **Native Ads** ⚪
**Status:** Config sẵn sàng, chưa implement

**Ad Unit IDs:**
- Android: `ca-app-pub-1555215290851782/2187221461`
- iOS: `ca-app-pub-1555215290851782/9491471771`

**Gợi ý sử dụng:**
- Chèn vào danh sách (mỗi 10 items)
- Hiển thị trong list tokens/notifications

---

## 🔧 Cấu trúc files

```
lib/core/ads/
├── admob_config.dart              # Static fallback IDs
├── admob_store.dart               # Remote config store (BLoC)
├── admob_service.dart             # API service (GET /admob/config)
├── admob_remote_config_model.dart # Data models
├── ad_manager_store.dart          # Central ad manager
├── interstitial_ad_manager.dart   # Interstitial logic
├── app_open_ad_manager.dart       # App open logic
└── app_lifecycle_reactor.dart     # Lifecycle observer

lib/core/utils/
└── ad_navigation_helper.dart      # Helper for navigation with ads

lib/main.dart                       # App initialization
```

---

## 🚀 Quy trình khởi tạo

1. **main()** → Initialize MobileAds.instance
2. **MyApp** → Create AdmobStore + AdManagerStore
3. **_AppRoot.initState()** → 
   - Load remote config từ API
   - Initialize ad managers
   - Setup app lifecycle observer
4. **Screens** → Load ads khi initState

---

## 📊 Remote Config Priority

```
1. Remote API (/admob/config)  ← Ưu tiên cao nhất
2. Debug Test IDs              ← Chỉ dùng khi debug mode
3. Release Production IDs      ← Fallback mặc định
```

**API Response format:**
```json
{
  "ios": {
    "id": "ca-app-pub-xxx~xxx",
    "ad_types": {
      "banner": "ca-app-pub-xxx/xxx",
      "interstitial": "ca-app-pub-xxx/xxx",
      "rewarded": "ca-app-pub-xxx/xxx",
      "native_advanced": "ca-app-pub-xxx/xxx",
      "app_open": "ca-app-pub-xxx/xxx"
    }
  },
  "android": { ... }
}
```

---

## 🎯 Cách thêm ads vào screen mới

### **Banner Ad:**
```dart
class YourScreen extends StatefulWidget {
  // ...
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    if (kIsWeb || kDebugMode) return;
    
    final adUnitId = context.read<AdmobStore>().resolveUnitId(
      adType: 'banner',
      debugFallback: Platform.isIOS
          ? AdMobConfig.testBannerIos
          : AdMobConfig.testBannerAndroid,
      releaseFallback: Platform.isIOS
          ? AdMobConfig.bannerAdUnitIdIos
          : AdMobConfig.bannerAdUnitIdAndroid,
    );

    final banner = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() {
          _bannerAd = ad as BannerAd;
          _isBannerLoaded = true;
        }),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    banner.load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isBannerLoaded && _bannerAd != null)
          SizedBox(
            height: 60,
            child: AdWidget(ad: _bannerAd!),
          ),
        // Your content...
      ],
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
```

### **Interstitial Ad:**
```dart
// Just wrap your navigation
AdNavigationHelper.navigateWithAd(
  context,
  routeName: AppRoutes.yourRoute,
  arguments: yourArgs,
);
```

---

## ⚙️ Configuration

**Debug mode:** Ads disabled (tránh bị Google ban account)
**Release mode:** Ads enabled với production IDs

**Sync native config:**
```bash
dart run tool/sync_admob_config.dart
```

Updates:
- `android/app/src/main/res/values/strings.xml`
- `ios/Runner/Info.plist`

---

## 📈 Next Steps - Chưa implement

1. **Native Ads** - Chèn vào lists
2. **Rewarded Ads** - Unlock features
3. **Analytics tracking** - Monitor ad performance
4. **A/B testing** - Test different ad placements
5. **Frequency capping** - Limit ads per user

---

## 🐛 Debugging

**Check ads loaded:**
```dart
print('Banner loaded: $_isBannerLoaded');
print('Interstitial ready: ${adManager.interstitialAdManager._interstitialAd != null}');
```

**Common issues:**
- Ads không hiện → Check debug mode disabled
- Failed to load → Check internet connection + Ad Unit IDs
- Too many requests → Check API rate limits

---

Created: 2026-03-08
Last Updated: 2026-03-08
