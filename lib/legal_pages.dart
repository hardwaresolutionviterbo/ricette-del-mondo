import 'package:flutter/material.dart';

const legalGreen = Color(0xFF075B3A);
const legalInk = Color(0xFF12324A);
const legalCream = Color(0xFFFFFBF3);

class LegalPage extends StatelessWidget {
  final String title;
  final List<Widget> sections;
  const LegalPage({super.key, required this.title, required this.sections});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: legalCream,
    appBar: AppBar(backgroundColor: legalCream, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
    body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 32), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [legalGreen, Color(0xFF0C7A4B)]), borderRadius: BorderRadius.circular(26)), child: const Row(children: [Icon(Icons.verified_user_rounded, color: Colors.white, size: 38), SizedBox(width: 14), Expanded(child: Text('Informazioni importanti e trasparenti per usare Ricette del Mondo in modo consapevole.', style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4, fontWeight: FontWeight.w700)))])),
      const SizedBox(height: 18),
      ...sections,
    ]),
  );
}

Widget legalSection(String title, String text, {IconData icon = Icons.article_outlined}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFEAF4EE), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: legalGreen)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: legalInk)), const SizedBox(height: 7), Text(text, style: const TextStyle(fontSize: 13.5, height: 1.55, color: Colors.black87))]))]))),
);

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});
  @override
  Widget build(BuildContext context) => LegalPage(title: 'Privacy Policy', sections: [
    legalSection('Titolare del trattamento', 'Il titolare del trattamento è Casalini Carlo. Recapito: Porano (TR), 05010, Italia. Per richieste relative alla privacy e ai dati personali è possibile scrivere a hardwaresolutionviterbo@gmail.com.', icon: Icons.person_outline_rounded),
    legalSection('Dati dell’account', 'Quando l’utente crea un account possono essere trattati dati necessari per autenticazione e gestione del profilo, come indirizzo email, nome visualizzato, preferenze, preferiti, lista della spesa e stato del servizio Premium.', icon: Icons.account_circle_outlined),
    legalSection('Accesso con Google', 'Se l’utente sceglie “Continua con Google”, l’autenticazione avviene tramite il servizio di Google. L’app utilizzerà solo le informazioni necessarie alla creazione e gestione dell’account, secondo le autorizzazioni e le impostazioni del servizio.', icon: Icons.login_rounded),
    legalSection('Foto del profilo', 'Se l’utente sceglie di impostare una foto, l’app può richiedere l’accesso alla galleria e conservarla esclusivamente sul dispositivo. La foto profilo non viene caricata su Firebase Storage o su altri server.', icon: Icons.photo_camera_back_outlined),
    legalSection('Preferiti, lista della spesa e preferenze', 'Questi dati possono essere conservati localmente sul dispositivo e, per gli utenti autenticati, sincronizzati online per consentirne il recupero su altri dispositivi.', icon: Icons.sync_rounded),
    legalSection('Pubblicità', 'La versione gratuita può mostrare pubblicità. I servizi pubblicitari possono trattare identificatori tecnici e dati relativi alla pubblicità secondo le loro rispettive informative. L’app distinguerà le preferenze relative alla pubblicità personalizzata. Gli utenti Premium utilizzano l’app senza pubblicità.', icon: Icons.campaign_outlined),
    legalSection('Statistiche e diagnostica', 'L’app può utilizzare strumenti come Firebase Analytics e Firebase Crashlytics per comprendere l’utilizzo in forma aggregata e individuare crash e problemi tecnici. Le preferenze relative alle statistiche saranno gestibili dall’utente.', icon: Icons.analytics_outlined),
    legalSection('Notifiche', 'Le notifiche di servizio sono gestite tramite Firebase Cloud Messaging (FCM). Per consegnare una notifica a uno specifico dispositivo può essere trattato il relativo token tecnico FCM. L’utente può autorizzare o disattivare le notifiche dalle impostazioni dell’app; le comunicazioni promozionali restano separate e richiedono una preferenza distinta.', icon: Icons.notifications_none_rounded),
    legalSection('Fotografie e contenuti di terze parti', 'Le fotografie delle ricette possono essere reperite tramite servizi come Openverse e Wikimedia Commons. Per i contenuti soggetti a licenze che richiedono attribuzione verranno indicati i relativi crediti e le condizioni applicabili.', icon: Icons.photo_library_outlined),
    legalSection('Sicurezza alimentare', 'Le informazioni su allergeni, conservazione e cottura hanno finalità informative e non sostituiscono il controllo delle etichette, le indicazioni del produttore o il parere di un professionista sanitario.', icon: Icons.health_and_safety_outlined),
    legalSection('Diritti dell’utente', 'L’utente può chiedere accesso, rettifica, cancellazione e, nei casi previsti, limitazione o opposizione al trattamento. È inoltre previsto un percorso per richiedere una copia dei propri dati e per eliminare l’account.', icon: Icons.manage_accounts_outlined),
    legalSection('Contatti privacy', 'Per richieste, esercizio dei diritti o chiarimenti: hardwaresolutionviterbo@gmail.com.', icon: Icons.email_outlined),
    legalSection('Aggiornamenti', 'Questa informativa sarà aggiornata quando cambieranno funzioni, servizi o modalità di trattamento. La versione pubblicata sarà mantenuta aggiornata in caso di modifiche ai servizi o alle modalità di trattamento. Prima della pubblicazione definitiva è opportuno far verificare il testo da un professionista.', icon: Icons.update_rounded),
  ]);
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});
  @override
  Widget build(BuildContext context) => LegalPage(title: 'Termini e Condizioni', sections: [
    legalSection('Uso dell’app', 'Ricette del Mondo offre contenuti e strumenti dedicati alla cucina e alla scoperta gastronomica. L’utente si impegna a utilizzare l’app in modo lecito e corretto.', icon: Icons.menu_book_outlined),
    legalSection('Account', 'L’utente è responsabile della correttezza dei dati forniti e della protezione delle proprie credenziali. Le funzioni dell’account possono essere utilizzate per sincronizzare preferiti, lista della spesa e altre preferenze.', icon: Icons.account_circle_outlined),
    legalSection('Ricette e sicurezza', 'Le ricette sono fornite a scopo informativo. Tempi, temperature, ingredienti e indicazioni devono essere verificati in relazione agli alimenti realmente utilizzati e alle esigenze personali.', icon: Icons.restaurant_menu_rounded),
    legalSection('Contenuti e fotografie', 'I contenuti di terze parti restano soggetti alle rispettive licenze. I crediti e le attribuzioni richieste sono disponibili nella sezione Licenze e crediti.', icon: Icons.copyright_outlined),
    legalSection('Funzioni gratuite', 'La versione gratuita rende disponibili 10 ricette alla volta secondo il ciclo previsto dall’app. Le ricette gratuite vengono rinnovate secondo la rotazione stabilita dal servizio e possono essere accompagnate da pubblicità.', icon: Icons.lock_open_outlined),
    legalSection('Premium', 'Premium consente l’accesso alle ricette e alle funzioni previste dal piano acquistato e rimuove la pubblicità. Le condizioni economiche e di rinnovo vengono mostrate prima dell’acquisto.', icon: Icons.workspace_premium_outlined),
    legalSection('Segnalazioni', 'Gli utenti possono segnalare ricette, fotografie, contenuti o malfunzionamenti. Le segnalazioni possono essere esaminate per correggere o rimuovere contenuti non appropriati.', icon: Icons.flag_outlined),
    legalSection('Limitazioni', 'L’app non sostituisce consulenza medica, nutrizionale o professionale. Non viene garantita l’assenza di contaminazioni o allergeni oltre quanto esplicitamente indicato.', icon: Icons.warning_amber_rounded),
  ]);
}

