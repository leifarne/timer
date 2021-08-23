import 'package:flutter/foundation.dart';
import 'package:timer/service.dart';

import 'parse.dart';

class TimeEntry {
  DateTime date;
  String accountName;
  DateTime from;
  Duration duration;
  String? _comment;

  DateTime get to => from.add(duration);
  String get comment => _comment ?? '';

  TimeEntry(this.date, this.accountName, this.from, this.duration, {comment = ''}) : this._comment = comment;

  TimeEntryEntity toEntity() {
    return TimeEntryEntity(date: date, account: accountName, from: from, duration: duration, comment: _comment);
  }

  static TimeEntry fromEntity(TimeEntryEntity timeEntryEntity) {
    return TimeEntry(
      timeEntryEntity.date,
      timeEntryEntity.account,
      timeEntryEntity.from,
      timeEntryEntity.duration,
      comment: timeEntryEntity.comment,
    );
  }
}

/// Model list
///
class TimeEntryList extends ChangeNotifier {
  String account;
  List<TimeEntry> entries = [];
  List<String> wbs = [];
  FirestoreRepository? _repository;

  TimeEntryList(this.account) {
    this._repository = FirestoreRepository('leif.arne.rones@gmail.com');
  }

  void loadAll(String account) {
    this.account = account;

    entries.clear();

    _repository!.loadData(account).then((entities) {
      entries = entities.map(TimeEntry.fromEntity).toList();
      entries.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    }).catchError((err) {
      notifyListeners();
    });
  }

  /// Add new entry, or update the entry for "date" if already present.
  ///
  void addTimeEntry(TimeEntry timeEntry) {
    final i = entries.indexWhere((element) => element.date == timeEntry.date);
    if (i != -1) {
      entries[i] = timeEntry;
    } else {
      entries.add(timeEntry);
      entries.sort((a, b) => b.date.compareTo(a.date));
    }

    notifyListeners();

    _repository!.saveTimeEntry(timeEntry.toEntity());
  }

  /// Add account if not present, then save the list.
  void addAccount(String account) {
    if (!wbs.contains(account)) {
      wbs.add(account);
      notifyListeners();
      _repository!.saveAccountList(wbs);
    }
  }

  void loadAccounts() {
    _repository!.loadAccountList().then((list) {
      wbs = list;
      notifyListeners();
    }).catchError((err) {
      notifyListeners();
    });
  }

  /// Aggregate into weekly summary for nn number of weeks.
  ///
  Map<int, WeeklySummary> generateWeeklySummary(int weeksHistory) {
    var now = DateTime.now();

    var lastTwoWeeksSummaries = <int, WeeklySummary>{};
    for (var i = 0; i < weeksHistory; i++) {
      int thisWeek = weekNumber(now.subtract(Duration(days: 7 * i)));
      lastTwoWeeksSummaries[thisWeek] = WeeklySummary();
    }

    // Iterate through all time entries and add it to the respective weekly summary
    entries.forEach((e) {
      int week = weekNumber(e.date);

      // Summaries only for the last two weeks.
      if (lastTwoWeeksSummaries.containsKey(week)) {
        lastTwoWeeksSummaries[week]!.add(e);
      }
    });
    return lastTwoWeeksSummaries;
  }

  void clear() {
    entries.clear();
    wbs.clear();
    account = '';
    notifyListeners();
    _repository = null;
  }
}

/// Summary
///
class WeeklySummary {
  Set<String> comments = {};
  Duration hours = Duration();

  WeeklySummary();

  void add(TimeEntry e) {
    if (e._comment != null && e._comment!.isNotEmpty) {
      // Trim and remove trailing '.'
      var trimmed = e._comment!.trim();
      if (trimmed.endsWith('.')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      comments.add(trimmed);
    }

    hours += e.duration;
  }
}
