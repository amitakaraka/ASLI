import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/connectivity_manager.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();
  Position? _userPosition;
  bool _isLoadingLocation = true;
  String? _locationError;
  String _selectedFilter = 'all';
  MapType _mapType = MapType.normal;
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  Set<Polyline> _polylines = {};
  bool _showListView = false;
  bool _showCampusBoundary = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  // Connectivity & Offline Support
  bool _isConnected = true;
  StreamSubscription? _connectivitySubscription;
  
  // Animation controllers
  late AnimationController _locationAnimController;

  // Andhra University Campus Centre — Real coordinates
  static const LatLng _auCenter = LatLng(17.7306, 83.3228);

  static const CameraPosition _initialCamera = CameraPosition(
    target: _auCenter,
    zoom: 15.8,
  );

  // AU Campus Boundary Polygon (approximate)
  final List<LatLng> _campusBoundary = const [
    LatLng(17.7350, 83.3160),
    LatLng(17.7355, 83.3200),
    LatLng(17.7350, 83.3250),
    LatLng(17.7340, 83.3285),
    LatLng(17.7320, 83.3295),
    LatLng(17.7295, 83.3290),
    LatLng(17.7260, 83.3280),
    LatLng(17.7240, 83.3285),
    LatLng(17.7235, 83.3270),
    LatLng(17.7240, 83.3240),
    LatLng(17.7245, 83.3200),
    LatLng(17.7250, 83.3170),
    LatLng(17.7265, 83.3155),
    LatLng(17.7290, 83.3150),
    LatLng(17.7320, 83.3155),
    LatLng(17.7340, 83.3155),
  ];

  // REAL AU CAMPUS LOCATIONS
  final List<Map<String, dynamic>> campusLocations = [
    // Colleges
    {"name": "AU College of Engineering (AUCE)",    "lat": 17.7319, "lng": 83.3216, "icon": Icons.engineering_rounded,    "category": "academic", "desc": "Established 1946 — CSE, ECE, EEE, Mech, Civil, Geo-Eng, Chemical, IT, Marine", "hours": "9 AM – 5 PM"},
    {"name": "AU College of Engg. for Women",       "lat": 17.7335, "lng": 83.3205, "icon": Icons.engineering_rounded,    "category": "academic", "desc": "Women's engineering college — all major branches", "hours": "9 AM – 5 PM"},
    {"name": "AU College of Science & Technology",   "lat": 17.7290, "lng": 83.3250, "icon": Icons.science_rounded,       "category": "academic", "desc": "Physics, Chemistry, Maths, Botany, Zoology, Biochemistry, Biotechnology, Microbiology, Statistics", "hours": "9 AM – 5 PM"},
    {"name": "AU College of Arts & Commerce",        "lat": 17.7280, "lng": 83.3200, "icon": Icons.palette_rounded,       "category": "academic", "desc": "Commerce, Economics, English, Telugu, History, Political Science, Sociology, Psychology, Philosophy", "hours": "9 AM – 5 PM"},
    {"name": "AU College of Pharmaceutical Sciences","lat": 17.7310, "lng": 83.3190, "icon": Icons.local_pharmacy_rounded,"category": "academic", "desc": "B.Pharm, M.Pharm, Pharm.D, Ph.D programs", "hours": "9 AM – 5 PM"},
    {"name": "Dr. B.R. Ambedkar College of Law",    "lat": 17.7275, "lng": 83.3220, "icon": Icons.gavel_rounded,         "category": "academic", "desc": "LLB (3yr & 5yr), LLM, Integrated Law programs", "hours": "9 AM – 5 PM"},

    // Departments
    {"name": "Dept. of Computer Science & SE",       "lat": 17.7315, "lng": 83.3225, "icon": Icons.computer_rounded,        "category": "academic", "desc": "B.Tech, M.Tech, MCA, Ph.D in Computer Science", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Electronics & Comm. Engg.",   "lat": 17.7322, "lng": 83.3210, "icon": Icons.memory_rounded,          "category": "academic", "desc": "B.Tech, M.Tech ECE — VLSI, Signal Processing", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Electrical Engineering",      "lat": 17.7325, "lng": 83.3220, "icon": Icons.electrical_services_rounded,"category": "academic", "desc": "B.Tech, M.Tech EEE — Power Systems, Control Systems", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Mechanical Engineering",      "lat": 17.7318, "lng": 83.3230, "icon": Icons.precision_manufacturing_rounded,"category": "academic", "desc": "B.Tech, M.Tech Mech — Design, Production, Thermal", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Civil Engineering",           "lat": 17.7312, "lng": 83.3235, "icon": Icons.architecture_rounded,    "category": "academic", "desc": "B.Tech, M.Tech Civil — Structural, Environmental", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Physics",                     "lat": 17.7295, "lng": 83.3245, "icon": Icons.waves_rounded,           "category": "academic", "desc": "M.Sc, M.Phil, Ph.D — Nuclear, Optical, Condensed Matter", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Chemistry",                   "lat": 17.7292, "lng": 83.3255, "icon": Icons.biotech_rounded,         "category": "academic", "desc": "M.Sc, M.Phil, Ph.D — Organic, Inorganic, Analytical", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Mathematics",                 "lat": 17.7288, "lng": 83.3260, "icon": Icons.calculate_rounded,       "category": "academic", "desc": "M.Sc, M.Phil, Ph.D in Mathematics", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Commerce & Management",       "lat": 17.7278, "lng": 83.3208, "icon": Icons.business_rounded,        "category": "academic", "desc": "B.Com, M.Com, MBA — Finance, Marketing, HR", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Economics",                   "lat": 17.7282, "lng": 83.3195, "icon": Icons.trending_up_rounded,     "category": "academic", "desc": "MA, M.Phil, Ph.D in Economics", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of English",                     "lat": 17.7285, "lng": 83.3210, "icon": Icons.menu_book_rounded,       "category": "academic", "desc": "MA, M.Phil, Ph.D in English Literature", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Journalism & Mass Comm.",     "lat": 17.7276, "lng": 83.3215, "icon": Icons.newspaper_rounded,       "category": "academic", "desc": "MA, Ph.D — Print, Electronic, Digital Media", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Marine Living Resources",     "lat": 17.7330, "lng": 83.3240, "icon": Icons.water_rounded,           "category": "academic", "desc": "M.Sc, Ph.D — Marine Biology, Fisheries Science", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Geo-Engineering",             "lat": 17.7316, "lng": 83.3240, "icon": Icons.terrain_rounded,         "category": "academic", "desc": "B.Tech, M.Tech — Mining, Petroleum, Geophysics", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Anthropology",                "lat": 17.7273, "lng": 83.3198, "icon": Icons.people_alt_rounded,      "category": "academic", "desc": "MA, M.Phil, Ph.D in Social & Physical Anthropology", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Education",                   "lat": 17.7270, "lng": 83.3205, "icon": Icons.school_rounded,          "category": "academic", "desc": "B.Ed, M.Ed, Ph.D — Teacher Education", "hours": "9 AM – 5 PM"},
    {"name": "Dept. of Yoga",                        "lat": 17.7268, "lng": 83.3195, "icon": Icons.self_improvement_rounded,"category": "academic", "desc": "MA, Diploma in Yoga Science", "hours": "6 AM – 8 AM, 4 PM – 6 PM"},

    // Admin buildings
    {"name": "Administrative Building (VC Office)",  "lat": 17.7300, "lng": 83.3230, "icon": Icons.account_balance_rounded,   "category": "admin", "desc": "Vice-Chancellor's Office, Registrar, Administrative Block", "hours": "10 AM – 5 PM"},
    {"name": "Examination Branch",                   "lat": 17.7296, "lng": 83.3238, "icon": Icons.assignment_rounded,        "category": "admin", "desc": "Controller of Examinations — Results, Hall Tickets", "hours": "10 AM – 5 PM"},
    {"name": "CDOE (Distance Education)",            "lat": 17.7265, "lng": 83.3185, "icon": Icons.cast_for_education_rounded,"category": "admin", "desc": "Centre for Distance & Online Education", "hours": "10 AM – 5 PM"},
    {"name": "AU Main Gate (South Campus)",          "lat": 17.7275, "lng": 83.3185, "icon": Icons.door_front_door_rounded,   "category": "admin", "desc": "Primary entrance from Waltair Junction side", "hours": "24 hours"},
    {"name": "AU North Campus Gate",                 "lat": 17.7340, "lng": 83.3200, "icon": Icons.door_sliding_rounded,      "category": "admin", "desc": "Engineering and North Campus entrance", "hours": "24 hours"},
    {"name": "Finance Section",                      "lat": 17.7298, "lng": 83.3225, "icon": Icons.payments_rounded,          "category": "admin", "desc": "Fee payments, scholarships, financial matters", "hours": "10 AM – 4 PM"},
    {"name": "AU Post Office",                       "lat": 17.7293, "lng": 83.3220, "icon": Icons.local_post_office_rounded, "category": "admin", "desc": "Campus post office — Waltair P.O.", "hours": "9 AM – 5 PM"},
    {"name": "Placement Cell",                       "lat": 17.7305, "lng": 83.3210, "icon": Icons.work_rounded,              "category": "admin", "desc": "University Placement & Training Cell", "hours": "10 AM – 5 PM"},

    // Hostels
    {"name": "Arts & Commerce Hostel (Boys)",        "lat": 17.7265, "lng": 83.3230, "icon": Icons.hotel_rounded, "category": "hostel", "desc": "Men's hostel for Arts & Commerce students", "hours": "24 hours"},
    {"name": "Science & Technology Hostel (Boys)",   "lat": 17.7285, "lng": 83.3270, "icon": Icons.hotel_rounded, "category": "hostel", "desc": "Men's hostel for Science & Tech students", "hours": "24 hours"},
    {"name": "Engineering Hostel (Boys)",            "lat": 17.7340, "lng": 83.3230, "icon": Icons.hotel_rounded, "category": "hostel", "desc": "Men's hostel within AUCE campus", "hours": "24 hours"},
    {"name": "Engineering Hostel (Girls)",           "lat": 17.7338, "lng": 83.3210, "icon": Icons.hotel_rounded, "category": "hostel", "desc": "Women's hostel within AUCE campus", "hours": "24 hours"},
    {"name": "Ladies Hostel (Maharanipeta)",         "lat": 17.7255, "lng": 83.3175, "icon": Icons.hotel_rounded, "category": "hostel", "desc": "Women's hostel near Maharanipeta area", "hours": "24 hours"},
    {"name": "PG Ladies Hostel",                     "lat": 17.7260, "lng": 83.3190, "icon": Icons.hotel_rounded, "category": "hostel", "desc": "Postgraduate women's hostel", "hours": "24 hours"},
    {"name": "Law Hostel",                           "lat": 17.7270, "lng": 83.3225, "icon": Icons.hotel_rounded, "category": "hostel", "desc": "Hostel for Law students", "hours": "24 hours"},
    {"name": "International Students Hostel",        "lat": 17.7252, "lng": 83.3235, "icon": Icons.hotel_rounded, "category": "hostel", "desc": "Accommodation for international students", "hours": "24 hours"},
    {"name": "Research Hostel",                      "lat": 17.7258, "lng": 83.3250, "icon": Icons.hotel_rounded, "category": "hostel", "desc": "Hostel for research scholars", "hours": "24 hours"},
    {"name": "Vidya Tarangini Vihar",                "lat": 17.7248, "lng": 83.3220, "icon": Icons.hotel_rounded, "category": "hostel", "desc": "SC/ST welfare hostel facility", "hours": "24 hours"},
    {"name": "Vidya Pragathi Hostel",                "lat": 17.7250, "lng": 83.3210, "icon": Icons.hotel_rounded, "category": "hostel", "desc": "SC/ST welfare hostel facility", "hours": "24 hours"},

    // Libraries
    {"name": "Dr. V.S. Krishna Library",             "lat": 17.7242, "lng": 83.3276, "icon": Icons.local_library_rounded, "category": "library", "desc": "Central Library — 4+ lakh books, rare manuscripts, digital section", "hours": "9 AM – 8 PM"},
    {"name": "Engineering Library",                  "lat": 17.7320, "lng": 83.3218, "icon": Icons.auto_stories_rounded,  "category": "library", "desc": "AUCE departmental library — technical books & journals", "hours": "9 AM – 5 PM"},
    {"name": "Law Library",                          "lat": 17.7274, "lng": 83.3222, "icon": Icons.auto_stories_rounded,  "category": "library", "desc": "Dr. B.R. Ambedkar College of Law library", "hours": "9 AM – 5 PM"},
    {"name": "AU Innovation & Incubation Centre",    "lat": 17.7308, "lng": 83.3195, "icon": Icons.rocket_launch_rounded, "category": "library", "desc": "Startup incubation & innovation hub — AICTE supported", "hours": "10 AM – 6 PM"},
    {"name": "AURC (Research Centre)",               "lat": 17.7302, "lng": 83.3245, "icon": Icons.biotech_rounded,       "category": "library", "desc": "Central research instrumentation facility", "hours": "9 AM – 5 PM"},

    // Sports facilities
    {"name": "Silver Jubilee Playground",            "lat": 17.7310, "lng": 83.3260, "icon": Icons.sports_cricket_rounded,    "category": "sports", "desc": "Cricket, Football, Athletics — main sports ground", "hours": "6 AM – 6 PM"},
    {"name": "Golden Jubilee Playground",            "lat": 17.7315, "lng": 83.3270, "icon": Icons.sports_soccer_rounded,     "category": "sports", "desc": "Additional sports ground for collegiate events", "hours": "6 AM – 6 PM"},
    {"name": "AU Gymnasium",                         "lat": 17.7308, "lng": 83.3255, "icon": Icons.fitness_center_rounded,    "category": "sports", "desc": "Indoor gymnasium — weightlifting, fitness training", "hours": "6 AM – 9 AM, 4 PM – 7 PM"},
    {"name": "Swimming Pool",                        "lat": 17.7305, "lng": 83.3265, "icon": Icons.pool_rounded,              "category": "sports", "desc": "University swimming pool facility", "hours": "6 AM – 8 AM, 4 PM – 6 PM"},
    {"name": "Dept. of Physical Education",          "lat": 17.7312, "lng": 83.3265, "icon": Icons.sports_handball_rounded,   "category": "sports", "desc": "B.P.Ed, M.P.Ed, Sports authority office", "hours": "9 AM – 5 PM"},
    {"name": "Indoor Stadium",                       "lat": 17.7306, "lng": 83.3270, "icon": Icons.sports_basketball_rounded, "category": "sports", "desc": "Badminton, Table Tennis, Volleyball — indoor courts", "hours": "6 AM – 8 PM"},

    // Other landmarks
    {"name": "AU Convocation Hall / Auditorium",     "lat": 17.7295, "lng": 83.3235, "icon": Icons.theater_comedy_rounded, "category": "landmark", "desc": "Annual convocation, cultural events & conferences", "hours": "Event-based"},
    {"name": "Centenary Celebrations Block",         "lat": 17.7300, "lng": 83.3215, "icon": Icons.celebration_rounded,    "category": "landmark", "desc": "AU Centenary (1926-2026) — exhibitions & events", "hours": "10 AM – 5 PM"},
    {"name": "AU Canteen (South Campus)",            "lat": 17.7280, "lng": 83.3230, "icon": Icons.restaurant_rounded,     "category": "landmark", "desc": "Main campus food court — South Campus", "hours": "8 AM – 8 PM"},
    {"name": "Engineering Canteen",                  "lat": 17.7325, "lng": 83.3215, "icon": Icons.restaurant_rounded,     "category": "landmark", "desc": "AUCE campus food court — North Campus", "hours": "8 AM – 7 PM"},
    {"name": "Health Centre (North)",                "lat": 17.7330, "lng": 83.3225, "icon": Icons.local_hospital_rounded, "category": "landmark", "desc": "Allopathic medical centre — North Campus", "hours": "9 AM – 1 PM, 2 PM – 5 PM"},
    {"name": "Health Centre (South)",                "lat": 17.7272, "lng": 83.3230, "icon": Icons.local_hospital_rounded, "category": "landmark", "desc": "Allopathic medical centre — South Campus", "hours": "9 AM – 1 PM, 2 PM – 5 PM"},
    {"name": "SBI Branch (AU Campus)",               "lat": 17.7290, "lng": 83.3225, "icon": Icons.account_balance_rounded,"category": "landmark", "desc": "State Bank of India — campus branch", "hours": "10 AM – 4 PM"},
    {"name": "AU Guest House",                       "lat": 17.7260, "lng": 83.3200, "icon": Icons.villa_rounded,          "category": "landmark", "desc": "University guest house for visitors", "hours": "24 hours"},
    {"name": "AU Botanical Garden",                  "lat": 17.7245, "lng": 83.3260, "icon": Icons.park_rounded,           "category": "landmark", "desc": "Botanical garden with diverse plant species", "hours": "9 AM – 5 PM"},
    {"name": "Waltair Junction (Railway)",           "lat": 17.7275, "lng": 83.3170, "icon": Icons.train_rounded,          "category": "landmark", "desc": "Nearest railway station — 500m from AU Main Gate", "hours": "24 hours"},
    {"name": "Cyber Laboratory",                     "lat": 17.7286, "lng": 83.3212, "icon": Icons.laptop_rounded,         "category": "landmark", "desc": "Free internet facility for students", "hours": "9 AM – 7 PM"},
    {"name": "Homeopathic Medical Centre",           "lat": 17.7290, "lng": 83.3215, "icon": Icons.healing_rounded,        "category": "landmark", "desc": "Homeopathic care near Telegraph Office", "hours": "10 AM – 4 PM"},
  ];

  final Map<String, Color> categoryColors = {
    'all':      AsliColors.primaryMaroon,
    'academic': AsliColors.accentTeal,
    'admin':    AsliColors.accentIndigo,
    'hostel':   AsliColors.accentSage,
    'library':  AsliColors.accentPlum,
    'sports':   AsliColors.accentAmber,
    'landmark': AsliColors.accentCoral,
  };

  final Map<String, String> categoryLabels = {
    'all': 'All', 'academic': 'Academic', 'admin': 'Admin',
    'hostel': 'Hostels', 'library': 'Libraries', 'sports': 'Sports', 'landmark': 'Landmarks',
  };

  double _colorToHue(Color c) {
    if (c == AsliColors.accentTeal)    return BitmapDescriptor.hueCyan;
    if (c == AsliColors.accentIndigo)  return BitmapDescriptor.hueViolet;
    if (c == AsliColors.accentSage)    return BitmapDescriptor.hueGreen;
    if (c == AsliColors.accentAmber)   return BitmapDescriptor.hueOrange;
    if (c == AsliColors.accentCoral)   return BitmapDescriptor.hueRose;
    if (c == AsliColors.accentPlum)    return BitmapDescriptor.hueMagenta;
    return BitmapDescriptor.hueRed;
  }

  List<Map<String, dynamic>> get _filteredLocations {
    var list = campusLocations;
    if (_selectedFilter != 'all') {
      list = list.where((l) => l['category'] == _selectedFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((l) =>
        (l['name'] as String).toLowerCase().contains(q) ||
        (l['desc'] as String).toLowerCase().contains(q) ||
        (l['category'] as String).toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  
  double _distanceBetween(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0; // Earth radius in metres
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _estimateWalkTime(double meters) {
    final mins = (meters / 80).round(); // ~80m/min walking speed
    if (mins < 1) return '< 1 min';
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  double? _distanceToPlace(Map<String, dynamic> place) {
    if (_userPosition == null) return null;
    return _distanceBetween(
      _userPosition!.latitude, _userPosition!.longitude,
      place['lat'], place['lng'],
    );
  }

  List<Map<String, dynamic>> get _sortedByDistance {
    final list = List<Map<String, dynamic>>.from(_filteredLocations);
    if (_userPosition != null) {
      list.sort((a, b) {
        final da = _distanceToPlace(a) ?? double.infinity;
        final db = _distanceToPlace(b) ?? double.infinity;
        return da.compareTo(db);
      });
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupConnectivityListener();
    _buildCampusBoundary();
    _getUserLocation();
  }
  
  void _setupAnimations() {
    _locationAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _locationAnimController, curve: Curves.easeInOut),
    );
  }
  
  void _setupConnectivityListener() {
    _connectivitySubscription = ConnectivityManager.instance.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isConnected = state == NetConnectionState.connected;
        });
      }
    });
  }

  @override
  void dispose() {
    _locationAnimController.dispose();
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _buildCampusBoundary() {
    if (_showCampusBoundary) {
      _polygons = {
        Polygon(
          polygonId: const PolygonId('campus_boundary'),
          points: _campusBoundary,
          strokeColor: AsliColors.primaryMaroon.withAlpha(180),
          strokeWidth: 3,
          fillColor: AsliColors.primaryMaroon.withAlpha(20),
        ),
      };
    } else {
      _polygons = {};
    }
  }

  Future<void> _getUserLocation() async {
    setState(() { _isLoadingLocation = true; _locationError = null; });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        setState(() { _isLoadingLocation = false; _locationError = "Location permission denied"; });
        _buildMarkers();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() { _userPosition = pos; _isLoadingLocation = false; });
    } catch (e) {
      setState(() { _isLoadingLocation = false; _locationError = "Could not get location"; });
    }
    _buildMarkers();
  }

  void _buildMarkers() {
    final Set<Marker> markers = {};
    for (final place in _filteredLocations) {
      final catColor = categoryColors[place['category']] ?? AsliColors.primaryMaroon;
      markers.add(Marker(
        markerId: MarkerId(place['name']),
        position: LatLng(place['lat'], place['lng']),
        icon: BitmapDescriptor.defaultMarkerWithHue(_colorToHue(catColor)),
        infoWindow: InfoWindow(title: place['name'], snippet: place['desc']),
        onTap: () => _showPlaceInfo(place),
      ));
    }
    setState(() => _markers = markers);
  }

  Future<void> _goToMyLocation() async {
    if (_userPosition == null) { _getUserLocation(); return; }
    final ctrl = await _mapController.future;
    ctrl.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(_userPosition!.latitude, _userPosition!.longitude), zoom: 18),
    ));
  }

  Future<void> _goToCampus() async {
    final ctrl = await _mapController.future;
    ctrl.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
  }

  Future<void> _goToPlace(Map<String, dynamic> place) async {
    setState(() => _showListView = false);
    final ctrl = await _mapController.future;
    ctrl.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(place['lat'], place['lng']), zoom: 18, tilt: 45),
    ));
    Future.delayed(const Duration(milliseconds: 500), () => _showPlaceInfo(place));
  }

  Future<void> _openGoogleMapsDirections(Map<String, dynamic> place) async {
    final lat = place['lat'];
    final lng = place['lng'];
    final name = Uri.encodeComponent(place['name']);
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name&travelmode=walking';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _onFilterChange(String filter) {
    setState(() => _selectedFilter = filter);
    _buildMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text("AU Campus Map"),
        actions: [
          // List / Map toggle
          IconButton(
            icon: Icon(_showListView ? Icons.map_rounded : Icons.list_rounded),
            tooltip: _showListView ? 'Map view' : 'List view',
            onPressed: () => setState(() => _showListView = !_showListView),
          ),
          // Map type
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers_rounded),
            tooltip: 'Map options',
            onSelected: (v) {
              if (v == 'normal') setState(() => _mapType = MapType.normal);
              else if (v == 'satellite') setState(() => _mapType = MapType.satellite);
              else if (v == 'terrain') setState(() => _mapType = MapType.terrain);
              else if (v == 'hybrid') setState(() => _mapType = MapType.hybrid);
              else if (v == 'boundary') {
                setState(() {
                  _showCampusBoundary = !_showCampusBoundary;
                  _buildCampusBoundary();
                });
              }
            },
            itemBuilder: (_) => [
              _mapMenuItem('normal',    Icons.map_rounded,           "Normal"),
              _mapMenuItem('satellite', Icons.satellite_rounded,     "Satellite"),
              _mapMenuItem('terrain',   Icons.terrain_rounded,       "Terrain"),
              _mapMenuItem('hybrid',    Icons.satellite_alt_rounded, "Hybrid"),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(value: 'boundary', checked: _showCampusBoundary, child: const Text("Campus Boundary")),
            ],
          ),
          if (_isLoadingLocation)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          else
            IconButton(icon: const Icon(Icons.my_location_rounded), tooltip: 'My location', onPressed: _goToMyLocation),
        ],
      ),
      body: _showListView ? _buildListView() : _buildMapView(),
    );
  }

  PopupMenuItem<String> _mapMenuItem(String value, IconData icon, String label) {
    return PopupMenuItem(value: value, child: Row(children: [Icon(icon, color: context.accent, size: 20), const SizedBox(width: 8), Text(label)]));
  }

  // MAP VIEW
  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
          mapType: _mapType,
          style: context.isDark ? _darkMapStyle : null,
          initialCameraPosition: _initialCamera,
          markers: _markers,
          polygons: _polygons,
          polylines: _polylines,
          myLocationEnabled: _userPosition != null,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          zoomControlsEnabled: false,
          buildingsEnabled: true,
          mapToolbarEnabled: true,
          onMapCreated: (controller) {
            _mapController.complete(controller);
            _buildMarkers();
          },
        ),
        
        
        if (!_isConnected)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AsliColors.statusError,
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 8)],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Offline Mode — Map cached, live location unavailable',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

        
        Positioned(
          top: 12, left: 12, right: 12,
          child: Container(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 10, offset: const Offset(0, 3))],
              border: Border.all(color: context.borderColor),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _buildMarkers();
              },
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search campus locations...',
                hintStyle: TextStyle(color: context.textSecondary, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: context.accent, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close, color: context.textSecondary, size: 20),
                      onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); _buildMarkers(); _searchFocus.unfocus(); },
                    )
                  : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

        
        Positioned(
          top: 72, left: 0, right: 0,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: categoryColors.entries.map((e) {
                final count = e.key == 'all' ? campusLocations.length :
                  campusLocations.where((l) => l['category'] == e.key).length;
                return _filterChip(e.key, '${categoryLabels[e.key]} ($count)', _categoryIcon(e.key));
              }).toList(),
            ),
          ),
        ),

        
        if (_searchQuery.isNotEmpty && _filteredLocations.isNotEmpty)
          Positioned(
            top: 64, left: 12, right: 12,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8)],
                border: Border.all(color: context.borderColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _filteredLocations.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: context.borderColor),
                itemBuilder: (_, i) {
                  final place = _filteredLocations[i];
                  final catColor = categoryColors[place['category']]!;
                  final dist = _distanceToPlace(place);
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(backgroundColor: catColor.withAlpha(25), radius: 18, child: Icon(place['icon'], color: catColor, size: 18)),
                    title: Text(place['name'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
                    subtitle: dist != null ? Text('${_formatDistance(dist)} • ${_estimateWalkTime(dist)} walk', style: TextStyle(fontSize: 11, color: context.textSecondary)) : null,
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textSecondary),
                    onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); _searchFocus.unfocus(); _buildMarkers(); _goToPlace(place); },
                  );
                },
              ),
            ),
          ),

        
        Positioned(
          bottom: 140, right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 8, offset: const Offset(0, 2))],
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_rounded, size: 14, color: context.accent),
                const SizedBox(width: 4),
                Text('${_filteredLocations.length} places',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary)),
              ],
            ),
          ),
        ),

        
        Positioned(bottom: 80, right: 16, child: FloatingActionButton.small(heroTag: 'campus', backgroundColor: context.cardBg, onPressed: _goToCampus, tooltip: 'AU Campus', child: Icon(Icons.school_rounded, color: context.accent))),

        
        Positioned(bottom: 16, right: 16, child: FloatingActionButton(heroTag: 'location', backgroundColor: context.accent, onPressed: _goToMyLocation, tooltip: 'My location', child: const Icon(Icons.my_location_rounded, color: Colors.white))),

        
        Positioned(
          bottom: 16, left: 16,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: context.cardBg.withAlpha(230), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8)], border: Border.all(color: context.borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: categoryColors.entries.where((e) => e.key != 'all').map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: e.value, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(categoryLabels[e.key]!, style: TextStyle(fontSize: 11, color: context.textSecondary)),
                ]),
              )).toList(),
            ),
          ),
        ),

        
        if (_locationError != null)
          Positioned(
            top: 108, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AsliColors.statusWarning.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: AsliColors.statusWarning)),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: AsliColors.statusWarning, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_locationError!, style: TextStyle(fontSize: 12, color: context.textPrimary))),
                GestureDetector(onTap: () => setState(() => _locationError = null), child: Icon(Icons.close, size: 16, color: context.textSecondary)),
              ]),
            ),
          ),
      ],
    );
  }

  // LIST VIEW
  Widget _buildListView() {
    final places = _sortedByDistance;
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: context.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search campus locations...',
              hintStyle: TextStyle(color: context.textSecondary),
              prefixIcon: Icon(Icons.search_rounded, color: context.accent),
              suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(icon: Icon(Icons.close, color: context.textSecondary, size: 20), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                : null,
              filled: true,
              fillColor: context.cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.accent, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: categoryColors.entries.map((e) {
              final count = e.key == 'all' ? campusLocations.length :
                campusLocations.where((l) => l['category'] == e.key).length;
              return _filterChip(e.key, '${categoryLabels[e.key]} ($count)', _categoryIcon(e.key));
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Distance banner
        if (_userPosition != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AsliColors.accentTeal.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: AsliColors.accentTeal.withAlpha(40))),
              child: Row(children: [
                Icon(Icons.near_me_rounded, size: 16, color: AsliColors.accentTeal),
                const SizedBox(width: 8),
                Text("Sorted by distance from you", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AsliColors.accentTeal)),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        // Place list
        Expanded(
          child: places.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off_rounded, size: 48, color: context.textSecondary),
                const SizedBox(height: 12),
                Text("No places found", style: TextStyle(color: context.textSecondary, fontSize: 16)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: places.length,
                itemBuilder: (_, i) => _buildPlaceListTile(places[i]),
              ),
        ),
      ],
    );
  }

  Widget _buildPlaceListTile(Map<String, dynamic> place) {
    final catColor = categoryColors[place['category']]!;
    final dist = _distanceToPlace(place);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _goToPlace(place),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: catColor.withAlpha(20), borderRadius: BorderRadius.circular(14)),
                  child: Icon(place['icon'], color: catColor, size: 24),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place['name'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(place['desc'], style: TextStyle(fontSize: 11, color: context.textSecondary, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: catColor.withAlpha(15), borderRadius: BorderRadius.circular(6)),
                          child: Text(categoryLabels[place['category']]!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: catColor)),
                        ),
                        const SizedBox(width: 8),
                        // Hours
                        Icon(Icons.access_time_rounded, size: 12, color: context.textSecondary),
                        const SizedBox(width: 3),
                        Flexible(child: Text(place['hours'] ?? '', style: TextStyle(fontSize: 10, color: context.textSecondary), overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Distance column
                if (dist != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatDistance(dist), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.accent)),
                      const SizedBox(height: 2),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.directions_walk_rounded, size: 12, color: context.textSecondary),
                        const SizedBox(width: 2),
                        Text(_estimateWalkTime(dist), style: TextStyle(fontSize: 10, color: context.textSecondary)),
                      ]),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'academic': return Icons.school_rounded;
      case 'admin': return Icons.account_balance_rounded;
      case 'hostel': return Icons.hotel_rounded;
      case 'library': return Icons.local_library_rounded;
      case 'sports': return Icons.sports_rounded;
      case 'landmark': return Icons.attractions_rounded;
      default: return Icons.place_rounded;
    }
  }

  Widget _filterChip(String category, String label, IconData icon) {
    final isSelected = _selectedFilter == category;
    final color = categoryColors[category]!;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _onFilterChange(category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : context.cardBg.withAlpha(230),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? color : context.borderColor),
            boxShadow: isSelected ? [BoxShadow(color: color.withAlpha(60), blurRadius: 6, offset: const Offset(0, 2))] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : context.textSecondary),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : context.textPrimary)),
          ]),
        ),
      ),
    );
  }

  // PLACE INFO SHEET
  void _showPlaceInfo(Map<String, dynamic> place) {
    final catColor = categoryColors[place['category']] ?? context.accent;
    final dist = _distanceToPlace(place);
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            // Icon + Distance row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: catColor.withAlpha(25), shape: BoxShape.circle),
                  child: Icon(place["icon"] as IconData, color: catColor, size: 32),
                ),
                if (dist != null) ...[
                  const SizedBox(width: 20),
                  Column(children: [
                    Text(_formatDistance(dist), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.accent)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.directions_walk_rounded, size: 14, color: context.textSecondary),
                      const SizedBox(width: 4),
                      Text(_estimateWalkTime(dist), style: TextStyle(fontSize: 13, color: context.textSecondary)),
                    ]),
                  ]),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(place["name"], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            // Tags row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _infoBadge(catColor, (place['category'] as String).toUpperCase()),
                if (place['hours'] != null)
                  _infoBadge(AsliColors.accentTeal, place['hours']),
              ],
            ),
            const SizedBox(height: 12),
            Text(place['desc'] ?? '', style: TextStyle(color: context.textSecondary, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            // Coordinates
            Text(
              '${(place['lat'] as double).toStringAsFixed(4)}°N, ${(place['lng'] as double).toStringAsFixed(4)}°E',
              style: TextStyle(fontSize: 11, color: context.textSecondary.withAlpha(150), fontFamily: 'monospace'),
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: catColor,
                      side: BorderSide(color: catColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.zoom_in_map_rounded, size: 20),
                    label: const Text("Focus", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ctrl = await _mapController.future;
                      ctrl.animateCamera(CameraUpdate.newCameraPosition(
                        CameraPosition(target: LatLng(place['lat'], place['lng']), zoom: 18, tilt: 45),
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: catColor, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.directions_rounded, size: 20),
                    label: const Text("Directions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openGoogleMapsDirections(place);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }
}

const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2d2d2d"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#1a3c1a"}]}
]
''';
