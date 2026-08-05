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

  static Color ink(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFF5F0FF)
      : ReceiptColors.ink;

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
      hintStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF807A94)
            : const Color(0xFF94A3B8),
        fontSize: 17,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
      ),
      suffixText: suffix,
      prefixIcon: icon == null ? null : Icon(icon, color: ReceiptColors.blue, size: 26),
      filled: true,
      fillColor: surface(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
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

  static void showTopSuccessAlert(
    BuildContext context, {
    required String title,
    String? subtitle,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final topMargin = mediaQuery.padding.top + 12;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: topMargin,
          left: 16,
          right: 16,
          bottom: mediaQuery.size.height - topMargin - 95,
        ),
        backgroundColor: const Color(0xFF047857),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF34D399), width: 1.5),
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF065F46),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF34D399),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFA7F3D0),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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

/// Thẻ hiển thị Hóa đơn / Phiếu cân trấu dạng Giấy chứng từ chuyên nghiệp (thay cho ảnh ghe)
class ReceiptDocumentCard extends StatelessWidget {
  const ReceiptDocumentCard({
    super.key,
    required this.boatNumber,
    this.date,
    this.weightKg,
    this.pricePerKg,
    this.height = 180,
    this.onTap,
  });

  final String boatNumber;
  final String? date;
  final int? weightKg;
  final int? pricePerKg;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isAg = boatNumber.toUpperCase().contains('AG');
    final tagColor = isAg ? const Color(0xFF047857) : const Color(0xFF4338CA);
    final displayBoat = boatNumber.isNotEmpty
        ? boatNumber
        : (isAg ? 'AG-26911' : 'DT-2764');
    final displayWeight = weightKg != null && weightKg! > 0
        ? '${(weightKg! / 1000).toStringAsFixed(3).replaceAll('.', ',')} tấn'
        : '80,956 tấn';

    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : const Color(0xFFFEFDF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: tagColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HÓA ĐƠN / PHIẾU CÂN TRẤU',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ReceiptUi.ink(context),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chứng từ nhập trấu - Cân Chị Mười',
                      style: TextStyle(
                        fontSize: 13,
                        color: ReceiptUi.secondaryText(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: ReceiptUi.line(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Số ghe:',
                      style: TextStyle(
                        fontSize: 14,
                        color: ReceiptUi.secondaryText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayBoat,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: tagColor,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Khối lượng trấu:',
                      style: TextStyle(
                        fontSize: 14,
                        color: ReceiptUi.secondaryText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayWeight,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  color: Color(0xFF0284C7),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Phiếu cân viết tay / Hóa đơn đã xác nhận',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                ),
                if (onTap != null)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_full_rounded,
                        color: Color(0xFF0284C7),
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Xem full',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
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
    return ReceiptDocumentCard(
      boatNumber: boatNumber,
      height: height,
      onTap: onTap,
    );
  }
}

