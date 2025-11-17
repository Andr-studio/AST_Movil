import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/supervisor_service.dart';
import 'crear_supervisor_screen.dart';
import 'editar_supervisor_screen.dart';

class GestionarSupervisoresScreen extends StatefulWidget {
  const GestionarSupervisoresScreen({super.key});

  @override
  State<GestionarSupervisoresScreen> createState() =>
      _GestionarSupervisoresScreenState();
}

class _GestionarSupervisoresScreenState
    extends State<GestionarSupervisoresScreen> with SingleTickerProviderStateMixin {
  final SupervisorService _supervisorService = SupervisorService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final adminUid = authProvider.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Supervisores'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'ACTIVOS', icon: Icon(Icons.check_circle)),
            Tab(text: 'INACTIVOS', icon: Icon(Icons.cancel)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab de supervisores activos
          _buildSupervisoresList(adminUid, true),
          // Tab de supervisores inactivos
          _buildSupervisoresList(adminUid, false),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CrearSupervisorScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('CREAR SUPERVISOR'),
      ),
    );
  }

  Widget _buildSupervisoresList(String adminUid, bool activo) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'supervisor')
          .where('creadoPor', isEqualTo: adminUid)
          .where('activo', isEqualTo: activo)
          .orderBy('fechaRegistro', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar supervisores',
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    activo ? Icons.supervisor_account : Icons.person_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    activo
                        ? 'No hay supervisores activos'
                        : 'No hay supervisores inactivos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  if (activo) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Presiona el botón + para crear uno',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final supervisor = AppUser.fromFirestore(doc);
              return _buildSupervisorCard(supervisor);
            },
          ),
        );
      },
    );
  }

  Widget _buildSupervisorCard(AppUser supervisor) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: supervisor.activo
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditarSupervisorScreen(supervisor: supervisor),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con nombre y estado
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: supervisor.activo
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    child: Icon(
                      Icons.supervisor_account,
                      color: supervisor.activo ? Colors.blue : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supervisor.nombre,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          supervisor.activo ? 'Activo' : 'Inactivo',
                          style: TextStyle(
                            color: supervisor.activo ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (supervisor.activo)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditarSupervisorScreen(supervisor: supervisor),
                            ),
                          );
                        } else if (value == 'delete') {
                          _confirmarEliminacion(supervisor);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Eliminar', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.green),
                      onPressed: () => _confirmarReactivacion(supervisor),
                      tooltip: 'Reactivar supervisor',
                    ),
                ],
              ),
              const Divider(height: 24),

              // Información de contacto
              _buildInfoRow(Icons.email, supervisor.email),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.phone, supervisor.telefono),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.calendar_today,
                'Registrado: ${dateFormat.format(supervisor.fechaRegistro)}',
              ),
              if (supervisor.fechaEliminacion != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.cancel,
                  'Eliminado: ${dateFormat.format(supervisor.fechaEliminacion!)}',
                  color: Colors.red,
                ),
              ],
              const Divider(height: 24),

              // Estadísticas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'Técnicos Creados',
                    supervisor.totalTecnicosCreados ?? 0,
                  ),
                  _buildStatColumn(
                    'Técnicos Activos',
                    supervisor.totalTecnicosActivos ?? 0,
                  ),
                  _buildStatColumn(
                    'AST Aprobados',
                    supervisor.totalASTAprobados ?? 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color ?? Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmarEliminacion(AppUser supervisor) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Supervisor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Está seguro de eliminar a ${supervisor.nombre}?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Importante:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• El supervisor quedará inactivo',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    '• Todos sus técnicos quedarán inactivos',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    '• No se eliminarán carpetas ni AST',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supervisorService.eliminarSupervisor(
          supervisorUid: supervisor.uid,
          adminUid: authProvider.currentUser!.uid,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supervisor eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmarReactivacion(AppUser supervisor) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivar Supervisor'),
        content: Text('¿Desea reactivar a ${supervisor.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('REACTIVAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supervisorService.reactivarSupervisor(
          supervisorUid: supervisor.uid,
          adminUid: authProvider.currentUser!.uid,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supervisor reactivado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
