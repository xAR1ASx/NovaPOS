import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  List<Map<String, dynamic>> _clientes = [];

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  void _cargarClientes() async {
    final data = await DBHelper().obtenerClientes();
    setState(() {
      _clientes = data;
    });
  }

  void _crearCliente() {
    final n = TextEditingController();
    final t = TextEditingController();
    final d = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Nuevo Cliente"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: n,
              decoration: const InputDecoration(labelText: "Nombre"),
            ),
            TextField(
              controller: t,
              decoration: const InputDecoration(labelText: "Teléfono"),
            ),
            TextField(
              controller: d,
              decoration: const InputDecoration(labelText: "Dirección"),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (n.text.isNotEmpty) {
                await DBHelper().crearCliente({
                  'nombre': n.text,
                  'telefono': t.text,
                  'direccion': d.text,
                  'deuda_actual': 0,
                  'cupo_credito': 500000,
                });
                Navigator.pop(c);
                _cargarClientes();
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _mostrarFichaCliente(Map<String, dynamic> c) {
    final a = TextEditingController();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 400,
        child: Column(
          children: [
            Text(
              c['nombre'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Deuda: ${formater.format(c['deuda_actual'])}",
              style: const TextStyle(fontSize: 20, color: Colors.red),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: a,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Monto a Abonar"),
            ),
            ElevatedButton(
              onPressed: () async {
                double? m = double.tryParse(a.text);
                if (m != null) {
                  await DBHelper().registrarAbonoCliente(
                    c['id'],
                    c['nombre'],
                    m,
                  );
                  Navigator.pop(ctx);
                  _cargarClientes();
                }
              },
              child: const Text("REGISTRAR ABONO"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Clientes"),
        backgroundColor: Colors.purple[800],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _crearCliente,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _clientes.length,
        itemBuilder: (c, i) {
          final cli = _clientes[i];
          return ListTile(
            title: Text(cli['nombre']),
            trailing: Text(formater.format(cli['deuda_actual'])),
            onTap: () => _mostrarFichaCliente(cli),
          );
        },
      ),
    );
  }
}
