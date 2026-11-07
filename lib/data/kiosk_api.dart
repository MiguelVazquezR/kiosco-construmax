import 'package:dio/dio.dart';

import '../config/kiosk_config.dart';
import 'models/api_error.dart';
import 'models/device_identity.dart';
import 'models/gps_fix.dart';
import 'models/kiosk_context.dart';
import 'models/punch_result.dart';

/// Result of `GET /ping` (connectivity probe + clock sync).
class KioskPing {
  const KioskPing({this.serverTime, this.device});

  final DateTime? serverTime;
  final KioskDevice? device;

  factory KioskPing.fromJson(Map<String, dynamic> json) => KioskPing(
    serverTime: DateTime.tryParse('${json['server_time'] ?? ''}'),
    device: KioskDevice.fromJson(json['device']),
  );
}

/// Backend contract used by the kiosk screens. Abstract so tests (and the
/// widget layer) never talk to `dio` directly.
abstract class KioskApi {
  Future<KioskPing> ping();

  Future<KioskContext> bootstrap(DeviceIdentity identity);

  Future<PunchResult> punch({
    required String employeeNumber,
    required String type,
    required GpsFix location,
    required DeviceIdentity identity,
    String? photo,
  });

  Future<PunchResult> facePunch({
    required String type,
    required String photo,
    required GpsFix location,
    required DeviceIdentity identity,
  });

  void close();
}

/// `dio` implementation of the kiosk API.
class DioKioskApi implements KioskApi {
  DioKioskApi({Dio? dio, String baseUrl = KioskConfig.baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: _baseUrl,
      connectTimeout: KioskConfig.connectTimeout,
      receiveTimeout: KioskConfig.receiveTimeout,
      sendTimeout: KioskConfig.sendTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (_) => true,
      responseType: ResponseType.json,
    );
  }

  final String _baseUrl;
  final Dio _dio;

  @override
  Future<KioskPing> ping() async {
    // One retry only for the connectivity probe.
    try {
      return KioskPing.fromJson(await _json(() => _dio.get<dynamic>('/ping')));
    } on ApiError catch (error) {
      if (!error.isUnreachable) rethrow;
      return KioskPing.fromJson(await _json(() => _dio.get<dynamic>('/ping')));
    }
  }

  @override
  Future<KioskContext> bootstrap(DeviceIdentity identity) async {
    final data = await _json(
      () => _dio.post<dynamic>('/bootstrap', data: identity.toJson()),
    );
    return KioskContext.fromJson(data);
  }

  @override
  Future<PunchResult> punch({
    required String employeeNumber,
    required String type,
    required GpsFix location,
    required DeviceIdentity identity,
    String? photo,
  }) async {
    final data = await _json(
      () => _dio.post<dynamic>(
        '/punch',
        data: {
          'employee_number': employeeNumber,
          'type': type,
          ...location.toJson(),
          ...identity.toJson(),
          'photo': ?photo,
        },
      ),
    );
    return PunchResult.fromJson(data);
  }

  @override
  Future<PunchResult> facePunch({
    required String type,
    required String photo,
    required GpsFix location,
    required DeviceIdentity identity,
  }) async {
    final data = await _json(
      () => _dio.post<dynamic>(
        '/face-punch',
        data: {
          'type': type,
          'photo': photo,
          ...location.toJson(),
          ...identity.toJson(),
        },
        options: Options(
          receiveTimeout: KioskConfig.facePunchTimeout,
          sendTimeout: KioskConfig.facePunchTimeout,
        ),
      ),
    );
    return PunchResult.fromJson(data);
  }

  @override
  void close() => _dio.close(force: true);

  Future<Map<String, dynamic>> _json(
    Future<Response<dynamic>> Function() send,
  ) async {
    Response<dynamic> response;
    try {
      response = await send();
    } on DioException catch (error) {
      throw _fromDio(error);
    }

    final status = response.statusCode ?? 0;
    final data = response.data;

    if (status >= 200 && status < 300) {
      if (data is Map) return Map<String, dynamic>.from(data);
      throw ApiError(statusCode: status, message: ApiError.unreachableMessage);
    }

    throw ApiError.fromResponse(status, data);
  }

  ApiError _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.badResponse:
        final response = error.response;
        return ApiError.fromResponse(
          response?.statusCode ?? 0,
          response?.data,
        );
      case DioExceptionType.cancel:
        return ApiError.unreachable('La solicitud fue cancelada.');
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError.unreachable('El servidor tardó demasiado en responder.');
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      case DioExceptionType.transformTimeout:
        return ApiError.unreachable();
    }
  }
}
