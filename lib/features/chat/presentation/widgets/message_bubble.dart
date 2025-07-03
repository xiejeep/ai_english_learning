import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/message_model.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_tts/flutter_tts.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onPlayTTS;
  final VoidCallback? onCopy;
  final bool isTTSLoading;
  final bool isCurrentlyPlaying;
  final bool isTemporary;

  // 离线TTS实例（静态，避免重复初始化）
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _ttsInitialized = false;

  // 离线TTS朗读
  static Future<void> speak(String text) async {
    if (!_ttsInitialized) {
      await _flutterTts.awaitSpeakCompletion(true);
      _ttsInitialized = true;
    }
    await _flutterTts.stop(); // 保证状态干净
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    var isAvailable = await _flutterTts.isLanguageAvailable('en-US');
    if (isAvailable == true) {
      await _flutterTts.speak(text);
    }
  }

  // 弹出菜单并处理操作（改为BottomSheet方式）
  static void showWordMenu(BuildContext context, String word) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.volume_up),
                title: const Text('朗读'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await speak(word);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('复制'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Clipboard.setData(ClipboardData(text: word));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已复制: $word'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 富文本处理：将英文单词/短语整体分为可点击span
  static List<InlineSpan> parseRichContent(String content, BuildContext context, void Function(BuildContext, String) onTap) {
    final List<InlineSpan> spans = [];
    final RegExp reg = RegExp(r"([a-zA-Z][a-zA-Z'-]* ?)+|[^a-zA-Z]+", multiLine: true);
    final matches = reg.allMatches(content);
    for (final m in matches) {
      final text = m.group(0)!;
      if (RegExp(r'^[a-zA-Z]').hasMatch(text.trim())) {
        spans.add(TextSpan(
          text: text,
          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () => onTap(context, text.trim()),
        ));
      } else {
        spans.add(TextSpan(text: text));
      }
    }
    return spans;
  }

  const MessageBubble({
    Key? key,
    required this.message,
    this.onPlayTTS,
    this.onCopy,
    this.isTTSLoading = false,
    this.isCurrentlyPlaying = false,
    this.isTemporary = false,
  }) : super(key: key);

  // TTS按钮图标逻辑
  IconData _getTTSButtonIcon() {
    if (isTTSLoading) {
      return Icons.hourglass_empty;
    }
    
    // 如果正在播放TTS，显示停止图标
    if (isCurrentlyPlaying) {
      return Icons.stop;
    }
    
    return Icons.volume_up;
  }
  
  // TTS按钮颜色逻辑
  Color? _getTTSButtonColor() {
    // 加载中时显示灰色
    if (isTTSLoading) {
      return Colors.grey.shade400;
    }
    return null; // 使用默认颜色
  }
  
  // TTS按钮是否可用
  bool _isTTSButtonEnabled() {
    // 加载中时禁用
    return !isTTSLoading;
  }
  
  // TTS按钮提示文本
  String _getTTSButtonTooltip() {
    if (isTTSLoading) {
      return '正在加载...';
    }
    
    if (isCurrentlyPlaying) {
      return '停止播放';
    }
    
    return '播放语音';
  }

  // 构建临时消息的内容（带动画效果）
  Widget _buildTemporaryMessageContent(String text, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 16),
          ),
        ),
        if (text.contains('思考中') || text.contains('输入')) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor.withOpacity(0.7)),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.type == MessageType.user;
    final bubbleColor = isMe ? const Color(0xFF4A6FFF) : Colors.grey.shade200;
    final textColor = isMe ? Colors.white : Colors.black87;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: isMe ? const Color(0xFF4A6FFF) : Colors.grey.shade400,
      child: isMe
          ? const Icon(Icons.person, color: Colors.white, size: 18)
          : const Icon(Icons.smart_toy, color: Colors.white, size: 18),
    );

    return Column(
      crossAxisAlignment: align,
      children: [
        isMe
            ? GestureDetector(
                onTap: () {
                  context.push(AppConstants.profileRoute);
                },
                child: avatar,
              )
            : avatar,
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                  minWidth: 36,
                ),
                child: IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: EdgeInsets.only(
                      left: isMe ? 0 : 16,
                      right: isMe ? 16 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isTemporary)
                          _buildTemporaryMessageContent(message.content, textColor)
                        else
                          // 用户消息用普通文本，AI消息用富文本
                          isMe
                              ? Text(
                                  message.content,
                                  style: TextStyle(color: textColor, fontSize: 16),
                                )
                              : (
                                  message.richContent != null
                                      ? Builder(
                                          builder: (context) => RichText(
                                            text: TextSpan(
                                              children: message.richContent!.map((span) {
                                                if (span is TextSpan && span.recognizer != null) {
                                                  // 重新包装recognizer，点击弹出菜单
                                                  return TextSpan(
                                                    text: span.text,
                                                    style: span.style,
                                                    recognizer: TapGestureRecognizer()
                                                      ..onTap = () {
                                                        showWordMenu(context, span.text ?? '');
                                                      },
                                                  );
                                                }
                                                return span;
                                              }).toList(),
                                              style: TextStyle(color: textColor, fontSize: 16),
                                            ),
                                          ),
                                        )
                                      : Builder(
                                          builder: (context) => RichText(
                                            text: TextSpan(
                                              children: MessageBubble.parseRichContent(
                                                message.content,
                                                context,
                                                showWordMenu,
                                              ),
                                              style: TextStyle(color: textColor, fontSize: 16),
                                            ),
                                          ),
                                        )
                                ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (onPlayTTS != null || onCopy != null)
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (onPlayTTS != null)
                IconButton(
                  icon: Icon(
                    _getTTSButtonIcon(),
                    size: 18,
                    color: _getTTSButtonColor(),
                  ),
                  onPressed: _isTTSButtonEnabled() ? () {
                    print('🎯 TTS按钮点击');
                    print('📊 当前状态: isTTSLoading=$isTTSLoading, isCurrentlyPlaying=$isCurrentlyPlaying');
                    onPlayTTS!();
                  } : null,
                  tooltip: _getTTSButtonTooltip(),
                ),
              if (onCopy != null)
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: onCopy,
                ),
            ],
          ),
      ],
    );
  }
}