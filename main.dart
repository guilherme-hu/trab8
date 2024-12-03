import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


String? gToken;
String? gEmail;
String? gID;
List<Map<String, dynamic>> gListas = [];  
List<Map<String, dynamic>> gChats = [];

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskList',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/main': (context) => MyHomePage(
              title: 'TaskList Home Page',
              token: gToken!,
              email: gEmail!,
            ),
        '/chat': (context) => ChatPage(),
        '/listaPrincipal': (context) => ListaPrincipal(),
        '/listaChats': (context) => ListaChats(),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';

  Future<void> _login() async {
  final username = _usernameController.text;
  final password = _passwordController.text;

  final response = await http.post(
    Uri.https('barra.cos.ufrj.br:443', '/rest/rpc/fazer_login'),
    headers: <String, String>{
      'accept': 'application/json', 'Content-Type': 'application/json'
    },
    body: jsonEncode(<String, String>{
      'email': username,
      'senha': password,
    }),
  );

  if (response.statusCode == 200) {
    final responseBody = jsonDecode(response.body);
    final String token = responseBody['token'];
    final String email = responseBody['email'];
    gToken = token;
    gEmail = email; 

    Navigator.pushReplacementNamed(context, '/listaPrincipal');

  } else {
    setState(() {
      _errorMessage = 'Invalid username or password';
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              child: const Text('Register'),
            ),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  String _errorMessage = '';

  Future<void> _register() async {
  final name = _nameController.text;
  final email = _emailController.text;
  final phone = _phoneController.text;
  final password = _passwordController.text;
  final confirmPassword = _confirmPasswordController.text;

  if (password != confirmPassword) {
    setState(() {
      _errorMessage = 'Passwords do not match';
    });
    return;
  }

  final response = await http.post(
    Uri.https('barra.cos.ufrj.br:443', '/rest/rpc/registra_usuario'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'nome': name,
      'email': email,
      'celular': phone,
      'senha': password,
    }),
  );

  if (response.statusCode == 200) {
    Navigator.pop(context);
  } else if (response.statusCode == 400) {
    setState(() {
      _errorMessage = 'The email is already in use';
    });
  } else {
    setState(() {
      _errorMessage = 'Registration failed';
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _register,
              child: const Text('Register'),
            ),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}

class Task {
  String title;
  bool isComplete;

  Task(this.title, this.isComplete);
}

class MyHomePage extends StatefulWidget {
  final String title;
  final String token;
  final String email;

  const MyHomePage({super.key, required this.title, required this.token, required this.email});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  final List<Task> tasks = [];
  final textController = TextEditingController();
  final List<bool> _isDeleting = [];
  late AnimationController _controller;
  int _recentlyMovedIndex = -1; // Add this line to define the variable
  late Animation<double> _tiltAnimation; // Add this line to define the tilt animation
  final ScrollController _scrollController = ScrollController(); // Add this line to define the ScrollController

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _tiltAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticInOut),
    ); // Initialize the tilt animation
    
    _fetchTasks();
  }

  @override
  void dispose() {
    _controller.dispose();
    textController.dispose();
    super.dispose();
  }

  Future<void> _fetchTasks() async {
    final response = await http.get(
      Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
      headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
    );

    if (response.statusCode == 200 || response.statusCode == 206) {
      final aux = jsonDecode(response.body);
      List<dynamic> list = [];
      for (var item in aux) {
        if (item['id'].toString() == gID) {
          list = item['valor'];
          break;
        }
      }
      if (list.isNotEmpty) {
        setState(() {
          tasks.clear();
          _isDeleting.clear();
          for (var task in list) {
            tasks.add(Task(task['title'], task['completed'] == "true"));
            _isDeleting.add(false);
          }
        });
      }
    } else if (response.statusCode == 401 && jsonDecode(response.body)['code'] == 'PGRST301') {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired, please log in again')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch tasks')),
      );
  } 
}

