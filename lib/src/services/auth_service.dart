import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService;

  AuthService(this._firestoreService);

  // Stream theo dõi trạng thái đăng nhập
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Đăng ký tài khoản
  Future<UserCredential> signUp(String email, String password, {String? fullName}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user != null) {
      if (fullName != null && fullName.isNotEmpty) {
        await credential.user!.updateDisplayName(fullName);
      }
      await _firestoreService.saveUser(credential.user!, name: fullName);
    }
    return credential;
  }

  // Đăng nhập
  Future<UserCredential> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user != null) {
      await _firestoreService.saveUser(credential.user!);
    }
    return credential;
  }

  // Đăng nhập bằng Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
      final GoogleSignInAccount expectedGoogleUser = await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = expectedGoogleUser.authentication;
      final GoogleSignInClientAuthorization? authClient = await expectedGoogleUser.authorizationClient.authorizationForScopes([]);

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authClient?.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        String? fullName = expectedGoogleUser.displayName;
        await _firestoreService.saveUser(userCredential.user!, name: fullName);
      }
      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // Người dùng huỷ đăng nhập
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // Đăng nhập bằng Apple
  Future<UserCredential?> signInWithApple() async {
    try {
      final AuthorizationCredentialAppleID appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        String? fullName;
        if (appleCredential.givenName != null || appleCredential.familyName != null) {
          fullName = '${appleCredential.familyName ?? ''} ${appleCredential.givenName ?? ''}'.trim();
        }
        await _firestoreService.saveUser(userCredential.user!, name: fullName);
      }
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Lấy User hiện tại
  User? get currentUser => _auth.currentUser;
}

// Provider truy cập AuthService
final authServiceProvider = Provider((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return AuthService(firestoreService);
});

// Provider theo dõi trạng thái User
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
