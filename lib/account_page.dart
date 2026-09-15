import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'legal_pages.dart';

const accountGreen = Color(0xFF075B3A);
const accountInk = Color(0xFF12324A);
const accountCream = Color(0xFFFFFBF3);

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool loginMode = true;
  bool accepted = false;
  bool obscure = true;
  bool busy = false;
  String? errorMessage;
  String? infoMessage;
  User? currentUser;
  Map<String, dynamic>? profileData;

  final email = TextEditingController();
  final password = TextEditingController();
  final displayName = TextEditingController();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get db => FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    currentUser = auth.currentUser;
    if (currentUser != null) {
      _loadProfile(currentUser!);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    displayName.dispose();
    super.dispose();
  }

  Future<void> _loadProfile(User user) async {
    try {
      await user.reload();
      final refreshed = auth.currentUser;
      if (refreshed == null) {
        if (mounted) setState(() => currentUser = null);
        return;
      }
      final snap = await db.collection('users').doc(refreshed.uid).get();
      if (!mounted) return;
      setState(() {
        currentUser = refreshed;
        profileData = snap.data();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => currentUser = user);
    }
  }

  Future<void> _saveProfile(User user) async {
    final name = displayName.text.trim().isEmpty
        ? (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Utente')
        : displayName.text.trim();

    if (user.displayName != name && name.isNotEmpty) {
      await user.updateDisplayName(name);
      await user.reload();
    }

    await db.collection('users').doc(user.uid).set({
      'displayName': name,
      'email': user.email,
      'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _emailAuth() async {
    if (busy) return;
    setState(() {
      busy = true;
      errorMessage = null;
      infoMessage = null;
    });

    try {
      if (loginMode) {
        final credential = await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
        final user = credential.user;
        if (user == null) throw StateError('Utente non disponibile.');

        await user.reload();
        final refreshed = auth.currentUser;
        if (refreshed == null) throw StateError('Sessione non disponibile.');

        if (!refreshed.emailVerified) {
          await auth.signOut();
          if (mounted) {
            setState(() {
              errorMessage = 'Devi prima confermare il tuo indirizzo email. '
                  'Controlla anche la cartella Spam e poi riprova.';
            });
          }
          return;
        }

        await _loadProfile(refreshed);
        if (mounted) Navigator.of(context).pop();
      } else {
        final cred = await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
        final user = cred.user;
        if (user == null) throw StateError('Account non disponibile.');

        await _saveProfile(user);
        await user.sendEmailVerification();

        // L'utente non viene lasciato autenticato finché l'email non è verificata.
        await auth.signOut();

        if (mounted) {
          setState(() {
            loginMode = true;
            infoMessage = 'Account creato correttamente. Ti abbiamo inviato una '
                'mail di conferma. Controlla anche Spam, conferma l\'indirizzo '
                'e poi accedi con email e password.';
            email.text = email.text.trim();
            password.clear();
            displayName.clear();
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => errorMessage = _authError(e.code));
    } catch (_) {
      if (mounted) {
        setState(() => errorMessage =
            'Non è stato possibile completare l’operazione. Riprova.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _googleAuth() async {
    if (busy) return;
    setState(() {
      busy = true;
      errorMessage = null;
      infoMessage = null;
    });

    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize();
      final googleUser = await signIn.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final result = await auth.signInWithCredential(credential);
      if (result.user != null) {
        await _saveProfile(result.user!);
        await _loadProfile(result.user!);
      }
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => errorMessage = _authError(e.code));
    } catch (_) {
      if (mounted) {
        setState(() => errorMessage =
            'Accesso Google non completato. Controlla la configurazione Google e riprova.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (email.text.trim().isEmpty) {
      setState(() => errorMessage = 'Inserisci prima il tuo indirizzo email.');
      return;
    }
    try {
      await auth.sendPasswordResetEmail(email: email.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ti abbiamo inviato le istruzioni per reimpostare la password.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => errorMessage = _authError(e.code));
    }
  }

  Future<void> _resendVerification() async {
    final user = auth.currentUser;
    if (user == null) return;
    setState(() {
      busy = true;
      errorMessage = null;
      infoMessage = null;
    });
    try {
      await user.sendEmailVerification();
      if (mounted) {
        setState(() => infoMessage =
            'Nuova email di conferma inviata. Controlla anche Spam.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => errorMessage = _authError(e.code));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _refreshVerification() async {
    final user = auth.currentUser;
    if (user == null) return;
    setState(() {
      busy = true;
      errorMessage = null;
      infoMessage = null;
    });
    try {
      await user.reload();
      final refreshed = auth.currentUser;
      if (refreshed == null) {
        if (mounted) setState(() => currentUser = null);
        return;
      }
      if (refreshed.emailVerified) {
        await _loadProfile(refreshed);
        if (mounted) {
          setState(() => infoMessage = 'Email confermata. Account attivo.');
        }
      } else if (mounted) {
        setState(() => errorMessage =
            'La conferma non risulta ancora completata. Apri il link ricevuto e riprova.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => errorMessage = 'Impossibile aggiornare lo stato dell’account.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() {
      busy = true;
      errorMessage = null;
      infoMessage = null;
    });
    try {
      await auth.signOut();
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      if (mounted) {
        setState(() {
          currentUser = null;
          profileData = null;
          loginMode = true;
          password.clear();
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _authError(String code) => switch (code) {
        'invalid-email' => 'L’indirizzo email non è valido.',
        'user-not-found' => 'Non esiste un account con questa email.',
        'wrong-password' || 'invalid-credential' => 'Email o password non corrette.',
        'email-already-in-use' => 'Questa email è già associata a un account.',
        'weak-password' => 'La password deve essere più sicura.',
        'network-request-failed' => 'Controlla la connessione Internet.',
        'too-many-requests' => 'Troppi tentativi. Riprova più tardi.',
        _ => 'Operazione non riuscita. Riprova.'
      };

  @override
  Widget build(BuildContext context) {
    final user = currentUser ?? auth.currentUser;
    return Scaffold(
      backgroundColor: accountCream,
      appBar: AppBar(
        backgroundColor: accountCream,
        title: const Text(
          'Il mio account',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: user != null ? _loggedInView(user) : _authView(),
    );
  }

  Widget _loggedInView(User user) {
    final name = (profileData?['displayName'] as String?)?.trim();
    final shownName = name?.isNotEmpty == true
        ? name!
        : (user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Utente');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accountGreen, Color(0xFF0C7A4B)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text(
                'Ciao, $shownName!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                user.email ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      user.emailVerified
                          ? Icons.mark_email_read_rounded
                          : Icons.mark_email_unread_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      user.emailVerified ? 'Email verificata' : 'Email non verificata',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (infoMessage != null) _messageCard(infoMessage!, false),
        if (errorMessage != null) _messageCard(errorMessage!, true),
        if (!user.emailVerified) ...[
          Card(
            elevation: 0,
            color: const Color(0xFFFFF3D6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conferma il tuo indirizzo email',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: accountInk,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Apri il link nella mail ricevuta. Se non la trovi, controlla Spam e Posta indesiderata.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : _refreshVerification,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Ho confermato'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _resendVerification,
                        icon: const Icon(Icons.email_outlined),
                        label: const Text('Invia di nuovo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline_rounded,
                    color: accountGreen),
                title: const Text('Nome utente',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(shownName),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.email_outlined,
                    color: accountGreen),
                title: const Text('Email',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(user.email ?? '—'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: busy ? null : _logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Esci dall’account'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
        ),
      ],
    );
  }

  Widget _authView() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accountGreen, Color(0xFF0C7A4B)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.account_circle_rounded,
                    color: Colors.white, size: 48),
                SizedBox(height: 10),
                Text(
                  'Il tuo spazio personale',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Accedi per sincronizzare il tuo account, i preferiti, la lista della spesa e Premium.',
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Accedi'),
                  selected: loginMode,
                  onSelected: (_) => setState(() {
                    loginMode = true;
                    errorMessage = null;
                    infoMessage = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Registrati'),
                  selected: !loginMode,
                  onSelected: (_) => setState(() {
                    loginMode = false;
                    errorMessage = null;
                    infoMessage = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!loginMode)
            TextField(
              controller: displayName,
              decoration: const InputDecoration(
                labelText: 'Nome o nome utente',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
          if (!loginMode) const SizedBox(height: 10),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: password,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
              ),
            ),
          ),
          if (loginMode)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetPassword,
                child: const Text('Password dimenticata?'),
              ),
            ),
          if (!loginMode)
            CheckboxListTile(
              value: accepted,
              onChanged: (v) => setState(() => accepted = v ?? false),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Accetto Privacy Policy e Termini e Condizioni',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Puoi modificare le tue preferenze privacy in qualsiasi momento.',
              ),
            ),
          if (infoMessage != null) _messageCard(infoMessage!, false),
          if (errorMessage != null) _messageCard(errorMessage!, true),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (busy || (!loginMode && !accepted)) ? null : _emailAuth,
              style: FilledButton.styleFrom(
                backgroundColor: accountGreen,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      loginMode ? 'Accedi' : 'Crea account',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Divider()),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('oppure', style: TextStyle(color: Colors.black54)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : _googleAuth,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
            label: const Text(
              'Continua con Google',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Con il tuo account potrai',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: accountInk,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...[
                    'sincronizzare preferiti e lista della spesa',
                    'recuperare il profilo cambiando telefono',
                    'gestire Premium e relativa scadenza',
                    'richiedere copia o cancellazione dei dati',
                  ].map(
                    (x) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: accountGreen, size: 19),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(x,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
            ),
            child: const Text('Privacy Policy e Termini e Condizioni'),
          ),
        ],
      );

  Widget _messageCard(String message, bool error) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (error ? Colors.redAccent : accountGreen)
              .withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: error ? Colors.redAccent : accountGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: error ? Colors.redAccent : accountGreen,
                ),
              ),
            ),
          ],
        ),
      );
}
