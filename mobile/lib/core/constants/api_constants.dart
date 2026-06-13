import 'package:flutter/foundation.dart';

const String kApiBaseUrl = kIsWeb
    ? 'http://localhost:8080/api/v1'
    : 'http://10.0.2.2:8080/api/v1';

const int kDefaultPageSize = 10;
