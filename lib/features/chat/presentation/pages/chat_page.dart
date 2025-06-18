import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/thinking_indicator.dart';
import '../../../../core/constants/app_constants.dart';

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
    // 延迟执行，确保provider已经初始化
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

  void _initializeChat() {
    final chatNotifier = ref.read(chatProvider.notifier);
    final state = ref.read(chatProvider);
    
    // 如果没有当前会话，创建一个新会话
    if (state.currentConversation == null) {
      chatNotifier.createNewConversation();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
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
      elevation: 0,
      actions: [
        IconButton(
          onPressed: () => _showChatOptions(context),
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
              _scrollToBottom();
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

    if (state.messages.isEmpty && state.currentConversation != null) {
      return _buildEmptyState();
    }

    // 计算列表项目数量，如果正在思考则+1
    final itemCount = state.messages.length + (state.status == ChatStatus.thinking ? 1 : 0);
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // 如果是最后一项且正在思考，显示思考指示器
        if (index == state.messages.length && state.status == ChatStatus.thinking) {
          return const ThinkingIndicator();
        }
        
        final message = state.messages[index];
        
        return MessageBubble(
          message: message,
          onPlayTTS: message.isAI 
            ? () => ref.read(chatProvider.notifier).playTTS(message.content)
            : null,
          onDelete: () => ref.read(chatProvider.notifier).deleteMessage(message.id),
        );
      },
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

  void _showChatOptions(BuildContext context) {
    final chatState = ref.read(chatProvider);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('新建对话'),
              onTap: () {
                Navigator.pop(context);
                ref.read(chatProvider.notifier).createNewConversation();
              },
            ),
            ListTile(
              leading: Icon(
                chatState.autoPlayTTS ? Icons.volume_up : Icons.volume_off,
              ),
              title: Text(
                chatState.autoPlayTTS ? '关闭自动朗读' : '开启自动朗读',
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(chatProvider.notifier).toggleTTSAutoPlay();
              },
            ),
            if (chatState.currentConversation != null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('重命名对话'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog();
                },
              ),
            if (chatState.currentConversation != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除对话', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final currentConversation = ref.read(chatProvider).currentConversation;
    if (currentConversation == null) return;

    final controller = TextEditingController(text: currentConversation.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入新的对话名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                ref.read(chatProvider.notifier).updateConversationTitle(
                  currentConversation.id,
                  newTitle,
                );
              }
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    final currentConversation = ref.read(chatProvider).currentConversation;
    if (currentConversation == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: const Text('确定要删除这个对话吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatProvider.notifier).deleteConversation(currentConversation.id);
              Navigator.pop(context);
              // 返回主页
              Navigator.pushReplacementNamed(context, AppConstants.homeRoute);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
} 