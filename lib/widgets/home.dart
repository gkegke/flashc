import 'dart:io';
import 'dart:collection';
import 'package:meta/meta.dart';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;


import 'cards.dart';

import '../db.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {

  String _selectedDirectoryError = '';

  @visibleForTesting
  List<dynamic> _checkCards(File file) {

    var lines = file.readAsLinesSync();

    bool _inComment = false;
    bool _inQuestion = false;
    bool _inAnswer = false;
  
    String possErr = "";
    var currentQuestion = <String>[];
    var currentAnswer = <String>[];

    var cards = new LinkedHashMap<String, String>();

    var lineN = 1;

    debugPrint("checking cards: ${lines.length} lines");

    for (var line in lines) {

      // #### comment indicators

      // comment start
      if (line.startsWith('<!##--')) {
        
        // case: 1 liner comment
        if (!line.contains('##--!>')) {
          _inComment = true;
        }
    
        continue;

      }

      // comment close
      if (_inComment) {

        if (line.startsWith('##--!>')) {

          if (_inComment) {

            _inComment = false;

          } else {

            possErr = 'Warning Line ${lineN}: You might be missing a <!##-- comment start'
                             ' indicator.';

            debugPrint(possErr);

            return [cards, possErr];

          }

        }

        continue;

      }

      // question indicators
      if (line.startsWith('<--') && line.contains("question")) {

        if (_inQuestion) {

          possErr = 'Warning Line ${lineN}: You have tried to start a new card, but seem'
                           ' to already be within a prior card.';

          debugPrint(possErr);

          return [cards, possErr];

        }
        
        _inQuestion = true;

        continue;

      }

      // answer indicators
      if (line.startsWith('<--') && line.contains("answer")) {

        if (_inAnswer || !_inQuestion) {

          possErr = 'Warning Line ${lineN}: You have tried to start a answer section, but'
                           ' seem to already be within a prior answer OR not within a prior'
                           'question.';

          debugPrint(possErr);

          return [cards, possErr];

        }
        
        _inQuestion = false;
        _inAnswer = true;

        continue;

      }

      //
      if (line.startsWith('<--') && line.contains("end")) {

        if (!_inAnswer || _inQuestion) {

          possErr = 'Warning Line ${lineN}: You have tried to end a card, but seem to not'
                           ' have an answer section.';

          debugPrint(possErr);

          return [cards, possErr];

        }

        _inAnswer = false;

        String q = currentQuestion.join("\n");
        String a = currentAnswer.join("\n");

        currentAnswer = <String>[];
        currentQuestion = <String>[];

        cards[q] = a;
 
      }

      if (_inQuestion)
        currentQuestion.add(line);

      if (_inAnswer)
        currentAnswer.add(line);

      lineN = lineN + 1;

    }

    if (currentQuestion.length != currentAnswer.length) {
      possErr = 'Warning Line ${lineN}: We found ${currentQuestion.length} questions '
                       'but ${currentAnswer.length} answers.';

      debugPrint(possErr);

      return [cards, possErr];

    }

    debugPrint(' We found ${cards.length} questions and answers.');

    debugPrint("cards.md appears to be valid..");

    for (int i = 0; i < currentQuestion.length; i++) {
      cards[currentQuestion[i]] = currentAnswer[i];
    }

    return [cards, possErr];

  }

  Future<void> _updateDB(CardsDB db, LinkedHashMap<String, String> dir_cards) async {

    List<Map<String, Object?>> db_cards = await db.getAllCards();
    List<FCard> db_updates = [];
    List<int> db_removes = [];
    String dt;

    final first = await db.getCardWithClosestReviewDate(); 

    if (first != null) {

      var temp = FCard.fromMap(first);
      dt = DateTime.parse(temp.reviewDate as String).subtract(Duration(seconds: 1)).toIso8601String();

    } else {

      dt = DateTime.now().toIso8601String();

    }


    // update db
    if (db_cards != null && db_cards.isNotEmpty) {

      for (final row in db_cards) {

        if (dir_cards.containsKey(row[columnQuestion])) {

          if (dir_cards[row[columnQuestion]] != row[columnAnswer]) {
            // add to update list
            db_updates.add(FCard(
              id : row[columnId] as int,
              question : row[columnQuestion] as String,
              answer: dir_cards[row[columnQuestion]] as String,
              reviewDate: dt as String,
            ));
          }

          dir_cards.remove(row[columnQuestion]);

        } else {

          // add to removal list
          db_removes.add(row[columnId] as int);

        }

      }

    }
      
    debugPrint('''
    db_updates: ${db_updates.length}
    db_removes: ${db_removes.length}
    dir_cards: ${dir_cards.length}
    ''');

    if (db_updates.isNotEmpty) {
      await db.updateCards(db_updates);
    }

    if (db_removes.isNotEmpty) {
      await db.deleteCards(db_removes);
    }

    if (dir_cards.isNotEmpty) {
      await db.insertCards(dir_cards, dt);
    }

  }


  Future<void> _pickValidDirectory() async {

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) {

        debugPrint("selectedDirectory: canceled");

        return;

    }

    debugPrint("selectedDirectory: ${selectedDirectory}");

    String fpath = p.join(selectedDirectory, "cards.md");

    File file = File(fpath);
    bool exists = await file.exists();

    if (!exists) {

      String emsg = 'cards.md does not exist in ${selectedDirectory}'
                    '\nConsider looking at ___.';

      debugPrint(emsg);

      setState(() {
        _selectedDirectoryError = emsg;
      });

      return;

    }
    
    debugPrint("cards.md found in ${selectedDirectory}");

    var result = _checkCards(file);
    var _cards = result[0];
    var possError = result[1];

    print("dir_cards: ${_cards.length}");

    if (_cards.length == 0) {

      String emsg = 'no valid cards were found in cards.md found in ${selectedDirectory}'
                    '\nConsider looking at ___.';

      debugPrint(emsg);

      setState(() {
        _selectedDirectoryError = emsg;
      });

      return;

    }

    print("possError: ${possError}");

    if (possError != "") {

      String emsg = 'cards.md found in ${selectedDirectory}'
                    '\nFound an error while loading:\n'
                    '${possError}';

      setState(() {
        _selectedDirectoryError = emsg;
      });

      return;
      
    }

    // update sqlite3 db with the cards found in the dir
    CardsDB cdb = await CardsDB();
    await cdb.open(p.join(selectedDirectory, "cards.db"));


    int n = await cdb.getCount();
    print("count ${n}");

    await _updateDB(cdb, _cards);

    n = await cdb.getCount();
    print("count ${n}");

    cdb.close();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Cards(directoryPath : selectedDirectory)),
    ).then((value) => setState(() {
      _selectedDirectoryError = "";
    }));

  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      body: Center(
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text("open flash card set", style: Theme.of(context).textTheme.headline6),
            ),
            ElevatedButton(
              //style: style,
              onPressed: _pickValidDirectory,
              child: const Text('Select Directory'),
            ),
            if (_selectedDirectoryError != "")
              Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  _selectedDirectoryError,
                  style: TextStyle(
                      color: Colors.red, // set the text color to red to make the error message stand out
                      fontWeight: FontWeight.bold, // set the font weight to bold to make the error message stand out
                    ),
                  ),  
              ),
          ],
        )
      ),
    );
  }
}