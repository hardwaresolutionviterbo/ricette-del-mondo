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
  @override State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool loginMode = true;
  bool accepted = false;
  bool obscure = true;
  bool busy = false;
  String? errorMessage;
  final email = TextEditingController();
  final password = TextEditingController();
  final displayName = TextEditingController();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get db => FirebaseFirestore.instance;

  @override
  void dispose(){email.dispose();password.dispose();displayName.dispose();super.dispose();}

  Future<void> _saveProfile(User user) async {
    final name = displayName.text.trim().isEmpty
        ? (user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'Utente')
        : displayName.text.trim();
    if (user.displayName != name && name.isNotEmpty) {
      await user.updateDisplayName(name);
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
    setState(() { busy = true; errorMessage = null; });
    try {
      if (loginMode) {
        await auth.signInWithEmailAndPassword(email: email.text.trim(), password: password.text);
      } else {
        final cred = await auth.createUserWithEmailAndPassword(email: email.text.trim(), password: password.text);
        await _saveProfile(cred.user!);
        await cred.user!.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account creato. Controlla la tua email per confermare la registrazione.')));
        }
      }
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(() { errorMessage = _authError(e.code); });
    } catch (_) {
      setState(() { errorMessage = 'Non è stato possibile completare l’operazione. Riprova.'; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _googleAuth() async {
    if (busy) return;
    setState(() { busy = true; errorMessage = null; });
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize();
      final googleUser = await signIn.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final result = await auth.signInWithCredential(credential);
      if (result.user != null) await _saveProfile(result.user!);
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(() { errorMessage = _authError(e.code); });
    } catch (_) {
      setState(() { errorMessage = 'Accesso Google non completato. Controlla la configurazione Google e riprova.'; });
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ti abbiamo inviato le istruzioni per reimpostare la password.')));
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = _authError(e.code));
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
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor: accountCream,
    appBar: AppBar(backgroundColor: accountCream,title:const Text('Il mio account',style:TextStyle(fontWeight:FontWeight.w900))),
    body: ListView(padding:const EdgeInsets.fromLTRB(16,8,16,32),children:[
      Container(padding:const EdgeInsets.fromLTRB(22,24,22,24),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[accountGreen,Color(0xFF0C7A4B)]),borderRadius:BorderRadius.circular(28)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.account_circle_rounded,color:Colors.white,size:48),SizedBox(height:10),Text('Il tuo spazio personale',style:TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)),SizedBox(height:6),Text('Sincronizza dati dell’account, preferiti, lista della spesa e Premium.\nLa foto del profilo resta solo sul tuo dispositivo.',style:TextStyle(color:Colors.white70,fontSize:14,height:1.45))])),
      const SizedBox(height:16),
      Row(children:[Expanded(child:ChoiceChip(label:const Text('Accedi'),selected:loginMode,onSelected:(_)=>setState((){loginMode=true;errorMessage=null;}))),const SizedBox(width:8),Expanded(child:ChoiceChip(label:const Text('Registrati'),selected:!loginMode,onSelected:(_)=>setState((){loginMode=false;errorMessage=null;})))]),
      const SizedBox(height:14),
      if(!loginMode)TextField(controller:displayName,decoration:const InputDecoration(labelText:'Nome o nome utente',prefixIcon:Icon(Icons.person_outline_rounded))),
      if(!loginMode)const SizedBox(height:10),
      TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',prefixIcon:Icon(Icons.email_outlined))),
      const SizedBox(height:10),
      TextField(controller:password,obscureText:obscure,decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline_rounded),suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility_outlined:Icons.visibility_off_outlined)))),
      if(loginMode)Align(alignment:Alignment.centerRight,child:TextButton(onPressed:_resetPassword,child:const Text('Password dimenticata?'))),
      if(!loginMode)CheckboxListTile(value:accepted,onChanged:(v)=>setState(()=>accepted=v??false),contentPadding:EdgeInsets.zero,title:const Text('Accetto Privacy Policy e Termini e Condizioni',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600)),subtitle:const Text('Puoi modificare le tue preferenze privacy in qualsiasi momento.')),
      if(errorMessage!=null)Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.red.withValues(alpha: .07),borderRadius:BorderRadius.circular(14)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.error_outline,color:Colors.redAccent),const SizedBox(width:8),Expanded(child:Text(errorMessage!,style:const TextStyle(fontWeight:FontWeight.w600,color:Colors.redAccent)))])),
      const SizedBox(height:4),
      SizedBox(width:double.infinity,child:FilledButton(onPressed:(busy||(!loginMode&&!accepted))?null:_emailAuth,style:FilledButton.styleFrom(backgroundColor:accountGreen,minimumSize:const Size.fromHeight(52),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17))),child:busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):Text(loginMode?'Accedi':'Crea account',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)))),
      const SizedBox(height:12),
      Row(children:[const Expanded(child:Divider()),Padding(padding:const EdgeInsets.symmetric(horizontal:10),child:Text('oppure',style:TextStyle(color:Colors.black54))),const Expanded(child:Divider())]),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:busy?null:_googleAuth,icon:const Icon(Icons.g_mobiledata_rounded,size:28),label:const Text('Continua con Google',style:TextStyle(fontWeight:FontWeight.w800)),style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(52),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17)))),
      const SizedBox(height:18),
      Card(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Con il tuo account potrai',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:accountInk)),const SizedBox(height:10),...['sincronizzare preferiti e lista della spesa','recuperare il profilo cambiando telefono','gestire Premium e relativa scadenza','richiedere copia o cancellazione dei dati'].map((x)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Row(children:[const Icon(Icons.check_circle,color:accountGreen,size:19),const SizedBox(width:8),Expanded(child:Text(x,style:const TextStyle(fontWeight:FontWeight.w600)))])))]))),
      const SizedBox(height:12),
      TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PrivacyPolicyPage())),child:const Text('Privacy Policy e Termini e Condizioni')),
    ]),
  );
}