class PremiumTermsPage extends StatelessWidget {
  const PremiumTermsPage({super.key});
  @override
  Widget build(BuildContext context) => LegalPage(title: 'Condizioni Premium', sections: [
    legalSection('Piani disponibili', 'Sono previsti piani con rinnovo automatico e piani una tantum. I prezzi attualmente configurati nell’app sono: rinnovo automatico 1 mese €2,99, 6 mesi €14,99, 12 mesi €24,99; una tantum 1 mese €3,49, 6 mesi €16,99, 12 mesi €29,99.', icon: Icons.euro_rounded),
    legalSection('Rinnovo automatico', 'Per i piani con rinnovo automatico il servizio viene rinnovato secondo il periodo scelto, alle condizioni e al prezzo mostrati al momento dell’acquisto, salvo cancellazione secondo le procedure dello store.', icon: Icons.autorenew_rounded),
    legalSection('Acquisto una tantum', 'I piani una tantum non prevedono rinnovo automatico e terminano alla scadenza del periodo acquistato.', icon: Icons.event_available_rounded),
    legalSection('Accesso Premium', 'Premium consente l’accesso alle ricette previste dal servizio e rimuove la pubblicità. Lo stato dell’abbonamento sarà associato all’account dell’utente quando il sistema di pagamento sarà collegato.', icon: Icons.workspace_premium_rounded),
    legalSection('Pagamento e store', 'Il pagamento reale dovrà essere gestito tramite i sistemi ufficiali di acquisto in-app dello store di distribuzione. Le condizioni definitive, incluse eventuali imposte e regole di rimborso, saranno quelle mostrate dallo store prima della conferma.', icon: Icons.storefront_outlined),
    legalSection('Annullamento e scadenza', 'Per i piani con rinnovo automatico l’utente può gestire o annullare il rinnovo tramite le impostazioni del relativo store. I piani una tantum scadono senza rinnovo automatico.', icon: Icons.cancel_outlined),
  ]);
}

