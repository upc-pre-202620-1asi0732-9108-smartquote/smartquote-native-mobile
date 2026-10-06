import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/request_list_viewmodel.dart';
import 'new_request_screen.dart';
import 'notifications_screen.dart';

class RequestListScreen extends StatefulWidget {
  @override
  _RequestListScreenState createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  @override
  void initState() {
    super.initState();
    // Llama a la API apenas inicia la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestListViewModel>().fetchRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RequestListViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Solicitudes de compra', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => NewRequestScreen()));
                }, // Navegar a nueva solicitud después
              icon: const Icon(Icons.add),
              label: const Text('Nueva solicitud'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0056B3)),
            ),
          )
        ],
      ),
      // Drawer (Menú lateral azul oscuro)
      drawer: Drawer(
        backgroundColor: const Color(0xFF1C3A53),
        child: ListView(
          children: [
            const DrawerHeader(child: Text('SmartQuote', style: TextStyle(color: Colors.white, fontSize: 24))),
            ListTile(
              leading: const Icon(Icons.inbox, color: Colors.white),
              title: const Text('Solicitudes de compra', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); // Cierra el menú lateral
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications, color: Colors.white),
              title: const Text('Notificaciones', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); // Cierra el menú lateral
                Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen()));
              },
            ),
          ],
        ),
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : viewModel.errorMessage != null
              ? Center(child: Text(viewModel.errorMessage!))
              : _buildTable(viewModel.requests),
    );
  }

  Widget _buildTable(List requests) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Solicitud')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Prioridad')),
          DataColumn(label: Text('Fecha requerida')),
          DataColumn(label: Text('Abrir')),
        ],
        rows: requests.map((req) {
          return DataRow(cells: [
            DataCell(Text(req.requestId.substring(0, 8))), // Muestra ID corto
            DataCell(_buildStatusChip(req.status ?? 'Desconocido')),
            DataCell(Text(req.priority ?? 'Normal')),
            DataCell(Text(DateFormat('dd MMM yyyy').format(req.requiredDate))),
            DataCell(IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () {})),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor = Colors.grey.shade200;
    Color textColor = Colors.black;

    if (status.toLowerCase().contains('emitida')) {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    } else if (status.toLowerCase().contains('rechazada')) {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
    }

    return Chip(
      label: Text(status, style: TextStyle(color: textColor, fontSize: 12)),
      backgroundColor: bgColor,
      side: BorderSide.none,
    );
  }
}