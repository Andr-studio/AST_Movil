import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/ast_model.dart';
import '../../services/ast_service.dart';
import 'generar_ast_screen.dart';
import 'detalle_ast_screen.dart';

class TecnicoHomeScreen extends StatefulWidget {
  const TecnicoHomeScreen({super.key});

  @override
  State<TecnicoHomeScreen> createState() => _TecnicoHomeScreenState();
}

class _TecnicoHomeScreenState extends State<TecnicoHomeScreen>
    with SingleTickerProviderStateMixin {
  final ASTService _astService = ASTService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis AST'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                final confirm = await _showLogoutDialog(context);
                if (confirm == true) {
                  await authProvider.logout();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Cerrar sesión'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'TODOS', icon: Icon(Icons.list, size: 20)),
            Tab(text: 'PENDIENTES', icon: Icon(Icons.pending, size: 20)),
            Tab(text: 'APROBADOS', icon: Icon(Icons.check_circle, size: 20)),
            Tab(text: 'RECHAZADOS', icon: Icon(Icons.cancel, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tarjeta de bienvenida y estadísticas
          _buildHeader(context, currentUser),
          // Lista de AST según tab
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildASTList(currentUser.uid, null),
                _buildASTList(currentUser.uid, EstadoAST.pendiente),
                _buildASTList(currentUser.uid, EstadoAST.aprobado),
                _buildASTList(currentUser.uid, EstadoAST.rechazado),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GenerarASTScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('GENERAR AST'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, user) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  child: const Icon(
                    Icons.engineering,
                    color: Colors.green,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nombre,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Text(
                        'Técnico',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Generados',
                  user.totalASTGenerados ?? 0,
                  Icons.assignment,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Pendientes',
                  user.totalASTPendientes ?? 0,
                  Icons.pending,
                  Colors.orange,
                ),
                _buildStatItem(
                  'Aprobados',
                  user.totalASTAprobados ?? 0,
                  Icons.check_circle,
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildASTList(String tecnicoUid, EstadoAST? estado) {
    Stream<QuerySnapshot> stream;

    if (estado == null) {
      stream = _astService.obtenerASTTecnico(tecnicoUid);
    } else if (estado == EstadoAST.pendiente) {
      stream = _astService.obtenerASTPendientesTecnico(tecnicoUid);
    } else if (estado == EstadoAST.aprobado) {
      stream = _astService.obtenerASTAprobadosTecnico(tecnicoUid);
    } else {
      stream = _astService.obtenerASTRechazadosTecnico(tecnicoUid);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error al cargar AST',
                style: TextStyle(color: Colors.red[700]),
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
                    Icons.assignment_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    estado == null
                        ? 'No has generado AST aún'
                        : 'No hay AST ${estado.displayName.toLowerCase()}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  if (estado == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Presiona el botón + para generar uno',
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
              final ast = AST.fromFirestore(doc);
              return _buildASTCard(ast);
            },
          ),
        );
      },
    );
  }

  Widget _buildASTCard(AST ast) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    Color estadoColor;
    IconData estadoIcon;

    switch (ast.estado) {
      case EstadoAST.pendiente:
        estadoColor = Colors.orange;
        estadoIcon = Icons.pending;
        break;
      case EstadoAST.aprobado:
        estadoColor = Colors.green;
        estadoIcon = Icons.check_circle;
        break;
      case EstadoAST.rechazado:
        estadoColor = Colors.red;
        estadoIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetalleASTScreen(ast: ast),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ast.numeroMTA,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: estadoColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcon, size: 14, color: estadoColor),
                        const SizedBox(width: 4),
                        Text(
                          ast.estado.displayName,
                          style: TextStyle(
                            color: estadoColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(ast.fechaGeneracion),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ast.direccion,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (ast.estado == EstadoAST.rechazado &&
                  ast.motivoRechazo != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Motivo: ${ast.motivoRechazo}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
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
            child: const Text('CERRAR SESIÓN'),
          ),
        ],
      ),
    );
  }
}
