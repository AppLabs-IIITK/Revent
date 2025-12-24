import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hello_truck_app/utils/logger.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hello_truck_app/providers/auth_providers.dart';
import 'package:hello_truck_app/auth/api_exception.dart';
import 'package:hello_truck_app/utils/constants.dart';

class API {
  final Dio _dio = Dio();
  String? accessToken;
  late CacheStore _cacheStore;
  late CacheOptions _cacheOptions;
  final storage = const FlutterSecureStorage();
  final Ref ref;

  API({this.accessToken, required this.ref});

  void updateToken(String? newToken) {
    accessToken = newToken;
  }

  Future<void> init() async {
    final dir = await getTemporaryDirectory();

    _cacheStore = HiveCacheStore(dir.path, hiveBoxName: 'hello_truck_cache');

    _cacheOptions = CacheOptions(
      store: _cacheStore,
      hitCacheOnNetworkFailure: true,
      policy: CachePolicy.request,
      hitCacheOnErrorCodes: [
        429,  // Too many requests
        408, 499,  // Client timeouts
        500, 501, 502, 503, 504, 505, 506, 507, 509,  // Server errors
        521, 522, 523, 524,  // Cloudflare specific network errors
      ],
      maxStale: const Duration(days: 7),
      priority: CachePriority.normal,
      keyBuilder: CacheOptions.defaultCacheKeyBuilder,
      allowPostMethod: false,
    );

    _dio.interceptors.addAll([
      _authInterceptor,
      DioCacheInterceptor(options: _cacheOptions),
      _errorInterceptor,
    ]);
  }

  InterceptorsWrapper get _authInterceptor => InterceptorsWrapper(
    onRequest: (options, handler) {
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
      return handler.next(options);
    },
  );

  InterceptorsWrapper get _errorInterceptor => InterceptorsWrapper(
    onError: (error, handler) {
      if (error.response?.statusCode == 401) {
        // Schedule sign out after 2 seconds if the error is an unauthorized error
        Future.delayed(const Duration(seconds: 2), () {
          signOut();
        });
      }

      // Convert DioException to APIException and continue with error handling
      handler.reject(APIException.fromDioException(error));
    },
  );

