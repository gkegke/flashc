import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:collection';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqlite_api.dart';

final String tableCard = 'cards';
final String columnId = '_id';
final String columnQuestion = 'question';
final String columnAnswer = 'answer';
final String columnReviewDate = 'review_date';

class FCard {
  final int id;
  final String question;
  final String answer;
  final String reviewDate;

  const FCard({
    required this.id,
    required this.question,
    required this.answer,
    required this.reviewDate,
  });

  Map<String, dynamic> toMap() {
    return {
      columnId: id,
      columnQuestion: question,
      columnAnswer: answer,
      columnReviewDate: reviewDate,
    };
  }

  factory FCard.fromMap(Map<String, dynamic> map) {
    return FCard(
      id: map[columnId] as int,
      question: map[columnQuestion] as String,
      answer: map[columnAnswer] as String,
      reviewDate: map[columnReviewDate] as String,
    );
  }

}

class CardsDB {
  late final Database db;

  Future<void> open(String path) async {
    db = await databaseFactoryFfi.openDatabase(path);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCard (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnQuestion TEXT NOT NULL,
        $columnAnswer TEXT NOT NULL,
        $columnReviewDate TEXT NOT NULL
      )
    ''');
  }

  Future<int> getCount() async {
    final result = await db.rawQuery('SELECT COUNT(*) FROM $tableCard', []);
    final count = result.first.values.first as int?;
    return count ?? 0;
  }

  Future<List<Map<String, Object?>>> getAllCards() async {
    return await db.query(tableCard);
  }

  Future<Map<String, Object?>?> getCardWithClosestReviewDate() async {

    final result = await db.query(
      tableCard,
      orderBy: "$columnReviewDate ASC",
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }
  
    return result.first;
  }

  Future<Map<String, Object?>?> getRandomCardWithinPercentRange(int percentage) async {

    // Get the total count of cards in the database.
    final count = await getCount();
  
    final int _max = (count * (percentage/100)).ceil();

    Random random = new Random();
    final random_n = random.nextInt(_max);
  
    // Fetch a random card within the percentage range.
    final result = await db.rawQuery(
      '''
      SELECT * FROM $tableCard
      ORDER BY review_date ASC
      LIMIT 1 OFFSET ?
      ''',
      [random_n],
    );
  
    // If there are no cards within the range, return null.
    if (result.isEmpty) {
      return null;
    }
  
    // Return the first card in the result set.
    return result.first;

  }


  Future<void> pushCardNPositions(int cardId, int n) async {

    final query = '''
      UPDATE $tableCard
      SET $columnReviewDate = (
        SELECT strftime('%Y-%m-%dT%H:%M:%S', datetime($columnReviewDate, '+1 second'))
        FROM $tableCard
        ORDER BY $columnReviewDate ASC
        LIMIT 1 OFFSET ?
      )
      WHERE $columnId = ?
      ''';
 
    debugPrint('''
    Moving card: $cardId $n spots

    $query

    with args: [${n-1}, $cardId]
    ''');

    await db.rawQuery(query, [n - 1, cardId]);

  }

  Future<void> insertCards(LinkedHashMap<String, String> cards, String dt) async {
    
    final batch = db.batch();

    cards.forEach((question, answer) {
      final values = {
        columnQuestion: question,
        columnAnswer: answer,
        columnReviewDate: dt,
      };
      batch.insert(tableCard, values);
    });

    await batch.commit(noResult: true);
  }

  Future<void> updateCards(List<FCard> cards) async {

    final batch = db.batch();

    cards.forEach((card) {
      final values = {
        columnId: card.id,
        columnQuestion: card.question,
        columnAnswer: card.answer,
        columnReviewDate: card.reviewDate,
      };
      batch.update(tableCard, values,
          where: '$columnId = ?', whereArgs: [card.id]);
    });

    await batch.commit(noResult: true);
  }

  Future<void> updateCardReviewDate(int cardId, DateTime newReviewDate) async {
    final values = {
      columnId: cardId,
      columnReviewDate: newReviewDate.toIso8601String(), // Convert to ISO-8601 format
    };
    await db.update(tableCard, values,
        where: '$columnId = ?', whereArgs: [cardId]);
  }

  Future<void> deleteCards(List<int> cardIds) async {
    final batch = db.batch();

    cardIds.forEach((id) {
      batch.delete(tableCard, where: '$columnId = ?', whereArgs: [id]);
    });

    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await db.close();
  }
}
