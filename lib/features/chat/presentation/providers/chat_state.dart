import '../../../../shared/models/message_model.dart';
import '../../domain/entities/conversation.dart';

enum ChatStatus {
  initial,
  loading,
  sending,
  thinking, // AI思考中状态
  streaming,
  success,
  error,
}

class ChatState {
  final ChatStatus status;
  final List<MessageModel> messages;
  final Conversation? currentConversation;
  final String? error;
  final bool isStreaming;
  final String streamingMessage;
  final bool autoPlayTTS;
  final bool isLoadingMore;
  final bool hasMoreMessages;
  final String? firstId;
  // TTS状态：简化为只需要加载状态和播放状态
  final bool isTTSLoading;
  final bool isTTSPlaying;
  final bool isTTSCompleted; // TTS是否已完成
  // 当前选择的Dify应用ID
  final String? appId;
  final String? appName;

  const ChatState({
    this.status = ChatStatus.initial,
    this.messages = const [],
    this.currentConversation,
    this.error,
    this.isStreaming = false,
    this.streamingMessage = '',
    this.autoPlayTTS = false,
    this.isLoadingMore = false,
    this.hasMoreMessages = true,
    this.firstId,
    this.isTTSLoading = false,
    this.isTTSPlaying = false,
    this.isTTSCompleted = false,
    this.appId,
    this.appName,
  });

  ChatState copyWith({
    ChatStatus? status,
    List<MessageModel>? messages,
    Conversation? currentConversation,
    String? error,
    bool? isStreaming,
    String? streamingMessage,
    bool? autoPlayTTS,
    bool? isLoadingMore,
    bool? hasMoreMessages,
    String? firstId,
    bool? isTTSLoading,
    bool? isTTSPlaying,
    bool? isTTSCompleted,
    String? appId,
    String? appName,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      currentConversation: currentConversation ?? this.currentConversation,
      error: error,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingMessage: streamingMessage ?? this.streamingMessage,
      autoPlayTTS: autoPlayTTS ?? this.autoPlayTTS,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      firstId: firstId ?? this.firstId,
      isTTSLoading: isTTSLoading ?? this.isTTSLoading,
      isTTSPlaying: isTTSPlaying ?? this.isTTSPlaying,
      isTTSCompleted: isTTSCompleted ?? this.isTTSCompleted,
      appId: appId ?? this.appId,
      appName: appName ?? this.appName,
    );
  }

  // 清除错误状态
  ChatState clearError() {
    return copyWith(error: null, status: ChatStatus.initial);
  }

  // 设置加载状态
  ChatState setLoading() {
    return copyWith(status: ChatStatus.loading, error: null);
  }

  // 设置发送状态
  ChatState setSending() {
    return copyWith(status: ChatStatus.sending, error: null);
  }

  // 设置思考状态
  ChatState setThinking() {
    return copyWith(status: ChatStatus.thinking, error: null);
  }

  // 设置流式响应状态
  ChatState setStreaming(String message) {
    return copyWith(
      status: ChatStatus.streaming,
      isStreaming: true,
      streamingMessage: message,
      error: null,
    );
  }

  // 停止流式响应
  ChatState stopStreaming() {
    return copyWith(
      status: ChatStatus.success,
      isStreaming: false,
      streamingMessage: '',
    );
  }

  // 设置错误状态
  ChatState setError(String error) {
    return copyWith(
      status: ChatStatus.error,
      error: error,
      isStreaming: false,
      streamingMessage: '',
    );
  }

  // 设置成功状态
  ChatState setSuccess() {
    return copyWith(
      status: ChatStatus.success,
      error: null,
      isStreaming: false,
      streamingMessage: '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatState &&
        other.status == status &&
        other.messages == messages &&
        other.currentConversation == currentConversation &&
        other.error == error &&
        other.isStreaming == isStreaming &&
        other.streamingMessage == streamingMessage &&
        other.autoPlayTTS == autoPlayTTS &&
        other.isLoadingMore == isLoadingMore &&
        other.hasMoreMessages == hasMoreMessages &&
        other.firstId == firstId &&
        other.isTTSLoading == isTTSLoading &&
        other.isTTSPlaying == isTTSPlaying &&
        other.isTTSCompleted == isTTSCompleted &&
        other.appId == appId &&
        other.appName == appName;
  }

  @override
  int get hashCode {
    return status.hashCode ^
        messages.hashCode ^
        currentConversation.hashCode ^
        error.hashCode ^
        isStreaming.hashCode ^
        streamingMessage.hashCode ^
        autoPlayTTS.hashCode ^
        isLoadingMore.hashCode ^
        hasMoreMessages.hashCode ^
        firstId.hashCode ^
        isTTSLoading.hashCode ^
        isTTSPlaying.hashCode ^
        isTTSCompleted.hashCode ^
        appId.hashCode ^
        appName.hashCode;
  }
}