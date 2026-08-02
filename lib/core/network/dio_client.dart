import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../errors/app_exceptions.dart';

/// Dio HTTP client factory with sensible production defaults.
///
/// Adds JSON headers, a timeout, logging in debug mode, and maps transport
/// errors to typed [AppException]s so repositories stay portable.
class DioClient {
  DioClient._();

  static Dio create({String? baseUrl, List<Interceptor>? interceptors}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
        connectTimeout: const Duration(
          seconds: AppConfig.requestTimeoutSeconds,
        ),
        receiveTimeout: const Duration(
          seconds: AppConfig.requestTimeoutSeconds,
        ),
        sendTimeout: const Duration(seconds: AppConfig.requestTimeoutSeconds),
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(ErrorMapperInterceptor());
    if (interceptors != null) {
      dio.interceptors.addAll(interceptors);
    }
    return dio;
  }
}

/// Converts DioException into typed [AppException].
class ErrorMapperInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppException mapped;
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        mapped = const TimeoutException('Request timed out.', code: 'timeout');
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        mapped = const NetworkException(
          'No internet connection.',
          code: 'network',
        );
      case DioExceptionType.badCertificate:
        mapped = const NetworkException(
          'Bad certificate.',
          code: 'bad_certificate',
        );
      case DioExceptionType.cancel:
        mapped = const AppError('Request cancelled.', code: 'cancelled');
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        mapped = _fromStatus(status, err.message ?? 'Request failed.');
    }
    handler.next(err.copyWith(error: mapped));
  }

  AppException _fromStatus(int status, String message) {
    if (status == 401 || status == 403) {
      return AuthException(message, code: 'auth', statusCode: status);
    }
    if (status == 404) {
      return NotFoundException(message, code: 'not_found', statusCode: status);
    }
    if (status >= 500) {
      return ServerException(message, code: 'server', statusCode: status);
    }
    return BusinessException(message, code: 'business', statusCode: status);
  }
}
