import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_state.dart';
import '../providers/conversation_list_provider.dart';
import '../../domain/entities/conversation.dart';
import '../../../../core/constants/app_constants.dart';

class ConversationDrawer extends ConsumerStatefulWidget {
  const ConversationDrawer({super.key});

  @override
  ConsumerState<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends ConsumerState<ConversationDrawer> {
  @override
  void initState() {
    super.initState();
    // 加载会话列表，独立于聊天状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final conversationListState = ref.read(conversationListProvider);
      if (conversationListState.conversations.isEmpty) {
        ref.read(conversationListProvider.notifier).loadConversations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(),
          _buildNewConversationTile(),
          const Divider(),
          Expanded(
            child: _buildConversationsList(),
          ),
          const Divider(),
          _buildDrawerFooter(),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A6FFF),
            Color(0xFF7B93FF),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        
          Row(
            children: [
              Text(
                '管理你的对话记录',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Consumer(
            builder: (context, ref, child) {
              final conversationListState = ref.watch(conversationListProvider);
              final conversationCount = conversationListState.conversations.length;
              
              return Text(
                '共 $conversationCount 个对话',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNewConversationTile() {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF4A6FFF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.add,
          color: Color(0xFF4A6FFF),
        ),
      ),
      title: const Text(
        '新建对话',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF4A6FFF),
        ),
      ),
      subtitle: const Text('开始新的英语学习对话'),
      onTap: () {
        Navigator.pop(context); // 关闭抽屉
        // 直接创建新会话，不显示主题选择弹窗
        ref.read(chatProvider.notifier).createNewConversation();
      },
    );
  }

  Widget _buildConversationsList() {
    return Consumer(
      builder: (context, ref, child) {
        final conversationListState = ref.watch(conversationListProvider);
        final chatState = ref.watch(chatProvider);
        
        // 加载中状态
        if (conversationListState.isLoading && conversationListState.conversations.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // 错误状态
        if (conversationListState.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    conversationListState.error!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(conversationListProvider.notifier).loadConversations();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 空状态
        if (conversationListState.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  '还没有对话记录',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击上方按钮开始新对话',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        // 只展示最新10个会话，按updatedAt倒序
        final sortedConversations = [...conversationListState.conversations]
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final latestConversations = sortedConversations.take(10).toList();

        return ListView.builder(
          itemCount: latestConversations.length,
          itemBuilder: (context, index) {
            final conversation = latestConversations[index];
            final isSelected = chatState.currentConversation?.id == conversation.id;
            
            return _buildConversationTile(conversation, isSelected);
          },
        );
      },
    );
  }

  Widget _buildConversationTile(Conversation conversation, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF4A6FFF).withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF4A6FFF) 
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.chat_rounded,
            color: isSelected ? Colors.white : Colors.grey.shade600,
            size: 20,
          ),
        ),
        title: Text(
          conversation.displayName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? const Color(0xFF4A6FFF) : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conversation.lastMessage != null)
              Text(
                conversation.lastMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              _formatDate(conversation.updatedAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: Colors.grey.shade600,
            size: 20,
          ),
          onSelected: (value) {
            switch (value) {
              case 'rename':
                _showRenameDialog(conversation);
                break;
              case 'delete':
                _showDeleteDialog(conversation);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('重命名'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('删除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () async {
          Navigator.pop(context); // 关闭抽屉
          await ref.read(chatProvider.notifier).switchToConversation(conversation);
        },
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Consumer(
      builder: (context, ref, child) {
        final chatState = ref.watch(chatProvider);
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  chatState.autoPlayTTS ? Icons.volume_up : Icons.volume_off,
                  color: const Color(0xFF4A6FFF),
                ),
                title: Text(
                  chatState.autoPlayTTS ? '自动朗读：开启' : '自动朗读：关闭',
                  style: const TextStyle(fontSize: 14),
                ),
                onTap: () {
                  ref.read(chatProvider.notifier).toggleTTSAutoPlay();
                },
              ),
              const SizedBox(height: 8),
              Text(
                '趣TALK伙伴 v${AppConstants.appVersion}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}周前';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  void _showRenameDialog(Conversation conversation) {
    final controller = TextEditingController(text: conversation.displayName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入新的对话名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != conversation.displayName) {
                ref.read(conversationListProvider.notifier).updateConversationName(
                  conversation.id,
                  newName,
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

  void _showDeleteDialog(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除对话「${conversation.displayName}」吗？\n\n此操作不可撤销，会永久删除该对话的所有消息记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 从会话列表中删除
              ref.read(conversationListProvider.notifier).deleteConversation(conversation.id);
              Navigator.pop(context);
              
              // 如果删除的是当前对话，创建新对话
              final currentState = ref.read(chatProvider);
              if (currentState.currentConversation?.id == conversation.id) {
                ref.read(chatProvider.notifier).createNewConversation();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
} 