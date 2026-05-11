import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'config/env_config.dart';
import 'services/secure_storage_service.dart';
import 'services/connectivity_manager.dart';
import 'services/offline_queue_service.dart';
import 'services/reliable_api_client.dart';
import 'services/api/analytics_api_client.dart';
import 'services/api/auth_api_client.dart';
import 'services/api/admin_api_client.dart';
import 'services/api/bookmarks_api_client.dart';
import 'services/api/chat_api_client.dart';
import 'services/api/collx_api_client.dart';
import 'services/api/community_api_client.dart';
import 'services/api/confessions_api_client.dart';
import 'services/api/events_api_client.dart';
import 'services/api/marketplace_api_client.dart';
import 'services/api/messages_api_client.dart';
import 'services/api/notifications_api_client.dart';
import 'services/api/polls_api_client.dart';
import 'services/api/qa_api_client.dart';
import 'services/api/stories_api_client.dart';
import 'services/api/study_groups_api_client.dart';
import 'services/api/upload_api_client.dart';

/// ==================== CONNECTION STATE ====================

/// Tracks if we have internet
class ConnectionStatus {
  static bool isConnected = false;
  static bool isInitialized = false;
  static String connectionType = 'Unknown';
  static int connectionQuality = 0;

  static Stream<NetConnectionState> get stateStream =>
      ConnectivityManager.instance.stateStream;

  static Stream<ConnectivityResult> get typeStream =>
      ConnectivityManager.instance.typeStream;

  static Stream<ConnectionError> get errorStream =>
      ConnectivityManager.instance.errorStream;

  /// Start monitoring network
  static Future<void> initialize() async {
    if (isInitialized) return;

    // Initialize services
    await SecureStorageService.instance.init();
    await OfflineQueueService.instance.init();

    // Initialize connectivity monitoring
    await ConnectivityManager.instance.init(connectionCheck: healthCheck);

    // Listen for state changes
    ConnectivityManager.instance.stateStream.listen((state) {
      isConnected = state == NetConnectionState.connected;
      connectionQuality = ConnectivityManager.instance.connectionQuality;

      // Sync pending actions when connection restored
      if (state == NetConnectionState.connected) {
        _syncPendingActions();
      }
    });

    // Listen for type changes
    ConnectivityManager.instance.typeStream.listen((type) {
      connectionType = ConnectivityManager.instance.connectionTypeString;
    });

    // Listen for errors
    ConnectivityManager.instance.errorStream.listen((error) {
      debugPrint('[Connection Error] Error: $error');
    });

    isInitialized = true;
  }

  /// Push queued actions when back online
  static Future<void> _syncPendingActions() async {
    if (OfflineQueueService.instance.hasPendingActions) {
      await ReliableApiClient.instance.syncPendingActions();
    }
  }

  /// Quick check if server is up
  static Future<bool> healthCheck() async {
    try {
      final response = await ReliableApiClient.instance.get('/');
      return response.success;
    } catch (e) {
      return false;
    }
  }

  /// Try reconnecting
  static Future<void> reconnect() async {
    await ConnectivityManager.instance.reconnect();
  }

  /// Block until connected
  static Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 10),
  }) {
    return ConnectivityManager.instance.waitForConnection(timeout: timeout);
  }
}

/// ==================== API EXCEPTIONS ====================

/// Base API exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final DateTime timestamp;

  ApiException(this.message, {this.statusCode, this.code, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'ApiException($statusCode): $message${code != null ? ' ($code)' : ''}';
}

/// Authentication exception
class AuthException extends ApiException {
  AuthException(String message, {int? statusCode})
    : super(message, statusCode: statusCode);
}

/// Network exception
class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

/// Timeout exception
class TimeoutException extends ApiException {
  TimeoutException(String message) : super(message);
}

/// Validation exception
class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;

  ValidationException(String message, {this.errors}) : super(message);
}

/// Server exception
class ServerException extends ApiException {
  ServerException(String message, {int? statusCode})
    : super(message, statusCode: statusCode);
}