  Future<Response> get(String path, {CachePolicy? policy}) => _dio.get(
    '$baseUrl$path',
    options: _cacheOptions
        .copyWith(policy: policy ?? _cacheOptions.policy)
        .toOptions(),
  );

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post('$baseUrl$path', data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put('$baseUrl$path', data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch('$baseUrl$path', data: data);

  Future<Response> delete(String path) => _dio.delete('$baseUrl$path');

  Future<String> uploadFile(File file, String filePath, String type) async {
    final prefix = ['png', 'jpg', 'jpeg'].contains(type.split('/').last) ? 'image' : 'application';
    final fileType = '$prefix/${type.split('/').last}';
    try {
      final signedUrlResponse = await _dio.get(
        '$baseUrl/bookings/customer/upload-url?filePath=$filePath&type=$fileType',
      );

      final signedUrl = signedUrlResponse.data['signedUrl'];
      final publicUrl = signedUrlResponse.data['publicUrl'];
      final token = signedUrlResponse.data['token'];

      await _dio.put(
        signedUrl,
        data: file.readAsBytesSync(),
        options: Options(
          contentType: fileType,
          headers: {
            'x-goog-meta-firebasestoragedownloadtokens': token,
          },
        ),
      );

      return publicUrl;
    } catch (e) {
      AppLogger.log('Error uploading file: $e');
      rethrow;
    }
  }

  Future<void> clearCache() async {
    await _cacheStore.clean();
  }

  Future<void> dispose() async {
    await _cacheStore.close();
  }

  // ==========================
  // SSE streaming helpers
  // ==========================
  Stream<String> streamSseRaw(String absoluteUrl) {
    final controller = StreamController<String>.broadcast();
    var cancelled = false;
    StreamSubscription? currentSubscription;

    Future<void> connect([int attempt = 0]) async {
      if (cancelled) return;
      try {
        final res = await _dio.get(
          absoluteUrl,
          options: Options(
            responseType: ResponseType.stream,
            headers: { HttpHeaders.acceptHeader: 'text/event-stream' },
            receiveTimeout: Duration.zero,
          ),
        );
        if (res.statusCode != 200 || res.data == null) {
          throw StateError('SSE HTTP ${res.statusCode}');
        }

        final stream = (res.data as ResponseBody).stream.map((c) => utf8.decode(c));
        final buffer = StringBuffer();
        var dataAcc = '';

        currentSubscription = stream.listen((chunk) {
          if (cancelled || controller.isClosed) return;
          buffer.write(chunk);
          final parts = buffer.toString().split('\n');
          buffer
            ..clear()
            ..write(parts.removeLast());
          for (final line in parts) {
            final l = line.trimRight();
            if (l.isEmpty) {
              if (dataAcc.isNotEmpty) {
                if (!cancelled && !controller.isClosed) {
                  controller.add(dataAcc.trim());
                }
                dataAcc = '';
              }
              continue;
            }
            if (l.startsWith(':')) continue;
            if (l.startsWith('data:')) {
              dataAcc += '${l.substring(5).trimLeft()}\n';
            }
          }
        });

        currentSubscription!.onDone(() {
          if (cancelled) return;
          final backoff = Duration(seconds: (2 * (attempt + 1)).clamp(0, 15));
          Future.delayed(backoff, () => connect(attempt + 1));
        });

        currentSubscription!.onError((_) {
          if (cancelled) return;
          final backoff = Duration(seconds: (2 * (attempt + 1)).clamp(0, 15));
          Future.delayed(backoff, () => connect(attempt + 1));
        });
      } catch (_) {
        if (cancelled) return;
        final backoff = Duration(seconds: (2 * (attempt + 1)).clamp(0, 15));
        Future.delayed(backoff, () => connect(attempt + 1));
      }
    }

    controller.onListen = connect;
    controller.onCancel = () async {
      cancelled = true;
      await currentSubscription?.cancel();
      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  Stream<Map<String, dynamic>> streamSseJson(String absoluteUrl) {
    return streamSseRaw(absoluteUrl).map((payload) {
      try {
        final decoded = jsonDecode(payload);
        return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
      } catch (_) {
        return {'raw': payload};
      }
    });
  }

  // Auth Methods
  Future<void> sendOtp(String phoneNumber) async {
    final response = await post(
      '/auth/customer/send-otp',
      data: {'phoneNumber': phoneNumber},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send OTP');
    }
  }

  Future<void> verifyOtp(String phoneNumber, String otp) async {
    final staleRefreshToken = await storage.read(key: 'staleRefreshToken');

    final response = await post(
      '/auth/customer/verify-otp',
      data: {
        'phoneNumber': phoneNumber,
        'otp': otp,
        'staleRefreshToken': staleRefreshToken,
      },
    );
    await Future.wait([
      storage.write(
        key: 'refreshToken',
        value: response.data['refreshToken'],
      ),
      storage.write(key: 'accessToken', value: response.data['accessToken']),
    ]);

    ref.read(authClientProvider).emitSignIn(
      accessToken: response.data['accessToken'],
      refreshToken: response.data['refreshToken'],
    );
  }

  Future<void> signOut() async {
    final refreshToken = await storage.read(key: 'refreshToken');
    await Future.wait([
      storage.delete(key: 'refreshToken'),
      storage.delete(key: 'accessToken'),
      FirebaseMessaging.instance.deleteToken(),
    ]);
    ref.read(authClientProvider).emitSignOut();

    if (refreshToken != null) {
      post('/auth/customer/logout', data: {'refreshToken': refreshToken}).catchError((e) {
        // If the logout fails, save the refresh token to the storage
        storage.write(key: 'staleRefreshToken', value: refreshToken);
        AppLogger.log('Error logging out: $e');
        return Response(requestOptions: RequestOptions(path: ''));
      });
    }
  }
}