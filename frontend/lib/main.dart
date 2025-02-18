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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: Colors.blue,
          secondary: Colors.blueAccent,
          surface: Color(0xFF1E1E1E),
          background: Color(0xFF121212),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      home: ResolumeControlScreen(),
    );
  }
}

class ResolumeControlScreen extends StatefulWidget {
  @override
  _ResolumeControlScreenState createState() => _ResolumeControlScreenState();
}

class _ResolumeControlScreenState extends State<ResolumeControlScreen> {
  String resolumeIP = "192.168.100.9";
  final int resolumePort = 8080;
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

  Future<void> loadSavedIP() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedIP = prefs.getString("resolumeIP");
    if (savedIP != null) {
      setState(() {
        resolumeIP = savedIP;
        ipController.text = savedIP;
      });
      fetchClipData();
    }
  }

  Future<void> saveIP(String ip) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("resolumeIP", ip);
    setState(() {
      resolumeIP = ip;
    });
    fetchClipData();
  }

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
      }
    } catch (e) {
      print("❌ Error mengambil data Resolume: $e");
    }
  }

  Future<void> selectClip(int layer, int clip) async {
    try {
      final response = await http.post(
        Uri.parse("http://$resolumeIP:$resolumePort/api/v1/composition/layers/$layer/clips/${clip}/connect"),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil dipilih!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih clip: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          "Resolume Control",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ipController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "IP Resolume",
                      labelStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      icon: Icon(Icons.computer, color: Colors.white70),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => saveIP(ipController.text),
                  icon: Icon(Icons.save),
                  label: Text("Simpan"),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: imageUrls.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Memuat thumbnail...",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: PageView.builder(
                      controller: _pageController,
                      physics: ClampingScrollPhysics(),
                      itemCount: imageUrls.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.all(16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrls[index],
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[900],
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 100,
                                    color: Colors.white54,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (imageUrls.isNotEmpty) ...[
            Container(
              margin: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentPage > 0
                        ? () {
                            _pageController.previousPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    icon: Icon(Icons.arrow_back),
                    label: Text("Previous"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(width: 15),
                  ElevatedButton.icon(
                    onPressed: () => selectClip(1, _currentPage + 1),
                    icon: Icon(Icons.play_arrow),
                    label: Text("Play This"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _currentPage < imageUrls.length - 1
                        ? () {
                            _pageController.nextPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    icon: Icon(Icons.arrow_forward),
                    label: Text("Next"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}