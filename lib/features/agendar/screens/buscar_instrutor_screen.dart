import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';

class BuscarInstrutorScreen extends StatefulWidget {
  const BuscarInstrutorScreen({super.key});

  @override
  State<BuscarInstrutorScreen> createState() => _BuscarInstrutorScreenState();
}

class _BuscarInstrutorScreenState extends State<BuscarInstrutorScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _instrutores = [];
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  String? _errorMessage;

  // Região do aluno (usada para filtrar por cidade/estado)
  String? _cidadeAluno;
  String? _estadoAluno;

  // Localização GPS
  double? _latitude;
  double? _longitude;
  bool _usingLocation = false;

  // Pagination
  int _paginaAtual = 1;
  int _totalPaginas = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _carregarRegiaoAluno();
  }

  void _carregarRegiaoAluno() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user != null) {
      _cidadeAluno = user.cidade;
      _estadoAluno = user.estado;
    }
    _loadInstrutores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstrutores({bool loadMore = false}) async {
    if (loadMore) {
      if (_paginaAtual >= _totalPaginas) return;
      setState(() => _isLoadingMore = true);
      _paginaAtual++;
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _paginaAtual = 1;
      });
    }

    try {
      final queryParams = <String, String>{
        'pagina': _paginaAtual.toString(),
        'limite': '20',
      };

      final nome = _searchController.text.trim();
      if (nome.isNotEmpty) {
        queryParams['nome'] = nome;
      }

      // Se está usando localização GPS, enviar latitude/longitude
      if (_usingLocation && _latitude != null && _longitude != null) {
        queryParams['latitude'] = _latitude.toString();
        queryParams['longitude'] = _longitude.toString();
        queryParams['raio'] = '15'; // 15km de raio
      } else {
        // Caso contrário, filtrar pela região do aluno
        if (_cidadeAluno != null && _cidadeAluno!.isNotEmpty) {
          queryParams['cidade'] = _cidadeAluno!;
        }
        if (_estadoAluno != null && _estadoAluno!.isNotEmpty) {
          queryParams['estado'] = _estadoAluno!;
        }
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      debugPrint('>>> Buscando instrutores: ${ApiEndpoints.listaInstrutores}?$queryString');

      final response = await _api.get(
        '${ApiEndpoints.listaInstrutores}?$queryString',
        requiresAuth: false,
      );

      final List<dynamic> data = response is List
          ? response
          : (response['instrutores'] ?? []);

      final paginacao = response is Map ? response['paginacao'] : null;

      setState(() {
        if (loadMore) {
          _instrutores.addAll(
            data.map((i) => Map<String, dynamic>.from(i)).toList(),
          );
        } else {
          _instrutores = data.map((i) => Map<String, dynamic>.from(i)).toList();
        }

        if (paginacao != null) {
          _totalPaginas = paginacao['totalPaginas'] ?? 1;
          _paginaAtual = paginacao['paginaAtual'] ?? 1;
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar instrutores: $e');
      if (!loadMore) {
        setState(() {
          _errorMessage = 'Não foi possível carregar os instrutores. Tente novamente.';
          _instrutores = [];
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _usarMinhaLocalizacao() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ative os serviços de localização do seu dispositivo.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permissão de localização negada.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permissão de localização permanentemente negada. Ative nas configurações do dispositivo.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _usingLocation = true;
      });

      // Reload with location filter
      await _loadInstrutores();
    } catch (e) {
      debugPrint('Erro ao obter localização: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao obter sua localização. Tente novamente.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _limparLocalizacao() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _usingLocation = false;
    });
    _loadInstrutores();
  }

  void _onSearchChanged(String query) {
    // Debounce: reload after user stops typing
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _searchController.text == query) {
        _loadInstrutores();
      }
    });
  }

  String _formatarCategorias(dynamic categorias) {
    if (categorias == null) return 'B';
    if (categorias is List) {
      return categorias.map((c) => c.toString()).join(', ');
    }
    return categorias.toString();
  }

  String _formatarDistancia(dynamic distancia) {
    if (distancia == null) return '';
    final dist = double.tryParse(distancia.toString()) ?? 0;
    if (dist < 1) {
      return '${(dist * 1000).toStringAsFixed(0)}m';
    }
    return '${dist.toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Buscar Instrutor'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar + location button
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.white,
            child: Column(
              children: [
                CustomTextField(
                  controller: _searchController,
                  hint: 'Buscar por nome...',
                  prefixIcon: const Icon(Icons.search),
                  onChanged: _onSearchChanged,
                ),
                // Região do aluno (quando NÃO usando GPS)
                if (!_usingLocation && (_cidadeAluno != null || _estadoAluno != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.gray600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Região: ${_cidadeAluno ?? ''}${_cidadeAluno != null && _estadoAluno != null ? ' - ' : ''}${_estadoAluno ?? ''}',
                            style: const TextStyle(
                              color: AppColors.gray600,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  '${_instrutores.length} instrutor(es) encontrado(s)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorState()
                    : _instrutores.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadInstrutores,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _instrutores.length + (_paginaAtual < _totalPaginas ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                if (index == _instrutores.length) {
                                  return _buildLoadMoreButton();
                                }
                                return _buildInstrutorCard(_instrutores[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.gray400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInstrutores,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.gray400,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum instrutor encontrado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _usingLocation
                  ? 'Não encontramos instrutores em até 15km. Tente buscar por nome ou desative o filtro de localização.'
                  : _cidadeAluno != null || _estadoAluno != null
                      ? 'Não encontramos instrutores na sua região. Tente usar sua localização para buscar por proximidade.'
                      : 'Atualize seu perfil com sua cidade ou use sua localização para encontrar instrutores próximos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: () => _loadInstrutores(loadMore: true),
                child: const Text('Carregar mais'),
              ),
      ),
    );
  }

  Widget _buildInstrutorCard(Map<String, dynamic> instrutor) {
    final nome = instrutor['nome_completo'] ?? instrutor['nome'] ?? 'Instrutor';
    final cep = instrutor['cep'] ?? '';
    final endereco = instrutor['endereco'] ?? '';
    final cidade = instrutor['cidade'] ?? '';
    final estado = instrutor['estado'] ?? '';
    final categorias = instrutor['categorias_cnh'];
    final tipoVeiculo = instrutor['tipo_veiculo'];
    final distancia = instrutor['distancia_km'];

    // Build location string
    final locationParts = <String>[];
    if (endereco.toString().isNotEmpty) locationParts.add(endereco.toString());
    if (cidade.toString().isNotEmpty) locationParts.add(cidade.toString());
    if (estado.toString().isNotEmpty) locationParts.add(estado.toString());
    if (cep.toString().isNotEmpty) locationParts.add('CEP: ${cep.toString()}');
    final locationStr = locationParts.join(', ');

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      nome.toString().isNotEmpty ? nome[0].toUpperCase() : 'I',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (locationStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.gray500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                locationStr,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.gray600,
                                    ),
                                maxLines: 3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Distância (quando usando GPS)
                if (_usingLocation && distancia != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.near_me,
                          size: 12,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatarDistancia(distancia),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Badges row: Verificado, Categoria, Tipo de Veículo
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Badge de verificado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Verificado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de categoria CNH
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cat. ${_formatarCategorias(categorias)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de tipo de veículo (se tiver)
                if (tipoVeiculo != null && tipoVeiculo.toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gray200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 14,
                          color: AppColors.gray700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tipoVeiculo.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Action button - Selecionar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.pop(instrutor),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Selecionar Instrutor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
