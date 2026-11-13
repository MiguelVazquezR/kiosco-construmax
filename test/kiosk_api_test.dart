import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosco/data/kiosk_api.dart';
import 'package:kiosco/data/models/api_error.dart';
import 'package:kiosco/data/models/device_identity.dart';
import 'package:kiosco/data/models/gps_fix.dart';

/// Minimal [HttpClientAdapter] that answers from a script, so the api is
/// exercised through the real dio pipeline without any network.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, int statusCode) {
  return ResponseBody.fromString(
    body is String ? body : jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

DioKioskApi _apiWith(_ScriptedAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return DioKioskApi(dio: dio, baseUrl: 'https://erp.test/api/v1/kiosk/');
}

const DeviceIdentity _identity = DeviceIdentity(
  key: 'device-1',
  name: 'SM-T500',
);
const GpsFix _fix = GpsFix(
  latitude: -12.0464,
  longitude: -77.0428,
  accuracy: 6,
);

void main() {
  group('DioKioskApi', () {
    test('ping reads the server clock and the registered device', () async {
      final adapter = _ScriptedAdapter(
        (_) async => _json({
          'status': 'ok',
          'server_time': '2026-11-07T13:05:00-05:00',
          'device': {'id': 7, 'name': 'Tablet Recepción', 'location': 'Lima'},
        }, 200),
      );

      final ping = await _apiWith(adapter).ping();

      expect(adapter.requests.single.uri.toString(),
          'https://erp.test/api/v1/kiosk/ping');
      expect(ping.serverTime, DateTime.parse('2026-11-07T13:05:00-05:00'));
      expect(ping.device?.name, 'Tablet Recepción');
    });

    test('bootstrap sends the device identity as JSON', () async {
      final adapter = _ScriptedAdapter(
        (_) async => _json({
          'device': {'id': 7, 'name': 'Tablet Recepción'},
          'punchTypes': {'check_in': 'Entrada', 'check_out': 'Salida'},
          'faceRecognitionEnabled': true,
          'employeeNumberEnabled': true,
          'appName': 'Construmax',
        }, 200),
      );

      final context = await _apiWith(adapter).bootstrap(_identity);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/bootstrap');
      expect(request.uri.toString(), 'https://erp.test/api/v1/kiosk/bootstrap');
      expect(request.headers['Accept'], 'application/json');
      expect(request.data, {
        'device_key': 'device-1',
        'device_name': 'SM-T500',
      });
      expect(context.punchTypes.length, 2);
      expect(context.faceRecognitionEnabled, isTrue);
    });

    test('punch sends the employee number, type and GPS fix', () async {
      final adapter = _ScriptedAdapter(
        (_) async => _json({
          'user_name': 'Ana Torres',
          'type_label': 'Entrada',
          'punched_at': '08:03',
        }, 201),
      );

      final result = await _apiWith(adapter).punch(
        employeeNumber: 'EMP-0001',
        type: 'check_in',
        location: _fix,
        identity: _identity,
      );

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['employee_number'], 'EMP-0001');
      expect(body['type'], 'check_in');
      expect(body['latitude'], -12.0464);
      expect(body['longitude'], -77.0428);
      expect(body['location_accuracy'], 6);
      expect(body['device_key'], 'device-1');
      expect(body.containsKey('photo'), isFalse);
      expect(result.userName, 'Ana Torres');
    });

    test('face-punch sends the photo data URL', () async {
      final adapter = _ScriptedAdapter(
        (_) async => _json({'user_name': 'Ana Torres', 'similarity': 96}, 201),
      );

      await _apiWith(adapter).facePunch(
        type: 'check_in',
        photo: 'data:image/jpeg;base64,ZmFrZQ==',
        location: _fix,
        identity: _identity,
      );

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['photo'], 'data:image/jpeg;base64,ZmFrZQ==');
      expect(body['type'], 'check_in');
    });

    test('turns a 422 into an ApiError with field errors', () async {
      final adapter = _ScriptedAdapter(
        (_) async => _json({
          'message': 'Datos inválidos.',
          'errors': {
            'employee_number': ['El número de empleado no existe.'],
          },
        }, 422),
      );

      await expectLater(
        _apiWith(adapter).punch(
          employeeNumber: 'NOPE',
          type: 'check_in',
          location: _fix,
          identity: _identity,
        ),
        throwsA(
          isA<ApiError>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having(
                (error) => error.messageFor('employee_number'),
                'employee number message',
                'El número de empleado no existe.',
              ),
        ),
      );
    });

    test('keeps the code and body of a punch rejection', () async {
      final adapter = _ScriptedAdapter(
        (_) async => _json({
          'message': 'Ya registraste tu entrada a las 09:14. '
              'Selecciona otro tipo de registro.',
          'code': 'attendance_punch_not_allowed',
          'type': 'check_in',
          'last_registered_at': '09:14',
          'options': [
            {
              'type': 'check_in',
              'label': 'Entrada',
              'allowed': false,
              'reason': 'Ya registraste tu entrada a las 09:14.',
              'last_registered_at': '09:14',
            },
            {'type': 'check_out', 'label': 'Salida', 'allowed': true},
          ],
          'errors': {
            'type': ['Ya registraste tu entrada a las 09:14.'],
          },
        }, 422),
      );

      await expectLater(
        _apiWith(adapter).punch(
          employeeNumber: 'EMP-0001',
          type: 'check_in',
          location: _fix,
          identity: _identity,
        ),
        throwsA(
          isA<ApiError>()
              .having((error) => error.isPunchNotAllowed, 'rejection', isTrue)
              .having(
                (error) => error.code,
                'code',
                ApiError.punchNotAllowedCode,
              )
              .having(
                (error) => error.responseData?['type'],
                'rejected type',
                'check_in',
              )
              .having(
                (error) => error.responseData?['options'],
                'options',
                hasLength(2),
              ),
        ),
      );
    });

    test('maps 429 to the throttle message', () async {
      final adapter = _ScriptedAdapter(
        (_) async => _json({'message': 'Too Many Attempts.'}, 429),
      );

      await expectLater(
        _apiWith(adapter).punch(
          employeeNumber: 'EMP-0001',
          type: 'check_in',
          location: _fix,
          identity: _identity,
        ),
        throwsA(
          isA<ApiError>()
              .having((error) => error.isThrottled, 'throttled', isTrue)
              .having(
                (error) => error.message,
                'message',
                ApiError.throttleMessage,
              ),
        ),
      );
    });

    test('retries the connectivity probe once when offline', () async {
      final adapter = _ScriptedAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'offline',
        );
      });

      await expectLater(
        _apiWith(adapter).ping(),
        throwsA(
          isA<ApiError>().having(
            (error) => error.isUnreachable,
            'unreachable',
            isTrue,
          ),
        ),
      );
      expect(adapter.requests.length, 2);
    });

    test('a server error is not treated as a network failure', () async {
      final adapter = _ScriptedAdapter(
        (_) async => _json({'message': 'Server Error'}, 500),
      );

      await expectLater(
        _apiWith(adapter).ping(),
        throwsA(
          isA<ApiError>()
              .having((error) => error.statusCode, 'statusCode', 500)
              .having((error) => error.isUnreachable, 'unreachable', isFalse),
        ),
      );
      expect(adapter.requests.length, 1);
    });
  });
}
