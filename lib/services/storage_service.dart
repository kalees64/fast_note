import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class StorageService {
  static const String _storageKey = 'notes';

  Future<void> saveNote(Note note) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> notesJson = prefs.getStringList(_storageKey) ?? [];

    // Add new note
    notesJson.add(jsonEncode(note.toJson()));

    await prefs.setStringList(_storageKey, notesJson);
  }

  Future<void> deleteNote(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notesJson = prefs.getStringList(_storageKey) ?? [];

    notesJson.removeWhere((noteStr) {
      final noteMap = jsonDecode(noteStr);
      return noteMap['id'] == id;
    });

    await prefs.setStringList(_storageKey, notesJson);
  }

  Future<void> deleteAllNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<List<Note>> getNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> notesJson = prefs.getStringList(_storageKey) ?? [];

    return notesJson
        .map((noteStr) => Note.fromJson(jsonDecode(noteStr)))
        .toList();
  }
}
