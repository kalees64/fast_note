import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import '../widgets/note_card.dart';
import '../widgets/search_bar_widget.dart';
import '../utils/toast_helper.dart';
import '../services/pdf_service.dart';

import 'dart:developer';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'note_detail_screen.dart';

enum SortOption { newest, oldest, alphabetical, exportPdf, deleteAll }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  String _searchQuery = '';
  SortOption _sortOption = SortOption.newest;

  bool _isListening = false;
  // String _currentLocaleId = ''; // This line was removed in the provided diff, but not explicitly in instructions. Keeping it as per original.

  // Animation controller for the pulsing effect
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _initSpeech();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    // Request permission early or check status
    await [
      Permission.microphone,
      Permission.bluetooth,
      Permission.bluetoothConnect, // For Android 12+
    ].request();
  }

  Future<void> _loadNotes() async {
    final notes = await _storageService.getNotes();
    setState(() {
      _notes = notes;
      _applyFilterAndSort();
    });
  }

  void _applyFilterAndSort() {
    List<Note> temp = _notes.where((n) {
      return n.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    switch (_sortOption) {
      case SortOption.newest:
        temp.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldest:
        temp.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.alphabetical:
        temp.sort((a, b) => a.content.compareTo(b.content));
        break;
      case SortOption.exportPdf:
        break;
      case SortOption.deleteAll:
        break;
    }

    setState(() {
      _filteredNotes = temp;
    });
  }

  // Refined listen logic
  // Refined listen logic
  String _liveText = '';

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      // Save image to app directory to persist it
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = "${const Uuid().v4()}.jpg";
      final String localPath = "${directory.path}/$fileName";

      await image.saveTo(localPath);

      // Create Note
      final newNote = Note(
        id: const Uuid().v4(),
        content: "Image Note", // Or empty string, or let user edit later
        createdAt: DateTime.now(),
        imagePath: localPath,
      );

      await _storageService.saveNote(newNote);
      _loadNotes();

      if (mounted) {
        showTopToast(context, 'Image Saved!');
      }
    }
  }

  // Original "Hold to Record" handlers
  void _onListenPress() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _liveText = '';
        });
        _speech.listen(
          onResult: (val) {
            setState(() {
              _liveText = val.recognizedWords;
            });
          },
          listenFor: const Duration(seconds: 300), // Max 5 mins
          pauseFor: const Duration(seconds: 5), // Silence timeout
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        );
      }
    }
  }

  void _onListenRelease() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);

      // Wait for the speech engine to process the last bit of audio
      await Future.delayed(const Duration(milliseconds: 500));

      if (_liveText.isNotEmpty) {
        final newNote = Note(
          id: const Uuid().v4(),
          content: _liveText,
          createdAt: DateTime.now(),
        );
        await _storageService.saveNote(newNote);
        _loadNotes();
        _liveText = '';

        if (mounted) {
          showTopToast(context, 'Note Saved!');
        }
      }
    }
  }

  Future<void> _deleteNote(String id) async {
    await _storageService.deleteNote(id);
    _loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar:
          true, // Allow liquid background to go behind app bar
      appBar: AppBar(
        title: const Text('Fast Note'),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort, color: Colors.white),
            onSelected: (SortOption result) async {
              if (result == SortOption.exportPdf) {
                if (_notes.isNotEmpty) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return const Center(child: CircularProgressIndicator());
                    },
                  );
                  try {
                    final pdfBytes = await PdfService().generatePdf(_notes);

                    if (mounted) {
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pop(); // Dismiss loader

                      // Show Action Dialog
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text('PDF Ready'),
                            content: const Text(
                              'Choose an action for your PDF.',
                            ),
                            actions: [
                              TextButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await PdfService().savePdfFile(
                                    pdfBytes,
                                    'fast_note_export.pdf',
                                  );
                                  if (mounted)
                                    showTopToast(
                                      context,
                                      'PDF Saved to Downloads!',
                                    );
                                },
                                icon: const Icon(Icons.download),
                                label: const Text('Download'),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A00E0),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await PdfService().sharePdfFile(
                                    pdfBytes,
                                    'fast_note_export.pdf',
                                  );
                                },
                                icon: const Icon(Icons.share),
                                label: const Text('Share'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  } catch (e) {
                    if (mounted)
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pop(); // Ensure loader is dismissed on error
                    log('PDF Error: $e');
                  }
                }
              } else if (result == SortOption.deleteAll) {
                if (_notes.isNotEmpty) {
                  bool? confirm = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text('Delete All Notes?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await _storageService.deleteAllNotes();
                    await _loadNotes();
                    if (mounted) showTopToast(context, 'All Notes Deleted!');
                  }
                }
              } else {
                setState(() {
                  _sortOption = result;
                  _applyFilterAndSort();
                });
              }
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<SortOption>>[
                const PopupMenuItem<SortOption>(
                  value: SortOption.newest,
                  child: Text('Newest First'),
                ),
                const PopupMenuItem<SortOption>(
                  value: SortOption.oldest,
                  child: Text('Oldest First'),
                ),
                const PopupMenuItem<SortOption>(
                  value: SortOption.alphabetical,
                  child: Text('A-Z'),
                ),
                if (_notes.isNotEmpty)
                  const PopupMenuItem<SortOption>(
                    value: SortOption.exportPdf,
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Export PDF'),
                      ],
                    ),
                  ),
                const PopupMenuItem<SortOption>(
                  value: SortOption.deleteAll,
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete All'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Liquid Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF8E2DE2),
                  Color(0xFF4A00E0),
                ], // Purple to Blue liquid
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Watermark
          Center(
            child: IgnorePointer(
              child: Text(
                'VK',
                style: TextStyle(
                  fontSize: 250,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(
                    0.1,
                  ), // White watermark for colorful bg
                ),
              ),
            ),
          ),

          // Background Shapes (Optional for "Liquid" feel)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                SearchHeader(
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilterAndSort();
                  },
                ),
                Expanded(
                  child: _filteredNotes.isEmpty
                      ? Center(
                          child: Text(
                            'No notes yet.\nHold the mic to record.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            bottom: 100,
                            left: 4,
                            right: 4,
                            top: 4,
                          ), // Reduced padding further
                          itemCount: _filteredNotes.length,
                          itemBuilder: (context, index) {
                            return NoteCard(
                              note: _filteredNotes[index],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => NoteDetailScreen(
                                      note: _filteredNotes[index],
                                    ),
                                  ),
                                );
                              },
                              onDelete: () =>
                                  _deleteNote(_filteredNotes[index].id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Pencil Edit Button (Bottom Right)
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'camera_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4A00E0),
                  onPressed: _pickImage,
                  child: const Icon(Icons.camera_alt),
                ),
                const SizedBox(height: 16),
                FloatingActionButton.small(
                  // Reduced size
                  heroTag: 'edit_btn',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4A00E0),
                  onPressed: _showManualNoteDialog,
                  child: const Icon(Icons.edit),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: GestureDetector(
        onLongPress: _onListenPress,
        onLongPressUp: _onListenRelease,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isListening ? _scaleAnimation.value : 1.0,
              child: Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF512F),
                      Color(0xFFDD2476),
                    ], // Vibrant Orange-Pink for Mic
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: _isListening ? 20 : 10,
                      spreadRadius: _isListening ? 5 : 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showManualNoteDialog() {
    String content = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('New Note'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter your note...',
              border: InputBorder.none,
            ),
            maxLines: 3,
            onChanged: (val) => content = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () async {
                if (content.trim().isNotEmpty) {
                  final newNote = Note(
                    id: const Uuid().v4(),
                    content: content,
                    createdAt: DateTime.now(),
                  );
                  await _storageService.saveNote(newNote);
                  _loadNotes();
                  if (mounted) {
                    Navigator.pop(context);
                    showTopToast(context, 'Note Saved!');
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
