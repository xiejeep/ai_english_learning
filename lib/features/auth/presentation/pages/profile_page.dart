import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import 'package:dio/dio.dart';
import '../../../../core/storage/storage_service.dart';
import '../providers/credits_provider.dart';
import '../../../../shared/models/user_model.dart';

final checkinStatusProvider = FutureProvider<CheckinStatus>((ref) async {
  final dio = Dio();
  final token = StorageService.getUserToken();
  print('[CheckinStatus] 获取签到状态, token: \\${token?.substring(0, 8) ?? 'null'}...');
  if (token == null) throw Exception('未登录，无法获取token');
  final url = AppConstants.baseUrl + 'api/checkin/status';
  print('[CheckinStatus] 请求url: $url');
  try {
    final response = await dio.get(
      url,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    print('[CheckinStatus] 响应: ${response.data}');
    final data = response.data;
    return CheckinStatus(
      hasCheckedIn: data['hasCheckedIn'] ?? data['hasCheckedToday'] ?? false,
      consecutiveDays: data['consecutiveDays'] ?? 0,
      lastCheckinDate: data['lastCheckinDate'] ?? '',
    );
  } catch (e) {
    print('[CheckinStatus] 异常: $e');
    rethrow;
  }
});

class CheckinStatus {
  final bool hasCheckedIn;
  final int consecutiveDays;
  final String lastCheckinDate;
  CheckinStatus({required this.hasCheckedIn, required this.consecutiveDays, required this.lastCheckinDate});
}

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(creditsBalanceProvider);
    });
  }

  Future<void> _doCheckin(BuildContext context, WidgetRef ref) async {
    final dio = Dio();
    final token = StorageService.getUserToken();
    if (token == null) {
      print('[Checkin] 未登录，无法获取token');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未登录，无法签到')),
      );
      return;
    }
    try {
      print('[Checkin] 发起签到请求, token: ${token.substring(0, 8)}...');
      final response = await dio.post(
        AppConstants.baseUrl + 'api/checkin',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('[Checkin] 签到响应: ${response.data}');
      final data = response.data;
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('签到成功，获得${data['creditEarned']}积分！')),
        );
        ref.invalidate(checkinStatusProvider);
      } else {
        final msg = data['message'] ?? '签到失败';
        print('[Checkin] 签到失败: $msg');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      String errorMsg = '签到失败';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          errorMsg = '网络超时，请检查网络后重试';
        } else if (e.type == DioExceptionType.badResponse && e.response != null) {
          final resp = e.response!.data;
          if (resp is Map && resp['message'] != null) {
            errorMsg = resp['message'];
          } else {
            errorMsg = '服务器错误，请稍后重试';
          }
        } else if (e.type == DioExceptionType.unknown) {
          errorMsg = '网络异常，请检查网络连接';
        } else {
          errorMsg = e.message ?? '签到失败';
        }
        print('[Checkin] DioException: $e, response: ${e.response?.data}');
      } else {
        errorMsg = e.toString();
        print('[Checkin] 未知异常: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkinStatusAsync = ref.watch(checkinStatusProvider);
    final creditsAsync = ref.watch(creditsBalanceProvider);
    final tokenAsync = ref.watch(tokenBalanceProvider);
    // 获取本地用户信息
    final userMap = StorageService.getUser();
    UserModel? user;
    if (userMap != null) {
      try {
        user = UserModel.fromJson(userMap);
      } catch (e) {
        print('[ProfilePage] 解析用户信息失败: $e, userMap: $userMap');
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: '退出登录',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('退出登录'),
                    content: const Text('确定要退出登录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('确定'),
                      ),
                    ],
                  );
                },
              );
              if (shouldLogout == true) {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed(AppConstants.loginRoute);
                }
              }
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          // Header: 账户信息+签到（白色圆角卡片）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12,vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 账户信息（左侧）
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.username ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(user?.email ?? '', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        if (user?.phone != null && user!.phone!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(user!.phone!, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                        const SizedBox(height: 4),
                        if (user != null)
                          Text('注册时间：${user.createdAt.year}-${user.createdAt.month.toString().padLeft(2, '0')}-${user.createdAt.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  // 签到（右侧）
                  checkinStatusAsync.when(
                    loading: () => Column(
                      children: const [
                        SizedBox(height: 8),
                        CircularProgressIndicator(strokeWidth: 2),
                      ],
                    ),
                    error: (e, _) => Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        Text('加载失败', style: const TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                    ),
                    data: (status) => Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              status.hasCheckedIn ? Icons.verified : Icons.info_outline,
                              color: status.hasCheckedIn ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(status.hasCheckedIn ? '已签到' : '签到', style: TextStyle(fontSize: 14, color: status.hasCheckedIn ? Colors.green : Colors.orange)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('连续：${status.consecutiveDays}天', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: status.hasCheckedIn ? null : () => _doCheckin(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: status.hasCheckedIn ? Colors.grey : Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(60, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text(status.hasCheckedIn ? '已签到' : '签到'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 当前积分 ListTile（白色卡片）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: creditsAsync.when(
                loading: () => const ListTile(
                  title:  Text('积分'),
                  trailing: SizedBox(width: 20, height: 20, child: CircularProgressIndicator()),
                ),
                error: (e, _) => const ListTile(
                  title:  Text('积分'),
                  trailing:  Text('--'),
                ),
                
                data: (credits) => ListTile(
                  title: const Text('积分'),
                  trailing: Text('$credits', style: TextStyle(fontSize: 16, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                  
                ),
                
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Token使用历史 ListTile（白色卡片）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: const Text('Token'),
                trailing: tokenAsync.when(
                  loading: () => const SizedBox(width: 60, child: LinearProgressIndicator()),
                  error: (e, _) => const Text('--'),
                  data: (token) => Text('$token', style: TextStyle(fontSize: 16, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                ),
                onTap: () {
                  context.push(AppConstants.creditsHistoryRoute);
                },
              ),
            ),
          ),
       
          const SizedBox(height: 24),
        ],
      ),
    );
  }
} 