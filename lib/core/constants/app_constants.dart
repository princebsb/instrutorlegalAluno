class AppConstants {
  AppConstants._();

  // API
  // Produção: https://instrutorlegal.org
  // Local Android Emulator: http://10.0.2.2:3000
  // Local dispositivo físico: http://SEU_IP:3000
  static const String baseUrl = 'https://instrutorlegal.org';
  static const String apiUrl = '$baseUrl/api';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String notificationPrefsKey = 'notification_prefs';
  static const String onboardingCompleteKey = 'onboarding_complete';

  // App Info
  static const String appName = 'Instrutor Legal Aluno';
  static const String appTagline = 'CNH + Barata Com Quem é Legalizado';
  static const String supportPhone = '5561995693166';
  static const String supportEmail = 'contato@instrutorlegal.org';
  static const String instagramUrl = 'https://www.instagram.com/instrutor.legal/';

  // Validation
  static const int minPasswordLength = 6;
  static const int phoneLength = 11;
  static const int cpfLength = 11;

  // Pagination
  static const int defaultPageSize = 20;

  // Cache
  static const Duration cacheValidDuration = Duration(minutes: 5);

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
}

class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/auth/login';
  static const String register = '/cadastro/aluno';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Aluno
  static String dashboard(String userId) => '/aluno/dashboard/$userId';
  static String progresso(String userId) => '/aluno/progresso/$userId';
  static String pagamentos(String userId) => '/aluno/pagamentos/$userId';

  // Usuário
  static String usuario(String userId) => '/usuarios/$userId';
  static String alterarSenha(String userId) => '/usuarios/$userId/senha';

  // Aulas
  static const String aulas = '/aulas';
  static String aula(String aulaId) => '/aulas/$aulaId';
  static String aulaStatus(String aulaId) => '/aulas/$aulaId/status';
  static String minhasAulas(String userId) => '/aluno/aulas/$userId';

  // Instrutores
  static const String instrutores = '/instrutores';
  static String instrutor(String instrutorId) => '/instrutores/$instrutorId';
  static const String listaInstrutores = '/lista-instrutores';

  // Mensagens
  static String conversas(String userId) => '/mensagens/conversas/$userId';
  static String mensagens(String userId, String outroId) => '/mensagens/$userId/$outroId';
  static String countNaoLidas(String userId) => '/mensagens/count/nao-lidas/$userId';
  static const String enviarMensagem = '/mensagens';

  // Notificações
  static String notificacoes(String userId) => '/notificacoes/$userId';
  static String marcarLida(String notifId) => '/notificacoes/$notifId/lida';

  // Cobrancas (PIX)
  static const String gerarCobranca = '/cobrancas/gerar';
  static String cobranca(String aulaId) => '/cobrancas/$aulaId';

  // Confirmação e Disputa de Aula
  static String confirmarAulaRealizada(String aulaId) => '/aulas/$aulaId/confirmar-realizada';
  static String abrirDisputa(String aulaId) => '/aulas/$aulaId/abrir-disputa';
}
