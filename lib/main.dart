import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late SharedPreferences _prefs;
  bool _isDarkTheme = false; // Initialize _isDarkTheme

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = _prefs.getBool('isDarkTheme') ?? false;
    });
  }

  void _toggleTheme() {
    setState(() {
      _isDarkTheme = !_isDarkTheme;
      _prefs.setBool('isDarkTheme', _isDarkTheme);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bot',
      debugShowCheckedModeBanner: false,
      theme: _isDarkTheme ? ThemeData.dark() : ThemeData.light(),
      home: ChatScreen(
        isDarkTheme: _isDarkTheme,
        toggleTheme: _toggleTheme,
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final bool isDarkTheme;
  final VoidCallback toggleTheme;

  const ChatScreen({Key? key, required this.isDarkTheme, required this.toggleTheme})
      : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _userInput = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const apiKey = "Use Your API Key";

  final model = GenerativeModel(model: 'Name', apiKey: apiKey);

  final List<Message> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMessages(); // Load messages when the chat screen initializes
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getStringList('messages') ?? [];

    setState(() {
      _messages.clear(); // Clear existing messages
      _messages.addAll(messagesJson.map((json) => Message.fromJson(jsonDecode(json)))); // Deserialize messages
    });
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = _messages.map((message) => jsonEncode(message.toJson())).toList();
    await prefs.setStringList('messages', messagesJson);
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _userInput.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final message = _userInput.text;
    _userInput.clear();

    setState(() {
      _messages.add(Message(isUser: true, message: message, date: DateTime.now()));
      _isLoading = true; // Start loading indicator
    });

    await _saveMessages(); // Save messages after adding new message
    _scrollToBottom(); // Scroll to bottom after sending user message

    final content = [Content.text(message)];
    final response = await model.generateContent(content);

    if (response.text != null) {
      setState(() {
        _messages.add(Message(isUser: false, message: response.text!, date: DateTime.now()));
        _isLoading = false; // Stop loading indicator
      });

      await _saveMessages(); // Save messages after receiving bot response
      _scrollToBottom(); // Scroll to bottom after receiving bot response
    }
  }

  void clearChat() async {
    setState(() {
      _messages.clear();
    });

    await _saveMessages(); // Save messages after clearing chat
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = widget.isDarkTheme;
    final textColor = isDarkTheme ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unknown Bot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: clearChat,
          ),
          PopupMenuButton<int>(
            onSelected: (item) => widget.toggleTheme(),
            itemBuilder: (context) => [
              PopupMenuItem<int>(
                value: 0,
                child: Row(
                  children: [
                    Icon(isDarkTheme ? Icons.light_mode : Icons.dark_mode),
                    const SizedBox(width: 8),
                    Text(isDarkTheme ? 'Light Theme' : 'Dark Theme'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://wallpapers.com/images/hd/neon-iphone-whatsapp-f1a0enk27o03wk4x.jpg',
                ),
                fit: BoxFit.cover,
                colorFilter: isDarkTheme
                    ? ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken)
                    : ColorFilter.mode(Colors.white.withOpacity(0.7), BlendMode.lighten),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Messages(
                        isUser: message.isUser,
                        message: message.message,
                        date: DateFormat('HH:mm').format(message.date),
                        isDarkTheme: isDarkTheme,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 15,
                        child: TextFormField(
                          style: TextStyle(color: textColor),
                          controller: _userInput,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            labelText: 'Enter Your Message',
                            labelStyle: TextStyle(color: textColor),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        padding: const EdgeInsets.all(12),
                        iconSize: 30,
                        color: textColor,
                        onPressed: sendMessage,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
        ],
      ),
    );
  }
}

class Message {
  final bool isUser;
  final String message;
  final DateTime date;

  Message({
    required this.isUser,
    required this.message,
    required this.date,
  });

  factory Message.fromJson(Map<String, dynamic> data) {
    return Message(
      isUser: data['isUser'],
      message: data['message'],
      date: DateTime.parse(data['date']),
    );
  }

  Map<String, dynamic> toJson() => {
    'isUser': isUser,
    'message': message,
    'date': date.toIso8601String(),
  };
}

class Messages extends StatelessWidget {
  final bool isUser;
  final String message;
  final String date;
  final bool isDarkTheme;

  const Messages({
    Key? key,
    required this.isUser,
    required this.message,
    required this.date,
    required this.isDarkTheme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final messageBackgroundColor = isUser
        ? (isDarkTheme ? Colors.blueAccent : Colors.blue)
        : (isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade400);
    final messageTextColor = isUser ? Colors.white : (isDarkTheme ? Colors.white : Colors.black);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(vertical: 15).copyWith(
        left: isUser ? 100 : 10,
        right: isUser ? 10 : 100,
      ),
      decoration: BoxDecoration(
        color: messageBackgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(10),
          bottomLeft: isUser ? const Radius.circular(10) : Radius.zero,
          topRight: const Radius.circular(10),
          bottomRight: isUser ? Radius.zero : const Radius.circular(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(fontSize: 16, color: messageTextColor),
          ),
          Text(
            date,
            style: TextStyle(fontSize: 10, color: messageTextColor),
          ),
        ],
      ),
    );
  }
}
