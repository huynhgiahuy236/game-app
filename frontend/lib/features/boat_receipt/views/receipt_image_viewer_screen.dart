import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ReceiptImageViewerScreen extends StatelessWidget {
  final String? imageUrl;
  final File? localFile;
  final String? assetPath;

  const ReceiptImageViewerScreen({
    super.key,
    this.imageUrl,
    this.localFile,
    this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (localFile != null) {
      if (kIsWeb) {
        imageWidget = const Center(
          child: Text(
            'Web preview không hỗ trợ file cục bộ',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        );
      } else {
        imageWidget = Image.file(localFile!, fit: BoxFit.contain);
      }
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text(
            'Không thể tải hình ảnh',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    } else if (assetPath != null && assetPath!.isNotEmpty) {
      imageWidget = Image.asset(
        assetPath!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text(
            'Không thể tải hình ảnh',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    } else {
      imageWidget = const Center(
        child: Text(
          'Không có hình ảnh',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          tooltip: 'Trở về',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ẢNH PHIẾU GỐC',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.close_rounded, size: 22),
              label: const Text(
                'ĐÓNG',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(child: imageWidget),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xDD0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: Colors.white30, width: 1.5),
                  ),
                ),
                icon: const Icon(Icons.close_rounded, size: 24),
                label: const Text(
                  'Đóng xem ảnh',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
