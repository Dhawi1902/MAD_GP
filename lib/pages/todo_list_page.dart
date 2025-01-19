import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/task.dart';
import '../models/project.dart';
import 'project_settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TodoListPage extends StatefulWidget {
  @override
  _TodoListPageState createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Center(child: Text('User not logged in.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Projects'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showCreateProjectDialog(context),
          ),
          // Debug Button
          // IconButton(
          //   icon: Icon(Icons.bug_report),
          //   onPressed: _testQuery, // Debugging method
          //   tooltip: 'Test Firestore Query',
          // ),
        ],
      ),
      body: StreamBuilder<List<Project>>(
        stream: _firestoreService.getProjectsForUser(_currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('Stream is loading...');
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            print('Snapshot has no data. Snapshot: $snapshot');
            return Center(child: Text('No projects found.'));
          }

          // final projects = snapshot.data;
          // if (projects == null || projects.isEmpty) {
          //   print('No projects found in the fetched data.');
          //   return Center(child: Text('No projects found.'));
          // }

          // print('Projects fetched in StreamBuilder: ${projects.length}');
          // for (var project in projects) {
          //   print('Project: ${project.name}, Index: ${project.index}');
          // }

          // Fetch and re-sort projects
          List<Project> projects = snapshot.data!;
          projects.sort((a, b) {
            // Personal project first
            if (a.isPersonal && !b.isPersonal) return -1;
            if (!a.isPersonal && b.isPersonal) return 1;

            // If both are not personal, sort by createdAt (oldest first)
            return a.createdAt.compareTo(b.createdAt);
          });

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return _buildProjectCard(context, project);
            },
          );
        },
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, Project project) {
    return Card(
      child: ListTile(
        title: Text(project.name),
        subtitle:
            Text(project.isPersonal ? 'Personal Project' : 'Sharable Project'),
        // trailing: Row(
        //   mainAxisSize: MainAxisSize.min,
        //   children: [
        //     if (!project.isPersonal)
        //       IconButton(
        //         icon: Icon(Icons.settings),
        //         onPressed: () {
        //           Navigator.push(
        //             context,
        //             MaterialPageRoute(
        //               builder: (context) =>
        //                   ProjectSettingsPage(project: project),
        //             ),
        //           );
        //         },
        //       ),
        //   ],
        // ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetailPage(project: project),
            ),
          );
        },
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Project'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: 'Project Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await _firestoreService.createProject(
                  name,
                  _currentUser!.uid,
                  isPersonal: false, // Sharable project by default
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Project name cannot be empty!')),
                );
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}

class ProjectDetailPage extends StatelessWidget {
  final Project project;

