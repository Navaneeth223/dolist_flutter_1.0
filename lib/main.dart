
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const DoListApp());
}

class DoListApp extends StatelessWidget {
  const DoListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _tasks = [];
  int streak = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _requestOverlayPermission();
  }

  Future<void> _requestOverlayPermission() async {
    final status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTasks = prefs.getStringList('tasks') ?? [];
    final savedStreak = prefs.getInt('streak') ?? 0;

    setState(() {
      _tasks.clear();
      for (String task in savedTasks) {
        final parts = task.split('|');
        _tasks.add({"text": parts[0], "done": parts[1] == 'true'});
      }
      streak = savedStreak;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final taskStrings = _tasks.map((task) => "${task['text']}|${task['done']}").toList();
    await prefs.setStringList('tasks', taskStrings);
    await prefs.setInt('streak', streak);
  }

  void _addTask(String text) {
    if (text.isEmpty) return;
    setState(() {
      _tasks.add({"text": text, "done": false});
      _controller.clear();
    });
    _saveData();
  }

  void _toggleTask(int index) {
    setState(() {
      _tasks[index]['done'] = !_tasks[index]['done'];
      streak = _tasks.where((t) => t['done']).length;
    });
    _saveData();
  }

  void _startOverlay() async {
    await FlutterOverlayWindow.showOverlay(
      alignment: OverlayAlignment.topRight,
      height: 100,
      width: 200,
      enableDrag: true,
      overlayTitle: "DoList",
      flag: OverlayFlag.defaultFlag,
    );
  }

  void _stopOverlay() {
    FlutterOverlayWindow.closeOverlay();
  }

  void _clearAllTasks() {
    setState(() {
      _tasks.clear();
      streak = 0;
    });
    _saveData();
  }

  void _markAllAsDone() {
    setState(() {
      for (var task in _tasks) {
        task['done'] = true;
      }
      streak = _tasks.length;
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('🔥 DoList'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_in_picture),
            onPressed: _startOverlay,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _stopOverlay,
          ),
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: _markAllAsDone,
            tooltip: 'Mark all as done',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearAllTasks,
            tooltip: 'Clear all tasks',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            StreakBar(streak: streak),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Add a task...",
                hintStyle: const TextStyle(color: Colors.white38),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _addTask(_controller.text),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return GlassTaskCard(
                    task: task['text'],
                    done: task['done'],
                    onToggle: () => _toggleTask(index),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class GlassTaskCard extends StatelessWidget {
  final String task;
  final bool done;
  final VoidCallback onToggle;

  const GlassTaskCard({super.key, required this.task, required this.done, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.circle_outlined,
                  color: done ? Colors.greenAccent : Colors.white60,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StreakBar extends StatelessWidget {
  final int streak;

  const StreakBar({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    double maxWidth = MediaQuery.of(context).size.width - 40;
    double progress = (streak % 7) / 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("🔥 Streak: $streak Days", style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                width: maxWidth,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: maxWidth * progress,
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

