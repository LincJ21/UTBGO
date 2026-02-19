class ApiConstants {
  // --- CONTROL DE DISPOSITIVO ---
  // Pon 'true' para usar el Emulador (10.0.2.2).
  // Pon 'false' para usar tu Celular Físico (IP Local).
  static const bool isEmulator = true;

  // Tu IP local (para cuando usas el celular físico)
  static const String _localIp = "192.168.1.75";

  // ---------------------
  static const String _emulatorIp = "10.0.2.2";

  static const String host = isEmulator ? _emulatorIp : _localIp;
  static const String baseUrl = "http://$host:8080";
  static const String apiUrl = "$baseUrl/api";
}