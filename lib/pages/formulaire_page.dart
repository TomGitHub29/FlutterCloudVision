import 'dart:io';
import 'package:flutter/material.dart';

class FormulairePage extends StatefulWidget {
  final File imageFile;
  final Map<String, dynamic> visionResponse;
  final Map<String, List<String>> webInfo;
  final List<String> labels;

  const FormulairePage({
    Key? key,
    required this.imageFile,
    required this.visionResponse,
    required this.webInfo,
    required this.labels,
  }) : super(key: key);

  @override
  State<FormulairePage> createState() => _FormulairePageState();
}

class _FormulairePageState extends State<FormulairePage> {
  late TextEditingController _titreController;
  late String _selectedCategorie;
  
  // Options pour les listes déroulantes
  List<String> _titreOptions = [];
  List<String> _categorieOptions = [];
  
  bool _isLoading = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _prepareFormData();
  }

  void _prepareFormData() {
    // Créer les options de titre (meilleure suggestion + 2 premières entités web)
    _titreOptions = [];
    
    // Ajouter la meilleure suggestion si disponible
    if (widget.webInfo['bestGuess']!.isNotEmpty && 
        widget.webInfo['bestGuess']!.first != 'Aucune suggestion trouvée') {
      _titreOptions.add(widget.webInfo['bestGuess']!.first);
    }
    
    // Ajouter les 2 premières entités web si disponibles
    if (widget.webInfo['webEntities']!.isNotEmpty) {
      for (var i = 0; i < widget.webInfo['webEntities']!.length && i < 2; i++) {
        String entity = widget.webInfo['webEntities']![i];
        // Supprimer le score s'il est présent
        if (entity.contains('(')) {
          entity = entity.substring(0, entity.indexOf('(')).trim();
        }
        if (!_titreOptions.contains(entity)) {
          _titreOptions.add(entity);
        }
      }
    }
    
    // Créer un titre par défaut en combinant les options si disponibles
    String defaultTitre = _titreOptions.isNotEmpty ? _titreOptions.first : 'Titre par défaut';
    _titreController = TextEditingController(text: defaultTitre);
    
    // Créer les options de catégorie (3 meilleurs labels)
    _categorieOptions = [];
    
    // Ajouter les 3 premiers labels
    for (var i = 0; i < widget.labels.length && i < 3; i++) {
      String label = widget.labels[i];
      // Supprimer le score s'il est présent
      if (label.contains('(')) {
        label = label.substring(0, label.indexOf('(')).trim();
      }
      _categorieOptions.add(label);
    }
    
    // Ajouter une catégorie "Autre" pour permettre la saisie manuelle
    _categorieOptions.add("Autre");
    
    // Sélectionner la première catégorie par défaut
    _selectedCategorie = _categorieOptions.isNotEmpty ? _categorieOptions.first : 'Catégorie par défaut';
  }

  Future<void> _sauvegarderFormulaire() async {
    setState(() {
      _isLoading = true;
    });
    
    // Simuler une sauvegarde en attendant 1 seconde
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _isLoading = false;
      _isSaved = true;
    });
    
    // Afficher un message de confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Formulaire sauvegardé avec succès!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compléter le formulaire'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.file(
                  widget.imageFile,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Section titre
            const Text(
              'Titre',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titreController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Saisir un titre',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Suggestions de titres:',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: _titreOptions.map((titre) {
                return ActionChip(
                  label: Text(titre),
                  onPressed: () {
                    setState(() {
                      _titreController.text = titre;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            
            // Section catégorie
            const Text(
              'Catégorie',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategorie,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: _categorieOptions.map((String categorie) {
                return DropdownMenuItem<String>(
                  value: categorie,
                  child: Text(categorie),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedCategorie = newValue!;
                  
                  // Si "Autre" est sélectionné, afficher une boîte de dialogue
                  if (newValue == "Autre") {
                    _showCustomCategoryDialog();
                  }
                });
              },
            ),
            const SizedBox(height: 40),
            
            // Bouton de sauvegarde
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaved ? null : _sauvegarderFormulaire,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isSaved ? 'Formulaire sauvegardé' : 'Sauvegarder'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Boîte de dialogue pour saisir une catégorie personnalisée
  Future<void> _showCustomCategoryDialog() async {
    final TextEditingController customCatController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Catégorie personnalisée'),
          content: TextField(
            controller: customCatController,
            decoration: const InputDecoration(
              hintText: 'Saisir une catégorie',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                if (customCatController.text.isNotEmpty) {
                  setState(() {
                    // Ajouter la catégorie personnalisée aux options
                    if (!_categorieOptions.contains(customCatController.text)) {
                      _categorieOptions.insert(_categorieOptions.length - 1, customCatController.text);
                    }
                    _selectedCategorie = customCatController.text;
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _titreController.dispose();
    super.dispose();
  }
}