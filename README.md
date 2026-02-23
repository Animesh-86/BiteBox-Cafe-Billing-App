# 🍽️ BiteBox Cafe Billing App

A modern, professional Flutter-based billing system designed for cafes and restaurants. Features real-time analytics, multi-device synchronization, thermal printing, and Firebase integration.

**Current Version**: 1.0.0  
**Last Updated**: February 2026

---

## 🎯 Features

### Core Billing
- ✅ **POS System** - Fast order creation and management
- ✅ **Invoice Generation** - Atomic invoice numbering with multi-device support
- ✅ **Multiple Payment Methods** - Cash, UPI, Card, Split payments
- ✅ **Hold/Pending Orders** - Manage incomplete orders with unique HOLD- prefixes
- ✅ **Thermal Printing** - Direct thermal printer integration via Bluetooth

### Real-Time Features
- 🔴 **Live Analytics** - Real-time revenue, order count, and item tracking (<50ms updates)
- 📊 **Live Dashboard** - Shows 🔴 LIVE badges for today's data
- 🛒 **Multi-Device Cart Sync** - Share carts across multiple devices atomically
- 👥 **Collaborative Mode** - Multiple staff can work on same cart simultaneously

### Analytics & Reports
- 📈 **Comprehensive Analytics** - Revenue, orders, trends, loyalty programs
- 📊 **Visual Charts** - Revenue trends, hourly breakdowns, payment mode distribution
- 📄 **Excel Export** - Export analytical data to Excel format
- 🔍 **Advanced Filtering** - Filter by date range, payment mode, location
- 💰 **Financial Insights** - Profit analysis, top items, customer insights

### Database
- 🗄️ **Local Storage** - Offline-capable with SQLite (via Drift ORM)
- ☁️ **Firebase Sync** - Real-time synchronization with Firebase
  - Firestore for historical data
  - Realtime Database for live features
  - Firebase Auth for user management
  - Firebase Storage for media

### Settings & Admin
- ⚙️ **Location Management** - Multi-location support
- 👤 **Inventory Management** - Menu items and categories
- 🎨 **Customizable Settings** - Theme, notification controls
- 🔐 **Role-Based Access** - Different permissions for staff and admins

---

## 🏗️ Architecture

### Technology Stack
- **Framework**: Flutter 3.8.1
- **Language**: Dart 3.8.1
- **State Management**: Riverpod
- **Database**: SQLite (Drift ORM) + Firebase
- **Backend**: Firebase (Auth, Firestore, Realtime DB, Storage)
- **UI Components**: Material Design 3, fl_chart for visualizations
- **Printing**: Blue Thermal Printer plugin

### Project Structure
```
BiteBox-Cafe-Billing-App/
├── Hangout Spot/                    # Main Flutter app
│   ├── android/                     # Android native code
│   ├── ios/                         # iOS native code
│   ├── lib/
│   │   ├── main.dart               # App entry point
│   │   ├── data/
│   │   │   ├── local/db/           # SQLite database (Drift)
│   │   │   ├── repositories/       # Data repositories
│   │   │   ├── providers/          # Riverpod providers
│   │   │   └── models/             # Data models
│   │   ├── services/
│   │   │   ├── live_*.dart         # Real-time features
│   │   │   ├── thermal_printing_service.dart
│   │   │   └── export/
│   │   ├── ui/
│   │   │   ├── screens/            # App screens
│   │   │   │   ├── pos/            # POS system
│   │   │   │   ├── analytics/      # Analytics dashboards
│   │   │   │   └── settings/       # Settings
│   │   │   └── widgets/            # Reusable widgets
│   │   └── utils/
│   │       ├── exceptions/         # Error handling
│   │       └── constants/
│   ├── pubspec.yaml                # Dependencies
│   ├── README.md                   # App-specific docs
│   └── ...
└── README.md                       # This file
```

### Data Flow Architecture

```
┌─────────────────────────────────────────┐
│           Flutter UI Layer              │
│  (screens/, widgets/) - Material Design │
└──────────────────┬──────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────┐
│      State Management (Riverpod)        │
│  (providers/) - Stream/Async providers  │
└──────────────────┬──────────────────────┘
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
┌─────────────────┐  ┌──────────────────┐
│   Repositories  │  │  Services        │
│  (data access)  │  │  (business logic)│
│   - Order       │  │  - Analytics     │
│   - Analytics   │  │  - Printing      │
│   - Settings    │  │  - Invoice Ctr   │
│   - Inventory   │  │  - Cart Sync     │
└────────┬────────┘  └────────┬─────────┘
         │                    │
    ┌────┴────────────────────┴────┐
    ▼                              ▼
┌────────────────────┐   ┌──────────────────┐
│  Local Database    │   │  Firebase        │
│   (SQLite/Drift)   │   │  - Firestore     │
│  - Orders          │   │  - Realtime DB   │
│  - Items           │   │  - Auth          │
│  - Settings        │   │  - Storage       │
└────────────────────┘   └──────────────────┘
```

