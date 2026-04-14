import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.gray500,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Perfil'),
            Tab(text: 'Segurança'),
            Tab(text: 'Notificações'),
            Tab(text: 'Privacidade'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPerfilTab(user),
          _buildSegurancaTab(),
          _buildNotificacoesTab(),
          _buildPrivacidadeTab(),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 4),
    );
  }

  Widget _buildPerfilTab(user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      user?.iniciais ?? 'U',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: AppColors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.nomeCompleto ?? 'Usuário',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            user?.email ?? '',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Info cards
          _buildInfoCard(
            icon: Icons.person_outline,
            title: 'Dados Pessoais',
            subtitle: 'Nome, telefone, CPF',
            onTap: () => context.push(AppRoutes.editarPerfil),
          ),
          _buildInfoCard(
            icon: Icons.location_on_outlined,
            title: 'Endereço',
            subtitle: _buildEnderecoCompleto(user),
          ),
          _buildInfoCard(
            icon: Icons.directions_car_outlined,
            title: 'Categoria Pretendida',
            subtitle: 'Categoria ${user?.categoriaPretendida ?? 'B'}',
            onTap: () {},
          ),

          const SizedBox(height: 24),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'Sair da Conta',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSegurancaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            icon: Icons.lock_outline,
            title: 'Alterar Senha',
            subtitle: 'Atualize sua senha de acesso',
            onTap: () => context.push(AppRoutes.alterarSenha),
          ),
          _buildInfoCard(
            icon: Icons.shield_outlined,
            title: 'Regras do Chat',
            subtitle: 'Veja as regras de uso das mensagens',
            onTap: _showChatRulesDialog,
          ),
          _buildInfoCard(
            icon: Icons.security,
            title: 'Autenticação em duas etapas',
            subtitle: 'Adicione uma camada extra de segurança',
            trailing: Switch(
              value: false,
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Em breve!')),
                );
              },
            ),
          ),
          _buildInfoCard(
            icon: Icons.devices,
            title: 'Dispositivos conectados',
            subtitle: 'Gerencie seus dispositivos',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Em breve!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificacoesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Canais de Notificação',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildNotificationToggle(
            'E-mail',
            Icons.email_outlined,
            true,
          ),
          _buildNotificationToggle(
            'SMS',
            Icons.sms_outlined,
            false,
          ),
          _buildNotificationToggle(
            'Push',
            Icons.notifications_outlined,
            true,
          ),

          const SizedBox(height: 24),

          Text(
            'Tipos de Notificação',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildNotificationToggle(
            'Aulas e Agendamentos',
            Icons.calendar_today_outlined,
            true,
          ),
          _buildNotificationToggle(
            'Mensagens',
            Icons.chat_bubble_outline,
            true,
          ),
          _buildNotificationToggle(
            'Pagamentos',
            Icons.payment_outlined,
            true,
          ),
          _buildNotificationToggle(
            'Promoções',
            Icons.local_offer_outlined,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacidadeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            icon: Icons.download_outlined,
            title: 'Baixar meus dados',
            subtitle: 'Exporte todas as suas informações',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preparando download...')),
              );
            },
          ),
          _buildInfoCard(
            icon: Icons.description_outlined,
            title: 'Termos de Uso',
            subtitle: 'Leia nossos termos',
            onTap: () => _openUrl('https://instrutorlegal.org/termos-de-uso'),
          ),
          _buildInfoCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de Privacidade',
            subtitle: 'Saiba como protegemos seus dados',
            onTap: () =>
                _openUrl('https://instrutorlegal.org/politica-de-privacidade'),
          ),
          _buildInfoCard(
            icon: Icons.cookie_outlined,
            title: 'Política de Cookies',
            subtitle: 'Informações sobre cookies',
            onTap: () => _openUrl('https://instrutorlegal.org/cookies'),
          ),

          const SizedBox(height: 24),

          // Desativar conta
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppColors.error),
                    SizedBox(width: 8),
                    Text(
                      'Zona de Perigo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ao desativar sua conta, você perderá acesso a todas as suas informações e histórico de aulas.',
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _showDeleteAccountDialog,
                  child: const Text(
                    'Desativar minha conta',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing:
            trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
        onTap: onTap,
      ),
    );
  }

  Widget _buildNotificationToggle(String title, IconData icon, bool value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gray500, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              // Salvar preferência
            },
          ),
        ],
      ),
    );
  }

  void _showChatRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text(
                'Regras do Chat',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Proibido compartilhar telefone, e-mail ou redes sociais',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildRuleRow('1ª vez: Aviso', Colors.amber),
                  const SizedBox(height: 6),
                  _buildRuleRow('2ª vez: Último aviso', Colors.orange),
                  const SizedBox(height: 6),
                  _buildRuleRow('3ª vez: Banimento', Colors.red),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('aluno_viu_regras_mensagens', false);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('O modal será exibido novamente ao acessar Mensagens')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Resetar Modal'),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String text, MaterialColor color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color.shade600, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color.shade700, fontSize: 12)),
      ],
    );
  }

  void _showLogoutDialog() {
    final parentContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da Conta'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await parentContext.read<AuthProvider>().logout();
              if (mounted) {
                context.go(AppRoutes.login);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final parentContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desativar Conta'),
        content: const Text(
          'Essa ação é irreversível. Todos os seus dados serão excluídos permanentemente. Tem certeza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success =
                  await parentContext.read<AuthProvider>().deleteAccount();
              if (success && mounted) {
                parentContext.go(AppRoutes.login);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sim, desativar'),
          ),
        ],
      ),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _buildEnderecoCompleto(user) {
    if (user == null) return 'Não informado';

    final partes = <String>[];

    if (user.endereco != null && user.endereco!.isNotEmpty) {
      partes.add(user.endereco!);
    }
    if (user.bairro != null && user.bairro!.isNotEmpty) {
      partes.add(user.bairro!);
    }
    if (user.cidade != null && user.cidade!.isNotEmpty) {
      String cidadeEstado = user.cidade!;
      if (user.estado != null && user.estado!.isNotEmpty) {
        cidadeEstado += '/${user.estado}';
      }
      partes.add(cidadeEstado);
    }
    if (user.cep != null && user.cep!.isNotEmpty) {
      partes.add('CEP: ${user.cep}');
    }

    return partes.isNotEmpty ? partes.join(', ') : 'Não informado';
  }
}
