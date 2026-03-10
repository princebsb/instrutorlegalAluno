import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
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

  // Location
  String? _cidade;
  String? _estado;
  bool _usingLocation = false;

  // Pagination
  int _paginaAtual = 1;
  int _totalPaginas = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
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

      if (_usingLocation && _cidade != null) {
        queryParams['cidade'] = _cidade!;
      }
      if (_usingLocation && _estado != null) {
        queryParams['estado'] = _estado!;
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

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

      // Reverse geocode to get city/state
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _cidade = place.subAdministrativeArea ?? place.locality;
          _estado = place.administrativeArea;
          _usingLocation = true;
        });

        // Reload with location filter
        await _loadInstrutores();
      }
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
      _cidade = null;
      _estado = null;
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

  Future<void> _abrirWhatsApp(String telefone, String nome) async {
    // Clean phone number
    final phone = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    final fullPhone = phone.startsWith('55') ? phone : '55$phone';
    final message = Uri.encodeComponent(
      'Olá $nome! Encontrei seu perfil no Instrutor Legal e gostaria de agendar uma aula.',
    );
    final url = Uri.parse('https://wa.me/$fullPhone?text=$message');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o WhatsApp.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
                const SizedBox(height: 12),
                // Location button
                SizedBox(
                  width: double.infinity,
                  child: _isLoadingLocation
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _usingLocation ? null : _usarMinhaLocalizacao,
                          icon: const Icon(Icons.my_location, size: 20),
                          label: const Text('Usar minha localização'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            disabledBackgroundColor: AppColors.gray200,
                            disabledForegroundColor: AppColors.gray500,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                ),
                // Location chip
                if (_usingLocation && _cidade != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _estado != null
                                        ? '$_cidade - $_estado'
                                        : _cidade!,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _limparLocalizacao,
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                  ? 'Tente limpar o filtro de localização ou buscar por nome.'
                  : 'Tente usar sua localização para encontrar instrutores próximos.',
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
    final nome = instrutor['nome'] ?? 'Instrutor';
    final cidade = instrutor['cidade'] ?? '';
    final estado = instrutor['estado'] ?? '';
    final bairro = instrutor['bairro'] ?? '';
    final telefone = instrutor['telefone'] ?? '';

    // Build location string
    final locationParts = <String>[];
    if (bairro.toString().isNotEmpty) locationParts.add(bairro.toString());
    if (cidade.toString().isNotEmpty) locationParts.add(cidade.toString());
    if (estado.toString().isNotEmpty) locationParts.add(estado.toString());
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
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.gray500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                locationStr,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.gray600,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Badge de verificado (todos instrutores listados são aprovados)
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
                    'Instrutor Verificado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                if (telefone.toString().isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _abrirWhatsApp(
                        telefone.toString(),
                        nome.toString(),
                      ),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                if (telefone.toString().isNotEmpty)
                  const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.pop(instrutor),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Selecionar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