Future<void> _deleteTaskFromApi() async {
  final response = await http.delete(
    Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2', {'id': 'eq.$gID'}),
    headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}',
    },
  );

  if (response.statusCode == 204) {
  } else if (jsonDecode(response.body)['code'] == 'PGRST301') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired, please log in again')),
    );
    Navigator.pushReplacementNamed(context, '/');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to delete task')),
    );
  }
}

  Future<void> _saveTasks() async {
    try {
      List<Map<String, String>> taskList = [];
      for (var task in tasks) {
        taskList.add({
          'title': task.title,
          'completed': task.isComplete.toString(),
        });
      }

      final response = await http.patch(
        Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2', {'id': 'eq.$gID'}),
        headers: <String, String>{
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode(<String, dynamic>{
          'email': widget.email,
          'valor': taskList,
        }),
      );

      if (response.statusCode == 204) {
        // Success
      } else if (jsonDecode(response.body)['code'] == 'PGRST301') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired, please log in again')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  Future<void> _addTask(String taskTitle) async {
    final trimmedTask = taskTitle.trim();

    if (trimmedTask.isNotEmpty && !tasks.any((task) => task.title == trimmedTask)) {
      setState(() {
        tasks.insert(0, Task(trimmedTask, false));
        textController.clear();
        _isDeleting.insert(0, false);
      });
      await _saveTasks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarefa inválida ou já existe!')),
      );
    }
  }

final Set<String> _deletingTaskTitles = {}; // Define the Set for deleting task titles

Future<void> _deleteTask(String taskTitle) async {
  setState(() {
    _deletingTaskTitles.add(taskTitle); // Add the task title to the Set
  });

  Future.delayed(const Duration(seconds: 3), () async {
    if (_deletingTaskTitles.contains(taskTitle)) {
      setState(() {
        _removeTask(taskTitle);
        _deletingTaskTitles.remove(taskTitle); // Remove the task title from the Set
      });
      await _saveTasks();
    }
  });
}

void _removeTask(String taskTitle) {
  setState(() {
    final index = tasks.indexWhere((task) => task.title == taskTitle);
    if (index != -1) {
      tasks.removeAt(index);
      _isDeleting.removeAt(index);
    }
  });
}

void _undoDelete(String taskTitle) {
  setState(() {
    _deletingTaskTitles.remove(taskTitle); // Remove the task title from the Set
  });
}

 Future<void> _toggleCompletion(int index) async {
  setState(() {
    final task = tasks.removeAt(index);
    _isDeleting.removeAt(index);

    if (task.isComplete) {
      task.isComplete = false;
      // Adiciona a tarefa no topo da lista dos não concluídos
      int insertIndex = tasks.indexWhere((t) => t.isComplete);
      if (insertIndex == -1) {
        insertIndex = tasks.length;
      }
      tasks.insert(insertIndex, task);
      _isDeleting.insert(insertIndex, false);
      _recentlyMovedIndex = insertIndex; // Atualiza o índice de destino
    } else {
      task.isComplete = true;
      // Adiciona a tarefa no topo da lista dos concluídos
      int insertIndex = tasks.indexWhere((t) => t.isComplete);
      if (insertIndex == -1) {
        insertIndex = tasks.length;
      }
      tasks.insert(insertIndex, task);
      _isDeleting.insert(insertIndex, false);
      _recentlyMovedIndex = insertIndex; // Atualiza o índice de destino
    }
    _controller.forward(from: 0.0); // Reinicia a animação  
  });
  await _saveTasks();
}

  double calculateTopPosition(int index) {
    const double taskHeight = 60.0;
    return index * taskHeight;
  }

void _logout() {
  // Limpar o token de autenticação ou invalidar a sessão
  Navigator.pushReplacementNamed(context, '/');
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      foregroundColor: Colors.white,
      backgroundColor: Colors.blue,
      title: Text(widget.title),
    ),
    drawer: Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Lista Principal'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/listaPrincipal');
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Lista de Chats'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/listaChats');
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_comment),
            title: const Text('Nova Conversa'),
            onTap: () {
              Navigator.pop(context);
              _showNewChatDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    ),
    body: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: textController,
            autofocus: true,
            onSubmitted: _addTask,
            decoration: const InputDecoration(
              labelText: 'Nova Tarefa',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        FloatingActionButton(
          onPressed: () => _addTask(textController.text),
          tooltip: 'Adicionar Tarefa',
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 16.0),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(8.0),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return ListView.builder(
                  controller: _scrollController, // Add this line to set the ScrollController
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final isDeleting = _deletingTaskTitles.contains(task.title);
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final tilt = (_controller.isAnimating && index == _recentlyMovedIndex) ? _tiltAnimation.value : 0.0;
                        return Transform.rotate(
                          angle: tilt,
                          child: Dismissible(
                            key: UniqueKey(),
                            direction: DismissDirection.horizontal,
                            onDismissed: (direction) {
                              if (direction == DismissDirection.endToStart) {
                                _deleteTask(task.title);
                              } else if (direction == DismissDirection.startToEnd) {
                                _toggleCompletion(index);
                              }
                            },
                            background: Container(
                              color: Colors.green,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                              ),
                            ),
                            secondaryBackground: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              decoration: BoxDecoration(
                                color: isDeleting
                                    ? Colors.red[100]
                                    : (index % 2 == 0 ? Colors.blue[200] : Colors.blue),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: ListTile(
                                title: Text(
                                  task.title,
                                  style: TextStyle(
                                    decoration: task.isComplete
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                                leading: Checkbox(
                                  value: task.isComplete,
                                  onChanged: (value) {
                                    setState(() {
                                      _recentlyMovedIndex = index;
                                    });
                                    _controller.forward(from: 0.0);
                                    _toggleCompletion(index);
                                  },
                                ),
                                trailing: isDeleting
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () => _undoDelete(task.title),
                                            child: const Text('Desfazer'),
                                          ),
                                        ],
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _deleteTask(task.title),
                                      ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> _newChat(String nomeChat) async {
  // Cria uma nova conversa
  final chatResponse = await http.post(
    Uri.https('barra.cos.ufrj.br:443', '/rest/rpc/cria_conversa'),
    headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $gToken',
    },
  );

  if (chatResponse.statusCode == 200) {
    final chatData = jsonDecode(chatResponse.body);
    final chatId = chatData.toString();
    gID = chatId;

    // Cria uma nova lista de tarefas associada ao chat
    final taskResponse = await http.post(
      Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
      headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $gToken',
      },
      body: jsonEncode(<String, dynamic>{
        'email': gEmail,
        'valor': [],
        'atributos': {'nome': nomeChat, 'index': -1, 'chatId': chatId},
      }),
    );

    if (taskResponse.statusCode == 201) {
      final fetchResponse = await http.get(
        Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
        headers: <String, String>{
          'accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $gToken',
        },
      );

      if (fetchResponse.statusCode == 200) {
        final fetchData = jsonDecode(fetchResponse.body);
        String taskId = '';
        for (var task in fetchData) {
          if (task['atributos']['chatId'] == chatId) {
            taskId = task['id'].toString();
            break;
          }
        }

      // Atualiza o chat com o ID da lista de tarefas
      final patchChatResponse = await http.patch(
        Uri.https('barra.cos.ufrj.br:443', '/rest/conversas', {'id': 'eq.$chatId'}),
        headers: <String, String>{
          'accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $gToken',
        },
        body: jsonEncode(<String, dynamic>{
          'atributos': {'nome': nomeChat, 'index': -1, 'listaId': taskId},
        }),
      );

      if (patchChatResponse.statusCode != 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update chat with task ID')),
        );
      }

    } else if (taskResponse.statusCode == 401 && jsonDecode(taskResponse.body)['code'] == 'PGRST301') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired, please log in again')),
      );
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create new task list')),
      );
    }
  } else if (chatResponse.statusCode == 401 && jsonDecode(chatResponse.body)['code'] == 'PGRST301') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired, please log in again')),
    );
    Navigator.pushReplacementNamed(context, '/');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to create new chat')),
    );
  }
}
}

