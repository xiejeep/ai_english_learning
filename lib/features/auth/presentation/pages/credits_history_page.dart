import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/network/dio_client.dart';
import '../providers/user_profile_provider.dart';

// 兑换比例数据模型
class ExchangeRateModel {
  final double rate;
  final int minCredits;
  final int maxCredits;

  ExchangeRateModel({
    required this.rate,
    required this.minCredits,
    required this.maxCredits,
  });

  factory ExchangeRateModel.fromJson(Map<String, dynamic> json) {
    return ExchangeRateModel(
      rate: (json['creditsToTokens'] ?? 1.0).toDouble(),
      minCredits: json['minCredits'] ?? 1,
      maxCredits: json['maxCredits'] ?? 1000,
    );
  }
}

// 兑换状态
class ExchangeState {
  final ExchangeRateModel? exchangeRate;
  final bool isLoading;
  final bool isExchanging;

  ExchangeState({
    this.exchangeRate,
    this.isLoading = false,
    this.isExchanging = false,
  });

  ExchangeState copyWith({
    ExchangeRateModel? exchangeRate,
    bool? isLoading,
    bool? isExchanging,
  }) {
    return ExchangeState(
      exchangeRate: exchangeRate ?? this.exchangeRate,
      isLoading: isLoading ?? this.isLoading,
      isExchanging: isExchanging ?? this.isExchanging,
    );
  }
}

// 兑换Provider
class ExchangeNotifier extends StateNotifier<ExchangeState> {
  ExchangeNotifier() : super(ExchangeState());

  Future<void> loadExchangeRate() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final dio = DioClient.instance;
      final token = StorageService.getUserToken();
      if (token == null) {
        throw Exception('未登录，无法获取兑换比例');
      }

