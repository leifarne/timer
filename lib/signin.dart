import 'package:firebase_auth/firebase_auth.dart';

class TimeUser {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  User? user;

  TimeUser() {
    // Register auth state listener.
    _firebaseAuth.authStateChanges().listen((User? user) {
      if (user == null) {
        print('User is currently signed out!');
      } else {
        print('User is signed in!');
      }
      this.user = user;
    });
  }

  String? get email => user?.email;
  bool get isLoggedIn => user != null;

  static Future<UserCredential> _signInWithGoogle() async {
    // Create a new provider
    GoogleAuthProvider googleProvider = GoogleAuthProvider();

    googleProvider.addScope('https://www.googleapis.com/auth/contacts.readonly');
    googleProvider.setCustomParameters({'login_hint': 'leif.arne.rones@gmail.com'});

    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithPopup(googleProvider);
  }

  static Future<TimeUser?> signinFuture() async {
    var timeUser = TimeUser();

    var u = timeUser._firebaseAuth.currentUser;

    print('current = ${u?.email}');

    // Not logged in? then log in.
    if (u == null) {
      final UserCredential userCredential = await _signInWithGoogle();
      u = userCredential.user;
    }

    timeUser.user = u;

    // sorry...
    if (u == null) {
      return null;
    }

    // Successful login.
    print(u.email);

    return timeUser;
  }

  Future<bool> signin() async {
    user = _firebaseAuth.currentUser;

    print('current = ${user?.email}');

    // Not logged in? then log in.
    if (user == null) {
      final UserCredential userCredential = await _signInWithGoogle();

      user = userCredential.user;
    }

    // sorry...
    if (user == null) {
      return false;
    }

    // Successful login.
    print(user!.email);

    return true;
  }

  Future<void> signout() async {
    await _firebaseAuth.signOut();
  }
}
