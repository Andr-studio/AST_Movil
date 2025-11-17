import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/tecnico_service.dart';
import 'crear_tecnico_screen.dart';
import 'editar_tecnico_screen.dart';

class GestionarTecnicosScreen extends StatefulWidget {
  const GestionarTecnicosScreen({super.key});

  @override
  State<GestionarTecnicosScreen> createState() =>
      _GestionarTecnicosScreenState();
}

class _GestionarTecnicosScreenState extends State<GestionarTecnicosScreen>
    with SingleTickerProviderStateMixin {
  final TecnicoService _tecnicoService = TecnicoService();
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
    final supervisorUid = authProvider.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Técnicos'),
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
          // Tab de técnicos activos
          _buildTecnicosList(supervisorUid, true),
          // Tab de técnicos inactivos
          _buildTecnicosList(supervisorUid, false),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CrearTecnicoScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('CREAR TÉCNICO'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildTecnicosList(String supervisorUid, bool activo) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'tecnico')
          .where('supervisorUid', isEqualTo: supervisorUid)
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
                    'Error al cargar técnicos',
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
                    activo ? Icons.engineering : Icons.person_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    activo
                        ? 'No hay técnicos activos'
                        : 'No hay técnicos inactivos',
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
              final tecnico = AppUser.fromFirestore(doc);
              return _buildTecnicoCard(tecnico);
            },
          ),
        );
      },
    );
  }

  Widget _buildTecnicoCard(AppUser tecnico) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: tecnico.activo
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditarTecnicoScreen(tecnico: tecnico),
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
                    backgroundColor: tecnico.activo
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    child: Icon(
                      Icons.engineering,
                      color: tecnico.activo ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tecnico.nombre,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          tecnico.activo ? 'Activo' : 'Inactivo',
                          style: TextStyle(
                            color: tecnico.activo ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tecnico.activo)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditarTecnicoScreen(tecnico: tecnico),
                            ),
                          );
                        } else if (value == 'delete') {
                          _confirmarEliminacion(tecnico);
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
                      onPressed: () => _confirmarReactivacion(tecnico),
                      tooltip: 'Reactivar técnico',
                    ),
                ],
              ),
              const Divider(height: 24),

              // Información de contacto
              _buildInfoRow(Icons.email, tecnico.email),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.phone, tecnico.telefono),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.calendar_today,
                'Registrado: ${dateFormat.format(tecnico.fechaRegistro)}',
              ),
              if (tecnico.fechaEliminacion != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.cancel,
                  'Eliminado: ${dateFormat.format(tecnico.fechaEliminacion!)}',
                  color: Colors.red,
                ),
              ],
              const Divider(height: 24),

              // Estadísticas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'AST Generados',
                    tecnico.totalASTGenerados ?? 0,
                  ),
                  _buildStatColumn(
                    'Pendientes',
                    tecnico.totalASTPendientes ?? 0,
                  ),
                  _buildStatColumn(
                    'Aprobados',
                    tecnico.totalASTAprobados ?? 0,
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
            color: Colors.green,
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

  Future<void> _confirmarEliminacion(AppUser tecnico) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Técnico'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Está seguro de eliminar a ${tecnico.nombre}?'),
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
                    '• El técnico quedará inactivo',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    '• No podrá generar nuevos AST',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    '• No se eliminarán sus AST existentes',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    '• No se eliminará su carpeta en Drive',
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
        await _tecnicoService.eliminarTecnico(
          tecnicoUid: tecnico.uid,
          supervisorUid: authProvider.currentUser!.uid,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Técnico eliminado correctamente'),
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

  Future<void> _confirmarReactivacion(AppUser tecnico) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivar Técnico'),
        content: Text('¿Desea reactivar a ${tecnico.nombre}?'),
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
        await _tecnicoService.reactivarTecnico(
          tecnicoUid: tecnico.uid,
          supervisorUid: authProvider.currentUser!.uid,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Técnico reactivado correctamente'),
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
