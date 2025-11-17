import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/reasignacion_service.dart';
import '../../providers/auth_provider.dart';

class ReasignarTecnicosScreen extends StatefulWidget {
  const ReasignarTecnicosScreen({super.key});

  @override
  State<ReasignarTecnicosScreen> createState() =>
      _ReasignarTecnicosScreenState();
}

class _ReasignarTecnicosScreenState extends State<ReasignarTecnicosScreen> {
  final ReasignacionService _reasignacionService = ReasignacionService();

  List<AppUser> _tecnicos = [];
  List<AppUser> _supervisores = [];
  bool _isLoading = true;
  String? _error;

  // Filtros
  String _searchQuery = '';
  String? _filtroSupervisor;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tecnicos = await _reasignacionService.obtenerTodosTecnicosActivos();
      final supervisores =
          await _reasignacionService.obtenerTodosSupervisoresActivos();

      setState(() {
        _tecnicos = tecnicos;
        _supervisores = supervisores;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<AppUser> get _tecnicosFiltrados {
    var tecnicos = _tecnicos;

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      tecnicos = tecnicos.where((tecnico) {
        final nombre = tecnico.nombre.toLowerCase();
        final email = tecnico.email.toLowerCase();
        final query = _searchQuery.toLowerCase();
        return nombre.contains(query) || email.contains(query);
      }).toList();
    }

    // Filtrar por supervisor
    if (_filtroSupervisor != null) {
      tecnicos = tecnicos
          .where((tecnico) => tecnico.supervisorUid == _filtroSupervisor)
          .toList();
    }

    return tecnicos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reasignar Técnicos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Ver Historial',
            onPressed: () {
              Navigator.pushNamed(context, '/historial_reasignaciones');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    _buildFiltros(),
                    Expanded(child: _buildListaTecnicos()),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error al cargar datos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _cargarDatos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          // Búsqueda
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar técnico por nombre o email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),

          // Filtro por supervisor
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _filtroSupervisor,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por supervisor',
                    prefixIcon: const Icon(Icons.supervisor_account),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todos los supervisores'),
                    ),
                    ..._supervisores.map((supervisor) {
                      return DropdownMenuItem(
                        value: supervisor.uid,
                        child: Text(supervisor.nombre),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filtroSupervisor = value;
                    });
                  },
                ),
              ),
              if (_filtroSupervisor != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _filtroSupervisor = null;
                    });
                  },
                ),
              ],
            ],
          ),

          // Resumen
          const SizedBox(height: 8),
          Text(
            'Mostrando ${_tecnicosFiltrados.length} de ${_tecnicos.length} técnicos',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildListaTecnicos() {
    if (_tecnicosFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron técnicos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta cambiar los filtros',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tecnicosFiltrados.length,
      itemBuilder: (context, index) {
        final tecnico = _tecnicosFiltrados[index];
        return _buildTecnicoCard(tecnico);
      },
    );
  }

  Widget _buildTecnicoCard(AppUser tecnico) {
    // Buscar el supervisor actual
    final supervisorActual = _supervisores.firstWhere(
      (s) => s.uid == tecnico.supervisorUid,
      orElse: () => AppUser(
        uid: '',
        nombre: 'Desconocido',
        email: '',
        telefono: '',
        rol: UserRole.supervisor,
        activo: false,
        fechaRegistro: DateTime.now(),
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _mostrarDialogoReasignacion(tecnico, supervisorActual),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      tecnico.nombre[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tecnico.nombre,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tecnico.email,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    tooltip: 'Reasignar',
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () =>
                        _mostrarDialogoReasignacion(tecnico, supervisorActual),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.supervisor_account,
                        size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supervisor Actual',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            supervisorActual.nombre,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Estadísticas
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatChip(
                    context,
                    'Total AST',
                    tecnico.totalASTGenerados?.toString() ?? '0',
                    Icons.assignment,
                    Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    context,
                    'Pendientes',
                    tecnico.totalASTPendientes?.toString() ?? '0',
                    Icons.pending_actions,
                    Colors.amber,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: color,
                        ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoReasignacion(
    AppUser tecnico,
    AppUser supervisorActual,
  ) async {
    String? supervisorNuevoUid;
    String? motivo;
    bool isProcessing = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reasignar Técnico'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info del técnico
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Técnico',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tecnico.nombre,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        tecnico.email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Supervisor actual
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supervisor Actual',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.blue[700],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        supervisorActual.nombre,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Icon(Icons.arrow_downward, color: Colors.grey),
                const SizedBox(height: 16),

                // Selector de supervisor nuevo
                DropdownButtonFormField<String>(
                  value: supervisorNuevoUid,
                  decoration: InputDecoration(
                    labelText: 'Nuevo Supervisor *',
                    prefixIcon: const Icon(Icons.supervisor_account),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _supervisores
                      .where((s) => s.uid != tecnico.supervisorUid)
                      .map((supervisor) {
                    return DropdownMenuItem(
                      value: supervisor.uid,
                      child: Text(supervisor.nombre),
                    );
                  }).toList(),
                  onChanged: isProcessing
                      ? null
                      : (value) {
                          setDialogState(() {
                            supervisorNuevoUid = value;
                          });
                        },
                ),
                const SizedBox(height: 16),

                // Motivo (opcional)
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Motivo (opcional)',
                    hintText: 'Ingrese el motivo de la reasignación',
                    prefixIcon: const Icon(Icons.note),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 3,
                  enabled: !isProcessing,
                  onChanged: (value) {
                    motivo = value.trim().isEmpty ? null : value.trim();
                  },
                ),
                const SizedBox(height: 16),

                // Advertencia
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Todos los AST pendientes del técnico serán reasignados al nuevo supervisor.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.orange[900],
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (isProcessing) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing
                  ? null
                  : () => Navigator.pop(context, false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: isProcessing || supervisorNuevoUid == null
                  ? null
                  : () async {
                      setDialogState(() {
                        isProcessing = true;
                      });

                      try {
                        final authProvider =
                            Provider.of<AuthProvider>(context, listen: false);
                        final adminUid = authProvider.currentUser!.uid;

                        await _reasignacionService.reasignarTecnico(
                          tecnicoUid: tecnico.uid,
                          supervisorNuevoUid: supervisorNuevoUid!,
                          adminUid: adminUid,
                          motivo: motivo,
                        );

                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      } catch (e) {
                        setDialogState(() {
                          isProcessing = false;
                        });

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('REASIGNAR'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Técnico reasignado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarDatos();
      }
    }
  }
}
