import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import 'secure_storage_service.dart';

class ImageUploadResult {
  final String? url;
  final String? error;
  final bool success;

  ImageUploadResult({this.url, this.error, required this.success});

  factory ImageUploadResult.success(String url) =>
      ImageUploadResult(url: url, success: true);
  factory ImageUploadResult.failure(String error) =>
      ImageUploadResult(error: error, success: false);
}

class ImageUploadService {
  static ImageUploadService? _instance;
  static ImageUploadService get instance =>
      _instance ??= ImageUploadService._();

  ImageUploadService._();

  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  Future<XFile?> pickFromCamera() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  Future<List<XFile>?> pickMultiple({int maxImages = 5}) async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (images.length > maxImages) {
        return images.sublist(0, maxImages);
      }
      return images;
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return null;
    }
  }

  Future<ImageUploadResult> uploadImage(
    File image, {
    String endpoint = '/api/upload/image',
  }) async {
    try {
      final uri = Uri.parse('${EnvConfig.apiUrl}$endpoint');
      final token = await SecureStorageService.instance.getToken();

      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 2),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['url'] != null) {
            return ImageUploadResult.success(data['url']);
          }
          return ImageUploadResult.failure(data['error'] ?? 'Upload failed');
        } catch (_) {
          return ImageUploadResult.failure('Invalid response format');
        }
      }

      return ImageUploadResult.failure('Upload failed: ${response.statusCode}');
    } on SocketException {
      return ImageUploadResult.failure('No internet connection');
    } on TimeoutException {
      return ImageUploadResult.failure('Upload timed out');
    } catch (e) {
      return ImageUploadResult.failure('Upload failed: $e');
    }
  }

  Future<ImageUploadResult> uploadMultiple(
    List<File> images, {
    String endpoint = '/api/upload/images',
  }) async {
    if (images.isEmpty) {
      return ImageUploadResult.failure('No images to upload');
    }

    final List<String> uploadedUrls = [];
    final List<String> errors = [];

    for (final image in images) {
      final result = await uploadImage(image, endpoint: endpoint);
      if (result.success) {
        uploadedUrls.add(result.url!);
      } else {
        errors.add('${image.path.split('/').last}: ${result.error}');
      }
    }

    if (uploadedUrls.isEmpty) {
      return ImageUploadResult.failure('All uploads failed');
    }

    if (errors.isNotEmpty) {
      debugPrint('Some uploads failed: $errors');
    }

    return ImageUploadResult.success(uploadedUrls.join(','));
  }

  Future<String?> saveImageToCache(File image, String filename) async {
    try {
      final cacheDir = await _getApplicationCacheDirectory();
      final savedPath = '${cacheDir.path}/$filename';
      await image.copy(savedPath);
      return savedPath;
    } catch (e) {
      debugPrint('Error saving image to cache: $e');
      return null;
    }
  }

  Future<Directory> _getApplicationCacheDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/data/user/0/com.example.asli_app/cache');
    }
    return Directory.systemTemp;
  }

  int getFileSizeInMB(File file) {
    return (file.lengthSync() / (1024 * 1024)).round();
  }

  bool isFileSizeValid(File file, {int maxSizeMB = 5}) {
    return getFileSizeInMB(file) <= maxSizeMB;
  }
}

class SocketException implements Exception {}

class TimeoutException implements Exception {}
