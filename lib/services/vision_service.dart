import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class VisionService {
  final String baseUrl = 'https://vision.googleapis.com/v1/images:annotate';
  final String? apiKey = dotenv.env['GOOGLE_CLOUD_VISION_API_KEY'];

  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    if (apiKey == null) {
      throw Exception('La clé API Google Cloud Vision n\'est pas définie');
    }

    try {
      // Convertir l'image en base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Créer la requête pour l'API Cloud Vision avec uniquement les features nécessaires
      final body = jsonEncode({
        "requests": [
          {
            "image": {
              "content": base64Image,
            },
            "features": [
              {
                "type": "LABEL_DETECTION",
                "maxResults": 15,
              },
              {
                "type": "WEB_DETECTION",
                "maxResults": 10,
              },
            ],
          }
        ]
      });

      // Envoyer la requête à l'API
      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        
        // Afficher la réponse brute de WebDetection
        print('===== RÉPONSE COMPLÈTE WEBDETECTION =====');
        if (jsonResponse['responses'] != null && 
            jsonResponse['responses'][0] != null && 
            jsonResponse['responses'][0]['webDetection'] != null) {
          print(JsonEncoder.withIndent('  ').convert(jsonResponse['responses'][0]['webDetection']));
        } else {
          print('Aucune donnée WebDetection trouvée dans la réponse');
        }
        print('========================================');
        
        return jsonResponse;
      } else {
        throw Exception(
            'Erreur lors de l\'analyse de l\'image: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'analyse de l\'image: $e');
    }
  }

  // Méthode pour extraire les étiquettes
  List<String> extractLabels(Map<String, dynamic> response) {
    try {
      final results = response['responses'][0];
      if (results.containsKey('labelAnnotations')) {
        final List<dynamic> annotations = results['labelAnnotations'];
        return annotations
            .map<String>((annotation) => 
                '${annotation['description']} (${(annotation['score'] * 100).toStringAsFixed(1)}%)')
            .toList();
      }
      return ['Aucune étiquette détectée'];
    } catch (e) {
      return ['Erreur d\'extraction des étiquettes: $e'];
    }
  }

  // Méthode pour extraire les informations web
  Map<String, List<String>> extractWebInfo(Map<String, dynamic> response) {
    Map<String, List<String>> webInfo = {
      'bestGuess': <String>[],
      'webEntities': <String>[],
      'fullMatchingImages': <String>[],
      'similarImages': <String>[],
      'relatedPages': <String>[],
    };

    try {
      final results = response['responses'][0];
      
      if (results.containsKey('webDetection')) {
        final webDetection = results['webDetection'];
        
        // Debug: print the entire webDetection structure to understand the format
        print("Structure complète du champ webDetection:");
        print(JsonEncoder.withIndent('  ').convert(webDetection));
        
        // Best guess labels - utilisation similaire au code Python
        if (webDetection.containsKey('bestGuessLabels')) {
          print("BestGuessLabels trouvé: ${webDetection['bestGuessLabels']}");
          final labelsList = webDetection['bestGuessLabels'] as List<dynamic>;
          webInfo['bestGuess'] = labelsList
              .map((label) => label['label'].toString())
              .toList();
        } else {
          print("ATTENTION: 'bestGuessLabels' n'est pas présent dans la réponse");
          
          // Analyser les autres champs qui peuvent contenir des informations similaires
          if (webDetection.containsKey('webEntities') && 
              (webDetection['webEntities'] as List<dynamic>).isNotEmpty) {
            // Utiliser l'entité web avec le score le plus élevé comme substitut
            var entities = webDetection['webEntities'] as List<dynamic>;
            entities.sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0));
            webInfo['bestGuess'] = [entities.first['description'].toString()];
            print("Substitut bestGuess utilisé: ${webInfo['bestGuess']}");
          }
        }
        
        // Web entities
        if (webDetection.containsKey('webEntities')) {
          final entitiesList = webDetection['webEntities'] as List<dynamic>;
          webInfo['webEntities'] = entitiesList.map((entity) {
            final description = entity['description']?.toString() ?? 'Inconnu';
            final score = entity.containsKey('score') 
                ? ' (${(entity['score'] * 100).toStringAsFixed(1)}%)' 
                : '';
            return '$description$score';
          }).toList();
        }
        
        // Full matching images
        if (webDetection.containsKey('fullMatchingImages')) {
          final imagesList = webDetection['fullMatchingImages'] as List<dynamic>;
          webInfo['fullMatchingImages'] = imagesList
              .map((image) => image['url'].toString())
              .toList();
        }
        
        // Visually similar images
        if (webDetection.containsKey('visuallySimilarImages')) {
          final imagesList = webDetection['visuallySimilarImages'] as List<dynamic>;
          webInfo['similarImages'] = imagesList
              .map((image) => image['url'].toString())
              .toList();
        }
        
        // Pages with matching images
        if (webDetection.containsKey('pagesWithMatchingImages')) {
          final pagesList = webDetection['pagesWithMatchingImages'] as List<dynamic>;
          webInfo['relatedPages'] = pagesList
              .map((page) => page['url'].toString())
              .toList();
        }
      }
      
      // Si aucune information web n'a été trouvée, on retourne des messages par défaut
      if (webInfo['bestGuess']!.isEmpty) {
        webInfo['bestGuess'] = ['Aucune suggestion trouvée'];
      }
      if (webInfo['webEntities']!.isEmpty) {
        webInfo['webEntities'] = ['Aucune entité web détectée'];
      }
      if (webInfo['fullMatchingImages']!.isEmpty) {
        webInfo['fullMatchingImages'] = ['Aucune image identique trouvée'];
      }
      if (webInfo['similarImages']!.isEmpty) {
        webInfo['similarImages'] = ['Aucune image similaire trouvée'];
      }
      if (webInfo['relatedPages']!.isEmpty) {
        webInfo['relatedPages'] = ['Aucune page associée trouvée'];
      }

      return webInfo;
    } catch (e) {
      print('Erreur dans extractWebInfo: $e');
      print('Stack trace: ${StackTrace.current}');
      return {
        'bestGuess': ['Erreur d\'extraction des informations web: $e'],
        'webEntities': [],
        'fullMatchingImages': [],
        'similarImages': [],
        'relatedPages': [],
      };
    }
  }
}