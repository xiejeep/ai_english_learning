import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_state.dart';
import '../providers/conversation_list_provider.dart';
import '../../domain/entities/conversation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/credits_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

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
      // 只在抽屉首次打开时刷新token余额
      ref.invalidate(tokenBalanceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(),
          _buildNewConversationTile(),

          Expanded(
            child: _buildConversationsList(),
          ),

          _buildDrawerFooter(),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    final headerHeight = isLandscape ? 126.0 : 160.0;
    final titleFontSize = isLandscape ? 14.0 : 16.0;
    final countFontSize = isLandscape ? 10.0 : 12.0;
    final verticalPadding = isLandscape ? 8.0 : 20.0;

    return SizedBox(
      height: headerHeight,
      child: DrawerHeader(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: verticalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 第一行：标题和按钮
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '会话记录',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: titleFontSize,
                      ),
                    ),
                  ),
                  // 新建会话按钮
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                    tooltip: '新建会话',
                    onPressed: () async {
                      await ref.read(chatProvider.notifier).createNewConversation();
                      if (context.mounted) {
                        Navigator.pop(context); // 关闭抽屉
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已新建对话')),
                        );
                      }
                    },
                  ),
                  // 自动朗读按钮
                  Consumer(
                    builder: (context, ref, child) {
                      final autoPlayTTS = ref.watch(chatProvider).autoPlayTTS;
                      return IconButton(
                        icon: Icon(
                          autoPlayTTS ? Icons.volume_up : Icons.volume_off,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: autoPlayTTS ? '自动朗读已开启' : '自动朗读已关闭',
                        onPressed: () async {
                          await ref.read(chatProvider.notifier).toggleTTSAutoPlay();
                          final newValue = ref.read(chatProvider).autoPlayTTS;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(newValue ? '自动朗读已开启' : '自动朗读已关闭'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),

              // 第二行：Token余额
              Consumer(
                builder: (context, ref, child) {
                  final tokenAsync = ref.watch(tokenBalanceProvider);
                  return tokenAsync.when(
                    loading: () => const Text('Token余额加载中...', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    error: (e, _) => Text('Token余额加载失败', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                    data: (token) => Text('当前Token余额：$token', style: const TextStyle(fontSize: 12, color: Colors.white)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewConversationTile() {
    // 彻底移除新建对话按钮
    return const SizedBox.shrink();
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
                      backgroundColor: Theme.of(context).primaryColor,
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
          padding: const EdgeInsets.symmetric(vertical: 10.0,horizontal: 5.0),
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
        color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).primaryColor 
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
            color: isSelected ? Theme.of(context).primaryColor : null,
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
          final currentConversationId = ref.read(chatProvider).currentConversation?.id;
          if (currentConversationId == conversation.id) {
            // 如果已是当前会话，只关闭抽屉
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          } else {
            // 切换会话前先unfocus并关闭抽屉
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          await ref.read(chatProvider.notifier).switchToConversation(conversation);
          }
        },
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Consumer(
      builder: (context, ref, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 5),
          child:  Builder(
                builder: (context) => SizedBox(
                  width: double.infinity,
                  child: SafeArea(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('退出登录'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        // 先弹出确认对话框
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('确认退出登录'),
                            content: const Text('确定要退出登录吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        // 调用Provider退出登录
                        final ref = Navigator.of(context).context.findAncestorStateOfType<ConsumerState>()?.ref;
                        if (ref != null) {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) {
                            Navigator.of(context).pop(); // 关闭抽屉
                            // 使用go_router跳转，避免pushReplacementNamed报错
                            context.go(AppConstants.loginRoute);
                          }
                        }
                      },
                ),
              ),
                ),
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