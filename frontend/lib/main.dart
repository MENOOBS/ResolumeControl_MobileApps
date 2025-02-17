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
    fetchThumbnails(); // Ambil thumbnail saat aplikasi dimulai
  }

  /// **🔹 Ambil Thumbnail dari Resolume**
  Future<void> fetchThumbnails() async {
    List<String> urls = [];
    int layerIndex = 1; // Ganti sesuai kebutuhan

    for (int clipIndex = 1; clipIndex <= 3; clipIndex++) {
      String url =
          "http://$resolumeIP:8080/api/v1/composition/layers/$layerIndex/clips/$clipIndex/thumbnail";
      urls.add(url);
    }

    setState(() {
      imageUrls = urls;
    });
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
          ElevatedButton(
            onPressed: () => sendOscRequest(1, _currentPage + 1),
            child: Text("Pilih Layer 1 - Clip ${_currentPage + 1}"),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
