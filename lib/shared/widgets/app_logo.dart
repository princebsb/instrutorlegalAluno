import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool horizontal;
  final Color? textColor;

  const AppLogo({
    super.key,
    this.size = 48,
    this.showText = true,
    this.horizontal = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final logoWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          'assets/images/logo_instrutor_legal.png',
          width: size * 0.7,
          height: size * 0.7,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.directions_car,
              size: size * 0.5,
              color: AppColors.primary,
            );
          },
        ),
      ),
    );

    if (!showText) return logoWidget;

    final textWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          'Instrutor Legal',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: size * 0.4,
            fontWeight: FontWeight.w800,
            color: textColor ?? AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );

    if (horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logoWidget,
          SizedBox(width: size * 0.25),
          textWidget,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoWidget,
        SizedBox(height: size * 0.2),
        textWidget,
      ],
    );
  }
}

class AppLogoHorizontal extends StatelessWidget {
  final double height;
  final Color? textColor;

  const AppLogoHorizontal({
    super.key,
    this.height = 40,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: height,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height * 0.25),
          ),
          child: Image.asset(
            'assets/images/logo_instrutor_legal.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.directions_car,
                size: height * 0.6,
                color: AppColors.primary,
              );
            },
          ),
        ),
        SizedBox(width: height * 0.25),
        Text(
          'Instrutor Legal',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: height * 0.5,
            fontWeight: FontWeight.w700,
            color: textColor ?? AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
