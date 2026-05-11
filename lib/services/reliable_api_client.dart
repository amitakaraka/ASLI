import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import 'connectivity_manager.dart';
import 'offline_queue_service.dart';
import 'secure_storage_service.dart';

/// API response wrapper
class ApiResponse<T> {
  final T? data;
  final String? error;
  final int? statusCode;
  final bool success;
  final bool fromCache;
  final bool fromQueue;

  ApiResponse({
    this.data,
    this.error,
    this.statusCode,
    this.success = false,
    this.fromCache = false,
    this.fromQueue = false,
  });

  factory ApiResponse.success(
    T data, {
    int? statusCode,
    bool fromCache = false,
    bool fromQueue = false,
  }) {
    return ApiResponse(
      data: data,
      statusCode: statusCode ?? 200,
      success: true,
      fromCache: fromCache,
      fromQueue: fromQueue,
    );
  }

  factory ApiResponse.error(String error, {int? statusCode}) {
    return ApiResponse(error: error, statusCode: statusCode, success: false);
  }
}

/// HTTP methods supported
enum HttpMethod { get, post, put, patch, delete }

/// Reliable API client with automatic retry, offline support, and caching
class ReliableApiClient {
  static ReliableApiClient? _instance;
  static ReliableApiClient get instance => _instance ??= ReliableApiClient._();

  ReliableApiClient._();

  final http.Client _httpClient = http.Client();
  final ConnectivityManager _connectivity = ConnectivityManager.instance;
  final OfflineQueueService _offlineQueue = OfflineQueueService.instance;
  final SecureStorageService _secureStorage = SecureStorageService.instance;