// ApiResponse and HttpMethod are imported from reliable_api_client.dart
// (re-exported here for backward compatibility)
typedef ApiResponseMap = ApiResponse<Map<String, dynamic>>;

/// ==================== API SERVICE ====================

/// Main API service for all backend communication
class ApiService {
  // Use environment-based configuration
  static String get baseUrl => EnvConfig.apiUrl;
  static Duration get _timeout => EnvConfig.receiveTimeout;
  static final AnalyticsApiClient _analyticsClient = AnalyticsApiClient(
    _rawRequest,
  );
  static final AuthApiClient _authClient = AuthApiClient(_rawRequest);
  static final AdminApiClient _adminClient = AdminApiClient(_rawRequest);
  static final BookmarksApiClient _bookmarksClient = BookmarksApiClient(
    _rawRequest,
  );
  static final ChatApiClient _chatClient = ChatApiClient(_rawRequest);
  static final CollxApiClient _collxClient = CollxApiClient(_rawRequest);
  static final CommunityApiClient _communityClient = CommunityApiClient(
    _rawRequest,
  );
  static final ConfessionsApiClient _confessionsClient = ConfessionsApiClient(
    _rawRequest,
  );
  static final EventsApiClient _eventsClient = EventsApiClient(_rawRequest);
  static final MarketplaceApiClient _marketplaceClient = MarketplaceApiClient(
    _rawRequest,
  );
  static final MessagesApiClient _messagesClient = MessagesApiClient(
    _rawRequest,
  );
  static final NotificationsApiClient _notificationsClient =
      NotificationsApiClient(_rawRequest);
  static final PollsApiClient _pollsClient = PollsApiClient(_rawRequest);
  static final QaApiClient _qaClient = QaApiClient(_rawRequest);
  static final StoriesApiClient _storiesClient = StoriesApiClient(_rawRequest);
  static final StudyGroupsApiClient _studyGroupsClient = StudyGroupsApiClient(
    _rawRequest,
  );
  static final UploadApiClient _uploadClient = UploadApiClient();

  // ==================== AUTH STATE ====================
  static String? _token;
  static Map<String, dynamic>? _currentUser;

  /// Get current auth token
  static String? get token => _token;

  /// Get current user data
  static Map<String, dynamic>? get currentUser => _currentUser;

  /// Check if user is logged in
  static bool get isLoggedIn => _token != null && _currentUser != null;

  /// Get current user ID
  static int get currentUserId => _currentUser?['id'] ?? 0;

  /// Check if connected to API
  static bool get isConnected => ConnectionStatus.isConnected;

  /// Get connection quality
  static int get connectionQuality => ConnectionStatus.connectionQuality;

  /// Load stored auth state on init
  static Future<void> loadAuthState() async {
    _token = await SecureStorageService.instance.getToken();
    _currentUser = await SecureStorageService.instance.getUser();
  }

  /// Logout - clear auth state
  static void logout() {
    _token = null;
    _currentUser = null;
    SecureStorageService.instance.clearAll();
  }

