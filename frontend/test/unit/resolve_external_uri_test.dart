import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/navigation.dart';

void main() {
  final origin = Uri.parse('http://192.168.1.10:8080/web/devices');

  test('resolves an origin-relative path against the current host', () {
    expect(
      resolveExternalUri('/api/docs', base: origin),
      Uri.parse('http://192.168.1.10:8080/api/docs'),
    );
  });

  test('preserves the scheme and host of an https origin', () {
    final secure = Uri.parse('https://example.com/web/');
    expect(
      resolveExternalUri('/api/docs', base: secure),
      Uri.parse('https://example.com/api/docs'),
    );
  });

  test('returns an absolute URL unchanged', () {
    expect(
      resolveExternalUri('https://docs.example.com/spec', base: origin),
      Uri.parse('https://docs.example.com/spec'),
    );
  });
}
