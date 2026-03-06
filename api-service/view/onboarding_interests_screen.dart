import 'package:flutter/material.dart';

class OnboardingInterestsScreen extends StatefulWidget {
  final VoidCallback? onFinish;

  const OnboardingInterestsScreen({super.key, this.onFinish});

  @override
  State<OnboardingInterestsScreen> createState() =>
      _OnboardingInterestsScreenState();
}

class _OnboardingInterestsScreenState extends State<OnboardingInterestsScreen> {
  // Estado para mantener los temas seleccionados
  final Set<String> _selectedTopics = {};

  final List<Map<String, dynamic>> _topics = [
    {
      'id': 'matematicas',
      'label': 'Matemáticas',
      'icon': Icons.calculate_outlined,
      'color': const Color(0xFFE8F5E9), // Verde muy claro
      'iconColor': const Color(0xFF4CAF50), // Verde
    },
    {
      'id': 'logica',
      'label': 'Lógica',
      'icon': Icons.psychology_outlined,
      'color': const Color(0xFFE3F2FD), // Azul muy claro
      'iconColor': const Color(0xFF2196F3), // Azul
    },
    {
      'id': 'ingles',
      'label': 'Inglés',
      'icon': Icons.language_outlined,
      'color': const Color(0xFFFFEBEE), // Rojo muy claro
      'iconColor': const Color(0xFFF44336), // Rojo
    },
    {
      'id': 'programacion',
      'label': 'Programación',
      'icon': Icons.code_outlined,
      'color': const Color(0xFFF3E5F5), // Morado muy claro
      'iconColor': const Color(0xFF9C27B0), // Morado
    },
    {
      'id': 'fisica',
      'label': 'Física',
      'icon': Icons.science_outlined,
      'color': const Color(0xFFFFF8E1), // Amarillo muy claro
      'iconColor': const Color(0xFFFFB300), // Amarillo/Naranja
    },
    {
      'id': 'quimica',
      'label': 'Química',
      'icon': Icons.biotech_outlined,
      'color': const Color(0xFFE0F7FA), // Cian muy claro
      'iconColor': const Color(0xFF00BCD4), // Cian
    },
    {
      'id': 'historia',
      'label': 'Historia',
      'icon': Icons.menu_book_outlined,
      'color': const Color(0xFFFBE9E7), // Naranja profundo claro
      'iconColor': const Color(0xFFFF5722), // Naranja profundo
    },
    {
      'id': 'arte',
      'label': 'Arte',
      'icon': Icons.palette_outlined,
      'color': const Color(0xFFE8EAF6), // Indigo claro
      'iconColor': const Color(0xFF3F51B5), // Indigo
    },
  ];

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedTopics.contains(id)) {
        _selectedTopics.remove(id);
      } else {
        _selectedTopics.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canContinue = _selectedTopics.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Fondo gris ultra claro (hueso)
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Barra superior: Paso y botón Omitir
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PASO 1 DE 3',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Color(0xFF003399)),
                      ),
                      const SizedBox(height: 6),
                      // Barra de progreso estilizada
                      Row(
                        children: [
                          Container(
                            height: 4,
                            width: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50), // Verde brillante del mockup
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            height: 4,
                            width: 30,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            height: 4,
                            width: 30,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      if (widget.onFinish != null) {
                        widget.onFinish!(); // Resume MainNavigationPage flow
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                    ),
                    child: const Text(
                      'Omitir',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Título y Subtítulo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Qué quieres\naprender hoy?',
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.1, // Line height ajustado para que encaje como en la imagen
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF001A40), // Azul ultramarino oscuro similar al del screenshot
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Selecciona tus áreas de interés para personalizar tu feed con el mejor contenido de la UTB.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Barra de búsqueda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    icon: Icon(Icons.search, color: Colors.grey.shade500),
                    hintText: 'Buscar temas (ej. Matemáticas)...',
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Grid de temas (Expanded para permitir scroll)
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.95, // Más cuadrado que rectangular
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: _topics.length,
                itemBuilder: (context, index) {
                  final topic = _topics[index];
                  final isSelected = _selectedTopics.contains(topic['id']);

                  return GestureDetector(
                    onTap: () => _toggleSelection(topic['id']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF4CAF50)
                              : Colors.transparent, // Verde si está seleccionado
                          width: 2,
                        ),
                        boxShadow: [
                          if (!isSelected) // Solo sombra si NO está seleccionado (da un look cleaner al seleccionar)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                        ],
                      ),
                      child: Stack(
                        children: [
                          // 6. Contenido central de la tarjeta (Icono + Texto)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Círculo de fondo para el icono
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: topic['color'],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    topic['icon'],
                                    color: topic['iconColor'],
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  topic['label'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          
                          // 5. Checkmark en la parte superior derecha si está seleccionado
                          if (isSelected)
                            const Positioned(
                              top: -8,
                              right: -8,
                              child: Icon(
                                Icons.check_circle,
                                color: Color(0xFF4CAF50),
                                size: 24,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // 7. Botón "Continuar" fijo en la parte inferior
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white, // Fondo blanco para la barra inferior
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ocupa solo el espacio de sus hijos
          children: [
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedTopics.length} seleccionados',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600),
                  ),
                  Text(
                    'Mínimo 1',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canContinue
                    ? () {
                        if (widget.onFinish != null) {
                          widget.onFinish!(); // Resume MainNavigationPage flow
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001F4E), // Azul súper oscuro (Casi negro)
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: canContinue ? Colors.white : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: canContinue ? Colors.white : Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
