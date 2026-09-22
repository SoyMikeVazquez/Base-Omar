import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_provider.dart';
import 'add_staff_screen.dart';

class PersonalListScreen extends StatefulWidget {
  const PersonalListScreen({super.key});

  @override
  State<PersonalListScreen> createState() => _PersonalListScreenState();
}

class _PersonalListScreenState extends State<PersonalListScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _checkSuperAdmin() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final res = await _supabase.from('users').select('superAdmin').eq('IDUser', user.id).maybeSingle();
        if (res != null && res['superAdmin'] == true) {
          _isSuperAdmin = true;
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _fetchStaff() async {
    setState(() => _isLoading = true);
    try {
      await _checkSuperAdmin();
      final response = await _supabase
          .from('Personal')
          .select()
          .order('nombre', ascending: true);
          
      final staffData = List<Map<String, dynamic>>.from(response);

      if (staffData.isNotEmpty) {
        final userIds = staffData
            .map((e) => e['userID']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .toList();
        if (userIds.isNotEmpty) {
          try {
            final usersResponse = await _supabase
                .from('users')
                .select('IDUser, password, correo')
                .inFilter('IDUser', userIds);
            
            final usersData = List<Map<String, dynamic>>.from(usersResponse);
            for (var staff in staffData) {
              final match = usersData.firstWhere((u) => u['IDUser'] == staff['userID'], orElse: () => {});
              if (match.isNotEmpty) {
                if (match['password'] != null && match['password'].toString().isNotEmpty) {
                  if (staff['password'] == null || staff['password'].toString().isEmpty) {
                    staff['password'] = match['password'];
                  }
                }
                if (match['correo'] != null && match['correo'].toString().isNotEmpty) {
                  if (staff['correo'] == null || staff['correo'].toString().isEmpty) {
                    staff['correo'] = match['correo'];
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
          
      setState(() => _staffList = staffData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar personal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStaff(String? userId) async {
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID de usuario inválido para eliminar.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Personal'),
        content: const Text('¿Estás seguro de que deseas eliminar este miembro del personal?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // Delete using the main relationship column 'userID' instead of redundant 'id'
      await _supabase.from('Personal').delete().eq('userID', userId);
      // Clean up the users table account as well
      await _supabase.from('users').delete().eq('IDUser', userId);
      _fetchStaff();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              onRefresh: _fetchStaff,
              color: Colors.black,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personal Registrado',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Gestiona los miembros de tu equipo',
                                style: TextStyle(color: Colors.black54, fontSize: 14),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddStaffScreen()),
                              ).then((_) => _fetchStaff());
                            },
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Nuevo', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_staffList.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No hay personal registrado')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final staff = _staffList[index];
                            return _StaffCard(
                              staff: staff,
                              isSuperAdmin: _isSuperAdmin,
                              onEdit: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddStaffScreen(editStaff: staff),
                                  ),
                                ).then((_) => _fetchStaff());
                              },
                              onDelete: () => _deleteStaff(staff['userID']),
                            );
                          },
                          childCount: _staffList.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }
}

class _StaffCard extends StatefulWidget {
  final Map<String, dynamic> staff;
  final bool isSuperAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StaffCard({
    required this.staff,
    required this.onEdit,
    required this.onDelete,
    this.isSuperAdmin = false,
  });

  @override
  State<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends State<_StaffCard> {
  bool _isPasswordVisible = false;
  bool _isAuthenticating = false;

  Future<void> _handlePasswordToggle() async {
    if (_isPasswordVisible) {
      setState(() => _isPasswordVisible = false);
      return;
    }

    setState(() => _isAuthenticating = true);

    try {
      final LocalAuthentication auth = LocalAuthentication();
      bool canCheckBiometrics = false;
      bool isDeviceSupported = false;

      try {
        canCheckBiometrics = await auth.canCheckBiometrics;
        isDeviceSupported = await auth.isDeviceSupported();
      } catch (_) {
        canCheckBiometrics = false;
        isDeviceSupported = false;
      }

      bool authenticated = false;

      if (canCheckBiometrics || isDeviceSupported) {
        try {
          authenticated = await auth.authenticate(
            localizedReason: 'Autentícate para ver la contraseña del personal',
            biometricOnly: false,
          );
        } catch (_) {
          authenticated = false;
        }
      }

      if (authenticated) {
        if (mounted) {
          setState(() {
            _isPasswordVisible = true;
            _isAuthenticating = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _isAuthenticating = false);
        await _promptForAccountPassword();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAuthenticating = false);
        await _promptForAccountPassword();
      }
    }
  }

  Future<void> _promptForAccountPassword() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final passwordCtrl = TextEditingController();
    bool isVerifying = false;
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.black),
                  SizedBox(width: 8),
                  Text('Confirmar Identidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Por favor ingresa tu contraseña de usuario para visualizar la contraseña del personal:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Tu contraseña',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: errorMessage,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  if (isVerifying) ...[
                    const SizedBox(height: 12),
                    const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final inputPwd = passwordCtrl.text.trim();
                          if (inputPwd.isEmpty) {
                            setDialogState(() => errorMessage = 'Ingresa tu contraseña');
                            return;
                          }
                          setDialogState(() {
                            isVerifying = true;
                            errorMessage = null;
                          });

                          try {
                            bool isValid = false;
                            final supabase = Supabase.instance.client;
                            final currentUser = supabase.auth.currentUser;

                            // 1. Try auth signInWithPassword if current user has email
                            if (currentUser?.email != null) {
                              try {
                                final authResp = await supabase.auth.signInWithPassword(
                                  email: currentUser!.email!,
                                  password: inputPwd,
                                );
                                if (authResp.user != null) {
                                  isValid = true;
                                }
                              } catch (_) {}
                            }

                            // 2. Check DB users / Personal table for logged in user ID
                            if (!isValid && currentUser != null) {
                              final userCheck = await supabase
                                  .from('users')
                                  .select('password')
                                  .eq('IDUser', currentUser.id)
                                  .maybeSingle();

                              if (userCheck != null && userCheck['password'] == inputPwd) {
                                isValid = true;
                              } else {
                                final personalCheck = await supabase
                                    .from('Personal')
                                    .select('password')
                                    .eq('userID', currentUser.id)
                                    .maybeSingle();
                                if (personalCheck != null && personalCheck['password'] == inputPwd) {
                                  isValid = true;
                                }
                              }
                            }

                            // 3. Check SessionProvider ID
                            if (!isValid && session.userId != null) {
                              final userCheck = await supabase
                                  .from('users')
                                  .select('password')
                                  .eq('IDUser', session.userId!)
                                  .maybeSingle();
                              if (userCheck != null && userCheck['password'] == inputPwd) {
                                isValid = true;
                              }
                            }

                            if (isValid) {
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } else {
                              setDialogState(() {
                                isVerifying = false;
                                errorMessage = 'Contraseña incorrecta';
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              isVerifying = false;
                              errorMessage = 'Error de verificación';
                            });
                          }
                        },
                  child: const Text('Verificar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      setState(() => _isPasswordVisible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final hasPhoto = staff['foto_perfil'] != null && staff['foto_perfil'].toString().isNotEmpty;
    final mostrarFoto = staff['mostrar_foto'] ?? true;
    final sucursal = staff['sucursal'] ?? 'Sin Sucursal';
    final correo = staff['correo']?.toString();
    final hasCorreo = correo != null && correo.isNotEmpty;
    final hasCert = staff['tiene_certificado'] ?? false;
    final rawPassword = staff['password']?.toString();
    final hasPassword = rawPassword != null && rawPassword.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Profile image
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: 70,
                height: 70,
                color: Colors.grey[100],
                child: (hasPhoto && mostrarFoto)
                    ? Image.network(staff['foto_perfil'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => _iconPlaceholder())
                    : _iconPlaceholder(),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff['nombre'] ?? 'Sin Nombre',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  if (hasCorreo) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 13, color: Colors.black45),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            correo,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.black45),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sucursal,
                          style: const TextStyle(fontSize: 13, color: Colors.black45),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (hasCert)
                        _badge('Certificado', Colors.blue.withOpacity(0.1), Colors.blue[700]!),
                      if (hasCert) const SizedBox(width: 6),
                      _badge(staff['TipoPersonal'] ?? 'Personal', Colors.black.withOpacity(0.05), Colors.black54),
                    ],
                  ),
                  if (hasPassword) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.key_outlined, size: 14, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            _isPasswordVisible ? rawPassword : '••••••••',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isPasswordVisible ? Colors.black : Colors.black54,
                              letterSpacing: _isPasswordVisible ? 0 : 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _isAuthenticating ? null : _handlePasswordToggle,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: _isAuthenticating
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : Icon(
                                      _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 18,
                                      color: Colors.black87,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 22),
                  onPressed: widget.onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _iconPlaceholder() => const Icon(Icons.person_outline, size: 30, color: Colors.black26);
}