      final response = await dio.get(
        '${AppConstants.baseUrl}api/credits/exchange-rate',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final exchangeRate = ExchangeRateModel.fromJson(response.data);
      state = state.copyWith(
        exchangeRate: exchangeRate,
        isLoading: false,
      );
    } catch (e) {
        state = state.copyWith(isLoading: false);
        // 可以选择在这里显示SnackBar，但通常获取兑换比例失败不需要特别提示
      }
  }

  Future<void> exchangeCreditsForTokens(int credits, BuildContext context, WidgetRef ref) async {
    state = state.copyWith(isExchanging: true);
    
    // 获取当前用户信息用于乐观更新
    final currentProfile = ref.read(userProfileProvider);
    int? currentCredits;
    int? currentTokenBalance;
    
    currentProfile.whenData((profile) {
      currentCredits = profile.credits;
      currentTokenBalance = profile.tokenBalance;
    });
    
    try {
      final dio = DioClient.instance;
      final token = StorageService.getUserToken();
      if (token == null) {
        throw Exception('未登录，无法进行兑换');
      }

      final response = await dio.post(
        '${AppConstants.baseUrl}api/credits/exchange-for-tokens',
        data: {'creditsToExchange': credits},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final tokens = (response.data['tokensEarned'] ?? 0) as int;
      state = state.copyWith(isExchanging: false);
      
      // 乐观更新：直接更新本地状态
      if (currentCredits != null && currentTokenBalance != null) {
        final newCredits = currentCredits! - credits;
        final newTokenBalance = currentTokenBalance! + tokens;
        
        print('[Exchange] 兑换成功，更新本地状态: 消耗积分=$credits, 获得tokens=$tokens');
        print('[Exchange] 更新前: credits=$currentCredits, tokens=$currentTokenBalance');
        print('[Exchange] 更新后: credits=$newCredits, tokens=$newTokenBalance');
        
        ref.read(userProfileProvider.notifier).updateCreditsAndTokens(
          newCredits,
          newTokenBalance,
        );
      } else {
        print('[Exchange] 警告：无法获取当前用户状态，跳过乐观更新');
      }
      
      // 刷新积分历史记录
      ref.read(creditsHistoryProvider.notifier).refresh();
      
      // 显示成功SnackBar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
            content: Text('兑换成功'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      state = state.copyWith(isExchanging: false);
      
      // 显示失败SnackBar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('兑换失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }


}

final exchangeProvider = StateNotifierProvider<ExchangeNotifier, ExchangeState>((ref) {
  return ExchangeNotifier();
});

// 积分历史数据模型
class CreditsHistoryModel {
  final String id;
  final int amount;
  final int balance;
  final DateTime createdAt;
  final String type;
  final String reason;
  final String? userId;

  CreditsHistoryModel({
    required this.id,
    required this.amount,
    required this.balance,
    required this.createdAt,
    required this.type,
    required this.reason,
    this.userId,
  });

  factory CreditsHistoryModel.fromJson(Map<String, dynamic> json) {
    return CreditsHistoryModel(
      id: json['id'] ?? '',
      amount: json['amount'] ?? 0,
      balance: json['balance'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      type: json['type'] ?? '',
      reason: json['reason'] ?? '',
      userId: json['userId'],
    );
  }
}

// 积分历史Provider
class CreditsHistoryNotifier extends StateNotifier<CreditsHistoryState> {
  CreditsHistoryNotifier() : super(CreditsHistoryState());

  Future<void> loadCreditsHistory({bool isRefresh = false, int page = 1}) async {
    if (isRefresh) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    } else {
      state = state.copyWith(isLoadingMore: true, errorMessage: null);
    }
    
    try {
      final dio = DioClient.instance;
      final token = StorageService.getUserToken();
      if (token == null) {
        throw Exception('未登录，无法获取积分历史');
      }

      final response = await dio.get(
        '${AppConstants.baseUrl}api/credits/history',
        queryParameters: {
          'page': page,
          'limit': 20,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final List<dynamic> data = response.data['data'] ?? [];
      final history = data.map((item) => CreditsHistoryModel.fromJson(item)).toList();
      final int totalPages = response.data['totalPages'] ?? 1;
      
      if (isRefresh) {
        state = state.copyWith(
          creditsHistory: history,
          isLoading: false,
          currentPage: 1,
          totalPages: totalPages,
        );
      } else {
        state = state.copyWith(
          creditsHistory: [...state.creditsHistory, ...history],
          isLoadingMore: false,
          currentPage: state.currentPage + 1,
          totalPages: totalPages,
        );
      }
    } catch (e) {
      if (isRefresh) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '加载失败: $e',
        );
      } else {
        state = state.copyWith(
          isLoadingMore: false,
          errorMessage: '加载更多失败: $e',
        );
      }
    }
  }

  void refresh() {
    loadCreditsHistory(isRefresh: true);
  }

  void loadMore() {
    // 如果已经到达最后一页，不再加载
    if (state.currentPage >= state.totalPages) {
      return;
    }
    loadCreditsHistory(isRefresh: false, page: state.currentPage + 1);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

class CreditsHistoryState {
  final List<CreditsHistoryModel> creditsHistory;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final int currentPage;
  final int totalPages;

  CreditsHistoryState({
    this.creditsHistory = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  CreditsHistoryState copyWith({
    List<CreditsHistoryModel>? creditsHistory,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    int? currentPage,
    int? totalPages,
  }) {
    return CreditsHistoryState(
      creditsHistory: creditsHistory ?? this.creditsHistory,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

final creditsHistoryProvider = StateNotifierProvider<CreditsHistoryNotifier, CreditsHistoryState>((ref) {
  return CreditsHistoryNotifier();
});

class CreditsHistoryPage extends ConsumerStatefulWidget {
  const CreditsHistoryPage({super.key});

  @override
  ConsumerState<CreditsHistoryPage> createState() => _CreditsHistoryPageState();
}

class _CreditsHistoryPageState extends ConsumerState<CreditsHistoryPage> {
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  @override
  void initState() {
    super.initState();
    // 页面加载时获取积分历史和兑换比例
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(creditsHistoryProvider.notifier).loadCreditsHistory(isRefresh: true);
      ref.read(exchangeProvider.notifier).loadExchangeRate();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '积分使用历史',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final creditsHistoryState = ref.watch(creditsHistoryProvider);
          
          if (creditsHistoryState.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              ),
            );
          }

          if (creditsHistoryState.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    creditsHistoryState.errorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(creditsHistoryProvider.notifier).clearError();
                      ref.read(creditsHistoryProvider.notifier).refresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          if (creditsHistoryState.creditsHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无积分记录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '签到或完成任务后将显示积分记录',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return EasyRefresh(
            controller: _refreshController,
            header: const ClassicHeader(),
            footer: const ClassicFooter(),
            onRefresh: () async {
              ref.read(creditsHistoryProvider.notifier).refresh();
              ref.read(exchangeProvider.notifier).loadExchangeRate();
              _refreshController.finishRefresh();
              return IndicatorResult.success;
            },
            onLoad: () async {
              ref.read(creditsHistoryProvider.notifier).loadMore();
              // 如果到达最后一页，返回noMore
              if (creditsHistoryState.currentPage >= creditsHistoryState.totalPages) {
                _refreshController.finishLoad(IndicatorResult.noMore);
                return IndicatorResult.noMore;
              }
              _refreshController.finishLoad();
              return IndicatorResult.success;
            },
            child: Column(
              children: [
                _buildExchangeHeader(),
                Expanded(child: _buildHistoryList(creditsHistoryState.creditsHistory)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExchangeHeader() {
    return Consumer(
      builder: (context, ref, child) {
        final exchangeState = ref.watch(exchangeProvider);
        final userProfile = ref.watch(userProfileProvider);
        final creditsAsync = userProfile.when(
          data: (profile) => AsyncValue.data(profile.credits),
          loading: () => const AsyncValue.loading(),
          error: (error, stack) => AsyncValue.error(error, stack),
        );
        final tokensAsync = userProfile.when(
           data: (profile) => AsyncValue.data(profile.tokenBalance),
           loading: () => const AsyncValue.loading(),
           error: (error, stack) => AsyncValue.error(error, stack),
         );
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '积分兑换',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 余额显示
              Row(
                children: [
                  Expanded(
                    child: _buildBalanceCard(
                      '积分余额',
                      creditsAsync.when(
                        data: (credits) => credits.toString(),
                        loading: () => '--',
                        error: (_, __) => '--',
                      ),
                      Icons.account_balance_wallet,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBalanceCard(
                      'Token余额',
                      tokensAsync.when(
                        data: (tokens) => tokens.toString(),
                        loading: () => '--',
                        error: (_, __) => '--',
                      ),
                      Icons.token,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              
              if (exchangeState.exchangeRate != null) ...[
                const SizedBox(height: 16),
                // 兑换比例
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '兑换比例: 1积分 = ${exchangeState.exchangeRate!.rate} Token',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 兑换按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: exchangeState.isExchanging ? null : () => _showExchangeDialog(exchangeState.exchangeRate!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: exchangeState.isExchanging
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '兑换Token',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<CreditsHistoryModel> history) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final record = history[index];
        return _buildHistoryItem(record);
      },
    );
  }

  void _showExchangeDialog(ExchangeRateModel exchangeRate) {
    final TextEditingController creditsController = TextEditingController();
    final userProfile = ref.read(userProfileProvider);
    final creditsAsync = userProfile.when(
      data: (profile) => AsyncValue.data(profile.credits),
      loading: () => const AsyncValue.loading(),
      error: (error, stack) => AsyncValue.error(error, stack),
    );
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final inputCredits = int.tryParse(creditsController.text) ?? 0;
            final tokens = (inputCredits * exchangeRate.rate).floor();
            final isValid = inputCredits >= exchangeRate.minCredits && 
                           inputCredits <= exchangeRate.maxCredits &&
                           creditsAsync.hasValue &&
                           inputCredits <= creditsAsync.value!;
            
            return AlertDialog(
              title: const Text(
                '积分兑换Token',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '兑换比例: 1 积分 = ${exchangeRate.rate} Token',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '可兑换范围: ${exchangeRate.minCredits} - ${exchangeRate.maxCredits} 积分',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: creditsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '输入积分数量',
                      hintText: '请输入要兑换的积分数量',
                      border: const OutlineInputBorder(),
                      errorText: !isValid && creditsController.text.isNotEmpty
                          ? _getValidationError(inputCredits, exchangeRate, creditsAsync)
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  if (inputCredits > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[600],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '将获得 $tokens 个Token',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () {
                          Navigator.of(context).pop();
                          ref.read(exchangeProvider.notifier).exchangeCreditsForTokens(inputCredits, context, ref);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('确认兑换'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String? _getValidationError(int inputCredits, ExchangeRateModel exchangeRate, AsyncValue<dynamic> creditsAsync) {
    if (inputCredits < exchangeRate.minCredits) {
      return '最少需要 ${exchangeRate.minCredits} 积分';
    }
    if (inputCredits > exchangeRate.maxCredits) {
      return '最多只能兑换 ${exchangeRate.maxCredits} 积分';
    }
    if (creditsAsync.hasValue && inputCredits > creditsAsync.value!) {
      return '积分余额不足';
    }
    return null;
  }

  Widget _buildHistoryItem(CreditsHistoryModel record) {
    final dateFormat = DateFormat('MM-dd HH:mm');
    final isPositive = record.amount > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isPositive ? Icons.add : Icons.remove,
              color: isPositive ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // 描述和时间
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.reason,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(record.createdAt),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          // 积分变化
          Text(
            '${isPositive ? '+' : ''}${record.amount}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}