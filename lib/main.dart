// TODO: show unauth domain in snack bar as error message - handle exception
// TODO: Use Provider for sign in
// TODO: Refactor into compbined Widgets

// ignore: todo
// TODO: Sign out properly
// ignore: todo
// TODO: remove global var _userName

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config.dart' as cfg;
import 'input_widgets.dart';
import 'model.dart';
import 'parse.dart';
import 'signin.dart';
import 'weektile.dart';

String _userName = '...';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TimeEntryList(cfg.defaultAccountName),
      child: MaterialApp(
        title: 'Nordheim Digital v${cfg.version}',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: MyHomePage(title: 'Timelister for $_userName'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

// Helper class for the UI, keeping temporary values during input
//
class TimeEntryEdit {
  DateTime? date;
  String? accountName;
  DateTime? from;
  Duration? duration;
  String? comment;

  DateTime? get to => (duration != null) ? from?.add(duration!) : null;

  TimeEntryEdit(this.date, this.accountName, this.from, this.duration, {this.comment});

  TimeEntry toEntry() {
    return TimeEntry(date!, accountName!, from!, duration!, comment: comment);
  }
}

class _MyHomePageState extends State<MyHomePage> {
  var _formkey = GlobalKey<FormState>();
  var _scaffoldKey = GlobalKey<ScaffoldState>();

  late TimeEntryEdit _timeEntry;
  // late QuickEntryModel _quickEntryModel;

  Future<User?>? _signInFuture;
  bool _accountsLoaded = false;

  // Helper called when Enter pressed in a focused field.
  //
  bool _handleKeyPress(FocusNode node, RawKeyEvent event) {
    print(event.logicalKey);
    if (isLoggedIn() && event.character == LogicalKeyboardKey.enter.keyLabel) {
      _onSaveForm();
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();

    initializeFlutterFire();

    // Assign defaults to UI model
    final now = DateTime.now();
    _timeEntry = TimeEntryEdit(
      now,
      cfg.defaultAccountName,
      DateTime(now.year, now.month, now.day, now.hour),
      Duration(hours: 1),
    );

    // _quickEntryModel = QuickEntryModel(from: _timeEntry.from, duration: _timeEntry.duration);

    // Kick off the sign in process to Google and Firebase with a Future.
    _signInFuture = signin();
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool ffInitialized = false;
  bool ffError = false;

// Define an async function to initialize FlutterFire
  void initializeFlutterFire() async {
    try {
      // Wait for Firebase to initialize and set `_initialized` state to true
      await Firebase.initializeApp();
      setState(() {
        ffInitialized = true;
      });
    } catch (e) {
      // Set `_error` state to true if Firebase initialization fails
      setState(() {
        ffError = true;
      });
    }
  }

  // Save form. Validate and Save all form fields, they are saved in _timeEntry object.
  // Then save to firestore.
  //
  void _onSaveForm() async {
    if (_formkey.currentState!.validate()) {
      _formkey.currentState!.save(); // The Model is updated in _timeEntry.

      final model = Provider.of<TimeEntryList>(context, listen: false);

      model.addTimeEntry(_timeEntry.toEntry());

      if (_timeEntry.accountName != model.account) {
        // If we are changing the account or creating a new one, add new account, and load new list.
        model.addAccount(_timeEntry.accountName!);
        model.loadAll(_timeEntry.accountName!);
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hours added!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ffError) {
      print('Wrong');
      return Text('Wrong');
    }

    // Show a loader until FlutterFire is initialized
    if (!ffInitialized) {
      print('Loading...');
      return Text('Loading...');
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: FutureBuilder<User?>(
            future: _signInFuture,
            initialData: null,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                if (!_accountsLoaded) {
                  var model = Provider.of<TimeEntryList>(context, listen: false);
                  model.loadAccounts();
                  model.loadAll(cfg.defaultAccountName);
                  _accountsLoaded = true;
                }
                final userName = snapshot.data!.email!;
                return Text(userName);
              } else {
                return Text('<..no user..>');
              }
            }),
        actions: [
          !isLoggedIn()
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                      onPressed: () {
                        signin();
                      },
                      child: Text('Sign in')),
                )
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                      onPressed: () async {
                        await firebaseAuth.signOut();
                        setState(() {
                          Provider.of<TimeEntryList>(context, listen: false).clear();
                          _userName = '<...>';
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
        child: OverflowBox(
          maxWidth: 700,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Card(
                  elevation: 4,
                  child: Form(
                    key: _formkey,
                    onChanged: () {},
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
                                  _buildDateField(_timeEntry.date),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: _buildTypeAheadField(_timeEntry.accountName, Provider.of<TimeEntryList>(context)),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: double.infinity, child: buildQuickInputField()),
                              IntrinsicHeight(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildFromField(),
                                    _buildDurationField(),
                                    _buildToField(),
                                    Spacer(),
                                    SizedBox(
                                      width: 200,
                                      child: Container(
                                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        height: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => showWeeklySummary(context, cfg.history),
                                          icon: Icon(Icons.assignment_outlined),
                                          label: Text('Summary'),
                                        ),
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
                  ),
                ),
                Expanded(
                  child: () {
                    List<TimeEntry> model = Provider.of<TimeEntryList>(context).entries;
                    return Card(
                      elevation: 4,
                      child: GestureDetector(
                        excludeFromSemantics: true,
                        behavior: HitTestBehavior.opaque,
                        onSecondaryTap: () => print('tapped'),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(0),
                          itemBuilder: (context, index) => WeekTile(model: model[index]),
                          itemCount: model.length,
                          separatorBuilder: (_, __) => const Divider(indent: 10, endIndent: 10, height: 2),
                        ),
                      ),
                    );
                  }(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Field builder helper.
  //
  Widget _buildToField() {
    return TextWidget(
      initialValue: formatTime(_timeEntry.to),
      iconData: Icons.access_time,
      labelText: 'To',
      helperText: '',
      readOnly: true,
    );
  }

  // Field builder helper.
  //
  Widget _buildDateField(DateTime? date) {
    void onSaved(String? v) {
      _timeEntry.date = parseDate(v);
    }

    String? validator(String? v) => isDate(v) ? null : "Not in dd.mm format";

    return TextWidget(
      initialValue: (date != null) ? dateFormat.format(date) : '',
      hintText: '12.04',
      iconData: Icons.calendar_today,
      helperText: 'dd[.MM]',
      labelText: 'Date',
      onSaved: onSaved,
      validator: validator,
    );
  }

  // Field builder helper.
  //
  Widget _buildFromField() {
    void onChanged(String v) {
      if (isTime(v)) {
        _timeEntry.from = parseTime(v);
        // setState(() {});
      }
    }

    void onSaved(String? v) {
      // _quickEntryModel.from ??= parseTime(v);
      _timeEntry.from ??= parseTime(v);
    }

    String? validator(String? v) => isTime(v) ? null : "Not in HH:mm or HH time format";

    return TextWidget(
      iconData: Icons.access_time,
      initialValue: formatTime(_timeEntry.from),
      hintText: '13:30',
      helperText: 'hh[:mm]',
      labelText: 'From',
      onChanged: onChanged,
      onSaved: onSaved,
      validator: validator,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')), LengthLimitingTextInputFormatter(5)],
    );
  }

  // Field builder helper.
  //
  Widget _buildDurationField() {
    void onChanged(String v) {
      if (isDuration(v)) {
        _timeEntry.duration = parseDuration(v);
        setState(() {});
      }
    }

    void onSaved(String? v) {
      // _quickEntryModel.duration ??= parseDuration(v);
      _timeEntry.duration ??= parseDuration(v);
    }

    String? validator(String? v) => isDuration(v) ? null : "Not an int";

    String? formatDuration(Duration? duration) {
      if (duration == null) return null;
      double hours = duration.inMinutes / 60.0;
      return hours.toStringAsFixed(1);
    }

    return TextWidget(
      initialValue: formatDuration(_timeEntry.duration),
      iconData: Icons.timelapse,
      hintText: '2',
      helperText: 'h[.h]',
      labelText: 'Duration',
      onChanged: onChanged,
      onSaved: onSaved,
      validator: validator,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(3)],
    );
  }

  // Form focus change
  //
  void _onFocusChange(bool value) {
    print('Focus change');
  }

  // Field builder helper.
  //
  TypeAheadWidget _buildTypeAheadField(String? initialAccount, TimeEntryList timeEntryList) {
    void onSelected(String account) {
      _timeEntry.accountName = account;
      timeEntryList.loadAll(account);
    }

    void onSubmitted(String account) {
      _timeEntry.accountName = account;
    }

    return TypeAheadWidget(initialAccount: initialAccount, timeEntryList: timeEntryList, wbs: timeEntryList.wbs, onSubmitted: onSubmitted, onSelected: onSelected);
  }

  // Field builder helper.
  //
  Widget buildQuickInputField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: QuickEntry(
        iconData: Icons.format_quote,
        helperText: '[from] [duration] [message]',
        labelText: 'Quick Input',
        onChanged: (s) {},
        onSaved: (s) {
          final quickEntryModel = parseQuickType(s);
          _timeEntry.from = quickEntryModel.from;
          _timeEntry.duration = quickEntryModel.duration;
          _timeEntry.comment = quickEntryModel.message;
        },
      ),
    );
  }
}