  /// Raw HTTP request for direct control
  static Future<http.Response> _rawRequest(
    String url, {
    required String method,
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final authToken = await SecureStorageService.instance.getToken();
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      'ngrok-skip-browser-warning': 'true',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
      ...?headers,
    };

    try {
      final uri = Uri.parse('$baseUrl$url');
      http.Response response;

      switch (method) {
        case 'GET':
          response = await http
              .get(uri, headers: requestHeaders)
              .timeout(timeout ?? _timeout);
          break;
        case 'POST':
          response = await http
              .post(
                uri,
                headers: requestHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(timeout ?? _timeout);
          break;
        case 'PUT':
          response = await http
              .put(
                uri,
                headers: requestHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(timeout ?? _timeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: requestHeaders)
              .timeout(timeout ?? _timeout);
          break;
        default:
          throw Exception('Unsupported method: $method');
      }

      // Update connection status
      ConnectionStatus.isConnected = true;
      return response;
    } catch (e) {
      ConnectionStatus.isConnected = false;

      if (e is TimeoutException) {
        throw TimeoutException('Request timed out');
      }
      throw NetworkException('Network error: $e');
    }
  }

  // ==================== AUTH API ====================

  /// Register a new account
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String username,
    String department = '',
    String year = '',
  }) async {
    try {
      final data = await _authClient.register(
        name: name,
        email: email,
        password: password,
        username: username,
        department: department,
        year: year,
      );
      if (data['success'] == true) {
        _token = data['token'];
        _currentUser = data['user'];
        // Persist credentials
        await SecureStorageService.instance.saveToken(
          _token!,
          expiry: const Duration(days: 30),
        );
        await SecureStorageService.instance.saveUser(_currentUser!);
      }
      return data;
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {
        'success': false,
        'error': 'Registration failed. Please check your connection.',
      };
    }
  }

