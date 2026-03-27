import 'package:flutter/material.dart';

/// Pantalla estática de Política de Privacidad.
/// Requerida por Google Play Store y Apple App Store.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _utbBlue = Color(0xFF003399);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Política de Privacidad',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF001F60), Color(0xFF003399)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield, color: Colors.white, size: 36),
                SizedBox(height: 12),
                Text(
                  'Tu privacidad es nuestra prioridad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Última actualización: Marzo 2026',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSection(
            icon: Icons.info_outline,
            title: '1. Información que Recopilamos',
            content: '''Al usar UTBGO, recopilamos la siguiente información:

• **Datos de cuenta:** Nombre, correo electrónico institucional y foto de perfil proporcionados mediante Google o Microsoft Entra ID.
• **Contenido generado:** Videos, comentarios, likes y bookmarks que publiques.
• **Datos de uso:** Información sobre cómo interactúas con la plataforma (videos vistos, tiempo de visualización, búsquedas).
• **Datos del dispositivo:** Tipo de dispositivo, sistema operativo y versión de la aplicación.''',
          ),

          _buildSection(
            icon: Icons.lock_outline,
            title: '2. Uso de la Información',
            content: '''Utilizamos tu información para:

• Proporcionar, mantener y mejorar los servicios de UTBGO.
• Personalizar tu experiencia y recomendaciones de contenido.
• Verificar tu identidad como miembro de la comunidad UTB.
• Enviar notificaciones relevantes sobre actividades académicas.
• Garantizar la seguridad de la plataforma y prevenir el uso indebido.''',
          ),

          _buildSection(
            icon: Icons.share_outlined,
            title: '3. Compartir Información',
            content: '''No vendemos tus datos personales. Compartimos información únicamente en los siguientes casos:

• **Con tu consentimiento:** Cuando autorizas explícitamente compartir datos.
• **Dentro de la comunidad UTB:** Tu nombre de usuario y contenido público son visibles para otros usuarios.
• **Proveedores de servicio:** Utilizamos servicios de terceros (almacenamiento en la nube, análisis) que procesan datos bajo estrictos acuerdos de confidencialidad.
• **Requisitos legales:** Cuando sea necesario para cumplir con la ley colombiana.''',
          ),

          _buildSection(
            icon: Icons.security,
            title: '4. Seguridad de los Datos',
            content: '''Implementamos medidas de seguridad que incluyen:

• Cifrado SSL/TLS para todas las comunicaciones.
• Tokens JWT con expiración temporal para autenticación.
• Almacenamiento seguro de contraseñas con bcrypt.
• Acceso restringido a la base de datos con Connection Pooling.
• Auditorías periódicas de seguridad.''',
          ),

          _buildSection(
            icon: Icons.person_outline,
            title: '5. Tus Derechos',
            content: '''De conformidad con la Ley 1581 de 2012 (Ley de Protección de Datos Personales de Colombia), tienes derecho a:

• **Acceder** a tus datos personales almacenados.
• **Rectificar** información incorrecta o desactualizada.
• **Eliminar** tu cuenta y datos asociados.
• **Revocar** el consentimiento para el tratamiento de datos.

Para ejercer estos derechos, contáctanos a través de la sección de Configuración.''',
          ),

          _buildSection(
            icon: Icons.child_care,
            title: '6. Menores de Edad',
            content: '''UTBGO es una plataforma educativa universitaria. No está diseñada para personas menores de 16 años. Si detectamos cuentas de menores, procederemos a su eliminación.''',
          ),

          _buildSection(
            icon: Icons.update,
            title: '7. Cambios en esta Política',
            content: '''Podemos actualizar esta política periódicamente. Te notificaremos sobre cambios significativos a través de la aplicación. El uso continuado de UTBGO después de los cambios constituye la aceptación de la política actualizada.''',
          ),

          const SizedBox(height: 24),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, color: _utbBlue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¿Preguntas sobre privacidad?',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        'privacidad@utb.edu.co',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _utbBlue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
