import 'package:asmrapp/core/cache/recommendation_cache_manager.dart';
import 'package:asmrapp/data/models/mark_status.dart';
import 'package:asmrapp/data/models/playlists_with_exist_statu/playlists_with_exist_statu.dart';
import 'package:dio/dio.dart';
import 'package:asmrapp/data/models/files/files.dart';
import 'package:asmrapp/data/models/works/work.dart';
import 'package:asmrapp/data/models/works/pagination.dart';
import 'package:asmrapp/utils/logger.dart';
import 'package:asmrapp/data/services/interceptors/auth_interceptor.dart';
import 'package:asmrapp/data/models/playlists_with_exist_statu/playlist.dart';
import 'package:asmrapp/data/models/my_lists/my_playlists/my_playlists.dart';
import 'package:asmrapp/core/cache/list_cache_manager.dart';


class WorksResponse {
  final List<Work> works;
  final Pagination pagination;

  WorksResponse({required this.works, required this.pagination});
}

class ApiService {
  final Dio _dio;
  final _recommendationCache = RecommendationCacheManager();
  final _listCache = ListCacheManager();

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.asmr.one/api',
        )) {
    _dio.interceptors.add(AuthInterceptor());
  }

  /// 获取作品文件列表
  Future<Files> getWorkFiles(String workId, {CancelToken? cancelToken}) async {
    final cacheKey = 'files-$workId';
    
    if (_listCache.enabled) {
      final cached = await _listCache.get(cacheKey);
      if (cached != null) {
        return Files.fromJson(cached);
      }
    }

    try {
      final response = await _dio.get(
        '/tracks/$workId', 
        queryParameters: {
          'v': '1',
        },
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        final filesData = {
          'type': 'root',
          'title': 'Root',
          'children': response.data,
        };

        final result = Files.fromJson(filesData);

        try {
          await _listCache.set(cacheKey, filesData);
        } catch (_) {}

        return result;
      }

      throw Exception('获取文件列表失败: ${response.statusCode}');
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('解析数据失败', e, stackTrace);
      throw Exception('解析数据失败: $e');
    }
  }

  /// 获取作品列表
  Future<WorksResponse> getWorks({
    int page = 1,
    bool hasSubtitle = false,
    String order = 'create_date',
    String sort = 'desc',
    String playlistId = '',
  }) async {
    final cacheKey = 'works-$page-$hasSubtitle-$order-$sort-$playlistId';
    
    // 如果启用了列表缓存，先尝试从缓存读取
    if (_listCache.enabled) {
      final cached = await _listCache.get(cacheKey);
      if (cached != null) {
        return WorksResponse(
          works: (cached['works'] as List)
              .map((w) => Work.fromJson(w as Map<String, dynamic>))
              .toList(),
          pagination: Pagination.fromJson(cached['pagination'] as Map<String, dynamic>),
        );
      }
    }

    try {
      final queryParams = {
        'page': page,
        'subtitle': hasSubtitle ? 1 : 0,
        'order': order,
        'sort': sort,
      };
      // 如果提供了收藏夹ID，添加到查询参数
      if (playlistId.isNotEmpty) {
        queryParams['withPlaylistStatus[]'] = playlistId;
      }

      final response = await _dio.get(
        '/works',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> works = response.data['works'] ?? [];
        final pagination = Pagination.fromJson(response.data['pagination']);

        final result = WorksResponse(
          works: works.map((work) => Work.fromJson(work)).toList(),
          pagination: pagination,
        );

        // 保存到列表缓存（无论开关状态，始终缓存以便后续离线使用）
        try {
          await _listCache.set(cacheKey, {
            'works': response.data['works'] ?? [],
            'pagination': response.data['pagination'] ?? {},
          });
        } catch (_) {}

        return result;
      }

      throw Exception('获取作品列表失败: ${response.statusCode}');
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('解析数据失败', e, stackTrace);
      throw Exception('解析数据失败: $e');
    }
  }

  /// 搜索作品
  Future<WorksResponse> searchWorks({
    required String keyword,
    int page = 1,
    String order = 'create_date',
    String sort = 'desc',
    bool hasSubtitle = false,
  }) async {
    final cacheKey = 'search-$keyword-$page-$order-$sort-$hasSubtitle';
    
    if (_listCache.enabled) {
      final cached = await _listCache.get(cacheKey);
      if (cached != null) {
        return WorksResponse(
          works: (cached['works'] as List)
              .map((w) => Work.fromJson(w as Map<String, dynamic>))
              .toList(),
          pagination: Pagination.fromJson(cached['pagination'] as Map<String, dynamic>),
        );
      }
    }

    try {
      final response = await _dio.get(
        '/search/${Uri.encodeComponent(keyword)}',
        queryParameters: {
          'page': page,
          'order': order,
          'sort': sort,
          'subtitle': hasSubtitle ? 1 : 0,
          'includeTranslationWorks': true,
        },
      );

      if (response.statusCode == 200) {
        AppLogger.debug('搜索返回数据: ${response.data}');

        final works = (response.data['works'] as List)
            .map((work) => Work.fromJson(work))
            .toList();

        final pagination = Pagination.fromJson(response.data['pagination']);

        final result = WorksResponse(
          works: works,
          pagination: pagination,
        );

        try {
          await _listCache.set(cacheKey, {
            'works': response.data['works'] ?? [],
            'pagination': response.data['pagination'] ?? {},
          });
        } catch (_) {}

        return result;
      }

      throw Exception('搜索失败: ${response.statusCode}');
    } catch (e) {
      throw Exception('搜索请求失败: $e');
    }
  }

  /// 获取收藏列表
  Future<WorksResponse> getFavorites({int page = 1}) async {
    final cacheKey = 'favorites-$page';
    
    if (_listCache.enabled) {
      final cached = await _listCache.get(cacheKey);
      if (cached != null) {
        return WorksResponse(
          works: (cached['works'] as List)
              .map((w) => Work.fromJson(w as Map<String, dynamic>))
              .toList(),
          pagination: Pagination.fromJson(cached['pagination'] as Map<String, dynamic>),
        );
      }
    }

    try {
      final response = await _dio.get('/review', queryParameters: {
        'page': page,
        'order': 'updated_at',
        'sort': 'desc',
      });

      if (response.statusCode == 200) {
        final List<dynamic> works = response.data['works'] ?? [];
        final pagination = Pagination.fromJson(response.data['pagination']);

        final result = WorksResponse(
          works: works.map((work) => Work.fromJson(work)).toList(),
          pagination: pagination,
        );

        try {
          await _listCache.set(cacheKey, {
            'works': response.data['works'] ?? [],
            'pagination': response.data['pagination'] ?? {},
          });
        } catch (_) {}

        return result;
      }

      throw Exception('获取收藏列表失败: ${response.statusCode}');
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('解析数据失败', e, stackTrace);
      throw Exception('解析数据失败: $e');
    }
  }

  /// 获取推荐作品
  Future<WorksResponse> getRecommendations({
    required String uuid,
    int page = 1,
    bool hasSubtitle = false,
  }) async {
    final cacheKey = 'recommend-$uuid-$page-$hasSubtitle';
    
    if (_listCache.enabled) {
      final cached = await _listCache.get(cacheKey);
      if (cached != null) {
        return WorksResponse(
          works: (cached['works'] as List)
              .map((w) => Work.fromJson(w as Map<String, dynamic>))
              .toList(),
          pagination: Pagination.fromJson(cached['pagination'] as Map<String, dynamic>),
        );
      }
    }

    try {
      final response = await _dio.post(
        '/recommender/recommend-for-user',
        data: {
          'keyword': ' ',
          'userId': uuid,
          'page': page,
          'subtitle': hasSubtitle ? 1 : 0,
          'localSubtitledWorks': [],
          'withPlaylistStatus': [],
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> works = response.data['works'] ?? [];
        final pagination = Pagination.fromJson(response.data['pagination']);

        final result = WorksResponse(
          works: works.map((work) => Work.fromJson(work)).toList(),
          pagination: pagination,
        );

        try {
          await _listCache.set(cacheKey, {
            'works': response.data['works'] ?? [],
            'pagination': response.data['pagination'] ?? {},
          });
        } catch (_) {}

        return result;
      }

      throw Exception('获取推荐列表失败: ${response.statusCode}');
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('解析数据失败', e, stackTrace);
      throw Exception('解析数据失败: $e');
    }
  }

  /// 获取热门作品
  Future<WorksResponse> getPopular({
    int page = 1,
    bool hasSubtitle = false,
  }) async {
    final cacheKey = 'popular-$page-$hasSubtitle';
    
    if (_listCache.enabled) {
      final cached = await _listCache.get(cacheKey);
      if (cached != null) {
        return WorksResponse(
          works: (cached['works'] as List)
              .map((w) => Work.fromJson(w as Map<String, dynamic>))
              .toList(),
          pagination: Pagination.fromJson(cached['pagination'] as Map<String, dynamic>),
        );
      }
    }

    try {
      final response = await _dio.post(
        '/recommender/popular',
        data: {
          'keyword': ' ',
          'page': page,
          'subtitle': hasSubtitle ? 1 : 0,
          'localSubtitledWorks': [],
          'withPlaylistStatus': [],
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> works = response.data['works'] ?? [];
        final pagination = Pagination.fromJson(response.data['pagination']);

        final result = WorksResponse(
          works: works.map((work) => Work.fromJson(work)).toList(),
          pagination: pagination,
        );

        try {
          await _listCache.set(cacheKey, {
            'works': response.data['works'] ?? [],
            'pagination': response.data['pagination'] ?? {},
          });
        } catch (_) {}

        return result;
      }

      throw Exception('获取热门列表失败: ${response.statusCode}');
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('解析数据失败', e, stackTrace);
      throw Exception('解析数据失败: $e');
    }
  }

  /// 获取相关推荐作品
  Future<WorksResponse> getItemNeighbors({
    required String itemId,
    int page = 1,
    bool hasSubtitle = false,
  }) async {
    try {
      // 先尝试从缓存获取
      final cachedData = _recommendationCache.get(itemId, page, hasSubtitle ? 1 : 0);
      if (cachedData != null) {
        return cachedData;
      }

      // 缓存未命中，从网络获取
      final response = await _dio.post(
        '/recommender/item-neighbors',
        data: {
          'keyword': '',
          'itemId': itemId,
          'page': page,
          'subtitle': hasSubtitle ? 1 : 0,
          'localSubtitledWorks': [],
          'withPlaylistStatus': [],
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> works = response.data['works'] ?? [];
        final pagination = Pagination.fromJson(response.data['pagination']);

        final worksResponse = WorksResponse(
          works: works.map((work) => Work.fromJson(work)).toList(),
          pagination: pagination,
        );

        // 存入缓存
        _recommendationCache.set(itemId, page, hasSubtitle ? 1 : 0, worksResponse);

        return worksResponse;
      }

      throw Exception('获取相关推荐失败: ${response.statusCode}');
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('解析数据失败', e, stackTrace);
      throw Exception('解析数据失败: $e');
    }
  }

  /// 获取作品在收藏夹中的状态
  Future<PlaylistsWithExistStatu> getWorkExistStatusInPlaylists({
    required String workId,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/playlist/get-work-exist-status-in-my-playlists',
        queryParameters: {
          'workID': workId,
          'page': page,
          'version': 2,
        },
      );

      if (response.statusCode == 200) {
        return PlaylistsWithExistStatu.fromJson(response.data);
      }

      throw Exception('获取收藏夹列表失败: ${response.statusCode}');
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('解析数据失败', e, stackTrace);
      throw Exception('解析数据失败: $e');
    }
  }

  /// 添加作品到收藏夹
  Future<void> addWorkToPlaylist({
    required String playlistId,
    required String workId,
  }) async {
    try {
      await _dio.post(
        '/playlist/add-works-to-playlist',
        data: {
          'id': playlistId,
          'works': [int.parse(workId)],
        },
      );
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('添加到收藏夹失败', e, stackTrace);
      throw Exception('添加到收藏夹失败: $e');
    }
  }

  /// 从收藏夹移除作品
  Future<void> removeWorkFromPlaylist({
    required String playlistId,
    required String workId,
  }) async {
    try {
      await _dio.post(
        '/playlist/remove-works-from-playlist',
        data: {
          'id': playlistId,
          'works': [int.parse(workId)],
        },
      );
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('从收藏夹移除失败', e, stackTrace);
      throw Exception('从收藏夹移除失败: $e');
    }
  }

  /// 更新作品的标记状态
  Future<void> updateWorkMarkStatus(String workId, String status) async {
    try {
      final response = await _dio.put(
        '/review',
        data: {
          'work_id': int.parse(workId),
          'progress': status,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('标记失败: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('更新标记状态失败', e);
      rethrow;
    }
  }

  /// 将 MarkStatus 枚举转换为 API 参数
  String convertMarkStatusToApi(MarkStatus status) {
    switch (status) {
      case MarkStatus.wantToListen:
        return 'marked';
      case MarkStatus.listening:
        return 'listening';
      case MarkStatus.listened:
        return 'listened';
      case MarkStatus.relistening:
        return 'replay';
      case MarkStatus.onHold:
        return 'postponed';
    }
  }

  /// 获取默认标记目标收藏夹
  Future<Playlist> getDefaultMarkTargetPlaylist() async {
    try {
      final response = await _dio.get('/playlist/get-default-mark-target-playlist');

      if (response.statusCode == 200) {
        final playlist = Playlist.fromJson(response.data);
        AppLogger.info('获取默认标记目标收藏夹成功: id=${playlist.id}, name=${playlist.name}');
        return playlist;
      }

      throw Exception('获取默认标记目标收藏夹失败: ${response.statusCode}');
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('解析数据失败', e, stackTrace);
      throw Exception('解析数据失败: $e');
    }
  }

  /// 获取用户的播放列表
  Future<MyPlaylists> getMyPlaylists({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/playlist/get-playlists',
        queryParameters: {
          'page': page,
        },
      );

      if (response.statusCode == 200) {
        final myPlaylists = MyPlaylists.fromJson(response.data);
        AppLogger.info('获取播放列表成功: ${myPlaylists.playlists?.length ?? 0}个播放列表');
        return myPlaylists;
      }

      throw Exception('获取播放列表失败: ${response.statusCode}');
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('解析数据失败', e, stackTrace);
      throw Exception('解析数据失败: $e');
    }
  }

  /// 获取播放列表中的作品
  Future<WorksResponse> getPlaylistWorks({
    required String playlistId,
    int page = 1,
    int pageSize = 12,
  }) async {
    final cacheKey = 'playlistWorks-$playlistId-$page-$pageSize';
    
    if (_listCache.enabled) {
      final cached = await _listCache.get(cacheKey);
      if (cached != null) {
        return WorksResponse(
          works: (cached['works'] as List)
              .map((w) => Work.fromJson(w as Map<String, dynamic>))
              .toList(),
          pagination: Pagination.fromJson(cached['pagination'] as Map<String, dynamic>),
        );
      }
    }

    try {
      final response = await _dio.get(
        '/playlist/get-playlist-works',
        queryParameters: {
          'id': playlistId,
          'page': page,
          'pageSize': pageSize,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> works = response.data['works'] ?? [];
        final pagination = Pagination.fromJson(response.data['pagination']);

        final result = WorksResponse(
          works: works.map((work) => Work.fromJson(work)).toList(),
          pagination: pagination,
        );

        try {
          await _listCache.set(cacheKey, {
            'works': response.data['works'] ?? [],
            'pagination': response.data['pagination'] ?? {},
          });
        } catch (_) {}

        return result;
      }

      throw Exception('获取播放列表作品失败: ${response.statusCode}');
    } on DioException catch (e) {
      AppLogger.error('网络请求失败', e, e.stackTrace);
      throw Exception('网络请求失败: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error('解析数据失败', e, stackTrace);
      throw Exception('解析数据失败: $e');
    }
  }