void _showNewChatDialog(BuildContext context) {
  final TextEditingController _nameController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Criar Nova Conversa'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nome da Conversa e Lista'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final nomeChat = _nameController.text;
              if (nomeChat.isNotEmpty) {
                _newChat(nomeChat);
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(),
                ),
              );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nome não pode ser vazio')),
                );
              }
            },
            child: const Text('Criar'),
          ),
        ],
      );
    },
  );
}
}

class ChatPage extends StatefulWidget {

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  final ScrollController _scrollController = ScrollController();
  String conversationId = '';
  String listaId = '';
  bool espera = false;
  bool chatMandouLista = false;
  List<dynamic> tasks = [];
  List<Task> api_tasks = [];  
  int index = 0;
  String nome = '';

  @override
  void initState() {
    super.initState();
    _pegarTarefas();
  }

  Future<void> _pegarTarefas() async {
    final url = Uri.https('barra.cos.ufrj.br:443', '/rest/conversas');
    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $gToken',
    };

    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      if (data.isNotEmpty) {
        setState(() {
          List<dynamic>? messages;
          for (var conversation in data) {
          if (conversation['id'].toString() == gID) {
            conversationId = conversation['id'] ?? '';
            messages = conversation['mensagens'];
            listaId = conversation['atributos']['listaId'] ?? '';
            nome = conversation['atributos']['nome'] ?? '';
            index = conversation['atributos']['index'] ?? 0;
            break;
          }
          }
          _chatMessages.clear();
          if (messages != null) {
            for (var msg in messages) {
                _chatMessages.add({
                  'content': msg['conteudo'] ?? '',
                  'role': msg['papel'] ?? '',
                });
            }
          }
        });
      } else {
        final urlP = Uri.https('barra.cos.ufrj.br:443', '/rest/rpc/cria_conversa');
        final headersP = {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $gToken',
        };
        final aux = await http.post(urlP, headers: headersP);

        final response_2 = await http.get(url, headers: headers);
        if (response_2.statusCode == 200) {
            var data = json.decode(response_2.body);
            if (data.isNotEmpty) {
            setState(() {
              for (var conversation in data) {
              if (conversation['id'].toString() == gID) {
                conversationId = conversation['id'] ?? '';
                var messages = conversation['mensagens'];
                _chatMessages.clear();
                if (messages != null) {
                for (var msg in messages) {
                  _chatMessages.add({
                  'content': msg['conteudo'] ?? '',
                  'role': msg['papel'] ?? '',
                  });
                }
                }
                break;
              }
              }
            });
          }
        }
      }
    } else if (response.statusCode == 401 && jsonDecode(response.body)['code'] == 'PGRST301') {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired, please log in again.')),
        );
      }
    }
  }

  Future<void> _sendChatMessage() async {
    final message = _chatController.text.trim();
    setState(() {
      _chatMessages.add({'content': message, 'role': 'user'});
      espera = true;
    });
    _chatController.clear();

    final url = Uri.https('barra.cos.ufrj.br:443', '/rest/rpc/envia_resposta');
    final headers = {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $gToken',
    };
    final body = json.encode({
      'conversa_id': conversationId,
      'resposta': message,
    });

    try {
    final response = await http.post(url, headers: headers, body: body);
    
    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      if (data != null && data.isNotEmpty) {
        setState(() {
          if (data.containsKey('tarefas')) {
            chatMandouLista = true;
            tasks = data['tarefas'];
            _chatMessages.add({
              'content': 'I received a list of tasks. What would you like to do?',
              'role': 'bot',
            });
            _showTaskOptionsDialog(listaId);
          } else if (data.containsKey('pergunta')) {
            var messages = data['mensagens'];
            if (messages != null && messages is List) {
              for (var msg in messages) {
                if (msg != null && msg is Map) {
                  _chatMessages.add({
                    'content': msg['conteudo'] ?? '',
                    'role': msg['papel'] ?? '',
                  });
                }
              }
            }
          }
          espera = false;
        });
      }
    } else if (response.statusCode == 401 && jsonDecode(response.body)['code'] == 'PGRST301') {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired, please log in again.')),
        );
      }
    } else if (response.statusCode == 400) {
      var data = json.decode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred: $e')),
    );
  }
  _pegarTarefas();
}

 void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

