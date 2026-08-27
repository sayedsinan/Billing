import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';

/// Thrown for any failed API call. [message] is the server's error message
/// when available, otherwise a generic network/parse error description.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // JWT Interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _box.read<String>(_tokenKey);

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
      ),
    );

    // Log every request & response
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (object) => print(object),
      ),
    );
  }

  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;

  late final Dio _dio;
  final GetStorage _box = GetStorage();
  static const _tokenKey = 'auth_token';

  //Production
  // static const String baseUrl = 'https://billing-backend-hd2t.onrender.com/api';
  //Development
  static const String baseUrl = 'http://localhost:3000/api';

  // ── Token management ──────────────────────────────────────────────────
  String? get token => _box.read<String>(_tokenKey);
  bool get isLoggedIn => token != null && token!.isNotEmpty;

  void saveToken(String token) => _box.write(_tokenKey, token);
  void clearToken() => _box.remove(_tokenKey);

  Future<dynamic> _request(
    Future<Response> Function() call, {
    bool fullResponse = false,
  }) async {
    try {
      final res = await call();
      final body = res.data;

      print("✅ SUCCESS");
      print(body);

      if (fullResponse) return body;

      if (body is Map && body['success'] == true) {
        return body['data'];
      }

      return body is Map && body.containsKey('data') ? body['data'] : body;
    } on DioException catch (e) {
      print("❌ API ERROR");
      print("Status Code : ${e.response?.statusCode}");
      print("Response    : ${e.response?.data}");
      print("Request Data: ${e.requestOptions.data}");

      final serverMessage = e.response?.data is Map
          ? e.response?.data['message']
          : null;

      throw ApiException(
        serverMessage ?? e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      print("❌ Unexpected Error: $e");
      throw ApiException('Unexpected error: $e');
    }
  }
  // ── Auth ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? role,
  }) async {
    final data = await _request(
      () => _dio.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          if (role != null) 'role': role,
        },
      ),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _request(
      () => _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      ),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final data = await _request(() => _dio.get('/auth/me'));
    return Map<String, dynamic>.from(data);
  }

  // ── Products ─────────────────────────────────────────────────────────
  Future<List<dynamic>> getProducts({String? search, String? category}) async {
    final data = await _request(
      () => _dio.get(
        '/products',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (category != null) 'category': category,
        },
      ),
    );
    return List<dynamic>.from(data);
  }

  Future<List<String>> getCategories() async {
    final data = await _request(() => _dio.get('/products/categories'));
    return List<String>.from(data);
  }

  Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> payload,
  ) async {
    final data = await _request(() => _dio.post('/products', data: payload));
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateProduct(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final data = await _request(() => _dio.put('/products/$id', data: payload));
    return Map<String, dynamic>.from(data);
  }

  Future<void> deleteProduct(String id) async {
    await _request(() => _dio.delete('/products/$id'));
  }

  // ── Tables ───────────────────────────────────────────────────────────
  Future<List<dynamic>> getTables({String? search, String? status}) async {
    final data = await _request(
      () => _dio.get(
        '/tables',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (status != null) 'status': status,
        },
      ),
    );
    return List<dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getTableSummary() async {
    final data = await _request(() => _dio.get('/tables/summary'));
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> createTable(String tableId, int seats) async {
    final data = await _request(
      () => _dio.post('/tables', data: {'tableId': tableId, 'seats': seats}),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateTable(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final data = await _request(() => _dio.put('/tables/$id', data: payload));
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> updateTableStatus(
    String id,
    String status,
  ) async {
    final data = await _request(
      () => _dio.patch('/tables/$id/status', data: {'status': status}),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<void> deleteTable(String id) async {
    await _request(() => _dio.delete('/tables/$id'));
  }

  // ── Bills ────────────────────────────────────────────────────────────
  /// Direct/counter bill built straight from products — no table involved.
  Future<Map<String, dynamic>>  createDirectBill({
    required List<Map<String, dynamic>>
    items, // [{productId, qty}] or [{name, qty, rate}]
    String? customerName,
    double taxRate = 0,
    double discount = 0,
  }) async {
    final data = await _request(
      () => _dio.post(
        '/bills',
        data: {
          'items': items,
          if (customerName != null) 'customerName': customerName,
          'taxRate': taxRate,
          'discount': discount,
        },
      ),
    );
    return Map<String, dynamic>.from(data);
  }

  /// Bill generated from a restaurant table's current order.
  Future<Map<String, dynamic>> generateTableBill(
    String tableId, {
    double taxRate = 0,
    double discount = 0,
  }) async {
    final data = await _request(
      () => _dio.post(
        '/bills/generate/$tableId',
        data: {'taxRate': taxRate, 'discount': discount},
      ),
    );
    return Map<String, dynamic>.from(data);
  }

  /// Returns the raw bill list plus server-computed totalRevenue/count.
  Future<Map<String, dynamic>> getBills({
    String? status,
    String? tableId,
    DateTime? from,
    DateTime? to,
  }) async {
    final body = await _request(
      () => _dio.get(
        '/bills',
        queryParameters: {
          if (status != null) 'status': status,
          if (tableId != null) 'tableId': tableId,
          if (from != null) 'from': from.toIso8601String(),
          if (to != null) 'to': to.toIso8601String(),
        },
      ),
      fullResponse: true,
    );
    return Map<String, dynamic>.from(body);
  }

  Future<void> deleteBill(String id) async {
    await _request(() => _dio.delete('/bills/$id'));
  }

  Future<Map<String, dynamic>> getBillById(String id) async {
    final data = await _request(() => _dio.get('/bills/$id'));
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> payBill(String id, String paymentMethod) async {
    final data = await _request(
      () =>
          _dio.patch('/bills/$id/pay', data: {'paymentMethod': paymentMethod}),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> cancelBill(String id) async {
    final data = await _request(() => _dio.patch('/bills/$id/cancel'));
    return Map<String, dynamic>.from(data);
  }
}
