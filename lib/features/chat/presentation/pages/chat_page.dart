import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/conversation_drawer.dart';
import 'package:easy_refresh/easy_refresh.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeChat() async {
    try {
      print('🚀 [ChatPage] 开始初始化聊天...');
      
      final chatNotifier = ref.read(chatProvider.notifier);
      
      // 直接加载最新会话（使用limit=1优化）
      await chatNotifier.loadLatestConversation();
      
      // 检查是否成功加载了会话
      final chatState = ref.read(chatProvider);
      if (chatState.currentConversation == null) {
        // 如果没有找到会话，创建一个新会话
        print('📝 [ChatPage] 没有找到现有会话，创建新会话...');
        await chatNotifier.createNewConversation();
        print('✅ [ChatPage] 成功创建新会话');
      } else {
        print('✅ [ChatPage] 成功加载最新会话: ${chatState.currentConversation!.displayName}');
      }
    } catch (e) {
      print('❌ [ChatPage] 初始化聊天失败: $e');
      // 如果加载失败，回退到创建新会话
      final chatNotifier = ref.read(chatProvider.notifier);
      await chatNotifier.createNewConversation();
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Consumer(
        builder: (context, ref, child) {
          final chatState = ref.watch(chatProvider);
          final currentConversation = chatState.currentConversation;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentConversation != null)
                Text(
                  currentConversation.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );
        },
      ),
      backgroundColor: const Color(0xFF4A6FFF),
      foregroundColor: Colors.white,
      elevation: 0
    );
  }

  @override
  Widget build(BuildContext context) {
    // 监听认证状态变化，处理登录过期
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isUnauthenticated && next.errorMessage?.contains('登录已过期') == true) {
        // 显示登录过期提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('登录已过期，请重新登录'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // 跳转到登录页面
        context.go(AppConstants.loginRoute);
        print('✅ [ChatPage] 检测到登录过期，已跳转到登录页面');
      }
    });

    return Scaffold(
      appBar: _buildAppBar(),
      drawer: const ConversationDrawer(),
      body: Consumer(
        builder: (context, ref, child) {
          final chatState = ref.watch(chatProvider);

          // 加载中时显示全屏加载指示器
          if (chatState.status == ChatStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Column(
            children: [
              // 聊天消息列表
              Expanded(
                child: _buildMessagesList(chatState),
              ),
              // 消息输入框
              _buildMessageInput(chatState),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessagesList(ChatState state) {
    if (state.status == ChatStatus.loading && state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在加载对话...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (state.messages.isEmpty) {
      return _buildEmptyState();
    }

    return EasyRefresh(
      controller: EasyRefreshController(),
      header: const ClassicHeader(position: IndicatorPosition.locator),
      footer: const ClassicFooter(position: IndicatorPosition.locator),
      onLoad: (state.hasMoreMessages && !state.isLoadingMore)
          ? () async {
              await ref.read(chatProvider.notifier).loadMoreMessages();
            }
          : null,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true, // 最新消息在底部
        padding: const EdgeInsets.all(16),
        itemCount: state.messages.length,
        itemBuilder: (context, index) {
          final reversedIndex = state.messages.length - 1 - index;
          final msg = state.messages[reversedIndex];
          final isTemporary = msg.isAI &&
              (msg.content.contains('思考中') ||
                  msg.content.contains('输入') ||
                  state.isStreaming && msg == state.messages.last);
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: MessageBubble(
              message: msg,
              isTemporary: isTemporary,
              onPlayTTS: msg.isAI
                  ? () {
                      if (state.isTTSPlaying) {
                        ref.read(chatProvider.notifier).stopTTS();
                      } else {
                        ref.read(chatProvider.notifier).playTTS(msg.content);
                      }
                    }
                  : null,
              onCopy: () => _copyMessageToClipboard(msg.content),
              isTTSLoading: state.isTTSLoading,
              isCurrentlyPlaying: state.isTTSPlaying,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Consumer(
      builder: (context, ref, child) {
        final chatState = ref.watch(chatProvider);
        final currentConversation = chatState.currentConversation;
        final hasIntroduction = currentConversation?.introduction?.isNotEmpty == true;
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.psychology,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              if (hasIntroduction) ...[
                // 显示会话开场白
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A6FFF).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF4A6FFF).withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [


                      Text(
                        currentConversation!.introduction!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                // 默认欢迎信息
                Text(
                  '开始你的英语学习之旅',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '输入任何你想练习的英语内容\nAI助手会帮你纠错、翻译和提供学习建议',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
              ],
              _buildSuggestedPrompts(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestedPrompts() {
    final prompts = [
      '那年18,母校舞会,站着如喽啰',
      'I  have been 练习 for two years and a half',
      'I like sing,jump,and playing basketball',
    ];

    return Column(
      children: [
        Text(
          '试试这些话题：',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: prompts.map((prompt) {
            return ActionChip(
              label: Text(prompt),
              onPressed: () {
                _messageController.text = prompt;
                _sendMessage();
              },
              backgroundColor: const Color(0xFF4A6FFF).withValues(alpha: 0.1),
              labelStyle: const TextStyle(
                color: Color(0xFF4A6FFF),
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMessageInput(ChatState state) {
    return MessageInput(
      controller: _messageController,
      isLoading: state.status == ChatStatus.loading || 
                 state.status == ChatStatus.sending || 
                 state.status == ChatStatus.thinking,
      isStreaming: state.isStreaming,
      onSend: _sendMessage,
      onStop: () => ref.read(chatProvider.notifier).stopGeneration(),
      hintText: state.currentConversation == null 
        ? '创建会话中...' 
        : '输入你想练习的英语内容...',
      autofocus: false,
    );
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    // 发送消息
    ref.read(chatProvider.notifier).sendMessageStream(content);
    
    // 清空输入框
    _messageController.clear();
  }

  // 复制消息到剪贴板
  void _copyMessageToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('消息已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}