Future<void> _clearAndAddTasks(String listaId) async {
    final response = await http.patch(
    Uri.https('barra.cos.ufrj.br:443', '/rest/tarefas', {'id': 'eq.$listaId'}),
    headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $gToken',
    },
      body: jsonEncode(<String, dynamic>{
      'email': gEmail,
      'valor': [],
      'atributos': {'nome': nome, 'index': index, 'chatId': gID},
    }),
  );
  for (var task in tasks) {
    api_tasks.add(Task(task,false));
  }
  await _saveTasks(listaId);
}

void _showTaskOptionsDialog(String listaId) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Task Options'),
        content: const Text('What would you like to do with the tasks?'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Continue the chat
            },
            child: const Text('Continue Chat'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Clear existing tasks and add new ones
              await _clearAndAddTasks(listaId);
            },
            child: const Text('Clear and Add Tasks'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Add new tasks to existing ones
              await _addTasksToExisting(listaId);
            },
            child: const Text('Add to Existing Tasks'),
          ),
        ],
      );
    },
  );
}


Future<void> _addTasksToExisting(String listaId) async {
  // Add new tasks to existing ones
  bool a = true;
  final response = await http.get(
    Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
    headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $gToken',
    },
  );
  if (response.statusCode == 200 || response.statusCode == 206) {
    final aux = jsonDecode(response.body);
    List<dynamic> list = [];
    for (var item in aux) {
      if (item['id'].toString() == listaId) {
        list = item['valor'];
        break;
      }
    }
  if (list.isNotEmpty) {
      setState(() {
      api_tasks.clear();
      for (var task in list) {
        if (task['completed'] != 'true' && a) {
          a = false;
          for (var task in tasks) {
            api_tasks.add(Task(task,false));
          }}
        api_tasks.add(Task(task['title'].toString(), task['completed'] == 'true'));
      }
      });
    }
  }
    await _saveTasks(listaId);
}

 Future<void> _saveTasks(String listaId) async {
  try {
    List<Map<String, String>> taskList = [];
    for (var task in api_tasks) {
      taskList.add({
        'title': task.title,
        'completed': task.isComplete.toString(),
      });
    }

    final response = await http.patch(
      Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2', {'id': 'eq.$listaId'}),
      headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $gToken',
      },
      body: jsonEncode(<String, dynamic>{
        'email': gEmail,
        'valor': taskList,
        'atributos': {'nome': nome, 'index': index, 'chatId': gID},
      }),
    );

    if (response.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tasks saved successfully')),
      );
      gID = listaId;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MyHomePage(
            title: 'TaskList Home Page',
            token: gToken!,
            email: gEmail!,
          ),
        ),
      );
    } else if (response.statusCode == 401 && jsonDecode(response.body)['code'] == 'PGRST301') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired, please log in again')),
      );
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save tasks')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred: $e')),
    );
  }
}

void _logout() {
  // Limpar o token de autenticação ou invalidar a sessão
  Navigator.pushReplacementNamed(context, '/');
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Lista Principal'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/listaPrincipal');
              },
            ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Lista de Chats'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/listaChats');
            },
          ),
            ListTile(
              leading: const Icon(Icons.add_comment),
              title: const Text('Nova Conversa'),
              onTap: () {
              Navigator.pop(context);
              _showNewChatDialog(context);
            },
          ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  final message = _chatMessages[index];
                  final isUserMessage = index % 2 != 0;
                  return Align(
                    alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
                    child: Callout(
                      triangleSize: 20,
                      triangleHeight: 10,
                      backgroundColor: isUserMessage ? const Color.fromARGB(255, 57, 202, 113) : Colors.grey[300]!,
                      isLeft: !isUserMessage,
                      position: isUserMessage ? "right" : "left",
                      child: Column(
                        crossAxisAlignment: isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            message['content']!,
                            style: TextStyle(
                              color: isUserMessage ? Colors.white : Colors.black,
                            ),
                          ),
                          if (isUserMessage)
                            Container(
                              width: 100,
                              alignment: Alignment.bottomRight,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      decoration: const InputDecoration(
                        labelText: 'Type a message',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: espera ? null : _sendChatMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

Future<void> _newChat(String nomeChat) async {
  // Cria uma nova conversa
  final chatResponse = await http.post(
    Uri.https('barra.cos.ufrj.br:443', '/rest/rpc/cria_conversa'),
    headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $gToken',
    },
  );

  if (chatResponse.statusCode == 200) {
    final chatData = jsonDecode(chatResponse.body);
    final chatId = chatData.toString();
    gID = chatId;

    // Cria uma nova lista de tarefas associada ao chat
    final taskResponse = await http.post(
      Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
      headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $gToken',
      },
      body: jsonEncode(<String, dynamic>{
        'email': gEmail,
        'valor': [],
        'atributos': {'nome': nomeChat, 'index': -1, 'chatId': chatId},
      }),
    );

    if (taskResponse.statusCode == 201) {
      final fetchResponse = await http.get(
        Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
        headers: <String, String>{
          'accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $gToken',
        },
      );

      if (fetchResponse.statusCode == 200) {
        final fetchData = jsonDecode(fetchResponse.body);
        String taskId = '';
        for (var task in fetchData) {
          if (task['atributos']['chatId'] == chatId) {
            taskId = task['id'].toString();
            break;
          }
        }

      // Atualiza o chat com o ID da lista de tarefas
      final patchChatResponse = await http.patch(
        Uri.https('barra.cos.ufrj.br:443', '/rest/conversas', {'id': 'eq.$chatId'}),
        headers: <String, String>{
          'accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $gToken',
        },
        body: jsonEncode(<String, dynamic>{
          'atributos': {'nome': nomeChat, 'index': -1, 'listaId': taskId},
        }),
      );

      if (patchChatResponse.statusCode != 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update chat with task ID')),
        );
      }

    } else if (taskResponse.statusCode == 401 && jsonDecode(taskResponse.body)['code'] == 'PGRST301') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired, please log in again')),
      );
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create new task list')),
      );
    }
  } else if (chatResponse.statusCode == 401 && jsonDecode(chatResponse.body)['code'] == 'PGRST301') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired, please log in again')),
    );
    Navigator.pushReplacementNamed(context, '/');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to create new chat')),
    );
  }
}
}

  void _showNewChatDialog(BuildContext context) {
  final TextEditingController _nameController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Criar Nova Conversa'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nome da Conversa e Lista'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(),
              ),
            );
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final nomeChat = _nameController.text;
              if (nomeChat.isNotEmpty) {
                _newChat(nomeChat);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nome não pode ser vazio')),
                );
              }
            },
            child: const Text('Criar'),
          ),
        ],
      );
    },
  );
}

}


