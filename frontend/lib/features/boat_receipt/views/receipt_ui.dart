import 'package:flutter/material.dart';

abstract final class ReceiptColors {
  static const blue = Color(0xFF0369A1);
  static const blueStrong = Color(0xFF075985);
  static const blueSoft = Color(0xFFE0F2FE);
  static const green = Color(0xFF047857);
  static const greenSoft = Color(0xFFD1FAE5);
  static const amber = Color(0xFFB45309);
  static const red = Color(0xFFB91C1C);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const canvas = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const darkCanvas = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF151F2E);
  static const darkLine = Color(0xFF2A3A4F);
}

abstract final class ReceiptUi {
  static Color canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? ReceiptColors.darkCanvas
      : ReceiptColors.canvas;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? ReceiptColors.darkSurface
      : Colors.white;

  static Color line(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? ReceiptColors.darkLine
      : ReceiptColors.line;

  static Color secondaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFAFC0D4)
      : ReceiptColors.muted;

  static AppBar appBar(
    BuildContext context,
    String title, {
    String? subtitle,
    List<Widget>? actions,
  }) {
    return AppBar(
      backgroundColor: canvas(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: Navigator.canPop(context) ? 0 : 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: secondaryText(context),
              ),
            ),
        ],
      ),
      actions: actions,
    );
  }

  static InputDecoration input(
    BuildContext context, {
    String? hint,
    IconData? icon,
    String? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      suffixText: suffix,
      prefixIcon: icon == null ? null : Icon(icon, color: ReceiptColors.blue),
      filled: true,
      fillColor: surface(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ReceiptColors.blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ReceiptColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ReceiptColors.red, width: 2),
      ),
    );
  }
}

class ReceiptSurface extends StatelessWidget {
  const ReceiptSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Ink(
      padding: padding,
      decoration: BoxDecoration(
        color: ReceiptUi.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReceiptUi.line(context)),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class ReceiptSectionTitle extends StatelessWidget {
  const ReceiptSectionTitle(
    this.title, {
    super.key,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          child: Text(action!, style: const TextStyle(fontSize: 16)),
        ),
    ],
  );
}

class ReceiptEmptyState extends StatelessWidget {
  const ReceiptEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: ReceiptColors.blueSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: ReceiptColors.blue),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: ReceiptUi.secondaryText(context),
            ),
          ),
        ],
      ),
    ),
  );
}

class ReceiptErrorState extends StatelessWidget {
  const ReceiptErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ReceiptSurface(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, color: ReceiptColors.red),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
        ),
        if (onRetry != null)
          IconButton(
            onPressed: onRetry,
            tooltip: 'Thử lại',
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
  );
}
