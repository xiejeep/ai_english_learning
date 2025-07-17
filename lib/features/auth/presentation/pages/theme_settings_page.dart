import 'package:flutter/material.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/chat/presentation/widgets/message_bubble.dart';
import '../../../../shared/models/message_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_color_provider.dart';

class ThemeSettingsPage extends ConsumerStatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  ConsumerState<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends ConsumerState<ThemeSettingsPage> {
  double _bubbleOpacity = 0.7;
  Color _userBubbleColor = const Color(0xFF2F211C);
  Color _aiBubbleColor = const Color(0xFFE0E0E0);
  Color _userTextColor = Colors.white;
  Color _aiTextColor = Colors.black87;
  Color _themeColor = AppConstants.primaryColor;
  bool _pendingApply = false;

  final List<Color> _presetColors = [
    Colors.indigo,
    Colors.indigoAccent,
    Colors.grey,
    Colors.blueGrey,
    Colors.brown,
    Colors.black,
    Colors.white,
    Colors.deepOrange,
    Colors.orange,
    Colors.red,
    Colors.redAccent,
    Colors.blue,
    Colors.blueAccent
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = StorageService.getChatBubbleSettings();
    setState(() {
      _bubbleOpacity = (settings['opacity'] ?? 0.7).toDouble();
      _userBubbleColor = Color(settings['userBubbleColor'] ?? 0xFF2F211C);
      _aiBubbleColor = Color(settings['aiBubbleColor'] ?? 0xFFE0E0E0);
      _userTextColor = Color(settings['userTextColor'] ?? 0xFFFFFFFF);
      _aiTextColor = Color(settings['aiTextColor'] ?? 0xFF212121);
      _themeColor = Color(settings['themeColor'] ?? AppConstants.primaryColor.value);
    });
  }

  Future<void> _saveSettings() async {
    await StorageService.saveChatBubbleSettings({
      'opacity': _bubbleOpacity,
      'userBubbleColor': _userBubbleColor.value,
      'aiBubbleColor': _aiBubbleColor.value,
      'userTextColor': _userTextColor.value,
      'aiTextColor': _aiTextColor.value,
      'themeColor': _themeColor.value,
    });
  }

  Future<void> _applySettings() async {
    setState(() { _pendingApply = true; });
    await StorageService.saveChatBubbleSettings({
      'opacity': _bubbleOpacity,
      'userBubbleColor': _userBubbleColor.value,
      'aiBubbleColor': _aiBubbleColor.value,
      'userTextColor': _userTextColor.value,
      'aiTextColor': _aiTextColor.value,
      'themeColor': _themeColor.value,
    });
    // 通知全局主题色变更
    ref.read(themeColorProvider.notifier).update(_themeColor);
    setState(() { _pendingApply = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('主题和气泡样式已应用'), duration: Duration(seconds: 2)),
      );
    }
  }

  Widget _buildColorSelector(Color currentColor, ValueChanged<Color> onColorChanged) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _presetColors.map((color) {
          return GestureDetector(
            onTap: () {
              onColorChanged(color);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: color.value == currentColor.value ? Colors.blue : Colors.grey.shade400,
                  width: color.value == currentColor.value ? 2 : 1,
                ),
              ),
              child: color.value == currentColor.value
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主题与气泡样式设置'),
        backgroundColor: _themeColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 聊天气泡样式预览
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('气泡样式预览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  MessageBubble(
                    message: MessageModel(
                      id: 'preview_user',
                      content: '这是用户气泡预览',
                      type: MessageType.user,
                      timestamp: DateTime.now(),
                      status: MessageStatus.sent,
                    ),
                    userBubbleColor: _userBubbleColor,
                    aiBubbleColor: _aiBubbleColor,
                    userTextColor: _userTextColor,
                    aiTextColor: _aiTextColor,
                    bubbleOpacity: _bubbleOpacity,
                  ),
                  const SizedBox(height: 8),
                  MessageBubble(
                    message: MessageModel(
                      id: 'preview_ai',
                      content: '这是AI气泡预览',
                      type: MessageType.ai,
                      timestamp: DateTime.now(),
                      status: MessageStatus.sent,
                    ),
                    userBubbleColor: _userBubbleColor,
                    aiBubbleColor: _aiBubbleColor,
                    userTextColor: _userTextColor,
                    aiTextColor: _aiTextColor,
                    bubbleOpacity: _bubbleOpacity,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('主题色', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildColorSelector(_themeColor, (color) {
                    setState(() => _themeColor = color);
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('聊天气泡样式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('透明度'),
                      Expanded(
                        child: Slider(
                          value: _bubbleOpacity,
                          min: 0.2,
                          max: 1.0,
                          divisions: 8,
                          label: _bubbleOpacity.toStringAsFixed(2),
                          onChanged: (v) {
                            setState(() => _bubbleOpacity = v);
                            _saveSettings();
                          },
                        ),
                      ),
                      Text((_bubbleOpacity * 100).toInt().toString() + '%'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('用户气泡'),
                      const SizedBox(width: 8),
                      Expanded(child: _buildColorSelector(_userBubbleColor, (color) {
                        setState(() => _userBubbleColor = color);
                      })),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('用户文字'),
                      const SizedBox(width: 8),
                      Expanded(child: _buildColorSelector(_userTextColor, (color) {
                        setState(() => _userTextColor = color);
                      })),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('AI气泡'),
                      const SizedBox(width: 8),
                      Expanded(child: _buildColorSelector(_aiBubbleColor, (color) {
                        setState(() => _aiBubbleColor = color);
                      })),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('AI文字'),
                      const SizedBox(width: 8),
                      Expanded(child: _buildColorSelector(_aiTextColor, (color) {
                        setState(() => _aiTextColor = color);
                      })),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 应用按钮
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ElevatedButton.icon(
              icon: _pendingApply ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
              label: const Text('应用'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _pendingApply ? null : _applySettings,
            ),
          ),
        ],
      ),
    );
  }
} 