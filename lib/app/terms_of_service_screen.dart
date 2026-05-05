import 'package:flutter/material.dart';

/// Pantalla estática de Términos y Condiciones de Uso.
/// Requerida por Google Play Store y Apple App Store.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          'Términos y Condiciones',
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
                colors: [Color(0xFF003399), Color(0xFF1E88E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description, color: Colors.white, size: 36),
                SizedBox(height: 12),
                Text(
                  'Términos y Condiciones de Uso',
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
            icon: Icons.handshake_outlined,
            title: '1. Aceptación de Términos',
            content: '''Al registrarte y usar UTBGO, aceptas estos Términos y Condiciones en su totalidad. Si no estás de acuerdo, no debes usar la plataforma.

UTBGO es una plataforma de microlearning académico desarrollada por y para la comunidad de la Universidad Tecnológica de Bolívar.''',
          ),

          _buildSection(
            icon: Icons.person_outline,
            title: '2. Registro y Cuenta',
            content: '''• Debes usar una cuenta válida de Google o Microsoft asociada a la UTB.
• Eres responsable de mantener la seguridad de tu cuenta.
• La información de tu perfil debe ser veraz y actualizada.
• Cada persona puede tener una sola cuenta activa.
• Nos reservamos el derecho de suspender cuentas que violen estos términos.''',
          ),

          _buildSection(
            icon: Icons.video_library_outlined,
            title: '3. Contenido del Usuario',
            content: '''Al publicar contenido en UTBGO:

• **Propiedad:** Conservas los derechos de autor de tu contenido original.
• **Licencia:** Nos otorgas una licencia no exclusiva para mostrar, distribuir y almacenar tu contenido dentro de la plataforma.
• **Responsabilidad:** Eres el único responsable del contenido que publicas.
• **Contenido prohibido:** No se permite contenido ofensivo, discriminatorio, con derechos de autor de terceros, spam, o contenido no relacionado con fines académicos.''',
          ),

          _buildSection(
            icon: Icons.gavel,
            title: '4. Conducta del Usuario',
            content: '''Los usuarios de UTBGO deben:

• Respetar a otros miembros de la comunidad.
• No realizar acoso, bullying o intimidación.
• No intentar acceder a cuentas ajenas.
• No usar la plataforma para actividades ilegales.
• No interferir con el funcionamiento técnico de la plataforma.
• Respetar las normas de la Universidad Tecnológica de Bolívar.''',
          ),

          _buildSection(
            icon: Icons.admin_panel_settings_outlined,
            title: '5. Moderación y Sanciones',
            content: '''El equipo de UTBGO se reserva el derecho de:

• Eliminar contenido que viole estos términos.
• Suspender o eliminar cuentas de usuarios reincidentes.
• Modificar o restringir funcionalidades sin previo aviso.
• Tomar acciones según la gravedad de la infracción (advertencia, suspensión temporal, suspensión permanente).''',
          ),

          _buildSection(
            icon: Icons.copyright,
            title: '6. Propiedad Intelectual',
            content: '''• La marca UTBGO, su logotipo, diseño y código fuente son propiedad de sus desarrolladores.
• Los materiales educativos publicados por profesores están protegidos por derechos de autor.
• El uso indebido o la copia no autorizada de contenidos será sancionado.''',
          ),

          _buildSection(
            icon: Icons.warning_amber_outlined,
            title: '7. Limitación de Responsabilidad',
            content: '''UTBGO se proporciona "tal cual". No garantizamos:

• Disponibilidad ininterrumpida del servicio.
• Que el contenido publicado por usuarios sea preciso o completo.
• Que la plataforma esté libre de errores técnicos.

No nos hacemos responsables por daños indirectos derivados del uso de la plataforma.''',
          ),

          _buildSection(
            icon: Icons.update,
            title: '8. Modificaciones',
            content: '''Nos reservamos el derecho de modificar estos términos en cualquier momento. Los cambios significativos serán notificados a través de la aplicación. El uso continuado después de las modificaciones implica la aceptación de los nuevos términos.''',
          ),

          _buildSection(
            icon: Icons.balance,
            title: '9. Ley Aplicable',
            content: '''Estos términos se rigen por las leyes de la República de Colombia. Cualquier disputa será resuelta ante los tribunales competentes de la ciudad de Cartagena de Indias, Bolívar, Colombia.''',
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
                const Icon(Icons.contact_support_outlined, color: _utbBlue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¿Necesitas ayuda?',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        'soporte@utb.edu.co',
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
