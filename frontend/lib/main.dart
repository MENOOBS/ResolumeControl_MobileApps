import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ResolumeControlScreen(),
    );
  }
}

class ResolumeControlScreen extends StatefulWidget {
  @override
  _ResolumeControlScreenState createState() => _ResolumeControlScreenState();
}

class _ResolumeControlScreenState extends State<ResolumeControlScreen> {
  final String backendURL = "http://192.168.100.9:3000/play"; // Backend untuk OSC
  final String resolumeIP = "192.168.100.9"; // IP Resolume
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<String> imageUrls = [];

  @override
  void initState() {
    super.initState();
    fetchClipData(); // Ambil data clip saat aplikasi dimulai
  }

  /// **🔹 Ambil jumlah clip & thumbnail dari Resolume**
  Future<void> fetchClipData() async {
  List<String> urls = [];
  int layerIndex = 1; // Coba ubah ke 0 jika perlu

  try {
    final response = await http.get(
      Uri.parse("http://$resolumeIP:8080/api/v1/composition/layers/1"),
    );

    print("🔍 API Response: ${response.statusCode}");
    print("📜 Response Body: ${response.body}");

    if (response.statusCode == 200) {
      var decodedResponse = jsonDecode(response.body);
      
      // Periksa jika data berupa Map atau List
      if (decodedResponse is List) {
        // Jika data berupa List, langsung proses seperti sebelumnya
        for (int clipIndex = 0; clipIndex < decodedResponse.length; clipIndex++) {
          String thumbnailUrl =
              "http://$resolumeIP:8080/api/v1/composition/layers/$layerIndex/clips/${clipIndex + 1}/thumbnail";
          urls.add(thumbnailUrl);
        }
      } else if (decodedResponse is Map) {
        // Jika data berupa Map, coba ambil value yang sesuai
        var clips = decodedResponse['clips']; // Pastikan key yang benar di sini
        if (clips is List) {
          for (int clipIndex = 0; clipIndex < clips.length; clipIndex++) {
            String thumbnailUrl =
                "http://$resolumeIP:8080/api/v1/composition/layers/$layerIndex/clips/${clipIndex + 1}/thumbnail";
            urls.add(thumbnailUrl);
          }
        }
      }

      setState(() {
        imageUrls = urls;
      });
    } else {
      print("❌ Gagal mendapatkan daftar clip: ${response.body}");
    }
  } catch (e) {
    print("❌ Error mengambil data Resolume: $e");
  }
}


  /// **🔹 Kirim perintah ke Resolume via backend**
  void sendOscRequest(int layer, int clip) async {
    final response = await http.post(
      Uri.parse(backendURL),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"layer": layer, "clip": clip}),
    );

    if (response.statusCode == 200) {
      print("✅ Berhasil mengontrol Resolume");
    } else {
      print("❌ Gagal: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Resolume Control")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: imageUrls.isEmpty
                ? Center(child: CircularProgressIndicator()) // Loading jika kosong
                : PageView.builder(
                    controller: _pageController,
                    physics: ClampingScrollPhysics(),
                    itemCount: imageUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Image.network(
                          imageUrls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.broken_image, size: 100); // Jika gagal load
                          },
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: 20),
          imageUrls.isEmpty
              ? Container()
              : ElevatedButton(
                  onPressed: () => sendOscRequest(1, _currentPage + 1),
                  child: Text("Pilih Layer 1 - Clip ${_currentPage + 1}"),
                ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
 