import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';

final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
// final GoogleSignIn googleSignIn = GoogleSignIn();

// Is logged in
bool isLoggedIn() {
  return firebaseAuth.currentUser != null;
}

Future<UserCredential> _signInWithGoogle() async {
  // Create a new provider
  GoogleAuthProvider googleProvider = GoogleAuthProvider();

  googleProvider.addScope('https://www.googleapis.com/auth/contacts.readonly');
  googleProvider.setCustomParameters({'login_hint': 'leif.arne.rones@gmail.com'});

  // Once signed in, return the UserCredential
  return await FirebaseAuth.instance.signInWithPopup(googleProvider);

  // Or use signInWithRedirect
  // return await FirebaseAuth.instance.signInWithRedirect(googleProvider);
}

// Future<UserCredential> _signInWithCredential() async {
//   final GoogleSignInAccount googleSignInAccount = await googleSignIn.signIn();
//   final GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount.authentication;

//   final AuthCredential credential = GoogleAuthProvider.credential(
//     accessToken: googleSignInAuthentication.accessToken,
//     idToken: googleSignInAuthentication.idToken,
//   );

//   final UserCredential userCredential = await firebaseAuth.signInWithCredential(credential);

//   return userCredential;
// }

Future<User?> signin() async {
  User? user = firebaseAuth.currentUser;

  print('current = ${user?.email}');

  // Not logged in? then log in.
  if (user == null) {
    final UserCredential userCredential = await _signInWithGoogle();

    user = userCredential.user;
  }

  // sorry...
  if (user == null) {
    return null;
  }

  // Successful login.
  print(user.email!);

  // ... and inside here: initiate loading of the data, as well
  // _loadAccountsFuture = _loadAccountList2();

  return user;
}
