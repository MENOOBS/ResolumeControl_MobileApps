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
          primary: const Color.fromARGB(255, 205, 243, 33),
          secondary: const Color.fromARGB(198, 228, 213, 11),
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

class Layer {
  final int id;
  final String name;
  final List<String> clipUrls;
  final List<String> clipTitles;
  int? selectedClipIndex;

  Layer({
    required this.id,
    required this.name,
    required this.clipUrls,
    required this.clipTitles,
    this.selectedClipIndex,
  });
}

class _ResolumeControlScreenState extends State<ResolumeControlScreen> with SingleTickerProviderStateMixin {
  String resolumeIP = "192.168.100.9";
  final int resolumePort = 8080;
  List<Layer> layers = [];
  TextEditingController ipController = TextEditingController();
  int? selectedDeckIndex;
  bool isLoading = false;
  
  // For deck control
  List<DeckInfo> decks = [];
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    loadSavedIP();
    _checkGuideStatus();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    ipController.dispose();
    super.dispose();
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Panduan Menggunakan Aplikasi Ini"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "1. Masukkan IP Address Resolume ke dalam aplikasi.\n"
                "2. Tekan tombol Simpan.\n"
                "3. Pastikan perangkat berada dalam WIFI yang sama dengan Resolume.\n"
                "4. Tab Clips untuk memilih clip dari berbagai layer, dan tab Decks untuk mengubah deck.\n"
                "5. Jika konten tidak muncul, periksa koneksi dan coba lagi."
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
  }

  Future<void> loadSavedIP() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedIP = prefs.getString("resolumeIP");
    if (savedIP != null) {
      setState(() {
        resolumeIP = savedIP;
        ipController.text = savedIP;
      });
      fetchResolumeData();
    }
  }

  Future<void> saveIP(String ip) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("resolumeIP", ip);
    setState(() {
      resolumeIP = ip;
    });
    fetchResolumeData();
  }

  Future<void> fetchResolumeData() async {
    setState(() {
      isLoading = true;
    });
    await fetchLayersCount();
    await fetchDeckData();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchLayersCount() async {
    try {
      final response = await http.get(
        Uri.parse("http://$resolumeIP:$resolumePort/api/v1/composition"),
      );

      if (response.statusCode == 200) {
        var decodedResponse = jsonDecode(response.body);
        var layersData = decodedResponse['layers'];

        if (layersData is List) {
          // Clear current layers data
          layers.clear();
          
          // Fetch data for each layer
          for (int i = 0; i < layersData.length; i++) {
            await fetchLayerData(i + 1, layersData[i]['name']?['value'] ?? '${i + 1}');
          }
        }
      }
    } catch (e) {
      print("❌ Error mengambil jumlah layer Resolume: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil data layer: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> fetchLayerData(int layerIndex, String layerName) async {
    List<String> urls = [];
    List<String> clipNames = [];

    try {
      final response = await http.get(
        Uri.parse("http://$resolumeIP:$resolumePort/api/v1/composition/layers/$layerIndex"),
      );

      if (response.statusCode == 200) {
        var decodedResponse = jsonDecode(response.body);
        var clips = decodedResponse['clips'];

        if (clips is List) {
          for (int clipIndex = 0; clipIndex < clips.length; clipIndex++) {
            var clip = clips[clipIndex];
            if (clip is Map<String, dynamic>) {
              String? clipName = clip['name']?['value'];

              // Hanya tambahkan jika nama tidak kosong
              if (clipName != null && clipName.trim().isNotEmpty) {
                String thumbnailUrl =
                    "http://$resolumeIP:$resolumePort/api/v1/composition/layers/$layerIndex/clips/${clipIndex + 1}/thumbnail";
                urls.add(thumbnailUrl);
                clipNames.add(clipName);
              }
            }
          }
        }

        // Add layer only if it has clips
        if (urls.isNotEmpty) {
          setState(() {
            layers.add(Layer(
              id: layerIndex,
              name: layerName,
              clipUrls: urls,
              clipTitles: clipNames,
            ));
          });
        }
      }
    } catch (e) {
      print("❌ Error mengambil data clip Layer $layerIndex: $e");
    }
  }

  Future<void> fetchDeckData() async {
    try {
      final response = await http.get(
        Uri.parse("http://$resolumeIP:$resolumePort/api/v1/composition"),
      );

      if (response.statusCode == 200) {
        var decodedResponse = jsonDecode(response.body);
        var decksData = decodedResponse['decks'];

        List<DeckInfo> fetchedDecks = [];
        if (decksData is List) {
          for (var deck in decksData) {
            if (deck is Map<String, dynamic>) {
              String deckId = deck['id']?.toString() ?? 'Unknown';
              String deckName = deck['name']?['value']?.toString() ?? 'Deck ${fetchedDecks.length + 1}';
              bool isSelected = deck['selected']?['value'] == true;

              fetchedDecks.add(DeckInfo(
                id: deckId,
                name: deckName,
                isSelected: isSelected,
              ));
            }
          }
        }

        setState(() {
          decks = fetchedDecks;
          // Temukan deck yang dipilih
          for (int i = 0; i < decks.length; i++) {
            if (decks[i].isSelected) {
              selectedDeckIndex = i;
              break;
            }
          }
        });
      }
    } catch (e) {
      print("❌ Error mengambil data deck Resolume: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil data deck: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> selectClip(int layerIndex, int clipIndex, int layerListIndex) async {
    setState(() {
      // Update selected clip index
      layers[layerListIndex].selectedClipIndex = clipIndex;
    });

    try {
      final response = await http.post(
        Uri.parse("http://$resolumeIP:$resolumePort/api/v1/composition/layers/$layerIndex/clips/${clipIndex + 1}/connect"),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clip berhasil dipilih pada Layer ${layerIndex}!'),
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
          layers[layerListIndex].selectedClipIndex = null;
        });
      }
    });
  }

  Future<void> selectDeck(String deckId, int index) async {
    setState(() {
      selectedDeckIndex = index;
    });

    try {
      final response = await http.post(
        Uri.parse("http://$resolumeIP:$resolumePort/api/v1/composition/decks/by-id/$deckId/select"),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deck berhasil dipilih!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Update deck status
        for (int i = 0; i < decks.length; i++) {
          decks[i].isSelected = (i == index);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih deck: $e'),
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
          "SMART HLS",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(228, 20, 20, 20)
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchResolumeData,
            color: Color.fromARGB(255, 0, 0, 1),
          ),
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showGuideDialog,
            color: Color.fromARGB(255, 0, 0, 1),
          ),
        ],
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.video_library),
              text: "Clips",
            ),
            Tab(
              icon: Icon(Icons.dashboard),
              text: "Decks",
            ),
          ],
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.black,
        ),
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
            child: TabBarView(
              controller: _tabController,
              children: [
                // Clips Tab - Multiple Layers
                _buildClipsTab(),
                
                // Decks Tab
                _buildDecksTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClipsTab() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Memuat data layer dan clip...",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (layers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              "Tidak ada layer yang ditemukan",
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              "Periksa koneksi dan tekan refresh",
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: layers.length,
      itemBuilder: (context, layerIndex) {
        Layer layer = layers[layerIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Layer Title with Container
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 12, top: layerIndex > 0 ? 24 : 0),
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.layers, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    "${layer.name}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Clips Grid for this Layer
            Container(
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
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemCount: layer.clipUrls.length,
                itemBuilder: (context, clipIndex) {
                  bool isSelected = layer.selectedClipIndex == clipIndex;
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    transform: isSelected
                        ? (Matrix4.identity()..scale(0.95))
                        : Matrix4.identity(),
                    child: InkWell(
                      onTap: () => selectClip(layer.id, clipIndex, layerIndex),
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
                                      layer.clipUrls[clipIndex],
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
                                layer.clipTitles[clipIndex],
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
            
            // Add a divider if not the last layer
            if (layerIndex < layers.length - 1)
              Divider(
                height: 48,
                thickness: 2,
                color: Colors.white24,
              ),
          ],
        );
      },
    );
  }

  Widget _buildDecksTab() {
    return decks.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isLoading 
                    ? CircularProgressIndicator()
                    : Icon(Icons.warning_amber_rounded, size: 64, color: Colors.white70),
                SizedBox(height: 16),
                Text(
                  isLoading 
                      ? "Memuat data deck..." 
                      : "Tidak ada deck yang ditemukan",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ],
            ),
          )
        : Container(
            margin: EdgeInsets.all(16),
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
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: decks.length,
              itemBuilder: (context, index) {
                bool isSelected = selectedDeckIndex == index;
                return Card(
                  elevation: isSelected ? 8 : 2,
                  margin: EdgeInsets.only(bottom: 12),
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary 
                      : Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected 
                          ? Colors.white 
                          : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => selectDeck(decks[index].id, index),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.dashboard,
                            size: 32,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  decks[index].name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "ID: ${decks[index].id}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.white70 : Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
  }
}

class DeckInfo {
  final String id;
  final String name;
  bool isSelected;

  DeckInfo({
    required this.id,
    required this.name,
    required this.isSelected,
  });
}