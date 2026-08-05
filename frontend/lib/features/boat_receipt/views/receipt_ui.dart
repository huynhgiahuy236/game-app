import 'package:flutter/material.dart';

abstract final class ReceiptColors {
  // Lavender palette inspired by the reference UI. Existing names are kept so
  // every receipt screen picks up the new identity consistently.
  static const blue = Color(0xFF7C5CC4);
  static const blueStrong = Color(0xFF6542B5);
  static const blueSoft = Color(0xFFE9E0FF);
  static const green = Color(0xFF047857);
  static const greenSoft = Color(0xFFBBF7D0);
  static const amber = Color(0xFFB45309);
  static const red = Color(0xFFB91C1C);
  static const ink = Color(0xFF252033);
  static const muted = Color(0xFF716A7F);
  static const canvas = Color(0xFFF5F0FF);
  static const line = Color(0xFFE3D8F7);
  static const darkCanvas = Color(0xFF171222);
  static const darkSurface = Color(0xFF241D32);
  static const darkLine = Color(0xFF493B62);
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
    this.borderColor,
    this.surfaceColor,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final content = Ink(
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor ?? ReceiptUi.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? ReceiptUi.line(context),
          width: borderColor == null ? 1 : 1.6,
        ),
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

/// Badge Icon / Thumbnail đại diện cho ghe DT-2764 hoặc AG-26911
class BoatAvatarBadge extends StatelessWidget {
  const BoatAvatarBadge({
    super.key,
    required this.boatNumber,
    this.size = 48,
    this.useAssetImage = true,
  });

  final String boatNumber;
  final double size;
  final bool useAssetImage;

  bool get isAG => boatNumber.toUpperCase().contains('AG');

  @override
  Widget build(BuildContext context) {
    final isAgBoat = isAG;
    final assetPath = isAgBoat ? 'assets/logo.jpg' : 'assets/image.png';
    final primaryColor = isAgBoat ? const Color(0xFF047857) : const Color(0xFF4338CA);
    final gradientColors = isAgBoat
        ? [const Color(0xFF059669), const Color(0xFF047857)]
        : [const Color(0xFF6366F1), const Color(0xFF4338CA)];
    final iconData = isAgBoat ? Icons.sailing_rounded : Icons.directions_boat_filled_rounded;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: useAssetImage
            ? Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(
                    iconData,
                    color: Colors.white,
                    size: size * 0.55,
                  ),
                ),
              )
            : Center(
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: size * 0.55,
                ),
              ),
      ),
    );
  }
}

/// Thẻ hình ảnh đại diện cho ghe DT-2764 (image.png) hoặc AG-26911 (logo.jpg)
class BoatImagePlaceholder extends StatelessWidget {
  const BoatImagePlaceholder({
    super.key,
    required this.boatNumber,
    this.height = 150,
    this.onTap,
  });

  final String boatNumber;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isAG = boatNumber.toUpperCase().contains('AG');
    final assetPath = isAG ? 'assets/logo.jpg' : 'assets/image.png';
    final boatLabel = isAG ? 'AG-26911' : 'DT-2764';
    final iconData = isAG ? Icons.sailing_rounded : Icons.directions_boat_filled_rounded;
    final tagColor = isAG ? const Color(0xFF047857) : const Color(0xFF4338CA);

    final content = Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: tagColor.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: tagColor,
                child: Center(
                  child: Icon(iconData, size: 64, color: Colors.white38),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xDD000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: tagColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconData, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          boatNumber.isNotEmpty ? boatNumber : boatLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    const Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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