class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});
  @override
  Widget build(BuildContext context) => LegalPage(title: 'Licenze e crediti', sections: [
    legalSection('Fotografie delle ricette', 'Le immagini possono essere fornite tramite Openverse e Wikimedia Commons o da risorse locali autorizzate. Ogni immagine soggetta a obblighi di attribuzione deve mantenere le informazioni richieste dalla relativa licenza.', icon: Icons.photo_library_outlined),
    legalSection('Openverse', 'Openverse è utilizzato come motore di ricerca di contenuti con licenze compatibili. Le condizioni della singola opera prevalgono sempre sulle informazioni generali del servizio.', icon: Icons.image_search_outlined),
    legalSection('Wikimedia Commons', 'Le immagini provenienti da Wikimedia Commons restano soggette alla licenza indicata nella pagina della singola opera e agli eventuali obblighi di attribuzione o condivisione.', icon: Icons.public_outlined),
    legalSection('Contenuti di terze parti', 'Marchi, nomi e altri materiali di terzi appartengono ai rispettivi titolari. Ricette del Mondo non rivendica diritti su materiali di terze parti oltre quanto consentito dalle relative licenze.', icon: Icons.copyright_outlined),
    legalSection('Crediti', 'La sezione crediti sarà mantenuta aggiornata con le attribuzioni necessarie. Per ogni immagine soggetta ad attribuzione saranno conservati e resi disponibili i dati di licenza e credito richiesti dalla relativa fonte.', icon: Icons.fact_check_outlined),
  ]);
}

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});
  @override State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}
class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool analytics = true, personalizedAds = true, promotional = false, serviceNotifications = true;
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: legalCream, appBar: AppBar(backgroundColor: legalCream, title: const Text('Gestisci Privacy', style: TextStyle(fontWeight: FontWeight.w900))), body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [legalGreen, Color(0xFF0C7A4B)]), borderRadius: BorderRadius.circular(26)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.shield_rounded, color: Colors.white, size: 38), SizedBox(height: 10), Text('Le tue preferenze, sotto il tuo controllo', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)), SizedBox(height: 7), Text('Puoi modificare queste scelte in qualsiasi momento.', style: TextStyle(color: Colors.white70, height: 1.4))])),
    const SizedBox(height: 14),
    Card(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Column(children: [
      SwitchListTile(value: analytics, onChanged: (v) => setState(() => analytics = v), title: const Text('Statistiche di utilizzo', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Aiutano a capire quali funzioni vengono usate di più.'), secondary: const Icon(Icons.analytics_outlined, color: legalGreen)),
      SwitchListTile(value: personalizedAds, onChanged: (v) => setState(() => personalizedAds = v), title: const Text('Pubblicità personalizzata', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Puoi disattivarla e continuare a usare la versione gratuita.'), secondary: const Icon(Icons.ads_click_outlined, color: legalGreen)),
      SwitchListTile(value: promotional, onChanged: (v) => setState(() => promotional = v), title: const Text('Comunicazioni promozionali', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Offerte, novità e promozioni.'), secondary: const Icon(Icons.campaign_outlined, color: legalGreen)),
      SwitchListTile(value: serviceNotifications, onChanged: (v) => setState(() => serviceNotifications = v), title: const Text('Notifiche di servizio', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('Scadenze, nuove ricette e comunicazioni importanti.'), secondary: const Icon(Icons.notifications_none_rounded, color: legalGreen)),
    ])),
    const SizedBox(height: 12),
    ListTile(tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), leading: const Icon(Icons.description_outlined, color: legalGreen), title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w800)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()))),
    const SizedBox(height: 8),
    ListTile(tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), leading: const Icon(Icons.gavel_outlined, color: legalGreen), title: const Text('Termini e Condizioni', style: TextStyle(fontWeight: FontWeight.w800)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPage()))),
    const SizedBox(height: 8),
    ListTile(tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), leading: const Icon(Icons.workspace_premium_outlined, color: legalGreen), title: const Text('Condizioni Premium', style: TextStyle(fontWeight: FontWeight.w800)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumTermsPage()))),
    const SizedBox(height: 8),
    ListTile(tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), leading: const Icon(Icons.email_outlined, color: legalGreen), title: const Text('Contatta il titolare del trattamento', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('hardwaresolutionviterbo@gmail.com')),
    const SizedBox(height: 16),
    OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Richiesta di esportazione dati registrata. La funzione online sarà collegata al sistema account.'))), icon: const Icon(Icons.download_outlined), label: const Text('Richiedi una copia dei miei dati')),
    const SizedBox(height: 8),
    OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La cancellazione completa dell’account sarà disponibile dal sistema account.'))), icon: const Icon(Icons.delete_outline_rounded), label: const Text('Elimina account e dati')),
  ]));
}
