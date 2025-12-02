import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ESTADOS
abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final int totalCitas;
  final int citasPendientes;
  final int totalPacientes;
  final String medicoNombre;
  final List<Map<String, dynamic>> proximasCitas;
  final int citasHoy;
  final int citasSemana;

  DashboardLoaded({
    required this.totalCitas,
    required this.citasPendientes,
    required this.totalPacientes,
    required this.medicoNombre,
    required this.proximasCitas,
    required this.citasHoy,
    required this.citasSemana,
  });
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}

// EVENTOS
abstract class DashboardEvent {}

class LoadDashboardData extends DashboardEvent {}

class RefreshDashboardData extends DashboardEvent {}

// BLoC
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DashboardBloc() : super(DashboardInitial()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<RefreshDashboardData>(_onRefreshDashboardData);
  }

  Future<void> _onLoadDashboardData(
      LoadDashboardData event,
      Emitter<DashboardState> emit,
      ) async {
    await _loadDashboardDataReal(emit);
  }

  Future<void> _onRefreshDashboardData(
      RefreshDashboardData event,
      Emitter<DashboardState> emit,
      ) async {
    await _loadDashboardDataReal(emit);
  }

  Future<void> _loadDashboardDataReal(
      Emitter<DashboardState> emit,
      ) async {
    emit(DashboardLoading());

    try {
      final user = _auth.currentUser;
      if (user == null) {
        emit(DashboardError('Usuario no autenticado'));
        return;
      }

      // 1. Obtener información del médico
      final userDoc = await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>?;
      final medicoNombre = userData?['nombre'] ?? 'Dr. ' + (user.email?.split('@').first ?? 'Médico');

      print('Cargando datos para médico: $medicoNombre');

      // 2. Obtener TODAS las citas del médico usando el campo correcto
      final citasSnapshot = await _firestore
          .collection('citas')
          .where('id_medico', isEqualTo: user.uid)
          .get();

      final todasLasCitas = citasSnapshot.docs;
      print('Total de citas encontradas: ${todasLasCitas.length}');

      // 3. Calcular métricas en memoria
      final ahora = DateTime.now();
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);

      // Métricas básicas
      final totalCitas = todasLasCitas.length;

      // Citas pendientes (estado 'pendiente' y fecha futura)
      final citasPendientes = todasLasCitas
          .where((doc) {
        final data = doc.data();
        final estado = data['estado'] as String? ?? 'pendiente';
        final fechaField = data['fecha_hora'] ?? data['fecha'];

        if (fechaField is Timestamp) {
          final fechaCita = fechaField.toDate();
          return estado == 'pendiente' && fechaCita.isAfter(ahora);
        }
        return false;
      })
          .length;

      // Pacientes únicos - usando el campo correcto 'id_paciente'
      final pacientesIds = todasLasCitas
          .map((doc) => doc.data()['id_paciente'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final totalPacientes = pacientesIds.length;

      // Próximas citas (5 más próximas) - CORREGIDO
      final List<Map<String, dynamic>> proximasCitas = _obtenerProximasCitas(todasLasCitas, ahora);

      // Citas de hoy - CORREGIDO
      final citasHoy = _contarCitasHoy(todasLasCitas, hoy);

      // Citas de esta semana - CORREGIDO
      final citasSemana = _contarCitasSemana(todasLasCitas, hoy);

      print('''
Datos calculados:
- Total citas: $totalCitas
- Citas pendientes: $citasPendientes
- Total pacientes: $totalPacientes
- Citas hoy: $citasHoy
- Citas semana: $citasSemana
- Próximas citas: ${proximasCitas.length}
      ''');

      emit(
        DashboardLoaded(
          totalCitas: totalCitas,
          citasPendientes: citasPendientes,
          totalPacientes: totalPacientes,
          medicoNombre: medicoNombre,
          proximasCitas: proximasCitas,
          citasHoy: citasHoy,
          citasSemana: citasSemana,
        ),
      );
    } catch (e) {
      print('Error en DashboardBloc: $e');
      emit(DashboardError('Error al cargar datos del dashboard: $e'));
    }
  }

  // MÉTODO CORREGIDO para obtener próximas citas
  List<Map<String, dynamic>> _obtenerProximasCitas(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> todasLasCitas,
      DateTime ahora) {

    // Filtrar y ordenar citas pendientes futuras
    final citasFuturas = todasLasCitas
        .where((doc) {
      final data = doc.data();
      final estado = data['estado'] as String? ?? 'pendiente';
      final fechaField = data['fecha_hora'] ?? data['fecha'];

      if (fechaField is Timestamp) {
        final fechaCita = fechaField.toDate();
        return estado == 'pendiente' && fechaCita.isAfter(ahora);
      }
      return false;
    })
        .toList();

    // Ordenar por fecha
    citasFuturas.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();
      final fechaA = (dataA['fecha_hora'] ?? dataA['fecha']) as Timestamp;
      final fechaB = (dataB['fecha_hora'] ?? dataB['fecha']) as Timestamp;
      return fechaA.compareTo(fechaB);
    });

    // Convertir a List<Map<String, dynamic>>
    return citasFuturas
        .take(5)
        .map((doc) {
      final data = doc.data();
      final fechaField = data['fecha_hora'] ?? data['fecha'];
      final fechaCita = (fechaField as Timestamp).toDate();

      return {
        'doc_id': doc.id,
        'id_paciente': data['id_paciente'],
        'nombre_paciente': data['nombre_paciente'] ?? 'Paciente',
        'motivo': data['motivo'] ?? 'Consulta',
        'fecha': fechaCita,
        'hora': data['hora'] ?? '--:--',
        'estado': data['estado'] ?? 'pendiente',
      };
    })
        .toList();
  }

  // MÉTODO CORREGIDO para contar citas de hoy
  int _contarCitasHoy(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> todasLasCitas,
      DateTime hoy) {

    return todasLasCitas.where((doc) {
      final data = doc.data();
      final fechaField = data['fecha_hora'] ?? data['fecha'];

      if (fechaField is Timestamp) {
        final fechaCita = fechaField.toDate();
        final fechaCitaDia = DateTime(fechaCita.year, fechaCita.month, fechaCita.day);
        return fechaCitaDia == hoy;
      }
      return false;
    }).length;
  }

  // MÉTODO CORREGIDO para contar citas de la semana
  int _contarCitasSemana(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> todasLasCitas,
      DateTime hoy) {

    final startOfWeek = hoy.subtract(Duration(days: hoy.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return todasLasCitas.where((doc) {
      final data = doc.data();
      final fechaField = data['fecha_hora'] ?? data['fecha'];

      if (fechaField is Timestamp) {
        final fechaCita = fechaField.toDate();
        final fechaCitaDia = DateTime(fechaCita.year, fechaCita.month, fechaCita.day);
        return fechaCitaDia.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            fechaCitaDia.isBefore(endOfWeek.add(const Duration(days: 1)));
      }
      return false;
    }).length;
  }

  // Método auxiliar para formatear fecha
  String _formatearFecha(DateTime fecha) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }
}