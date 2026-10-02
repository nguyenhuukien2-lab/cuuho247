import 'dart:io';

Future<void> main() async {
  final root = Directory('build/web').absolute;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8765);
  await for (final request in server) {
    var path = request.uri.path == '/' ? 'index.html' : request.uri.path.substring(1);
    final file = File('${root.path}${Platform.pathSeparator}${path.replaceAll('/', Platform.pathSeparator)}');
    if (!file.absolute.path.startsWith(root.path) || !await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
    } else {
      request.response.headers.contentType = switch (file.path.split('.').last) {
        'html' => ContentType.html,
        'js' => ContentType('application', 'javascript'),
        'json' => ContentType.json,
        'css' => ContentType('text', 'css'),
        'wasm' => ContentType('application', 'wasm'),
        'png' => ContentType('image', 'png'),
        _ => ContentType.binary,
      };
      await request.response.addStream(file.openRead());
    }
    await request.response.close();
  }
}
