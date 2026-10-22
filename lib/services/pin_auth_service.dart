import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../database/db_helper.dart';
import 'login_offline_service.dart';
import '../firebase_options.dart';

class PinAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<File> _sesionFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}novapos_sesion.json');
  }

  static Future<void> guardarSesion(String email, String uid) async {
    final file = await _sesionFile();
    final jsonStr = jsonEncode({
      'sesion_verificada': true,
      'usuario_email': email,
      'usuario_uid': uid,
    });
    final encriptado = base64Encode(utf8.encode(jsonStr)); // L-03: Encriptación básica
    await file.writeAsString(encriptado);
  }

  /// Verificar si ya hay sesion verificada en este dispositivo
  static Future<bool> haySesion() async {
    try {
      final file = await _sesionFile();
      if (!await file.exists()) return false;
      String contenidoEncriptado = await file.readAsString();
      String contenido = utf8.decode(base64Decode(contenidoEncriptado));
      Map<String, dynamic> datos = jsonDecode(contenido);
      return datos['sesion_verificada'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Obtener email guardado
  static Future<String?> emailGuardado() async {
    try {
      final file = await _sesionFile();
      if (!await file.exists()) return null;
      String contenidoEncriptado = await file.readAsString();
      String contenido = utf8.decode(base64Decode(contenidoEncriptado));
      Map<String, dynamic> datos = jsonDecode(contenido);
      return datos['usuario_email'];
    } catch (e) {
      return null;
    }
  }

  /// Limpiar sesion guardada (archivo)
  static Future<void> limpiarSesion() async {
    try {
      final file = await _sesionFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {}
  }

  /// Validar complejidad de PIN (M-03)
  static bool _esPinInseguro(String pin) {
    const inseguros = ['000000', '111111', '222222', '333333', '444444', '555555', '666666', '777777', '888888', '999999', '123456', '654321'];
    return inseguros.contains(pin);
  }

  /// Cerrar sesion completa: firma fuera de Firebase y borra el archivo local
  static Future<void> cerrarSesion() async {
    _timerReconexion?.cancel();
    _pendienteReconexion = null;
    try {
      await _auth.signOut();
    } catch (e) {}
    await limpiarSesion();
  }

  /// Trae el documento del usuario desde Firestore (ya autenticado)
  /// Perfil para iniciar sesión: a diferencia de [_obtenerDocUsuario], dice
  /// por qué no se puede entrar (el correo y el PIN ya fueron correctos).
  static Future<Map<String, dynamic>> _perfilParaLogin(String uid) async {
    DocumentSnapshot doc;
    try {
      doc = await _firestore.collection('usuarios').doc(uid).get();
    } on FirebaseException catch (e) {
      throw ProblemaLogin.desdeFirebase(e);
    }
    if (!doc.exists) throw const ProblemaLogin(ProblemaLogin.sinPerfil);
    final data = doc.data() as Map<String, dynamic>;
    if (data['esta_activo'] != true) throw const ProblemaLogin(ProblemaLogin.inactivo);
    final perfil = await _obtenerDocUsuario(uid);
    if (perfil == null) throw const ProblemaLogin(ProblemaLogin.sinConexion);
    return perfil;
  }

  static Future<Map<String, dynamic>?> _obtenerDocUsuario(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('usuarios').doc(uid).get();
      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data['esta_activo'] != true) return null;

      data['uid'] = doc.id;
      try {
        final idLocal = await DBHelper().asegurarUsuarioLocal(
          uid: doc.id,
          nombre: data['nombre']?.toString() ?? '',
          rol: (data['rol'] ?? 'CAJERO').toString(),
          activo: data['esta_activo'] != false,
        );
        data['id'] = idLocal;
      } catch (e) {
        data['id'] = null;
      }
      return data;
    } catch (e) {
      return null;
    }
  }

  /// Enviar enlace de recuperacion (admin resetea PIN de un cajero)
  static Future<bool> enviarEnlaceRecuperacion(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Login con email + PIN (primera vez en el dispositivo).
  /// El PIN es el password real de la cuenta Firebase.
  /// Devuelve null si las credenciales son invalidas o el usuario no existe.
  static Future<Map<String, dynamic>?> loginConEmailPin(
      String email, String pin) =>
      _entrar(email.trim(), pin);

  /// Login con solo PIN usando la sesion guardada (email en disco).
  static Future<Map<String, dynamic>?> loginConPin(String pin) async {
    String? email = await emailGuardado();
    if (email == null || email.isEmpty) return null;
    return _entrar(email, pin);
  }

  /// Entra con internet; si no hay conexión, con la huella guardada en este
  /// equipo (ver LoginOfflineService). Devuelve null si el PIN es incorrecto.
  static Future<Map<String, dynamic>?> _entrar(String email, String pin) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: pin);
      final perfil = await _perfilParaLogin(cred.user!.uid);
      await LoginOfflineService.recordar(email: email, pin: pin, perfil: perfil);
      _pendienteReconexion = null;
      return perfil;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        return null;
      }
      if (e.code == 'network-request-failed') return _entrarSinConexion(email, pin);
      rethrow;
    } on ProblemaLogin catch (e) {
      // Sin perfil o desactivado: tampoco puede entrar sin internet.
      if (e.codigo == ProblemaLogin.sinPerfil || e.codigo == ProblemaLogin.inactivo) {
        await LoginOfflineService.olvidar(email);
      }
      if (e.codigo == ProblemaLogin.sinConexion) return _entrarSinConexion(email, pin);
      rethrow;
    } on SocketException {
      return _entrarSinConexion(email, pin);
    }
  }

  static Future<Map<String, dynamic>?> _entrarSinConexion(String email, String pin) async {
    final r = await LoginOfflineService.entrar(email, pin);
    switch (r.codigo) {
      case ResultadoOffline.ok:
        // El PIN queda solo en memoria para reconectarse a la nube al volver
        // el internet.
        _pendienteReconexion = (email: email, pin: pin);
        return r.perfil;
      case ResultadoOffline.pinIncorrecto:
        return null;
      case ResultadoOffline.vencido:
        throw const ProblemaLogin(ProblemaLogin.offlineVencido);
      default:
        throw const ProblemaLogin(ProblemaLogin.sinCredencialOffline);
    }
  }

  static ({String email, String pin})? _pendienteReconexion;

  /// Si se entró sin internet: intenta iniciar sesión en la nube. true si lo
  /// logró (entonces hay que reiniciar la sincronización).
  static Future<bool> reconectarSiHaceFalta() async {
    final p = _pendienteReconexion;
    if (p == null) return false;
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: p.email, password: p.pin);
      final perfil = await _perfilParaLogin(cred.user!.uid);
      await LoginOfflineService.recordar(email: p.email, pin: p.pin, perfil: perfil);
      _pendienteReconexion = null;
      return true;
    } on ProblemaLogin catch (e) {
      if (e.codigo == ProblemaLogin.sinPerfil || e.codigo == ProblemaLogin.inactivo) {
        await LoginOfflineService.olvidar(p.email);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static bool get sesionSinConexion => _pendienteReconexion != null;

  static Timer? _timerReconexion;

  /// Mientras se trabaja sin internet, cada minuto intenta conectarse a la
  /// nube; al lograrlo llama [alConectar] (reiniciar sincronización y licencia).
  static void iniciarReconexionAutomatica(Future<void> Function() alConectar) {
    _timerReconexion?.cancel();
    _timerReconexion = Timer.periodic(const Duration(minutes: 1), (t) async {
      if (!sesionSinConexion) {
        t.cancel();
        return;
      }
      if (await reconectarSiHaceFalta()) {
        t.cancel();
        await alConectar();
      }
    });
  }

  /// Verificar el PIN actual del usuario conectado (para acciones sensibles)
  static Future<bool> verificarPinActual(String pinActual) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: pinActual),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cambiar el propio PIN (self-service): requiere el PIN actual
  static Future<Map<String, dynamic>> cambiarPinPropio(
      String pinActual, String nuevoPin) async {
    try {
      if (_esPinInseguro(nuevoPin)) {
        return {'exito': false, 'mensaje': 'El nuevo PIN es muy inseguro. Elija otro.'};
      }
      
      final ok = await verificarPinActual(pinActual);
      if (!ok) {
        return {'exito': false, 'mensaje': 'El PIN actual es incorrecto'};
      }

      await _auth.currentUser!.updatePassword(nuevoPin);
      final email = _auth.currentUser?.email;
      final perfil = _auth.currentUser == null ? null : await _obtenerDocUsuario(_auth.currentUser!.uid);
      if (email != null && perfil != null) {
        await LoginOfflineService.recordar(email: email, pin: nuevoPin, perfil: perfil);
      }
      return {'exito': true, 'mensaje': 'PIN actualizado correctamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al cambiar el PIN'};
    }
  }

  /// Crear negocio + admin (protegido por llave maestra para evitar negocios fantasma)
  static Future<Map<String, dynamic>> crearNegocioAdmin({
    required String nombreNegocio,
    required String nit,
    required String direccion,
    required String emailAdmin,
    required String passwordAdmin,
    required String nombreAdmin,
    String? licenciaFin,
    required String codigoInstalador, // M-02
  }) async {
    // LLAVE MAESTRA DE INSTALACIÓN
    if (codigoInstalador != 'NOVAPOS-MASTER-KEY') {
      return {'exito': false, 'mensaje': 'Código de instalador inválido. Acceso denegado.'};
    }

    try {
      final creado = await _crearCuentaFirebase(
        email: emailAdmin,
        pin: passwordAdmin,
      );
      if (!creado['exito']) return creado;

      String uid = creado['uid'];

      DocumentReference negocioRef = await _firestore
          .collection('negocios')
          .add({
        'nombre': nombreNegocio,
        'nit': nit,
        'direccion': direccion,
        'estado': 'activa',
        'licencia_fin': licenciaFin,
        'created_at': FieldValue.serverTimestamp(),
        'created_by': uid,
      });

      await _firestore.collection('usuarios').doc(uid).set({
        'email': emailAdmin.trim(),
        'nombre': nombreAdmin,
        'rol': 'ADMIN',
        'negocio_id': negocioRef.id,
        'esta_activo': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      return {
        'exito': true,
        'negocioId': negocioRef.id,
        'userId': uid,
        'mensaje': 'Negocio y administrador creados correctamente',
      };
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error: $e',
      };
    }
  }

  /// Crear una cuenta en Firebase Auth por REST sin cambiar la sesion actual.
  static Future<Map<String, dynamic>> _crearCuentaFirebase({
    required String email,
    required String pin,
  }) async {
    if (_esPinInseguro(pin)) {
      return {'exito': false, 'mensaje': 'El PIN es muy inseguro (ej. 123456 o repetido)'};
    }
    try {
      final config = DefaultFirebaseOptions.currentPlatform;
      final url =
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${config.apiKey}';

      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': pin,
          'returnSecureToken': true,
        }),
      );

      Map<String, dynamic> data = jsonDecode(resp.body);

      if (resp.statusCode == 200) {
        return {'exito': true, 'uid': data['localId'] as String};
      }

      String code = data['error']?['message'] ?? 'Error desconocido';
      if (code.contains('EMAIL_EXISTS')) {
        return {'exito': false, 'mensaje': 'Ese correo ya esta registrado'};
      }
      if (code.contains('WEAK_PASSWORD')) {
        return {
          'exito': false,
          'mensaje': 'El PIN debe tener al menos 6 caracteres'
        };
      }
      return {'exito': false, 'mensaje': 'No se pudo crear la cuenta: $code'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexion al crear cuenta'};
    }
  }

  /// Crear usuario (cajero o admin) desde la app sin afectar la sesion actual
  static Future<Map<String, dynamic>> crearUsuario({
    required String nombre,
    required String email,
    required String pin,
    required String rol,
    required String negocioId,
  }) async {
    try {
      final creado = await _crearCuentaFirebase(email: email, pin: pin);
      if (!creado['exito']) return creado;

      String uid = creado['uid'];

      await _firestore.collection('usuarios').doc(uid).set({
        'email': email.trim(),
        'nombre': nombre,
        'rol': rol,
        'negocio_id': negocioId,
        'esta_activo': true,
        'created_by': _auth.currentUser?.uid,
        'created_at': FieldValue.serverTimestamp(),
      });

      return {
        'exito': true,
        'userId': uid,
        'mensaje': 'Usuario $nombre creado correctamente',
      };
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error: $e',
      };
    }
  }

  /// Obtener usuarios de un negocio
  static Future<List<Map<String, dynamic>>> obtenerUsuarios(
      String negocioId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('usuarios')
          .where('negocio_id', isEqualTo: negocioId)
          .where('esta_activo', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Desactivar usuario
  static Future<bool> desactivarUsuario(String uid) async {
    try {
      await _firestore.collection('usuarios').doc(uid).update({
        'esta_activo': false,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Editar nombre y rol de un usuario
  static Future<bool> editarUsuario(String uid, String nombre, String rol) async {
    try {
      await _firestore.collection('usuarios').doc(uid).update({
        'nombre': nombre,
        'rol': rol,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Verificar si el negocio tiene licencia valida
  static Future<Map<String, dynamic>> verificarLicencia(String negocioId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('negocios')
          .doc(negocioId)
          .get();

      if (!doc.exists) {
        return {'valida': false, 'mensaje': 'Negocio no encontrado'};
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      if (data['estado'] == 'bloqueada') {
        return {
          'valida': false,
          'mensaje': 'Licencia bloqueada. Contacte al administrador.'
        };
      }

      dynamic licenciaFin = data['licencia_fin'];
      if (licenciaFin == null) {
        return {'valida': true};
      }

      DateTime fechaFin = (licenciaFin as Timestamp).toDate();
      if (fechaFin.isBefore(DateTime.now())) {
        return {
          'valida': false,
          'mensaje': 'Tu licencia de NovaPOS ha vencido. Renueva para continuar.'
        };
      }

      return {'valida': true};
    } catch (e) {
      return {'valida': false, 'mensaje': 'Error de conexion'};
    }
  }
}

/// Razón clara por la que no se pudo iniciar sesión.
class ProblemaLogin implements Exception {
  static const sinPerfil = 'SIN_PERFIL';
  static const inactivo = 'INACTIVO';
  static const sinConexion = 'SIN_CONEXION';
  static const sinPermiso = 'SIN_PERMISO';
  static const limiteNube = 'LIMITE_NUBE';
  static const sinCredencialOffline = 'SIN_CREDENCIAL_OFFLINE';
  static const offlineVencido = 'OFFLINE_VENCIDO';

  final String codigo;
  const ProblemaLogin(this.codigo);

  factory ProblemaLogin.desdeFirebase(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const ProblemaLogin(sinPermiso);
      case 'resource-exhausted':
        return const ProblemaLogin(limiteNube);
      default:
        return const ProblemaLogin(sinConexion);
    }
  }

  String get mensaje {
    switch (codigo) {
      case sinPerfil:
        return 'El correo y el PIN están bien, pero este usuario no tiene perfil en NovaPOS. '
            'Pide a soporte que lo cree (colección "usuarios" en Firebase).';
      case inactivo:
        return 'Este usuario está desactivado. El administrador puede activarlo en Usuarios.';
      case sinPermiso:
        return 'Este usuario no tiene un negocio asignado o no tiene permisos. Contacta a soporte.';
      case limiteNube:
        return 'La nube llegó a su límite de hoy. Intenta de nuevo más tarde o contacta a soporte.';
      case sinCredencialOffline:
        return 'No hay internet y este usuario nunca ha entrado en este equipo. '
            'La primera vez hay que entrar con internet.';
      case offlineVencido:
        return 'Llevas más de ${LoginOfflineService.diasMaximos} días sin internet en este equipo. '
            'Conéctate a internet para entrar.';
      default:
        return 'No hay conexión con la nube. Revisa el internet (Wi-Fi o cable) e intenta de nuevo.';
    }
  }

  @override
  String toString() => mensaje;
}
