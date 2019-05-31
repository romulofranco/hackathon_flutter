import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttr_protorecorder/languages.dart';
import 'package:fluttr_protorecorder/recognizer.dart';
import 'package:fluttr_protorecorder/task.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';


class TranscriptorWidget extends StatefulWidget {
  final Language lang;

  TranscriptorWidget({this.lang});

  @override
  _TranscriptorAppState createState() => new _TranscriptorAppState();
}

class _TranscriptorAppState extends State<TranscriptorWidget> {
  String transcription = '';

  bool authorized = false;

  bool isListening = false;

  List<Task> todos = [];

  bool get isNotEmpty => transcription != '';

  get numArchived =>
      todos
          .where((t) => t.complete)
          .length;

  Iterable<Task> get incompleteTasks => todos.where((t) => !t.complete);

  @override
  void initState() {
    super.initState();
    SpeechRecognizer.setMethodCallHandler(_platformCallHandler);
    _activateRecognition();
  }

  @override
  void dispose() {
    super.dispose();
    if (isListening) _cancelRecognitionHandler();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery
        .of(context)
        .size;

    List<Widget> blocks = [
      new Expanded(
          flex: 2,
          child: new ListView(
              children: incompleteTasks
                  .map((t) =>
                  _buildTaskWidgets(
                      task: t,
                      onDelete: () => _deleteTaskHandler(t),
                      onComplete: () => _completeTaskHandler(t)))
                  .toList())),
      _buildButtonBar(),
    ];
    if (isListening || transcription != '')
      blocks.insert(
          1,
          _buildTranscriptionBox(
              text: transcription,
              onCancel: _cancelRecognitionHandler,
              width: size.width - 20.0));
    return new Center(
        child: new Column(mainAxisSize: MainAxisSize.min, children: blocks));
  }

  Future<String> apiRequest(String url, Map jsonMap) async {
    HttpClient httpClient = new HttpClient();
    HttpClientRequest request = await httpClient.postUrl(Uri.parse(url));
    request.headers.set('content-type', 'application/json');
    request.add(utf8.encode(json.encode(jsonMap)));
    HttpClientResponse response = await request.close();
    // todo - you should check the response.statusCode
    String reply = await response.transform(utf8.decoder).join();
    httpClient.close();
    return reply;
  }

  Future<http.Response> requestMethod(String urlParam, Map jsonMap) async {
    var url = urlParam;
    var body = json.encode(jsonMap);

    String apiKey = 'apikey';
    String password = 'oXJJES7ym2VT01RBWVUgCiRM6Ci0vTqQbt3UeU9Q92uP';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$apiKey:$password'));
    print(basicAuth);

    Map<String,String> headers = {
      'Content-type' : 'application/json',
      'Accept': 'application/json',
      'authorization': basicAuth,
    };

    final response = await http.post(url, body: body, headers: headers);
    if (response.statusCode == 200) {
      String responseBody = response.body;
      var responseJSON = json.decode(responseBody);
      var dataFinal = responseJSON['data'];
      setState(() {
        print('UI Updated');
      });
    } else {
      print('Something went wrong. \nResponse Code : ${response.statusCode}');
    }

    final responseJson = json.decode(response.body);
    print(responseJson);
    return response;
  }

  void getMethod2() async {
    var queryParameters = {
      'version': '2018-11-16',
      'text': "I am feeling melancolig by the way",
      'features': 'keywords,entities',
      'entities.emotion': 'true',
      'entities.sentiment': 'true',
      'keywords.emotion': 'true',
      'keywords.sentiment': 'true',
    };


    String apiKey = 'apikey';
    String password = 'oXJJES7ym2VT01RBWVUgCiRM6Ci0vTqQbt3UeU9Q92uP';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$apiKey:$password'));
    print(basicAuth);

    print(queryParameters);

    var uri =
    Uri.https('gateway.watsonplatform.net', '/natural-language-understanding/api/v1/analyze', queryParameters);
    var response = await http.get(uri, headers: {
      HttpHeaders.authorizationHeader: basicAuth,
      HttpHeaders.contentTypeHeader: 'application/json',
    });

    print(response.statusCode);
    print(response.body);
  }

  void getMethod() async {
    String apiKey = 'apikey';
    String password = 'oXJJES7ym2VT01RBWVUgCiRM6Ci0vTqQbt3UeU9Q92uP';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$apiKey:$password'));
    print(basicAuth);

    Response r = await get('https://gateway.watsonplatform.net/natural-language-understanding/api/v1/analyze?version=2018-11-16&text=this%20is%20a%20test&features=keywords,entities&entities.emotion=true&entities.sentiment=true&keywords.emotion=true&keywords.sentiment=true',
        headers: {'authorization': basicAuth});
    print(r.statusCode);
    print(r.body);
  }

