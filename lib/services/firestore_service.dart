import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../models/project.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Ensure the user's personal project exists
  Future<void> ensurePersonalProjectExists(String userId) async {
    final String personalProjectId = 'personal_$userId';

    DocumentSnapshot personalProject =
        await _db.collection('projects').doc(personalProjectId).get();

    if (!personalProject.exists) {
      // Fetch the owner's username
      final userDoc = await _db.collection('users').doc(userId).get();
      final username = userDoc.data()?['username'];

      if (username == null) {
        throw Exception('Username not found for the user.');
      }

      // Create the personal project
      await _db.collection('projects').doc(personalProjectId).set({
        'id': personalProjectId,
        'name': 'Personal Project',
        'ownerId': userId,
        'participants': [username], // Use username instead of user ID
        'isPersonal': true, // Mark as personal project
        'createdAt': FieldValue.serverTimestamp(),
        'index': 0,
      });

      print('Personal project created successfully for username: $username');
    }
  }


  /// Create a project (personal or shared)
  Future<void> createProject(String name, String ownerId, {bool isPersonal = false}) async {
    try {
      // Fetch the owner's username from Firestore
      final userDoc = await _db.collection('users').doc(ownerId).get();
      final username = userDoc.data()?['username'];

      if (username == null) {
        throw Exception('Username not found for the project creator.');
      }

      // Prepare project data
      final projectData = {
        'name': name,
        'ownerId': ownerId,
        'participants': [username], // Add the owner's username
        'isPersonal': isPersonal,
        'createdAt': FieldValue.serverTimestamp(),
        'index': DateTime.now().millisecondsSinceEpoch,
      };

      // Save the project to Firestore
      await _db.collection('projects').add(projectData);

      print('Personal project created successfully for username: $username');
    } catch (e) {
      print('Error creating project: $e');
      throw Exception('Failed to create project.');
    }
  }

  Future<int> _getNextProjectIndex(String ownerId) async {
    final querySnapshot = await _db
        .collection('projects')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final lastIndex = querySnapshot.docs.last['index'] as int;
      print('Last project index: $lastIndex');
      return lastIndex + 1;
    } else {
      return 0; // Start at 0 if no projects exist
    }
  }

  /// Fetch projects for the current user
  Stream<List<Project>> getProjectsForUser(String userId) async* {
    try {
      // Fetch the current user's username
      final userDoc = await _db.collection('users').doc(userId).get();
      final username = userDoc.data()?['username'];

      if (username == null) {
        throw Exception('Username not found for the current user.');
      }

      // Fetch projects where the username is in the participants list
      yield* _db
          .collection('projects')
          .where('participants', arrayContains: username)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => Project.fromFirestore(doc)).toList());
    } catch (e) {
      print('Error fetching projects: $e');
      yield [];
    }
  }

  /// Create a new task in the specified project
  Future<void> createTask(
    String projectId,
    String title,
    String description, {
    String priority = 'Medium',
    String? assigneeUsername,
    DateTime? dueDate, // Optional due date
  }) async {
    final String taskId = FirebaseFirestore.instance.collection('tasks').doc().id;

    await FirebaseFirestore.instance.collection('tasks').doc(taskId).set({
      'id': taskId,
      'projectId': projectId,
      'title': title,
      'description': description,
      'priority': priority,
      'assignee': assigneeUsername,
      'status': 'To Do', // Default status
      'createdAt': FieldValue.serverTimestamp(),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
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
    return FirebaseFirestore.instance
        .collection('tasks')
        .where('projectId', isEqualTo: projectId)
        .orderBy('dueDate') // Sort by nearest deadline
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

  Future<List<String>> getProjectParticipants(String projectId) async {
    final doc = await _db.collection('projects').doc(projectId).get();

    if (!doc.exists) {
      return [];
    }

    // Assuming the 'participants' field already contains usernames
    return List<String>.from(doc.data()?['participants'] ?? []);
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

  Future<void> addUserToProject(String projectId, String username) async {
    // Fetch user by username
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      throw Exception('No user found with this username.');
    }

    // Add the username to the project's participants list
    await FirebaseFirestore.instance.collection('projects').doc(projectId).update({
      'participants': FieldValue.arrayUnion([username]),
    });
  }

  Future<void> addUserToProjectByUsername(String projectId, String username) async {
    final userQuery = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      throw Exception('No user found with this username.');
    }

    await _db.collection('projects').doc(projectId).update({
      'participants': FieldValue.arrayUnion([username]),
    });
  }




  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    try {
      await _db.collection('projects').doc(projectId).update(data);
      print('Project $projectId updated successfully!');
    } catch (e) {
      print('Error updating project $projectId: $e');
    }
  }

  Future<void> updateProjectIndexes(List<Project> reorderedProjects) async {
    for (int i = 0; i < reorderedProjects.length; i++) {
      await _db.collection('projects').doc(reorderedProjects[i].id).update({
        'index': i,
      });
    }
  }

  Future<void> updateTask(
    String taskId, {
    String? title,
    String? description,
    String? status,
    String? priority,
    String? assignee,
    DateTime? dueDate,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (status != null) updates['status'] = status;
    if (priority != null) updates['priority'] = priority;
    if (assignee != null) updates['assignee'] = assignee;
    if (dueDate != null) updates['dueDate'] = Timestamp.fromDate(dueDate);

    await FirebaseFirestore.instance.collection('tasks').doc(taskId).update(updates);
  }

  Stream<List<Task>> getAssignedTasks(String userId) {
    return FirebaseFirestore.instance
        .collection('tasks')
        .where('assignee', isEqualTo: userId) // Only fetch tasks assigned to the user
        .orderBy('dueDate') // Sort by nearest deadline
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList());
  }

  Stream<Project?> getProjectById(String projectId) {
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .snapshots()
        .map((snapshot) =>
            snapshot.exists ? Project.fromFirestore(snapshot) : null);
  }

  Future<void> migrateParticipantsToUsernames() async {
    final projects = await FirebaseFirestore.instance.collection('projects').get();

    for (final project in projects.docs) {
      final participantIds = List<String>.from(project.data()['participants'] ?? []);
      final usernames = <String>[];

      for (final userId in participantIds) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final username = userDoc.data()?['username'];
          if (username != null) {
            usernames.add(username);
          }
        }
      }

      // Update the project with usernames
      await project.reference.update({
        'participants': usernames,
      });
    }

    print('Migration completed.');
  }

  Future<void> migrateProjectCreatorsToUsernames() async {
    final projects = await FirebaseFirestore.instance.collection('projects').get();

    for (final project in projects.docs) {
      final participants = List<String>.from(project.data()['participants'] ?? []);
      final updatedParticipants = <String>[];

      for (final participantId in participants) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(participantId).get();
        if (userDoc.exists) {
          final username = userDoc.data()?['username'];
          if (username != null) {
            updatedParticipants.add(username);
          }
        }
      }

      // Update the project with usernames
      await project.reference.update({'participants': updatedParticipants});
    }

    print('Migration completed.');
  }

}