class CalloutPainter extends CustomPainter {
  final double triangleSize;
  final double triangleHeight;
  final String position;
  final Color backgroundColor;
  final bool isLeft; // Define se o balão é da esquerda ou direita

  CalloutPainter({
    required this.triangleSize,
    required this.triangleHeight,
    required this.position,
    required this.backgroundColor,
    this.isLeft = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final Path balloonPath = Path();

    // Definir o corpo do balão (retângulo arredondado)
    const double margin = 10;
    const double radius = 8;
    final double bodyHeight = size.height - triangleHeight - margin;

    balloonPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(margin, margin, size.width - 2 * margin, bodyHeight),
      const Radius.circular(radius),
    ));

    // Desenhar a seta na parte de baixo com inclinação para fora
    final Path trianglePath = Path();

    if (position == "left") {
      // Seta no lado esquerdo inferior, inclinada para a esquerda (obtusa)
      trianglePath.moveTo(
          margin + 10, bodyHeight + margin); // Base esquerda da seta
      trianglePath.lineTo(margin + 10 + triangleSize,
          bodyHeight + margin); // Base direita da seta
      trianglePath.lineTo(
          margin - 10, size.height); // Ponta da seta inclinada para fora
    } else if (position == "right") {
      // Seta no lado direito inferior, inclinada para a direita (obtusa)
      trianglePath.moveTo(size.width - margin - 10 - triangleSize,
          bodyHeight + margin); // Base esquerda da seta
      trianglePath.lineTo(size.width - margin - 10,
          bodyHeight + margin); // Base direita da seta
      trianglePath.lineTo(size.width + 10 - margin,
          size.height); // Ponta da seta inclinada para fora
    } else {
      // Seta no centro inferior (isósceles)
      double centerX = (size.width - triangleSize) / 2;
      trianglePath.moveTo(
          centerX, bodyHeight + margin); // Base esquerda da seta
      trianglePath.lineTo(
          centerX + triangleSize, bodyHeight + margin); // Base direita da seta
      trianglePath.lineTo(
          centerX + triangleSize / 2, size.height); // Ponta da seta (centro)
    }

    balloonPath.addPath(trianglePath, Offset.zero);

    // Desenhar o balão e a seta
    canvas.drawShadow(balloonPath, Colors.black, 6, false);
    canvas.drawPath(balloonPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class Callout extends StatelessWidget {
  final Widget child;
  final double triangleSize;
  final double triangleHeight;
  final String position;
  final Color backgroundColor;
  final bool isLeft;

  const Callout({super.key, 
    required this.child,
    this.triangleSize = 20,
    this.triangleHeight = 10,
    this.position = "left",
    this.backgroundColor = Colors.white,
    this.isLeft = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CalloutPainter(
        triangleSize: triangleSize,
        triangleHeight: triangleHeight,
        position: position,
        backgroundColor: backgroundColor,
        isLeft: isLeft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }
}


class ListaPrincipal extends StatefulWidget {
  @override
  _ListaPrincipalState createState() => _ListaPrincipalState();
}

class _ListaPrincipalState extends State<ListaPrincipal> {
  List<Map<String, dynamic>> listas = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchTasks();
    });
  }

Future<void> _fetchTasks() async {
  final response = await http.get(
    Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
    headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $gToken',
    },
  );
  if (response.statusCode == 200) {
    final aux = jsonDecode(response.body);
    setState(() {
      listas.clear();
      for (var task in aux) {
        listas.add({
          'id': task['id'].toString(),
          'atributos': task['atributos'],
        });
      }
    });

  listas.sort((a, b) => a['atributos']['index'].compareTo(b['atributos']['index']));
  for (int i = 0; i < listas.length; i++) {
    listas[i]['atributos']['index'] = i;
  }

  // Atualiza a ordem dos índices no servidor
  for (var task in listas) {
    final taskId = task['id'];
    final taskIndex = task['atributos']['index'];

    final response = await http.patch(
      Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2', {'id': 'eq.$taskId'}),
      headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $gToken',
      },
      body: jsonEncode(<String, dynamic>{
        'atributos': {
          'nome': task['atributos']['nome'],
          'index': taskIndex,
          'chatId': task['atributos']['chatId'],
        },
      }),
    );

    if (response.statusCode != 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update task order')),
      );
    }
  }

