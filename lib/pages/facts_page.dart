import 'package:flutter/material.dart';
import '../services/facts_service.dart';
import '../utils/custom_font_style.dart';

class FactsPage extends StatefulWidget {
  final String detectedObject;
  final double confidence;
  
  const FactsPage({
    super.key, 
    required this.detectedObject,
    required this.confidence,
  });

  @override
  State<FactsPage> createState() => _FactsPageState();
}

class _FactsPageState extends State<FactsPage> {
  final FactsService _factsService = FactsService();
  List<String> facts = [];
  bool isLoading = true;
  String? error;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _loadFacts();
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
              
              // Object Display Card
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Object Circle
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFDAA523),
                      ),
                    ),
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
                    
                    // Sound Icon
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
                  ],
                ),
              ),
              
              SizedBox(height: 20),
              
              // Fun Facts Section
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fun Facts Header with Speak All Button
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
                        if (facts.isNotEmpty && !isLoading)
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
                                      fontWeight: FontWeight.w600,
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
                                  onTap: () => _speakSingleFact(fact),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      fact,
                                      style: customFontStyle(
                                        color: Colors.grey[700]!,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Individual fact play button
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
              ),
              
              // Bottom Navigation
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Left placeholder
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
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
                    
                    // Right placeholder
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
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