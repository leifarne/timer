import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'parse.dart';
import 'model.dart';

class WeekTile extends StatelessWidget {
  const WeekTile({
    Key? key,
    required this.model,
  }) : super(key: key);

  final TimeEntry model;

  @override
  Widget build(BuildContext context) {
    final week = weekNumber(model.date);
    final date = dateFormat.format(model.date);
    final accountName = model.accountName;
    final from = timeFormat.format(model.from);
    final to = timeFormat.format(model.to);
    final duration = (model.duration.inMinutes.toDouble() / 60).toStringAsFixed(1);

    final themeData = Theme.of(context);
    final headline5 = themeData.textTheme.headline5!.copyWith(fontWeight: FontWeight.bold);

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 100,
        // height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(4)), color: Colors.black26),
        child: Text('$date', style: headline5),
      ),
      title: Row(
        children: [
          Text(accountName, style: themeData.textTheme.subtitle1),
          Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(' week $week [ $from - $to ]', style: themeData.textTheme.caption),
          ),
        ],
      ),
      subtitle: Text(model.comment, style: themeData.textTheme.bodyText1),
      trailing: Container(
        width: 50,
        height: 40,
        alignment: Alignment.center,
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(4)), color: Colors.purple),
        child: Text(duration, style: headline5.copyWith(color: Colors.white)),
      ),
    );
  }
}

void showWeeklySummary(BuildContext context, int weeksHistory) {
  showDialog(
    context: context,
    builder: (context) {
      // var weeksHistory = 17;
      var model = Provider.of<TimeEntryList>(context, listen: false);
      Map<int, WeeklySummary> lastTwoWeeksSummaries = model.generateWeeklySummary(weeksHistory);

      // Convert weekly summaries to a list of SelectableText

      var cards = lastTwoWeeksSummaries.entries.map<Card>((MapEntry<int, WeeklySummary> e) {
        var text = 'Uke ${e.key}: ${e.value.comments.join('. ')}';

        return Card(
            elevation: 2,
            child: ListTile(
              leading: IconButton(icon: Icon(Icons.copy_outlined), onPressed: () => Clipboard.setData(ClipboardData(text: text))),
              title: SelectableText(text),
              trailing: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(4)), color: Colors.purple),
                child: Text(
                  '${(e.value.hours.inMinutes.toDouble() / 60).toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ));
      }).toList();

      return SimpleDialog(
        contentPadding: EdgeInsets.all(8),
        title: Text('Three weeks\' summary'),
        children: cards,
      );
    },
  );
}
