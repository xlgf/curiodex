import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; // Add this dependency
import '../services/facts_service.dart';
import '../utils/custom_font_style.dart';

class FactsPage extends StatefulWidget {
  final String detectedObject;
  final double confidence;
  final String? imagePath; // Add image path parameter
  
  const FactsPage({
    super.key, 
    required this.detectedObject,
    required this.confidence,
    this.imagePath,
  });

  @override
  State<FactsPage> createState() => _FactsPageState();
}

class _FactsPageState extends State<FactsPage> {
  final FactsService _factsService = FactsService();
  final GlobalKey _cardKey = GlobalKey(); // Key for capturing the card
  List<String> facts = [];
  bool isLoading = true;
  String? error;
  bool _isSpeaking = false;
  bool _isDownloading = false;
  bool _isCardDownloaded = false; // Track if card has been downloaded
  List<String> _savedCards = []; // List to store saved card paths

  @override
  void initState() {
    super.initState();
    _loadFacts();
    _loadSavedCards();
  }

  @override
  void dispose() {
    _factsService.dispose();
    super.dispose();
  }

  Future<void> _loadFacts() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      
      final objectFacts = await _factsService.getFacts(widget.detectedObject);
      
      setState(() {
        facts = objectFacts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load facts: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadSavedCards() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cardsDir = Directory('${directory.path}/curiodex_cards');
      
      if (await cardsDir.exists()) {
        final files = cardsDir.listSync()
            .where((file) => file.path.endsWith('.png'))
            .map((file) => file.path)
            .toList();
        
        setState(() {
          _savedCards = files;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading saved cards: $e');
    }
  }

  Future<void> _downloadCard() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // Request storage permission
      PermissionStatus permission;
      if (Platform.isAndroid) {
        if (await _getAndroidVersion() >= 33) {
          permission = await Permission.photos.request();
        } else {
          permission = await Permission.storage.request();
        }
      } else {
        permission = await Permission.photos.request();
      }
      
      if (!permission.isGranted) {
        throw Exception('Gallery permission denied');
      }

      // Capture the widget as image
      RenderRepaintBoundary boundary = _cardKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to gallery
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'CurioDex_${widget.detectedObject}_$timestamp';
      
      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        name: fileName,
        quality: 100,
      );

      if (result['isSuccess'] == true) {
        // Also save to app directory for local gallery
        final directory = await getApplicationDocumentsDirectory();
        final cardsDir = Directory('${directory.path}/curiodex_cards');
        if (!await cardsDir.exists()) {
          await cardsDir.create(recursive: true);
        }

        final file = File('${cardsDir.path}/$fileName.png');
        await file.writeAsBytes(pngBytes);

        // Update saved cards list
        setState(() {
          _savedCards.add(file.path);
          _isCardDownloaded = true; // Mark card as downloaded
        });

        // Show success message
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card saved to gallery successfully!'),
            backgroundColor: Color(0xFFDAA523),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Failed to save to gallery');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save card: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<int> _getAndroidVersion() async {
    var androidInfo = await DeviceInfoPlugin().androidInfo;
    return androidInfo.version.sdkInt;
  }

  void _showGallery() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'SAVED CARDS',
                style: customFontStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            
            // Gallery grid
            Expanded(
              child: _savedCards.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No saved cards yet',
                            style: customFontStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.all(20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _savedCards.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // Show full image
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      File(_savedCards[index]),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFFDAA523),
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(_savedCards[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _speakObjectName() async {
    setState(() {
      _isSpeaking = true;
    });
    
    await _factsService.speakObjectName(widget.detectedObject);
    
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _speakAllFacts() async {
    if (facts.isEmpty) return;
    
    setState(() {
      _isSpeaking = true;
    });
    
    await _factsService.speakAllFacts(facts, widget.detectedObject);
    
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _speakSingleFact(String fact) async {
    setState(() {
      _isSpeaking = true;
    });
    
    await _factsService.speakSingleFact(fact);
    
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _stopSpeaking() async {
    await _factsService.stopSpeaking();
    setState(() {
      _isSpeaking = false;
    });
  }

  Widget _buildObjectCircle() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.imagePath != null ? Colors.transparent : Color(0xFFDAA523),
        border: widget.imagePath != null 
            ? Border.all(color: Color(0xFFDAA523), width: 3)
            : null,
      ),
      child: widget.imagePath != null
          ? ClipOval(
              child: Image.file(
                File(widget.imagePath!),
                fit: BoxFit.cover,
                width: 150,
                height: 150,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top Status Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            // ignore: deprecated_member_use
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    // Title
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFFDAA523),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'CURIODEX',
                          style: customFontStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    // Stop speaking button (if speaking)
                    if (_isSpeaking)
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _stopSpeaking,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              // ignore: deprecated_member_use
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.stop,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Object Display Card - Wrapped with RepaintBoundary for capture
              RepaintBoundary(
                key: _cardKey,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Object Circle with Photo
                      _buildObjectCircle(),
                      SizedBox(height: 16),
                      
                      // Object Name
                      Text(
                        widget.detectedObject.toUpperCase(),
                        style: customFontStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      
                      // Confidence
                      Text(
                        '[${widget.confidence.toStringAsFixed(1)}% Confidence]',
                        style: customFontStyle(
                          color: Colors.grey[600]!,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 12),
                      
                      // Sound Icon - Only show if card not downloaded
                      if (!_isCardDownloaded)
                        GestureDetector(
                          onTap: _isSpeaking ? _stopSpeaking : _speakObjectName,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isSpeaking ? Colors.red[100] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isSpeaking ? Icons.volume_off : Icons.volume_up,
                              color: _isSpeaking ? Colors.red[600] : Colors.grey[600],
                              size: 20,
                            ),
                          ),
                        ),
                      
                      SizedBox(height: 20),
                      
                      // Fun Facts Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fun Facts Header with Speak All Button (only if not downloaded)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FUN FACTS',
                                style: customFontStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              // Only show Play All button if card not downloaded
                              if (facts.isNotEmpty && !isLoading && !_isCardDownloaded)
                                GestureDetector(
                                  onTap: _isSpeaking ? _stopSpeaking : _speakAllFacts,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      // ignore: deprecated_member_use
                                      color: _isSpeaking ? Colors.red[50] : Color(0xFFDAA523).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _isSpeaking ? Colors.red : Color(0xFFDAA523),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isSpeaking ? Icons.stop : Icons.play_arrow,
                                          size: 16,
                                          color: _isSpeaking ? Colors.red : Color(0xFFDAA523),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          _isSpeaking ? 'Stop' : 'Play All',
                                          style: customFontStyle(
                                            color: _isSpeaking ? Colors.red : Color(0xFFDAA523),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 16),
                          
                          // Facts Content
                          if (isLoading)
                            Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(
                                    color: Color(0xFFDAA523),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Loading interesting facts...',
                                    style: customFontStyle(
                                      color: Colors.grey[600]!,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (error != null)
                            Column(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  error!,
                                  style: customFontStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadFacts,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFFDAA523),
                                    foregroundColor: Colors.black,
                                  ),
                                  child: Text('Retry'),
                                ),
                              ],
                            )
                          else if (facts.isEmpty)
                            Text(
                              'No facts available for this object.',
                              style: customFontStyle(
                                color: Colors.grey[600]!,
                                fontSize: 12,
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: facts.map((fact) => Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: customFontStyle(
                                        color: Color(0xFFDAA523),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: _isCardDownloaded ? null : () => _speakSingleFact(fact),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 4),
                                          child: Text(
                                            fact,
                                            style: customFontStyle(
                                              color: Colors.black87,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Individual fact play button - Only show if card not downloaded
                                    if (!_isCardDownloaded)
                                      GestureDetector(
                                        onTap: () => _speakSingleFact(fact),
                                        child: Container(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.play_circle_outline,
                                            size: 16,
                                            color: Color(0xFFDAA523),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )).toList(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Bottom Navigation
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery button (left)
                    GestureDetector(
                      onTap: _showGallery,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Color(0xFFDAA523),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.photo_library,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                    
                    // Center search button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFFDAA523),
                            width: 5,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.black,
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              Icons.search,
                              size: 48,
                              color: Color(0xFF232323),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Download button (right)
                    GestureDetector(
                      onTap: _isDownloading ? null : _downloadCard,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _isDownloading ? Colors.grey : Color(0xFFDAA523),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _isDownloading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : Icon(
                                Icons.download,
                                color: Colors.black,
                                size: 24,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}