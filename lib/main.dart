import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const BioClasificadorApp());
}

class BioClasificadorApp extends StatelessWidget {
  const BioClasificadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioClasificador',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green[700]!,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _altitudController = TextEditingController();
  final _phController = TextEditingController();
  final _temperaturaController = TextEditingController();
  final _densidadMaderaController = TextEditingController();

  // ✅ Valores que coinciden EXACTAMENTE con features_config.json
  String _tipoHoja = 'Simple'; // ← 'Simple' o 'Compuesta'
  String _texturaSuelo = 'Arcilloso';
  String _habitat = 'Bosque'; // ← 'Bosque', 'Paramo', 'Selva', 'Costa'
  String _marcadorMolecular = 'rbcL';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco, color: Colors.white),
            SizedBox(width: 8),
            Text('🌿 BioClasificador'),
          ],
        ),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('🍃 Variables Morfológicas'),
            DropdownButtonFormField<String>(
              value: _tipoHoja,
              decoration: const InputDecoration(
                labelText: 'Tipo de Hoja',
                border: OutlineInputBorder(),
              ),
              items: const [
                // ✅ Valores que coinciden con features_config.json
                DropdownMenuItem(value: 'Simple', child: Text('Hoja Simple')),
                DropdownMenuItem(
                  value: 'Compuesta',
                  child: Text('Hoja Compuesta'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _tipoHoja = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('🧬 Variables Genéticas'),
            DropdownButtonFormField<String>(
              value: _marcadorMolecular,
              decoration: const InputDecoration(
                labelText: 'Marcador Molecular',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'rbcL', child: Text('rbcL')),
                DropdownMenuItem(value: 'matK', child: Text('matK')),
                DropdownMenuItem(value: 'ITS', child: Text('ITS')),
              ],
              onChanged: (value) {
                setState(() {
                  _marcadorMolecular = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('🌍 Variables Ecológicas'),
            TextField(
              controller: _altitudController,
              decoration: const InputDecoration(
                labelText: 'Altitud (msnm)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _temperaturaController,
              decoration: const InputDecoration(
                labelText: 'Temperatura (°C)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            // ✅ Dropdown para Hábitat con valores correctos
            DropdownButtonFormField<String>(
              value: _habitat,
              decoration: const InputDecoration(
                labelText: 'Hábitat',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Bosque', child: Text('Bosque')),
                DropdownMenuItem(value: 'Paramo', child: Text('Páramo')),
                DropdownMenuItem(value: 'Selva', child: Text('Selva')),
                DropdownMenuItem(value: 'Costa', child: Text('Costa')),
                DropdownMenuItem(
                  value: 'Desconocido',
                  child: Text('Desconocido'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _habitat = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('🧪 Variables Fisicoquímicas'),
            TextField(
              controller: _phController,
              decoration: const InputDecoration(
                labelText: 'pH del Suelo',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _texturaSuelo,
              decoration: const InputDecoration(
                labelText: 'Textura del Suelo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Arcilloso', child: Text('Arcilloso')),
                DropdownMenuItem(value: 'Arenoso', child: Text('Arenoso')),
                DropdownMenuItem(value: 'Franco', child: Text('Franco')),
                DropdownMenuItem(value: 'Limoso', child: Text('Limoso')),
                DropdownMenuItem(
                  value: 'Desconocido',
                  child: Text('Desconocido'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _texturaSuelo = value!;
                });
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () {
                _mostrarResultado();
              },
              icon: const Icon(Icons.search),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '🔍 CLASIFICAR',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }

  // ✅ FUNCIÓN CONECTADA AL BACKEND REAL
  void _mostrarResultado() async {
    try {
      // Preparar TODOS los campos con valores que coinciden con features_config.json
      final datosParaEnviar = {
        'Altitud': double.tryParse(_altitudController.text) ?? 1500.0,
        'Lat': -2.5,
        'Long': -78.3,
        'PAIS': 'Ecuador',
        'Tipo_Hoja': _tipoHoja, // 'Simple' o 'Compuesta' ✅
        'Textura_Suelo': _texturaSuelo, // 'Arcilloso', 'Arenoso', etc. ✅
        'pH_Suelo': double.tryParse(_phController.text) ?? 5.4,
        'Conductividad': 150.0,
        'Habitat': _habitat, // 'Bosque', 'Paramo', 'Selva', 'Costa' ✅
        'Stem_dry_mass_per_stem_fresh_volume_stem_specific_density_SSD_wood_density_sapwood':
            double.tryParse(_densidadMaderaController.text) ?? 0.55,
      };

      print('📤 Enviando: ${jsonEncode(datosParaEnviar)}');

      final response = await http.post(
        Uri.parse('http://192.168.100.20:8000/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(datosParaEnviar),
      );

      print('📥 Respuesta: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prediccion = data['prediction'];
        final familia = prediccion['familia'] ?? 'Desconocida';
        final confianzaDecimal = (prediccion['confianza'] ?? 0.0).toDouble();
        final confianzaPorcentaje = (confianzaDecimal * 100).toStringAsFixed(1);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Resultado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Familia Predicha:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  familia,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Confianza: $confianzaPorcentaje%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                LinearProgressIndicator(
                  value: confianzaDecimal.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ Error del Servidor'),
            content: SelectableText(
              'Código: ${response.statusCode}\n\nRespuesta:\n${response.body}',
              style: const TextStyle(fontSize: 11),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    } catch (e, stack) {
      print('❌ Error: $e\n$stack');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('❌ Error'),
          content: SelectableText(
            'No se pudo conectar.\n\nError: $e',
            style: const TextStyle(fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _altitudController.dispose();
    _phController.dispose();
    _temperaturaController.dispose();
    _densidadMaderaController.dispose();
    super.dispose();
  }
}
