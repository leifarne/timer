// TODO: More entries per day. From as doc key? Accountname part of record.
// TODO: parse decimal numbers as duration in quickType.
// TODO: delete lines
// TODO: optimise list update performance

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

bool debug = true;
String timeEntryCollectionName = (debug) ? "timer-d" : "timer";

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class Model {
  DateTime date;
  String accountName;
  DateTime from;
  Duration duration;
  String comment;
  DateTime get to => from.add(duration);

  Model(this.date, this.accountName, this.from, this.duration,
      {this.comment = ''});
}

final dateFormat = DateFormat('dd.MM');
final timeFormat = DateFormat.Hm();

class _MyHomePageState extends State<MyHomePage> {
  var _fromFocusNode = FocusNode();
  var _quickTypeFocusNode = FocusNode();
  FocusNode _durationFocusNode = FocusNode();
  FocusNode _dateFocusNode = FocusNode();
  var _accountNameFocusNode = FocusNode();

  var _formkey = GlobalKey<FormState>();
  var _scaffoldKey = GlobalKey<ScaffoldState>();

  TextEditingController _dateController;
  TextEditingController _fromController;
  TextEditingController _toController;
  TextEditingController _durationController;
  TextEditingController _quickTypeController;

  CollectionReference _timeEntryCollection;

  DateTime _date;
  String _accountName;
  DateTime _from;
  DateTime _to;
  Duration _duration;
  String _message;
  bool _fromFromQuickType = false;
  bool _durationFromQuickType = false;

  List<Model> _list = <Model>[];

