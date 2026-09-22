import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminClientsScreen extends StatefulWidget {
  const AdminClientsScreen({super.key});

  @override
  State<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

enum _SortOption { name, points, date }

class _AdminClientsScreenState extends State<AdminClientsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filteredClients = [];

  String _searchQuery = '';
  _SortOption _currentSort = _SortOption.name;

  // Controllers
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClients() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('clientes')
          .select()
          .order('nombre', ascending: true);

      setState(() {
        _clients = List<Map<String, dynamic>>.from(response);
        _applyFiltersAndSorting();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar clientes: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSorting() {
    List<Map<String, dynamic>> temp = List.from(_clients);

    // Apply Search Filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      temp = temp.where((c) {
        final name = (c['nombre'] ?? '').toString().toLowerCase();
        final phone = (c['telefono'] ?? '').toString().toLowerCase();
        final email = (c['correo'] ?? '').toString().toLowerCase();
        final branch = (c['sucursal_preferida'] ?? '').toString().toLowerCase();

        return name.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            branch.contains(query);
      }).toList();
    }

    // Apply Sorting
    switch (_currentSort) {
      case _SortOption.name:
        temp.sort((a, b) {
          final nameA = (a['nombre'] ?? '').toString().toLowerCase();
          final nameB = (b['nombre'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;
      case _SortOption.points:
        temp.sort((a, b) {
          final ptsA = int.tryParse(a['puntos']?.toString() ?? '0') ?? 0;
          final ptsB = int.tryParse(b['puntos']?.toString() ?? '0') ?? 0;
          return ptsB.compareTo(ptsA); // Descending points
        });
        break;
      case _SortOption.date:
        temp.sort((a, b) {
          final dateAStr = a['created_at']?.toString() ?? '';
          final dateBStr = b['created_at']?.toString() ?? '';
          if (dateAStr.isEmpty) return 1;
          if (dateBStr.isEmpty) return -1;
          return DateTime.parse(dateBStr).compareTo(DateTime.parse(dateAStr)); // Newer first
        });
        break;
    }

    setState(() {
      _filteredClients = temp;
    });
  }

  // Helper Stats Computation
  int get _totalPoints {
    return _clients.fold(0, (sum, c) {
      return sum + (int.tryParse(c['puntos']?.toString() ?? '0') ?? 0);
    });
  }

  int get _redeemedCount {
    return _clients.where((c) => c['ultimo_canjeo'] != null).length;
  }

  // Gradients for Avatars
  LinearGradient _getRandomGradient(String id) {
    final int hash = id.hashCode;
    final gradients = [
      const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFFA855F7)], // Indigo to Purple
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFF43F5E)], // Pink to Rose
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)], // Blue to Cyan
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF3B82F6)], // Emerald to Blue
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)], // Amber to Red
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];
    return gradients[hash.abs() % gradients.length];
  }

  // Initials Extractor
  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // Helper for Copying Text
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Details Dialog Sheet
  void _showClientDetails(Map<String, dynamic> c) {
    final id = c['IDCliente']?.toString() ?? '';
    final name = c['nombre']?.toString() ?? 'Sin Nombre';
    final phone = c['telefono']?.toString() ?? '';
    final email = c['correo']?.toString() ?? '';
    final notes = c['notas']?.toString() ?? '';
    final branch = c['sucursal_preferida']?.toString() ?? '';
    final points = int.tryParse(c['puntos']?.toString() ?? '0') ?? 0;
    final meta = int.tryParse(c['puntos_meta']?.toString() ?? '6') ?? 6;
    final progress = meta > 0 ? (points / meta).clamp(0.0, 1.0) : 0.0;

    String regDate = 'No disponible';
    if (c['created_at'] != null) {
      try {
        final dt = DateTime.parse(c['created_at'].toString()).toLocal();
        regDate = intl.DateFormat('d \'de\' MMMM, yyyy - HH:mm', 'es').format(dt);
      } catch (_) {
        regDate = c['created_at'].toString();
      }
    }

    String lastCanjeo = 'Sin canjeos registrados';
    if (c['ultimo_canjeo'] != null) {
      try {
        final dt = DateTime.parse(c['ultimo_canjeo'].toString()).toLocal();
        lastCanjeo = intl.DateFormat('d \'de\' MMMM, yyyy - HH:mm', 'es').format(dt);
      } catch (_) {
        lastCanjeo = c['ultimo_canjeo'].toString();
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 12,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: _getRandomGradient(id),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(name),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (branch.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.store_rounded, size: 12, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    branch,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const Text(
                              'Sin sucursal preferida',
                              style: TextStyle(fontSize: 12, color: Colors.black38, fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Información de Contacto',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                _buildDetailContactRow(
                  icon: Icons.phone_android_rounded,
                  label: 'Teléfono',
                  value: phone,
                  onCopy: () => _copyToClipboard(phone, 'Teléfono'),
                ),
                const SizedBox(height: 12),
                _buildDetailContactRow(
                  icon: Icons.alternate_email_rounded,
                  label: 'Correo',
                  value: email,
                  onCopy: () => _copyToClipboard(email, 'Correo'),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Programa de Fidelidad',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Puntos acumulados:',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    Text(
                      '$points / $meta puntos',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
                if (progress >= 1.0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '¡Cliente listo para canjeo de premio!',
                        style: TextStyle(color: Colors.amber.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Último canjeo:',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    Text(
                      lastCanjeo,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Registro y Notas',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fecha de inscripción:',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    Text(
                      regDate,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Notas internas:',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Text(
                    notes.isNotEmpty ? notes : 'Sin notas registradas sobre el cliente.',
                    style: TextStyle(
                      color: notes.isNotEmpty ? Colors.black87 : Colors.black38,
                      fontSize: 13,
                      height: 1.4,
                      fontStyle: notes.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                _ClientHistorySection(client: c),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Cerrar Detalle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailContactRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onCopy,
  }) {
    final bool isEmpty = value.isEmpty;
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black45),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
            Text(
              isEmpty ? 'No registrado' : value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                color: isEmpty ? Colors.black38 : Colors.black87,
                fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (!isEmpty)
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.black54),
            splashRadius: 20,
            tooltip: 'Copiar',
          ),
      ],
    );
  }

  // Stats Card builder
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black38,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Clientes Registrados',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : Column(
                children: [
                  // Stat cards and Search section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      children: [
                        // Stats Row
                        Row(
                          children: [
                            _buildStatCard(
                              'Clientes',
                              _clients.length.toString(),
                              Icons.people_outline_rounded,
                              Colors.blueAccent,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              'Puntos Totales',
                              _totalPoints.toString(),
                              Icons.stars_rounded,
                              Colors.amber,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              'Canjes Realizados',
                              _redeemedCount.toString(),
                              Icons.check_circle_outline_rounded,
                              Colors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                                _applyFiltersAndSorting();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Buscar por nombre, teléfono, sucursal...',
                              hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                              prefixIcon: const Icon(Icons.search_rounded, color: Colors.black45, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: Colors.black54, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _applyFiltersAndSorting();
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Sort Chips Row
                        Row(
                          children: [
                            const Text(
                              'Ordenar por: ',
                              style: TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            _buildSortChip('Nombre', _SortOption.name),
                            const SizedBox(width: 8),
                            _buildSortChip('Puntos', _SortOption.points),
                            const SizedBox(width: 8),
                            _buildSortChip('Inscripción', _SortOption.date),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Clients List
                  Expanded(
                    child: _filteredClients.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_alt_rounded, size: 48, color: Colors.black.withValues(alpha: 0.15)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No se encontraron clientes.',
                                    style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filteredClients.length,
                            itemBuilder: (context, index) {
                              final client = _filteredClients[index];
                              return _ClientListCard(
                                client: client,
                                gradient: _getRandomGradient(client['IDCliente']?.toString() ?? ''),
                                initials: _getInitials(client['nombre']?.toString() ?? ''),
                                onTap: () => _showClientDetails(client),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSortChip(String label, _SortOption option) {
    final isSelected = _currentSort == option;
    return InkWell(
      onTap: () {
        setState(() {
          _currentSort = option;
          _applyFiltersAndSorting();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ClientListCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final LinearGradient gradient;
  final String initials;
  final VoidCallback onTap;

  const _ClientListCard({
    required this.client,
    required this.gradient,
    required this.initials,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = client['nombre']?.toString() ?? 'Sin Nombre';
    final phone = client['telefono']?.toString() ?? '';
    final branch = client['sucursal_preferida']?.toString() ?? '';
    final points = int.tryParse(client['puntos']?.toString() ?? '0') ?? 0;
    final meta = int.tryParse(client['puntos_meta']?.toString() ?? '6') ?? 6;
    final progress = meta > 0 ? (points / meta).clamp(0.0, 1.0) : 0.0;

    String dateStr = '';
    if (client['created_at'] != null) {
      try {
        final dt = DateTime.parse(client['created_at'].toString()).toLocal();
        dateStr = intl.DateFormat('d MMM yyyy').format(dt);
      } catch (_) {
        dateStr = client['created_at'].toString();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (dateStr.isNotEmpty)
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black38,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Subtitle: Phone or email
                        if (phone.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.phone_android_rounded, size: 12, color: Colors.black38),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          )
                        else
                          const Text(
                            'Sin teléfono registrado',
                            style: TextStyle(fontSize: 11, color: Colors.black38, fontStyle: FontStyle.italic),
                          ),

                        const SizedBox(height: 8),

                        // Fidelity progress and branch row
                        Row(
                          children: [
                            if (branch.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.store_rounded, size: 10, color: Colors.black54),
                                    const SizedBox(width: 3),
                                    Text(
                                      branch,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            
                            // Points badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: progress >= 1.0 ? Colors.amber.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.stars_rounded,
                                    size: 10,
                                    color: progress >= 1.0 ? Colors.amber.shade800 : Colors.black54,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$points / $meta pts',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: progress >= 1.0 ? Colors.amber.shade800 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Progress Bar indicator
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0 ? Colors.amber.shade700 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientHistorySection extends StatefulWidget {
  final Map<String, dynamic> client;
  const _ClientHistorySection({required this.client});

  @override
  State<_ClientHistorySection> createState() => _ClientHistorySectionState();
}

class _ClientHistorySectionState extends State<_ClientHistorySection> {
  final _supabase = Supabase.instance.client;
  String _selectedTab = 'citas'; // 'citas', 'servicios', 'productos'
  late Future<Map<String, dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<Map<String, dynamic>> _fetchHistory() async {
    final clientEmail = widget.client['correo']?.toString().trim() ?? '';
    final clientPhone = widget.client['telefono']?.toString().trim() ?? '';
    final clientId = widget.client['IDCliente']?.toString().trim() ?? '';

    // 1. Fetch appointments
    var appointmentsQuery = _supabase
        .from('Citas')
        .select('fecha, horaInicio, Servicios, completada, estatus, MuestraMonto, MontoACobrar')
        .eq('clienteID', clientId);

    // 2. Fetch services from FinanzasPersonal
    var servicesQuery = _supabase
        .from('FinanzasPersonal')
        .select('fecha, servicios_detalle, total, sucursal, formadepago, cliente_id, cliente_email, cliente_telefono');

    // 3. Fetch products from OrdenesProductos
    var productsQuery = _supabase
        .from('OrdenesProductos')
        .select('fecha, productos_detalle, suma_productos, sucursal, formadepago, cliente_id, cliente_email, cliente_telefono');

    List<String> filters = [];
    if (clientId.isNotEmpty) filters.add('cliente_id.eq.$clientId');
    if (clientEmail.isNotEmpty) filters.add('cliente_email.eq.$clientEmail');
    if (clientPhone.isNotEmpty) filters.add('cliente_telefono.eq.$clientPhone');

    if (filters.isNotEmpty) {
      final orFilter = filters.join(',');
      servicesQuery = servicesQuery.or(orFilter);
      productsQuery = productsQuery.or(orFilter);
    } else {
      servicesQuery = servicesQuery.eq('cliente_id', 'dummy');
      productsQuery = productsQuery.eq('cliente_id', 'dummy');
    }

    final results = await Future.wait([
      appointmentsQuery.order('fecha', ascending: false),
      servicesQuery.order('fecha', ascending: false),
      productsQuery.order('fecha', ascending: false),
    ]);

    return {
      'appointments': results[0] as List,
      'services': results[1] as List,
      'products': results[2] as List,
    };
  }

  Widget _buildAppointmentItem(Map<String, dynamic> item) {
    final date = item['fecha'] ?? '';
    final time = item['horaInicio'] ?? '';
    final services = item['Servicios'] ?? 'Servicio';
    final isCompleted = item['completada'] == true || item['estatus']?.toString().toLowerCase() == 'completada';
    final price = item['MontoACobrar'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  services,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$date  •  $time',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCompleted ? 'Completada' : 'Pendiente',
                  style: TextStyle(
                    color: isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem(Map<String, dynamic> item) {
    final date = item['fecha'] != null ? item['fecha'].toString().substring(0, 10) : '';
    final total = item['total'] ?? 0.0;
    final sucursal = item['sucursal'] ?? 'General';
    final payment = item['formadepago'] ?? 'Efectivo';

    List<dynamic> detail = [];
    if (item['servicios_detalle'] is List) {
      detail = item['servicios_detalle'] as List;
    }
    final servicesStr = detail.map((e) => e['name'] ?? 'Servicio').join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.spa_rounded, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servicesStr.isNotEmpty ? servicesStr : 'Servicios Realizados',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$date  •  $sucursal  •  $payment',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          Text('\$$total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> item) {
    final date = item['fecha'] != null ? item['fecha'].toString().substring(0, 10) : '';
    final total = item['suma_productos'] ?? 0.0;
    final sucursal = item['sucursal'] ?? 'General';
    final payment = item['formadepago'] ?? 'Efectivo';

    List<dynamic> detail = [];
    if (item['productos_detalle'] is List) {
      detail = item['productos_detalle'] as List;
    }
    final productsStr = detail.map((e) => '${e['nombre'] ?? 'Producto'} (x${e['cantidad'] ?? 1})').join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_bag_rounded, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productsStr.isNotEmpty ? productsStr : 'Orden de Productos',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$date  •  $sucursal  •  $payment',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          Text('\$$total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(child: CircularProgressIndicator(color: Colors.black)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'Error al cargar el historial: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final List appointments = data['appointments'] ?? [];
        final List services = data['services'] ?? [];
        final List products = data['products'] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Historial de Actividad',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 12),

            // Custom Tab Segment Selector
            Row(
              children: [
                _buildTabButton('Citas', appointments.length, 'citas'),
                const SizedBox(width: 8),
                _buildTabButton('Servicios', services.length, 'servicios'),
                const SizedBox(width: 8),
                _buildTabButton('Productos', products.length, 'productos'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Content
            _buildTabContent(appointments, services, products),
          ],
        );
      },
    );
  }

  Widget _buildTabButton(String label, int count, String tabKey) {
    final isSelected = _selectedTab == tabKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = tabKey),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.black : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white24 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(List appointments, List services, List products) {
    if (_selectedTab == 'citas') {
      if (appointments.isEmpty) return _buildEmptyState('No hay citas programadas');
      return Column(children: appointments.map((item) => _buildAppointmentItem(Map<String, dynamic>.from(item))).toList());
    } else if (_selectedTab == 'servicios') {
      if (services.isEmpty) return _buildEmptyState('No hay servicios registrados');
      return Column(children: services.map((item) => _buildServiceItem(Map<String, dynamic>.from(item))).toList());
    } else {
      if (products.isEmpty) return _buildEmptyState('No hay productos comprados');
      return Column(children: products.map((item) => _buildProductItem(Map<String, dynamic>.from(item))).toList());
    }
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Text(
        message,
        style: const TextStyle(color: Colors.black38, fontSize: 12, fontStyle: FontStyle.italic),
      ),
    );
  }
}
