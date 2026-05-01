import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_practica/app/login_screen.dart';

void main() {
  testWidgets('LoginScreen interactividad y validaciones (Test Deterministico UI)', (WidgetTester tester) async {
    // 1. Arrange: Construir la UI aislando la pantalla de Login
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onLoginSuccess: () {}, // Callback vacío, no navegaremos a ningún lado real
        ),
      ),
    );

    // 2. Assert (Estado Inicial): Verificar que arranca en modo "Iniciar Sesión"
    expect(find.text('Bienvenido a UTBGo'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsWidgets);
    expect(find.text('Crear Cuenta'), findsNothing);
    
    // Verificar que los campos de "Nombre" y "Apellido" NO están en pantalla
    expect(find.text('Nombre'), findsNothing);
    expect(find.text('Apellido'), findsNothing);

    // 3. Act: Tocar el botón de "¿No tienes cuenta? Regístrate"
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle(); // Esperar animaciones/rebuilds

    // 4. Assert (Estado de Registro): Verificar que cambió el UI
    expect(find.text('Crear Cuenta'), findsWidgets);
    expect(find.text('Regístrate para comenzar'), findsOneWidget);
    
    // Los campos de "Nombre" y "Apellido" deben haber aparecido
    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Apellido'), findsOneWidget);

    // 5. Act: Tocar el botón "Crear Cuenta" con campos vacíos
    // Nota: Como 'Crear Cuenta' es tanto el título como el texto del botón, buscamos el Elevated Button.
    final createAccountButton = find.widgetWithText(ElevatedButton, 'Crear Cuenta');
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    // 6. Assert (Validación OWASP del cliente): Verificar que el validador del Form arroja advertencias
    expect(find.text('Ingresa tu nombre'), findsOneWidget);
    expect(find.text('Ingresa tu apellido'), findsOneWidget);
    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });
}
