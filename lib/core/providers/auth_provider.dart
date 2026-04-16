import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../constants/app_constants.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _error;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        _user = _authService.currentUser;
        _status = AuthStatus.authenticated;

        // Registrar token FCM para receber notificações push
        _registerFCMToken();
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String senha) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.login(email, senha);
      _status = AuthStatus.authenticated;
      notifyListeners();

      // Registrar token FCM para receber notificações push
      _registerFCMToken();

      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erro ao fazer login. Tente novamente.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> _registerFCMToken() async {
    try {
      final token = await NotificationService.getToken();
      if (token != null && _user != null) {
        final api = ApiService();
        await api.post(
          ApiEndpoints.fcmRegister,
          body: {
            'usuario_id': _user!.id,
            'token': token,
            'platform': 'android',
          },
        );
        debugPrint('✅ Token FCM registrado no backend');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao registrar token FCM: $e');
      // Não falhar o login se não conseguir registrar o token
    }
  }

  Future<bool> register({
    required String nomeCompleto,
    required String email,
    required String senha,
    String? telefone,
    String? dataNascimento,
    String? cpf,
    String? cep,
    String? endereco,
    String? bairro,
    String? cidade,
    String? estado,
    required bool possuiCnh,
    required String categoriaPretendida,
    double? latitude,
    double? longitude,
  }) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.register(
        nomeCompleto: nomeCompleto,
        email: email,
        senha: senha,
        telefone: telefone,
        dataNascimento: dataNascimento,
        cpf: cpf,
        cep: cep,
        endereco: endereco,
        bairro: bairro,
        cidade: cidade,
        estado: estado,
        possuiCnh: possuiCnh,
        categoriaPretendida: categoriaPretendida,
        latitude: latitude,
        longitude: longitude,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();

      // Registrar token FCM para receber notificações push
      _registerFCMToken();

      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erro ao cadastrar. Tente novamente.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      await _authService.forgotPassword(email);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erro ao enviar email. Tente novamente.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String senhaAtual, String novaSenha) async {
    try {
      await _authService.changePassword(senhaAtual, novaSenha);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erro ao alterar senha. Tente novamente.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      _user = await _authService.updateProfile(
        nomeCompleto: data['nome_completo'],
        email: data['email'],
        telefone: data['telefone'],
        endereco: data['endereco'],
        bairro: data['bairro'],
        cep: data['cep'],
        cidade: data['cidade'],
        estado: data['estado'],
        cpf: data['cpf'],
        dataNascimento: data['data_nascimento'],
      );
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erro ao atualizar perfil. Tente novamente.';
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshUser() async {
    try {
      _user = await _authService.refreshUser();
      notifyListeners();
    } catch (e) {
      // Silencioso
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    try {
      await _authService.deleteAccount();
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erro ao excluir conta. Tente novamente.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }
}