  /// Login with email/username + password
  static Future<Map<String, dynamic>> login(
    String identifier,
    String password,
  ) async {
    try {
      final data = await _authClient.login(identifier, password);
      if (data['success'] == true) {
        _token = data['token'];
        _currentUser = data['user'];
        // Persist credentials
        await SecureStorageService.instance.saveToken(
          _token!,
          expiry: const Duration(days: 30),
        );
        await SecureStorageService.instance.saveUser(_currentUser!);
      }
      return data;
    } on ApiException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {
        'success': false,
        'error': 'Login failed. Please check your connection.',
      };
    }
  }

  /// Get current user profile
  static Future<Map<String, dynamic>?> getMe() async {
    try {
      final data = await _authClient.getMe();
      if (data != null) {
        _currentUser = data['user'];
        await SecureStorageService.instance.saveUser(_currentUser!);
        return data['user'];
      }
      return null;
    } catch (e) {
      // Try to return cached user
      return SecureStorageService.instance.getUser();
    }
  }

  /// Check if backend is running
  static Future<bool> healthCheck() async {
    return ConnectionStatus.healthCheck();
  }

  // ==================== CHAT API ====================

  /// Send message to chatbot (legacy)
  static Future<Map<String, dynamic>?> sendMessage(String message) async {
    return _chatClient.sendLegacyMessage(message);
  }

  /// Send message to AI chatbot (enhanced v2)
  static Future<Map<String, dynamic>?> sendChatMessage(
    String message, {
    String? conversationId,
  }) async {
    return _chatClient.sendMessage(message, conversationId: conversationId);
  }

  /// Get chat suggestions
  static Future<List<String>> getChatSuggestions(String prefix) async {
    return _chatClient.getSuggestions(prefix);
  }

  /// Get chat history
  static Future<List<Map<String, dynamic>>> getChatHistory({
    int page = 1,
    String? sessionId,
  }) async {
    return _chatClient.getHistory(page: page, sessionId: sessionId);
  }

  /// Clear chat history
  static Future<bool> clearChatHistory({String? sessionId}) async {
    return _chatClient.clearHistory(sessionId: sessionId);
  }

  /// Get chat statistics
  static Future<Map<String, dynamic>?> getChatStats() async {
    return _chatClient.getStats();
  }

  // ==================== COLLX API METHODS ====================

  /// Get CollX feed with pagination
  static Future<List<Map<String, dynamic>>> getCollxFeed({
    int page = 1,
    int limit = 20,
  }) async {
    return _collxClient.getFeed(page: page, limit: limit);
  }

  /// Get single post with replies
  static Future<Map<String, dynamic>?> getCollxPost(int postId) async {
    return _collxClient.getPost(postId);
  }

  /// Create a new CollX post
  static Future<Map<String, dynamic>?> createCollxPost(
    String content, {
    String? imageUrl,
  }) async {
    return _collxClient.createPost(content, imageUrl: imageUrl);
  }

  /// Toggle like on a post
  static Future<Map<String, dynamic>?> toggleCollxLike(int postId) async {
    return _collxClient.toggleLike(postId);
  }

  /// Reply to a post
  static Future<bool> replyCollxPost(int postId, String content) async {
    return _collxClient.replyToPost(postId, content);
  }

  /// Repost a post
  static Future<Map<String, dynamic>?> repostCollxPost(int postId) async {
    return _collxClient.repost(postId);
  }

  /// Get trending hashtags
  static Future<List<Map<String, dynamic>>> getCollxTrending() async {
    return _collxClient.getTrending();
  }

  /// Search users and posts
  static Future<Map<String, dynamic>?> searchCollx(String query) async {
    return _collxClient.search(query);
  }

  // ==================== EVENTS API ====================

  /// Get all events
  static Future<List<Map<String, dynamic>>> getEvents() async {
    try {
      return _eventsClient.getEvents();
    } catch (_) {
      return [];
    }
  }

  /// Get announcements
  static Future<List<Map<String, dynamic>>> getAnnouncements() async {
    try {
      return _eventsClient.getAnnouncements();
    } catch (_) {
      return [];
    }
  }

  /// RSVP to an event
  static Future<Map<String, dynamic>?> rsvpEvent(int eventId) async {
    try {
      return _eventsClient.rsvpEvent(eventId);
    } catch (_) {
      return null;
    }
  }

  /// Create a new event
  static Future<Map<String, dynamic>?> createEvent(
    Map<String, dynamic> data,
  ) async {
    try {
      return _eventsClient.createEvent(data);
    } catch (_) {
      return null;
    }
  }

  // ==================== NOTIFICATIONS API ====================

  /// Get notifications
  static Future<Map<String, dynamic>?> getNotifications() async {
    try {
      return _notificationsClient.getNotifications();
    } catch (_) {
      return null;
    }
  }

  /// Get unread count
  static Future<int> getUnreadCount() async {
    try {
      return _notificationsClient.getUnreadCount();
    } catch (_) {
      return 0;
    }
  }

  /// Mark all as read
  static Future<void> markAllNotificationsRead() async {
    try {
      await _notificationsClient.markAllRead();
    } catch (_) {}
  }

  // ==================== PROFILE UPDATE ====================

  /// Update current user profile
  static Future<Map<String, dynamic>?> updateProfile({
    String? name,
    String? bio,
    String? department,
    String? year,
    String? profileColor,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (bio != null) body['bio'] = bio;
      if (department != null) body['department'] = department;
      if (year != null) body['year'] = year;
      if (profileColor != null) body['profile_color'] = profileColor;

      final data = await _authClient.updateProfile(body);
      if (data != null) {
        if (data['user'] != null) {
          _currentUser = data['user'];
          await SecureStorageService.instance.saveUser(_currentUser!);
        }
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== ANALYTICS API ====================

  /// Get analytics statistics
  static Future<Map<String, dynamic>?> getAnalyticsStats() async {
    try {
      return _analyticsClient.getStats();
    } catch (e) {
      return null;
    }
  }

  /// Get activity feed
  static Future<List<dynamic>> getActivityFeed() async {
    try {
      return _analyticsClient.getActivityFeed();
    } catch (e) {
      return [];
    }
  }

  /// Get leaderboard
  static Future<List<dynamic>> getLeaderboard() async {
    try {
      return _analyticsClient.getLeaderboard();
    } catch (e) {
      return [];
    }
  }

  // ==================== MESSAGES API ====================

  /// Get conversations
  static Future<List<dynamic>> getConversations() async {
    try {
      return _messagesClient.getConversations();
    } catch (_) {
      return [];
    }
  }

  /// Get chat messages with a user
  static Future<Map<String, dynamic>?> getChatMessages(int partnerId) async {
    try {
      return _messagesClient.getChatMessages(partnerId);
    } catch (_) {
      return null;
    }
  }

  /// Send direct message
  static Future<Map<String, dynamic>?> sendDM(
    int receiverId,
    String content,
  ) async {
    try {
      return _messagesClient.sendDM(receiverId, content);
    } catch (_) {
      return null;
    }
  }

  /// Get unread DM count
  static Future<int> getUnreadDMCount() async {
    try {
      return _messagesClient.getUnreadCount();
    } catch (_) {
      return 0;
    }
  }

  // ==================== ADMIN API ====================

  /// Get all users (admin only)
  static Future<List<dynamic>> getAdminUsers() async {
    try {
      return _adminClient.getUsers();
    } catch (_) {
      return [];
    }
  }

  /// Toggle user status (admin only)
  static Future<Map<String, dynamic>?> toggleUserStatus(int targetId) async {
    try {
      return _adminClient.toggleUserStatus(targetId);
    } catch (_) {
      return null;
    }
  }

  /// Get admin overview
  static Future<Map<String, dynamic>?> getAdminOverview() async {
    try {
      return _adminClient.getOverview();
    } catch (_) {
      return null;
    }
  }

  /// Get audit log (admin only)
  static Future<List<dynamic>> getAuditLog() async {
    try {
      return _adminClient.getAuditLog();
    } catch (_) {
      return [];
    }
  }

  /// Delete post (admin only)
  static Future<bool> adminDeletePost(int postId) async {
    try {
      return _adminClient.deletePost(postId);
    } catch (_) {
      return false;
    }
  }

  // ==================== BOOKMARKS API ====================

  /// Get bookmarks
  static Future<List<dynamic>> getBookmarks() async {
    try {
      return _bookmarksClient.getBookmarks();
    } catch (_) {
      return [];
    }
  }

  /// Toggle bookmark
  static Future<Map<String, dynamic>?> toggleBookmark(int postId) async {
    try {
      return _bookmarksClient.toggleBookmark(postId);
    } catch (_) {
      return null;
    }
  }

  /// Check if post is bookmarked
  static Future<bool> checkBookmark(int postId) async {
    try {
      return _bookmarksClient.checkBookmark(postId);
    } catch (_) {
      return false;
    }
  }

  /// Get bookmark count
  static Future<int> getBookmarkCount() async {
    try {
      return _bookmarksClient.getBookmarkCount();
    } catch (_) {
      return 0;
    }
  }

  // ==================== POLLS API ====================

  /// Get all polls
  static Future<List<dynamic>?> getPolls() async {
    try {
      return _pollsClient.getPolls();
    } catch (_) {
      return null;
    }
  }

  /// Create a poll
  static Future<Map<String, dynamic>?> createPoll(
    String question,
    List<String> options, {
    int durationHours = 24,
  }) async {
    try {
      return _pollsClient.createPoll(
        question,
        options,
        durationHours: durationHours,
      );
    } catch (_) {
      return null;
    }
  }

  /// Vote on a poll
  static Future<Map<String, dynamic>?> votePoll(
    int pollId,
    int optionId,
  ) async {
    try {
      return _pollsClient.votePoll(pollId, optionId);
    } catch (_) {
      return null;
    }
  }

  // ==================== STORIES API ====================

  /// Get all active stories
  static Future<List<dynamic>?> getStories() async {
    try {
      return _storiesClient.getStories();
    } catch (_) {
      return null;
    }
  }

  /// Create a story
  static Future<Map<String, dynamic>?> createStory(
    String text,
    String bgColor, {
    String emoji = '',
  }) async {
    try {
      return _storiesClient.createStory(text, bgColor, emoji: emoji);
    } catch (_) {
      return null;
    }
  }

  /// Mark story as viewed
  static Future<void> viewStory(int storyId) async {
    try {
      await _storiesClient.viewStory(storyId);
    } catch (_) {}
  }

  // ==================== STUDY GROUPS API ====================

  /// Get all study groups
  static Future<List<dynamic>?> getStudyGroups() async {
    try {
      return _studyGroupsClient.getStudyGroups();
    } catch (_) {
      return null;
    }
  }

  /// Create a study group
  static Future<Map<String, dynamic>?> createStudyGroup(
    String name,
    String subject, {
    String description = '',
    String emoji = '📚',
    String color = '#3B82F6',
  }) async {
    try {
      return _studyGroupsClient.createStudyGroup(
        name,
        subject,
        description: description,
        emoji: emoji,
        color: color,
      );
    } catch (_) {
      return null;
    }
  }

  /// Join a study group
  static Future<Map<String, dynamic>?> joinStudyGroup(int groupId) async {
    try {
      return _studyGroupsClient.joinStudyGroup(groupId);
    } catch (_) {
      return null;
    }
  }

  /// Leave a study group
  static Future<Map<String, dynamic>?> leaveStudyGroup(int groupId) async {
    try {
      return _studyGroupsClient.leaveStudyGroup(groupId);
    } catch (_) {
      return null;
    }
  }

  /// Get study group details
  static Future<Map<String, dynamic>?> getStudyGroupDetail(int groupId) async {
    try {
      return _studyGroupsClient.getStudyGroupDetail(groupId);
    } catch (_) {
      return null;
    }
  }

  // ==================== CONFESSIONS API ====================

  static Future<Map<String, dynamic>?> getConfessions({
    String? category,
  }) async {
    try {
      return _confessionsClient.getConfessions(category: category);
    } catch (_) {
      return null;
    }
  }

  /// Create a confession
  static Future<Map<String, dynamic>?> createConfession(
    String content, {
    String category = 'general',
    String mood = '😶',
  }) async {
    try {
      return _confessionsClient.createConfession(
        content,
        category: category,
        mood: mood,
      );
    } catch (_) {
      return null;
    }
  }

  /// React to a confession
  static Future<Map<String, dynamic>?> reactToConfession(
    int confessionId,
    String emoji,
  ) async {
    try {
      return _confessionsClient.reactToConfession(confessionId, emoji);
    } catch (_) {
      return null;
    }
  }

  // ==================== MARKETPLACE API ====================

  /// Get all marketplace listings
  static Future<List<dynamic>?> getMarketplaceListings() async {
    try {
      return _marketplaceClient.getMarketplaceListings();
    } catch (_) {
      return null;
    }
  }

  /// Create a marketplace listing
  static Future<Map<String, dynamic>?> createMarketplaceListing({
    required String title,
    required String description,
    required double price,
    required String category,
    required String condition,
    String? imageUrl,
  }) async {
    try {
      return _marketplaceClient.createMarketplaceListing(
        title: title,
        description: description,
        price: price,
        category: category,
        condition: condition,
        imageUrl: imageUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Express interest in a listing
  static Future<Map<String, dynamic>?> expressInterest(
    int listingId,
    String message,
  ) async {
    try {
      return _marketplaceClient.expressInterest(listingId, message);
    } catch (_) {
      return null;
    }
  }

  // ==================== COMMUNITY API ====================

  /// Get community posts by channel
  static Future<Map<String, dynamic>?> getCommunityPosts({
    String? channel,
  }) async {
    try {
      return _communityClient.getCommunityPosts(channel: channel);
    } catch (_) {
      return null;
    }
  }

  /// Get all community channels
  static Future<List<dynamic>?> getCommunityChannels() async {
    try {
      return _communityClient.getCommunityChannels();
    } catch (_) {
      return null;
    }
  }

  /// Create a community post
  static Future<Map<String, dynamic>?> createCommunityPost(
    String content, {
    String channel = 'general',
  }) async {
    try {
      return _communityClient.createCommunityPost(content, channel: channel);
    } catch (_) {
      return null;
    }
  }

  /// Post to community channel
  static Future<Map<String, dynamic>?> postToCommunity(
    String channelId,
    String content,
  ) async {
    try {
      return _communityClient.postToCommunity(channelId, content);
    } catch (_) {
      return null;
    }
  }

  // ==================== STUDY GROUPS API ====================

  /// Get user's study groups
  static Future<List<dynamic>?> getMyStudyGroups() async {
    try {
      return _studyGroupsClient.getMyStudyGroups();
    } catch (_) {
      return null;
    }
  }

  /// Get group messages
  static Future<Map<String, dynamic>?> getGroupMessages(int groupId) async {
    try {
      return _studyGroupsClient.getGroupMessages(groupId);
    } catch (_) {
      return null;
    }
  }

  /// Send group message
  static Future<Map<String, dynamic>?> sendGroupMessage(
    int groupId,
    String content,
  ) async {
    try {
      return _studyGroupsClient.sendGroupMessage(groupId, content);
    } catch (_) {
      return null;
    }
  }

  // ==================== UPLOAD API ====================

  /// Upload an image
  static Future<Map<String, dynamic>?> uploadImage(
    String filePath, {
    String folder = 'posts',
  }) async {
    try {
      return _uploadClient.uploadImage(filePath, folder: folder);
    } catch (_) {
      return null;
    }
  }

  // ==================== Q&A API ====================
  static Future<List<Map<String, dynamic>>> getQuestions({
    int limit = 20,
  }) async {
    try {
      return _qaClient.getQuestions(limit: limit);
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> addQuestion(
    String content, [
    String? details,
  ]) async {
    try {
      return _qaClient.addQuestion(content, details);
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getAnswers(int questionId) async {
    try {
      return _qaClient.getAnswers(questionId);
    } catch (_) {
      return [];
    }
  }

  // ==================== COLLX USER ====================
  static Future<Map<String, dynamic>?> getCollxUser(int userId) async {
    try {
      return _collxClient.getUser(userId);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> toggleCollxFollow(int userId) async {
    try {
      return _collxClient.toggleFollow(userId);
    } catch (_) {
      return null;
    }
  }

  // ==================== MARKETPLACE ====================
  static Future<Map<String, dynamic>?> getListings({String? category}) async {
    try {
      return _marketplaceClient.getListings(category: category);
    } catch (_) {
      return {'listings': [], 'categories': []};
    }
  }

  static Future<Map<String, dynamic>?> createListing(
    Map<String, dynamic> data,
  ) async {
    try {
      return _marketplaceClient.createListing(data);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> toggleInterest(int listingId) async {
    try {
      return _marketplaceClient.toggleInterest(listingId);
    } catch (_) {
      return null;
    }
  }

  // ==================== ANALYTICS ====================
  static Future<List<dynamic>> getModuleHealth() async {
    try {
      return _analyticsClient.getModuleHealth();
    } catch (e) {
      return [];
    }
  }

  // ==================== NOTIFICATIONS ====================
  static Future<bool> markNotificationRead(int id) async {
    try {
      return _notificationsClient.markRead(id);
    } catch (_) {
      return false;
    }
  }

  static Future<void> updateFcmToken(String token) async {
    try {
      await _notificationsClient.updateFcmToken(token);
    } catch (_) {
      /* ignore */
    }
  }

  // ==================== CONFESSIONS ====================
  static Future<Map<String, dynamic>?> reactConfession(
    int confessionId,
    String reaction,
  ) async {
    try {
      return _confessionsClient.reactConfession(confessionId, reaction);
    } catch (_) {
      return null;
    }
  }

  // ==================== LEADERBOARD ====================
  static Future<Map<String, dynamic>?> getEngagementLeaderboard() async {
    try {
      return _analyticsClient.getEngagementLeaderboard();
    } catch (e) {
      return null;
    }
  }

  /// Add answer to a question
  static Future<bool> addAnswer(int questionId, String text) async {
    try {
      return _qaClient.addAnswer(questionId, text);
    } catch (_) {
      return false;
    }
  }
}

/// Extension for checking null/empty values
extension StringExtension on String {
  bool get isNullOrEmpty => trim().isEmpty;
  bool get isNotNullOrEmpty => trim().isNotEmpty;
}
