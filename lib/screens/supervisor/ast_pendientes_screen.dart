import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/ast_model.dart';
import '../../providers/auth_provider.dart';
import 'revisar_ast_screen.dart';

class ASTPendientesScreen extends StatefulWidget {
  const ASTPendientesScreen({super.key});

  @override
  State<ASTPendientesScreen> createState() => _ASTPendientesScreenState();
}

class _ASTPendientesScreenState extends State<ASTPendientesScreen> {
  String _filtroTecnico = 'todos';
  String _ordenamiento = 'fecha_desc'; // fecha_desc, fecha_asc, tecnico

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final supervisorUid = authProvider.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AST Pendientes'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            onSelected: (value) {
              setState(() => _ordenamiento = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'fecha_desc',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward),
                    SizedBox(width: 8),
                    Text('Más recientes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'fecha_asc',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward),
                    SizedBox(width: 8),
                    Text('Más antiguos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'tecnico',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Por técnico'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de información
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.orange.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.pending_actions, color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AST Pendientes de Aprobación',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Revisa y aprueba o rechaza los AST de tus técnicos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filtros
          _buildFiltros(supervisorUid),

          // Lista de AST
          Expanded(
            child: _buildListaAST(supervisorUid),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros(String supervisorUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ast')
          .where('supervisorAsignadoUid', isEqualTo: supervisorUid)
          .where('estado', isEqualTo: 'pendiente')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        // Obtener técnicos únicos
        final tecnicos = <String, String>{};
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final tecnicoUid = data['tecnicoUid'] as String;
          final tecnicoNombre = data['tecnicoNombre'] as String;
          if (!tecnicos.containsKey(tecnicoUid)) {
            tecnicos[tecnicoUid] = tecnicoNombre;
          }
        }

        if (tecnicos.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Filtrar:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Todos (${snapshot.data!.docs.length})'),
                        selected: _filtroTecnico == 'todos',
                        onSelected: (selected) {
                          setState(() => _filtroTecnico = 'todos');
                        },
                      ),
                      const SizedBox(width: 8),
                      ...tecnicos.entries.map((entry) {
                        final count = snapshot.data!.docs
                            .where((doc) =>
                                (doc.data() as Map<String, dynamic>)['tecnicoUid'] ==
                                entry.key)
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${entry.value} ($count)'),
                            selected: _filtroTecnico == entry.key,
                            onSelected: (selected) {
                              setState(() => _filtroTecnico = entry.key);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListaAST(String supervisorUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ast')
          .where('supervisorAsignadoUid', isEqualTo: supervisorUid)
          .where('estado', isEqualTo: 'pendiente')
          .orderBy(
            'fechaGeneracion',
            descending: _ordenamiento == 'fecha_desc',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar los AST',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay AST pendientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Todos los AST han sido revisados',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        // Filtrar por técnico si es necesario
        var docs = snapshot.data!.docs;
        if (_filtroTecnico != 'todos') {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['tecnicoUid'] == _filtroTecnico;
          }).toList();
        }

        // Ordenar si es necesario
        if (_ordenamiento == 'tecnico') {
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            return (dataA['tecnicoNombre'] as String)
                .compareTo(dataB['tecnicoNombre'] as String);
          });
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.filter_alt_off,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay resultados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No se encontraron AST con los filtros aplicados',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
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
    final tiempoTranscurrido = DateTime.now().difference(ast.fechaGeneracion);

    String tiempoTexto;
    Color tiempoColor;

    if (tiempoTranscurrido.inHours < 1) {
      tiempoTexto = 'Hace ${tiempoTranscurrido.inMinutes} minutos';
      tiempoColor = Colors.green;
    } else if (tiempoTranscurrido.inHours < 24) {
      tiempoTexto = 'Hace ${tiempoTranscurrido.inHours} horas';
      tiempoColor = Colors.orange;
    } else {
      tiempoTexto = 'Hace ${tiempoTranscurrido.inDays} días';
      tiempoColor = tiempoTranscurrido.inDays > 3 ? Colors.red : Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _abrirDetalleAST(ast),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.pending_actions,
                      color: Colors.orange.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ast.numeroMTA,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.engineering, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                ast.tecnicoNombre,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ast.direccion,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(ast.fechaGeneracion),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tiempoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tiempoColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      tiempoTexto,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tiempoColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      Icons.work_outline,
                      '${ast.actividades.length} actividades',
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.warning,
                      '${ast.riesgos.length} riesgos',
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _abrirDetalleAST(AST ast) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RevisarASTScreen(ast: ast),
      ),
    );
  }
}
