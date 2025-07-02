import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/thinking_indicator.dart';
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
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    // 延迟执行，确保provider已经初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pageController?.dispose();
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

  // void _scrollToBottom() {
  //   if (_scrollController.hasClients) {
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       _scrollController.animateTo(
  //         _scrollController.position.maxScrollExtent,
  //         duration: const Duration(milliseconds: 300),
  //         curve: Curves.easeOut,
  //       );
  //     });
  //   }
  // }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Consumer(
        builder: (context, ref, child) {
          final chatState = ref.watch(chatProvider);
          final currentConversation = chatState.currentConversation;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI英语对话',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (currentConversation != null)
                Text(
                  currentConversation.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
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
          
          // 监听消息变化，自动滚动到底部
          ref.listen<ChatState>(chatProvider, (previous, next) {
            if (previous?.messages.length != next.messages.length ||
                previous?.streamingMessage != next.streamingMessage) {
              // _scrollToBottom();
            }
          });

          return Column(
            children: [
              // 会话切换指示器
              if (chatState.status == ChatStatus.loading && chatState.currentConversation != null)
                _buildConversationSwitchIndicator(),
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

    if (state.conversationPages.isEmpty && state.currentConversation != null) {
      return _buildEmptyState();
    }

    if (state.conversationPages.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        // PageView显示对话页面
        PageView.builder(
          reverse: true,
          controller: _pageController ??= PageController(initialPage: state.currentPageIndex),
          onPageChanged: (pageIndex) {
            ref.read(chatProvider.notifier).onPageChanged(pageIndex);
            
            // 如果滑动到最后一页且还有更多消息，自动加载下一页
            if (pageIndex == state.conversationPages.length - 1 && 
                ref.read(chatProvider.notifier).canLoadMorePages) {
              ref.read(chatProvider.notifier).loadMoreMessages();
            }
          },
          itemCount: state.conversationPages.length,
          itemBuilder: (context, pageIndex) {
            final pageMessages = state.conversationPages[pageIndex];
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 页面指示器
                  if (state.conversationPages.length > 1)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: Text(
                          '第 ${pageIndex + 1} 页',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  // 消息列表
                  ...pageMessages.map((msg) {
                    return MessageBubble(
                      message: msg,
                      onPlayTTS: msg.isAI ? () {
                        if (state.isTTSPlaying) {
                          // 如果正在播放，则停止播放
                          ref.read(chatProvider.notifier).stopTTS();
                        } else {
                          // 否则播放当前消息
                          ref.read(chatProvider.notifier).playTTS(msg.content);
                        }
                      } : null,
                      onCopy: () => _copyMessageToClipboard(msg.content),
                      isTTSLoading: state.isTTSLoading,
                      isCurrentlyPlaying: state.isTTSPlaying,
                    );
                  }).toList(),
                ],
              ),
            );
          },
        ),
        // 左侧上一页按钮（加载历史消息）
        if (state.hasMoreMessages)
          Positioned(
            left: 4,
            top: MediaQuery.of(context).size.height * 0.3,
            child: _buildNavigationButton(
              icon: Icons.keyboard_arrow_left,
              onPressed: state.isLoadingMore ? null : () async {
                final currentPageCount = state.conversationPages.length;
                await ref.read(chatProvider.notifier).loadMoreMessages();
                
                // 加载完成后，检查是否有新页面被添加
                final newPageCount = ref.read(chatProvider).conversationPages.length;
                if (newPageCount > currentPageCount && _pageController != null) {
                  // 跳转到最后一页（新加载的页面）
                  _pageController!.animateToPage(
                    newPageCount - 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              tooltip: '加载历史消息',
              isLoading: state.isLoadingMore,
            ),
          ),
        // 右侧下一页按钮（返回较新的页面）
        if (state.conversationPages.length > 1 && state.currentPageIndex > 0)
          Positioned(
            right: 4,
            top: MediaQuery.of(context).size.height * 0.3,
            child: _buildNavigationButton(
              icon: Icons.keyboard_arrow_right,
              onPressed: () {
                if (_pageController != null && state.currentPageIndex > 0) {
                  _pageController!.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              tooltip: '返回较新的消息',
              isLoading: false,
            ),
          ),
      ],
    );
  }

  // 构建导航按钮
  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    required bool isLoading,
  }) {
    return Container(
      width: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: onPressed != null 
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
            
              ),
              child: Center(
                child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          onPressed != null ? Colors.blue : Colors.grey,
                        ),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 20,
                      color: onPressed != null ? Colors.blue : Colors.grey,
                    ),
              ),
            ),
          ),
        ),
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
                    color: const Color(0xFF4A6FFF).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF4A6FFF).withOpacity(0.2),
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

  Widget _buildConversationSwitchIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4A6FFF).withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF4A6FFF).withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF4A6FFF),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '正在切换对话...',
            style: TextStyle(
              color: const Color(0xFF4A6FFF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
              backgroundColor: const Color(0xFF4A6FFF).withOpacity(0.1),
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