
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:mime/mime.dart';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:markdown/markdown.dart' as md;
import 'package:flutter_html/flutter_html.dart';

import 'package:timeago/timeago.dart' as timeago;

import '../db.dart';

class Cards extends StatefulWidget {
  const Cards({super.key, required this.directoryPath});

  final String directoryPath;

  @override
  State<Cards> createState() => _CardsState();
}

class _CardsState extends State<Cards> {
  CardsDB _cardsDB = CardsDB();

  FCard? _currentCard;
  bool _showAnswer = false;

  final _RANDOM = {
    "10%": 10,
    "25%": 25,
    "50%": 50,
    "75%": 75,
    "100%": 100,
  };

  final _INTERVALS1 = {
    "1 min": 60,
    "5 min": 60 * 5,
    "15 min": 60 * 15,
    "1 hour": 60 * 60,
    "1 days": 60 * 60 * 12,
 };
  
  final _INTERVALS2 = {
    "1 week": 60 * 60 * 24 * 7,
    "1 month": 60 * 60 * 24 * 30,
    "3 months": 60 * 60 * 24 * 30 * 3,
    "12 months": 60 * 60 * 24 * 30 * 12,
  };
 
  final _PUSH_BACKS1 = {
    "5 spots": 5,
    "10 spots": 10,
    "20 spots": 20,
    "50 spots" : 50,
  };

  final _PUSH_BACKS2 = {
    "push 25%" : 25,
    "push 50%" : 50,
    "push 75%" : 75,
    "push 100%" : 100,
  };

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    var dbPath = p.join(widget.directoryPath, "cards.db");
    await _cardsDB.open(dbPath);
    print("dbPath: $dbPath");

    await _initCurrentCard();

  }

  Future<void> _initCurrentCard() async {

    final closestReviewDateCard = await _cardsDB.getCardWithClosestReviewDate();

    if (closestReviewDateCard != null) {
      setState(() {
        _currentCard = FCard.fromMap(closestReviewDateCard);
        _showAnswer = false;
      });
    }

  }

  Future<void> _initRandomCard(int percentage) async {

    final randomCard = await _cardsDB.getRandomCardWithinPercentRange(percentage);

    if (randomCard != null) {
      setState(() {
        _currentCard = FCard.fromMap(randomCard);
        _showAnswer = false;
      });
    }

  }

  void _showAnswerFunc() {
    setState(() {
      _showAnswer = true;
    });
  }

  Future<void> _moveCardByPosition(String moveType, int moveAmount) async {
    if (_currentCard == null) return;

    var count = await _cardsDB.getCount();
    int targetN;

    if (moveType.startsWith("push")) {

      targetN = (count * moveAmount/100).floor();
      targetN = targetN <= count ? targetN : count;


    } else {

      targetN = moveAmount <= count ? moveAmount : count;

    }

    debugPrint('''
    _moveCardByPosition\n
    moveType: $moveType, moveAmount: $moveAmount, count: $count, targetN: $targetN
    ''');
    
    await _cardsDB.pushCardNPositions(_currentCard!.id, targetN);
  
    await _initCurrentCard();
  
  }

  Future<void> _moveCardBySeconds(int secondsToAdd) async {
    if (_currentCard == null) return;

    DateTime now = DateTime.now();

    DateTime new_datetime = now.add(Duration(seconds: secondsToAdd));

    await _cardsDB.updateCardReviewDate(_currentCard!.id, new_datetime);

    final closestReviewDateCard = await _cardsDB.getCardWithClosestReviewDate();

    await _initCurrentCard();

  }

  String replaceMarkdownImageString(String input) {
    final regex = RegExp(r'\!\[([^\][]*)]\(([^()]*)\)');

  
    return input.replaceAllMapped(regex, (match) {
      var altText = match.group(1);
      var imagePath = match.group(2);

      //print("img src: ${imagePath}");

      final newPath = p.join(widget.directoryPath, "media", imagePath);
  
      if (altText == "") {
        altText = imagePath;
      }
  
      try {

          final bytes = File(newPath).readAsBytesSync();
          final base64Image = base64Encode(bytes);
          final mimeType = lookupMimeType(newPath);
          final src = "data:$mimeType;base64,$base64Image";

          return '<img alt="$altText" src="$src" />';

      } catch (e) {

        debugPrint("${e}");

        return '''
        Image: ${newPath} failed to display, usually this is because the file has a / or a \\ in it's filepath.\n
        Rename the image file, removing the / and \\, and edit it in the cards.md file and the image should be displayed.
        ''';

      }
  
    });
  }


  @override
  Widget build(BuildContext context) {
    var q = _currentCard?.question ?? 'There seems to be no question.';
    var a = _currentCard?.answer ?? 'There seems to be no answer.';

    //print("before ${q}");
    q = replaceMarkdownImageString(q);
    //print("after ${q}");
    a = replaceMarkdownImageString(a);

    var questionH = md.markdownToHtml(q);
    var answerH = md.markdownToHtml(a);

    //print("html ${questionH}");

    var dt = _currentCard?.reviewDate ?? DateTime.now().toIso8601String();
    var due_date = timeago.format(DateTime.parse(dt));
  
    return Scaffold(
      body: Flex(
        direction: Axis.vertical,
        children: <Widget>[
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Column(
                      children: [
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ElevatedButton(
                                onPressed: () => _initCurrentCard(),
                                style: ElevatedButton.styleFrom(
                                  primary: Colors.green,
                                ),
                                child: Text("0"),
                              ),
                            ),
                            Container(
                              alignment: Alignment.topLeft,
                              padding: const EdgeInsets.only(right: 10),
                              child: Text(
                                'Random <<',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            ..._RANDOM.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ElevatedButton(
                                onPressed: () => _initRandomCard(entry.value),
                                child: Text(entry.key),
                              ),
                            );
                            }).toList(),
                        ]),
                        Container(
                          alignment: Alignment.topLeft,
                          margin: EdgeInsets.only(top: 20, bottom: 20),
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            //color: Colors.grey.shade800,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Question ',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'from ${p.join(widget.directoryPath, "cards.md")}',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Text(
                                'Due date: ${due_date}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Html(
                          data: questionH,
                        ),
                        if (!_showAnswer)
                          ElevatedButton(
                            onPressed: _showAnswerFunc,
                            child: Text("Show Answer"),
                          ),
                          SizedBox(height: 20),
                      ]
                    ),
                    if (_showAnswer)
                      Column(
                        children: [
                          Container(
                            alignment: Alignment.topLeft,
                            margin: EdgeInsets.only(top: 20, bottom: 20),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'Answer',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ), 
                          Html(
                            data: answerH,
                          ),
                          Container(
                            alignment: Alignment.topLeft,
                            margin: EdgeInsets.only(top: 20, bottom: 20),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'Review in or Push back N places',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _INTERVALS1.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: ElevatedButton(
                                  onPressed: () => _moveCardBySeconds(entry.value),
                                  child: Text(entry.key),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _INTERVALS2.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: ElevatedButton(
                                  onPressed: () => _moveCardBySeconds(entry.value),
                                  child: Text(entry.key),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _PUSH_BACKS1.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: ElevatedButton(
                                  onPressed: () => _moveCardByPosition(entry.key, entry.value),
                                  child: Text(entry.key),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _PUSH_BACKS2.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: ElevatedButton(
                                  onPressed: () => _moveCardByPosition(entry.key, entry.value),
                                  child: Text(entry.key),
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        backgroundColor: Colors.grey,
        child: const Icon(Icons.arrow_back),
      ),
    );
 
  }


}