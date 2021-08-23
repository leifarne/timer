import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:timer/model.dart';

class QuickEntry extends StatelessWidget {
  const QuickEntry({
    Key? key,
    required this.iconData,
    this.initialValue,
    required this.helperText,
    required this.labelText,
    required this.onChanged,
    required this.onSaved,
    this.inputFormatters,
  }) : super(key: key);

  final IconData iconData;
  final String? initialValue;
  final String helperText;
  final String labelText;
  final void Function(String p1) onChanged;
  final void Function(String? p1) onSaved;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextWidget(
      hintText: '13 3 Meeting on strategy',
      iconData: iconData,
      initialValue: initialValue,
      helperText: '([from] duration [descr.]) ! [descr.]',
      labelText: labelText,
      onChanged: onChanged,
      onSaved: onSaved,
    );
  }
}

class TextWidget extends StatefulWidget {
  const TextWidget({
    Key? key,
    this.width,
    required this.iconData,
    this.initialValue,
    this.helperText,
    required this.labelText,
    this.onChanged,
    this.onSaved,
    this.validator,
    this.inputFormatters,
    this.hintText,
    this.readOnly = false,
  }) : super(key: key);

  final double? width;
  final IconData iconData;
  final String? initialValue;
  final String? helperText;
  final String labelText;
  final String? hintText;
  final void Function(String p1)? onChanged;
  final void Function(String? p1)? onSaved;
  final String? Function(String? p1)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;

  @override
  _TextWidgetState createState() => _TextWidgetState();
}

class _TextWidgetState extends State<TextWidget> {
  late TextEditingController controller;
  late FocusNode focusNode;

  @override
  void initState() {
    controller = TextEditingController(text: widget.initialValue);
    focusNode = FocusNode();
    if (!widget.readOnly) {
      selectAllOnFocusChange(focusNode, controller);
    }
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      hintText: widget.hintText,
      border: OutlineInputBorder(),
      helperText: widget.helperText,
      icon: Icon(widget.iconData),
      labelText: widget.labelText,
      // suffixText: '(ddmm)',
    );

    return Container(
      width: widget.width ?? 150,
      padding: EdgeInsets.all(8),
      child: TextFormField(
        readOnly: widget.readOnly,
        controller: controller,
        onChanged: widget.onChanged,
        onSaved: widget.onSaved,
        focusNode: focusNode,
        decoration: decoration,
        inputFormatters: widget.inputFormatters,
        validator: widget.validator,
      ),
    );
  }
}

/// helper function
void selectAllOnFocusChange(FocusNode focusNode, TextEditingController controller) {
  focusNode.addListener(() {
    if (focusNode.hasFocus) {
      controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    }
  });
}

class TypeAheadWidget extends StatefulWidget {
  final TimeEntryList timeEntryList;
  final List<String> wbs;
  final void Function(String) onSubmitted;
  final void Function(String) onSelected;
  final String? initialAccount;

  TypeAheadWidget({Key? key, required this.timeEntryList, required this.wbs, required this.onSubmitted, required this.onSelected, required this.initialAccount}) : super(key: key);

  @override
  _TypeAheadWidgetState createState() => _TypeAheadWidgetState();
}

class _TypeAheadWidgetState extends State<TypeAheadWidget> {
  late TextEditingController _accountNameController;
  late FocusNode _accountNameFocusNode;

  List<String> _getAccountList(String query, List<String> accounts) {
    List<String> matches = [];
    matches.addAll(accounts);
    matches.retainWhere((s) => s.toLowerCase().contains(query.toLowerCase()));
    return matches;
  }

  @override
  void initState() {
    _accountNameController = TextEditingController(text: widget.initialAccount);
    _accountNameFocusNode = FocusNode();
    selectAllOnFocusChange(_accountNameFocusNode, _accountNameController);

    super.initState();
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNameFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            // _accountNameController.text = s;
            widget.onSubmitted(s);
          },
          controller: _accountNameController,
          focusNode: _accountNameFocusNode,
        ),
        getImmediateSuggestions: true,
        suggestionsBoxVerticalOffset: -20,
        suggestionsCallback: (pattern) {
          return _getAccountList(pattern, widget.wbs);
        },
        transitionBuilder: (context, suggestionsBox, controller) {
          return suggestionsBox;
        },
        itemBuilder: (context, String suggestion) {
          var tile = ListTile(
            title: Focus(
                autofocus: autofocus,
                child: Builder(builder: (context) {
                  return Container(color: Focus.of(context).hasPrimaryFocus ? Colors.black12 : null, child: Text(suggestion));
                })),
          );
          autofocus = false;
          return tile;
        },
        onSuggestionSelected: (String suggestion) {
          _accountNameController.text = suggestion;
          widget.onSelected(suggestion);
        });
  }
}

  // Widget buildDateField2() {
  //   return buildDateField(null, 'Date', null, (v) => _date = parseDate(v), (v) => isDate(v) ? null : "Not a date", _dateFocusNode);
  // }

  // Widget buildDateField3() {
  //   const decoration = const InputDecoration(
  //     border: OutlineInputBorder(),
  //     helperText: 'dd[.MM]',
  //     icon: Icon(Icons.calendar_today),
  //     labelText: 'Date',
  //     // suffixText: '(ddmm)',
  //   );

  //   return Container(
  //     width: 150,
  //     padding: EdgeInsets.all(8),
  //     child: TextFormField(
  //       controller: _dateController,
  //       onChanged: null,
  //       onSaved: (v) => _date = parseDate(v),
  //       initialValue: null,
  //       focusNode: _dateFocusNode,
  //       decoration: decoration,
  //       inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(5)],
  //       validator: (v) => isDate(v) ? null : "Not a date",
  //     ),
  //   );
  // }

                // child: FutureBuilder<bool>(
                //   future: _loadDataFuture,
                //   builder: (context, snapshot) {
                //     if (snapshot.hasData) {
                //       return GestureDetector(
                //         excludeFromSemantics: true,
                //         behavior: HitTestBehavior.opaque,
                //         onSecondaryTap: () => print('tapped'),
                //         child: ListView.builder(
                //           itemBuilder: (context, index) => WeekTile(model: _list[index]),
                //           itemCount: _list.length,
                //         ),
                //       );
                //     } else {
                //       return Text('tommelomt');
                //     }
                //   },
                // ),

// ignore: unused_element
// DropdownButtonFormField<String> _buildDropdownFormField(List<String> accounts) {
//   return DropdownButtonFormField<String>(
//     decoration: InputDecoration(border: OutlineInputBorder(), labelText: 'Account List'),
//     value: _accountName,
//     icon: Icon(Icons.arrow_downward),
//     iconSize: 24,
//     elevation: 16,
//     style: TextStyle(color: Colors.deepPurple),
//     onChanged: (String newValue) {
//       setState(() {
//         _accountName = newValue;
//         _accountNameController.text = newValue;
//         _onLoad();
//       });
//     },
//     items: accounts.map<DropdownMenuItem<String>>((String value) {
//       print('item = $value');
//       return DropdownMenuItem<String>(
//         value: value,
//         child: Text(value),
//       );
//     }).toList(),
//   );
// }
