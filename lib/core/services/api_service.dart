import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  String? _authToken;

  Future<String?> get authToken async {
    _authToken ??= await _storage.read(key: AppConstants.authTokenKey);
    return _authToken;
  }

  Future<void> setAuthToken(String token) async {
    _authToken = token;
    await _storage.write(key: AppConstants.authTokenKey, value: token);
  }

  Future<void> clearAuthToken() async {
    _authToken = null;
    await _storage.delete(key: AppConstants.authTokenKey);
  }

  Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await authToken;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(
    String endpoint, {
    bool requiresAuth = true,
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('${AppConstants.apiUrl}$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http
          .get(
            uri,
            headers: await _getHeaders(requiresAuth: requiresAuth),
          )
          .timeout(AppConstants.apiTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException('Tempo de conexão esgotado');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erro inesperado: $e');
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.apiUrl}$endpoint'),
            headers: await _getHeaders(requiresAuth: requiresAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConstants.apiTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException('Tempo de conexão esgotado');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erro inesperado: $e');
    }
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('${AppConstants.apiUrl}$endpoint'),
            headers: await _getHeaders(requiresAuth: requiresAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConstants.apiTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException('Tempo de conexão esgotado');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erro inesperado: $e');
    }
  }

  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('${AppConstants.apiUrl}$endpoint'),
            headers: await _getHeaders(requiresAuth: requiresAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConstants.apiTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException('Tempo de conexão esgotado');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erro inesperado: $e');
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${AppConstants.apiUrl}$endpoint'),
            headers: await _getHeaders(requiresAuth: requiresAuth),
          )
          .timeout(AppConstants.apiTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException('Tempo de conexão esgotado');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Erro inesperado: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    // Verifica se a resposta é HTML (erro do servidor)
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('text/html') ||
        (response.body.isNotEmpty && response.body.trimLeft().startsWith('<'))) {
      // Log para debug
      print('API retornou HTML - Status: ${response.statusCode}');
      print('URL: ${response.request?.url}');
      throw ApiException(
        'Erro de comunicação com o servidor (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    switch (response.statusCode) {
      case 200:
      case 201:
        return body;
      case 400:
        throw ApiException(
          body?['error'] ?? 'Requisição inválida',
          statusCode: 400,
          data: body,
        );
      case 401:
        throw ApiException(
          body?['error'] ?? 'Não autorizado',
          statusCode: 401,
          data: body,
        );
      case 403:
        throw ApiException(
          body?['error'] ?? 'Acesso negado',
          statusCode: 403,
          data: body,
        );
      case 404:
        throw ApiException(
          body?['error'] ?? 'Não encontrado',
          statusCode: 404,
          data: body,
        );
      case 409:
        throw ApiException(
          body?['error'] ?? 'Conflito de dados',
          statusCode: 409,
          data: body,
        );
      case 500:
        throw ApiException(
          'Erro interno do servidor',
          statusCode: 500,
          data: body,
        );
      default:
        throw ApiException(
          body?['error'] ?? 'Erro desconhecido',
          statusCode: response.statusCode,
          data: body,
        );
    }
  }
}
