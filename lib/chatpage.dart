import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ChatPages extends StatefulWidget {
  final String currentUserId; // The logged-in user's ID
  final String receiverId; // The recipient's ID
  final String receiverName; // Name of the chat recipient

  const ChatPages({
    Key? key,
    required this.currentUserId,
    required this.receiverId,
    required this.receiverName,
  }) : super(key: key);

  @override
  _ChatPagesState createState() => _ChatPagesState();
}

class _ChatPagesState extends State<ChatPages> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  final DatabaseReference _messagesRef =
      FirebaseDatabase.instance.ref('messages');

  List<Map<dynamic, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _listenForMessages();
  }

  // Generate a unique chat room ID based on sender and receiver IDs
  String getChatRoomId() {
    List<String> ids = [widget.currentUserId, widget.receiverId];
    ids.sort(); // Ensures the ID is consistent regardless of sender/receiver order
    return ids.join('_');
  }

  // Listen for messages in the specific chat room
  void _listenForMessages() {
    String chatRoomId = getChatRoomId();

    _messagesRef.child(chatRoomId).onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        List<Map<dynamic, dynamic>> tempMessages = [];

        data.forEach((key, value) {
          if (value is Map) {
            tempMessages.add(Map<dynamic, dynamic>.from(value));
          }
        });

        setState(() {
          _messages = tempMessages;
          _messages.sort((a, b) => (a['timestamp'] ?? 0)
              .compareTo(b['timestamp'] ?? 0)); // Sort messages by timestamp
        });

        _scrollToBottom();
      }
    });
  }

  // Send a text message
  void _sendMessage() {
    if (_controller.text.trim().isNotEmpty) {
      String chatRoomId = getChatRoomId();

      final newMessage = {
        'senderID': widget.currentUserId,
        'receiverID': widget.receiverId,
        'message': _controller.text.trim(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'text',
      };

      _messagesRef.child(chatRoomId).push().set(newMessage);
      _controller.clear();
      _scrollToBottom();
    }
  }

  // Send an image
  Future<void> _sendImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      String chatRoomId = getChatRoomId();

      // Upload to Firebase Storage
      final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final Reference storageRef =
          FirebaseStorage.instance.ref().child('chat_images').child(fileName);

      await storageRef.putFile(imageFile);
      final String downloadUrl = await storageRef.getDownloadURL();

      // Save image URL to the database
      final newMessage = {
        'senderID': widget.currentUserId,
        'receiverID': widget.receiverId,
        'message': downloadUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'image',
      };

      _messagesRef.child(chatRoomId).push().set(newMessage);
      _scrollToBottom();
    }
  }

  // Scroll the chat to the bottom
  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.receiverName}'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isSentByMe = message['senderID'] == widget.currentUserId;
                final messageType = message['type'] ?? 'text';

                return Align(
                  alignment:
                      isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSentByMe ? Colors.blueAccent : Colors.grey[300],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                        bottomLeft: isSentByMe
                            ? Radius.circular(12)
                            : Radius.circular(0),
                        bottomRight: isSentByMe
                            ? Radius.circular(0)
                            : Radius.circular(12),
                      ),
                    ),
                    child: messageType == 'image'
                        ? Image.network(
                            message['message'],
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          )
                        : Text(
                            message['message'] ?? '',
                            style: TextStyle(
                              color: isSentByMe ? Colors.white : Colors.black87,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image, color: Colors.blueAccent),
                  onPressed: _sendImage, // Pick and send image
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Enter your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.send, color: Colors.white),
                  mini: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
