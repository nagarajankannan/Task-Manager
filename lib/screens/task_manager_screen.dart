import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'login_screen.dart';
import 'completed_tasks_screen.dart';
import '../models/task_model.dart';

class Task {
  String objectId;
  String title;
  String description;
  bool isCompleted;

  Task({
    required this.objectId,
    required this.title,
    this.description = '',
    this.isCompleted = false,
  });

  factory Task.fromParse(TaskModel parseTask) {
    return Task(
      objectId: parseTask.objectId ?? '',
      title: parseTask.title ?? '',
      description: parseTask.description ?? '',
      isCompleted: parseTask.isCompleted,
    );
  }
}

class TaskManagerScreen extends StatefulWidget {
  const TaskManagerScreen({super.key});

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen> {
  List<Task> _tasks = [];
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = await ParseUser.currentUser() as ParseUser?;
      if (currentUser == null) return;

      final query = QueryBuilder<TaskModel>(TaskModel())
        ..whereEqualTo('user', currentUser)
        ..orderByDescending('createdAt');

      final response = await query.query();

      if (response.success && response.results != null) {
        setState(() {
          _tasks = response.results!
              .map((task) => Task.fromParse(task as TaskModel))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() => _isLoading = false);
    }
  }

  int get _pendingCount => _tasks.where((task) => !task.isCompleted).length;
  int get _completedCount => _tasks.where((task) => task.isCompleted).length;

  Future<void> _addTask() async {
    _taskController.clear();
    _descriptionController.clear();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _taskController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter task title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter task description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = _taskController.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(context, {
                  'title': title,
                  'description': _descriptionController.text.trim(),
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final currentUser = await ParseUser.currentUser() as ParseUser?;
        if (currentUser == null) return;

        final taskModel = TaskModel()
          ..title = result['title']!
          ..description = result['description'] ?? ''
          ..isCompleted = false
          ..user = currentUser
          ..setACL(ParseACL(owner: currentUser));

        final response = await taskModel.save();

        if (response.success) {
          await _loadTasks();
        } else {
          _showError('Failed to add task');
        }
      } catch (e) {
        _showError('Error adding task: $e');
      }
    }
  }

  Future<void> _toggleTask(int index) async {
    final task = _tasks[index];
    
    try {
      final currentUser = await ParseUser.currentUser() as ParseUser?;
      if (currentUser == null) return;

      final taskModel = TaskModel()
        ..objectId = task.objectId
        ..isCompleted = !task.isCompleted
        ..setACL(ParseACL(owner: currentUser));

      final response = await taskModel.save();

      if (response.success) {
        await _loadTasks();
      } else {
        _showError('Failed to update task');
      }
    } catch (e) {
      _showError('Error updating task: $e');
    }
  }

  Future<void> _deleteTask(int index) async {
    final task = _tasks[index];
    
    try {
      final taskModel = TaskModel()..objectId = task.objectId;
      final response = await taskModel.delete();

      if (response.success) {
        await _loadTasks();
      } else {
        _showError('Failed to delete task');
      }
    } catch (e) {
      _showError('Error deleting task: $e');
    }
  }

  Future<void> _editTask(int index) async {
    final task = _tasks[index];
    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Task title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Task description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(context, {
                  'title': title,
                  'description': descController.text.trim(),
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    await Future.delayed(const Duration(milliseconds: 100));
    titleController.dispose();
    descController.dispose();

    if (result != null) {
      final newTitle = result['title']!;
      final newDescription = result['description'] ?? '';
      
      if (newTitle != task.title || newDescription != task.description) {
        try {
          final currentUser = await ParseUser.currentUser() as ParseUser?;
          if (currentUser == null) return;

          final taskModel = TaskModel()
            ..objectId = task.objectId
            ..title = newTitle
            ..description = newDescription
            ..setACL(ParseACL(owner: currentUser));

          final response = await taskModel.save();

          if (response.success) {
            await _loadTasks();
          } else {
            _showError('Failed to update task');
          }
        } catch (e) {
          _showError('Error updating task: $e');
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _navigateToCompletedTasks() {
    final completedTasks = _tasks.where((task) => task.isCompleted).toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CompletedTasksScreen(
          completedTasks: completedTasks,
          onDelete: (index) async {
            final taskToDelete = completedTasks[index];
            try {
              final taskModel = TaskModel()..objectId = taskToDelete.objectId;
              await taskModel.delete();
              await _loadTasks();
            } catch (e) {
              _showError('Error deleting task: $e');
            }
          },
        ),
      ),
    ).then((_) => _loadTasks());
  }

  Future<void> _logout() async {
    final user = await ParseUser.currentUser() as ParseUser?;
    if (user != null) {
      await user.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Task Manager'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Task Manager'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCountCard('Pending', _pendingCount, Colors.orange),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                    ),
                    GestureDetector(
                      onTap: _navigateToCompletedTasks,
                      child: _buildCountCard('Completed', _completedCount, Colors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Current tasks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _pendingCount == 0
                      ? Center(
                          child: Text(
                            'No pending tasks!\nTap + to add a new task',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _tasks.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            if (task.isCompleted) {
                              return const SizedBox.shrink();
                            }
                            return Dismissible(
                              key: Key(task.title + index.toString()),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) => _deleteTask(index),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.red,
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                leading: GestureDetector(
                                  onTap: () => _toggleTask(index),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey[400]!,
                                        width: 2,
                                      ),
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                subtitle: task.description.isNotEmpty
                                    ? Text(
                                        task.description,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                  onPressed: () => _editTask(index),
                                  tooltip: 'Edit task',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Task'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountCard(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
