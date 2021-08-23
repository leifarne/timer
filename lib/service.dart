import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:timer/config.dart' as cfg;

/// Global constants and types
///
const timeEntryCollectionName = (kDebugMode) ? cfg.debugCollection : cfg.productionCollection;
final dateFormat = DateFormat('y-MM-dd');

typedef JSON = Map<String, dynamic>;

/// Firestore model class
///
class TimeEntryEntity {
  DateTime date;
  String account;
  DateTime from;
  Duration duration;
  String? comment;

  TimeEntryEntity({required this.date, required this.account, required this.from, required this.duration, this.comment});

  factory TimeEntryEntity.fromJson(String id, String account, JSON json) {
    return TimeEntryEntity(
      date: dateFormat.parse(id),
      account: account,
      from: (json['from']! as Timestamp).toDate(),
      duration: Duration(minutes: json['duration']!),
      comment: json['comment'] as String?,
    );
  }

  JSON toJson() {
    return {
      'from': this.from,
      'duration': this.duration.inMinutes,
      'comment': this.comment,
    };
  }
}

class FirestoreRepository {
  String userName;
  late DocumentReference<JSON> _userDocRef;
  late CollectionReference<TimeEntryEntity> timeEntryCollection;

  FirestoreRepository(this.userName) {
    _userDocRef = FirebaseFirestore.instance.collection(timeEntryCollectionName).doc(userName);
  }

  Future<List<TimeEntryEntity>> loadData(String account) async {
    final timeEntryCollection = _createCollectionRef(account);
    // final querySnapshot = await timeEntryCollection.orderBy(FieldPath.documentId, descending: true).get();
    final querySnapshot = await timeEntryCollection.get();
    final list = querySnapshot.docs.map((docsnapshot) => docsnapshot.data()).toList();
    return list;
  }

  void saveTimeEntry(TimeEntryEntity entity) {
    final timeEntryCollection = _createCollectionRef(entity.account);
    timeEntryCollection.doc(dateFormat.format(entity.date)).set(entity).then((value) {
      print("Hours Added");
    }).catchError((error, trace) {
      print('error');
    });
  }

  Future<List<String>> loadAccountList() async {
    List<String>? wbsList;

    var docSnapshot = await _userDocRef.get();
    var data = docSnapshot.data();

    if (data != null) {
      wbsList = List<String>.from(data['wbss']);
    }
    if (wbsList == null || wbsList.isEmpty) {
      wbsList = [];
    }

    return wbsList;
  }

  void saveAccountList(List<String> wbsList) {
    _userDocRef.set({'wbss': FieldValue.arrayUnion(wbsList)});
  }

  CollectionReference<TimeEntryEntity> _createCollectionRef(String account) {
    final timeEntryCollection = _userDocRef.collection(account).withConverter<TimeEntryEntity>(
          fromFirestore: (snapshot, _) => TimeEntryEntity.fromJson(snapshot.id, account, snapshot.data()!),
          toFirestore: (entry, _) => entry.toJson(),
        );
    return timeEntryCollection;
  }
}

/// Not used
///
// var fmt = DateFormat('y-MM-dd');
// final date = fmt.parse(doc.id);
// final accountName = doc.data()?.['accountName'] ?? _accountName;
// final from = doc.data()['from'].toDate();
// final duration = Duration(minutes: doc.data()['duration']);
// final comment = doc.data()['comment'];
