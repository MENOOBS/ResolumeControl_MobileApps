import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  String resolumeIP = "192.168.100.9"; // Default IP Resolume
  final int resolumePort = 8080; // Port Resolume API
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<String> imageUrls = [];
  TextEditingController ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadSavedIP();
    fetchClipData();
  }

  /// **🔹 Load IP Resolume yang disimpan sebelumnya**
  Future<void> loadSavedIP() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedIP = prefs.getString("resolumeIP");
    if (savedIP != null) {
      setState(() {
        resolumeIP = savedIP;
      });
      fetchClipData(); // Fetch ulang dengan IP baru
    }
  }

  /// **🔹 Simpan IP Resolume ke SharedPreferences**
  Future<void> saveIP(String ip) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("resolumeIP", ip);
    setState(() {
      resolumeIP = ip;
    });
    fetchClipData(); // Refresh data setelah ganti IP
  }

  /// **🔹 Ambil jumlah clip & thumbnail dari Resolume**
  Future<void> fetchClipData() async {
    List<String> urls = [];
    int layerIndex = 1;

    try {
      final response = await http.get(
        Uri.parse("http://$resolumeIP:$resolumePort/api/v1/composition/layers/1"),
      );

      if (response.statusCode == 200) {
        var decodedResponse = jsonDecode(response.body);
        var clips = decodedResponse['clips'];

        if (clips is List) {
          for (int clipIndex = 0; clipIndex < clips.length; clipIndex++) {
            String thumbnailUrl =
                "http://$resolumeIP:$resolumePort/api/v1/composition/layers/$layerIndex/clips/${clipIndex + 1}/thumbnail";
            urls.add(thumbnailUrl);
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

  /// **🔹 Kirim HTTP request untuk memilih clip di Resolume**
  Future<void> selectClip(int layer, int clip) async {
    final String url =
        "http://$resolumeIP:$resolumePort/api/v1/composition/layers/$layer/clips/${clip}/connect";

    try {
      final response = await http.post(Uri.parse(url));

      if (response.statusCode == 200 || response.statusCode == 204) {
        print("✅ Berhasil memilih clip: $clip di layer $layer!");
      } else {
        print("❌ Gagal memilih clip: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("❌ Error dalam pengiriman HTTP request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Resolume Control")),
      body: Column(
        children: [
          // **Input IP Resolume**
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ipController,
                    decoration: InputDecoration(
                      labelText: "Masukkan IP Resolume",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    saveIP(ipController.text);
                  },
                  child: Text("Simpan"),
                ),
              ],
            ),
          ),

          // **Tampilkan Thumbnail Clip**
          Expanded(
            child: imageUrls.isEmpty
                ? Center(child: CircularProgressIndicator())
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
                            return Icon(Icons.broken_image, size: 100);
                          },
                        ),
                      );
                    },
                  ),
          ),

          // **Tombol Pilih Clip**
          SizedBox(height: 20),
          imageUrls.isEmpty
              ? Container()
              : ElevatedButton(
                  onPressed: () => selectClip(1, _currentPage + 1),
                  child: Text("Pilih Layer 1 - Clip ${_currentPage + 1}"),
                ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
