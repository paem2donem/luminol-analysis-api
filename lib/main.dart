import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const LuminolApp());
}

class LuminolApp extends StatelessWidget {
  const LuminolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luminol Q1 Analyzer',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Serif',
      ),
      home: const AnalizEkrani(),
    );
  }
}

class AnalizEkrani extends StatefulWidget {
  const AnalizEkrani({super.key});

  @override
  State<AnalizEkrani> createState() => _AnalizEkraniState();
}

class _AnalizEkraniState extends State<AnalizEkrani> {
  final String sunucuUrl = "https://luminol-analysis-api.onrender.com";

  File? _secilenVideo;
  bool _yukleniyor = false;
  Map<String, dynamic>? _analizSonuclari;
  String? _grafikUrl;
  final ImagePicker _picker = ImagePicker();

  Future<void> _videoSec() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _secilenVideo = File(video.path);
        _analizSonuclari = null; 
        _grafikUrl = null;
      });
    }
  }

  Future<void> _analizEt() async {
    if (_secilenVideo == null) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$sunucuUrl/analiz'));
      request.files.add(await http.MultipartFile.fromPath('video', _secilenVideo!.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var veri = json.decode(response.body);
        setState(() {
          _analizSonuclari = veri;
          _grafikUrl = "$sunucuUrl/grafik/${veri['graph_name']}";
          _yukleniyor = false;
        });
      } else {
        _hataGoster("Sunucu Hatası: ${response.statusCode}");
      }
    } catch (e) {
      _hataGoster("Bağlantı Hatası: Sunucu uyanıyor olabilir, lütfen tekrar deneyin.");
    }
  }

  void _hataGoster(String mesaj) {
    setState(() => _yukleniyor = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Luminol Q1 Bio-Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF000080), 
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.science_outlined, size: 48, color: Color(0xFF000080)),
                    const SizedBox(height: 10),
                    Text(
                      _secilenVideo == null ? "Analiz edilecek luminol videosunu seçin." : "Video Başarıyla Seçildi",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _yukleniyor ? null : _videoSec,
                      icon: const Icon(Icons.video_library),
                      label: const Text("Galeriden Video Yükle"),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000080), foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            if (_secilenVideo != null && !_yukleniyor && _analizSonuclari == null)
              ElevatedButton(
                onPressed: _analizEt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Kuantum Analizini Başlat (Q1 Standard)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),

            if (_yukleniyor)
              const Column(
                children: [
                  SizedBox(height: 20),
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF000080))),
                  SizedBox(height: 15),
                  Text("Bulut Sunucusunda Spektral Analiz Yapılıyor...\nLütfen Bekleyin.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ],
              ),

            if (_analizSonuclari != null) ...[
              const SizedBox(height: 20),
              const Text("BİLİMSEL ANALİZ RAPORU", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF000080))),
              const Divider(color: Color(0xFF000080), thickness: 1.5),
              
              _veriSatiriOlustur("Peak Intensity (Net)", "${_analizSonuclari!['peak_intensity_au']} a.u."),
              _veriSatiriOlustur("Baseline Noise (Dark)", "${_analizSonuclari!['baseline_noise_au']} a.u."),
              _veriSatiriOlustur("Time to Peak", "${_analizSonuclari!['time_to_peak_sec']} s"),
              _veriSatiriOlustur("Area Under Curve (AUC)", "${_analizSonuclari!['area_under_curve_auc']}"),
              _veriSatiriOlustur("Half-life (t1/2)", "${_analizSonuclari!['half_life_sec']} s"),
              _veriSatiriOlustur("Total Processing Time", "${_analizSonuclari!['total_processing_time']}"),
              
              const SizedBox(height: 25),
              const Text("KİMLÜMİNESANS SİNYAL GRAFİĞİ (300 DPI)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              if (_grafikUrl != null)
                Card(
                  elevation: 4,
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    _grafikUrl!,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(), 
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("Grafik yüklenirken bir hata oluştu."),
                    ),
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _veriSatiriOlustur(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(baslik, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
          Text(deger, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000080))),
        ],
      ),
    );
  }
}
