import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../models/project.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Ensure the user's personal project exists
  Future<void> ensurePersonalProjectExists(String userId) async {
    final String personalProjectId = 'personal_$userId';

    DocumentSnapshot personalProject = await _db.collection('projects').doc(personalProjectId).get();

    if (!personalProject.exists) {
      await _db.collection('projects').doc(personalProjectId).set({
        'id': personalProjectId,
        'name': 'Personal Project',
        'ownerId': userId,
        'participants': [userId],
        'isPersonal': true, // Mark as personal project
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Create a project (personal or shared)
  Future<void> createProject(String name, String ownerId,
      {bool isPersonal = false}) async {
    final String projectId = isPersonal
        ? 'personal_$ownerId'
        : _db.collection('projects').doc().id;

    await _db.collection('projects').doc(projectId).set({
      'id': projectId,
      'name': name,
      'isPersonal': isPersonal,
      'ownerId': ownerId,
      'participants': [ownerId],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch projects for the current user
  Stream<List<Project>> getProjectsForUser(String userId) {
    return _db
        .collection('projects')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Project.fromFirestore(doc)).toList());
  }

  /// Create a new task in the specified project
  Future<void> createTask(String projectId, String title, String description) async {
    final String taskId = _db.collection('tasks').doc().id;

    await _db.collection('tasks').doc(taskId).set({
      'id': taskId,
      'title': title,
      'description': description,
      'status': 'To Do',
      'assignee': null, // Unassigned by default
      'projectId': projectId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Claim an unassigned task
  Future<void> claimTask(String taskId, String userId) async {
    await _db.collection('tasks').doc(taskId).update({
      'assignee': userId,
    });
  }

  /// Assign a task to a specific user (Owner-only functionality)
  Future<void> assignTask(String taskId, String userId) async {
    await _db.collection('tasks').doc(taskId).update({
      'assignee': userId,
    });
  }

  /// Get all tasks for a specific project
  Stream<List<Task>> getProjectTasks(String projectId) {
    return _db
        .collection('tasks')
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList());
  }

  /// Fetch user data by user ID
  Future<Map<String, dynamic>> getUserData(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    } else {
      throw Exception('User data not found');
    }
  }

  /// Update or set user data
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).set(data, SetOptions(merge: true));
  }

  /// Delete a project and its associated tasks
  Future<void> deleteProject(String projectId) async {
    if (projectId.startsWith('personal_')) {
      throw Exception('Personal projects cannot be deleted.');
    }

    // Delete all tasks in the project
    final tasksSnapshot = await _db.collection('tasks').where('projectId', isEqualTo: projectId).get();
    for (final doc in tasksSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the project itself
    await _db.collection('projects').doc(projectId).delete();
  }

  /// Delete a specific task
  Future<void> deleteTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).delete();
  }

  Future<void> addMissingCreatedAtFields() async {
    final projectsSnapshot = await _db.collection('projects').get();
    for (var doc in projectsSnapshot.docs) {
      if (!doc.data().containsKey('createdAt')) {
        print('Updating project: ${doc.id}');
        await doc.reference.update({
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> inviteUserToProject(String projectId, String email) async {
    final FirebaseFirestore _db = FirebaseFirestore.instance;

    try {
      // Find the user by email
      final userSnapshot = await _db.collection('users').where('email', isEqualTo: email).get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('User not found');
      }

      final invitedUserId = userSnapshot.docs.first.id;

      // Update the participants array in the project
      await _db.collection('projects').doc(projectId).update({
        'participants': FieldValue.arrayUnion([invitedUserId]),
      });

      print('User added to project: $invitedUserId');
    } catch (e) {
      print('Error inviting user to project: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getProjectParticipants(String projectId) async {
    try {
      final doc = await _db.collection('projects').doc(projectId).get();

      if (!doc.exists) {
        print('Project not found: $projectId');
        return [];
      }

      final data = doc.data();
      if (data == null || !data.containsKey('participants')) {
        print('No participants found in the project: $projectId');
        return [];
      }

      // Fetch user details for each participant
      final List<String> participantIds = List<String>.from(data['participants']);
      List<Map<String, dynamic>> participants = [];

      for (String userId in participantIds) {
        final userDoc = await _db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          participants.add({
            'email': userData?['email'] ?? 'Unknown',
            'role': userData?['role'] ?? 'Member',
          });
        }
      }

      return participants;
    } catch (e) {
      print('Error fetching project participants: $e');
      return [];
    }
  }

  Future<String?> findUserIdByEmail(String email) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('No user found with email: $email');
        return null;
      }

      final userId = querySnapshot.docs.first.id;
      print('User found: $email -> $userId');
      return userId;
    } catch (e) {
      print('Error finding user by email: $e');
      return null;
    }
  }

  Future<void> addUserToProject(String projectId, String email) async {
    try {
      // Fetch the user ID by email
      final userId = await findUserIdByEmail(email);

      if (userId == null) {
        print('No user found with email: $email');
        return;
      }

      // Add the user to the project's participants
      await _db.collection('projects').doc(projectId).update({
        'participants': FieldValue.arrayUnion([userId]),
      });

      print('User $email added to project $projectId successfully!');
    } catch (e) {
      print('Error adding user to project: $e');
    }
  }


  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    try {
      await _db.collection('projects').doc(projectId).update(data);
      print('Project $projectId updated successfully!');
    } catch (e) {
      print('Error updating project $projectId: $e');
    }
  }

}


