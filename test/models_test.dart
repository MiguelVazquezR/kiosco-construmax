import 'package:flutter_test/flutter_test.dart';
import 'package:kiosco/data/models/api_error.dart';
import 'package:kiosco/data/models/device_identity.dart';
import 'package:kiosco/data/models/gps_fix.dart';
import 'package:kiosco/data/models/kiosk_context.dart';
import 'package:kiosco/data/models/punch_result.dart';

void main() {
  group('ApiError', () {
    test('maps 422 validation errors to field messages', () {
      final error = ApiError.fromResponse(422, {
        'message': 'El número de empleado no existe.',
        'errors': {
          'employee_number': ['El número de empleado no existe.'],
          'type': ['El tipo de fichaje no es válido.'],
        },
      });

      expect(error.isValidation, isTrue);
      expect(error.isUnreachable, isFalse);
      expect(error.messageFor('employee_number'),
          'El número de empleado no existe.');
      expect(error.messageFor('type'), 'El tipo de fichaje no es válido.');
      expect(error.messageFor('unknown'), error.message);
    });

    test('uses the throttle message for 429 without body', () {
      final error = ApiError.fromResponse(429, null);

      expect(error.isThrottled, isTrue);
      expect(error.message, ApiError.throttleMessage);
    });

    test('falls back to a friendly message for 5xx', () {
      final error = ApiError.fromResponse(503, '<html>down</html>');

      expect(error.statusCode, 503);
      expect(error.message, isNotEmpty);
    });

    test('keeps the server message when no field errors are present', () {
      final error = ApiError.fromResponse(403, {
        'message': 'El dispositivo no está activo.',
      });

      expect(error.message, 'El dispositivo no está activo.');
      expect(error.fieldErrors, isEmpty);
    });

    test('network failures are unreachable', () {
      expect(ApiError.unreachable().isUnreachable, isTrue);
      expect(ApiError.unreachable('sin red').message, 'sin red');
    });
  });

  group('KioskContext', () {
    test('keeps the punch type order sent by the server', () {
      final context = KioskContext.fromJson({
        'device': {'id': '7', 'name': 'Tablet Recepción'},
        'punchTypes': {
          'check_in': 'Entrada',
          'lunch_start': 'Inicio de comida',
          'check_out': 'Salida',
        },
        'faceRecognitionEnabled': true,
        'employeeNumberEnabled': false,
        'appName': 'Construmax',
        'server_time': '2026-11-07T13:05:00-05:00',
        'timezone': 'America/Lima',
      });

      expect(context.punchTypes.map((type) => type.key).toList(), [
        'check_in',
        'lunch_start',
        'check_out',
      ]);
      expect(context.punchTypes.first.label, 'Entrada');
      expect(context.device?.id, 7);
      expect(context.deviceName, 'Tablet Recepción');
      expect(context.deviceLocation, isNull);
      expect(context.faceRecognitionEnabled, isTrue);
      expect(context.employeeNumberEnabled, isFalse);
      expect(context.serverTime, isNotNull);
      expect(context.timezone, 'America/Lima');
    });

    test('defaults to an empty, unsupported context', () {
      final context = KioskContext.fromJson(const {});

      expect(context.punchTypes, isEmpty);
      expect(context.faceRecognitionEnabled, isFalse);
      expect(context.employeeNumberEnabled, isFalse);
      expect(context.appName, 'Construmax');
      expect(context.hasAnyMethod, isFalse);
    });
  });

  group('PunchResult', () {
    test('parses the success payload', () {
      final result = PunchResult.fromJson({
        'user_name': 'Ana Torres',
        'employee_number': 'EMP-0001',
        'type': 'check_in',
        'type_label': 'Entrada',
        'punched_at': '08:03',
        'date_label': '07/11/2026',
        'suggested_next': 'lunch_start',
        'suggested_next_label': 'Inicio de comida',
        'similarity': 97.5,
      });

      expect(result.userName, 'Ana Torres');
      expect(result.typeLabel, 'Entrada');
      expect(result.punchedAt, '08:03');
      expect(result.dateLabel, '07/11/2026');
      expect(result.suggestedNext, 'lunch_start');
      expect(result.suggestedNextLabel, 'Inicio de comida');
      expect(result.similarity, 97.5);
    });

    test('treats missing optional values as null', () {
      final result = PunchResult.fromJson(const {'user_name': 'Luis'});

      expect(result.userName, 'Luis');
      expect(result.suggestedNext, isNull);
      expect(result.suggestedNextLabel, isNull);
      expect(result.similarity, isNull);
    });
  });

  group('DeviceIdentity / GpsFix', () {
    test('omits empty device fields', () {
      expect(DeviceIdentity.unknown.toJson(), isEmpty);
      expect(
        const DeviceIdentity(key: 'abc', name: 'SM-T500').toJson(),
        {'device_key': 'abc', 'device_name': 'SM-T500'},
      );
    });

    test('sends accuracy only when known', () {
      expect(
        const GpsFix(latitude: 1.5, longitude: -2.5).toJson(),
        {'latitude': 1.5, 'longitude': -2.5},
      );
      expect(
        const GpsFix(latitude: 1.5, longitude: -2.5, accuracy: 8).toJson(),
        {'latitude': 1.5, 'longitude': -2.5, 'location_accuracy': 8},
      );
    });
  });
}
