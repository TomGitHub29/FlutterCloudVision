import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttercloudvision/services/vision_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttercloudvision/pages/formulaire_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Cloud Vision Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Google Cloud Vision Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final VisionService _visionService = VisionService();
  bool _isLoading = false;
  Map<String, dynamic>? _visionResponse;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Demande des permissions pour la caméra et la galerie
    await Permission.camera.request();
    if (Platform.isAndroid && await Permission.camera.isDenied) {
      await Permission.camera.request();
    }

    if (Platform.isIOS) {
      await Permission.photos.request();
    } else if (Platform.isAndroid) {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _visionResponse = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _visionService.analyzeImage(_imageFile!);

      setState(() {
        _visionResponse = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'analyse: $e')),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    if (url.startsWith('Aucune')) return;

    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir cette URL')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ouverture de l\'URL: $e')),
      );
    }
  }

  void _navigateToFormulaire() {
    if (_imageFile == null || _visionResponse == null) return;

    // Extraire les labels et webInfo pour les passer à la page de formulaire
    final labels = _visionService.extractLabels(_visionResponse!);
    final webInfo = _visionService.extractWebInfo(_visionResponse!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormulairePage(
          imageFile: _imageFile!,
          visionResponse: _visionResponse!,
          webInfo: webInfo,
          labels: labels,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section pour afficher l'image
              if (_imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.file(
                    _imageFile!,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: const Center(
                    child: Text('Aucune image sélectionnée'),
                  ),
                ),
              const SizedBox(height: 16),

              // Boutons pour sélectionner une image
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _getImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Caméra'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _getImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galerie'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bouton pour analyser l'image
              ElevatedButton(
                onPressed: _imageFile == null || _isLoading
                    ? null
                    : _analyzeImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Analyser l\'image'),
              ),
              const SizedBox(height: 24),

              // Affichage des résultats
              if (_visionResponse != null && !_isLoading) _buildResultsTabs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsTabs() {
    return Column(
      children: [
        const Divider(),
        const Text(
          'Résultats de l\'analyse',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                onTap: (index) {
                  setState(() {
                    _selectedTabIndex = index;
                  });
                },
                tabs: const [
                  Tab(text: 'Labels'),
                  Tab(text: 'Web Detection'),
                ],
              ),
              const SizedBox(height: 16),
              [
                _buildLabelsTab(),
                _buildWebInfoTab(),
              ][_selectedTabIndex],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Bouton pour accéder au formulaire
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _navigateToFormulaire,
            icon: const Icon(Icons.edit_document),
            label: const Text('Compléter un formulaire avec ces données'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelsTab() {
    final labels = _visionService.extractLabels(_visionResponse!);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.label_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Étiquettes détectées',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...labels.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebInfoTab() {
    final webInfo = _visionService.extractWebInfo(_visionResponse!);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meilleure suggestion
            Row(
              children: [
                Icon(Icons.search, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Meilleure suggestion',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...webInfo['bestGuess']!.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Entités Web
            Row(
              children: [
                Icon(Icons.tag, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Entités Web',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...webInfo['webEntities']!.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(item),
              ),
            ),
            const SizedBox(height: 20),

            // Images identiques
            if (webInfo['fullMatchingImages']!.first != 'Aucune image identique trouvée') ...[
              Row(
                children: [
                  Icon(Icons.compare, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Images identiques',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: webInfo['fullMatchingImages']!.length,
                  itemBuilder: (context, index) {
                    final url = webInfo['fullMatchingImages']![index];
                    if (url.startsWith('http')) {
                      return GestureDetector(
                        onTap: () => _launchUrl(url),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Image.network(
                            url,
                            height: 100,
                            errorBuilder: (ctx, obj, stack) => const SizedBox(
                              width: 100,
                              height: 100,
                              child: Center(child: Icon(Icons.broken_image)),
                            ),
                          ),
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Images similaires
            if (webInfo['similarImages']!.first != 'Aucune image similaire trouvée') ...[
              Row(
                children: [
                  Icon(Icons.image_search, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Images similaires',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: webInfo['similarImages']!.length,
                  itemBuilder: (context, index) {
                    final url = webInfo['similarImages']![index];
                    if (url.startsWith('http')) {
                      return GestureDetector(
                        onTap: () => _launchUrl(url),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Image.network(
                            url,
                            height: 100,
                            errorBuilder: (ctx, obj, stack) => const SizedBox(
                              width: 100,
                              height: 100,
                              child: Center(child: Icon(Icons.broken_image)),
                            ),
                          ),
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Pages associées
            Row(
              children: [
                Icon(Icons.web, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Pages associées',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...webInfo['relatedPages']!.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: () => _launchUrl(item),
                  child: Text(
                    item,
                    style: item.startsWith('http')
                        ? const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          )
                        : null,
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
