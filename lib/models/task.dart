import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final String status;
  final String? assignee; // Nullable, for unassigned tasks
  final String projectId;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.assignee,
    required this.projectId,
  });

  /// Factory constructor to create a Task object from Firestore document
  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'To Do',
      assignee: data['assignee'],
      projectId: data['projectId'] ?? '',
    );
  }

  /// Converts a Task object into a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'assignee': assignee,
      'projectId': projectId,
    };
  }
}
