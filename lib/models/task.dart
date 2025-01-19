import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final String status;
  final String? assignee;
  final String priority;
  final String projectId;
  final DateTime createdAt;
  final DateTime? dueDate; // New field for due date

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.assignee,
    required this.priority,
    required this.projectId,
    required this.createdAt,
    this.dueDate,
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
      priority: data['priority'] ?? 'Medium',
      projectId: data['projectId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
    );
  }

  /// Converts a Task object into a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'assignee': assignee,
      'priority': priority,
      'projectId': projectId,
      'createdAt': createdAt,
      'dueDate': dueDate,
    };
  }
}
