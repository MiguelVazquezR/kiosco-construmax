import 'package:flutter_test/flutter_test.dart';
import 'package:kiosco/data/models/api_error.dart';
import 'package:kiosco/data/models/device_identity.dart';
import 'package:kiosco/data/models/gps_fix.dart';
import 'package:kiosco/data/models/kiosk_context.dart';
import 'package:kiosco/data/models/punch_not_allowed.dart';
import 'package:kiosco/data/models/punch_option.dart';
import 'package:kiosco/data/models/punch_result.dart';

import 'support/fakes.dart';

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

    test('keeps the business code and the decoded body', () {
      final error = ApiError.fromResponse(422, punchNotAllowedPayload);

      expect(error.statusCode, 422);
      expect(error.code, ApiError.punchNotAllowedCode);
      expect(error.isPunchNotAllowed, isTrue);
      expect(error.responseData?['type'], 'check_in');
      expect(error.messageFor('type'), startsWith('Ya registraste'));

      final validation = ApiError.fromResponse(422, {
        'message': 'El número de empleado no existe.',
      });

      expect(validation.code, isNull);
      expect(validation.isPunchNotAllowed, isFalse);
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
      expect(result.options, isEmpty);
    });

    test('reads the daily sequence of options', () {
      final result = PunchResult.fromJson({
        'user_name': 'Ana Torres',
        'options': punchNotAllowedPayload['options'],
      });

      expect(result.options, hasLength(6));
      expect(result.options.first.type, 'check_in');
      expect(result.options.first.allowed, isFalse);
      expect(result.options[1].allowed, isTrue);
    });
  });

  group('PunchOption', () {
    test('parses one entry of the daily sequence', () {
      final option = PunchOption.fromJson({
        'type': 'check_in',
        'label': 'Entrada',
        'allowed': false,
        'reason': 'Ya registraste tu entrada a las 09:14.',
        'last_registered_at': '09:14',
      });

      expect(option.type, 'check_in');
      expect(option.label, 'Entrada');
      expect(option.allowed, isFalse);
      expect(option.reason, 'Ya registraste tu entrada a las 09:14.');
      expect(option.lastRegisteredAt, '09:14');
    });

    test('drops unnamed entries and malformed lists', () {
      final options = PunchOption.listFromJson([
        {'type': 'lunch_start', 'label': 'Inicio de comida'},
        {'label': 'Sin tipo'},
        'basura',
      ]);

      expect(options, hasLength(1));
      expect(options.single.allowed, isFalse);
      expect(options.single.reason, isNull);
      expect(PunchOption.listFromJson(null), isEmpty);
      expect(PunchOption.listFromJson('nope'), isEmpty);
    });
  });

  group('PunchNotAllowed', () {
    test('builds the already-registered dialog from the 422 body', () {
      final rejection = PunchNotAllowed.fromApiError(punchNotAllowedError());

      expect(rejection.type, 'check_in');
      expect(rejection.title, 'Ese registro ya se realizó');
      expect(rejection.message, startsWith('Ya registraste tu entrada'));
      expect(rejection.lastRegisteredAt, '09:14');
      expect(rejection.typeLabel, 'Entrada');
      expect(rejection.options, hasLength(6));
      // The server message already asks for another type: no repetition.
      expect(rejection.showsHint, isFalse);
    });

    test('asks for another type when the message does not', () {
      final rejection = PunchNotAllowed(
        type: 'check_in',
        message: 'Ya registraste tu entrada a las 09:14.',
        lastRegisteredAt: '09:14',
      );

      expect(rejection.title, 'Ese registro ya se realizó');
      expect(rejection.showsHint, isTrue);
      expect(rejection.typeLabel, isEmpty);
    });

    test('uses the neutral title when the body has no registered time', () {
      final rejection = PunchNotAllowed(
        type: 'check_in',
        message: 'Ya registraste tu entrada a las 09:14.',
      );

      expect(rejection.title, 'No se pudo registrar ese movimiento');
      expect(rejection.showsHint, isTrue);
    });

    test('explains a disabled tile without a server round trip', () {
      final rejection = PunchNotAllowed.fromOption(
        sampleOptions[2],
        options: sampleOptions,
      );

      expect(rejection.type, 'lunch_end');
      expect(rejection.typeLabel, 'Fin de comida');
      expect(rejection.message, 'No tienes una comida en curso.');
      // Never registered, so it is not the "already registered" wording.
      expect(rejection.title, 'No se pudo registrar ese movimiento');
      expect(rejection.showsHint, isTrue);
      expect(rejection.lastRegisteredAt, isNull);
    });

    test('falls back when the rejection carries no message', () {
      final rejection = PunchNotAllowed.fromApiError(
        ApiError.fromResponse(422, {
          'code': ApiError.punchNotAllowedCode,
          'type': 'check_in',
        }),
      );

      expect(rejection.message, isNotEmpty);
      expect(rejection.options, isEmpty);
      expect(rejection.typeLabel, isEmpty);
      expect(rejection.title, 'No se pudo registrar ese movimiento');
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
