# 🍎 iOS Configuration - Complete Setup Guide

## Overview

This guide covers the complete iOS configuration for the ASLI Campus Platform Flutter app.

---

## 📁 Workspace Settings

### **Files Updated**

Two workspace settings files have been configured:

**1. Project Workspace:**
```
ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
```

**2. Main Workspace:**
```
ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
```

### **Configuration**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PreviewsEnabled</key>
	<false/>
	<key>IDEWorkspaceSharedSettings_AutocreateContextsIfNeeded</key>
	<false/>
</dict>
</plist>
```

### **Purpose**

| Setting | Value | Purpose |
|---------|-------|---------|
| **PreviewsEnabled** | false | Disable Swift previews (not needed for Flutter) |
| **IDEWorkspaceSharedSettings_AutocreateContextsIfNeeded** | false | Prevent automatic context creation |

**Benefits:**
- Cleaner Xcode workspace
- No unnecessary Swift package manager contexts
- Optimized for Flutter development
- Reduced workspace bloat

---

## 🔧 IDE Workspace Checks

**File:** `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>IDEDidComputeMac32BitWarning</key>
	<true/>
</dict>
</plist>
```

**Purpose:**
- Enables 32-bit warning in Xcode
- Helps identify compatibility issues
- Recommended by Apple

---

## 📱 Info.plist Configuration

### **App Information**

```xml
<key>CFBundleDisplayName</key>
<string>ASLI - Campus Platform</string>
<key>CFBundleName</key>
<string>asli_app</string>
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>CFBundleVersion</key>
<string>$(FLUTTER_BUILD_NUMBER)</string>
<key>CFBundleShortVersionString</key>
<string>$(FLUTTER_BUILD_NAME)</string>
```

---

### **Permissions**

#### **Location Services**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>ASLI needs your location to show your position on the campus map and provide navigation features.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>ASLI needs your location to provide campus navigation and location-based features even when the app is in background.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>ASLI needs your location for campus navigation and nearby features.</string>
```

**Features:**
- Campus map navigation
- Distance calculation
- "My Location" button
- Background location tracking

---

#### **Camera**
```xml
<key>NSCameraUsageDescription</key>
<string>ASLI needs camera access to take photos for posts, profile pictures, and sharing campus moments.</string>
```

**Features:**
- Profile picture capture
- Post photo upload
- Story creation
- QR code scanning

---

#### **Photo Library**
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>ASLI needs photo library access to select images for posts, profile pictures, and sharing.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>ASLI needs permission to save images to your photo library.</string>
```

**Features:**
- Select from gallery
- Save profile pictures
- Upload post images
- Download content

---

#### **Microphone** (Future)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>ASLI needs microphone access for voice messages and audio features.</string>
```

**Future Features:**
- Voice messages in chat
- Audio notes
- Voice posts

---

#### **Background Modes**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

**Features:**
- Push notifications
- Background data fetch
- Real-time message updates
- Background app refresh

---

#### **URL Schemes**
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>https</string>
    <string>http</string>
    <string>mailto</string>
    <string>tel</string>
</array>
```

**Features:**
- Open external URLs
- Email links
- Phone number links
- Web navigation

---

#### **App Transport Security**
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

**Security:**
- Allow HTTP for localhost (development)
- Enforce HTTPS in production
- Secure network communication
- ATS compliance

---

### **UI Configuration**

#### **Status Bar**
```xml
<key>UIStatusBarStyle</key>
<string>UIStatusBarStyleLightContent</string>
<key>UIViewControllerBasedStatusBarAppearance</key>
<true/>
```

#### **Orientation**
```xml
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
</array>
```

#### **Performance**
```xml
<key>CADisableMinimumFrameDurationOnPhone</key>
<true/>
<key>UIApplicationSupportsIndirectInputEvents</key>
<true/>
```

---

## 🏗️ Build Settings

### **Deployment Target**

**Minimum iOS Version:** 12.0

```xml
<key>MinimumOSVersion</key>
<string>12.0</string>
```

**Why iOS 12?**
- Supports 95%+ of active iOS devices
- Required for latest Flutter features
- Good balance of features and compatibility

---

### **Architectures**

**Supported:**
- arm64 (iPhone/iPad)
- arm64e (Latest devices)

**Bitcode:** Disabled (Flutter requirement)

---

### **Swift Version**

**Version:** 5.0

Required for:
- Flutter plugins
- iOS platform features
- Future Swift code integration

---

## 📦 CocoaPods Configuration

### **Podfile**

**Location:** `ios/Podfile`

```ruby
platform :ios, '12.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.absolute_path("../..")
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
```

---

## 🔐 Security Features

### **Keychain Entitlements**

**File:** `ios/Runner/Runner.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>keychain-access-groups</key>
	<array>
		<string>$(AppIdentifierPrefix)com.example.asliApp</string>
	</array>
