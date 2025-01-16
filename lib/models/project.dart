import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Project {
  final String id; // Unique ID for the project
  final String name; // Name of the project
  final String ownerId; // User ID of the project owner
  final List<String> participants; // List of participant user IDs
  final bool isPersonal; // True for personal projects
  final DateTime createdAt; // When the project was created
  final Color? cardColor;

  Project({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.participants,
    required this.isPersonal,
    required this.createdAt,
    required this.cardColor,
  });

  /// Factory constructor to create a Project object from Firestore
  factory Project.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Project(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Project',
      ownerId: data['ownerId'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      isPersonal: data['isPersonal'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      cardColor: data['cardColor'] != null
          ? Color(data['cardColor'] as int)
          : null,
    );
  }

  /// Converts a Project object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'participants': participants,
      'isPersonal': isPersonal,
      'createdAt': createdAt,
      'cardColor': cardColor?.value,
    };
  }
}
