import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/supervisor_service.dart';
import 'gestionar_supervisores_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final SupervisorService _supervisorService = SupervisorService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.supervisor_account),
            tooltip: 'Gestionar Supervisores',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GestionarSupervisoresScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Reasignar Técnicos',
            onPressed: () {
              // TODO: Implementar en Fase 5
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Función disponible en Fase 5'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Reportes',
            onPressed: () {
              // TODO: Implementar reportes
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reportes en desarrollo'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
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
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await authProvider.reloadCurrentUser();
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta de bienvenida
              _buildWelcomeCard(context, currentUser.nombre),
              const SizedBox(height: 24),

              // Estadísticas globales
              Text(
                'ESTADÍSTICAS GLOBALES',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildEstadisticasGlobales(context, currentUser.uid),
              const SizedBox(height: 24),

              // Acciones rápidas
              Text(
                'ACCIONES RÁPIDAS',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildAccionesRapidas(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, String nombre) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              '¡Hola, $nombre!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Administrador del Sistema',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticasGlobales(BuildContext context, String adminUid) {
    return FutureBuilder<Map<String, int>>(
      future: _obtenerEstadisticasGlobales(adminUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error al cargar estadísticas',
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
          );
        }

        final stats = snapshot.data ?? {};
        
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Supervisores\nActivos',
                    stats['supervisoresActivos'] ?? 0,
                    Icons.supervisor_account,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Técnicos\nActivos',
                    stats['tecnicosActivos'] ?? 0,
                    Icons.engineering,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total AST',
                    stats['totalAST'] ?? 0,
                    Icons.assignment,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'AST Pendientes',
                    stats['astPendientes'] ?? 0,
                    Icons.pending_actions,
                    Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    int value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccionesRapidas(BuildContext context) {
    return Column(
      children: [
        _buildActionButton(
          context,
          'Gestionar Supervisores',
          'Crear, editar y eliminar supervisores',
          Icons.supervisor_account,
          Colors.blue,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GestionarSupervisoresScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          'Reasignar Técnicos',
          'Cambiar técnicos entre supervisores',
          Icons.swap_horiz,
          Colors.purple,
          () {
            // TODO: Implementar en Fase 5
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Función disponible en Fase 5'),
                backgroundColor: Colors.orange,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context,
          'Ver Reportes',
          'Estadísticas y reportes del sistema',
          Icons.bar_chart,
          Colors.green,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reportes en desarrollo'),
                backgroundColor: Colors.orange,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, int>> _obtenerEstadisticasGlobales(String adminUid) async {
    try {
      // Contar supervisores activos
      final supervisoresActivos =
          await _supervisorService.contarSupervisoresActivos(adminUid);

      // Contar técnicos activos (de todos los supervisores de este admin)
      final tecnicosSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('rol', isEqualTo: 'tecnico')
          .where('activo', isEqualTo: true)
          .count()
          .get();

      // Contar total de AST
      final totalASTSnapshot = await FirebaseFirestore.instance
          .collection('ast')
          .count()
          .get();

      // Contar AST pendientes
      final astPendientesSnapshot = await FirebaseFirestore.instance
          .collection('ast')
          .where('estado', isEqualTo: 'pendiente')
          .count()
          .get();

      return {
        'supervisoresActivos': supervisoresActivos,
        'tecnicosActivos': tecnicosSnapshot.count ?? 0,
        'totalAST': totalASTSnapshot.count ?? 0,
        'astPendientes': astPendientesSnapshot.count ?? 0,
      };
    } catch (e) {
      return {};
    }
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
