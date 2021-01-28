// TODO: Save if not logged in
// TODO: split messages on '.'. Keep a Set of sentences to avoid duplicates.
// TODO: Clean up widgets. F.eks. egen stateful for from, duration, to.
// TODO: delete lines
// TODO: optimise list update performance
// TODO: Avoid list flashing when type ahead field receives focus.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_typeahead_web/flutter_typeahead.dart';

String timeEntryCollectionName = (kDebugMode) ? "timer-d" : "timer";
String _userName = '...';
final defaultAccountName = 'Haavind';

final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
final GoogleSignIn googleSignIn = GoogleSignIn();

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nordheim Digital',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Timelister for $_userName'),
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

  Model(this.date, this.accountName, this.from, this.duration, {this.comment});
}

class WeeklySummary {
  Set<String> comments = {};
  Duration hours = Duration();

  WeeklySummary();

  void add(Model e) {
    assert(comments != null);
    assert(hours != null);

    if (e.comment != null && e.comment.isNotEmpty) {
      // if (comments == null) {
      //   comments = [];
      // }

      // Trim and remove trailing '.'
      var trimmed = e.comment.trim();
      if (trimmed.endsWith('.')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      comments.add(trimmed);
    }

    hours += e.duration;
  }
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
  TextEditingController _accountNameController;

  CollectionReference _timeEntryCollection;
  DocumentReference _userDocRef;

  List<String> _wbsList = [defaultAccountName];

  DateTime _date;
  String _accountName;
  DateTime _from;
  DateTime _to;
  Duration _duration;
  String _message;
  bool _fromFromQuickType = false;
  bool _durationFromQuickType = false;

  List<Model> _list = <Model>[];

  Future<String> _signInFuture;
  Future<List<String>> _loadAccountsFuture;
  Future<bool> _loadDataFuture;

  // Is logged in
  bool _isLoggedIn() {
    return firebaseAuth.currentUser != null;
  }

  /// Calculates week number from a date as per https://en.wikipedia.org/wiki/ISO_week_date#Calculation
  int weekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  bool _handleKeyPress(FocusNode node, RawKeyEvent event) {
    print(event.logicalKey);
    if (_isLoggedIn() && event.isKeyPressed(LogicalKeyboardKey.enter)) {
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

  Future<bool> _loadData2() async {
    _list.clear();
    // setState(() {});

    QuerySnapshot querySnapshot =
        await _timeEntryCollection.orderBy('from', descending: true).get();

    var fmt = DateFormat('y-MM-dd');

    querySnapshot.docs.forEach((doc) {
      final date = fmt.parse(doc.id);
      final accountName = doc.data()['accountName'] ?? _accountName;
      final from = doc.data()['from'].toDate();
      final duration = Duration(minutes: doc.data()['duration']);
      final comment = doc.data()['comment'];

      // print('${doc.id} - $from - $duration');

      _list.add(Model(date, accountName, from, duration, comment: comment));
    });

    setState(() {});

    return true;
  }

  void _loadData() {
    _list.clear();
    setState(() {});

    _timeEntryCollection
        .orderBy('from', descending: true)
        .get()
        .then((QuerySnapshot querySnapshot) {
      var fmt = DateFormat('y-MM-dd');

      querySnapshot.docs.forEach((doc) {
        final date = fmt.parse(doc.id);
        final accountName = doc.data()['accountName'] ?? _accountName;
        final from = doc.data()['from'].toDate();
        final duration = Duration(minutes: doc.data()['duration']);
        final comment = doc.data()['comment'];

        // print('${doc.id} - $from - $duration');

        _list.add(Model(date, accountName, from, duration, comment: comment));
        setState(() {});
      });
    });
  }

  Future<List<String>> _loadAccountList2() async {
    DocumentSnapshot docSnapshot = await _userDocRef.get();

    var data = docSnapshot.data();

    if (data != null) {
      _wbsList = List<String>.from(data['wbss']);
    }
    if (_wbsList == null || _wbsList.isEmpty) {
      _wbsList = [defaultAccountName];
    }

    // setState(() {});

    print(_wbsList);

    // Default account is first in list. Set docref and _accountNameController.
    _accountName = _wbsList[0];
    _accountNameController.text = _accountName;
    _timeEntryCollection = FirebaseFirestore.instance
        .collection(timeEntryCollectionName)
        .doc(_userName)
        .collection(_accountName);

    // Load timer from doc ref as a Future.
    _loadDataFuture = _loadData2();

    return _wbsList;
  }

  // ignore: unused_element
  void _loadAccountList() async {
    _userDocRef.get().then((DocumentSnapshot docSnapshot) {
      var data = docSnapshot.data();
      if (data != null) {
        _wbsList = List<String>.from(data['wbss']);
      }
      if (_wbsList == null || _wbsList.isEmpty) {
        _wbsList = [defaultAccountName];
      }

      // setState(() {});
      print(_wbsList);
    });
  }

  Future<String> _signin() async {
    User user = firebaseAuth.currentUser;

    print('current = ${user?.email}');

    // Not logged in? then log in.
    if (user == null) {
      final GoogleSignInAccount googleSignInAccount =
          await googleSignIn.signIn();
      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleSignInAuthentication.accessToken,
        idToken: googleSignInAuthentication.idToken,
      );

      final UserCredential userCredential =
          await firebaseAuth.signInWithCredential(credential);

      user = userCredential.user;
    }

    // sorry...
    if (user == null) {
      return 'skybert@nomail.com';
    }

    // Successful login.
    _userName = user.email;
    setState(() {});
    print(_userName);

    _userDocRef = FirebaseFirestore.instance
        .collection(timeEntryCollectionName)
        .doc(_userName);

    // ... and inside here: initiate loading of the data, as well
    _loadAccountsFuture = _loadAccountList2();

    return _userName;
  }

  @override
  void initState() {
    super.initState();

    initializeFlutterFire();

    // Assign defaults to UI model
    _accountName = defaultAccountName;
    _date = DateTime.now();
    _from = DateTime(_date.year, _date.month, _date.day, _date.hour);
    _duration = Duration(hours: 1);
    final m = Model(_date, _accountName, _from, _duration);
    _to = m.to;

    // Create UI field controllers
    _dateController = TextEditingController(text: dateFormat.format(_date));
    _quickTypeController = TextEditingController();
    _fromController = TextEditingController(text: timeFormat.format(_from));
    _toController = TextEditingController(text: timeFormat.format(_to));
    _durationController =
        TextEditingController(text: _duration.inHours.toString());
    _accountNameController = TextEditingController(text: _accountName);

    // Configure focus handling
    _selectAllOnFocusChange(_dateFocusNode, _dateController);
    _selectAllOnFocusChange(_quickTypeFocusNode, _quickTypeController);
    _selectAllOnFocusChange(_fromFocusNode, _fromController);
    _selectAllOnFocusChange(_durationFocusNode, _durationController);
    _selectAllOnFocusChange(_accountNameFocusNode, _accountNameController);

    // Kick off the sign in process to Google and Firebase with a Future.
    _signInFuture = _signin();

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
    _accountNameController.dispose();

    super.dispose();
  }

  void _onLoad() {
    _accountName = _accountNameController.text;
    _timeEntryCollection = FirebaseFirestore.instance
        .collection(timeEntryCollectionName)
        .doc(_userName)
        .collection(_accountName);
    _loadData();
  }

  void _onSaveForm() async {
    if (_formkey.currentState.validate()) {
      _formkey.currentState.save(); // The Model is updated.

      _userDocRef = FirebaseFirestore.instance
          .collection(timeEntryCollectionName)
          .doc(_userName);
      _timeEntryCollection = FirebaseFirestore.instance
          .collection(timeEntryCollectionName)
          .doc(_userName)
          .collection(_accountName);

      await _timeEntryCollection
          .doc(DateFormat('yyyy-MM-dd').format(_date))
          .set({
        // 'accountName': _accountName,
        'from': _from,
        'duration': _duration.inMinutes,
        'comment': _message,
      });

      if (!_wbsList.contains(_accountName)) {
        _wbsList.add(_accountName);
      }

      await _userDocRef.set({'wbss': FieldValue.arrayUnion(_wbsList)});

      print("Hours Added");

      //Scaffold.of(_formkey.currentContext)
      _scaffoldKey.currentState
          .showSnackBar(SnackBar(content: Text('Hours added!')));

      await _loadData2();
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

    // TODO: Use precise #occurences, f.ex. {1,2}
    // Determine which fields are present in the string.
    RegExp rxfdm = RegExp(r'(\d+(?::\d+)*)\s(\d+(?:\.\d*)*)\s(.+)');
    RegExp rxfd = RegExp(r'(\d+(?::\d+)*)\s(\d+(?:\.\d*)*)');
    RegExp rxdm = RegExp(r'(\d+(?:\.\d*)*)\s(.+)');
    RegExp rxd = RegExp(r'(\d+(?:\.\d*)*)');
    RegExp rxm = RegExp(r'(.+)');

    bool fdm = scanner.matches(rxfdm);
    bool fd = scanner.matches(rxfd);
    bool dm = scanner.matches(rxdm);
    bool d = scanner.matches(rxd);
    bool m = scanner.matches(rxm);

    // Collect the strings from Quick Type.
    if (fdm) {
      scanner.expect(rxfdm);
      from = scanner.lastMatch.group(1);
      duration = scanner.lastMatch.group(2);
      message = scanner.lastMatch.group(3);
    } else if (fd) {
      scanner.expect(rxfd);
      from = scanner.lastMatch.group(1);
      duration = scanner.lastMatch.group(2);
      message = null;
    } else if (dm) {
      scanner.expect(rxdm);
      from = null;
      duration = scanner.lastMatch.group(1);
      message = scanner.lastMatch.group(2);
    } else if (d) {
      scanner.expect(rxd);
      from = null;
      duration = scanner.lastMatch.group(1);
      message = null;
    } else if (m) {
      scanner.expect(rxm);
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
        subtitle: TextFormField(
            initialValue: model.comment ?? '',
            readOnly: true,
            decoration: InputDecoration(border: InputBorder.none)),
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

    var weeklySummaryButton = ElevatedButton.icon(
        onPressed: _showWeeklySummary,
        icon: Icon(Icons.assignment_outlined),
        label: Text('Summary'));

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: FutureBuilder<String>(
            future: _signInFuture,
            initialData: '<...>',
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // _userName = snapshot.data;
                return Text(_userName);
              } else {
                return Text('<..no user..>');
              }
            }),
        actions: [
          !_isLoggedIn()
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: RaisedButton(
                      onPressed: () {
                        _signin();
                      },
                      child: Text('Sign in')),
                )
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: RaisedButton(
                      onPressed: () async {
                        await firebaseAuth.signOut();
                        setState(() {
                          _userName = '<...>';
                          _list.clear();
                          _wbsList.clear();
                          _wbsList = [];
                        });
                      },
                      child: Text('Sign out')),
                ),
          SizedBox(
            width: 8,
          ),
          Checkbox(value: kDebugMode, onChanged: null),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(child: Text('Debug')),
          ),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildDateField3(),
                                // Expanded(child: buildAccountNameField()),
                                Expanded(child: buildAccountName2()),
                              ],
                            ),
                            buildQuickInputField(),
                            IntrinsicHeight(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  fromField,
                                  durationField,
                                  toField,
                                  Spacer(),
                                  SizedBox(
                                    width: 200,
                                    child: Container(
                                      padding:
                                          EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      height: double.infinity,
                                      child: weeklySummaryButton,
                                    ),
                                  ),
                                ],
                              ),
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
                child: FutureBuilder<bool>(
                  future: _loadDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return GestureDetector(
                        excludeFromSemantics: true,
                        behavior: HitTestBehavior.opaque,
                        onSecondaryTap: () => print('tapped'),
                        child: ListView.builder(
                          itemBuilder: (context, index) =>
                              buildListTile(_list[index]),
                          itemCount: _list.length,
                        ),
                      );
                    } else {
                      return Text('tommelomt');
                    }
                  },
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
      padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
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
      padding: EdgeInsets.all(8),
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
      padding: EdgeInsets.all(8),
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

    return Padding(
      // width: 150,
      padding: EdgeInsets.all(8),
      child: TextFormField(
        onSaved: (s) => _accountName = s,
        initialValue: null,
        controller: _accountNameController,
        focusNode: _accountNameFocusNode,
        decoration: decoration,
      ),
    );
  }

  // ignore: unused_element
  DropdownButtonFormField<String> _buildDropdownFormField(
      List<String> accounts) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
          border: OutlineInputBorder(), labelText: 'Account List'),
      value: _accountName,
      icon: Icon(Icons.arrow_downward),
      iconSize: 24,
      elevation: 16,
      style: TextStyle(color: Colors.deepPurple),
      onChanged: (String newValue) {
        setState(() {
          _accountName = newValue;
          _accountNameController.text = newValue;
          _onLoad();
        });
      },
      items: accounts.map<DropdownMenuItem<String>>((String value) {
        print('item = $value');
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }

  List<String> _getAccountList(String query, List<String> accounts) {
    List<String> matches = List();
    matches.addAll(accounts);
    matches.retainWhere((s) => s.toLowerCase().contains(query.toLowerCase()));
    return matches;
  }

  TypeAheadField _buildTypeAheadField(List<String> items) {
    var autofocus = true;

    return TypeAheadField(
        textFieldConfiguration: TextFieldConfiguration(
          decoration: InputDecoration(
            hintText: 'Haavind',
            border: OutlineInputBorder(),
            helperText: 'Text label',
            icon: Icon(Icons.account_balance),
            labelText: 'Account Name',
          ),
          onSubmitted: (s) {
            _accountName = s;
            _accountNameController.text = s;
          },
          controller: _accountNameController,
          focusNode: _accountNameFocusNode,
        ),
        getImmediateSuggestions: true,
        suggestionsBoxVerticalOffset: -20,
        suggestionsCallback: (pattern) {
          return _getAccountList(pattern, items);
        },
        transitionBuilder: (context, suggestionsBox, controller) {
          return suggestionsBox;
        },
        itemBuilder: (context, suggestion) {
          var tile = ListTile(
            title: Focus(
                autofocus: autofocus,
                child: Builder(builder: (context) {
                  return Container(
                      color: Focus.of(context).hasPrimaryFocus
                          ? Colors.black12
                          : null,
                      child: Text(suggestion));
                })),
          );
          autofocus = false;
          return tile;
        },
        onSuggestionSelected: (suggestion) {
          setState(() {
            _accountName = suggestion;
            _accountNameController.text = suggestion;
            _onLoad();
          });
        });
  }

  Widget buildAccountName2() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: FutureBuilder<List<String>>(
        future: _loadAccountsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return _buildTypeAheadField(snapshot.data);
          } else {
            return Text('loading ...');
          }
        },
      ),
    );
  }

  Widget buildQuickInputField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: buildTextField2(
          Icons.format_quote,
          null,
          '[from] [duration] [message]',
          'Quick Input',
          (s) {},
          _parseQuickType,
          null,
          null),
    );
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
      padding: EdgeInsets.all(8),
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

  void _showWeeklySummary() {
    showDialog(
      context: context,
      builder: (context) {
        var weeksHistory = 14;
        var now = DateTime.now();

        var lastTwoWeeksSummaries = <int, WeeklySummary>{};
        for (var i = 0; i < weeksHistory; i++) {
          int thisWeek = weekNumber(now.subtract(Duration(days: 7 * i)));
          lastTwoWeeksSummaries[thisWeek] = WeeklySummary();
        }

        // Iterate through all time entries and add it to the respective weekly summary
        _list.forEach((e) {
          int week = weekNumber(e.date);

          // Summaries only for the last two weeks.
          if (lastTwoWeeksSummaries.containsKey(week)) {
            lastTwoWeeksSummaries[week].add(e);
          }
        });

        // Convert weekly summaries to a list of SelectableText

        var entries = lastTwoWeeksSummaries.entries
            .map<Card>((MapEntry<int, WeeklySummary> e) {
          var hours = e.value.hours.inMinutes.toDouble() / 60;

          final text = 'Uke ${e.key}: ${e.value.comments.join('. ')}';
          final selectableText = SelectableText(text);

          print(selectableText.data);

          var t = Card(
              elevation: 2,
              child: ListTile(
                leading: IconButton(
                    icon: Icon(Icons.copy_outlined),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: text))),
                title: selectableText,
                trailing: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      color: Colors.purple),
                  child: Text(
                    '${hours.toStringAsFixed(1)}',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ));
          return t;
        }).toList();

        return SimpleDialog(
          contentPadding: EdgeInsets.all(8),
          title: Text('Three weeks\' summary'),
          children: entries,
        );
      },
    );
  }
}

