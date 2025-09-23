// ------------------------- IMPORTS -------------------------
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart'; // your backend API service
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:translator/translator.dart';
import './pages/loginpage1.dart';
import './pages/create_account_page.dart';
import './pages/admin_dashboard_page.dart';
import 'launcher_page.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;
import 'package:crypto/crypto.dart'; // For SHA-256 hashing

// ------------------------- GLOBAL FONT -------------------------
pw.Font? bengaliFont;

// ------------------------- MAIN -------------------------
// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Bangla Doc Scanner',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         scaffoldBackgroundColor: const Color(0xFFF0F2F5),
//       ),
//       home: const HomeScreen(),
//     );
//   }
// }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bengali Doc Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      ),
      home: const LoginPage(), // Start from login page
    );
  }
}

// ----------------------------
// Add this below MyApp class
// ----------------------------
class MainAppPage extends StatelessWidget {
  const MainAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bangla Doc Scanner')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Welcome to the App!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Start scanning your documents here.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------- HOME SCREEN -------------------------
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
class HomeScreen extends StatefulWidget {
  final String role; // 👈 add this

  const HomeScreen({super.key, required this.role}); // 👈 require role

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ✅ Logout (back to LoginPage)
  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // ✅ For admin only: create account
  void _openCreateAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create Account"),
        content: const Text("Here admin will create a new account."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  File? _pickedImage;
  Uint8List? _webImage;
  final List<Map<String, dynamic>> _recentScans = [];
  final List<Map<String, dynamic>> _savedScans = []; // Saved in backend
  int? _selectedIndex;
  bool _isProcessing = false;

  // ------------------ PICK IMAGE ------------------
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile != null) {
      String? fileName = await _askFileName();
      if (fileName == null || fileName.trim().isEmpty)
        fileName = "Untitled Document";

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        String ocrText = "";
        try {
          ocrText = await recognizeTextWeb(bytes, 'ben+eng');
        } catch (e) {
          ocrText = "OCR failed: $e";
        }

        setState(() {
          _webImage = bytes;
          _pickedImage = null;
          _recentScans.insert(0, {
            "webImage": bytes,
            "title": fileName,
            "date": DateTime.now().toString().split(".").first,
            "ocrText": ocrText,
          });
        });
      } else {
        setState(() {
          _pickedImage = File(pickedFile.path);
          _webImage = null;
          _recentScans.insert(0, {
            "file": File(pickedFile.path),
            "title": fileName,
            "date": DateTime.now().toString().split(".").first,
            "ocrText": "",
          });
        });
      }
    }
  }

  // ------------------ ASK FILE NAME ------------------
  Future<String?> _askFileName({String currentName = ""}) async {
    TextEditingController controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter file name"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "File name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ------------------ PERFORM OCR ------------------
  // Future<void> _performOCR() async {
  //   if (_selectedIndex == null) {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(const SnackBar(content: Text("Select a document first")));
  //     return;
  //   }

  //   setState(() => _isProcessing = true);

  //   final scan = _recentScans[_selectedIndex!];
  //   String ocrText = '';

  //   try {
  //     if (kIsWeb && scan["webImage"] != null) {
  //       ocrText = await recognizeTextWeb(scan["webImage"], 'ben+eng');
  //     } else if (!kIsWeb && scan["file"] != null) {
  //       final inputImage = InputImage.fromFile(scan["file"]);
  //       final textRecognizer = TextRecognizer();
  //       final recognizedText = await textRecognizer.processImage(inputImage);
  //       ocrText = recognizedText.text;
  //       textRecognizer.close();
  //     } else {
  //       ocrText = "No valid image found for OCR";
  //     }
  //   } catch (e) {
  //     ocrText = "OCR failed: $e";
  //   }

  //   setState(() {
  //     _recentScans[_selectedIndex!]["ocrText"] = ocrText;
  //     _isProcessing = false;
  //   });

  //   // ------------------- UPLOAD TO BACKEND -------------------
  //   final api = ApiService();
  //   try {
  //     Map<String, dynamic> result;

  //     if (kIsWeb && scan["webImage"] != null) {
  //       result = await api.uploadDocument(
  //         webBytes: scan["webImage"],
  //         title: scan["title"],
  //         ocrText: ocrText,
  //         fileName: "${scan['title']}.png",
  //       );
  //     } else if (!kIsWeb && scan["file"] != null) {
  //       result = await api.uploadDocument(
  //         filePath: scan["file"].path,
  //         title: scan["title"],
  //         ocrText: ocrText,
  //       );
  //     } else {
  //       result = {"success": false, "message": "No file to upload"};
  //     }

  //     if (result['success'] == true) {
  //       setState(() {
  //         _savedScans.insert(0, {
  //           "title": scan["title"],
  //           "date": scan["date"],
  //           "ocrText": ocrText,
  //         });
  //       });
  //       print("Document uploaded successfully");
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text("Document saved to database")),
  //       );
  //     } else {
  //       print("Upload failed: ${result['message']}");
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text("Upload failed: ${result['message']}")),
  //       );
  //     }
  //   } catch (e) {
  //     print("Upload error: $e");
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text("Upload error: $e")));
  //   }

  //   // ------------------- SHOW OCR RESULT -------------------
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (context) => OCRResultScreen(text: ocrText)),
  //   );
  // }
  Future<void> _performOCR() async {
    if (_selectedIndex == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select a document first")));
      return;
    }

    setState(() => _isProcessing = true);

    final scan = _recentScans[_selectedIndex!];
    String ocrText = '';

    try {
      // Perform OCR
      if (kIsWeb && scan["webImage"] != null) {
        ocrText = await recognizeTextWeb(scan["webImage"], 'ben+eng');
      } else if (!kIsWeb && scan["file"] != null) {
        final inputImage = InputImage.fromFile(scan["file"]);
        final textRecognizer = TextRecognizer();
        final recognizedText = await textRecognizer.processImage(inputImage);
        ocrText = recognizedText.text;
        textRecognizer.close();
      } else {
        ocrText = "No valid image found for OCR";
      }
    } catch (e) {
      ocrText = "OCR failed: $e";
    }

    // Update recent scan
    setState(() {
      _recentScans[_selectedIndex!]["ocrText"] = ocrText;
      _isProcessing = false;
    });

    // ------------------- CHECK IF DOCUMENT ALREADY EXISTS -------------------
    bool exists = _savedScans.any(
      (doc) => doc["title"] == scan["title"] && doc["ocrText"] == ocrText,
    );

    if (exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Document already exists!")));
    } else {
      // ------------------- UPLOAD TO BACKEND -------------------
      try {
        final api = ApiService();
        final result = await api.uploadDocument(
          title: scan["title"],
          ocrText: ocrText,
          bytes: kIsWeb ? scan["webImage"] : null, // for web
          file: !kIsWeb ? scan["file"] : null, // for mobile
        );

        if (result['success'] == true) {
          setState(() {
            _savedScans.insert(0, {
              "title": scan["title"],
              "date": DateTime.now().toString().split(".").first,
              "ocrText": ocrText,
            });
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Document uploaded successfully!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload failed: ${result['message']}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Upload error: $e")));
      }
    }

    // ------------------- SHOW OCR RESULT -------------------
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OCRResultScreen(text: ocrText)),
    );
  }

  // ------------------ OPEN SEARCH ------------------
  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(recentScans: _recentScans),
      ),
    );
  }

  // ------------------ OPEN SAVED DOCUMENTS ------------------
  void _openSaved() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SavedDocumentsScreen(savedScans: _savedScans),
      ),
    );
  }

  // ------------------ BUILD ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Doc Scanner', style: TextStyle(color: Colors.white)),
      //   backgroundColor: const Color(0xFF1A237E),
      //   elevation: 0,
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.folder_open),
      //       onPressed: _openSaved,
      //     ), // Saved documents
      //   ],
      // ),
      // appBar: AppBar(
      //   title: const Text('Doc Scanner'),
      //   actions: [
      //     if (widget.role == "admin") // 👈 only for admins
      //       IconButton(
      //         icon: const Icon(Icons.person_add),
      //         tooltip: "Create Account",
      //         onPressed: () {
      //           Navigator.push(
      //             context,
      //             MaterialPageRoute(builder: (_) => const CreateAccountPage()),
      //           );
      //         },
      //       ),

      //     IconButton(
      //       icon: const Icon(Icons.logout),
      //       tooltip: "Logout",
      //       onPressed: _logout,
      //     ),
      //   ],
      // ),
      appBar: AppBar(
        title: const Text('Doc Scanner'),
        leading: widget.role == "admin"
            ? IconButton(
                icon: const Icon(Icons.dashboard),
                tooltip: "Admin Dashboard",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardPage(),
                    ),
                  );
                },
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),

      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF1A237E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 40,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(
                        icon: Icons.camera_alt,
                        label: 'Select Document',
                        onPressed: _pickImage,
                      ),
                      _buildActionButton(
                        icon: Icons.text_fields,
                        label: 'OCR',
                        onPressed: _performOCR,
                      ),
                      _buildActionButton(
                        icon: Icons.search,
                        label: 'Search',
                        onPressed: _openSearch,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Scans',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _recentScans.isEmpty
                          ? const Text("No scans yet")
                          : Column(
                              children: _recentScans
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => _buildRecentScanItem(
                                      entry.value,
                                      entry.key,
                                    ),
                                  )
                                  .toList(),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------ BUILD ACTION BUTTON ------------------
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onPressed,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(icon, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ------------------ BUILD RECENT SCAN ITEM ------------------
  Widget _buildRecentScanItem(Map<String, dynamic> scan, int index) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            if (kIsWeb && scan["webImage"] != null)
              Image.memory(
                scan["webImage"],
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              )
            else if (scan["file"] != null)
              Image.file(scan["file"], width: 60, height: 60, fit: BoxFit.cover)
            else
              const SizedBox(width: 60, height: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          scan["title"],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () async {
                          String? newName = await _askFileName(
                            currentName: scan["title"],
                          );
                          if (newName != null && newName.isNotEmpty)
                            setState(() => scan["title"] = newName);
                        },
                      ),
                    ],
                  ),
                  Text(
                    "Date: ${scan["date"]}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------- OCR RESULT SCREEN -------------------------
class OCRResultScreen extends StatefulWidget {
  final String text;
  final String? highlight;
  const OCRResultScreen({super.key, required this.text, this.highlight});
  @override
  State<OCRResultScreen> createState() => _OCRResultScreenState();
}

class _OCRResultScreenState extends State<OCRResultScreen> {
  String displayedText = "";
  String selectedLanguage = "Bengali";
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    displayedText = widget.text;
  }

  Future<void> _translateToEnglish() async {
    setState(() => _isTranslating = true);
    try {
      final translator = GoogleTranslator();
      final translation = await translator.translate(
        widget.text,
        from: 'bn',
        to: 'en',
      );
      setState(() {
        displayedText = translation.text;
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        displayedText = "Translation error: $e";
        _isTranslating = false;
      });
    }
  }

  void _switchLanguage(String language) {
    if (language == selectedLanguage) return;
    setState(() => selectedLanguage = language);
    if (language == "English")
      _translateToEnglish();
    else
      setState(() => displayedText = widget.text);
  }

  Future<void> _generatePDF() async {
    if (bengaliFont == null) {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSansBengali-VariableFont_wdth,wght.ttf',
      );
      bengaliFont = pw.Font.ttf(fontData);
    }
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Text(
            displayedText,
            style: pw.TextStyle(font: bengaliFont, fontSize: 16),
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Widget highlightText(String text, String? query) {
    if (query == null || query.isEmpty)
      return SelectableText(
        text,
        style: const TextStyle(fontSize: 16, height: 1.5),
      );
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    int index;
    while ((index = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (index > start)
        spans.add(TextSpan(text: text.substring(start, index)));
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = index + query.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return SelectableText.rich(
      TextSpan(
        style: const TextStyle(fontSize: 16, height: 1.5),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OCR Result")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Bengali"),
                  selected: selectedLanguage == "Bengali",
                  onSelected: (_) => _switchLanguage("Bengali"),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text("English"),
                  selected: selectedLanguage == "English",
                  onSelected: (_) => _switchLanguage("English"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isTranslating
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: highlightText(displayedText, widget.highlight),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: displayedText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Text copied to clipboard")),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text("Copy"),
                ),
                ElevatedButton.icon(
                  onPressed: _generatePDF,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Save as PDF"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------- SAVED DOCUMENTS SCREEN -------------------------
class SavedDocumentsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> savedScans;
  const SavedDocumentsScreen({super.key, required this.savedScans});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Documents")),
      body: savedScans.isEmpty
          ? const Center(child: Text("No saved documents yet"))
          : ListView.builder(
              itemCount: savedScans.length,
              itemBuilder: (context, index) {
                final scan = savedScans[index];
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(scan["title"]),
                  subtitle: Text("Date: ${scan["date"]}"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DocumentDetailScreen(scan: scan),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// ------------------------- SEARCH SCREEN -------------------------

class SearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> recentScans;
  const SearchScreen({super.key, required this.recentScans});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String query = "";

  @override
  Widget build(BuildContext context) {
    final filtered = query.isEmpty
        ? []
        : widget.recentScans.where((scan) {
            final titleMatch = (scan["title"] ?? "").toLowerCase().contains(
              query.toLowerCase(),
            );
            final ocrMatch = (scan["ocrText"] ?? "").toLowerCase().contains(
              query.toLowerCase(),
            );
            return titleMatch || ocrMatch;
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Search Scans")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Search by keyword or title",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => query = val),
            ),
          ),
          Expanded(
            child: query.isEmpty
                ? const Center(child: Text("Type something to search"))
                : filtered.isEmpty
                ? const Center(child: Text("No results found"))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final scan = filtered[index];
                      return ListTile(
                        leading: (kIsWeb && scan["webImage"] != null)
                            ? Image.memory(
                                scan["webImage"],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : (scan["file"] != null
                                  ? Image.file(
                                      scan["file"],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.insert_drive_file)),
                        title: Text(scan["title"]),
                        subtitle: Text("Date: ${scan["date"]}"),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DocumentDetailScreen(
                                scan: scan,
                                keyword: query,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------- DOCUMENT DETAIL SCREEN -------------------------
class DocumentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> scan;
  final String? keyword;
  const DocumentDetailScreen({super.key, required this.scan, this.keyword});

  @override
  Widget build(BuildContext context) {
    final text = scan["ocrText"] ?? "";

    return Scaffold(
      appBar: AppBar(title: Text(scan["title"] ?? "Document")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: keyword != null && keyword!.isNotEmpty
              ? _buildHighlightedText(text, keyword!)
              : Text(text, style: const TextStyle(fontSize: 16, height: 1.5)),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String keyword) {
    final spans = <TextSpan>[];
    final query = keyword.toLowerCase();
    final lowerText = text.toLowerCase();
    int start = 0;
    int index;
    while ((index = lowerText.indexOf(query, start)) != -1) {
      if (index > start)
        spans.add(TextSpan(text: text.substring(start, index)));
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = index + query.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 16),
        children: spans,
      ),
    );
  }
}

// ------------------------- WEB OCR -------------------------
@JS('Tesseract')
external dynamic get Tesseract;

Future<String> recognizeTextWeb(Uint8List bytes, String lang) async {
  final base64Image = base64Encode(bytes);
  final dataUrl = 'data:image/png;base64,$base64Image';
  try {
    final promise = js_util.callMethod(Tesseract, 'recognize', [dataUrl, lang]);
    final result = await js_util.promiseToFuture(promise);
    final data = js_util.getProperty(result, 'data');
    final text = js_util.getProperty(data, 'text');
    return text ?? '';
  } catch (e) {
    return "Web OCR failed: $e";
  }
}