  /// Execute a reliable GET request
  Future<ApiResponse<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    bool useCache = false,
    Duration? cacheMaxAge,
    int? retryCount,
  }) async {
    return _executeRequest(
      endpoint,
      HttpMethod.get,
      queryParams: queryParams,
      headers: headers,
      useCache: useCache,
      cacheMaxAge: cacheMaxAge,
      retryCount: retryCount ?? EnvConfig.maxRetries,
    );
  }

  /// Execute a reliable POST request
  Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool queueIfOffline = false,
    int? retryCount,
  }) async {
    return _executeRequest(
      endpoint,
      HttpMethod.post,
      body: body,
      headers: headers,
      queueIfOffline: queueIfOffline,
      retryCount: retryCount ?? EnvConfig.maxRetries,
    );
  }

  /// Execute a reliable PUT request
  Future<ApiResponse<Map<String, dynamic>>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    int? retryCount,
  }) async {
    return _executeRequest(
      endpoint,
      HttpMethod.put,
      body: body,
      headers: headers,
      retryCount: retryCount ?? EnvConfig.maxRetries,
    );
  }

  /// Execute a reliable PATCH request
  Future<ApiResponse<Map<String, dynamic>>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    int? retryCount,
  }) async {
    return _executeRequest(
      endpoint,
      HttpMethod.patch,
      body: body,
      headers: headers,
      retryCount: retryCount ?? EnvConfig.maxRetries,
    );
  }

  /// Execute a reliable DELETE request
  Future<ApiResponse<Map<String, dynamic>>> delete(
    String endpoint, {
    Map<String, String>? headers,
    int? retryCount,
  }) async {
    return _executeRequest(
      endpoint,
      HttpMethod.delete,
      headers: headers,
      retryCount: retryCount ?? EnvConfig.maxRetries,
    );
  }

  /// Internal request executor with retry logic
  Future<ApiResponse<Map<String, dynamic>>> _executeRequest(
    String endpoint,
    HttpMethod method, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    bool useCache = false,
    Duration? cacheMaxAge,
    bool queueIfOffline = false,
    int retryCount = 3,
  }) async {
    // Build URL
    var url = '${EnvConfig.apiUrl}$endpoint';
    if (queryParams != null && queryParams.isNotEmpty) {
      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      url = uri.toString();
    }

    // Check cache for GET requests
    if (method == HttpMethod.get && useCache) {
      final cached = await _offlineQueue.getCachedResponse(url);
      if (cached != null) {
        return ApiResponse.success(cached['data'], fromCache: true);
      }
    }

    // Check connectivity
    if (!_connectivity.isConnected) {
      // Queue for later if it's a mutation
      if (queueIfOffline && method != HttpMethod.get) {
        await _offlineQueue.queueAction(
          id: '${DateTime.now().millisecondsSinceEpoch}_$endpoint',
          endpoint: endpoint,
          method: method.name,
          data: body ?? {},
        );
        return ApiResponse.error('Queued for offline sync', statusCode: 202);
      }

      return ApiResponse.error('No internet connection', statusCode: 0);
    }

    // Build headers
    final authToken = await _secureStorage.getToken();
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      'ngrok-skip-browser-warning': 'true',
      ...?headers,
    };
    if (authToken != null) {
      requestHeaders['Authorization'] = 'Bearer $authToken';
    }

    // Execute request with retry
    int attempts = 0;
    Duration delay = const Duration(milliseconds: 500);

    while (attempts < retryCount) {
      try {
        final response = await _makeRequest(
          url,
          method,
          headers: requestHeaders,
          body: body,
        );

        // Cache successful GET responses
        if (method == HttpMethod.get &&
            useCache &&
            response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          await _offlineQueue.cacheResponse(
            url,
            responseData,
            expiry: cacheMaxAge ?? EnvConfig.cacheDuration,
          );
        }

        return _handleResponse(response);
      } on TimeoutException {
        attempts++;
        if (attempts < retryCount) {
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff
        }
      } on SocketException {
        attempts++;
        if (attempts < retryCount) {
          await Future.delayed(delay);
          delay *= 2;
        }
      } catch (e) {
        return ApiResponse.error(e.toString());
      }
    }

    // All retries failed
    if (queueIfOffline && method != HttpMethod.get) {
      await _offlineQueue.queueAction(
        id: '${DateTime.now().millisecondsSinceEpoch}_$endpoint',
        endpoint: endpoint,
        method: method.name,
        data: body ?? {},
      );
      return ApiResponse.error(
        'Queued for offline sync after retries',
        statusCode: 202,
      );
    }

    return ApiResponse.error(
      'Request failed after $retryCount attempts',
      statusCode: 408,
    );
  }

  /// Make the actual HTTP request
  Future<http.Response> _makeRequest(
    String url,
    HttpMethod method, {
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(url);

    switch (method) {
      case HttpMethod.get:
        return await _httpClient
            .get(uri, headers: headers)
            .timeout(EnvConfig.receiveTimeout);
      case HttpMethod.post:
        return await _httpClient
            .post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(EnvConfig.receiveTimeout);
      case HttpMethod.put:
        return await _httpClient
            .put(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(EnvConfig.receiveTimeout);
      case HttpMethod.patch:
        return await _httpClient
            .patch(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(EnvConfig.receiveTimeout);
      case HttpMethod.delete:
        return await _httpClient
            .delete(uri, headers: headers)
            .timeout(EnvConfig.receiveTimeout);
    }
  }

  /// Handle HTTP response
  ApiResponse<Map<String, dynamic>> _handleResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(body, statusCode: response.statusCode);
      }

      // Handle specific error codes
      switch (response.statusCode) {
        case 401:
          // Token expired or invalid
          return ApiResponse.error(
            body['error'] ?? 'Authentication required',
            statusCode: 401,
          );
        case 403:
          return ApiResponse.error(
            body['error'] ?? 'Access denied',
            statusCode: 403,
          );
        case 404:
          return ApiResponse.error(
            body['error'] ?? 'Not found',
            statusCode: 404,
          );
        case 429:
          return ApiResponse.error(
            'Too many requests. Please try again later.',
            statusCode: 429,
          );
        case 500:
        case 502:
        case 503:
          return ApiResponse.error(
            body['error'] ?? 'Server error',
            statusCode: response.statusCode,
          );
        default:
          return ApiResponse.error(
            body['error'] ?? 'Request failed',
            statusCode: response.statusCode,
          );
      }
    } catch (e) {
      return ApiResponse.error(
        'Invalid response format',
        statusCode: response.statusCode,
      );
    }
  }

  /// Sync pending offline actions
  Future<int> syncPendingActions() async {
    return _offlineQueue.syncPendingActions((action) async {
      final response = await _executeRequest(
        action.endpoint,
        HttpMethod.values.firstWhere((m) => m.name == action.method),
        body: action.data,
        retryCount: 1, // Only one retry for queued actions
      );
      return response.success;
    });
  }

  /// Close the HTTP client
  void dispose() {
    _httpClient.close();
  }
}
