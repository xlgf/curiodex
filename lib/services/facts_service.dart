import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';

class FactsService {
  // TTS instance
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  
  // Constructor to initialize TTS
  FactsService() {
    _initializeTts();
  }

  // Initialize TTS settings
  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    // Set up completion handler
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    
    // Set up error handler
    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  // Sample facts database - in a real app, this would come from an API or local database
  static final Map<String, List<String>> _factsDatabase = {
    'person': [
      'The human brain contains approximately 86 billion neurons.',
      'Humans are the only species known to blush.',
      'Your body produces about 2 million new red blood cells every second.',
      'The strongest muscle in the human body is the masseter (jaw muscle).',
      'Humans share about 60% of their DNA with bananas.',
    ],
    'cat': [
      'Cats can jump up to 6 times their height.',
      'A group of cats is called a "clowder".',
      'Cats can rotate their ears 180 degrees.',
      'Ancient Egyptians worshipped cats and considered them sacred.',
      'Cats spend 70% of their lives sleeping.',
    ],
    'dog': [
      'Dogs are the most popular pet on the planet!',
      'They can learn over 100 words and gestures!',
      'Dogs can learn more than 1,000 words.',
      'Dogs use body language to express their feelings.',
      'Dogs sweat through their paw pads.',
    ],
    'car': [
      'The first car was invented in 1885 by Karl Benz.',
      'There are over 1 billion cars currently in use worldwide.',
      'The average car contains over 30,000 parts.',
      'Electric cars actually date back to the 1830s.',
      'The longest traffic jam lasted 12 days in China.',
    ],
    'book': [
      'The first printed book was the Gutenberg Bible in 1455.',
      'The longest novel ever written has over 4 million words.',
      'Libraries predate the invention of books by thousands of years.',
      'The smell of old books comes from organic compounds breaking down.',
      'Iceland publishes more books per capita than any other country.',
    ],
    'tree': [
      'Trees can live for thousands of years - the oldest known tree is over 4,800 years old.',
      'A large tree can lift up to 100 gallons of water per day.',
      'Trees communicate with each other through underground fungal networks.',
      'One tree can produce enough oxygen for two people per day.',
      'Trees can lower surrounding air temperature by up to 20°F.',
    ],
    'phone': [
      'The first mobile phone call was made in 1973.',
      'Your smartphone has more computing power than NASA used to land on the moon.',
      'The average person checks their phone 96 times per day.',
      'There are more mobile phones than people on Earth.',
      'The first text message was sent in 1992 and said "Merry Christmas".',
    ],
    'chair': [
      'The first chairs were created in ancient Egypt around 3000 BCE.',
      'The electric chair was invented by a dentist.',
      'The most expensive chair ever sold cost over 28 million.',
      'Sitting for long periods can reduce life expectancy.',
      'The word "chair" comes from the Greek word "kathedra".',
    ],
    'flower': [
      'Flowers existed before bees - they were pollinated by beetles.',
      'The corpse flower can grow up to 10 feet tall and smells like rotting meat.',
      'Sunflowers can help clean radioactive soil.',
      'The world\'s oldest flower is 130 million years old.',
      'Broccoli is actually a flower that we eat before it blooms.',
    ],
    'bicycle': [
      'The first bicycle was invented in 1817 and had no pedals.',
      'Bicycles are the most efficient way humans have discovered to travel.',
      'More people in the world own bicycles than cars.',
      'The fastest speed on a bicycle is 183.9 mph.',
      'In Amsterdam, there are more bicycles than residents.',
    ],
  };

  // Generic facts for unknown objects
  static final List<String> _genericFacts = [
    'Every object has its own unique story and purpose.',
    'The study of objects and their properties is called material science.',
    'Everything around us is made up of atoms and molecules.',
    'Objects can be classified by their physical and chemical properties.',
    'The way we perceive objects depends on how light interacts with them.',
    'Many everyday objects have fascinating histories of invention and development.',
  ];

  Future<List<String>> getFacts(String objectName) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(1200)));
    
    // Normalize the object name (lowercase, remove extra spaces)
    String normalizedName = objectName.toLowerCase().trim();
    
    // Try to find exact match first
    if (_factsDatabase.containsKey(normalizedName)) {
      return List<String>.from(_factsDatabase[normalizedName]!);
    }
    
    // Try to find partial matches
    for (String key in _factsDatabase.keys) {
      if (normalizedName.contains(key) || key.contains(normalizedName)) {
        return List<String>.from(_factsDatabase[key]!);
      }
    }
    
    // If no specific facts found, return generic facts
    return List<String>.from(_genericFacts);
  }

  // TTS Methods
  Future<void> speakObjectName(String objectName) async {
    if (_isSpeaking) {
      await stopSpeaking();
    }
    
    _isSpeaking = true;
    String textToSpeak = "This is a $objectName";
    await _flutterTts.speak(textToSpeak);
  }

  Future<void> speakAllFacts(List<String> facts, String objectName) async {
    if (_isSpeaking) {
      await stopSpeaking();
    }
    
    if (facts.isEmpty) return;
    
    _isSpeaking = true;
    String introduction = "Here are some interesting facts about $objectName. ";
    String allFacts = facts.join(". ");
    String textToSpeak = introduction + allFacts;
    
    await _flutterTts.speak(textToSpeak);
  }

  Future<void> speakSingleFact(String fact) async {
    if (_isSpeaking) {
      await stopSpeaking();
    }
    
    _isSpeaking = true;
    await _flutterTts.speak(fact);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  bool get isSpeaking => _isSpeaking;

  // TTS Settings
  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  // Get available languages
  Future<List<String>> getLanguages() async {
    return await _flutterTts.getLanguages;
  }

  // Get available voices
  Future<List<Map<String, String>>> getVoices() async {
    return await _flutterTts.getVoices;
  }

  // Method to add new facts (for future expansion)
  void addFacts(String objectName, List<String> facts) {
    String normalizedName = objectName.toLowerCase().trim();
    if (_factsDatabase.containsKey(normalizedName)) {
      _factsDatabase[normalizedName]!.addAll(facts);
    } else {
      _factsDatabase[normalizedName] = List<String>.from(facts);
    }
  }

  // Method to get all available objects with facts
  List<String> getAvailableObjects() {
    return _factsDatabase.keys.toList();
  }

  // Method to search for facts by keyword
  Future<Map<String, List<String>>> searchFactsByKeyword(String keyword) async {
    await Future.delayed(Duration(milliseconds: 500));
    
    Map<String, List<String>> results = {};
    String normalizedKeyword = keyword.toLowerCase().trim();
    
    for (String objectName in _factsDatabase.keys) {
      List<String> matchingFacts = _factsDatabase[objectName]!
          .where((fact) => fact.toLowerCase().contains(normalizedKeyword))
          .toList();
      
      if (matchingFacts.isNotEmpty) {
        results[objectName] = matchingFacts;
      }
    }
    
    return results;
  }

  // Dispose method to clean up resources
  void dispose() {
    _flutterTts.stop();
  }
}