  gListas = listas;

  } else if (response.statusCode == 401 && jsonDecode(response.body)['code'] == 'PGRST301') {
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired, please log in again')),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to fetch lists')),
    );
  }
}

  Future<void> _newTask(String nomeLista, bool associarChat) async {
  String chatId = '0';

  if (associarChat) {
    // Cria uma nova conversa
    final chatResponse = await http.post(
      Uri.https('barra.cos.ufrj.br:443', '/rest/rpc/cria_conversa'),
      headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $gToken',
      },
    );

    if (chatResponse.statusCode == 200) {
      final chatData = jsonDecode(chatResponse.body);
      chatId = chatData.toString();
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create new chat')),
      );
      return;
    }
  }

  // Cria uma nova tarefa
  final taskResponse = await http.post(
    Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
    headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $gToken',
    },
    body: jsonEncode(<String, dynamic>{
      'email': gEmail,
      'valor': [],
      'atributos': {'nome': nomeLista, 'index': -1, 'chatId': chatId},
    }),
  );

  if (taskResponse.statusCode == 201) {
    final fetchResponse = await http.get(
      Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
      headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $gToken',
      },
    );

    if (fetchResponse.statusCode == 200) {
      final fetchData = jsonDecode(fetchResponse.body);
      String taskId = '';
      for (var task in fetchData) {
      if (task['atributos']['chatId'] == chatId) {
        taskId = task['id'].toString();
        break;
        }
      }

    if (associarChat) {
      // Atualiza o chat com o ID da lista de tarefas e o nome da lista
      final patchResponse = await http.patch(
        Uri.https('barra.cos.ufrj.br:443', '/rest/conversas', {'id': 'eq.$chatId'}),
        headers: <String, String>{
          'accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $gToken',
        },
        body: jsonEncode(<String, dynamic>{
          'atributos': {'nome': nomeLista, 'index': -1, 'listaId': taskId},
        }),
      );

      if (patchResponse.statusCode != 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update chat with task ID')),
        );
      }
    }
  }
    _fetchTasks();
  } else if (taskResponse.statusCode == 401 && jsonDecode(taskResponse.body)['code'] == 'PGRST301') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired, please log in again')),
    );
    Navigator.pushReplacementNamed(context, '/');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to create new list')),
    );
  }
}
  
  Future<void> _delete() async {
  // Primeiro, obtenha os detalhes da tarefa para verificar se há um chat associado
  final taskResponse = await http.get(
    Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2', {'id': 'eq.$gID'}),
    headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $gToken',
    },
  );

  if (taskResponse.statusCode == 200) {
    final taskData = jsonDecode(taskResponse.body);
    final chatId = taskData[0]['atributos']['chatId'];

    // Deleta a tarefa
    final deleteTaskResponse = await http.delete(
      Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2', {'id': 'eq.$gID'}),
      headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $gToken',
      },
    );

    if (deleteTaskResponse.statusCode == 204) {
      // Se a tarefa foi deletada com sucesso e há um chat associado, deleta o chat
      if (chatId != '0') {
        final deleteChatResponse = await http.delete(
          Uri.https('barra.cos.ufrj.br:443', '/rest/conversas', {'id': 'eq.$chatId'}),
          headers: <String, String>{
            'accept': 'application/json',
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $gToken',
          },
        );

        if (deleteChatResponse.statusCode != 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete associated chat')),
          );
        }
      }

      _fetchTasks();
    } else if (deleteTaskResponse.statusCode == 401 && jsonDecode(deleteTaskResponse.body)['code'] == 'PGRST301') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired, please log in again')),
      );
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete task')),
      );
    }
  } else if (taskResponse.statusCode == 401 && jsonDecode(taskResponse.body)['code'] == 'PGRST301') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired, please log in again')),
    );
    Navigator.pushReplacementNamed(context, '/');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to fetch task details')),
    );
  }
}

  void _logout() {
    // Limpar o token de autenticação ou invalidar a sessão
    Navigator.pushReplacementNamed(context, '/');
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Lista Principal'),
    ),
    drawer: Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Lista Principal'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/listaPrincipal');
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Lista de Chats'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/listaChats');
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_comment),
            title: const Text('Nova Conversa'),
            onTap: () {
              Navigator.pop(context);
              _showNewChatDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    ),
    body: listas.isEmpty
        ? const Center(child: Text('Nenhuma tarefa encontrada'))
        : Container(
            color: Colors.grey[200], // Cor de fundo
            child: ListView.builder(
              itemCount: listas.length,
              itemBuilder: (context, index) {
                final task = listas[index];
                final taskId = task['id'];
                final taskName = task['atributos']['nome']?.toString() ?? 'Unnamed Task';

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blue, width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: ListTile(
                    title: Text(taskName),
                    subtitle: task['atributos']['chatId'] != '0'
                        ? Text("Associado ao chat de nome: $taskName")
                        : const SizedBox.shrink(),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        setState(() {
                          gID = taskId;
                        });
                        await _delete();
                      },
                    ),
                    onTap: () {
                      // Atualiza o gID e navega para MyHomePage
                      setState(() {
                        gID = taskId;
                      });
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyHomePage(
                            title: 'TaskList Home Page',
                            token: gToken!,
                            email: gEmail!,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        _showNewTaskDialog(context);
      },
      child: const Icon(Icons.add),
      tooltip: 'Criar Nova Lista',
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
  );
}

void _showNewTaskDialog(BuildContext context) {
  final TextEditingController _nameController = TextEditingController();
  bool associarChat = false;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Criar Nova Lista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome da Lista'),
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                const Text('Associar a um chat?'),
                StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return Switch(
                      value: associarChat,
                      onChanged: (value) {
                        setState(() {
                          associarChat = value;
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final nomeLista = _nameController.text;
              if (nomeLista.isNotEmpty) {
                _newTask(nomeLista, associarChat);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nome não pode ser vazio')),
                );
              }
            },
            child: const Text('Criar'),
          ),
        ],
      );
    },
  );
}
Future<void> _newChat(String nomeChat) async {
  // Cria uma nova conversa
  final chatResponse = await http.post(
    Uri.https('barra.cos.ufrj.br:443', '/rest/rpc/cria_conversa'),
    headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $gToken',
    },
  );

  if (chatResponse.statusCode == 200) {
    final chatData = jsonDecode(chatResponse.body);
    final chatId = chatData.toString();
    gID = chatId;

    // Cria uma nova lista de tarefas associada ao chat
    final taskResponse = await http.post(
      Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
      headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $gToken',
      },
      body: jsonEncode(<String, dynamic>{
        'email': gEmail,
        'valor': [],
        'atributos': {'nome': nomeChat, 'index': -1, 'chatId': chatId},
      }),
    );

    if (taskResponse.statusCode == 201) {
      final fetchResponse = await http.get(
        Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
        headers: <String, String>{
          'accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $gToken',
        },
      );

      if (fetchResponse.statusCode == 200) {
        final fetchData = jsonDecode(fetchResponse.body);
        String taskId = '';
        for (var task in fetchData) {
          if (task['atributos']['chatId'] == chatId) {
            taskId = task['id'].toString();
            break;
          }
        }

      // Atualiza o chat com o ID da lista de tarefas
      final patchChatResponse = await http.patch(
        Uri.https('barra.cos.ufrj.br:443', '/rest/conversas', {'id': 'eq.$chatId'}),
        headers: <String, String>{
          'accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $gToken',
        },
        body: jsonEncode(<String, dynamic>{
          'atributos': {'nome': nomeChat, 'index': -1, 'listaId': taskId},
        }),
      );

      if (patchChatResponse.statusCode != 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update chat with task ID')),
        );
      }

    } else if (taskResponse.statusCode == 401 && jsonDecode(taskResponse.body)['code'] == 'PGRST301') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired, please log in again')),
      );
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create new task list')),
      );
    }
  } else if (chatResponse.statusCode == 401 && jsonDecode(chatResponse.body)['code'] == 'PGRST301') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired, please log in again')),
    );
    Navigator.pushReplacementNamed(context, '/');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to create new chat')),
    );
  }
}
}