  const ProjectDetailPage({Key? key, required this.project}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectSettingsPage(project: project),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: TaskList(project: project)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () => _showCreateTaskDialog(context, project),
              child: Text('Create Task'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProject(BuildContext context, Project project) {
    if (project.isPersonal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Personal projects cannot be deleted.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Project'),
        content: Text(
            'Are you sure you want to delete this project? All associated tasks will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await FirestoreService().deleteProject(project.id);
              Navigator.pop(context);
              Navigator.pop(context); // Navigate back to the project list
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCreateTaskDialog(BuildContext context, Project project) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String selectedPriority = 'Medium'; // Default priority
    String? selectedAssignee;
    DateTime? selectedDueDate; // To store the selected due date
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Task Title'),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Task Description'),
              ),
              DropdownButtonFormField<String>(
                value: selectedPriority,
                onChanged: (value) => selectedPriority = value!,
                decoration: InputDecoration(labelText: 'Priority'),
                items: ['High', 'Medium', 'Low']
                    .map((priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        ))
                    .toList(),
              ),
              if (!project.isPersonal)
                DropdownButtonFormField<String>(
                  value: selectedAssignee,
                  onChanged: (value) => selectedAssignee = value,
                  decoration: InputDecoration(labelText: 'Assign to'),
                  items: project.participants
                      .map((username) => DropdownMenuItem(
                            value: username,
                            child: Text(username),
                          ))
                      .toList(),
                ),
              Row(
                children: [
                  Text('Due Date:'),
                  SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(), // No past dates
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        selectedDueDate = pickedDate;
                        print('Selected Due Date: $selectedDueDate');
                      }
                    },
                    child: Text(selectedDueDate == null
                        ? 'Select Date'
                        : selectedDueDate!.toLocal().toString().split(' ')[0]),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('Time:'),
                  TextButton(
                    onPressed: () async {
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        selectedTime = pickedTime;
                      }
                    },
                    child: Text(selectedTime == null
                        ? 'Select Time'
                        : selectedTime!.format(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();

              if (title.isNotEmpty) {
                DateTime taskDueDateTime = DateTime(
                  selectedDueDate!.year,
                  selectedDueDate!.month,
                  selectedDueDate!.day,
                  selectedTime?.hour ?? 0,
                  selectedTime?.minute ?? 0,
                );

                await FirestoreService().createTask(
                  project.id, // Use the current project ID
                  title,
                  description,
                  priority: selectedPriority,
                  assigneeUsername: project.isPersonal
                    ? FirebaseAuth.instance.currentUser!.uid // Assign to current user
                    : selectedAssignee,
                  dueDate: taskDueDateTime, // Pass the selected due date
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Task title cannot be empty!')),
                );
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}

class TaskList extends StatelessWidget {
  final Project project;

  const TaskList({Key? key, required this.project}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: FirestoreService().getProjectTasks(project.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No tasks found.'));
        }

        final tasks = snapshot.data!;
        return ListView(
          children: tasks
              .map((task) => _buildTaskTile(context, task, project))
              .toList(),
        );
      },
    );
  }

  Widget _buildTaskTile(BuildContext context, Task task, Project project) {
    return ListTile(
      title: Text(task.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description: ${task.description}'),
          Text('Priority: ${task.priority}'),
          Text('Assignee: ${task.assignee ?? 'Unassigned'}'), // Show username or 'Unassigned'
          if (task.dueDate != null)
            Text('Due Date: ${task.dueDate!.toLocal().toString().split(' ')[0]}'),
          Text('Status: ${task.status}'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Switch to toggle task completion
          Switch(
            value: task.status == 'Completed',
            onChanged: (value) async {
              await FirestoreService().updateTask(
                task.id,
                status: value ? 'Completed' : 'To Do',
              );
            },
          ),
          // Edit button for updating the task
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _showUpdateTaskDialog(context, task),
          ),
          // Claim button for unassigned tasks
          if (!project.isPersonal && task.assignee == null)
            ElevatedButton(
              onPressed: () async {
                await FirestoreService().updateTask(
                  task.id,
                  assignee: FirebaseAuth.instance.currentUser!.uid,
                );
              },
              child: Text('Claim'),
            ),
        ].whereType<Widget>().toList(), // Remove null widgets
      ),
    );
  }
}  


  void _showUpdateTaskDialog(BuildContext context, Task task) {
    final TextEditingController titleController =
        TextEditingController(text: task.title);
    final TextEditingController descriptionController =
        TextEditingController(text: task.description);
    String selectedPriority = task.priority;
    String selectedStatus = task.status;
    DateTime? selectedDueDate = task.dueDate;
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Task Title'),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Task Description'),
              ),
              DropdownButtonFormField<String>(
                value: selectedPriority,
                onChanged: (value) => selectedPriority = value!,
                decoration: InputDecoration(labelText: 'Priority'),
                items: ['High', 'Medium', 'Low']
                    .map((priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        ))
                    .toList(),
              ),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                onChanged: (value) => selectedStatus = value!,
                decoration: InputDecoration(labelText: 'Status'),
                items: ['To Do', 'In Progress', 'Completed']
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
              ),
              Row(
                children: [
                  Text('Due Date:'),
                  TextButton(
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDueDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) selectedDueDate = pickedDate;
                    },
                    child: Text(
                      selectedDueDate == null
                          ? 'Select Date'
                          : selectedDueDate!.toLocal().toString().split(' ')[0],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('Time:'),
                  TextButton(
                    onPressed: () async {
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        selectedTime = pickedTime;
                      }
                    },
                    child: Text(selectedTime == null
                        ? 'Select Time'
                        : selectedTime!.format(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();

              if (title.isNotEmpty) {
                DateTime taskDueDateTime = DateTime(
                  selectedDueDate!.year,
                  selectedDueDate!.month,
                  selectedDueDate!.day,
                  selectedTime?.hour ?? 0,
                  selectedTime?.minute ?? 0,
                );
                await FirestoreService().updateTask(
                  task.id,
                  title: title,
                  description: description,
                  priority: selectedPriority,
                  status: selectedStatus,
                  dueDate: taskDueDateTime,
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Task title and description cannot be empty!')),
                );
              }
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }
