// Dev-only bridge used to test the kiosk app on a physical Android device.
//
// The device cannot reach this machine over the network: Herd publishes the
// site on `127.0.0.1:443` only, `construmax.test` does not resolve inside the
// phone, and the Herd certificate is not trusted by Android. `adb reverse`
// fixes the transport but not the `Host` header (nginx answers 404 for
// `Host: localhost`), so this process listens on plain HTTP and relays every
// request to the real HTTPS site with the right `Host`/SNI.
//
// ```
// dart run tool/dev_proxy.dart --port 8001 --upstream construmax.test
// ```
//
// Then: `adb reverse tcp:8001 tcp:8001` and point the app at
// `http://localhost:8001/api/v1/kiosk`.
import 'dart:async';
import 'dart:io';

// Headers that describe the connection itself, not the request payload.
const _skipRequestHeaders = {
  'host',
  'connection',
  'keep-alive',
  'proxy-connection',
  'transfer-encoding',
  'upgrade',
  'content-length',
  // The upstream picks the encoding (Herd gzips anyway) and we relay the body
  // together with its `content-encoding`, so the client decodes it once.
  'accept-encoding',
};

// Framing headers are recomputed by dart:io on the way back.
const _skipResponseHeaders = {
  'connection',
  'keep-alive',
  'transfer-encoding',
  'content-length',
};

Future<void> main(List<String> args) async {
  final options = _parseOptions(args);
  final upstreamHost = options['upstream'] ?? 'construmax.test';
  final upstreamPort = int.tryParse(options['upstream-port'] ?? '') ?? 443;
  final listenPort = int.tryParse(options['port'] ?? '') ?? 8001;

  final client = HttpClient();
  // Loopback only: we talk to the local Herd certificate, never the internet.
  client.badCertificateCallback = (_, _, _) => true;
  client.idleTimeout = const Duration(seconds: 30);
  // Forward bodies exactly as they arrive: if we let dart:io uncompress them the
  // `content-encoding` header would no longer match the bytes the app receives.
  client.autoUncompress = false;

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, listenPort);
  stdout.writeln(
    '[tunel] escuchando en http://127.0.0.1:$listenPort -> '
    'https://$upstreamHost:$upstreamPort',
  );

  await for (final request in server) {
    unawaited(_forward(request, client, upstreamHost, upstreamPort, listenPort));
  }
}

Future<void> _forward(
  HttpRequest request,
  HttpClient client,
  String upstreamHost,
  int upstreamPort,
  int listenPort,
) async {
  final stopwatch = Stopwatch()..start();
  final target = request.uri.hasQuery
      ? '${request.uri.path}?${request.uri.query}'
      : request.uri.path;

  try {
    final upstream = await client.openUrl(
      request.method,
      Uri(
        scheme: 'https',
        host: upstreamHost,
        port: upstreamPort,
        path: request.uri.path,
        query: request.uri.hasQuery ? request.uri.query : null,
      ),
    );
    // Redirects must be handled by the app: it keeps its own session state.
    upstream.followRedirects = false;

    request.headers.forEach((name, values) {
      if (_skipRequestHeaders.contains(name.toLowerCase())) return;
      for (final value in values) {
        upstream.headers.add(name, value);
      }
    });
    upstream.headers.set(HttpHeaders.hostHeader, upstreamHost);
    if (request.contentLength >= 0) {
      upstream.contentLength = request.contentLength;
    }

    await upstream.addStream(request);

    final response = await upstream.close();
    final out = request.response..statusCode = response.statusCode;
    response.headers.forEach((name, values) {
      if (_skipResponseHeaders.contains(name.toLowerCase())) return;
      for (final value in values) {
        out.headers.add(name, _rewrite(value, upstreamHost, listenPort));
      }
    });
    await out.addStream(response);
    await out.close();

    stdout.writeln(
      '[tunel] ${request.method} $target -> ${response.statusCode} '
      '(${stopwatch.elapsedMilliseconds}ms)',
    );
  } catch (error) {
    stdout.writeln('[tunel] ${request.method} $target -> ERROR $error');
    try {
      final out = request.response
        ..statusCode = HttpStatus.badGateway
        ..write('Tunel no disponible: $error');
      await out.close();
    } catch (_) {
      // The client is already gone; nothing left to do.
    }
  }
}

/// Keep absolute links/redirects pointing at the tunnel, not at the real host.
String _rewrite(String value, String upstreamHost, int listenPort) {
  if (!value.contains(upstreamHost)) return value;
  return value
      .replaceAll('https://$upstreamHost', 'http://localhost:$listenPort')
      .replaceAll('http://$upstreamHost', 'http://localhost:$listenPort');
}

Map<String, String> _parseOptions(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final separator = arg.indexOf('=');
    if (separator != -1) {
      options[arg.substring(2, separator)] = arg.substring(separator + 1);
      continue;
    }
    if (i + 1 < args.length) options[arg.substring(2)] = args[++i];
  }
  return options;
}
