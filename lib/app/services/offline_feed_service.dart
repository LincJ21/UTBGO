import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../video_model.dart';
import 'global_ui_service.dart';

/// Servicio responsable de cachear el feed para soporte offline.
class OfflineFeedService {
  static const String _feedCacheKey = 'offline_feed_cache';

  /// Guarda una copia del Feed actual en disco (SharedPreferences).
  /// Esto se hace asíncronamente en segundo plano.
  static Future<void> saveFeed(List<VideoModel> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convertir la lista de objetos a una lista de diccionarios JSON
      final List<Map<String, dynamic>> jsonList = 
          videos.map((v) => v.toJson()).toList();
          
      // Serializar a String y guardar
      final String jsonString = jsonEncode(jsonList);
      await prefs.setString(_feedCacheKey, jsonString);
      debugPrint('OfflineFeedService: Guardado exitoso en caché local (${videos.length} videos).');
    } catch (e) {
      debugPrint('OfflineFeedService Error al guardar: $e');
      GlobalUIService.showError('Error guardando caché: $e');
    }
  }

  /// Recupera el feed guardado cuando no hay conexión a internet.
  static Future<List<VideoModel>> getCachedFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_feedCacheKey);
      
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(jsonString);
        
        // El constructor fromJson ya espera el formato que definimos en toJson()
        final List<VideoModel> cachedVideos = decodedList
            .map((item) => VideoModel.fromJson(item as Map<String, dynamic>))
            .toList();
            
        debugPrint('OfflineFeedService: Recuperados ${cachedVideos.length} videos de caché local.');
        return cachedVideos;
      }
    } catch (e) {
      debugPrint('OfflineFeedService Error al leer caché: $e');
      GlobalUIService.showError('Error leyendo caché: $e');
    }
    
    return [];
  }
}