class StateService {
  static final List<String> states = [
    'ANDAMAN AND NICOBAR ISLANDS',
    'ANDHRA PRADESH',
    'ARUNACHAL PRADESH',
    'ASSAM',
    'BIHAR',
    'CHATTISGARH',
    'CHANDIGARH',
    'DAMAN AND DIU',
    'DELHI',
    'DADRA AND NAGAR HAVELI',
    'GOA',
    'GUJARAT',
    'HIMACHAL PRADESH',
    'HARYANA',
    'JAMMU AND KASHMIR',
    'JHARKHAND',
    'KERALA',
    'KARNATAKA',
    'LAKSHADWEEP',
    'MEGHALAYA',
    'MAHARASHTRA',
    'MANIPUR',
    'MADHYA PRADESH',
    'MIZORAM',
    'NAGALAND',
    'ORISSA',
    'PUNJAB',
    'PONDICHERRY',
    'RAJASTHAN',
    'SIKKIM',
    'TAMIL NADU',
    'TRIPURA',
    'UTTARAKHAND',
    'UTTAR PRADESH',
    'WEST BENGAL',
    'TELANGANA',
    'LADAKH'
  ];

  static List<String> getSuggestions(String query) {
    List<String> matches = List();
    matches.addAll(states);
    matches.retainWhere((s) => s.toLowerCase().contains(query.toLowerCase()));
    return matches;
  }
}
