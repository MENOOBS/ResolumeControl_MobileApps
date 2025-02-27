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
          background: Color.fromARGB(246, 204, 207, 3),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color.fromRGBO(229, 255, 0, 1),
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
  String resolumeIP = "YOUR RESOLUME IP";
  final int resolumePort = YOUR RESOLUME PORT;
  List<String> imageUrls = [];
  TextEditingController ipController = TextEditingController();
  int? selectedIndex;

  @override
  void initState() {
    super.initState();
    loadSavedIP();
    fetchClipData();
    _checkGuideStatus();
  }

  Future<void> _checkGuideStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasSeenGuide = prefs.getBool('hasSeenGuide') ?? false;
    if (!hasSeenGuide) {
      _showGuideDialog();
    }
  }

  Future<void> _setGuideStatus(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenGuide', value);
  }

  void _showGuideDialog() {
    bool dontShowAgain = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Panduan Menggunakan Aplikasi Ini"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      "1. Masukkan IP Address : 192.168.18.43 ke dalam aplikasi.\n"
                      "2. Tekan tombol Simpan.\n"
                      "3. Pastikan  perangkat berada dalam WIFI POV.\n"
                      "4. Jika Konten tidak muncul, periksa koneksi dan coba lagi."),
                  Row(
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                   
                    Navigator.of(context).pop();
                  },
                  child: Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );
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
    setState(() {
      selectedIndex = clip - 1;
    });

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

    // Reset selection after animation
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          selectedIndex = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          "SMART HLS",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(228, 20, 20, 20)
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showGuideDialog,
            color: Color.fromARGB(255, 0, 0, 1),
          ),
        ],
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
                    child: GridView.builder(
                      padding: EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1,
                      ),
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        bool isSelected = selectedIndex == index;
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          transform: isSelected
                              ? (Matrix4.identity()..scale(0.95))
                              : Matrix4.identity(),
                          child: InkWell(
                            onTap: () => selectClip(1, index + 1),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white24,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : [],
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: Stack(
                                        children: [
                                          Image.network(
                                            imageUrls[index],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[900],
                                                child: Icon(
                                                  Icons.broken_image,
                                                  size: 40,
                                                  color: Colors.white54,
                                                ),
                                              );
                                            },
                                          ),
                                          if (isSelected)
                                            Container(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.3),
                                              child: Center(
                                                child: Icon(
                                                  Icons.play_circle_fill,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.black45,
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Clip ${index + 1}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