void _showNewChatDialog(BuildContext context) {
  final TextEditingController _nameController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Criar Nova Conversa'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nome da Conversa e Lista'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final nomeChat = _nameController.text;
              if (nomeChat.isNotEmpty) {
                _newChat(nomeChat);
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(),
                ),
              );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nome não pode ser vazio')),
                );
              }
            },
            child: const Text('Criar'),
          ),
        ],
      );
    },
  );
}
}

class ListaChats extends StatefulWidget {
  @override
  _ListaChatsState createState() => _ListaChatsState();
}

class _ListaChatsState extends State<ListaChats> {
  List<Map<String, dynamic>> chats = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchChats();
    });
  }

  Future<void> _fetchChats() async {
    final response = await http.get(
      Uri.https('barra.cos.ufrj.br:443', '/rest/conversas'),
      headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $gToken',
      },
    );
    if (response.statusCode == 200) {
      final aux = jsonDecode(response.body);
      setState(() {
        chats.clear();
        for (var chat in aux) {
          chats.add({
            'id': chat['id'].toString(),
            'atributos': chat['atributos'],
          });
        }
      });

      chats.sort((a, b) => (a['atributos']['index'] ?? 0).compareTo(b['atributos']['index'] ?? 0));
      for (int i = 0; i < chats.length; i++) {
        chats[i]['atributos']['index'] = i;
      }
      // Atualiza a ordem dos índices no servidor
      for (var chat in chats) {
        final chatId = chat['id'];
        final chatIndex = chat['atributos']['index'];

        final response = await http.patch(
          Uri.https('barra.cos.ufrj.br:443', '/rest/conversas', {'id': 'eq.$chatId'}),
          headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $gToken',
          },
          body: jsonEncode(<String, dynamic>{
        'atributos': {
          'nome': chat['atributos']['nome'],
          'index': chatIndex,
          'listaId': chat['atributos']['listaId'],
        },
          }),
        );

        if (response.statusCode != 204) {
          ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update chat order')),
          );
        }
      }

      gChats = chats;

    } else if (response.statusCode == 401 && jsonDecode(response.body)['code'] == 'PGRST301') {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired, please log in again')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch chats')),
      );
    }
  }

