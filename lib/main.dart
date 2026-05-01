import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Intentar inicializar Firebase con un timeout de 10 segundos
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    print("Firebase inicializado correctamente");
  } catch (e) {
    print("Error al inicializar Firebase: $e");
    // Continuar de todos modos para que la app no se quede cargando infinitamente
  }
  runApp(const MyApp());
}




