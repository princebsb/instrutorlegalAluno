import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;

import '../../core/theme/app_colors.dart';
import '../../core/routes/app_router.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final int unreadMessages;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    this.unreadMessages = 0,
  });

  /// Navega para uma rota do bottom nav.
  /// Para Dashboard: usa go() (limpa a stack).
  /// Para outras abas: vai ao dashboard primeiro, depois push() na tela destino.
  /// Isso cria uma stack real (dashboard → tela), permitindo que o botão
  /// voltar do Android retorne ao dashboard em vez de fechar o app.
  void _navigateTo(BuildContext context, String route) {
    if (route == AppRoutes.dashboard) {
      context.go(AppRoutes.dashboard);
    } else {
      context.go(AppRoutes.dashboard);
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Início',
                isActive: currentIndex == 0,
                onTap: () => _navigateTo(context, AppRoutes.dashboard),
              ),
              _NavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                label: 'Agendar',
                isActive: currentIndex == 1,
                onTap: () => _navigateTo(context, AppRoutes.agendarAula),
              ),
              _NavItem(
                icon: Icons.trending_up_outlined,
                activeIcon: Icons.trending_up,
                label: 'Progresso',
                isActive: currentIndex == 2,
                onTap: () => _navigateTo(context, AppRoutes.progresso),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Mensagens',
                isActive: currentIndex == 3,
                badgeCount: unreadMessages,
                onTap: () => _navigateTo(context, AppRoutes.mensagens),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Perfil',
                isActive: currentIndex == 4,
                onTap: () => _navigateTo(context, AppRoutes.configuracoes),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      isActive ? activeIcon : icon,
      color: isActive ? AppColors.primary : AppColors.gray400,
      size: 24,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            badgeCount > 0
                ? badges.Badge(
                    badgeContent: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    badgeStyle: const badges.BadgeStyle(
                      badgeColor: AppColors.error,
                      padding: EdgeInsets.all(4),
                    ),
                    child: iconWidget,
                  )
                : iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
