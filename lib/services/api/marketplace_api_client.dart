import 'dart:convert';

import 'raw_api_request.dart';

class MarketplaceApiClient {
  final RawApiRequest _rawRequest;

  const MarketplaceApiClient(this._rawRequest);

  Future<List<dynamic>?> getMarketplaceListings() async {
    final response = await _rawRequest('/api/marketplace/', method: 'GET');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> createMarketplaceListing({
    required String title,
    required String description,
    required double price,
    required String category,
    required String condition,
    String? imageUrl,
  }) async {
    final response = await _rawRequest(
      '/api/marketplace/create',
      method: 'POST',
      body: {
        'title': title,
        'description': description,
        'price': price,
        'category': category,
        'condition': condition,
        if (imageUrl != null) 'image_url': imageUrl,
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> expressInterest(
    int listingId,
    String message,
  ) async {
    final response = await _rawRequest(
      '/api/marketplace/$listingId/interest',
      method: 'POST',
      body: {'message': message},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getListings({String? category}) async {
    final url = category != null
        ? '/api/marketplace/listings?category=$category'
        : '/api/marketplace/listings';
    final response = await _rawRequest(url, method: 'GET');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      return {'listings': body is List ? body : [], 'categories': []};
    }
    return {'listings': [], 'categories': []};
  }

  Future<Map<String, dynamic>?> createListing(Map<String, dynamic> data) async {
    final response = await _rawRequest(
      '/api/marketplace/listings',
      method: 'POST',
      body: data,
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>?> toggleInterest(int listingId) async {
    final response = await _rawRequest(
      '/api/marketplace/listings/$listingId/interest',
      method: 'POST',
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
}