  Future _saveTranscription() async {
    if (transcription.isEmpty) return;

    String url =
        'https://gateway.watsonplatform.net/natural-language-understanding/api/v1/analyze?version=2018-11-16';
    Map map = {
    'data': {'text': 'I love apples! I do not like oranges.','features': {'sentiment': {},'keywords': {'emotion': true}}}};

    //print(await apiRequest(url, map));
    //print(await requestMethod(url,map));
    getMethod2();


    setState(() {
    todos.add(new Task(
    taskId: new DateTime.now().millisecondsSinceEpoch,
    label: transcription));
    transcription = '';
    });
    _cancelRecognitionHandler
    (
    );
  }

  Future _startRecognition() async {
    final res = await SpeechRecognizer.start(widget.lang.code);
    if (!res)
      showDialog(
          context: context,
          child: new SimpleDialog(title: new Text("Error"), children: [
            new Padding(
                padding: new EdgeInsets.all(12.0),
                child: const Text('Recognition not started'))
          ]));
  }

  Future _cancelRecognitionHandler() async {
    final res = await SpeechRecognizer.cancel();

    setState(() {
      transcription = '';
      isListening = res;
    });
  }

  Future _activateRecognition() async {
    final res = await SpeechRecognizer.activate();
    setState(() => authorized = res);
  }

  Future _platformCallHandler(MethodCall call) async {
    switch (call.method) {
      case "onSpeechAvailability":
        setState(() => isListening = call.arguments);
        break;
      case "onSpeech":
        if (todos.isNotEmpty) if (transcription == todos.last.label) return;
        setState(() => transcription = call.arguments);
        break;
      case "onRecognitionStarted":
        setState(() => isListening = true);
        break;
      case "onRecognitionComplete":
        setState(() {
          if (todos.isEmpty) {
            transcription = call.arguments;
          } else if (call.arguments == todos.last?.label)
            // on ios user can have correct partial recognition
            // => if user add it before complete recognition just clear the transcription
            transcription = '';
          else
            transcription = call.arguments;
        });
        break;
      default:
        print('Unknowm method ${call.method} ');
    }
  }

  void _deleteTaskHandler(Task t) {
    setState(() {
      todos.remove(t);
      _showStatus("cancelled");
    });
  }

  void _completeTaskHandler(Task completed) {
    setState(() {
      todos =
          todos.map((t) => completed == t ? (t..complete = true) : t).toList();
      _showStatus("completed");
    });
  }

  Widget _buildButtonBar() {
    List<Widget> buttons = [
      !isListening
          ? _buildIconButton(authorized ? Icons.mic : Icons.mic_off,
          authorized ? _startRecognition : null,
          color: Colors.white, fab: true)
          : _buildIconButton(Icons.add, isListening ? _saveTranscription : null,
          color: Colors.white,
          backgroundColor: Colors.greenAccent,
          fab: true),
    ];
    Row buttonBar = new Row(mainAxisSize: MainAxisSize.min, children: buttons);
    return buttonBar;
  }

  Widget _buildTranscriptionBox(
      {String text, VoidCallback onCancel, double width}) =>
      new Container(
          width: width,
          color: Colors.grey.shade200,
          child: new Row(children: [
            new Expanded(
                child: new Padding(
                    padding: new EdgeInsets.all(8.0), child: new Text(text))),
            new IconButton(
                icon: new Icon(Icons.close, color: Colors.grey.shade600),
                onPressed: text != '' ? () => onCancel() : null),
          ]));

  Widget _buildIconButton(IconData icon, VoidCallback onPress,
      {Color color: Colors.grey,
        Color backgroundColor: Colors.pinkAccent,
        bool fab = false}) {
    return new Padding(
      padding: new EdgeInsets.all(12.0),
      child: fab
          ? new FloatingActionButton(
          child: new Icon(icon),
          onPressed: onPress,
          backgroundColor: backgroundColor)
          : new IconButton(
          icon: new Icon(icon, size: 32.0),
          color: color,
          onPressed: onPress),
    );
  }

  Widget _buildTaskWidgets(
      {Task task, VoidCallback onDelete, VoidCallback onComplete}) {
    return new TaskWidget(
        label: task.label, onDelete: onDelete, onComplete: onComplete);
  }

  void _showStatus(String action) {
    final label = "Task $action : ${incompleteTasks.length} left "
        "/ ${numArchived} archived";
    Scaffold.of(context).showSnackBar(new SnackBar(content: new Text(label)));
  }
}