---

## 🚀 Getting Started

### Prerequisites
- **Flutter**: 3.8.1 or higher ([Install](https://flutter.dev/docs/get-started/install))
- **Dart**: 3.8.1 or higher (comes with Flutter)
- **Android Studio** or **Xcode** for device/emulator
- **Firebase Account** ([Create one](https://firebase.google.com))

### Installation Steps

1. **Clone the repository**
```bash
git clone https://github.com/your-repo/BiteBox-Cafe-Billing-App.git
cd BiteBox-Cafe-Billing-App
```

2. **Navigate to app folder**
```bash
cd "Hangout Spot"
```

3. **Install dependencies**
```bash
flutter pub get
```

4. **Setup Firebase**
   - Create a Firebase project at [firebase.google.com](https://firebase.google.com)
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in respective platform folders:
     - Android: `android/app/google-services.json`
     - iOS: `ios/Runner/GoogleService-Info.plist`
   - Enable Firebase services:
     - Authentication (Email/Password, Phone)
     - Firestore Database
     - **Realtime Database** (NEW - for live features)
     - Cloud Storage
     - Cloud Functions (optional)

5. **Apply Firebase Security Rules**
   - Go to Firebase Console → Realtime Database → Rules
   - Copy rules from `database.rules.json`
   - Publish the rules
   - See `FIREBASE_REALTIME_DATABASE_SETUP.md` for detailed setup

6. **Run the app**
```bash
# Run on connected device/emulator
flutter run

# Run in release mode
flutter run --release
```

---

## 📱 Using the App

### First Time Setup
1. Launch app → Sign in with email/password
2. Go to **Settings** → Configure:
   - Restaurant name and logo
   - Location details
   - Tax settings
   - Menu items and categories

### Creating Orders (POS Screen)
1. Tap **POS** on home screen
2. Select items from menu
3. Enter quantity and notes
4. Optionally **Hold** order (generates HOLD-timestamp invoice)
5. Complete order:
   - Select payment method (Cash/UPI/Card/Split)
   - Enter amounts
   - Print bill (if printer connected)
   - **Submit Order** → Finalizes with sequential invoice number

### View Analytics
1. Tap **Analytics** on home screen
2. View **Overview** dashboard with:
   - 🔴 LIVE badge for real-time data (today only)
   - Revenue and order counts
   - Payment mode breakdown
3. Explore **Trends** for historical analysis
4. Export data as Excel file

### Multi-Device Setup
1. Login on multiple devices with **same user account**
2. Orders appear on all devices
3. Carts sync in real-time across devices
4. Invoice numbers remain unique and sequential

---

## 🔐 Firebase Setup

### Firestore (Historical Data)
```
Collections:
- orders/{orderId}          → Order details
- order_items/{itemId}     → Items in order
- customers/{customerId}   → Customer info
- locations/{locationId}   → Location details
```

### Realtime Database (Live Features)
```
/analytics/{userId}/daily/{date}/
  - revenue: real-time total
  - orderCount: real-time count
  - payments/{mode}: breakdown

/invoiceCounters/{userId}/sessions/{sessionId}/
  - currentNumber: atomic counter
  - lastUpdated: timestamp

/active_carts/{userId}/{cartId}/
  - items: cart items
  - totalAmount: real-time total
  - status: active/completed/abandoned

/kds/{userId}/pending/{orderId}/
  - Kitchen display queue (bonus feature)
```

### Security Rules
- ✅ User can only read/write their own data
- ✅ Atomic transactions prevent race conditions
- ✅ Validation ensures data integrity
- See `FIREBASE_REALTIME_DATABASE_SETUP.md` for complete rules

---

## ⚙️ Configuration Files

### `pubspec.yaml`
```yaml
dependencies:
  flutter: sdk: flutter
  firebase_core: ^latest
  cloud_firestore: ^latest
  firebase_database: ^11.3.0      # Realtime DB
  firebase_auth: ^latest
  firebase_storage: ^latest
  
  # State management
  flutter_riverpod: ^latest
  
  # Database
  drift: ^latest
  sqlite3_flutter_libs: ^latest
  
  # UI
  fl_chart: ^latest
  intl: ^latest
  
  # Utilities
  image_picker: ^latest
  excel: ^latest
  blue_thermal_printer: ^latest
```

### Environment Variables
Create `.env` file (git-ignored):
```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-api-key
FIREBASE_APP_ID=your-app-id
```

---

## 🐛 Error Handling

The app implements professional error handling that separates technical details from user messages.

### User-Friendly Error Messages
Instead of technical stack traces, users see clear, actionable messages:
- ❌ Before: "Export failed: $e" (confusing)
- ✅ After: "Failed to export data. Please check your storage" (clear)

### How It Works
- **Service Layer**: Throws typed `AppException` objects
- **UI Layer**: Converts to user-friendly messages via `ErrorHandler`
- **Display**: Shows via `ErrorUI` helpers (SnackBar, Dialog, Inline)

### Exception Types
- `AuthException` - Sign in errors
- `NetworkException` - Connection issues
- `OrderException` - Order processing errors
- `InvoiceException` - Invoice generation errors
- `PrintingException` - Printer connection errors
- `ExportException` - Export/import errors
- [See full list in `ERROR_HANDLING_GUIDE.md`]

### Example Usage
```dart
try {
  await orderRepository.createOrder(data);
  ErrorUI.showSuccess(context, 'Order created!');
} catch (e) {
  ErrorUI.showSnackBar(context, ErrorHandler.handleOrderError(e));
}
```

---

## 🔴 Real-Time Features (NEW)

### Live Analytics Dashboard
- **Revenue Counter**: Updates instantly as orders complete
- **Order Count**: Real-time count with ServerValue.increment()
- **Payment Breakdown**: Real-time payment mode analysis
- **Latency**: <50ms updates via Firebase WebSocket

**How to Use**:
1. Go to Analytics → Today view shows 🔴 LIVE
2. Create an order on one device
3. See revenue/count update instantly on all devices
4. Switch to historical date → switches to Firestore data

### Multi-Device Cart Sync
- **Atomic Updates**: Prevents race conditions
- **Conflict-Free**: Last write wins with timestamps
- **Real-Time**: <100ms synchronization
- **Session Awareness**: Detects disconnections automatically

**How to Use**:
1. Open cart on Device A
2. Add item on Device B
3. Item appears instantly on Device A
4. Both devices show synchronized totals

### Invoice Counter (Multi-Device Safe)
- **HOLD Orders**: Get HOLD-timestamp prefix while pending
- **Atomic Counter**: Uses Firebase transactions for uniqueness
- **Sequential**: Converted to sequential only when completed
- **Eliminates Gaps**: Cancelled hold orders don't create gaps

**How to Use**:
1. Hold order on Device A → Gets `HOLD-1708596543`
2. Complete order on Device B → Gets sequential `INV-0001`
3. Cancel hold on Device A → No gap in sequence
4. New order always gets unique sequential number

---

## 📊 Live Features Architecture

```
Firebase Realtime Database (Live)
↓
Stream Providers (Riverpod)
↓
Consumer Widgets with LIVE Badge
↓
Instant UI Updates (<50ms)

Fallback: Firestore (Historical, offline)
```

### When Live Features Activate
- ✅ Viewing **today's** analytics (live badge shows 🔴)
- ✅ Creating orders (invoice counter uses atomic transactions)
- ✅ Multi-device cart (syncs via WebSocket)
- ❌ Viewing past dates (uses Firestore instead)
- ❌ Without internet (uses local cache)

---

## 🖨️ Thermal Printer Setup

### Hardware
- Bluetooth thermal printer (58mm or 80mm)
- Printer must support ESC/POS commands

### Configuration
1. **Pair printer**:
   - Go to device Bluetooth settings
   - Search for printer (e.g., "PT-810")
   - Pair and note bluetooth name

2. **In App**:
   - Settings → Printer → Select Device
   - Print test bill to verify connection

3. **Troubleshooting**:
   - Check printer power
   - Ensure Bluetooth is ON
   - Verify app has Bluetooth permission
   - Restart printer if connection fails

### Printing Bill
- Auto-formats to 58mm or 80mm width
- Includes QR code (if enabled)
- Prints receipt and duplicate copy
- Supports logo/header customization

---

## 📦 Building for Release

### Android
```bash
# Build APK
flutter build apk --release

# Build AAB (for Play Store)
flutter build appbundle --release

# Output: build/app/outputs/flutter-app.aab
```

### iOS
```bash
# Build IPA
flutter build ios --release

# Output: build/ios/iphoneos/Runner.app
```

---

## 🧪 Testing

### Run Tests
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

### Device Testing
```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

---

## 🔧 Troubleshooting

### Common Issues

**Firebase Connection Fails**
- ✅ Check internet connection
- ✅ Verify Firebase credentials in `google-services.json`
- ✅ Ensure Firebase project is active
- ✅ Check Firebase security rules

**Thermal Printer Not Connecting**
- ✅ Ensure printer is paired in Bluetooth
- ✅ Verify printer is powered on
- ✅ Check app has Bluetooth permission
- ✅ Restart app and try again

**Real-Time Data Not Syncing**
- ✅ Check internet connection
- ✅ Verify Realtime DB rules are published
- ✅ Check user is authenticated
- ✅ View logs in Firebase Console

**Compilation Errors**
- ✅ Run `flutter clean && flutter pub get`
- ✅ Check Dart version matches (3.8.1+)
- ✅ Update Android/iOS build tools

---

## 📚 Documentation

- **[ERROR_HANDLING_GUIDE.md](./Hangout%20Spot/ERROR_HANDLING_GUIDE.md)** - Professional error handling
- **[QUICK_ERROR_HANDLING_REFERENCE.md](./Hangout%20Spot/QUICK_ERROR_HANDLING_REFERENCE.md)** - Quick start for errors
- **[FIREBASE_REALTIME_DATABASE_SETUP.md](./Hangout%20Spot/FIREBASE_REALTIME_DATABASE_SETUP.md)** - Firebase Realtime DB guide
- **[FIREBASE_IMPLEMENTATION_SUMMARY.md](./Hangout%20Spot/FIREBASE_IMPLEMENTATION_SUMMARY.md)** - Complete feature docs
- **[FIREBASE_COST_ANALYSIS.md](./Hangout%20Spot/FIREBASE_COST_ANALYSIS.md)** - Cost analysis & predictions
- **[MULTI_DEVICE_INVOICE_ISSUE.md](./Hangout%20Spot/MULTI_DEVICE_INVOICE_ISSUE.md)** - Invoice problem & solution

---

## 🤝 Contributing

1. **Create a branch** for your feature
```bash
git checkout -b feature/your-feature-name
```

2. **Make changes** and test thoroughly

3. **Commit with clear messages**
```bash
git commit -m "feat: Add your feature description"
```

4. **Push and create Pull Request**
```bash
git push origin feature/your-feature-name
```

---

## 📋 Project Status

| Feature | Status | Notes |
|---------|--------|-------|
| Core POS | ✅ Complete | Fully functional |
| Analytics Dashboard | ✅ Complete | With charts and export |
| Thermal Printing | ✅ Complete | Bluetooth integration |
| Live Analytics | ✅ NEW | Real-time revenue/orders (<50ms) |
| Multi-Device Cart Sync | ✅ NEW | Atomic, conflict-free |
| Invoice Counter | ✅ NEW | HOLD- prefix solution for multi-device |
| Firebase Realtime DB | ✅ NEW | Integrated for live features |
| Kitchen Display | ⏳ Planned | Future enhancement |
| Mobile Payments | ⏳ Planned | Razorpay/PhonePe integration |
| Customer Loyalty | ✅ Complete | Points-based system |

---

## 📈 Performance Metrics

### Current Performance
- **Dashboard Load**: ~800ms (with real-time updates)
- **Order Creation**: ~500ms (POS → Firebase)
- **Invoice Generation**: <100ms (atomic counter)
- **Analytics Export**: ~2-3s (for monthly data)
- **Live Update Latency**: <50ms (Firebase Realtime)
- **Cart Sync**: <100ms (multi-device)

### Optimization (Future)
- [ ] Implement caching layer for analytics
- [ ] Lazy load dashboard components
- [ ] Pagination for historical orders
- [ ] Incremental analytics sync

---

## 📞 Support

For issues or questions:
1. Check documentation in `Hangout Spot/` folder
2. Review error messages (now user-friendly!)
3. Check Firebase Console for permission errors
4. Enable debug logging in `main.dart`

---

## 📄 License

This project is proprietary software for BiteBox Cafe.

---

## 🎉 Credits

Built with ❤️ using Flutter, Firebase, and Riverpod.

**Key Libraries**:
- Flutter Riverpod - State management
- Drift - Database ORM
- firebase_* packages - Backend services
- fl_chart - Beautiful charts
- blue_thermal_printer - Thermal printing

---

## 🚀 What's New (v1.0.0)

### 🎯 Live Features (February 2026)
- ✨ **Real-Time Analytics** - See revenue/orders update instantly
- 🛒 **Multi-Device Cart Sync** - Staff can collaborate seamlessly
- 📊 **Live Invoice Counter** - Prevents gaps from hold orders
- 🔴 **LIVE Badges** - Dashboard shows real-time data with visual indicator
- ⚡ **Sub-50ms Updates** - Firebase Realtime DB integration

### 🔒 Error Handling
- 👥 **User-Friendly Messages** - No technical jargon
- 🎨 **Professional UI** - Color-coded, icon-matched errors
- 🐛 **Debug Support** - Technical details logged for developers
- 🔄 **Retry Support** - Built-in retry for recoverable errors

### 📁 Project Structure
- Better organized service layer
- Centralized error handling system
- Professional UI helpers
- Comprehensive documentation

---

**Happy Billing! 🍽️💳**
