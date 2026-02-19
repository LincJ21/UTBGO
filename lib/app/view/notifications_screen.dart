import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5, // Sutil elevación para separar
        centerTitle: true,
        // --- FLECHA DE REGRESO ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Devuelve al panel principal (UTB)
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView.separated(
        itemCount: 5, // Ejemplo de notificaciones
        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
        itemBuilder: (context, index) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              child: const Icon(Icons.notifications_none, color: Colors.black87),
            ),
            title: Text(
              'Notificación de prueba ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('Hace un momento'),
            onTap: () {},
          );
        },
      ),
    );
  }
}