class Note {
  final String id;
  final String content;
  final DateTime createdAt;

  final String? imagePath;

  Note({
    required this.id,
    required this.content,
    required this.createdAt,
    this.imagePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'imagePath': imagePath,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      imagePath: json['imagePath'],
    );
  }
}
