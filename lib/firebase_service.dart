// firebase_service.dart - VERSIÓN SIMPLIFICADA Y FUNCIONAL
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== CREAR CITA (VERSIÓN SIMPLIFICADA) ==========
  Future<String> crearCita({
    required String idMedico,
    required DateTime fechaHora,
    required String motivo,
    required String nombrePaciente,
    required String nombreMedico,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Crear la cita directamente sin validar disponibilidad
        final docRef = await _firestore.collection('citas').add({
          'id_paciente': user.uid,
          'id_medico': idMedico,
          'nombre_medico': nombreMedico,
          'nombre_paciente': nombrePaciente,
          'motivo': motivo,
          'fecha': Timestamp.fromDate(fechaHora),
          'hora': '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}',
          'estado': 'pendiente',
          'created_at': FieldValue.serverTimestamp(),
        });

        return docRef.id;
      } catch (e) {
        print('Error creando cita: $e');
        throw Exception('Error al crear la cita: $e');
      }
    }
    throw Exception('Usuario no autenticado');
  }

  // ========== ACTUALIZAR CITA (VERSIÓN SIMPLIFICADA) ==========
  Future<void> actualizarCita({
    required String docId,
    required DateTime fechaHora,
    required String motivo,
    required String idMedico,
    required String nombreMedico,
  }) async {
    try {
      await _firestore.collection('citas').doc(docId).update({
        'fecha': Timestamp.fromDate(fechaHora),
        'motivo': motivo,
        'id_medico': idMedico,
        'nombre_medico': nombreMedico,
        'hora': '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error actualizando cita: $e');
      throw Exception('Error al actualizar la cita: $e');
    }
  }

  // ========== ELIMINAR CITA ==========
  Future<void> eliminarCita({required String docId}) async {
    try {
      await _firestore.collection('citas').doc(docId).delete();
    } catch (e) {
      print('Error eliminando cita: $e');
      throw Exception('Error al eliminar la cita: $e');
    }
  }

  // ========== MÉTODOS DE CONSULTA ==========

  // Obtener próximas citas del usuario
  Stream<List<Map<String, dynamic>>> obtenerProximasCitasUsuario(String uid) {
    return _firestore
        .collection('citas')
        .where('id_paciente', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final ahora = DateTime.now();
      final citasFuturas = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data != null) {
          final Map<String, dynamic> citaData;
          if (data is Map<String, dynamic>) {
            citaData = Map<String, dynamic>.from(data);
          } else {
            citaData = Map<String, dynamic>.from(data as Map);
          }

          final fecha = citaData['fecha'];
          if (fecha is Timestamp) {
            final fechaCita = fecha.toDate();
            if (fechaCita.isAfter(ahora)) {
              citaData['doc_id'] = doc.id;
              citasFuturas.add(citaData);
            }
          }
        }
      }

      citasFuturas.sort((a, b) {
        final fechaA = a['fecha'] as Timestamp;
        final fechaB = b['fecha'] as Timestamp;
        return fechaA.compareTo(fechaB);
      });

      return citasFuturas;
    });
  }

  // Obtener todas las citas del usuario (Stream)
  Stream<QuerySnapshot> obtenerCitasDelUsuarioStream(String uid) {
    return _firestore
        .collection('citas')
        .where('id_paciente', isEqualTo: uid)
        .orderBy('fecha')
        .snapshots();
  }

  // Obtener todas las citas del sistema
  Stream<QuerySnapshot> obtenerTodasLasCitas() {
    return _firestore
        .collection('citas')
        .orderBy('fecha')
        .snapshots();
  }

  // Obtener cita por ID
  Future<Map<String, dynamic>?> obtenerCitaPorId(String docId) async {
    try {
      final doc = await _firestore.collection('citas').doc(docId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final Map<String, dynamic> dataMap;
          if (data is Map<String, dynamic>) {
            dataMap = Map<String, dynamic>.from(data);
          } else {
            dataMap = Map<String, dynamic>.from(data as Map);
          }
          dataMap['doc_id'] = doc.id;
          return dataMap;
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo cita por ID: $e');
      return null;
    }
  }

  // Obtener usuario actual
  Future<Map<String, dynamic>?> obtenerUsuarioActual() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('usuarios').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            return data is Map<String, dynamic>
                ? Map<String, dynamic>.from(data)
                : Map<String, dynamic>.from(data as Map);
          }
        }

        // Si no existe el documento de usuario, crear uno básico
        final userData = {
          'nombre': user.email?.split('@').first ?? 'Usuario',
          'email': user.email ?? '',
          'telefono': '',
          'historial_medico': '',
          'uid': user.uid,
          'created_at': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('usuarios').doc(user.uid).set(userData);
        return userData;
      }
      return null;
    } catch (e) {
      print('Error obteniendo usuario actual: $e');
      return null;
    }
  }

  // ========== MÉTODOS ADICIONALES ==========

  // Crear usuario
  Future<void> crearUsuario({
    required String nombre,
    required String email,
    String telefono = '',
    String historialMedico = '',
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('usuarios').doc(user.uid).set({
        'nombre': nombre,
        'email': email,
        'telefono': telefono,
        'historial_medico': historialMedico,
        'uid': user.uid,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // Obtener médicos disponibles
  Future<List<Map<String, dynamic>>> obtenerMedicos() async {
    try {
      final snapshot = await _firestore.collection('medicos').get();
      if (snapshot.docs.isEmpty) {
        // Si no hay médicos en la base de datos, retornar lista por defecto
        return [
          {'nombre': 'Cardiólogo', 'especialidad': 'Cardiólogo', 'doc_id': 'cardio_default'},
          {'nombre': 'Dermatólogo', 'especialidad': 'Dermatólogo', 'doc_id': 'derma_default'},
          {'nombre': 'Ginecólogo', 'especialidad': 'Ginecólogo', 'doc_id': 'gineco_default'},
          {'nombre': 'Pediatra', 'especialidad': 'Pediatra', 'doc_id': 'pediatra_default'},
          {'nombre': 'Psicólogo', 'especialidad': 'Psicólogo', 'doc_id': 'psicologo_default'},
        ];
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final Map<String, dynamic> medicoData;
        if (data is Map<String, dynamic>) {
          medicoData = Map<String, dynamic>.from(data);
        } else {
          medicoData = Map<String, dynamic>.from(data as Map);
        }
        medicoData['doc_id'] = doc.id;
        return medicoData;
      }).toList();
    } catch (e) {
      print('Error obteniendo médicos: $e');
      // Retornar lista por defecto en caso de error
      return [
        {'nombre': 'Cardiólogo', 'especialidad': 'Cardiólogo', 'doc_id': 'cardio_default'},
        {'nombre': 'Dermatólogo', 'especialidad': 'Dermatólogo', 'doc_id': 'derma_default'},
        {'nombre': 'Ginecólogo', 'especialidad': 'Ginecólogo', 'doc_id': 'gineco_default'},
        {'nombre': 'Pediatra', 'especialidad': 'Pediatra', 'doc_id': 'pediatra_default'},
        {'nombre': 'Psicólogo', 'especialidad': 'Psicólogo', 'doc_id': 'psicologo_default'},
      ];
    }
  }

  // Cambiar estado de cita
  Future<void> cambiarEstadoCita({
    required String docId,
    required String estado,
  }) async {
    await _firestore.collection('citas').doc(docId).update({
      'estado': estado,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Obtener citas por médico
  Stream<QuerySnapshot> obtenerCitasPorMedicoStream(String idMedico) {
    return _firestore
        .collection('citas')
        .where('id_medico', isEqualTo: idMedico)
        .orderBy('fecha', descending: false)
        .snapshots();
  }

  // Obtener citas por fecha
  Future<List<Map<String, dynamic>>> obtenerCitasPorFecha(DateTime fecha) async {
    try {
      final inicioDia = DateTime(fecha.year, fecha.month, fecha.day);
      final finDia = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('citas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finDia))
          .orderBy('fecha')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final Map<String, dynamic> citaData;
        if (data is Map<String, dynamic>) {
          citaData = Map<String, dynamic>.from(data);
        } else {
          citaData = Map<String, dynamic>.from(data as Map);
        }
        citaData['doc_id'] = doc.id;
        return citaData;
      }).toList();
    } catch (e) {
      print('Error obteniendo citas por fecha: $e');
      return [];
    }
  }
}