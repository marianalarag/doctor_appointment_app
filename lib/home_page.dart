import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agendar_cita.dart';
import 'messages_page.dart';
import 'settings_page.dart';
import 'firebase_service.dart';
import 'calendario_page.dart';
import 'citas_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _service = FirebaseService();
  final user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  // Key para el RefreshIndicator
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  final List<String> especialistas = [
    'Cardiólogo',
    'Dermatólogo',
    'Ginecólogo',
    'Pediatra',
    'Psicólogo',
  ];

  // Lista de páginas disponibles
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Inicializar las páginas
    _pages = [
      _buildHomeContent(),
      const MessagesPage(),
      const CalendarioPage(),
      const SettingsPage(),
    ];
  }

  // ============================================================
  // GESTO 1: Recarga Manual (Adaptado para Chrome)
  // ============================================================
  Future<void> _recargarDatos() async {
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('✓ Datos actualizados correctamente'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0 ? _buildAppBar() : null,
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Inicio",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: "Mensajes",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "Calendario",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Configuración",
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Sistema de Citas Médicas'),
      backgroundColor: Colors.teal,
      foregroundColor: Colors.white,
      actions: [
        // ⭐ GESTO 1: Botón de recarga manual (reemplaza pull-to-refresh)
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar datos',
          onPressed: _recargarDatos,
        ),
        IconButton(
          icon: const Icon(Icons.calendar_month),
          onPressed: () {
            setState(() {
              _currentIndex = 2;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.list_alt),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CitasPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicador de recarga manual
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.teal.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh, size: 16, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'Usa el botón ',
                  style: TextStyle(fontSize: 12, color: Colors.teal),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.refresh, size: 12, color: Colors.white),
                ),
                const Text(
                  ' para actualizar',
                  style: TextStyle(fontSize: 12, color: Colors.teal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildUserHeader(),
          const SizedBox(height: 20),
          _buildActionButtons(),
          const SizedBox(height: 30),
          _buildEspecialistas(),
          const SizedBox(height: 30),
          _buildTipsRapidos(),
          const SizedBox(height: 30),
          _buildProximasCitas(),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Cargando...'),
            ],
          );
        }

        String nombre = 'Usuario';
        String? telefono;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          nombre = data['nombre'] ?? user?.email ?? 'Usuario';
          telefono = data['telefono'];
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "¡Hola, $nombre!",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'En vivo',
                        style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (telefono != null && telefono.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Tel: $telefono",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_circle),
            label: const Text("Agendar Cita"),
            onPressed: () => _abrirFormularioCita(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.medical_services),
            label: const Text("Médicos"),
            onPressed: _mostrarListaMedicos,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEspecialistas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Especialistas",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: especialistas.length,
            itemBuilder: (context, index) {
              // ⭐ GESTO 2 y 3: Click simple + botón de info (reemplazan tap y long press)
              return Card(
                margin: const EdgeInsets.only(right: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(_getIconoEspecialidad(especialistas[index]), color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text('Seleccionaste: ${especialistas[index]}'),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.teal,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getIconoEspecialidad(especialistas[index]),
                          color: Colors.teal,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          especialistas[index],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // ⭐ GESTO 3: Botón de información (reemplaza long press)
                        ElevatedButton(
                          onPressed: () => _mostrarInfoEspecialista(especialistas[index]),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 14),
                              SizedBox(width: 4),
                              Text('Info', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.touch_app, size: 14, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Click en la tarjeta para seleccionar, botón "Info" para detalles',
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarInfoEspecialista(String especialista) {
    final info = {
      'Cardiólogo': 'Especialista en enfermedades del corazón y sistema circulatorio. Trata arritmias, insuficiencia cardíaca y más.',
      'Dermatólogo': 'Experto en salud de la piel, cabello y uñas. Diagnostica y trata acné, eczema, psoriasis y más.',
      'Ginecólogo': 'Especialista en salud reproductiva femenina. Realiza exámenes preventivos y trata trastornos ginecológicos.',
      'Pediatra': 'Médico especializado en la salud infantil desde el nacimiento hasta la adolescencia.',
      'Psicólogo': 'Profesional de la salud mental y bienestar emocional. Ofrece terapia y apoyo psicológico.',
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getIconoEspecialidad(especialista), color: Colors.teal, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                especialista,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info[especialista] ?? 'Información no disponible',
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.teal, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¿Deseas agendar una cita con este especialista?',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _abrirFormularioCita();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: const Text('Agendar Cita'),
          ),
        ],
      ),
    );
  }

  IconData _getIconoEspecialidad(String especialidad) {
    switch (especialidad) {
      case 'Cardiólogo':
        return Icons.favorite;
      case 'Dermatólogo':
        return Icons.face;
      case 'Ginecólogo':
        return Icons.woman;
      case 'Pediatra':
        return Icons.child_care;
      case 'Psicólogo':
        return Icons.psychology;
      default:
        return Icons.medical_services;
    }
  }

  Widget _buildTipsRapidos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tips de Salud",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade50, Colors.teal.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.withOpacity(0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.teal, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text("Bebe al menos 8 vasos de agua al día", style: TextStyle(fontSize: 14))),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.bedtime, color: Colors.teal, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text("Duerme entre 7-9 horas diarias", style: TextStyle(fontSize: 14))),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.directions_walk, color: Colors.teal, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text("Camina al menos 30 minutos al día", style: TextStyle(fontSize: 14))),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.psychology, color: Colors.teal, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text("Practica meditación o mindfulness", style: TextStyle(fontSize: 14))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProximasCitas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Próximas Citas",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            // ⭐ Tip para botón de eliminar (reemplaza swipe)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, size: 14, color: Colors.red),
                  SizedBox(width: 4),
                  Text(
                    'Usa el menú para cancelar',
                    style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _service.obtenerProximasCitasUsuario(user!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text('Error: ${snapshot.error}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        "No tienes citas próximas",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Agenda tu primera cita usando el botón 'Agendar Cita'",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final citas = snapshot.data!;

            return Column(
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: citas.length > 3 ? 3 : citas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final cita = citas[index];
                    final fecha = (cita['fecha'] as Timestamp).toDate();
                    final docId = cita['doc_id'] as String;

                    // ⭐ GESTO 4: Botón de eliminar (reemplaza Dismissible/swipe)
                    return _buildCitaCard(cita, fecha, docId);
                  },
                ),
                if (citas.length > 3) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CitasPage()),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text('Ver todas las citas (${citas.length})'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.teal,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCitaCard(Map<String, dynamic> cita, DateTime fecha, String docId) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade300, Colors.teal.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.medical_services,
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Text(
          "Dr. ${cita['id_medico']}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatearFecha(fecha),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  cita['hora'],
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Motivo: ${cita['motivo']}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Chip(
              label: Text(
                cita['estado'] ?? 'pendiente',
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: _getColorEstado(cita['estado']),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _manejarAccionCita(value, docId, cita),
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 18, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('Ver Detalles'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Cancelar Cita'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorEstado(String? estado) {
    switch (estado) {
      case 'confirmada':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatearFecha(DateTime fecha) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }

  void _manejarAccionCita(String accion, String docId, Map<String, dynamic> cita) async {
    switch (accion) {
      case 'edit':
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AgendarCitaPage(docId: docId)),
        );
        if (changed == true) setState(() {});
        break;

      case 'view':
        _mostrarDetallesCita(cita);
        break;

      case 'delete':
        await _confirmarEliminacionCita(docId);
        break;
    }
  }

  void _mostrarDetallesCita(Map<String, dynamic> cita) {
    final fecha = (cita['fecha'] as Timestamp).toDate();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.medical_services, color: Colors.teal),
            ),
            const SizedBox(width: 12),
            const Text('Detalles de la Cita'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetalleItem(Icons.person, 'Médico', 'Dr. ${cita['id_medico']}'),
            const Divider(height: 20),
            _buildDetalleItem(Icons.calendar_today, 'Fecha', _formatearFecha(fecha)),
            const Divider(height: 20),
            _buildDetalleItem(Icons.access_time, 'Hora', cita['hora']),
            const Divider(height: 20),
            _buildDetalleItem(Icons.description, 'Motivo', cita['motivo']),
            const Divider(height: 20),
            _buildDetalleItem(Icons.info, 'Estado', cita['estado'] ?? 'pendiente'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.teal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmarEliminacionCita(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Confirmar Cancelación'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que quieres cancelar esta cita?'),
            SizedBox(height: 12),
            Text(
              'Esta acción no se puede deshacer.',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, mantener'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sí, cancelar cita'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _service.eliminarCita(docId: docId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Cita cancelada exitosamente'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error: $e')),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }
    return false;
  }

  void _abrirFormularioCita() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgendarCitaPage()),
    );
    if (created == true) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Cita agendada exitosamente'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _mostrarListaMedicos() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.medical_services, color: Colors.teal),
            SizedBox(width: 12),
            Text('Especialistas Disponibles'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: especialistas.length,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconoEspecialidad(especialistas[index]),
                      color: Colors.teal,
                    ),
                  ),
                  title: Text(
                    especialistas[index],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Disponible para consulta',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarInfoEspecialista(especialistas[index]);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}