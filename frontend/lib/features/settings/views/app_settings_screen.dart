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

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final sectionHeaderColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('CÀI ĐẶT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shared Section: Theme
              _buildSectionHeader('GIAO DIỆN', sectionHeaderColor),
              const SizedBox(height: 10),
              Material(
                color: cardBgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: cardBorderColor),
                ),
                child: SwitchListTile(
                  value: isDark,
                  activeThumbColor: const Color(0xFF38BDF8),
                  activeTrackColor: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                  title: Text('Chế độ tối', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: textColor)),
                  secondary: const Icon(Icons.dark_mode_rounded, color: Color(0xFFFDE047), size: 28),
                  onChanged: (val) {
                    widget.onThemeChanged(val ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Contextual Settings
              if (widget.currentModule == 'main') ...[
                _buildSectionHeader('TÀI KHOẢN', sectionHeaderColor),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Tên người dùng', user?.displayName ?? 'Mẹ', subtextColor, textColor),
                      Divider(color: cardBorderColor, height: 20),
                      _buildInfoRow('Tên đăng nhập', user?.username ?? 'admin', subtextColor, textColor),
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
                                  backgroundColor: cardBgColor,
                                  title: Text('Đăng xuất', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                                  content: Text('Bạn có muốn đăng xuất không?', style: TextStyle(fontSize: 18, color: subtextColor)),
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
                _buildSectionHeader('TÙY CHỈNH SỔ GHE', sectionHeaderColor),
                const SizedBox(height: 10),
                Material(
                  color: cardBgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: cardBorderColor),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _enableOcrAutoFill,
                        activeThumbColor: const Color(0xFF38BDF8),
                        activeTrackColor: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        title: Text('Đọc chữ từ ảnh tự động', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        secondary: const Icon(Icons.document_scanner_rounded, color: Color(0xFF38BDF8), size: 28),
                        onChanged: (val) => setState(() => _enableOcrAutoFill = val),
                      ),
                      Divider(color: cardBorderColor, height: 1),
                      ListTile(
                        leading: const Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981), size: 28),
                        title: Text('Lưu trữ hình ảnh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        trailing: const Text('Tự động', style: TextStyle(fontSize: 16, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ] else if (widget.currentModule == 'games') ...[
                _buildSectionHeader('TÙY CHỈNH TRÒ CHƠI', sectionHeaderColor),
                const SizedBox(height: 10),
                Material(
                  color: cardBgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: cardBorderColor),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _enableSoundEffects,
                        activeThumbColor: const Color(0xFF2DD4BF),
                        activeTrackColor: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                        title: Text('Âm thanh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        secondary: const Icon(Icons.volume_up_rounded, color: Color(0xFF2DD4BF), size: 28),
                        onChanged: (val) => setState(() => _enableSoundEffects = val),
                      ),
                      Divider(color: cardBorderColor, height: 1),
                      SwitchListTile(
                        value: _enableVibration,
                        activeThumbColor: const Color(0xFF2DD4BF),
                        activeTrackColor: const Color(0xFF2DD4BF).withValues(alpha: 0.4),
                        title: Text('Rung phản hồi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        secondary: const Icon(Icons.vibration_rounded, color: Color(0xFF2DD4BF), size: 28),
                        onChanged: (val) => setState(() => _enableVibration = val),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // System Info
              _buildSectionHeader('THÔNG TIN THIẾT BỊ', sectionHeaderColor),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Ứng dụng', 'Chị Mười - Phiên bản 1.0', subtextColor, textColor),
                    Divider(color: cardBorderColor, height: 20),
                    _buildInfoRow('Máy chủ', 'Máy chủ nội bộ', subtextColor, textColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color subtextColor, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 17, color: subtextColor)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
          ),
        ),
      ],
    );
  }
}