Future<void> _newChat(String nomeChat) async {
  // Cria uma nova conversa
  final chatResponse = await http.post(
    Uri.https('barra.cos.ufrj.br:443', '/rest/rpc/cria_conversa'),
    headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $gToken',
    },
  );

  if (chatResponse.statusCode == 200) {
    final chatData = jsonDecode(chatResponse.body);
    final chatId = chatData.toString();
    gID = chatId;

    // Cria uma nova lista de tarefas associada ao chat
    final taskResponse = await http.post(
      Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
      headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $gToken',
      },
      body: jsonEncode(<String, dynamic>{
        'email': gEmail,
        'valor': [],
        'atributos': {'nome': nomeChat, 'index': -1, 'chatId': chatId},
      }),
    );

    if (taskResponse.statusCode == 201) {
      final fetchResponse = await http.get(
        Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2'),
        headers: <String, String>{
          'accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $gToken',
        },
      );

      if (fetchResponse.statusCode == 200) {
        final fetchData = jsonDecode(fetchResponse.body);
        String taskId = '';
        for (var task in fetchData) {
          if (task['atributos']['chatId'] == chatId) {
            taskId = task['id'].toString();
            break;
          }
        }

      // Atualiza o chat com o ID da lista de tarefas
      final patchChatResponse = await http.patch(
        Uri.https('barra.cos.ufrj.br:443', '/rest/conversas', {'id': 'eq.$chatId'}),
        headers: <String, String>{
          'accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $gToken',
        },
        body: jsonEncode(<String, dynamic>{
          'atributos': {'nome': nomeChat, 'index': -1, 'listaId': taskId},
        }),
      );

      if (patchChatResponse.statusCode != 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update chat with task ID')),
        );
      }

    } else if (taskResponse.statusCode == 401 && jsonDecode(taskResponse.body)['code'] == 'PGRST301') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired, please log in again')),
      );
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create new task list')),
      );
    }
  } else if (chatResponse.statusCode == 401 && jsonDecode(chatResponse.body)['code'] == 'PGRST301') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired, please log in again')),
    );
    Navigator.pushReplacementNamed(context, '/');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to create new chat')),
    );
  }
}
}

  Future<void> _deleteChat() async {
  // Primeiro, obtenha os detalhes do chat para verificar se há uma lista associada
  final chatResponse = await http.get(
    Uri.https('barra.cos.ufrj.br:443', '/rest/conversas', {'id': 'eq.$gID'}),
    headers: <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $gToken',
    },
  );

  if (chatResponse.statusCode == 200) {
    final chatData = jsonDecode(chatResponse.body);
    final listaId = chatData[0]['atributos']['listaId'];

    // Deleta o chat
    final deleteChatResponse = await http.delete(
      Uri.https('barra.cos.ufrj.br:443', '/rest/conversas', {'id': 'eq.$gID'}),
      headers: <String, String>{
        'accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $gToken',
      },
    );

    if (deleteChatResponse.statusCode == 204) {
      // Se o chat foi deletado com sucesso e há uma lista associada, deleta a lista
      if (listaId != null && listaId != '0') {
        final deleteTaskResponse = await http.delete(
          Uri.https('barra.cos.ufrj.br:443', '/rest/tarefasv2', {'id': 'eq.$listaId'}),
          headers: <String, String>{
            'accept': 'application/json',
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $gToken',
          },
        );

        if (deleteTaskResponse.statusCode != 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete associated task list')),
          );
        }
      }

      _fetchChats();
    } else if (deleteChatResponse.statusCode == 401 && jsonDecode(deleteChatResponse.body)['code'] == 'PGRST301') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired, please log in again')),
      );
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete chat')),
      );
    }
  } else if (chatResponse.statusCode == 401 && jsonDecode(chatResponse.body)['code'] == 'PGRST301') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired, please log in again')),
    );
    Navigator.pushReplacementNamed(context, '/');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to fetch chat details')),
    );
  }
}

  void _logout() {
    // Limpar o token de autenticação ou invalidar a sessão
    Navigator.pushReplacementNamed(context, '/');
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Lista de Chats'),
    ),
    drawer: Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.green,
            ),
            child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Lista Principal'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/listaPrincipal');
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Lista de Chats'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/listaChats');
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_comment),
            title: const Text('Nova Conversa'),
            onTap: () {
              Navigator.pop(context);
              _showNewChatDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    ),
    body: chats.isEmpty
        ? const Center(child: Text('Nenhum chat encontrado'))
        : Container(
            color: Colors.grey[200], // Cor de fundo
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final chatId = chat['id'];
                final chatName = chat['atributos']['nome']?.toString() ?? 'Unnamed Chat';

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.green, width: 2.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: ListTile(
                    title: Text(chatName),
                    subtitle: chat['atributos']['listaId'] != '0'
                        ? Text("Associado à lista de tarefas de nome: $chatName")
                        : const SizedBox.shrink(),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        setState(() {
                          gID = chatId;
                        });
                        await _deleteChat();
                      },
                    ),
                    onTap: () {
                      // Atualiza o gID e navega para ChatPage
                      setState(() {
                        gID = chatId;
                      });
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        _showNewChatDialog(context);
      },
      child: const Icon(Icons.add),
      tooltip: 'Criar Novo Chat',
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
  );
}

void _showNewChatDialog(BuildContext context) {
  final TextEditingController _nameController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Criar Nova Conversa'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nome da Conversa e Lista'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final nomeChat = _nameController.text;
              if (nomeChat.isNotEmpty) {
                _newChat(nomeChat);
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPage(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nome não pode ser vazio')),
                );
              }
            },
            child: const Text('Criar'),
          ),
        ],
      );
    },
  );
}
}
