# 📱 ASLI App - iOS Profile & Configuration Guide

## Overview

This guide covers the iOS configuration, permissions, and profile features for the ASLI Campus Platform app.

---

## 🔧 iOS Configuration

### **Info.plist Permissions**

The following permissions have been configured for full app functionality:

#### **1. Location Services**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>ASLI needs your location to show your position on the campus map and provide navigation features.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>ASLI needs your location to provide campus navigation and location-based features even when the app is in background.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>ASLI needs your location for campus navigation and nearby features.</string>
```

**Usage:**
- Campus map navigation
- Distance calculation to locations
- "My Location" feature

---

#### **2. Camera**
```xml
<key>NSCameraUsageDescription</key>
<string>ASLI needs camera access to take photos for posts, profile pictures, and sharing campus moments.</string>
```

**Usage:**
- Profile picture capture
- Post photos
- Story creation

---

#### **3. Photo Library**
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>ASLI needs photo library access to select images for posts, profile pictures, and sharing.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>ASLI needs permission to save images to your photo library.</string>
```

**Usage:**
- Select profile pictures
- Upload post images
- Save shared content

---

#### **4. Microphone** (Future)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>ASLI needs microphone access for voice messages and audio features.</string>
```

**Usage:**
- Voice messages in chat
- Audio notes
- Future audio features

---

#### **5. Background Modes**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

**Usage:**
- Push notifications
- Background data fetch
- Real-time message updates

---

#### **6. App Transport Security**
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

**Usage:**
- Allow HTTP for local development
- Enforce HTTPS in production
- Secure network communication

---

### **Workspace Settings**

**File:** `WorkspaceSettings.xcsettings`

```xml
<key>PreviewsEnabled</key>
<false/>
<key>IDEWorkspaceSharedSettings_AutocreateContextsIfNeeded</key>
<false/>
```

**Purpose:**
- Disable Swift previews (not needed for Flutter)
- Prevent automatic context creation

---

## 👤 Profile Features

### **Profile Screen Features**

**Location:** `lib/screens/profile_screen.dart`

**Features:**
- ✅ User avatar with custom color
- ✅ Name, username, email display
- ✅ Department & Year info
- ✅ Bio section
- ✅ Stats (Followers, Following, Posts)
- ✅ Edit profile button
- ✅ Bookmarks access
- ✅ Notifications access
- ✅ Pull-to-refresh
- ✅ Loading states

**Stats Display:**
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    _statItem('Followers', followerCount),
    _statItem('Following', followingCount),
    _statItem('Posts', postCount),
  ],
)
```

---

### **Edit Profile Screen**

**Location:** `lib/screens/edit_profile_screen.dart`

**Features:**
- ✅ Avatar preview with live update
- ✅ Profile color picker (10 colors)
- ✅ Name editing
- ✅ Bio editing (max 160 chars)
- ✅ Department editing
- ✅ Year editing
- ✅ Save validation
- ✅ Loading states
- ✅ Success/Error feedback

**Color Options:**
```dart
final _colorOptions = [
  '#A9523C', // Heritage Maroon (default)
  '#E11D48', // Rose
  '#059669', // Emerald
  '#D97706', // Amber
  '#7C3AED', // Violet
  '#4F46E5', // Indigo
  '#0EA5E9', // Sky
  '#DC2626', // Red
  '#16A34A', // Green
  '#9333EA', // Purple
];
```

---

## 🔐 Android Configuration

### **AndroidManifest.xml Permissions**

**Location:** `android/app/src/main/AndroidManifest.xml`

```xml
<!-- Location -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Camera -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Storage -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<!-- Internet -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- Notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

---

## 🎨 Profile Customization

### **Avatar System**

**Features:**
- Initial-based avatar
- Custom color selection
- Gradient backgrounds
- Shadow effects
- Rounded square design

**Implementation:**
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [profileColor, profileColor.withAlpha(180)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: profileColor.withAlpha(60),
        blurRadius: 16,
        offset: Offset(0, 6),
      ),
    ],
  ),
  child: Text(name[0].toUpperCase()),
)
```

---

### **Profile Color Psychology**

| Color | Hex | Meaning |
|-------|-----|---------|
| **Heritage Maroon** | #A9523C | Traditional, Classic |
| **Rose** | #E11D48 | Energetic, Passionate |
| **Emerald** | #059669 | Growth, Harmony |
| **Amber** | #D97706 | Creativity, Warmth |
| **Violet** | #7C3AED | Luxury, Wisdom |
| **Indigo** | #4F46E5 | Trust, Loyalty |
| **Sky** | #0EA5E9 | Freedom, Clarity |
| **Red** | #DC2626 | Bold, Confident |
| **Green** | #16A34A | Fresh, Natural |
| **Purple** | #9333EA | Royal, Ambitious |

