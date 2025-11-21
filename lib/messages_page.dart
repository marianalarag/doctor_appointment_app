import 'package:flutter/material.dart';
import 'doctor_home_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  // Lista local de mensajes (placeholders)
  final List<Map<String, String>> mensajes = [
    {
      "remitente": "Dr. Ramírez",
      "hora": "10:45 AM",
      "mensaje": "Hola, recuerda tu cita mañana temprano.",
    },
    {
      "remitente": "Clínica Central",
      "hora": "9:12 AM",
      "mensaje": "Tus resultados están disponibles.",
    },
    {
      "remitente": "Nutrióloga Pérez",
      "hora": "Ayer",
      "mensaje": "No olvides enviar tu registro semanal.",
    },
    {
      "remitente": "Dr. González",
      "hora": "Lunes",
      "mensaje": "Tu tratamiento está dando buenos resultados.",
    },
    {
      "remitente": "Administración",
      "hora": "28 Oct",
      "mensaje": "Confirmación de pago recibido.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mensajes',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: mensajes.isEmpty
          ? Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade50,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 60,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sistema de Mensajes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Próximamente podrás comunicarte directamente con tu médico y recibir notificaciones importantes sobre tus citas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Esta función estará disponible en la próxima actualización',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade50,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: ListView.builder(
          itemCount: mensajes.length,
          itemBuilder: (context, index) {
            final mensaje = mensajes[index];

            return Container(
              margin: const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: Colors.teal,
                  ),
                ),
                title: Text(
                  mensaje["remitente"]!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  mensaje["mensaje"]!,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  mensaje["hora"]!,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                // Gestor para abrir detalles del mensaje
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        mensaje["remitente"]!,
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      content: Text(
                        mensaje["mensaje"]!,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Cerrar",
                            style: TextStyle(color: Colors.teal),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // Aquí podrías agregar funcionalidad de responder
                          },
                          child: const Text(
                            "Responder",
                            style: TextStyle(color: Colors.teal),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      // Botón para simular agregar un mensaje nuevo
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () {
          setState(() {
            mensajes.insert(0, {
              "remitente": "Sistema Médico",
              "hora": "Ahora",
              "mensaje":
              "Nuevo mensaje automático de prueba. Esta es una simulación de la funcionalidad de mensajería en desarrollo.",
            });
          });

          // Mostrar snackbar de confirmación
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text(
                'Nuevo mensaje recibido',
                style: TextStyle(color: Colors.white),
              ),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          );
        },
      ),
    );
  }
}