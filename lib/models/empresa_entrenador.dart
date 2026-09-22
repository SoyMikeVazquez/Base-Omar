class EmpresaEntrenador {
  final String idEmpresa;
  final DateTime createdAt;
  final String nombre;
  final String correoElectronico;
  final int numeroClientes;
  final DateTime? fechaCorte;
  final double calificacion;
  final List<dynamic> resenas;

  EmpresaEntrenador({
    required this.idEmpresa,
    required this.createdAt,
    required this.nombre,
    required this.correoElectronico,
    required this.numeroClientes,
    this.fechaCorte,
    required this.calificacion,
    required this.resenas,
  });

  /// Factory method to build a model from Supabase JSON map
  factory EmpresaEntrenador.fromJson(Map<String, dynamic> json) {
    return EmpresaEntrenador(
      idEmpresa: json['IDEmpresa']?.toString() ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      nombre: json['nombre']?.toString() ?? '',
      correoElectronico: json['correo_electronico']?.toString() ?? '',
      numeroClientes: int.tryParse(json['numero_clientes']?.toString() ?? '0') ?? 0,
      fechaCorte: json['fecha_corte'] != null ? DateTime.parse(json['fecha_corte']) : null,
      calificacion: double.tryParse(json['calificacion']?.toString() ?? '0.0') ?? 0.0,
      resenas: json['reseñas'] is List ? json['reseñas'] : [],
    );
  }

  /// Converts the model to a JSON map suitable for Supabase inserts or updates
  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'correo_electronico': correoElectronico,
      'numero_clientes': numeroClientes,
      if (fechaCorte != null) 
        'fecha_corte': "${fechaCorte!.year.toString().padLeft(4, '0')}-${fechaCorte!.month.toString().padLeft(2, '0')}-${fechaCorte!.day.toString().padLeft(2, '0')}",
      'calificacion': calificacion,
      'reseñas': resenas,
    };
  }
}
