# 🗺️ ASLI Campus Map - Complete Feature Documentation

## Overview

The ASLI Campus Map is a **comprehensive, offline-first navigation system** for Andhra University Campus, featuring:

- ✅ **Real-time location tracking**
- ✅ **50+ campus locations** mapped with coordinates
- ✅ **Category-based filtering** (Academic, Hostels, Libraries, Sports, etc.)
- ✅ **Search functionality** with instant results
- ✅ **Distance calculation** from user's location
- ✅ **Walking time estimates**
- ✅ **Google Maps integration** for turn-by-turn directions
- ✅ **Offline support** with cached locations
- ✅ **Connectivity monitoring**
- ✅ **Dark/Light theme** support
- ✅ **Campus boundary** visualization
- ✅ **Multiple map types** (Normal, Satellite, Terrain, Hybrid)

---

## 📊 Features Summary

### **Mapped Locations (50+)**

| Category | Count | Examples |
|----------|-------|----------|
| 🎓 **Academic** | 20 | Engineering, Science, Arts, Law, Pharmacy colleges |
| 🏛️ **Administration** | 8 | VC Office, Exams, Finance, Placement Cell |
| 🏠 **Hostels** | 11 | Boys, Girls, International, Research hostels |
| 📚 **Libraries** | 5 | Central Library, Engineering, Law libraries |
| 🏆 **Sports** | 6 | Stadiums, Gym, Swimming Pool, Grounds |
| 🏛️ **Landmarks** | 13 | Auditorium, Canteens, Health Centres, Banks |

### **Key Features**

1. **Interactive Map**
   - Google Maps integration
   - Real-time user location
   - Custom markers with colors
   - Campus boundary polygon
   - Multiple map types

2. **Search & Filter**
   - Search by name, description, category
   - Filter by category chips
   - Instant search results dropdown
   - Distance-sorted results

3. **Navigation**
   - Distance calculation (meters/km)
   - Walking time estimates
   - Google Maps directions
   - "My Location" button
   - "Campus Centre" button

4. **Offline Support**
   - All locations cached locally
   - Works without internet
   - Connectivity status banner
   - Graceful degradation

5. **UX Enhancements**
   - Pull-to-refresh
   - Smooth animations
   - Haptic feedback
   - Loading states
   - Error handling

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Flutter Map Screen                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Google Maps Widget                               │  │
│  │  - Markers (50+ locations)                        │  │
│  │  - Polygons (Campus boundary)                     │  │
│  │  - Polylines (Routes - future)                    │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Search & Filter                                  │  │
│  │  - Search bar with autocomplete                   │  │
│  │  - Category chips                                 │  │
│  │  - Results dropdown                               │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Connectivity Manager                             │  │
│  │  - Online/Offline detection                       │  │
│  │  - Status banner                                  │  │
│  └───────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │  Location Services     │
        │  - GPS (Geolocator)    │
        │  - Distance calc       │
        └────────────────────────┘
```

---

## 📱 Usage Guide

### **For Students**

1. **Find a Building**
   - Open Map screen from bottom navigation
   - Use search bar or category filters
   - Tap on marker for details
   - Get walking directions

2. **Navigate to Location**
   - Search for destination
   - Tap "Navigate" button
   - Opens Google Maps with directions
   - Follow turn-by-turn navigation

3. **Explore Campus**
   - Browse different categories
   - Discover facilities (libraries, sports, etc.)
   - Check opening hours
   - See distance from current location

### **For Visitors**

1. **Orient Yourself**
   - Tap "My Location" button
   - See campus layout
   - Find nearest gate/entrance

2. **Find Key Locations**
   - Use "Landmarks" filter
   - Locate admin buildings
   - Find parking areas

---

## 🔧 Technical Implementation

### **Dependencies**

```yaml
google_maps_flutter: ^2.9.0
geolocator: ^13.0.0
url_launcher: ^6.3.0
connectivity_plus: ^6.1.0
```

### **Key Components**

#### **1. Location Data Structure**
```dart
Map<String, dynamic> {
  "name": String,       // Location name
  "lat": double,        // Latitude
  "lng": double,        // Longitude
  "icon": IconData,     // Material icon
  "category": String,   // Category (academic, hostel, etc.)
  "desc": String,       // Description
  "hours": String,      // Opening hours
}
```

#### **2. Markers**
```dart
Marker(
  markerId: MarkerId(location['name']),
  position: LatLng(location['lat'], location['lng']),
  icon: BitmapDescriptor.defaultMarkerWithHue(hue),
  infoWindow: InfoWindow(title: name, snippet: desc),
  onTap: () => showDetails(),
)
```

#### **3. Distance Calculation**
```dart
double _distanceBetween(lat1, lng1, lat2, lng2) {
  const R = 6371000.0; // Earth radius in meters
  // Haversine formula
  return R * c; // Distance in meters
}
```

#### **4. Connectivity Monitoring**
```dart
_connectivitySubscription = ConnectivityManager.instance
    .stateStream.listen((state) {
  setState(() {
    _isConnected = state == NetConnectionState.connected;
  });
});
```

---

## 🎨 UI/UX Features

### **Color-Coded Categories**

| Category | Color | Hue |
|----------|-------|-----|
| Academic | Teal | Cyan |
| Admin | Indigo | Violet |
| Hostels | Sage | Green |
| Libraries | Plum | Magenta |
| Sports | Amber | Orange |
| Landmarks | Coral | Rose |

### **Interactive Elements**

1. **Search Bar**
   - Floating design
   - Real-time search
   - Clear button
   - Results dropdown

2. **Category Chips**
   - Horizontal scroll
   - Shows count per category
   - Active state highlighting
   - Icon for each category

3. **Floating Action Buttons**
   - My Location (bottom-right)
   - Campus Centre (above)
   - Custom design

4. **Stats Badge**
   - Shows total locations
   - Floating design
   - Updates with filter

---

## 📡 Offline Support

### **What Works Offline**

✅ All 50+ location markers  
✅ Search functionality  
✅ Category filtering  
✅ Distance calculation  
✅ Campus boundary  
✅ Location details  

### **What Requires Internet**

❌ Live GPS location (cached last known)  
❌ Google Maps tiles (if not cached)  
❌ Google Maps directions  
❌ Real-time traffic  

### **Offline Indicators**

- Red banner at top: "Offline Mode"
- Grayed out "My Location" button
- Tooltip explaining limitations

---

## 🔐 Privacy & Permissions

### **Required Permissions**

**Android (`AndroidManifest.xml`):**
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

**iOS (`Info.plist`):**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs your location to show your position on campus map.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>For navigation features.</string>
```

