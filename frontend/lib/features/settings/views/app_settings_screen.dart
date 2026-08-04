import 'package:flutter/material.dart';
import '../../auth/services/auth_repository.dart';

class AppSettingsScreen extends StatefulWidget {
  final String currentModule; // 'main' | 'boat_receipts' | 'games'
  final Function(ThemeMode) onThemeChanged;
  final AuthRepository? authRepository;

  const AppSettingsScreen({
    super.key,
    required this.currentModule,
    required this.onThemeChanged,
    this.authRepository,
  });

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _enableOcrAutoFill = true;
  bool _enableSoundEffects = true;
  bool _enableVibration = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = widget.authRepository?.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('CÀI ĐẶT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shared Section: Theme
              _buildSectionHeader('GIAO DIỆN'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: SwitchListTile(
                  value: isDark,
                  activeThumbColor: const Color(0xFF38BDF8),
                  activeTrackColor: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                  title: const Text('Chế độ tối', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                  secondary: const Icon(Icons.dark_mode_rounded, color: Color(0xFFFDE047), size: 28),
                  onChanged: (val) {
                    widget.onThemeChanged(val ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Contextual Settings
              if (widget.currentModule == 'main') ...[
                _buildSectionHeader('TÀI KHOẢN'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Tên người dùng', user?.displayName ?? 'Mẹ'),
                      const Divider(color: Color(0xFF334155), height: 20),
                      _buildInfoRow('Tên đăng nhập', user?.username ?? 'admin'),
                      if (widget.authRepository != null) ...[
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  title: const Text('Đăng xuất', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                  content: const Text('Bạn có muốn đăng xuất không?', style: TextStyle(fontSize: 18, color: Color(0xFFCBD5E1))),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy', style: TextStyle(fontSize: 18, color: Colors.grey))),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                      child: const Text('Đăng xuất', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await widget.authRepository!.logout();
                              }
                            },
                            icon: const Icon(Icons.logout_rounded, size: 24),
                            label: const Text('ĐĂNG XUẤT', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else if (widget.currentModule == 'boat_receipts') ...[
                _buildSectionHeader('TÙY CHỈNH SỔ GHE'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _enableOcrAutoFill,
                        activeThumbColor: const Color(0xFF38BDF8),
                        activeTrackColor: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        title: const Text('Đọc chữ từ ảnh tự động', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        secondary: const Icon(Icons.document_scanner_rounded, color: Color(0xFF38BDF8), size: 28),
                        onChanged: (val) => setState(() => _enableOcrAutoFill = val),
                      ),
                      const Divider(color: Color(0xFF334155), height: 1),
                      ListTile(
                        leading: const Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981), size: 28),
                        title: const Text('Lưu trữ hình ảnh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        trailing: const Text('Tự động', style: TextStyle(fontSize: 16, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ] else if (widget.currentModule == 'games') ...[
                _buildSectionHeader('TÙY CHỈNH TRÒ CHƠI'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _enableSoundEffects,
                        activeThumbColor: const Color(0xFF2DD4BF),
                        activeTrackColor: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                        title: const Text('Âm thanh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        secondary: const Icon(Icons.volume_up_rounded, color: Color(0xFF2DD4BF), size: 28),
                        onChanged: (val) => setState(() => _enableSoundEffects = val),
                      ),
                      const Divider(color: Color(0xFF334155), height: 1),
                      SwitchListTile(
                        value: _enableVibration,
                        activeThumbColor: const Color(0xFF2DD4BF),
                        activeTrackColor: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                        title: const Text('Rung phản hồi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        secondary: const Icon(Icons.vibration_rounded, color: Color(0xFF2DD4BF), size: 28),
                        onChanged: (val) => setState(() => _enableVibration = val),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // System Info
              _buildSectionHeader('THÔNG TIN THIẾT BỊ'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Ứng dụng', 'Chị Mười - Phiên bản 1.0'),
                    const Divider(color: Color(0xFF334155), height: 20),
                    _buildInfoRow('Máy chủ', 'Máy chủ nội bộ'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF38BDF8),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 18, color: Color(0xFF94A3B8))),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
