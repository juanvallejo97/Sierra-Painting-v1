import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for managing offline-first functionality
/// Uses Hive for local storage and monitors network connectivity
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  Box? _cacheBox;
  bool _isOnline = true;
  final Connectivity _connectivity = Connectivity();

  /// Initialize Hive and set up connectivity monitoring
  static Future<void> initialize() async {
    final instance = OfflineService();
    await Hive.initFlutter();

    // Open cache box
    instance._cacheBox = await Hive.openBox('offline_cache');

    // Check initial connectivity
    final connectivityResult = await instance._connectivity.checkConnectivity();
    instance._isOnline = connectivityResult != ConnectivityResult.none;

    // Listen to connectivity changes
    instance._connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      instance._isOnline = results.any(
        (result) => result != ConnectivityResult.none,
      );
    });
  }

  /// Check if the device is online
  bool get isOnline => _isOnline;

  /// Check if the device is offline
  bool get isOffline => !_isOnline;

  /// Save data to local cache
  Future<void> saveToCache(String key, dynamic value) async {
    if (_cacheBox == null) return;
    await _cacheBox!.put(key, value);
  }

  /// Get data from local cache
  T? getFromCache<T>(String key) {
    if (_cacheBox == null) return null;
    return _cacheBox!.get(key) as T?;
  }

  /// Remove data from local cache
  Future<void> removeFromCache(String key) async {
    if (_cacheBox == null) return;
    await _cacheBox!.delete(key);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    if (_cacheBox == null) return;
    await _cacheBox!.clear();
  }

  /// Check if a key exists in cache
  bool hasKey(String key) {
    if (_cacheBox == null) return false;
    return _cacheBox!.containsKey(key);
  }

  /// Get all keys from cache
  Iterable<dynamic> get allKeys {
    if (_cacheBox == null) return [];
    return _cacheBox!.keys;
  }

  /// Get all values from cache
  Iterable<dynamic> get allValues {
    if (_cacheBox == null) return [];
    return _cacheBox!.values;
  }

  /// Save pending sync operation
  Future<void> addPendingSync(
    String operation,
    Map<String, dynamic> data,
  ) async {
    if (_cacheBox == null) return;

    final pendingSyncs = getFromCache<List>('pending_syncs') ?? [];
    pendingSyncs.add({
      'operation': operation,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await saveToCache('pending_syncs', pendingSyncs);
  }

  /// Get all pending sync operations
  List<dynamic> getPendingSyncs() {
    return getFromCache<List>('pending_syncs') ?? [];
  }

  /// Clear pending sync operations
  Future<void> clearPendingSyncs() async {
    await removeFromCache('pending_syncs');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _cacheBox?.close();
  }
}
