import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/network/dio_client.dart';

// Token历史数据模型
class TokenHistoryModel {
  final String id;
  final int tokens;
  final DateTime createdAt;
  final String conversationId;
  final String messageId;
  final String remark;
  final String reason;

  TokenHistoryModel({
    required this.id,
    required this.tokens,
    required this.createdAt,
    required this.conversationId,
    required this.messageId,
    required this.remark,
    required this.reason,
  });

  factory TokenHistoryModel.fromJson(Map<String, dynamic> json) {
    return TokenHistoryModel(
      id: json['id'] ?? '',
      tokens: json['totalTokens'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      conversationId: json['conversation_id'] ?? '',
      messageId: json['message_id'] ?? '',
      remark: json['remark'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}

// Token历史Provider
class TokenHistoryNotifier extends StateNotifier<TokenHistoryState> {
  TokenHistoryNotifier() : super(TokenHistoryState());

  Future<void> loadTokenHistory({bool isRefresh = false, int page = 1}) async {
    if (isRefresh) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    } else {
      state = state.copyWith(isLoadingMore: true, errorMessage: null);
    }
    
    try {
      final dio = DioClient.instance;
      final token = StorageService.getUserToken();
      if (token == null) {
        throw Exception('未登录，无法获取token');
      }

      final response = await dio.get(
        '${AppConstants.baseUrl}api/credits/token-history',
        queryParameters: {
          'page': page,
          'limit': 20,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final List<dynamic> data = response.data['data'] ?? [];
      final history = data.map((item) => TokenHistoryModel.fromJson(item)).toList();
      final int totalPages = response.data['totalPages'] ?? 1;
      
      if (isRefresh) {
        state = state.copyWith(
          tokenHistory: history,
          isLoading: false,
          currentPage: 1,
          totalPages: totalPages,
        );
      } else {
        state = state.copyWith(
          tokenHistory: [...state.tokenHistory, ...history],
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
    loadTokenHistory(isRefresh: true);
  }

  void loadMore() {
    // 如果已经到达最后一页，不再加载
    if (state.currentPage >= state.totalPages) {
      return;
    }
    loadTokenHistory(isRefresh: false, page: state.currentPage + 1);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

class TokenHistoryState {
  final List<TokenHistoryModel> tokenHistory;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final int currentPage;
  final int totalPages;

  TokenHistoryState({
    this.tokenHistory = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  TokenHistoryState copyWith({
    List<TokenHistoryModel>? tokenHistory,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    int? currentPage,
    int? totalPages,
  }) {
    return TokenHistoryState(
      tokenHistory: tokenHistory ?? this.tokenHistory,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

final tokenHistoryProvider = StateNotifierProvider<TokenHistoryNotifier, TokenHistoryState>((ref) {
  return TokenHistoryNotifier();
});

class TokenHistoryPage extends ConsumerStatefulWidget {
  const TokenHistoryPage({super.key});

  @override
  ConsumerState<TokenHistoryPage> createState() => _TokenHistoryPageState();
}

class _TokenHistoryPageState extends ConsumerState<TokenHistoryPage> {
  final EasyRefreshController _refreshController = EasyRefreshController(
    controlFinishRefresh: true,
    controlFinishLoad: true,
  );

  @override
  void initState() {
    super.initState();
    // 页面加载时获取token历史
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tokenHistoryProvider.notifier).loadTokenHistory(isRefresh: true);
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
          'Token使用历史',
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
          final tokenHistoryState = ref.watch(tokenHistoryProvider);
          
          if (tokenHistoryState.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              ),
            );
          }

          if (tokenHistoryState.errorMessage != null) {
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
                    tokenHistoryState.errorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(tokenHistoryProvider.notifier).clearError();
                      ref.read(tokenHistoryProvider.notifier).refresh();
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

          if (tokenHistoryState.tokenHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无使用记录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '开始对话后将显示token使用记录',
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
              ref.read(tokenHistoryProvider.notifier).refresh();
              _refreshController.finishRefresh();
              return IndicatorResult.success;
            },
            onLoad: () async {
              ref.read(tokenHistoryProvider.notifier).loadMore();
              // 如果到达最后一页，返回noMore
              if (tokenHistoryState.currentPage >= tokenHistoryState.totalPages) {
                _refreshController.finishLoad(IndicatorResult.noMore);
                return IndicatorResult.noMore;
              }
              _refreshController.finishLoad();
              return IndicatorResult.success;
            },
            child: _buildHistoryList(tokenHistoryState.tokenHistory),
          );
        },
      ),
    );
  }

  Widget _buildHistoryList(List<TokenHistoryModel> history) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final record = history[index];
        return _buildHistoryItem(record);
      },
    );
  }

  Widget _buildHistoryItem(TokenHistoryModel record) {
    final dateFormat = DateFormat('MM-dd HH:mm');
    
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 7,
            child: Text(
              record.reason,
              maxLines: 2,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  dateFormat.format(record.createdAt),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '${record.tokens} tokens',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 