import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pin_auth_service.dart';
import '../services/session_service.dart';
import '../services/locale_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Crear usuario': 'Create user',
  'Nombre completo': 'Full name',
  'Correo electronico': 'Email',
  'Ej: juan@gmail.com': 'E.g: juan@gmail.com',
  'Rol': 'Role',
  'Cajero': 'Cashier',
  'Administrador': 'Administrator',
  'PIN (6 digitos)': 'PIN (6 digits)',
  'Ej: 123456': 'E.g: 123456',
  'Cancelar': 'Cancel',
  'Crear': 'Create',
  'Recuperar PIN': 'Recover PIN',
  'Se enviara un enlace a': 'A link will be sent to',
  'El usuario debera abrirlo, crear un PIN nuevo y luego usarlo para entrar a NovaPOS.':
      'The user must open it, create a new PIN, and then use it to enter NovaPOS.',
  'Enviar enlace': 'Send link',
  'Enlace enviado a': 'Link sent to',
  'No se pudo enviar el enlace': 'Could not send the link',
  'Editar': 'Edit',
  'Guardar': 'Save',
  'Usuario actualizado': 'User updated',
  'Error al actualizar': 'Error updating',
  'Desactivar': 'Deactivate',
  'Desactivar usuario': 'Deactivate user',
  'Deseas desactivar a': 'Do you want to deactivate',
  'Usuario desactivado': 'User deactivated',
  'Error': 'Error',
  'Gestionar Usuarios': 'Manage Users',
  'No hay usuarios': 'No users',
  'Toca + para crear el primer usuario': 'Tap + to create the first user',
  'Admin': 'Admin',
};

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _usuarios = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _cargando = true);
    String? negocioId = SessionService.negocioId();
    if (negocioId != null) {
      _usuarios = await PinAuthService.obtenerUsuarios(negocioId);
    }
    setState(() => _cargando = false);
  }

  void _mostrarDialogoCrear() {
    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String rolSeleccionado = 'CAJERO';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Crear usuario')),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: InputDecoration(
                  labelText: _t('Nombre completo'),
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: _t('Correo electronico'),
                  border: const OutlineInputBorder(),
                  hintText: _t('Ej: juan@gmail.com'),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: rolSeleccionado,
                decoration: InputDecoration(
                  labelText: _t('Rol'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'CAJERO',
                    child: Text(_t('Cajero')),
                  ),
                  DropdownMenuItem(
                    value: 'ADMIN',
                    child: Text(_t('Administrador')),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => rolSeleccionado = v);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                decoration: InputDecoration(
                  labelText: _t('PIN (6 digitos)'),
                  border: const OutlineInputBorder(),
                  hintText: _t('Ej: 123456'),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Cancelar')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              if (emailCtrl.text.trim().isEmpty) return;
              if (pinCtrl.text.length < 6) return;

              String? negocioId = SessionService.negocioId();
              if (negocioId == null) return;

              Navigator.pop(ctx);

              Map<String, dynamic> resultado = await PinAuthService.crearUsuario(
                nombre: nombreCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                pin: pinCtrl.text,
                rol: rolSeleccionado,
                negocioId: negocioId,
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(resultado['mensaje']),
                  backgroundColor: resultado['exito'] ? Colors.green : Colors.red,
                ),
              );

              _cargarUsuarios();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text(_t('Crear')),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoRecuperar(Map<String, dynamic> usuario) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Recuperar PIN')),
        content: Text(
          '${_t('Se enviara un enlace a')} ${usuario['email']}.\n\n'
          '${_t('El usuario debera abrirlo, crear un PIN nuevo y luego usarlo para entrar a NovaPOS.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Cancelar')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              bool ok = await PinAuthService.enviarEnlaceRecuperacion(
                usuario['email'] ?? '',
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? '${_t('Enlace enviado a')} ${usuario['email']}'
                        : _t('No se pudo enviar el enlace'),
                  ),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ),
              );
            },
            child: Text(_t('Enviar enlace')),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditar(Map<String, dynamic> usuario) {
    final nombreCtrl = TextEditingController(text: usuario['nombre'] ?? '');
    String rolSeleccionado = usuario['rol'] ?? 'CAJERO';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_t('Editar')} - ${usuario['nombre']}'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: InputDecoration(
                  labelText: _t('Nombre completo'),
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: rolSeleccionado,
                decoration: InputDecoration(
                  labelText: _t('Rol'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'CAJERO',
                    child: Text(_t('Cajero')),
                  ),
                  DropdownMenuItem(
                    value: 'ADMIN',
                    child: Text(_t('Administrador')),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => rolSeleccionado = v);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Cancelar')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              bool ok = await PinAuthService.editarUsuario(
                usuario['uid'],
                nombreCtrl.text.trim(),
                rolSeleccionado,
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? _t('Usuario actualizado') : _t('Error al actualizar')),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ),
              );

              _cargarUsuarios();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text(_t('Guardar')),
          ),
        ],
      ),
    );
  }

  void _confirmarDesactivar(Map<String, dynamic> usuario) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Desactivar usuario')),
        content: Text('${_t('Deseas desactivar a')} ${usuario['nombre']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('Cancelar')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              bool ok = await PinAuthService.desactivarUsuario(usuario['uid']);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? _t('Usuario desactivado') : _t('Error')),
                  backgroundColor: ok ? Colors.orange : Colors.red,
                ),
              );
              _cargarUsuarios();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(_t('Desactivar')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Gestionar Usuarios')),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoCrear,
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _usuarios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _t('No hay usuarios'),
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t('Toca + para crear el primer usuario'),
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _usuarios.length,
                  itemBuilder: (ctx, i) {
                    Map<String, dynamic> u = _usuarios[i];
                    bool esAdmin = u['rol'] == 'ADMIN';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: esAdmin
                              ? Colors.green.shade100
                              : Colors.blue.shade100,
                          child: Icon(
                            esAdmin ? Icons.admin_panel_settings : Icons.person,
                            color: esAdmin ? Colors.green.shade700 : Colors.blue,
                          ),
                        ),
                        title: Text(
                          u['nombre'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${u['email'] ?? ''}  •  ${esAdmin ? _t('Admin') : _t('Cajero')}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'editar',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text(_t('Editar')),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'recuperar',
                              child: Row(
                                children: [
                                  Icon(Icons.mail_outline, size: 20),
                                  SizedBox(width: 8),
                                  Text(_t('Recuperar PIN')),
                                ],
                              ),
                            ),
                            if (!esAdmin)
                              PopupMenuItem(
                                value: 'desactivar',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_off, size: 20, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text(_t('Desactivar'),
                                        style: TextStyle(color: Colors.orange)),
                                  ],
                                ),
                              ),
                          ],
                          onSelected: (valor) {
                            if (valor == 'editar') _mostrarDialogoEditar(u);
                            if (valor == 'recuperar') _mostrarDialogoRecuperar(u);
                            if (valor == 'desactivar') _confirmarDesactivar(u);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}