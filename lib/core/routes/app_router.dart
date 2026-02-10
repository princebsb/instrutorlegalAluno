import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/agendar/screens/agendar_aula_screen.dart';
import '../../features/agendar/screens/buscar_instrutor_screen.dart';
import '../../features/progresso/screens/progresso_screen.dart';
import '../../features/pagamentos/screens/pagamentos_screen.dart';
import '../../features/mensagens/screens/mensagens_screen.dart';
import '../../features/mensagens/screens/conversa_screen.dart';
import '../../features/configuracoes/screens/configuracoes_screen.dart';
import '../../features/configuracoes/screens/editar_perfil_screen.dart';
import '../../features/configuracoes/screens/alterar_senha_screen.dart';
import '../../features/aulas/screens/minhas_aulas_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/cadastro';
  static const forgotPassword = '/esqueci-senha';
  static const home = '/home';
  static const dashboard = '/dashboard';
  static const agendarAula = '/agendar';
  static const buscarInstrutor = '/buscar-instrutor';
  static const progresso = '/progresso';
  static const pagamentos = '/pagamentos';
  static const mensagens = '/mensagens';
  static const conversa = '/conversa';
  static const configuracoes = '/configuracoes';
  static const minhasAulas = '/minhas-aulas';
  static const editarPerfil = '/editar-perfil';
  static const alterarSenha = '/alterar-senha';
}

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authProvider = context.read<AuthProvider>();
      final isAuthenticated = authProvider.isAuthenticated;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword;
      final isSplash = state.matchedLocation == AppRoutes.splash;

      // Se está no splash, deixar continuar
      if (isSplash) return null;

      // Se não autenticado e tentando acessar rota protegida
      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.login;
      }

      // Se autenticado e tentando acessar rota de auth
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Main App Routes
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const _ExitAppWrapper(
          child: DashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.agendarAula,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AgendarAulaScreen(
            instrutorId: extra?['instrutorId'],
            instrutorNome: extra?['instrutorNome'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.buscarInstrutor,
        builder: (context, state) => const BuscarInstrutorScreen(),
      ),
      GoRoute(
        path: AppRoutes.progresso,
        builder: (context, state) => const ProgressoScreen(),
      ),
      GoRoute(
        path: AppRoutes.pagamentos,
        builder: (context, state) => const PagamentosScreen(),
      ),
      GoRoute(
        path: AppRoutes.mensagens,
        builder: (context, state) => const MensagensScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.conversa}/:id',
        builder: (context, state) {
          final conversaId = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ConversaScreen(
            conversaId: conversaId,
            nomeContato: extra?['nomeContato'] ?? 'Conversa',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.minhasAulas,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return MinhasAulasScreen(initialTab: extra?['initialTab'] ?? 0);
        },
      ),
      GoRoute(
        path: AppRoutes.configuracoes,
        builder: (context, state) => const ConfiguracoesScreen(),
      ),
      GoRoute(
        path: AppRoutes.editarPerfil,
        builder: (context, state) => const EditarPerfilScreen(),
      ),
      GoRoute(
        path: AppRoutes.alterarSenha,
        builder: (context, state) => const AlterarSenhaScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Página não encontrada',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.matchedLocation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Voltar ao início'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Wrapper para o Dashboard: duplo toque no voltar para sair do app
class _ExitAppWrapper extends StatefulWidget {
  final Widget child;
  const _ExitAppWrapper({required this.child});

  @override
  State<_ExitAppWrapper> createState() => _ExitAppWrapperState();
}

class _ExitAppWrapperState extends State<_ExitAppWrapper> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pressione voltar novamente para sair'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: widget.child,
    );
  }
}