</dict>
</plist>
```

**Purpose:**
- Secure token storage
- Biometric authentication
- Encrypted data storage

---

### **App Transport Security (ATS)**

**Configuration:**
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

**Security Features:**
- HTTPS enforced in production
- HTTP allowed for localhost (development)
- ATS exception logging
- Secure network communication

---

## 🚀 Build & Deployment

### **Development Build**

```bash
# Clean
flutter clean
flutter pub get

# Run on device
flutter run

# Run on simulator
flutter run -d iPhone 15
```

### **Release Build**

```bash
# Build IPA
flutter build ios --release

# Archive in Xcode
cd ios
open Runner.xcworkspace

# Xcode: Product → Archive
# Then: Distribute App
```

### **App Store Submission**

1. **Archive:**
   - Xcode → Product → Archive
   - Wait for archive to complete

2. **Distribute:**
   - Click "Distribute App"
   - Select "App Store Connect"
   - Upload for review

3. **App Store Connect:**
   - Fill app information
   - Add screenshots
   - Submit for review

---

## 📊 Permission Summary

| Permission | Status | Required For |
|------------|--------|--------------|
| **Location** | ✅ | Campus map, navigation |
| **Camera** | ✅ | Photos, profile pics |
| **Photo Library** | ✅ | Gallery access |
| **Microphone** | ✅ (Future) | Voice messages |
| **Notifications** | ✅ | Push notifications |
| **Background Fetch** | ✅ | Real-time updates |
| **Keychain** | ✅ | Secure storage |

---

## 🧪 Testing Checklist

### **Workspace Settings**
- [x] PreviewsEnabled set to false
- [x] AutocreateContextsIfNeeded set to false
- [x] Both workspace files updated

### **Info.plist**
- [x] App display name updated
- [x] All permissions added
- [x] Background modes configured
- [x] ATS configured correctly

### **Build Settings**
- [x] Deployment target: 12.0
- [x] Swift version: 5.0
- [x] Architectures: arm64

### **Permissions**
- [x] Location permission configured
- [x] Camera permission configured
- [x] Photo library configured
- [x] Notifications configured

### **Security**
- [x] Keychain entitlements
- [x] ATS configuration
- [x] HTTPS enforcement

---

## 📞 Troubleshooting

### **Common Issues**

**Workspace won't open:**
```bash
cd ios
rm -rf Runner.xcworkspace
pod install
```

**Build errors:**
```bash
flutter clean
cd ios
pod deintegrate
pod install
flutter run
```

**Permission denied:**
- Check Info.plist entries
- Verify usage descriptions
- Test on real device (simulators may not prompt)

**Archive fails:**
- Check signing certificates
- Verify provisioning profiles
- Ensure bundle ID matches

---

## 📝 Future Enhancements

### **Phase 1**
1. Push notification certificates
2. App Store screenshots
3. Privacy policy URL
4. Terms of service URL

### **Phase 2**
1. App Groups (for widgets)
2. Share extension
3. Siri Shortcuts
4. Watch app support

---

## 📚 Resources

### **Apple Documentation**
- [Info.plist Reference](https://developer.apple.com/documentation/bundleresources/information_property_list)
- [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

### **Flutter Documentation**
- [iOS Platform Integration](https://docs.flutter.dev/deployment/ios)
- [Adding iOS Permissions](https://docs.flutter.dev/deployment/ios#review-xcode-project-settings)

---

**Version**: 21.0.0  
**Last Updated**: March 2026  
**Platform**: iOS 12.0+  
**Status**: Production Ready ✅
