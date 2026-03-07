class UserModel {
  final String id;
  final String? alunoId; // ID na tabela alunos
  final String nomeCompleto;
  final String email;
  final String? telefone;
  final String? cpf;
  final String? dataNascimento;
  final String? cep;
  final String? endereco;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String? cidade;
  final String? estado;
  final String tipoUsuario;
  final String? fotoUrl;
  final bool ativo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Dados específicos do aluno
  final bool? possuiCnh;
  final String? categoriaPretendida;

  UserModel({
    required this.id,
    this.alunoId,
    required this.nomeCompleto,
    required this.email,
    this.telefone,
    this.cpf,
    this.dataNascimento,
    this.cep,
    this.endereco,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.estado,
    required this.tipoUsuario,
    this.fotoUrl,
    this.ativo = true,
    this.createdAt,
    this.updatedAt,
    this.possuiCnh,
    this.categoriaPretendida,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      alunoId: json['aluno_id']?.toString(),
      nomeCompleto: json['nome_completo'] ?? json['nomeCompleto'] ?? json['nome'] ?? '',
      email: json['email'] ?? '',
      telefone: json['telefone'],
      cpf: json['cpf'],
      dataNascimento: json['data_nascimento'] ?? json['dataNascimento'],
      cep: json['cep'],
      endereco: json['endereco'],
      numero: json['numero'],
      complemento: json['complemento'],
      bairro: json['bairro'],
      cidade: json['cidade'],
      estado: json['estado'],
      tipoUsuario: json['tipo_usuario'] ?? json['tipoUsuario'] ?? json['tipo'] ?? 'aluno',
      fotoUrl: json['foto_url'] ?? json['fotoUrl'],
      ativo: json['ativo'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      possuiCnh: json['possui_cnh'] ?? json['possuiCnh'],
      categoriaPretendida:
          json['categoria_pretendida'] ?? json['categoriaPretendida'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'aluno_id': alunoId,
      'nome_completo': nomeCompleto,
      'email': email,
      'telefone': telefone,
      'cpf': cpf,
      'data_nascimento': dataNascimento,
      'cep': cep,
      'endereco': endereco,
      'numero': numero,
      'complemento': complemento,
      'bairro': bairro,
      'cidade': cidade,
      'estado': estado,
      'tipo_usuario': tipoUsuario,
      'foto_url': fotoUrl,
      'ativo': ativo,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'possui_cnh': possuiCnh,
      'categoria_pretendida': categoriaPretendida,
    };
  }

  UserModel copyWith({
    String? id,
    String? alunoId,
    String? nomeCompleto,
    String? email,
    String? telefone,
    String? cpf,
    String? dataNascimento,
    String? cep,
    String? endereco,
    String? numero,
    String? complemento,
    String? bairro,
    String? cidade,
    String? estado,
    String? tipoUsuario,
    String? fotoUrl,
    bool? ativo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? possuiCnh,
    String? categoriaPretendida,
  }) {
    return UserModel(
      id: id ?? this.id,
      alunoId: alunoId ?? this.alunoId,
      nomeCompleto: nomeCompleto ?? this.nomeCompleto,
      email: email ?? this.email,
      telefone: telefone ?? this.telefone,
      cpf: cpf ?? this.cpf,
      dataNascimento: dataNascimento ?? this.dataNascimento,
      cep: cep ?? this.cep,
      endereco: endereco ?? this.endereco,
      numero: numero ?? this.numero,
      complemento: complemento ?? this.complemento,
      bairro: bairro ?? this.bairro,
      cidade: cidade ?? this.cidade,
      estado: estado ?? this.estado,
      tipoUsuario: tipoUsuario ?? this.tipoUsuario,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      possuiCnh: possuiCnh ?? this.possuiCnh,
      categoriaPretendida: categoriaPretendida ?? this.categoriaPretendida,
    );
  }

  String get primeiroNome => nomeCompleto.split(' ').first;

  String get iniciais {
    final partes = nomeCompleto.split(' ');
    if (partes.length >= 2) {
      return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
    }
    return nomeCompleto.isNotEmpty ? nomeCompleto[0].toUpperCase() : 'U';
  }

  String get telefoneFormatado {
    if (telefone == null || telefone!.length < 10) return telefone ?? '';
    final numbers = telefone!.replaceAll(RegExp(r'\D'), '');
    if (numbers.length == 11) {
      return '(${numbers.substring(0, 2)}) ${numbers.substring(2, 7)}-${numbers.substring(7)}';
    } else if (numbers.length == 10) {
      return '(${numbers.substring(0, 2)}) ${numbers.substring(2, 6)}-${numbers.substring(6)}';
    }
    return telefone!;
  }

  String get cpfFormatado {
    if (cpf == null || cpf!.length != 11) return cpf ?? '';
    return '${cpf!.substring(0, 3)}.${cpf!.substring(3, 6)}.${cpf!.substring(6, 9)}-${cpf!.substring(9)}';
  }
}
