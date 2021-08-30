// TODO: show unauth domain in snack bar as error message - handle exception

// ignore: todo
// TODO: Sign out properly

// TODO: remove global var _userName
// TODO:
// TODO: Use Provider for sign in.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timer/from_to_widget.dart';
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
    return MaterialApp(
      title: 'Nordheim Digital v${cfg.version}',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Timelister for $_userName'),
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
    // _signInFuture = signin();
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

    return FutureProvider<User?>(
        create: (_) => signin(),
        lazy: false,
        catchError: (context, error) {
          print('Login error $error');
          return null;
        },
        initialData: null,
        builder: (context, _) {
          void onSignin() {
            signin();
          }

          void onSignOut() async {
            await firebaseAuth.signOut();
            setState(() {
              Provider.of<TimeEntryList>(context, listen: false).clear();
              _userName = '<...>';
            });
          }

          var userModel = context.watch<User?>();

          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: Text(userModel?.email ?? '<..no user..>'),
              // if (!_accountsLoaded) {
              //   var model = Provider.of<TimeEntryList>(context, listen: false);
              //   model.loadAccounts();
              //   model.loadAll(cfg.defaultAccountName);
              //   _accountsLoaded = true;
              // }
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: isLoggedIn() ? onSignOut : onSignin,
                    child: Text(isLoggedIn() ? 'Sign outx' : 'Sign in'),
                  ),
                ),
                SizedBox(width: 8),
                Checkbox(value: kDebugMode, onChanged: null),
                Center(child: Text('Debug')),
                SizedBox(width: 8),
              ],
            ),
            body: ChangeNotifierProvider<TimeEntryList>(
              create: (_) {
                var model = TimeEntryList(cfg.defaultAccountName);
                model.loadAccounts();
                model.loadAll(cfg.defaultAccountName);
                return model;
              },
              builder: (context, _) {
                // Save form. Validate and Save all form fields, they are saved in _timeEntry object.
                // Then save to firestore.
                //
                void onSaveForm() async {
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

                // Helper called when Enter pressed in a focused field.
                //
                bool handleKeyPress(FocusNode node, RawKeyEvent event) {
                  print(event.logicalKey);
                  if (isLoggedIn() && event.character == LogicalKeyboardKey.enter.keyLabel) {
                    onSaveForm();
                    return true;
                  }
                  return false;
                }

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Card(
                          elevation: 4,
                          child: Form(
                            key: _formkey,
                            onChanged: () {
                              print('from changed');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: FocusScope(
                                onKey: handleKeyPress,
                                onFocusChange: _onFocusChange,
                                child: Container(
                                  width: double.infinity,
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: _buildDateField(_timeEntry.date),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: _buildTypeAheadField(_timeEntry.accountName, Provider.of<TimeEntryList>(context)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(width: double.infinity, padding: EdgeInsets.only(right: 8), child: buildQuickInputField()),
                                      SizedBox(height: 16),
                                      IntrinsicHeight(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            FromFormField(
                                              initialValue: TimeDuration(_timeEntry.from, _timeEntry.duration),
                                              onSaved: (v) {
                                                _timeEntry.from = v?.from;
                                                _timeEntry.duration = v?.duration;
                                              },
                                            ),
                                            Spacer(),
                                            Container(
                                              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                              height: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: () => showWeeklySummary(context, cfg.history),
                                                icon: Icon(Icons.assignment_outlined),
                                                label: Text('Summary'),
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
                );
              },
            ),
          );
        });
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
    return QuickEntry(
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
    );
  }
}
