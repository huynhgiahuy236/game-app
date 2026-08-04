import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ReceiptImageViewerScreen extends StatelessWidget {
  final String? imageUrl;
  final File? localFile;

  const ReceiptImageViewerScreen({
    super.key,
    this.imageUrl,
    this.localFile,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (localFile != null) {
      if (kIsWeb) {
        imageWidget = const Center(
          child: Text('Web preview không hỗ trợ file cục bộ', style: TextStyle(color: Colors.white, fontSize: 18)),
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
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        },
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text('Không thể tải hình ảnh', style: TextStyle(color: Colors.white, fontSize: 18)),
        ),
      );
    } else {
      imageWidget = const Center(
        child: Text('Không có hình ảnh', style: TextStyle(color: Colors.white, fontSize: 20)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('XEM ẢNH PHIẾU', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(child: imageWidget),
      ),
    );
  }
}
