import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/theme_ext.dart';
import '../widgets/skeleton_loaders.dart';
import '../widgets/error_states.dart';

class EventsScreen extends StatefulWidget {
  final int initialTab;
  const EventsScreen({super.key, this.initialTab = 0});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final Set<int> _rsvpIds = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final events = await ApiService.getEvents();
      final announcements = await ApiService.getAnnouncements();
      if (!mounted) return;
      setState(() {
        _events = events;
        _announcements = announcements;
        _rsvpIds.clear();
        for (var e in events) {
          if (e['user_rsvp'] == true) _rsvpIds.add(e['id']);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRsvp(int eventId) async {
    setState(() {
      if (_rsvpIds.contains(eventId)) {
        _rsvpIds.remove(eventId);
      } else {
        _rsvpIds.add(eventId);
      }
    });
    await ApiService.rsvpEvent(eventId);
  }

  void _showCreateEvent() {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    final venueC = TextEditingController();
    final timeC = TextEditingController();
    String category = 'general';
    final dateC = TextEditingController(
      text: DateTime.now()
          .add(const Duration(days: 7))
          .toString()
          .substring(0, 10),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: context.surfaceBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Create Event',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _formField(titleC, 'Event Title', Icons.event_rounded),
                  const SizedBox(height: 12),
                  _formField(
                    descC,
                    'Description',
                    Icons.description_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _formField(
                    dateC,
                    'Date (YYYY-MM-DD)',
                    Icons.calendar_today_rounded,
                  ),
                  const SizedBox(height: 12),
                  _formField(
                    timeC,
                    'Time (e.g. 10:00 AM)',
                    Icons.access_time_rounded,
                  ),
                  const SizedBox(height: 12),
                  _formField(venueC, 'Venue', Icons.location_on_rounded),
                  const SizedBox(height: 12),
                  // Category dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: category,
                        isExpanded: true,
                        dropdownColor: context.surfaceBg,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                        ),
                        items:
                            [
                                  'general',
                                  'fest',
                                  'exam',
                                  'cultural',
                                  'placement',
                                  'sports',
                                  'workshop',
                                  'deadline',
                                  'networking',
                                ]
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.toUpperCase()),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setS(() => category = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        'Create Event',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () async {
                        if (titleC.text.trim().isEmpty) return;
                        Navigator.pop(ctx);
                        await ApiService.createEvent({
                          'title': titleC.text.trim(),
                          'description': descC.text.trim(),
                          'date': dateC.text.trim(),
                          'time': timeC.text.trim(),
                          'venue': venueC.text.trim(),
                          'category': category,
                        });
                        _loadData();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _formField(
    TextEditingController c,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: TextStyle(color: context.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.textSecondary),
        prefixIcon: Icon(icon, color: context.accent, size: 20),
        filled: true,
        fillColor: context.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.accent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.accent,
        onPressed: _showCreateEvent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 6,
        itemBuilder: (context, index) => const EventCardSkeleton(),
      );
    }

    if (_hasError) {
      return NetworkErrorWidget(onRetry: _loadData, message: _errorMessage);
    }

    return RefreshIndicator(
      color: context.accent,
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          _buildHeader(),
          _buildTabs(),
          if (_tabController.index == 0) ...[
            if (_announcements.isNotEmpty) _buildAnnouncementsSection(),
            _buildEventsSection(),
          ] else ...[
            _buildCalendarView(),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday =
        DateTime(now.year, now.month, 1).weekday % 7; // Sunday=0
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    // Map events to dates
    final eventDates = <int, List<Map<String, dynamic>>>{};
    for (var e in _events) {
      try {
        final d = DateTime.parse(e['date'] ?? '');
        if (d.month == now.month && d.year == now.year) {
          eventDates.putIfAbsent(d.day, () => []).add(e);
        }
      } catch (_) {}
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                children: [
                  Text(
                    '${months[now.month - 1]} ${now.year}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Day headers
                  Row(
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map(
                          (d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  // Calendar grid
                  ...List.generate(6, (week) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: List.generate(7, (dow) {
                          final dayNum = week * 7 + dow - firstWeekday + 1;
                          if (dayNum < 1 || dayNum > daysInMonth) {
                            return const Expanded(child: SizedBox(height: 40));
                          }
                          final isToday = dayNum == now.day;
                          final hasEvent = eventDates.containsKey(dayNum);
                          return Expanded(
                            child: GestureDetector(
                              onTap: hasEvent
                                  ? () => _showDayEvents(
                                      dayNum,
                                      eventDates[dayNum]!,
                                    )
                                  : null,
                              child: Container(
                                height: 40,
                                margin: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? context.accent
                                      : hasEvent
                                      ? context.accent.withAlpha(15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: hasEvent && !isToday
                                      ? Border.all(
                                          color: context.accent.withAlpha(60),
                                        )
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$dayNum',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isToday
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isToday
                                            ? Colors.white
                                            : context.textPrimary,
                                      ),
                                    ),
                                    if (hasEvent && !isToday)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: context.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Upcoming from this month
            Text(
              'This Month',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (eventDates.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor),
                ),
                child: Center(
                  child: Text(
                    'No events this month',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayEvents(int day, List<Map<String, dynamic>> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final now = DateTime.now();
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$day ${months[now.month - 1]} ${now.year}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              Text(
                '${events.length} event${events.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 13, color: context.textSecondary),
              ),
              const SizedBox(height: 16),
              ...events.map(
                (e) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.pageBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(
                    children: [
                      Text(
                        e['image'] ?? '📅',
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e['title'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              '${e['time'] ?? ''} · ${e['venue'] ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [context.accent, context.accent.withAlpha(200)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.event_rounded, color: context.accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Events & Alerts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_events.length} upcoming · ${_announcements.length} announcements',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          labelColor: Colors.white,
          unselectedLabelColor: context.textSecondary,
          indicator: BoxDecoration(
            color: context.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          tabs: const [
            Tab(text: "Events"),
            Tab(text: "Calendar"),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.isDark
              ? context.accent.withAlpha(20)
              : AsliColors.warmSand.withAlpha(80),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.accent.withAlpha(context.isDark ? 40 : 50),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_rounded, color: context.accent, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Announcements',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_announcements.length}',
                    style: TextStyle(
                      color: context.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._announcements.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: context.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['title'] ?? '',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if ((a['message'] ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                a['message'],
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsSection() {
    if (_events.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy_rounded,
                size: 64,
                color: context.borderColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No upcoming events',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back soon for campus events!',
                style: TextStyle(fontSize: 13, color: context.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildEventCard(_events[index]),
          childCount: _events.length,
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final categoryColors = {
      'fest': AsliColors.accentCoral,
      'exam': AsliColors.accentRust,
      'cultural': AsliColors.accentPlum,
      'placement': AsliColors.accentSage,
      'sports': AsliColors.accentAmber,
      'workshop': AsliColors.accentTeal,
      'deadline': AsliColors.statusWarning,
      'networking': AsliColors.accentSlate,
      'centenary': context.accent,
    };

    final color = categoryColors[event['category']] ?? context.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: (context.isDark ? Colors.black : AsliColors.heritageBrown)
                .withAlpha(context.isDark ? 30 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.isDark ? color.withAlpha(20) : color.withAlpha(12),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  event['image'] ?? '📅',
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withAlpha(80)),
                        ),
                        child: Text(
                          (event['category'] ?? 'event')
                              .toString()
                              .toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event['title'] ?? '',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['description'] ?? '',
                  style: TextStyle(
                    color: context.textSecondary,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      Icons.calendar_today_rounded,
                      _formatDate(event['date']),
                      color,
                    ),
                    _buildInfoChip(
                      Icons.access_time_rounded,
                      event['time'] ?? '',
                      color,
                    ),
                    _buildInfoChip(
                      Icons.location_on_rounded,
                      event['venue'] ?? '',
                      color,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // RSVP Button
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _toggleRsvp(event['id']),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _rsvpIds.contains(event['id'])
                                ? color
                                : color.withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withAlpha(80)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _rsvpIds.contains(event['id'])
                                    ? Icons.check_circle_rounded
                                    : Icons.event_available_rounded,
                                size: 18,
                                color: _rsvpIds.contains(event['id'])
                                    ? Colors.white
                                    : color,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _rsvpIds.contains(event['id'])
                                    ? 'Going \u2713'
                                    : 'RSVP',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _rsvpIds.contains(event['id'])
                                      ? Colors.white
                                      : color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 16,
                            color: context.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(event['rsvp_count'] ?? 0) + (_rsvpIds.contains(event['id']) && event['user_rsvp'] != true ? 1 : 0) - (!_rsvpIds.contains(event['id']) && event['user_rsvp'] == true ? 1 : 0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color accentColor) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.isDark
            ? accentColor.withAlpha(15)
            : accentColor.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: context.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'TBA';
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
