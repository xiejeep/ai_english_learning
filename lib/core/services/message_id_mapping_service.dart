/// 消息ID映射服务
/// 负责管理服务器消息ID与本地消息ID之间的映射关系
class MessageIdMappingService {
  static final MessageIdMappingService _instance = MessageIdMappingService._internal();
  factory MessageIdMappingService() => _instance;
  MessageIdMappingService._internal();

  static MessageIdMappingService get instance => _instance;

  /// 服务器ID到本地ID的映射表
  final Map<String, String> _serverToLocalMap = {};
  
  /// 本地ID到服务器ID的映射表（反向映射）
  final Map<String, String> _localToServerMap = {};

  /// 添加映射关系
  void addMapping(String serverId, String localId) {
    if (serverId.isEmpty || localId.isEmpty) {
      print('⚠️ [ID Mapping] 无效的ID映射: serverId=$serverId, localId=$localId');
      return;
    }

    _serverToLocalMap[serverId] = localId;
    _localToServerMap[localId] = serverId;
    
    print('🔗 [ID Mapping] 建立映射: $serverId -> $localId');
    print('📊 [ID Mapping] 当前映射数量: ${_serverToLocalMap.length}');
  }

  /// 根据服务器ID获取本地ID
  String? getLocalId(String serverId) {
    final localId = _serverToLocalMap[serverId];
    if (localId == null) {
      print('⚠️ [ID Mapping] 未找到服务器ID对应的本地ID: $serverId');
    }
    return localId;
  }

  /// 根据本地ID获取服务器ID
  String? getServerId(String localId) {
    final serverId = _localToServerMap[localId];
    if (serverId == null) {
      print('⚠️ [ID Mapping] 未找到本地ID对应的服务器ID: $localId');
    }
    return serverId;
  }

  /// 根据本地ID获取服务器消息ID（别名方法）
  String? getServerMessageId(String localId) {
    return getServerId(localId);
  }

  /// 确保映射关系存在，如果不存在则创建
  void ensureMapping(String serverId, String localId) {
    if (!hasMapping(serverId)) {
      addMapping(serverId, localId);
      print('🎬 [ID Mapping] 启动TTS消息处理: $serverId -> $localId');
    }
  }

  /// 检查映射是否存在
  bool hasMapping(String serverId) {
    return _serverToLocalMap.containsKey(serverId);
  }

  /// 清除指定的映射关系
  void clearMapping(String serverId) {
    final localId = _serverToLocalMap.remove(serverId);
    if (localId != null) {
      _localToServerMap.remove(localId);
      print('🗑️ [ID Mapping] 清除映射: $serverId -> $localId');
    }
  }

  /// 清除所有映射关系
  void clearAllMappings() {
    final count = _serverToLocalMap.length;
    _serverToLocalMap.clear();
    _localToServerMap.clear();
    print('🗑️ [ID Mapping] 清除所有映射，共清除 $count 个映射');
  }

  /// 清除所有映射关系（别名方法）
  void clear() {
    clearAllMappings();
  }

  /// 获取所有映射关系（用于调试）
  Map<String, String> getAllMappings() {
    return Map.unmodifiable(_serverToLocalMap);
  }

  /// 获取映射统计信息
  Map<String, dynamic> getStats() {
    return {
      'totalMappings': _serverToLocalMap.length,
      'serverIds': _serverToLocalMap.keys.toList(),
      'localIds': _serverToLocalMap.values.toList(),
    };
  }
}