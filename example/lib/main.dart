import 'package:dio/dio.dart';

void main() {
  final dio = Dio();
  dio.get('https://pub.dev');
  print('Running example project with dio 3.0.10');
}
