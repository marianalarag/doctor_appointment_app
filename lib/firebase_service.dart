import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      });
    }
  }

  // Crear cita con todos los campos necesarios
  Future<void> crearCita({
    required String idMedico,
    required DateTime fecha,
    required TimeOfDay hora,
    required String motivo,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      final fechaHora = DateTime(
        fecha.year,
        fecha.month,
        fecha.day,
        hora.hour,
        hora.minute,
      );

      await _firestore.collection('citas').add({
        'id_paciente': user.uid,
        'paciente_id': user.uid,
        'id_medico': idMedico,
        'motivo': motivo,
        'fecha': Timestamp.fromDate(fecha),
        'hora': '${hora.hour}:${hora.minute.toString().padLeft(2, '0')}',
        'fecha_hora': Timestamp.fromDate(fechaHora),
        'estado': 'pendiente', // valor inicial
      });
    }
  }

  // Registrar disponibilidad de médicos
  Future<void> registrarDisponibilidad({
    required String idMedico,
    required DateTime fecha,
    required DateTime horaInicio,
    required DateTime horaFin,
  }) async {
    await _firestore.collection('disponibilidad_medicos').add({
      'id_medico': idMedico,
      'fecha': Timestamp.fromDate(fecha),
      'hora_inicio': Timestamp.fromDate(horaInicio),
      'hora_fin': Timestamp.fromDate(horaFin),
      'disponibilidad': true,
    });
  }

  // 🔥 Obtener citas del usuario actual en tiempo real
  Stream<List<Map<String, dynamic>>> obtenerCitasDelUsuario(String uid) {
    return _firestore
        .collection('citas')
        .where('id_paciente', isEqualTo: uid)
        .orderBy('fecha_hora', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