---

## 📊 Profile Stats

### **Tracked Metrics**

| Metric | Source | Update Frequency |
|--------|--------|------------------|
| **Followers** | CollxFollow count | Real-time |
| **Following** | CollxFollow count | Real-time |
| **Posts** | CollxPost count | Real-time |
| **Bookmarks** | Bookmark count | On view |
| **Notifications** | Notification count | Real-time |

---

## 🔧 API Integration

### **Profile Endpoints**

**Get Profile:**
```
GET /api/auth/me
Authorization: Bearer <token>

Response:
{
  "success": true,
  "user": {
    "id": 1,
    "name": "John Doe",
    "username": "johndoe",
    "email": "john@university.edu",
    "department": "CSE",
    "year": "3rd",
    "bio": "CSE student",
    "profile_color": "#4F46E5",
    "follower_count": 45,
    "following_count": 32,
    "post_count": 23
  }
}
```

**Update Profile:**
```
PUT /api/auth/me
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "John Doe",
  "bio": "Updated bio",
  "department": "CSE",
  "year": "4th",
  "profile_color": "#7C3AED"
}
```

---

## 🎯 User Experience

### **Profile Flow**

```
1. User opens app
   ↓
2. Navigate to Profile tab
   ↓
3. View profile stats & info
   ↓
4. Tap "Edit Profile"
   ↓
5. Update details
   ↓
6. Select color
   ↓
7. Save changes
   ↓
8. Return to profile with updates
```

---

### **Edit Profile Flow**

```
1. Tap Edit Profile button
   ↓
2. Form loads with current data
   ↓
3. User modifies fields
   ↓
4. Preview updates in real-time
   ↓
5. Select new color (optional)
   ↓
6. Tap Save
   ↓
7. Validation runs
   ↓
8. API call made
   ↓
9. Success/Error feedback
   ↓
10. Return to profile
```

---

## 📱 Platform-Specific Features

### **iOS Specific**

- ✅ Native status bar styling
- ✅ Safe area handling
- ✅ iOS-style alerts
- ✅ Pull-to-refresh
- ✅ Haptic feedback (future)
- ✅ Share sheet integration

### **Android Specific**

- ✅ Material Design
- ✅ Back button handling
- ✅ Android-style dialogs
- ✅ Permission handling
- ✅ Deep linking (future)

---

## 🔒 Privacy & Security

### **Data Protection**

- ✅ JWT token authentication
- ✅ Secure token storage (Keychain/Keystore)
- ✅ HTTPS for all API calls
- ✅ Input validation
- ✅ XSS prevention

### **Permission Handling**

- ✅ Runtime permission requests
- ✅ Permission denial handling
- ✅ Settings redirect for denied permissions
- ✅ Graceful degradation

---

## 🧪 Testing Checklist

### **Profile Screen**
- [ ] Avatar displays correctly
- [ ] Stats load accurately
- [ ] Edit button works
- [ ] Pull-to-refresh works
- [ ] Loading states show
- [ ] Error handling works

### **Edit Profile**
- [ ] Form pre-fills correctly
- [ ] Color picker works
- [ ] Preview updates live
- [ ] Validation works
- [ ] Save succeeds
- [ ] Error handling works
- [ ] Cancel works

### **Permissions**
- [ ] Location permission requested
- [ ] Camera permission requested
- [ ] Photo library requested
- [ ] Denial handled gracefully
- [ ] Settings redirect works

---

## 🚀 Build Configuration

### **iOS Build Settings**

**File:** `ios/Runner.xcodeproj/project.pbxproj`

**Key Settings:**
- Deployment Target: iOS 12.0+
- Swift Version: 5.0
- Bitcode: Disabled
- Architecture: arm64

### **Android Build Settings**

**File:** `android/app/build.gradle`

**Key Settings:**
- minSdkVersion: 21
- targetSdkVersion: 34
- compileSdkVersion: 34
- ndkVersion: 23.1.7779620

---

## 📞 Support

### **Common Issues**

**Profile not loading:**
- Check JWT token validity
- Verify API connection
- Check user authentication

**Permissions denied:**
- Guide user to Settings
- Explain why permission needed
- Handle gracefully

**Color not saving:**
- Check API response
- Verify color format (#RRGGBB)
- Check network connection

---

## 📝 Future Enhancements

### **Phase 1**
1. Profile picture upload
2. Cover photo
3. QR code profile sharing
4. Profile verification badge

### **Phase 2**
1. Profile themes
2. Custom backgrounds
3. Achievement badges
4. Activity timeline

---

**Version**: 21.0.0  
**Last Updated**: March 2026  
**Platform**: iOS & Android  
**Status**: Production Ready ✅
