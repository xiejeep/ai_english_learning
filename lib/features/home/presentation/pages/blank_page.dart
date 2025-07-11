import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/providers/chat_state.dart';
import '../widgets/simple_message_bubble.dart';
import '../../../chat/presentation/widgets/message_input.dart';
import '../../../chat/presentation/widgets/conversation_drawer.dart';
import 'package:easy_refresh/easy_refresh.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../../../shared/models/message_model.dart';

class BlankPage extends ConsumerStatefulWidget {
  final String? type;
  final String? appId;
  final String? appName;
  
  const BlankPage({super.key, this.type, this.appId, this.appName});

  @override
  ConsumerState<BlankPage> createState() => _BlankPageState();
}

class _BlankPageState extends ConsumerState<BlankPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
      FocusScope.of(context).unfocus();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeChat() async {
    if (widget.appId != null || widget.appName != null) {
      ref.read(chatProvider.notifier).setAppInfo(widget.appId, widget.appName);
    }
    await ref.read(chatProvider.notifier).initializeChat();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          context.pop();
        },
      ),
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
                    color: Colors.white.withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );
        },
      ),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: '会话列表',
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.person_outline),
          tooltip: '个人中心',
          onPressed: () {
            context.push(AppConstants.profileRoute);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isUnauthenticated && next.errorMessage?.contains('登录已过期') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('登录已过期，请重新登录'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        
        context.go(AppConstants.loginRoute);
      }
    });

    return Scaffold(
      appBar: _buildAppBar(),
      drawer: const ConversationDrawer(),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Consumer(
          builder: (context, ref, child) {
            final chatState = ref.watch(chatProvider);

            if (chatState.status == ChatStatus.loading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (chatState.status == ChatStatus.error) {
              return _buildErrorWidget(chatState.error ?? '未知错误');
            }

            return Column(
              children: [
                Expanded(
                  child: _buildMessagesList(chatState),
                ),
                _buildMessageInput(chatState),
              ],
            );
          },
        ),
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
      footer: const CupertinoFooter(position: IndicatorPosition.locator),
      onLoad: (state.hasMoreMessages && !state.isLoadingMore)
          ? () async {
              await ref.read(chatProvider.notifier).loadMoreMessages();
            }
          : null,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 8,vertical: 10),
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
            child: SimpleMessageBubble(
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
              onRetry: msg.status == MessageStatus.failed ? () => ref.read(chatProvider.notifier).retryMessage(msg.id) : null,
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
              if (hasIntroduction) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
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
                  '输入任何你想练习的内容\nAI助手会帮你纠错、翻译和提供学习建议,可以是中文、英文,也可以中英混杂',
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
      'I like sing,jump,and play basketball',
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
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              labelStyle:  TextStyle(
                color: Theme.of(context).primaryColor,
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
        : '输入你想练习的内容...',
      autofocus: false,
      enableInteractiveSelection: true,
    );
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    FocusScope.of(context).unfocus();

    if (widget.type != null) {
      ref.read(chatProvider.notifier).sendMessageStreamWithType(content, widget.type!);
    } else {
      ref.read(chatProvider.notifier).sendMessageStream(content);
    }
    
    _messageController.clear();
  }

  void _copyMessageToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('消息已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              error,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializeChat,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}