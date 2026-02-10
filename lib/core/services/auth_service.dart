import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _api = ApiService();
  final _storage = const FlutterSecureStorage();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  Future<bool> isLoggedIn() async {
    final token = await _api.authToken;
    if (token == null) return false;

    // Tentar carregar dados do usuário salvos
    final userData = await _storage.read(key: AppConstants.userDataKey);
    if (userData != null) {
      _currentUser = UserModel.fromJson(jsonDecode(userData));
      return true;
    }
    return false;
  }

  Future<UserModel> login(String email, String senha) async {
    final response = await _api.post(
      ApiEndpoints.login,
      body: {'email': email, 'senha': senha},
      requiresAuth: false,
    );

    final token = response['token'];
    final user = UserModel.fromJson(response['usuario']);

    // Verificar se é aluno
    if (user.tipoUsuario != 'aluno') {
      throw ApiException('Este aplicativo é exclusivo para alunos');
    }

    // Salvar token e dados do usuário
    await _api.setAuthToken(token);
    await _storage.write(
      key: AppConstants.userDataKey,
      value: jsonEncode(user.toJson()),
    );

    _currentUser = user;
    return user;
  }

  Future<UserModel> register({
    required String nomeCompleto,
    required String email,
    required String senha,
    required String telefone,
    required String dataNascimento,
    required String cpf,
    required String cep,
    String? endereco,
    required String cidade,
    required String estado,
    required bool possuiCnh,
    required String categoriaPretendida,
  }) async {
    final response = await _api.post(
      ApiEndpoints.register,
      body: {
        'nomeCompleto': nomeCompleto,
        'email': email,
        'senha': senha,
        'telefone': telefone,
        'dataNascimento': dataNascimento,
        'cpf': cpf,
        'cep': cep,
        'endereco': endereco,
        'cidade': cidade,
        'estado': estado,
        'possuiCnh': possuiCnh ? 'sim' : 'nao',
        'categoriaPretendida': categoriaPretendida,
      },
      requiresAuth: false,
    );

    // Após registro, fazer login automaticamente
    return await login(email, senha);
  }

  Future<void> forgotPassword(String email) async {
    await _api.post(
      ApiEndpoints.forgotPassword,
      body: {'email': email},
      requiresAuth: false,
    );
  }

  Future<void> resetPassword(String token, String novaSenha) async {
    await _api.post(
      ApiEndpoints.resetPassword,
      body: {'token': token, 'novaSenha': novaSenha},
      requiresAuth: false,
    );
  }

  Future<void> changePassword(String senhaAtual, String novaSenha) async {
    if (_currentUser == null) throw ApiException('Usuário não autenticado');

    await _api.patch(
      ApiEndpoints.alterarSenha(_currentUser!.id),
      body: {
        'senha_atual': senhaAtual,
        'nova_senha': novaSenha,
      },
    );
  }

  Future<UserModel> updateProfile({
    String? nomeCompleto,
    String? email,
    String? telefone,
    String? endereco,
    String? cep,
    String? cidade,
    String? estado,
    String? cpf,
    String? dataNascimento,
    String? numero,
    String? complemento,
    String? bairro,
  }) async {
    if (_currentUser == null) throw ApiException('Usuário não autenticado');

    final response = await _api.put(
      ApiEndpoints.usuario(_currentUser!.id),
      body: {
        if (nomeCompleto != null) 'nome_completo': nomeCompleto,
        if (email != null) 'email': email,
        if (telefone != null) 'telefone': telefone,
        if (endereco != null) 'endereco': endereco,
        if (cep != null) 'cep': cep,
        if (cidade != null) 'cidade': cidade,
        if (estado != null) 'estado': estado,
        if (cpf != null) 'cpf': cpf,
        if (dataNascimento != null) 'data_nascimento': dataNascimento,
        if (numero != null) 'numero': numero,
        if (complemento != null) 'complemento': complemento,
        if (bairro != null) 'bairro': bairro,
      },
    );

    final updatedUser = UserModel.fromJson(response);
    await _storage.write(
      key: AppConstants.userDataKey,
      value: jsonEncode(updatedUser.toJson()),
    );

    _currentUser = updatedUser;
    return updatedUser;
  }

  Future<UserModel> refreshUser() async {
    if (_currentUser == null) throw ApiException('Usuário não autenticado');

    final response = await _api.get(ApiEndpoints.usuario(_currentUser!.id));
    final user = UserModel.fromJson(response);

    await _storage.write(
      key: AppConstants.userDataKey,
      value: jsonEncode(user.toJson()),
    );

    _currentUser = user;
    return user;
  }

  Future<void> logout() async {
    await _api.clearAuthToken();
    await _storage.delete(key: AppConstants.userDataKey);
    _currentUser = null;
  }

  Future<void> deleteAccount() async {
    if (_currentUser == null) throw ApiException('Usuário não autenticado');

    await _api.delete(ApiEndpoints.usuario(_currentUser!.id));
    await logout();
  }
}