### **Privacy Features**

- Location only used for distance calculation
- No location data sent to server
- No tracking or analytics
- User can deny location permission (map still works)

---

## 🚀 Performance Optimization

### **Marker Management**

- **Lazy Loading**: Only build visible markers
- **Clustering**: (Future) Group nearby markers
- **Caching**: Store marker icons
- **Filtering**: Rebuild only on filter change

### **Search Optimization**

- **Debouncing**: Wait 300ms after typing
- **Case-insensitive**: Better matching
- **Multiple fields**: Search name, desc, category
- **Sorted by distance**: Most relevant first

### **Memory Management**

- Dispose controllers in `dispose()`
- Cancel subscriptions
- Clear caches on memory warning
- Use `const` where possible

---

## 🧪 Testing Checklist

- [ ] Map loads correctly
- [ ] All 50+ markers appear
- [ ] Markers have correct colors
- [ ] Search works (online & offline)
- [ ] Filters work correctly
- [ ] Distance calculation accurate
- [ ] "My Location" button works
- [ ] Google Maps directions open
- [ ] Offline mode shows banner
- [ ] Dark theme works
- [ ] List view works
- [ ] Campus boundary visible
- [ ] All categories have icons
- [ ] Opening hours display correctly

---

## 🔮 Future Enhancements

### **Phase 1 (Next Sprint)**

1. **Indoor Maps**
   - Building floor plans
   - Room-level navigation
   - Department locations

2. **Route Planning**
   - Walking paths on campus
   - Shortest route calculation
   - Accessible routes

3. **Real-time Updates**
   - Crowd levels
   - Facility availability
   - Event locations

### **Phase 2 (Future)**

1. **AR Navigation**
   - Augmented reality directions
   - Camera overlay
   - Points of interest

2. **Social Features**
   - Share location with friends
   - Meetup points
   - Popular spots

3. **Accessibility**
   - Wheelchair accessible routes
   - Audio guidance
   - Larger text option

---

## 📞 Support & Feedback

### **Report Issues**

- Missing locations
- Incorrect coordinates
- Wrong opening hours
- Accessibility issues

### **Suggest Improvements**

- New features
- UI/UX enhancements
- Performance improvements

**Contact:** support@asli-campus.com

---

## 📝 Setup Instructions

### **1. Get Google Maps API Key**

See `GOOGLE_MAPS_SETUP.md` for detailed instructions.

### **2. Add API Key**

**Android:** `android/app/src/main/AndroidManifest.xml`
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY" />
```

**iOS:** `ios/Runner/AppDelegate.swift`
```swift
GMSServices.provideAPIKey("YOUR_API_KEY")
```

### **3. Run the App**

```bash
flutter pub get
flutter run
```

---

## 📊 Usage Analytics (Future)

Track anonymously:
- Most searched locations
- Popular categories
- Peak usage times
- Navigation requests

**Privacy-first:**
- No personal data collected
- Aggregated statistics only
- Opt-in option

---

**Version**: 21.0.0  
**Last Updated**: March 2026  
**Status**: Production Ready ✅
