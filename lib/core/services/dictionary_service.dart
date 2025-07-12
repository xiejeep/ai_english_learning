import 'package:dio/dio.dart';
import '../network/dio_client.dart';

class DictionaryService {
  static final DictionaryService _instance = DictionaryService._internal();
  static DictionaryService get instance => _instance;
  
  DictionaryService._internal();

  /// 获取可用词典列表
  Future<List<DictionaryInfo>?> getAvailableDictionaries() async {
    try {
      final response = await DioClient.instance.get('/api/admin/dictionaries');

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data;
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final dataList = responseData['data'] as List;
          return dataList.map((item) => DictionaryInfo.fromJson(item)).toList();
        }
      }
      
      return null;
    } on DioException catch (e) {
      print('获取词典列表失败: ${e.message}');
      return null;
    } catch (e) {
      print('获取词典列表错误: $e');
      return null;
    }
  }

  /// 调用词典API查询单词
  Future<DictionaryResult?> lookupWord(String word, {String? dictionaryId}) async {
    try {
      String url = '/api/dictionary/lookup/${Uri.encodeComponent(word.trim())}';
      if (dictionaryId != null && dictionaryId.isNotEmpty) {
        url += '?dictId=${Uri.encodeComponent(dictionaryId)}';
      }
      
      final response = await DioClient.instance.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data;
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final dataList = responseData['data'] as List;
          if (dataList.isNotEmpty) {
            final data = dataList[0];
            
            return DictionaryResult(
              word: data['word'] ?? word,
              htmlDefinition: data['definition'] ?? '未找到定义',
              isExactMatch: true,
            );
          }
        }
      }
      
      return null;
    } on DioException catch (e) {
      print('词典查询失败: ${e.message}');
      return null;
    } catch (e) {
      print('词典查询错误: $e');
      return null;
    }
  }

  /// 获取单词建议
  Future<List<String>?> getSuggestions(String query, {String? dictionaryId}) async {
    if (query.trim().isEmpty) return null;
    
    try {
      String url = '/api/dictionary/suggest/${Uri.encodeComponent(query.trim())}';
      if (dictionaryId != null && dictionaryId.isNotEmpty) {
        url += '?dictId=${Uri.encodeComponent(dictionaryId)}';
      }
      
      final response = await DioClient.instance.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data;
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final dataList = responseData['data'] as List;
          return dataList.map((item) => item.toString()).toList();
        }
      }
      
      return null;
    } on DioException catch (e) {
      print('获取建议失败: ${e.message}');
      return null;
    } catch (e) {
      print('获取建议错误: $e');
      return null;
    }
  }

  List<String>? _parseExamples(dynamic examples) {
    if (examples == null) return null;
    
    if (examples is List) {
      return examples.map((e) => e.toString()).toList();
    } else if (examples is String) {
      // 如果是字符串，按换行符分割
      return examples.split('\n').where((e) => e.trim().isNotEmpty).toList();
    }
    
    return null;
  }
}

/// 词典信息
class DictionaryInfo {
  final String id;
  final String name;
  final String? description;
  final int wordCount;
  final String? version;

  DictionaryInfo({
    required this.id,
    required this.name,
    this.description,
    required this.wordCount,
    this.version,
  });

  factory DictionaryInfo.fromJson(Map<String, dynamic> json) {
    return DictionaryInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      wordCount: json['wordCount'] ?? 0,
      version: json['version'],
    );
  }

  // 显示名称，只显示词典名称
  String get displayName => name;
}

/// 词典查询结果
class DictionaryResult {
  final String word;
  final String? definition;
  final String? htmlDefinition;
  final String? pronunciation;
  final String? partOfSpeech;
  final List<String>? examples;
  final bool isExactMatch;

  DictionaryResult({
    required this.word,
    this.definition,
    this.htmlDefinition,
    this.pronunciation,
    this.partOfSpeech,
    this.examples,
    this.isExactMatch = true,
  });
}