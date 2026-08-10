import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hall_of_fame_selector_screen.dart';
import '../../utils/image_compressor.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final List<Map<String, dynamic>?> hallOfFame;

  const EditProfileScreen({
    super.key,
    required this.userProfile,
    required this.hallOfFame,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _emailController;
  List<String> _selectedPlatforms = [];
  final List<String> _allPlatforms = [
    'pc',
    'linux',
    'playstation',
    'xbox',
    'switch',
    'wii',
    'mac',
    'android',
  ];
  late List<Map<String, dynamic>?> _localHallOfFame;

  bool _isLoading = false;

  // Local state for UI preview before saving
  String? _avatarUrl;
  String? _bannerUrl;

  // Local bytes if user selects a new image
  Uint8List? _newAvatarBytes;
  String? _newAvatarExt;
  Uint8List? _newBannerBytes;
  String? _newBannerExt;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.userProfile['username'] ?? '',
    );
    _displayNameController = TextEditingController(
      text:
          widget.userProfile['display_name'] ??
          widget.userProfile['username'] ??
          '',
    );
    _bioController = TextEditingController(
      text: widget.userProfile['bio'] ?? '',
    );
    _emailController = TextEditingController(
      text: Supabase.instance.client.auth.currentUser!.email ?? '',
    );
    _selectedPlatforms = List<String>.from(
      widget.userProfile['platforms'] ?? [],
    );
    _localHallOfFame = List.from(widget.hallOfFame);

    // Reordenar _allPlatforms para que los seleccionados aparezcan primero en su orden guardado
    for (final p in _selectedPlatforms.reversed) {
      if (_allPlatforms.contains(p)) {
        _allPlatforms.remove(p);
        _allPlatforms.insert(0, p);
      }
    }

    _avatarUrl = widget.userProfile['avatar_url'];
    _bannerUrl = widget.userProfile['banner_url'];
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _refreshHallOfFame() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final hallOfFameList = List<Map<String, dynamic>?>.filled(5, null);
    try {
      final hallOfFameResp = await Supabase.instance.client
          .from('hall_of_fame')
          .select('*, games(*)')
          .eq('user_id', userId)
          .order('pin_order', ascending: true);

      for (var row in hallOfFameResp) {
        final order = row['pin_order'] as int;
        if (order >= 1 && order <= 5 && row['games'] != null) {
          hallOfFameList[order - 1] = row['games'];
        }
      }
      if (mounted) {
        setState(() {
          _localHallOfFame = hallOfFameList;
        });
      }
    } catch (e) {
      debugPrint('[CORPUS] Error refrescando Hall of fame: $e');
    }
  }

  Future<void> _pickImage(bool isAvatar) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: isAvatar
            ? const CropAspectRatio(ratioX: 1, ratioY: 1)
            : const CropAspectRatio(ratioX: 3, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isAvatar ? 'Recortar Perfil' : 'Recortar Banner',
            toolbarColor: Theme.of(context).colorScheme.surface,
            toolbarWidgetColor: Theme.of(context).colorScheme.onSurface,
            initAspectRatio: isAvatar ? CropAspectRatioPreset.square : CropAspectRatioPreset.original,
            lockAspectRatio: true,
            hideBottomControls: true, // Oculta controles de zoom/rotar en Android
          ),
          IOSUiSettings(
            title: isAvatar ? 'Recortar Perfil' : 'Recortar Banner',
            aspectRatioLockEnabled: true,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.page,
            customRouteBuilder: (cropper, initCropper, crop, rotate, scale) {
              return MaterialPageRoute<String>(
                builder: (_) => _WebCropperPage(
                  cropper: cropper,
                  initCropper: initCropper,
                  crop: crop,
                ),
              );
            },
          ),
        ],
      );

      if (croppedFile != null) {
        final bytes = await ImageCompressor.compressImage(XFile(croppedFile.path));
        if (bytes == null) return;
        final ext = croppedFile.path.split('.').last;

        setState(() {
          if (isAvatar) {
            _newAvatarBytes = bytes;
            _newAvatarExt = ext;
          } else {
            _newBannerBytes = bytes;
            _newBannerExt = ext;
          }
        });
      }
    }
  }

  Future<String?> _uploadImageToStorage(
    String bucket,
    Uint8List bytes,
    String ext,
  ) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '$userId/$timestamp.$ext';

      await Supabase.instance.client.storage
          .from(bucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );

      return Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(filePath);
    } catch (e) {
      debugPrint('[CORPUS DEBUG] Error uploading image to $bucket: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final newUsername = _usernameController.text.trim();
      final newDisplayName = _displayNameController.text.trim();
      final newBio = _bioController.text.trim();
      final newEmail = _emailController.text.trim();

      // Upload images if changed
      String? finalAvatarUrl = _avatarUrl;
      if (_newAvatarBytes != null && _newAvatarExt != null) {
        final uploadedUrl = await _uploadImageToStorage(
          'avatars',
          _newAvatarBytes!,
          _newAvatarExt!,
        );
        if (uploadedUrl != null) finalAvatarUrl = uploadedUrl;
      }

      String? finalBannerUrl = _bannerUrl;
      if (_newBannerBytes != null && _newBannerExt != null) {
        final uploadedUrl = await _uploadImageToStorage(
          'banners',
          _newBannerBytes!,
          _newBannerExt!,
        );
        if (uploadedUrl != null) finalBannerUrl = uploadedUrl;
      }

      // Check if username is already taken by someone else
      if (newUsername != widget.userProfile['username']) {
        final existingUser = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('username', newUsername)
            .maybeSingle();

        if (existingUser != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ese nombre de usuario ya está en uso.'),
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      // Actualizar Email en Auth si cambió
      if (newEmail != Supabase.instance.client.auth.currentUser!.email) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(email: newEmail),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Revisa tu bandeja de entrada para confirmar el nuevo email.',
              ),
            ),
          );
        }
      }

      // Update DB
      await Supabase.instance.client
          .from('users')
          .update({
            'username': newUsername,
            'display_name': newDisplayName.isEmpty
                ? newUsername
                : newDisplayName,
            'bio': newBio,
            'platforms': _selectedPlatforms,
            'avatar_url': finalAvatarUrl,
            'banner_url': finalBannerUrl,
          })
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil guardado correctamente')),
        );
        Navigator.pop(context); // Cierra EditProfileScreen
        Navigator.pop(context); // Cierra SettingsScreen
      }
    } catch (e) {
      debugPrint('[CORPUS DEBUG] Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerHeight = (screenWidth / 3).clamp(120.0, 340.0);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const CorpusScreenTitle('Editar Perfil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // BANNER & AVATAR EDIT
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        // BANNER
                        GestureDetector(
                          onTap: () => _pickImage(false),
                          child: Container(
                            height: bannerHeight,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              gradient:
                                  _bannerUrl == null && _newBannerBytes == null
                                  ? LinearGradient(
                                      colors: [
                                        Colors.deepPurple.shade800,
                                        Colors.red.shade900,
                                      ],
                                    )
                                  : null,
                              image: _newBannerBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(_newBannerBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : _bannerUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_bannerUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                // Degradado oscuro para que resalte la cámara y se funda bien
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Theme.of(context)
                                            .scaffoldBackgroundColor
                                            .withValues(alpha: 0.54),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                // Icono de la cámara elevado (alineado más arriba del centro)
                                Align(
                                  alignment: const Alignment(
                                    0,
                                    -0.4,
                                  ), // Elevado respecto al centro
                                  child: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .scaffoldBackgroundColor
                                        .withValues(alpha: 0.54),
                                    radius: 24,
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // AVATAR
                        Positioned(
                          bottom: -40,
                          child: GestureDetector(
                            onTap: () => _pickImage(true),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  width: 4,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    backgroundImage: _newAvatarBytes != null
                                        ? MemoryImage(_newAvatarBytes!)
                                              as ImageProvider
                                        : _avatarUrl != null
                                        ? NetworkImage(_avatarUrl!)
                                        : null,
                                    onBackgroundImageError: (e, s) {
                                      debugPrint(
                                        '[CORPUS] Error cargando preview de avatar: $e',
                                      );
                                    },
                                    child:
                                        _newAvatarBytes == null &&
                                            _avatarUrl == null
                                        ? const Icon(Icons.person, size: 50)
                                        : null,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .scaffoldBackgroundColor
                                          .withValues(alpha: 0.54),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          children: [
                            const SizedBox(height: 60),

                            _buildHallOfFameEditor(),
                            const SizedBox(height: 40),

                            // USERNAME FIELD
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nombre a mostrar (Público)',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _displayNameController,

                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      prefixIcon: Icon(
                                        Icons.person,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: ext.radiusMedium,
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  Text(
                                    'Nombre de usuario (Único)',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _usernameController,

                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      prefixIcon: Icon(
                                        Icons.alternate_email,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: ext.radiusMedium,
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'El nombre de usuario no puede estar vacío';
                                      }
                                      if (value.trim().length < 3) {
                                        return 'El nombre de usuario es muy corto';
                                      }
                                      if (value.contains(' ')) {
                                        return 'No puede contener espacios';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  Text(
                                    'Correo Electrónico (Inicio de sesión)',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _emailController,

                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      prefixIcon: Icon(
                                        Icons.email,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: ext.radiusMedium,
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty ||
                                          !value.contains('@')) {
                                        return 'Introduce un correo válido';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  Text(
                                    'Biografía',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _bioController,

                                    maxLines: 3,
                                    maxLength: 150,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      border: OutlineInputBorder(
                                        borderRadius: ext.radiusMedium,
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  Text(
                                    'Plataformas (Mantén pulsado para ordenar)',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 60,
                                    child: ReorderableListView(
                                      scrollDirection: Axis.horizontal,
                                      buildDefaultDragHandles: true,
                                      onReorderItem: (oldIndex, newIndex) {
                                        setState(() {
                                          if (oldIndex < newIndex) {
                                            newIndex -= 1;
                                          }
                                          final String item = _allPlatforms
                                              .removeAt(oldIndex);
                                          _allPlatforms.insert(newIndex, item);

                                          // Reordenar también la lista de seleccionados basándose en este nuevo orden general
                                          _selectedPlatforms.sort(
                                            (a, b) => _allPlatforms
                                                .indexOf(a)
                                                .compareTo(
                                                  _allPlatforms.indexOf(b),
                                                ),
                                          );
                                        });
                                      },
                                      children: _allPlatforms.map((p) {
                                        switch (p) {
                                          case 'pc':
                                            return _buildPlatformBadge(
                                              'pc',
                                              Theme.of(context).colorScheme.onSurfaceVariant,
                                              icon: Icons.computer,
                                              key: const ValueKey('pc'),
                                            );
                                          case 'linux':
                                            return _buildPlatformBadge(
                                              'linux',
                                              Colors.orangeAccent.shade700,
                                              imagePath:
                                                  'assets/images/linux.png',
                                              key: const ValueKey('linux'),
                                            );
                                          case 'playstation':
                                            return _buildPlatformBadge(
                                              'playstation',
                                              Colors.blue,
                                              imagePath:
                                                  'assets/images/playstation.png',
                                              key: const ValueKey(
                                                'playstation',
                                              ),
                                            );
                                          case 'xbox':
                                            return _buildPlatformBadge(
                                              'xbox',
                                              Colors.green,
                                              imagePath:
                                                  'assets/images/xbox.png',
                                              key: const ValueKey('xbox'),
                                            );
                                          case 'switch':
                                            return _buildPlatformBadge(
                                              'switch',
                                              Colors.red,
                                              imagePath:
                                                  'assets/images/switch.png',
                                              key: const ValueKey('switch'),
                                            );
                                          case 'wii':
                                            return _buildPlatformBadge(
                                              'wii',
                                              Theme.of(context).colorScheme.onSurfaceVariant,
                                              imagePath:
                                                  'assets/images/wii.png',
                                              key: const ValueKey('wii'),
                                            );
                                          case 'mac':
                                            return _buildPlatformBadge(
                                              'mac',
                                              Theme.of(context).colorScheme.onSurfaceVariant,
                                              imagePath:
                                                  'assets/images/mac.png',
                                              key: const ValueKey('mac'),
                                            );
                                          case 'android':
                                            return _buildPlatformBadge(
                                              'android',
                                              const Color(0xFF3DDC84),
                                              imagePath:
                                                  'assets/images/android.png',
                                              key: const ValueKey('android'),
                                            );
                                          default:
                                            return Container(key: ValueKey(p));
                                        }
                                      }).toList(),
                                    ),
                                  ),

                                  const SizedBox(height: 40),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Guardar Cambios',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height:
                                        MediaQuery.of(context).padding.bottom +
                                        20,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPlatformBadge(
    String platform,
    Color activeColor, {
    IconData? icon,
    String? imagePath,
    Key? key,
  }) {
    final isSelected = _selectedPlatforms.contains(platform);
    return GestureDetector(
      key: key,
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedPlatforms.remove(platform);
          } else {
            _selectedPlatforms.add(platform);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 2,
          ),
          shape: BoxShape.circle,
        ),
        child: imagePath != null
            ? Image.asset(
                imagePath,
                width: 30,
                height: 30,
                color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : Icon(
                icon,
                color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 30,
              ),
      ),
    );
  }

  Widget _buildHallOfFameEditor() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hall of Fame (Toca para editar)',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  final game = _localHallOfFame[index];
                  final isNumberOne = index == 2;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: AspectRatio(
                        aspectRatio: 0.72,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (isNumberOne)
                              Positioned(
                                top: -4,
                                bottom: -4,
                                left: -4,
                                right: -4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.amber,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            HallOfFameSelectorScreen(
                                              pinOrder: index + 1,
                                            ),
                                      ),
                                    ).then((updated) {
                                      if (updated == true) _refreshHallOfFame();
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child:
                                        game != null &&
                                            game['cover_url'] != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              7,
                                            ),
                                            child: Image.network(
                                              game['cover_url'].replaceAll(
                                                't_cover_big',
                                                't_1080p',
                                              ),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          )
                                        : Center(
                                            child: Icon(
                                              Icons.add,
                                              color: isNumberOne
                                                  ? Colors.amber.withValues(
                                                      alpha: 0.8,
                                                    )
                                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebCropperPage extends StatefulWidget {
  final Widget cropper;
  final void Function() initCropper;
  final Future<String?> Function() crop;

  const _WebCropperPage({
    required this.cropper,
    required this.initCropper,
    required this.crop,
  });

  @override
  State<_WebCropperPage> createState() => _WebCropperPageState();
}

class _WebCropperPageState extends State<_WebCropperPage> {
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    widget.initCropper();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recortar Imagen'),
        actions: [
          if (_processing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.done),
              onPressed: () async {
                if (_processing) return;
                setState(() => _processing = true);
                try {
                  final result = await widget.crop();
                  if (mounted) {
                    Navigator.of(context).pop(result);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _processing = false);
                  }
                }
              },
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: widget.cropper,
        ),
      ),
    );
  }
}