  /// Calculates week number from a date as per https://en.wikipedia.org/wiki/ISO_week_date#Calculation
  int weekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  bool _handleKeyPress(FocusNode node, RawKeyEvent event) {
    print(event.logicalKey);
    if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
      _onSaveForm();
      return true;
    }
    return false;
  }

  bool _initialized = false;
  bool _error = false;

  // Define an async function to initialize FlutterFire
  void initializeFlutterFire() async {
    try {
      // Wait for Firebase to initialize and set `_initialized` state to true
      await Firebase.initializeApp();
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      // Set `_error` state to true if Firebase initialization fails
      setState(() {
        _error = true;
      });
    }
  }

  void _loadData() {
    _list.clear();

    _timeEntryCollection.get().then((QuerySnapshot querySnapshot) {
      var fmt = DateFormat('y-MM-dd');

      querySnapshot.docs.forEach((doc) {
        final date = fmt.parse(doc.id);
        final accountName = doc.data()['accountName'];
        final from = doc.data()['from'].toDate();
        final duration = Duration(minutes: doc.data()['duration']);
        final comment = doc.data()['comment'];

        // print('${doc.id} - $from - $duration');

        _list.add(Model(date, accountName, from, duration, comment: comment));
        setState(() {});
      });
    });
  }

  @override
  void initState() {
    initializeFlutterFire();
    super.initState();

    _timeEntryCollection =
        FirebaseFirestore.instance.collection(timeEntryCollectionName);

    _loadData();

    _date = DateTime.now();
    _accountName = 'Haavind';
    _from = DateTime(_date.year, _date.month, _date.day, _date.hour);
    _duration = Duration(hours: 1);
    final m = Model(_date, _accountName, _from, _duration);
    _to = m.to;

    _dateController = TextEditingController(text: dateFormat.format(_date));
    _quickTypeController = TextEditingController();
    _fromController = TextEditingController(text: timeFormat.format(_from));
    _toController = TextEditingController(text: timeFormat.format(_to));
    _durationController =
        TextEditingController(text: _duration.inHours.toString());

    _selectAllOnFocusChange(_dateFocusNode, _dateController);
    _selectAllOnFocusChange(_quickTypeFocusNode, _quickTypeController);
    _selectAllOnFocusChange(_fromFocusNode, _fromController);
    _selectAllOnFocusChange(_durationFocusNode, _durationController);

    // list.add(Model(_date, _from, _duration)); // For local testing only.
  }

  void _selectAllOnFocusChange(
      FocusNode focusNode, TextEditingController controller) {
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        controller.selection =
            TextSelection(baseOffset: 0, extentOffset: controller.text.length);
      }
    });
  }

  @override
  void dispose() {
    _fromFocusNode.dispose();
    _dateFocusNode.dispose();
    _quickTypeFocusNode.dispose();
    _durationFocusNode.dispose();
    _accountNameFocusNode.dispose();

    _dateController.dispose();
    _quickTypeController.dispose();
    _toController.dispose();
    _fromController.dispose();
    _durationController.dispose();

    super.dispose();
  }

  void _onSaveForm() async {
    if (_formkey.currentState.validate()) {
      _formkey.currentState.save(); // The Model is updated.

      await _timeEntryCollection
          .doc(DateFormat('yyyy-MM-dd').format(_date))
          .set({
        'accountName': _accountName,
        'from': _from,
        'duration': _duration.inMinutes,
        'comment': _message,
      });

      print("Hours Added");

      //Scaffold.of(_formkey.currentContext)
      _scaffoldKey.currentState
          .showSnackBar(SnackBar(content: Text('Hours added!')));

      _loadData();
    }
  }

  void _parseQuickType(String s) {
    // Quick type overrides the other individual fields. If focus in Quick type field.
    // Collect string variables first. Then parse as DateTime and update model object.

    // if empty - use other fields, ie. no Model object == null
    // if 1 field & number => duration. Read From field
    // if 1 field & text (ie. not number) => message.
    // if 2 fields & both numbers => from and duration. Overwrite From and Duration fields
    // if 2 fields & number & text => duration and message. Read From field. Overwrite Duration.
    // if 3 fields & number, number, text => from, duration, message. Overwrite From, Duration.
    // else ERROR.
    String from;
    String duration;
    String message;

    // Do From and Duration come from quick type, or from their respective fields?
    _fromFromQuickType = false;
    _durationFromQuickType = false;

    s = s.trim();
    var scanner = StringScanner(s);

    // Determine which fields are present in the string.
    bool fdm = scanner.matches(RegExp(r'\d+\s\d+\s.+'));
    bool fd = scanner.matches(RegExp(r'\d+\s\d+'));
    bool dm = scanner.matches(RegExp(r'\d+\s.+'));
    bool d = scanner.matches(RegExp(r'\d+'));
    bool m = scanner.matches(RegExp(r'.+'));

    // Collect the strings from Quick Type.
    if (fdm) {
      scanner.expect(RegExp(r'(\d+)\s(\d+)\s(.+)'));
      from = scanner.lastMatch.group(1);
      duration = scanner.lastMatch.group(2);
      message = scanner.lastMatch.group(3);
    } else if (fd) {
      scanner.expect(RegExp(r'(\d+)\s(\d+)'));
      from = scanner.lastMatch.group(1);
      duration = scanner.lastMatch.group(2);
      message = null;
    } else if (dm) {
      scanner.expect(RegExp(r'(\d+)\s(.+)'));
      from = null;
      duration = scanner.lastMatch.group(1);
      message = scanner.lastMatch.group(2);
    } else if (d) {
      scanner.expect(RegExp(r'(\d+)'));
      from = null;
      duration = scanner.lastMatch.group(1);
      message = null;
    } else if (m) {
      scanner.expect(RegExp(r'(.+)'));
      from = null;
      duration = null;
      message = scanner.lastMatch.group(1);
    } else {
      from = null;
      duration = null;
      message = null;
    }

    // Parse and save to model. Defer to _onSave to collect other fields.
    // Use flags to make quick type override individual From and Duration fields.
    if (from != null) {
      _from = _parseTime(from);
      _fromController.text = timeFormat.format(_from);
      _fromFromQuickType = true;
    }
    if (duration != null) {
      _duration = _parseDuration(duration);
      _durationFromQuickType = true;
    }
    _message = message;
  }

  DateTime _parseDate(String v) {
    final now = DateTime.now();
    DateTime dt;
    try {
      dt = dateFormat.parse(v);
      dt = DateTime(now.year, dt.month, dt.day);
    } catch (FormatException) {
      dt = DateFormat('dd').parse(v);
      dt = DateTime(now.year, now.month, dt.day);
    }
    print('date = $dt');
    return dt;
  }

  bool _isDate(String v) {
    // ignore: unused_local_variable
    DateTime dt;
    try {
      dt = dateFormat.parse(v);
    } catch (FormatException) {
      try {
        dt = DateFormat('dd').parse(v);
      } catch (FormatException) {
        return false;
      }
    }
    return true;
  }

  DateTime _parseTime(String s) {
    final now = DateTime.now();
    DateTime tm;
    try {
      tm = timeFormat.parse(s);
    } catch (FormatException) {
      tm = DateFormat('HH').parse(s);
    }
    tm = DateTime(now.year, now.month, now.day, tm.hour, tm.minute);
    print('time = $tm');
    return tm;
  }

  bool _isTime(String s) {
    // ignore: unused_local_variable
    DateTime tm;
    try {
      tm = timeFormat.parse(s);
    } catch (FormatException) {
      try {
        tm = DateFormat('HH').parse(s);
      } catch (FormatException) {
        return false;
      }
    }
    return true;
  }

  Duration _parseDuration(String s) {
    double d = double.parse(s);
    final h = d.truncate();
    final m = (d.remainder(1) * 60).round();
    print('h = $h, m = $m');
    return Duration(hours: h, minutes: m);
  }

  bool _isDuration(String s) {
    try {
      double.parse(s);
    } catch (FormatException) {
      return false;
    }
    return true;
  }

  Widget buildListTile(Model model) {
    final week = weekNumber(model.date);
    final date = dateFormat.format(model.date);
    final accountName = model.accountName ?? '<...>';
    final from = timeFormat.format(model.from);
    final to = timeFormat.format(model.to);
    final duration =
        (model.duration.inMinutes.toDouble() / 60).toStringAsFixed(1);

    return Card(
      child: ListTile(
        leading: Container(
          width: 100,
          // height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              color: Colors.black26),
          child: Text(
            '$date',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(accountName, style: TextStyle(fontWeight: FontWeight.bold)),
            Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text(
                ' week $week [ $from - $to ]',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.black54),
              ),
            ),
          ],
        ),
        subtitle: Text(model.comment ?? ''),
        trailing: Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              color: Colors.purple),
          child: Text(
            duration,
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      print('Wrong');
      return Text('Wrong');
    }

    // Show a loader until FlutterFire is initialized
    if (!_initialized) {
      print('Loading...');
      return Text('Loading...');
    }

    // TODO: clean up onChange and updates to the model.
    // including clean up the model itself.

    var fromField = buildTimeField(null, 'From', _fromController, (v) {
      if (_isTime(v)) {
        _from = _parseTime(v);
        // _fromController.text = timeFormat.format(_from);

        _to = _from.add(_duration);
        _toController.text = timeFormat.format(_to);
      }
    },
        (v) => _from = (_fromFromQuickType) ? _from : _parseTime(v),
        (v) => _isTime(v) ? null : "Not in HH:mm or HH time format",
        _fromFocusNode);

    var durationField = buildDurationField(_duration, 'Duration', (v) {
      if (_isDuration(v)) {
        _duration = _parseDuration(v);
        _to = _from.add(_duration);
        _toController.text = timeFormat.format(_to);
      }
    },
        (v) => _duration =
            (_durationFromQuickType) ? _duration : _parseDuration(v),
        (v) => _isDuration(v) ? null : "Not an int");

    var toField = buildTextField3(Icons.access_time, null, 'HH:mm', 'To',
        _toController, null, null, null, null, null);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Checkbox(value: debug, onChanged: null),
          Center(child: Text('Debug')),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Card(
                elevation: 4,
                child: Form(
                  key: _formkey,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: FocusScope(
                      onKey: _handleKeyPress,
                      onFocusChange: _onFocusChange,
                      child: Container(
                        width: double.infinity,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                buildDateField3(),
                                Expanded(
                                  child: buildAccountNameField(),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            buildQuickInputField(),
                            SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                fromField,
                                durationField,
                                toField,
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  onChanged: () {},
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemBuilder: (context, index) => buildListTile(_list[index]),
                  itemCount: _list.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTextField2(
      IconData iconData,
      String initialValue,
      String helperText,
      String labelText,
      void Function(String) onChanged,
      void Function(String) onSaved,
      List<TextInputFormatter> inputFormatters,
      FocusNode focusNode) {
    final decoration = InputDecoration(
      hintText: '13 3 Meeting on strategy',
      border: OutlineInputBorder(),
      helperText: '([from] duration [descr.]) ! [descr.]',
      icon: Icon(iconData),
      labelText: labelText,
      // suffixText: '(ddmm)',
    );

    return Container(
      // width: 150,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: TextFormField(
        controller: _quickTypeController,
        onChanged: onChanged,
        onSaved: onSaved,
        initialValue: null,
        focusNode: _quickTypeFocusNode,
        decoration: decoration,
        inputFormatters: inputFormatters,
      ),
    );
  }

  Widget buildTextField(
      IconData iconData,
      String initialValue,
      String helperText,
      String labelText,
      TextEditingController controller,
      void Function(String) onChanged,
      void Function(String) onSaved,
      String Function(String) validator,
      List<TextInputFormatter> inputFormatters,
      FocusNode focusNode) {
    final decoration = InputDecoration(
      border: OutlineInputBorder(),
      helperText: helperText,
      icon: Icon(iconData),
      labelText: labelText,
      // suffixText: '(ddmm)',
    );

    return Container(
      width: 150,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        onSaved: onSaved,
        initialValue: initialValue,
        focusNode: focusNode,
        decoration: decoration,
        inputFormatters: inputFormatters,
        validator: validator,
      ),
    );
  }

  Widget buildTextField3(
      IconData iconData,
      String initialValue,
      String helperText,
      String labelText,
      TextEditingController controller,
      void Function(String) onChanged,
      void Function(String) onSaved,
      String Function(String) validator,
      List<TextInputFormatter> inputFormatters,
      FocusNode focusNode) {
    final decoration = InputDecoration(
      border: OutlineInputBorder(),
      helperText: helperText,
      icon: Icon(iconData),
      labelText: labelText,
      enabled: false,
      // suffixText: '(ddmm)',
    );

    return Container(
      width: 150,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        onSaved: onSaved,
        initialValue: initialValue,
        focusNode: focusNode,
        decoration: decoration,
        inputFormatters: inputFormatters,
        validator: validator,
      ),
    );
  }

  Widget buildDateField(
      DateTime initialValue,
      String labelText,
      void Function(String) onChanged,
      void Function(String) onSaved,
      String Function(String) validator,
      FocusNode focusNode) {
    return Container(
      width: 150,
      child: buildTextField(
          Icons.calendar_today,
          null,
          'dd[.MM]',
          labelText,
          _dateController,
          onChanged,
          onSaved,
          validator,
          null, //[FilteringTextInputFormatter.digitsOnly],
          _dateFocusNode),
    );
  }

  Widget buildTimeField(
      DateTime initialValue,
      String labelText,
      TextEditingController controller,
      void Function(String) onChanged,
      void Function(String) onSaved,
      String Function(String) validator,
      FocusNode focusNode) {
    return Container(
      width: 150,
      child: buildTextField(
          Icons.access_time,
          (initialValue != null) ? timeFormat.format(initialValue) : null,
          'hh[:mm]',
          labelText,
          controller,
          onChanged,
          onSaved,
          validator,
          [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            LengthLimitingTextInputFormatter(5)
          ],
          focusNode),
    );
  }

  Widget buildDurationField(
    Duration initialValue,
    String labelText,
    void Function(String) onChanged,
    void Function(String) onSaved,
    String Function(String) validator,
  ) {
    return buildTextField(
        Icons.timelapse,
        null, //initialValue.inHours.toString(),
        'h[.h]',
        labelText,
        _durationController,
        onChanged,
        onSaved,
        validator,
        [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          LengthLimitingTextInputFormatter(3)
        ],
        _durationFocusNode);
  }

  void _onFocusChange(bool value) {
    print('Focus change');
  }

  Widget buildAccountNameField() {
    final decoration = InputDecoration(
      hintText: 'Haavind',
      border: OutlineInputBorder(),
      helperText: 'Text label',
      icon: Icon(Icons.account_balance),
      labelText: 'Account Name',
      // suffixText: '(ddmm)',
    );

    return Container(
      // width: 150,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: TextFormField(
        onSaved: (s) => _accountName = s,
        initialValue: _accountName,
        focusNode: _accountNameFocusNode,
        decoration: decoration,
      ),
    );
  }

  Widget buildQuickInputField() {
    return buildTextField2(
        Icons.format_quote,
        null,
        '[from] [duration] [message]',
        'Quick Input',
        (s) {},
        _parseQuickType,
        null,
        null);
  }

  Widget buildDateField2() {
    return buildDateField(null, 'Date', null, (v) => _date = _parseDate(v),
        (v) => _isDate(v) ? null : "Not a date", _dateFocusNode);
  }

  Widget buildDateField3() {
    final decoration = InputDecoration(
      border: OutlineInputBorder(),
      helperText: 'dd[.MM]',
      icon: Icon(Icons.calendar_today),
      labelText: 'Date',
      // suffixText: '(ddmm)',
    );

    return Container(
      width: 150,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: TextFormField(
        controller: _dateController,
        onChanged: null,
        onSaved: (v) => _date = _parseDate(v),
        initialValue: null,
        focusNode: _dateFocusNode,
        decoration: decoration,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          LengthLimitingTextInputFormatter(5)
        ],
        validator: (v) => _isDate(v) ? null : "Not a date",
      ),
    );
  }
}
