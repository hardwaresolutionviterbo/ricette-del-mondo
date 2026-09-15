import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'notification_service.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'recipe.dart';
import 'recipe_photo_service.dart';
import 'recipe_repository.dart';
import 'special_recipes.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'legal_pages.dart';
import 'account_page.dart';
import 'ad_consent_service.dart';
import 'ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Limita la cache immagini: con migliaia di ricette e foto remote non
  // permettiamo alla cache Flutter di crescere indefinitamente.
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 120;
  imageCache.maximumSizeBytes = 32 << 20;
  // L'app deve poter disegnare subito: Firebase/consenso pubblicità non devono
  // bloccare il primo frame o tenere fermo il thread UI durante l'avvio.
  runApp(const RicetteApp());
  unawaited(_initializeNonCriticalServices());
}

Future<void> _initializeNonCriticalServices() async {
  try {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  } catch (_) {
    // Firebase non deve mai impedire l'avvio dell'app.
  }
}

class RatingStats { double sum=0; int count=0; double get avg=>count==0?0:sum/count; }

const green=Color(0xFF075B3A), green2=Color(0xFF0C7A4B), orange=Color(0xFFF39A19), cream=Color(0xFFFFFBF3), ink=Color(0xFF12324A), pale=Color(0xFFF2E8D8);
const flags={'Italia':'🇮🇹','Giappone':'🇯🇵','Messico':'🇲🇽','India':'🇮🇳','Grecia':'🇬🇷','Thailandia':'🇹🇭','Spagna':'🇪🇸','Corea del Sud':'🇰🇷','Perù':'🇵🇪','Francia':'🇫🇷','Turchia':'🇹🇷','Cina':'🇨🇳','Stati Uniti':'🇺🇸','USA':'🇺🇸','Marocco':'🇲🇦','Brasile':'🇧🇷','Argentina':'🇦🇷','Vietnam':'🇻🇳','Indonesia':'🇮🇩','Portogallo':'🇵🇹','Germania':'🇩🇪','Regno Unito':'🇬🇧','Etiopia':'🇪🇹','Libano':'🇱🇧','Israele':'🇮🇱','Egitto':'🇪🇬','Australia':'🇦🇺','Filippine':'🇵🇭'};
String flag(String c)=>flags[c]??'🌍';

const allergenLabels = <String, String>{
  'glutine': 'Glutine',
  'crostacei': 'Crostacei',
  'uova': 'Uova',
  'pesce': 'Pesce',
  'arachidi': 'Arachidi',
  'soia': 'Soia',
  'latte': 'Latte e derivati',
  'frutta_secca': 'Frutta a guscio',
  'sedano': 'Sedano',
  'senape': 'Senape',
  'sesamo': 'Sesamo',
  'solfiti': 'Solfiti',
  'lupini': 'Lupini',
  'molluschi': 'Molluschi',
};

const allergenTerms = <String, List<String>>{
  'glutine': ['glutine','frumento','grano','farina','pane','pasta','couscous','semola','orzo','segale','avena','farro','seitan'],
  'crostacei': ['crostacei','gambero','gamberi','scampo','scampi','granchio','aragosta','astice'],
  'uova': ['uovo','uova','albume','tuorlo','maionese'],
  'pesce': ['pesce','salmone','tonno','merluzzo','orata','branzino','acciuga','acciughe','sardina','sardine','aringa','sgombro'],
  'arachidi': ['arachidi','burro di arachidi','noccioline'],
  'soia': ['soia','tofu','edamame','salsa di soia','miso','tempeh'],
  'latte': ['latte','burro','panna','formaggio','parmigiano','mozzarella','ricotta','yogurt','mascarpone','lattosio'],
  'frutta_secca': ['mandorla','mandorle','noce','noci','nocciola','nocciole','pistacchio','pistacchi','anacardo','anacardi','pecan','macadamia'],
  'sedano': ['sedano'],
  'senape': ['senape'],
  'sesamo': ['sesamo','tahina','tahini'],
  'solfiti': ['solfiti','metabisolfito','anidride solforosa'],
  'lupini': ['lupini','farina di lupino'],
  'molluschi': ['molluschi','cozze','vongole','calamaro','calamari','seppia','seppie','polpo','polpo','ostrica','ostriche'],
};

Set<String> detectAllergens(Recipe r) {
  final text = '${r.title} ${r.description} ${r.ingredients.join(' ')} ${r.tags.join(' ')}'.toLowerCase();
  final found = <String>{};
  allergenTerms.forEach((key, terms) {
    if (terms.any((term) => text.contains(term))) found.add(key);
  });
  return found;
}

// Inserire qui i profili ufficiali prima della pubblicazione. Non vengono inventati URL.
const socialFacebook='';
const socialInstagram='';
const socialTikTok='';

Widget recipeVisual(Recipe r,{double height=170,BorderRadius? radius})=>RecipePhoto(recipe:r,height:height,radius:radius??BorderRadius.circular(18));

Widget specialVisual(Recipe r,{double height=170,BorderRadius? radius})=>recipeVisual(r,height:height,radius:radius);

class SplashPage extends StatefulWidget{const SplashPage({super.key});@override State<SplashPage> createState()=>_SplashPageState();}
class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin{
 late final AnimationController controller;
 @override void initState(){super.initState();controller=AnimationController(vsync:this,duration:const Duration(milliseconds:5000))..forward();Future.delayed(const Duration(milliseconds:5200),(){if(mounted)Navigator.of(context).pushReplacement(MaterialPageRoute(builder:(_)=>const AppShell()));});}
 @override void dispose(){controller.dispose();super.dispose();}
 @override Widget build(BuildContext c)=>Scaffold(backgroundColor:Colors.black,body:SafeArea(child:LayoutBuilder(builder:(c,box)=>Stack(children:[Positioned.fill(child:Image.asset('assets/splash_v6.png',fit:BoxFit.cover,filterQuality:FilterQuality.high)),Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Colors.black.withValues(alpha: .08),Colors.black.withValues(alpha: .20)])))),
Positioned(left:0,right:0,top:box.maxHeight*.615,height:box.maxHeight*.12,child:IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Colors.black,Colors.black,Colors.transparent]))))),
Positioned(left:24,right:24,bottom:42,child:AnimatedBuilder(animation:controller,builder:(_,__) {final p=controller.value;final pct=(p*100).round();final count=(p*10000).round().clamp(0,10000);return Column(children:[Text('Caricamento ricette...',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w700,shadows:[Shadow(color:Colors.black54,blurRadius:5)])),const SizedBox(height:7),ClipRRect(borderRadius:BorderRadius.circular(20),child:Container(height:12,decoration:BoxDecoration(color:Colors.black.withValues(alpha: .35),border:Border.all(color:Colors.white70)),child:FractionallySizedBox(alignment:Alignment.centerLeft,widthFactor:p,child:Container(decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFFD89A32),Color(0xFFFFE0A0)])))))),const SizedBox(height:7),Text('$pct%',style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900,shadows:[Shadow(color:Colors.black54,blurRadius:5)])),const SizedBox(height:7),Text('$count di 10.000 ricette caricate',style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900,shadows:[Shadow(color:Colors.black54,blurRadius:5)]))]);}) )]))));}

class RicetteApp extends StatelessWidget{const RicetteApp({super.key});@override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Ricette del Mondo',theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:cream,colorScheme:ColorScheme.fromSeed(seedColor:green),fontFamily:'sans-serif',appBarTheme:const AppBarTheme(backgroundColor:cream,foregroundColor:ink,elevation:0)),home:const SplashPage());}

class AppShell extends StatefulWidget{const AppShell({super.key});@override State<AppShell> createState()=>_AppShellState();}
class _AppShellState extends State<AppShell>{
 String? profilePhotoPath;
 final ImagePicker _profilePicker = ImagePicker();
 final repo=RecipeRepository(), search=TextEditingController(); List<Recipe> all=[]; List<Recipe> _catalog=[]; List<Recipe> _premiumFree=[]; List<Recipe> _specialBraceria=[]; List<Recipe> _specialGourmet=[]; int _italianCount=0; Timer? _searchDebounce; String _searchQuery=''; String? _filteredCacheKey; List<Recipe> _filteredCache=const []; final favorites=<String>{}, shopping=<String>{}; final ratings=<String,RatingStats>{}, tasteRatings=<String,RatingStats>{}; final userRatings=<String,int>{}, userTasteRatings=<String,int>{}; final avoidedAllergens=<String>{}; int tab=0; String category='Tutte',diet='Tutte',language='Italiano'; int maxTime=180;
 List<Recipe> get catalog=>_catalog;

 // Le 10 ricette gratuite Premium ruotano su 5 gruppi diversi.
 // Il gruppo viene scelto in modo deterministico in base al giorno, così
 // durante la giornata resta stabile e dopo 5 rotazioni il ciclo riparte.
 List<Recipe> get premiumFreeRecipes=>_premiumFree;
 RatingStats statsFor(Map<String,RatingStats> map,String id)=>map.putIfAbsent(id,()=>RatingStats());
 void castVote(Recipe r,int stars,{required bool taste}){
  final map=taste?tasteRatings:ratings;
  final mine=taste?userTasteRatings:userRatings;
  final old=mine[r.id];
  final st=statsFor(map,r.id);
  if(old!=null){
    st.sum-=old;
  }else{
    st.count++;
  }
  st.sum+=stars;
  mine[r.id]=stars;
  // Aggiorna immediatamente tutte le sezioni della Home e la classifica.
  // Il voto dell'utente diventa quindi visibile appena si torna alla Home,
  // senza dover ricaricare il catalogo.
  if(mounted)setState((){});
 }
 double avgFor(Recipe r,{bool taste=false})=>(taste?tasteRatings:ratings)[r.id]?.avg??0;
 int countFor(Recipe r,{bool taste=false})=>(taste?tasteRatings:ratings)[r.id]?.count??0;
 @override void initState(){super.initState();
  repo.loadRecipes().then((r){
    if(!mounted)return;
    _buildCatalogCaches(r);
    setState(()=>all=r);
  }).catchError((_){
    if(mounted)setState((){});
  });
  SharedPreferences.getInstance().then((p){if(mounted)setState((){avoidedAllergens.addAll(p.getStringList('rdm_avoided_allergens')??const []);profilePhotoPath=p.getString('rdm_profile_photo_path');});});
  // Gli annunci non devono competere con il primo rendering dell'Home.
  
}
 void _buildCatalogCaches(List<Recipe> recipes){
  _catalog=List<Recipe>.unmodifiable([...recipes,...specialDoughRecipes]);
  final pool=recipes.where((r)=>!r.premium).toList(growable:false);
  if(pool.length<=10){
    _premiumFree=List<Recipe>.unmodifiable(pool);
  }else{
    // Selezione deterministica senza shuffle dell'intero catalogo: evita un
    // lavoro inutile sul thread UI ogni volta che l'app viene avviata.
    final day=DateTime.now().difference(DateTime(2020,1,1)).inDays;
    final start=(day%5)*10;
    final safeStart=start<pool.length?start:0;
    _premiumFree=List<Recipe>.unmodifiable(List.generate(10,(i)=>pool[(safeStart+i)%pool.length]));
  }
  _italianCount=0;
  final braceria=[...specialBraceriaRecipes];
  final gourmet=<Recipe>[];
  for(final r in _catalog){
    if(r.country.toLowerCase()=='italia')_italianCount++;
    final title=r.title.toLowerCase();
    final tags=r.tags.map((x)=>x.toLowerCase()).toSet();
    if(tags.intersection({'carne','griglia','brace','bbq','pollo'}).isNotEmpty||title.contains('asado')||title.contains('pulled'))braceria.add(r);
    if(tags.contains('gourmet'))gourmet.add(r);
  }
  _specialBraceria=List<Recipe>.unmodifiable(braceria);
  _specialGourmet=List<Recipe>.unmodifiable(gourmet);
 }

 bool dietMatches(Recipe r,String selected){if(selected=='Tutte')return true;final t='${r.title} ${r.description} ${r.ingredients.join(' ')} ${r.tags.join(' ')}'.toLowerCase();if(selected=='Vegetariano')return !RegExp(r'\b(carne|manzo|maiale|prosciutto|pollo|tacchino|agnello|salsiccia|pesce|salmone|tonno|merluzzo|gamberi|gambero|acciuga|acciughe)\b').hasMatch(t);if(selected=='Vegano')return !RegExp(r'\b(carne|manzo|maiale|prosciutto|pollo|tacchino|agnello|salsiccia|pesce|salmone|tonno|merluzzo|gamberi|gambero|uova|uovo|latte|burro|panna|formaggio|parmigiano|mozzarella|ricotta|yogurt|miele)\b').hasMatch(t);if(selected=='Senza glutine')return !allergenTerms['glutine']!.any((x)=>t.contains(x));if(selected=='Senza lattosio')return !allergenTerms['latte']!.any((x)=>t.contains(x));return true;}
 List<Recipe> get filtered{
  final s=_searchQuery.trim().toLowerCase();
  final allergenKey=(avoidedAllergens.toList()..sort()).join(',');
  final key='$s|$category|$diet|$maxTime|$allergenKey';
  if (_filteredCacheKey==key) return _filteredCache;
  if (s.isEmpty && category=='Tutte' && diet=='Tutte' && maxTime>=180 && avoidedAllergens.isEmpty) {
    _filteredCacheKey=key;
    _filteredCache=_catalog;
    return _filteredCache;
  }
  final terms=s.split(RegExp(r'[, ]+')).where((x)=>x.isNotEmpty).toList(growable:false);
  final result=<Recipe>[];
  for(final r in catalog){
    if(category!='Tutte' && r.category!=category) continue;
    if(r.timeMin>maxTime) continue;
    if(diet!='Tutte' && !dietMatches(r,diet)) continue;
    if(terms.isNotEmpty){
      final hay='${r.title} ${r.country} ${r.cuisine} ${r.category} ${r.ingredients.join(' ')} ${r.tags.join(' ')}'.toLowerCase();
      if(!terms.every(hay.contains)) continue;
    }
    if(avoidedAllergens.isNotEmpty && detectAllergens(r).intersection(avoidedAllergens).isNotEmpty) continue;
    result.add(r);
  }
  _filteredCacheKey=key;
  _filteredCache=List<Recipe>.unmodifiable(result);
  return _filteredCache;
 }
 void _invalidateFilteredCache()=>_filteredCacheKey=null;
 void onSearchChanged(String value){
  _searchQuery=value;
  _invalidateFilteredCache();
  _searchDebounce?.cancel();
  if(tab!=1)return;
  _searchDebounce=Timer(const Duration(milliseconds:160),(){if(mounted)setState((){});});
 }
 @override void dispose(){_searchDebounce?.cancel();search.dispose();super.dispose();}
 @override Widget build(BuildContext c){if(all.isEmpty)return const Scaffold(body:Center(child:CircularProgressIndicator()));final Widget currentPage=switch(tab){0=>home(),1=>searchPage(),2=>categoriesPage(),3=>favoritesPage(),4=>profilePage(),_=>home()};return Scaffold(body:SafeArea(child:currentPage),bottomNavigationBar:NavigationBar(height:68,elevation:10,backgroundColor:Colors.white,indicatorColor:const Color(0xFFDCEFE5),labelBehavior:NavigationDestinationLabelBehavior.alwaysShow,selectedIndex:tab,onDestinationSelected:(i){if(i!=tab)setState(()=>tab=i);},destinations:const [NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home_rounded),label:'Home'),NavigationDestination(icon:Icon(Icons.search_rounded),selectedIcon:Icon(Icons.search_rounded),label:'Cerca'),NavigationDestination(icon:Icon(Icons.grid_view_rounded),selectedIcon:Icon(Icons.grid_view_rounded),label:'Esplora'),NavigationDestination(icon:Icon(Icons.favorite_border_rounded),selectedIcon:Icon(Icons.favorite_rounded),label:'Preferiti'),NavigationDestination(icon:Icon(Icons.person_outline_rounded),selectedIcon:Icon(Icons.person_rounded),label:'Profilo')]));}
 Widget logo({double h=96})=>Image.asset('assets/logo_rdm.png',height:h,fit:BoxFit.contain);
 Widget home(){
  final total=all.length;
  final italian=_italianCount;
  final world=total-italian;
  final heroRecipe=all.isNotEmpty?all[0]:null;
  return ListView(
    padding:const EdgeInsets.fromLTRB(16,8,16,28),
    children:[
      modernHeader(),
      const SizedBox(height:12),
      if(heroRecipe!=null) homeHeroModern(heroRecipe,total,italian,world),
      const SizedBox(height:14),
      searchBox(),
      const SizedBox(height:6),
      section('Scopri le specialità',action:'Vedi tutte'),
      SizedBox(
        height:92,
        child:ListView(
          scrollDirection:Axis.horizontal,
          padding:const EdgeInsets.only(bottom:4),
          children:[
            specialCompact('assets/banners/banner_impasti.png','Impasti','Basi perfette per grandi ricette',()=>openSpecialPage('Speciale Impasti','Impasti per pizza e focaccia da fare a casa.',specialDoughRecipes,Icons.local_pizza)),
            specialCompact('assets/banners/banner_hamburger.png','Hamburger','Classici e creativi da tutto il mondo',()=>openSpecialPage('Speciale Hamburger','Una raccolta dedicata agli hamburger.',[...specialHamburgerRecipes,...catalog.where((r)=>r.title.toLowerCase().contains('hamburger')||r.tags.any((t)=>t.toLowerCase().contains('burger')))],Icons.lunch_dining)),
            specialCompact('assets/banners/banner_braceria.png','Braceria','Il gusto autentico della griglia',()=>openSpecialPage('Speciale Braceria','Ricette per griglia, brace e cotture lente.',_specialBraceria,Icons.outdoor_grill)),
            specialCompact('assets/banners/banner_gourmet.png','Gourmet','L’alta cucina a casa tua',()=>openSpecialPage('Speciale Gourmet Stellato','Una raccolta editoriale di alta cucina.',_specialGourmet,Icons.auto_awesome)),
          ],
        ),
      ),
      section('Ricetta del giorno',action:'Apri',onAction:heroRecipe==null?null:()=>openRecipe(heroRecipe)),
      if(heroRecipe!=null) dailyRecipeCard(),
      const SizedBox(height:4),
      section('Le 10 ricette gratuite',action:'Vedi tutte',onAction:()=>setState(()=>tab=1)),
      SizedBox(height:238,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.only(bottom:4),children:premiumFreeRecipes.map((r)=>miniCard(r)).toList())),
      ratingHomeSection('🏆 Più votate',false),
      section('Esplora il mondo',action:'Scopri tutto'),
      continentGrid(),
      section('Idee per te',action:'Vedi tutte'),
      ...all.skip(10).take(6).map(recipeCard),
      section('Scopri Premium'),
      premiumBanner(),
      const SizedBox(height:4),
      socialSection(),
    ],
  );
 }
 Widget modernHeader()=>Row(children:[
   Container(width:46,height:46,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.06),blurRadius:14,offset:const Offset(0,5))]),child:Padding(padding:const EdgeInsets.all(6),child:Image.asset('assets/logo_rdm.png',fit:BoxFit.contain))),
   const SizedBox(width:10),
   const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Ricette del Mondo',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:ink)),Text('Ogni ricetta è un viaggio.',style:TextStyle(fontSize:11,color:Colors.black54,fontWeight:FontWeight.w600))])),
   IconButton(style:IconButton.styleFrom(backgroundColor:Colors.white),onPressed:()=>setState(()=>tab=4),icon:const Icon(Icons.person_outline_rounded,color:green)),
 ]);
 Widget homeHeroModern(Recipe r,int total,int italian,int world)=>Container(
   height:290,
   decoration:BoxDecoration(borderRadius:BorderRadius.circular(28),boxShadow:[BoxShadow(color:green.withValues(alpha:.16),blurRadius:24,offset:const Offset(0,10))]),
   child:ClipRRect(borderRadius:BorderRadius.circular(28),child:Stack(children:[
     Positioned.fill(child:recipeVisual(r,height:290,radius:BorderRadius.zero)),
     Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black.withValues(alpha:.08),Colors.black.withValues(alpha:.10),Colors.black.withValues(alpha:.78)])))),
     Positioned(left:18,right:18,top:16,child:Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.16),borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white.withValues(alpha:.24))),child:const Text('SAPORI SENZA CONFINI',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1.5)),),const Spacer(),Container(width:38,height:38,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.16),shape:BoxShape.circle),child:const Icon(Icons.public_rounded,color:Colors.white,size:20))])),
     Positioned(left:18,right:18,bottom:16,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       const Text('Scopri il mondo a tavola',style:TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900,height:1.05)),
       const SizedBox(height:5),
       const Text('Ricette, tradizioni e sapori da ogni angolo del pianeta.',style:TextStyle(color:Colors.white70,fontSize:12.5,fontWeight:FontWeight.w500)),
       const SizedBox(height:12),
       Row(children:[
         Expanded(child:Container(height:44,padding:const EdgeInsets.symmetric(horizontal:12),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.95),borderRadius:BorderRadius.circular(15)),child:Row(children:[const Icon(Icons.restaurant_menu_rounded,color:green,size:18),const SizedBox(width:8),Expanded(child:Text(r.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:ink,fontSize:12,fontWeight:FontWeight.w900))),Text('${r.timeMin} min',style:const TextStyle(color:green,fontSize:11,fontWeight:FontWeight.w800))]))),
         const SizedBox(width:8),
         Container(height:44,padding:const EdgeInsets.symmetric(horizontal:14),decoration:BoxDecoration(color:green,borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.arrow_forward_rounded,color:Colors.white)),
       ]),
       const SizedBox(height:10),
       Row(children:[homeHeroMetric('$total','RICETTE'),homeHeroMetric('$italian','ITALIANE'),homeHeroMetric('$world','DAL MONDO')]),
     ])),
   ])));
 Widget homeHeroMetric(String value,String label)=>Expanded(child:Row(children:[Text(value,style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w900)),const SizedBox(width:5),Text(label,style:const TextStyle(color:Colors.white70,fontSize:8,fontWeight:FontWeight.w800,letterSpacing:.6))]));
 Widget specialCompact(String asset,String title,String subtitle,VoidCallback onTap)=>Padding(padding:const EdgeInsets.only(right:9),child:SizedBox(width:300,height:62,child:Material(color:Colors.white,borderRadius:BorderRadius.circular(17),elevation:2,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(17),child:ClipRRect(borderRadius:BorderRadius.circular(17),child:Image.asset(asset,width:300,height:62,fit:BoxFit.fill,filterQuality:FilterQuality.medium,errorBuilder:(_,__,___)=>Container(color:pale,alignment:Alignment.center,child:const Icon(Icons.image_not_supported_outlined,color:green,size:26))))))));
 Widget dailyRecipeCard(){
  if(all.isEmpty)return const SizedBox.shrink();
  final now=DateTime.now();
  final start=DateTime(now.year,1,1);
  final day=now.difference(start).inDays;
  final recipe=all[day%all.length];
  return TweenAnimationBuilder<double>(
    tween:Tween(begin:0,end:1),duration:const Duration(milliseconds:750),curve:Curves.easeOutCubic,
    builder:(context,v,child)=>Opacity(opacity:v,child:Transform.translate(offset:Offset(0,12*(1-v)),child:child)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Text('⭐',style:TextStyle(fontSize:21)),const SizedBox(width:7),const Expanded(child:Text('Ricetta del giorno',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:ink))),TextButton(onPressed:()=>openRecipe(recipe),child:const Text('Apri',style:TextStyle(color:green,fontWeight:FontWeight.w900)))]),
      const SizedBox(height:6),
      Card(
        clipBehavior:Clip.antiAlias,elevation:4,margin:EdgeInsets.zero,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26)),
        child:InkWell(onTap:()=>openRecipe(recipe),child:Stack(children:[
          SizedBox(width:double.infinity,height:250,child:recipeVisual(recipe,height:250,radius:BorderRadius.zero)),
          Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Colors.transparent,Colors.black.withValues(alpha: .72)])))),
          Positioned(left:15,top:14,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:green,borderRadius:BorderRadius.circular(18),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha: .18),blurRadius:10)]),child:const Text('RICETTA DEL GIORNO',style:TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.8)))),
          Positioned(left:16,right:16,bottom:15,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(recipe.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),
            const SizedBox(height:6),
            Row(children:[Text('${flag(recipe.country)} ${recipe.country}',style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w800)),const SizedBox(width:12),const Icon(Icons.schedule_rounded,color:Colors.white70,size:14),const SizedBox(width:4),Text('${recipe.timeMin} min',style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w700)),const SizedBox(width:12),Text(recipe.difficulty,style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w700))]),
          ])),
        ])),
      ),
    ]),
  );
 }
 Widget homeHero(int total,int italian,int world)=>TweenAnimationBuilder<double>(
  tween:Tween(begin:0,end:1),
  duration:const Duration(milliseconds:650),
  curve:Curves.easeOutCubic,
  builder:(context,fade,child)=>Opacity(
    opacity:fade,
    child:Transform.translate(offset:Offset(0,10*(1-fade)),child:child),
  ),
  child:Container(
    decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(30),
      boxShadow:[BoxShadow(color:green.withValues(alpha: .18),blurRadius:28,offset:const Offset(0,12))],
    ),
    child:ClipRRect(
      borderRadius:BorderRadius.circular(30),
      child:Stack(
        children:[
          Container(
            height:390,
            decoration:const BoxDecoration(
              gradient:LinearGradient(
                begin:Alignment.topLeft,
                end:Alignment.bottomRight,
                colors:[Color(0xFF063A28),Color(0xFF075B3A),Color(0xFF0B7A4D),Color(0xFF0A4D38)],
                stops:[0,.38,.72,1],
              ),
            ),
          ),
          Positioned(right:-70,top:-80,child:Container(width:250,height:250,decoration:BoxDecoration(shape:BoxShape.circle,color:Colors.white.withValues(alpha: .055)))),
          Positioned(left:-90,bottom:-115,child:Container(width:300,height:300,decoration:BoxDecoration(shape:BoxShape.circle,color:orange.withValues(alpha: .10)))),
          Padding(
            padding:const EdgeInsets.fromLTRB(20,18,20,18),
            child:Column(children:[
              Row(children:[
                Container(
                  padding:const EdgeInsets.symmetric(horizontal:13,vertical:8),
                  decoration:BoxDecoration(color:Colors.white.withValues(alpha: .10),borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white.withValues(alpha: .13))),
                  child:const Text('SAPORI SENZA CONFINI',style:TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.7)),
                ),
                const Spacer(),
                IconButton(
                  tooltip:'Profilo',
                  style:IconButton.styleFrom(backgroundColor:Colors.white.withValues(alpha: .12),foregroundColor:Colors.white),
                  onPressed:()=>setState(()=>tab=4),
                  icon:const Icon(Icons.person_outline_rounded,size:25),
                ),
              ]),
              const SizedBox(height:2),
              SizedBox(height:156,child:logo(h:154)),
              const Text('Ogni ricetta è un viaggio.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900,letterSpacing:.15)),
              const SizedBox(height:4),
              Text('Scopri sapori, tradizioni e cucine da tutto il mondo.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white.withValues(alpha: .82),fontSize:12.5,fontWeight:FontWeight.w500)),
              const SizedBox(height:17),
              Container(
                padding:const EdgeInsets.symmetric(horizontal:8,vertical:13),
                decoration:BoxDecoration(color:Colors.white.withValues(alpha: .105),borderRadius:BorderRadius.circular(22),border:Border.all(color:Colors.white.withValues(alpha: .15))),
                child:Row(children:[
                  homeStat('$total','RICETTE',Icons.menu_book_rounded),
                  homeDivider(),
                  homeStat('$italian','ITALIANE',Icons.flag_rounded),
                  homeDivider(),
                  homeStat('$world','DAL MONDO',Icons.public_rounded),
                ]),
              ),
              const SizedBox(height:12),
              Row(children:[
                Expanded(child:heroAction(Icons.kitchen_rounded,'Cosa hai nel frigo?',fridgePage)),
                const SizedBox(width:10),
                Expanded(child:heroAction(Icons.favorite_rounded,'I miei preferiti',()=>setState(()=>tab=3))),
              ]),
            ]),
          ),
        ],
      ),
    ),
  ),
);
 Widget homeStat(String value,String label,IconData icon)=>Expanded(child:Column(children:[Icon(icon,color:Colors.white.withValues(alpha: .82),size:19),const SizedBox(height:4),Text(value,style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),Text(label,style:TextStyle(color:Colors.white.withValues(alpha: .70),fontSize:8.5,fontWeight:FontWeight.w800,letterSpacing:.7))]));
 Widget homeDivider()=>Container(width:1,height:48,color:Colors.white.withValues(alpha: .16));
 Widget heroAction(IconData icon,String label,VoidCallback onTap)=>Material(color:Colors.white,borderRadius:BorderRadius.circular(16),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(16),child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:11),child:Row(children:[Container(width:34,height:34,decoration:BoxDecoration(color:const Color(0xFFE1F1E8),borderRadius:BorderRadius.circular(11)),child:Icon(icon,color:green,size:19)),const SizedBox(width:8),Expanded(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:ink,fontSize:11.5,fontWeight:FontWeight.w900))),const Icon(Icons.arrow_forward_ios_rounded,color:green,size:13)]))));
 Widget countStat(String value,String label)=>Column(children:[Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:green)),Text(label,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:ink,letterSpacing:.5))]);
 Widget quickHomeAction(IconData icon,String label,VoidCallback onTap)=>FilledButton.tonalIcon(onPressed:onTap,icon:Icon(icon,size:19),label:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),style:FilledButton.styleFrom(foregroundColor:green,backgroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:12,horizontal:9),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))));
 Widget specialBanner(String assetPath,{required VoidCallback onTap})=>Card(clipBehavior:Clip.antiAlias,elevation:2,margin:const EdgeInsets.only(bottom:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:AspectRatio(aspectRatio:5.15,child:Image.asset(assetPath,fit:BoxFit.cover,filterQuality:FilterQuality.medium,errorBuilder:(_,__,___)=>Container(color:pale,alignment:Alignment.center,child:const Icon(Icons.image_not_supported_outlined,color:green,size:28))))));
 void openSpecialPage(String title,String subtitle,List<Recipe> recipes,IconData icon)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SpecialCollectionPage(title:title,subtitle:subtitle,recipes:recipes,icon:icon)));
 Widget socialSection()=>Card(clipBehavior:Clip.antiAlias,elevation:2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),child:Container(padding:const EdgeInsets.all(18),decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFFF5E9D7),Color(0xFFE5F1E8)])),child:Column(crossAxisAlignment:CrossAxisAlignment.center,children:[const Text('Seguici sui social',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:4),const Text('Ricette, curiosità, novità e tanto altro!',textAlign:TextAlign.center,style:TextStyle(color:ink)),const SizedBox(height:14),Row(children:[Expanded(child:socialButton('f','Facebook',const Color(0xFF1877F2),socialFacebook)),const SizedBox(width:9),Expanded(child:socialButton('◎','Instagram',const Color(0xFFE1306C),socialInstagram)),const SizedBox(width:9),Expanded(child:socialButton('♪','TikTok',Colors.black,socialTikTok))]),const SizedBox(height:10),const Text('Unisciti alla nostra community ❤️',style:TextStyle(fontWeight:FontWeight.w700,color:green))])));
 Widget socialButton(String mark,String label,Color color,String url)=>InkWell(onTap:()=>openSocial(url,label),borderRadius:BorderRadius.circular(18),child:Container(padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),boxShadow:[BoxShadow(color:Colors.black12,blurRadius:8,offset:Offset(0,3))]),child:Column(children:[CircleAvatar(radius:21,backgroundColor:color,child:Text(mark,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900))),const SizedBox(height:5),Text(label,style:const TextStyle(fontWeight:FontWeight.w800,color:ink,fontSize:12))])));
 void openSocial(String url,String label){if(url.isEmpty){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Collegheremo $label al tuo profilo ufficiale.')));return;}}

 Widget ratingHomeSection(String title,bool taste){final ranked=_rankedByRating(taste); final shown=ranked.take(5); return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[section(title,action:'Vedi tutte',onAction:()=>showRatingRanking(taste)),if(shown.isEmpty)Card(color:Colors.white,child:const Padding(padding:EdgeInsets.all(18),child:Text('Ancora nessun voto: sii il primo a valutare una ricetta ⭐',style:TextStyle(fontWeight:FontWeight.w700,color:ink)))) else ...shown.map((r)=>ratingRow(r,taste))]);}
 List<Recipe> _rankedByRating(bool taste){final source=taste?tasteRatings:ratings;final ranked=catalog.where((r)=>source.containsKey(r.id)&&source[r.id]!.count>0).toList();ranked.sort((a,b)=>source[b.id]!.avg.compareTo(source[a.id]!.avg));return ranked;}
 Widget ratingRow(Recipe r,bool taste)=>Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(leading:SizedBox(width:58,height:58,child:recipeVisual(r,height:58,radius:BorderRadius.circular(12))),title:Text(r.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,color:ink)),subtitle:Row(children:[stars(avgFor(r,taste:taste)),const SizedBox(width:5),Text('${avgFor(r,taste:taste).toStringAsFixed(1)} • ${countFor(r,taste:taste)} voti',style:const TextStyle(fontSize:11))]),trailing:const Icon(Icons.chevron_right),onTap:()=>openRecipe(r)));
 Widget stars(double value)=>Row(mainAxisSize:MainAxisSize.min,children:List.generate(5,(i)=>Icon(i<value.round()?Icons.star:Icons.star_border,size:17,color:orange)));
 void showRatingRanking(bool taste)=>showModalBottomSheet(context:context,showDragHandle:true,builder:(_){final ranked=_rankedByRating(taste);return SafeArea(child:ListView(padding:const EdgeInsets.all(18),children:[Text(taste?'Ricette più buone':'Ricette più votate',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:10),...ranked.map((r)=>ratingRow(r,taste))]));});
 Widget searchBox()=>Container(
   decoration:BoxDecoration(
     color:Colors.white,
     borderRadius:BorderRadius.circular(20),
     boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.05),blurRadius:14,offset:const Offset(0,5))],
   ),
   child:TextField(
     controller:search,
     onChanged:onSearchChanged,
     onSubmitted:(_){_searchQuery=search.text;setState(()=>tab=1);},
     decoration:InputDecoration(
       hintText:'Cerca ricette, Paesi o ingredienti',
       prefixIcon:const Icon(Icons.search_rounded,color:green),
       suffixIcon:IconButton(
         onPressed:showFilters,
         icon:Container(
           width:34,height:34,
           decoration:BoxDecoration(color:const Color(0xFFE5F1E9),borderRadius:BorderRadius.circular(11)),
           child:const Icon(Icons.tune_rounded,color:green,size:18),
         ),
       ),
       filled:true,
       fillColor:Colors.transparent,
       border:OutlineInputBorder(borderRadius:BorderRadius.circular(20),borderSide:BorderSide.none),
       contentPadding:const EdgeInsets.symmetric(vertical:13),
     ),
   ),
 );
 Widget fridgeBanner()=>Card(elevation:0,color:const Color(0xFFE4F1E8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),child:InkWell(borderRadius:BorderRadius.circular(22),onTap:fridgePage,child:Padding(padding:const EdgeInsets.all(17),child:Row(children:[Container(width:52,height:52,decoration:BoxDecoration(color:green,borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.kitchen,color:Colors.white)),const SizedBox(width:14),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Cosa hai nel frigo?',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:ink)),SizedBox(height:4),Text('Seleziona gli ingredienti e scopri cosa puoi cucinare.',style:TextStyle(color:ink))])),const Icon(Icons.arrow_forward_ios_rounded,size:18,color:green)]))));
 Widget section(String t,{String? action,VoidCallback? onAction})=>Padding(padding:const EdgeInsets.only(top:20,bottom:10),child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[Expanded(child:Text(t,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:ink,letterSpacing:-.2))),if(action!=null)InkWell(onTap:onAction,borderRadius:BorderRadius.circular(14),child:Padding(padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),child:Row(children:[Text(action,style:const TextStyle(color:green,fontSize:11,fontWeight:FontWeight.w900)),const SizedBox(width:3),const Icon(Icons.arrow_forward_rounded,size:15,color:green)])))]));
 Widget recipeCard(Recipe r)=>Card(
  margin:const EdgeInsets.only(bottom:11),
  clipBehavior:Clip.antiAlias,
  elevation:1,
  child:InkWell(
    onTap:()=>openRecipe(r),
    child:Row(children:[
      SizedBox(width:124,height:124,child:recipeVisual(r,height:124,radius:BorderRadius.zero)),
      Expanded(child:Padding(
        padding:const EdgeInsets.all(12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Expanded(child:Text(r.title,maxLines:2,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16,color:ink))),
            if(r.premium)const Icon(Icons.workspace_premium,size:18,color:orange),
          ]),
          const SizedBox(height:5),
          Text('${flag(r.country)} ${r.country}',style:const TextStyle(fontWeight:FontWeight.w600)),
          const SizedBox(height:5),
          Text('${r.prepMin} min prep • ${r.cookMin} min cottura • ${r.servings} porzioni',
            style:const TextStyle(fontSize:11)),
          Text(cost(r,r.servings),
            style:const TextStyle(fontSize:11,color:green,fontWeight:FontWeight.w800)),
        ]),
      )),
      FavoriteButton(
        selected:favorites.contains(r.id),
        onTap:(){
          setState((){
            if(favorites.contains(r.id)){
              favorites.remove(r.id);
            }else{
              favorites.add(r.id);
            }
          });
        },
      ),
    ]),
  ),
 );
 String cost(Recipe r,int servings){
   final base=1.9+r.ingredients.length*.9;
   final v=base*(servings/(r.servings==0?4:r.servings));
   return '€${v.toStringAsFixed(2)} stimati';
 }
 Widget miniCard(Recipe r)=>GestureDetector(
   onTap:()=>openRecipe(r),
   child:SizedBox(
     width:170,
     height:226,
     child:Container(
       margin:const EdgeInsets.only(right:10),
       decoration:BoxDecoration(
         color:Colors.white,
         borderRadius:BorderRadius.circular(22),
         boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.07),blurRadius:14,offset:const Offset(0,5))],
       ),
       child:ClipRRect(
         borderRadius:BorderRadius.circular(22),
         child:Column(
           crossAxisAlignment:CrossAxisAlignment.start,
           children:[
             Stack(children:[
               SizedBox(width:170,height:112,child:recipeVisual(r,height:112,radius:BorderRadius.zero)),
               Positioned(
                 top:8,right:8,
                 child:Container(
                   width:30,height:30,
                   decoration:BoxDecoration(color:Colors.white.withValues(alpha:.94),shape:BoxShape.circle),
                   child:Icon(r.premium?Icons.workspace_premium_rounded:Icons.arrow_forward_rounded,size:16,color:r.premium?orange:green),
                 ),
               ),
             ]),
             Padding(
               padding:const EdgeInsets.fromLTRB(10,9,10,8),
               child:Column(
                 crossAxisAlignment:CrossAxisAlignment.start,
                 children:[
                   Text(r.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,color:ink,fontSize:13)),
                   const SizedBox(height:5),
                   Text('${flag(r.country)} ${r.country}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10.5,color:Colors.black54,fontWeight:FontWeight.w700)),
                   const SizedBox(height:5),
                   Row(children:[
                     const Icon(Icons.schedule_rounded,size:13,color:green),
                     const SizedBox(width:3),
                     Text('${r.timeMin} min',style:const TextStyle(fontSize:10.5,color:ink,fontWeight:FontWeight.w700)),
                     const Spacer(),
                     Flexible(child:Text(cost(r,r.servings),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9.5,color:green,fontWeight:FontWeight.w900))),
                   ]),
                 ],
               ),
             ),
           ],
         ),
       ),
     ),
   ),
 );
 Widget continentGrid()=>GridView.count(crossAxisCount:3,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:9,mainAxisSpacing:9,childAspectRatio:1.02,children:[['Europa','🇪🇺'],['Asia','🌏'],['Americhe','🌎'],['Africa','🌍'],['Oceania','🌊'],['Medio Oriente','🕌']].map((x)=>InkWell(onTap:()=>openContinentPage(x[0]),borderRadius:BorderRadius.circular(20),child:Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFFE7EDE8)),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.04),blurRadius:10,offset:const Offset(0,3))]),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(x[1],style:const TextStyle(fontSize:29)),const SizedBox(height:6),Text(x[0],style:const TextStyle(fontWeight:FontWeight.w900,color:ink,fontSize:12)),const SizedBox(height:3),const Icon(Icons.arrow_forward_rounded,size:15,color:green)])))).toList());
 void openContinentPage(String continent){final rs=all.where((r)=>r.continent.toLowerCase()==continent.toLowerCase()).toList();Navigator.push(context,MaterialPageRoute(builder:(_)=>SpecialCollectionPage(title:'Ricette $continent',subtitle:'Scopri le ricette di $continent.',recipes:rs,icon:Icons.public)));}
 Widget premiumBanner()=>Card(clipBehavior:Clip.antiAlias,elevation:3,child:Container(decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF075B3A),Color(0xFF0C7A4B)])),padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.workspace_premium,color:orange,size:32),SizedBox(width:8),Text('Passa a Premium',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900))]),const SizedBox(height:6),const Text('Sblocca tutte le ricette Premium, le raccolte speciali, storie, procedimenti e funzioni esclusive.',style:TextStyle(color:Colors.white,fontSize:15)),const SizedBox(height:12),Row(children:[priceChip('1 mese','€2,99'),priceChip('6 mesi','€14,99'),priceChip('12 mesi','€24,99')]),const SizedBox(height:12),FilledButton(style:FilledButton.styleFrom(backgroundColor:orange,foregroundColor:ink,minimumSize:const Size.fromHeight(48)),onPressed:premiumPage,child:const Text('Scopri Premium',style:TextStyle(fontWeight:FontWeight.w900)))])));
 Widget priceChip(String a,String b)=>Expanded(child:Container(margin:const EdgeInsets.only(right:6),padding:const EdgeInsets.symmetric(vertical:9,horizontal:5),decoration:BoxDecoration(color:Colors.white.withValues(alpha: .95),borderRadius:BorderRadius.circular(14)),child:Column(children:[Text(a,style:const TextStyle(fontSize:11,color:ink)),Text(b,style:const TextStyle(fontWeight:FontWeight.w900,color:green))])));
 Widget searchPage(){
   final results=filtered;
   return ListView(padding:const EdgeInsets.fromLTRB(16,10,16,28),children:[
     Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Cerca',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink)),Text('Trova la ricetta perfetta per il tuo prossimo viaggio.',style:TextStyle(fontSize:12,color:Colors.black54))])),Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFFE6F2EB),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.travel_explore_rounded,color:green))]),
     const SizedBox(height:14),searchBox(),
     section('Ricerche popolari'),
     Wrap(spacing:8,runSpacing:8,children:['Pasta','Pollo','Pizza','Dolci','Vegetariano','Senza glutine','Salmone','Veloci'].map((x)=>modernChip(x,selected:search.text.toLowerCase()==x.toLowerCase(),onTap:(){search.text=x;_searchQuery=x;_invalidateFilteredCache();setState((){});})).toList()),
     section('Risultati',action:'${results.length} ricette'),
     if(results.isEmpty)emptyState(Icons.search_off_rounded,'Nessuna ricetta trovata','Prova a cambiare parole chiave o filtri.')
     else GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:.73,children:results.take(30).map(miniCard).toList()),
   ]);
 }
 Widget categoriesPage()=>ListView(padding:const EdgeInsets.fromLTRB(16,10,16,28),children:[
   Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Categorie',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink)),Text('Esplora, scopri, cucina.',style:TextStyle(fontSize:12,color:Colors.black54))])),IconButton(onPressed:showFilters,icon:const Icon(Icons.tune_rounded,color:green))]),
   const SizedBox(height:8),
   Container(
     height:150,
     padding:const EdgeInsets.all(18),
     decoration:BoxDecoration(
       borderRadius:BorderRadius.circular(26),
       gradient:const LinearGradient(colors:[Color(0xFF06452F),Color(0xFF0C7A4B)]),
       boxShadow:[BoxShadow(color:green.withValues(alpha:.15),blurRadius:18,offset:const Offset(0,7))],
     ),
     child:Stack(children:[
       const Positioned(right:-18,top:-25,child:Icon(Icons.restaurant_menu_rounded,size:150,color:Colors.white10)),
       const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Text('Un mondo di sapori',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),
         SizedBox(height:4),
         Text('Dall’antipasto al dolce, trovi sempre una nuova ispirazione.',style:TextStyle(color:Colors.white70,fontSize:12,height:1.35)),
       ]),
       Positioned(left:0,bottom:0,child:Container(
         padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),
         decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),
         child:const Text('Esplora ora →',style:TextStyle(color:green,fontWeight:FontWeight.w900,fontSize:11)),
       )),
     ]),
   ),
   section('Scegli una categoria'),
   Wrap(spacing:8,runSpacing:8,children:['Tutte','Antipasti','Primi','Secondi','Zuppe','Dolci','Pizze','Insalate'].map((x)=>modernChip(x,selected:category==x,onTap:()=>setState((){category=x;_invalidateFilteredCache();}))).toList()),
   section('Ricette in evidenza'),
   ...all.where((r)=>category=='Tutte'||r.category==category).take(10).map(recipeCard),
 ]);
 Widget modernChip(String text,{required bool selected,required VoidCallback onTap})=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:AnimatedContainer(duration:const Duration(milliseconds:180),padding:const EdgeInsets.symmetric(horizontal:13,vertical:9),decoration:BoxDecoration(color:selected?green:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:selected?green:const Color(0xFFE1E7E3))),child:Text(text,style:TextStyle(color:selected?Colors.white:ink,fontSize:11,fontWeight:FontWeight.w800))));
 Widget emptyState(IconData icon,String title,String subtitle)=>Container(margin:const EdgeInsets.only(top:10),padding:const EdgeInsets.all(28),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24)),child:Column(children:[Icon(icon,size:48,color:green),const SizedBox(height:10),Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:5),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:Colors.black54))]));
 Widget favoritesPage(){final list=all.where((r)=>favorites.contains(r.id)).toList();return ListView(padding:const EdgeInsets.fromLTRB(16,10,16,28),children:[const Text('I miei preferiti',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:3),Text('${list.length} ricette salvate',style:const TextStyle(color:Colors.black54)),section('Le tue ricette'),if(list.isEmpty)emptyState(Icons.favorite_border_rounded,'Nessun preferito ancora','Salva le ricette che vuoi ritrovare in un attimo.') else GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:.73,children:list.map(miniCard).toList())] );}
 Future<void> pickProfilePhoto() async {
  final action = await showModalBottomSheet<String>(context: context, builder: (c)=>SafeArea(child: Wrap(children:[
    ListTile(leading:const Icon(Icons.photo_library_outlined),title:const Text('Scegli dalla galleria'),onTap:()=>Navigator.pop(c,'gallery')),
    ListTile(leading:const Icon(Icons.photo_camera_outlined),title:const Text('Scatta una foto'),onTap:()=>Navigator.pop(c,'camera')),
    if(profilePhotoPath!=null) ListTile(leading:const Icon(Icons.delete_outline),title:const Text('Rimuovi foto'),onTap:()=>Navigator.pop(c,'remove')),
  ])));
  if(action==null)return;
  if(action=='remove'){
    final p=await SharedPreferences.getInstance();await p.remove('rdm_profile_photo_path');if(mounted)setState(()=>profilePhotoPath=null);return;
  }
  final source=action=='camera'?ImageSource.camera:ImageSource.gallery;
  final picked=await _profilePicker.pickImage(source:source,maxWidth:900,maxHeight:900,imageQuality:88);
  if(picked==null)return;
  final p=await SharedPreferences.getInstance();await p.setString('rdm_profile_photo_path',picked.path);if(mounted)setState(()=>profilePhotoPath=picked.path);
 }
 Widget profileAvatar(){
  final path=profilePhotoPath;
  final hasPhoto=path!=null && path.isNotEmpty;
  return Stack(clipBehavior:Clip.none,children:[
    CircleAvatar(radius:48,backgroundColor:const Color(0xFFDCEFE5),backgroundImage:hasPhoto?FileImage(File(path)):null,child:hasPhoto?null:const Icon(Icons.person_rounded,size:56,color:green)),
    Positioned(right:-2,bottom:0,child:InkWell(onTap:pickProfilePhoto,borderRadius:BorderRadius.circular(18),child:Container(width:34,height:34,decoration:const BoxDecoration(color:green,shape:BoxShape.circle),child:const Icon(Icons.camera_alt_rounded,size:17,color:Colors.white)))),
  ]);
 }
 Widget profilePage()=>ListView(
   padding:const EdgeInsets.fromLTRB(16,10,16,28),
   children:[
     Row(children:[
       const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Text('Profilo',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink)),
         Text('Il tuo spazio personale.',style:TextStyle(fontSize:12,color:Colors.black54)),
       ])),
       IconButton(style:IconButton.styleFrom(backgroundColor:Colors.white),onPressed:showProfileSettings,icon:const Icon(Icons.settings_outlined,color:green)),
     ]),
     const SizedBox(height:8),
     Container(
       padding:const EdgeInsets.all(18),
       decoration:BoxDecoration(
         gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFE8F4ED),Color(0xFFF9F5EC)]),
         borderRadius:BorderRadius.circular(28),
         boxShadow:[BoxShadow(color:green.withValues(alpha:.10),blurRadius:18,offset:const Offset(0,7))],
       ),
       child:Row(children:[
         profileAvatar(),
         const SizedBox(width:16),
         const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Text('Ricette del Mondo',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:ink)),
           SizedBox(height:3),
           Text('Buongiorno, viaggiatore! ❤️',style:TextStyle(fontSize:12,color:Colors.black54)),
           SizedBox(height:10),
           Text('Esplora • cucina • viaggia',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:green)),
         ])),
       ]),
     ),
     const SizedBox(height:12),
     Container(
       padding:const EdgeInsets.symmetric(vertical:15),
       decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.05),blurRadius:14,offset:const Offset(0,5))]),
       child:Row(children:[
         Expanded(child:profileStat(Icons.favorite_rounded,'${favorites.length}','Salvate',Colors.red)),
         profileDivider(),
         Expanded(child:profileStat(Icons.public_rounded,'0','Paesi esplorati',green)),
         profileDivider(),
         Expanded(child:profileStat(Icons.flight_takeoff_rounded,'0','Cucine provate',green)),
       ]),
     ),
     const SizedBox(height:14),
     InkWell(
       onTap:premiumPage,
       borderRadius:BorderRadius.circular(22),
       child:Container(
         padding:const EdgeInsets.all(15),
         decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFFFF1D1),Color(0xFFFFE3A7)]),borderRadius:BorderRadius.circular(22),border:Border.all(color:const Color(0xFFE8C77A))),
         child:Row(children:[
           Container(width:42,height:42,decoration:const BoxDecoration(color:Color(0xFFD28C22),shape:BoxShape.circle),child:const Icon(Icons.workspace_premium_rounded,color:Colors.white)),
           const SizedBox(width:11),
           const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
             Text('Passa a Premium',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:ink)),
             Text('Sblocca tutto il mondo delle ricette.',style:TextStyle(fontSize:11,color:Colors.black54)),
           ])),
           const Icon(Icons.arrow_forward_rounded,color:ink),
         ]),
       ),
     ),
     section('Il tuo viaggio gastronomico'),
     profileTile(Icons.account_circle_rounded,'Il mio account','Registrazione, accesso e sincronizzazione',green,onTap:accountPage),
     profileTile(Icons.favorite_rounded,'I miei preferiti','Le tue ricette salvate',Colors.red,trailing:Text('${favorites.length}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16,color:ink)),onTap:()=>setState(()=>tab=3)),
     profileTile(Icons.shopping_cart_rounded,'Lista della spesa','Gestisci i tuoi ingredienti',green,trailing:Text('${shopping.length}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16,color:ink)),onTap:shoppingPage),
     profileTile(Icons.kitchen_rounded,'Cosa hai nel frigo?','Trova ricette con quello che hai',green,onTap:fridgePage),
     profileTile(Icons.health_and_safety_rounded,'Sicurezza alimentare','Allergeni, conservazione e cottura sicura',green,onTap:foodSafetyPage),
     profileTile(Icons.shield_outlined,'Allergeni da evitare','Personalizza le ricette che vuoi evitare',green,onTap:allergenSettingsPage),
     profileTile(Icons.privacy_tip_outlined,'Gestisci Privacy','Consensi, dati, notifiche e pubblicità',green,onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AppPrivacySettingsPage()))),
     profileTile(Icons.settings_rounded,'Impostazioni','Notifiche, tema e preferenze',Colors.blueGrey,onTap:showProfileSettings),
     profileTile(Icons.help_rounded,'Aiuto e supporto','FAQ e contatti',Colors.blueGrey,onTap:showHelp),
     const SizedBox(height:8),
     Container(
       padding:const EdgeInsets.all(18),
       decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22)),
       child:const Column(children:[
         Text('“Il cibo è memoria, cultura ed emozione.”',textAlign:TextAlign.center,style:TextStyle(color:ink,fontSize:14,fontStyle:FontStyle.italic,fontWeight:FontWeight.w700)),
         SizedBox(height:10),
         Text('Ricette del Mondo',style:TextStyle(color:green,fontSize:17,fontWeight:FontWeight.w900)),
         Text('Ogni ricetta è un viaggio. ❤️',style:TextStyle(color:Colors.black54,fontSize:10)),
       ]),
     ),
   ],
 );
 Widget profileStat(IconData icon,String value,String label,Color color)=>Column(children:[Icon(icon,color:color,size:25),const SizedBox(height:5),Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:Colors.black)),const SizedBox(height:2),Text(label,textAlign:TextAlign.center,maxLines:2,style:const TextStyle(fontSize:10,color:Colors.black54,fontWeight:FontWeight.w600))]);
 Widget profileDivider()=>Container(width:1,height:55,color:const Color(0xFFE5E0D8));
 Widget profileTile(IconData icon,String title,String subtitle,Color iconColor,{Widget? trailing,VoidCallback? onTap,bool highlight=false,String? action})=>Padding(padding:const EdgeInsets.only(bottom:10),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(22),child:Container(padding:const EdgeInsets.fromLTRB(16,14,12,14),decoration:BoxDecoration(color:highlight?const Color(0xFFFFF8E9):Colors.white,borderRadius:BorderRadius.circular(22),border:highlight?Border.all(color:const Color(0xFFE8C87C)):null,boxShadow:[BoxShadow(color:Colors.black.withValues(alpha: .055),blurRadius:12,offset:const Offset(0,4))]),child:Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:highlight?const Color(0xFFFFE8B7):const Color(0xFFEAF4EE),borderRadius:BorderRadius.circular(14)),child:Icon(icon,color:iconColor,size:24)),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:2),Text(subtitle,style:const TextStyle(fontSize:12.5,color:Colors.black54))])),if(action!=null)Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),decoration:BoxDecoration(color:orange,borderRadius:BorderRadius.circular(18)),child:Text(action,style:const TextStyle(color:ink,fontWeight:FontWeight.w900,fontSize:12))),if(trailing!=null)Padding(padding:const EdgeInsets.only(left:8),child:trailing),if(action==null&&trailing==null)const Padding(padding:EdgeInsets.only(left:8),child:Icon(Icons.chevron_right_rounded,color:ink,size:27))]))));
 void accountPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccountPage()));
 void showProfileSettings(){showModalBottomSheet(context:context,showDragHandle:true,backgroundColor:cream,builder:(c)=>SafeArea(child:ListView(shrinkWrap:true,padding:const EdgeInsets.fromLTRB(20,8,20,20),children:[const Text('Impostazioni',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:8),ListTile(leading:const Icon(Icons.notifications_none_rounded,color:green),title:const Text('Notifiche'),subtitle:const Text('Gestisci gli avvisi dell’app'),onTap:(){Navigator.pop(c);Navigator.push(context,MaterialPageRoute(builder:(_)=>const AppPrivacySettingsPage()));}),const ListTile(leading:Icon(Icons.dark_mode_outlined,color:green),title:Text('Aspetto'),subtitle:Text('Tema chiaro dell’app')),ListTile(leading:const Icon(Icons.privacy_tip_outlined,color:green),title:const Text('Privacy'),subtitle:const Text('Gestisci le tue preferenze'),onTap:(){Navigator.pop(c);Navigator.push(context,MaterialPageRoute(builder:(_)=>const AppPrivacySettingsPage()));}),const SizedBox(height:8),FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('Chiudi'))])));}
 void showHelp(){showModalBottomSheet(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Aiuto e supporto',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:10),const Text('Per assistenza, suggerimenti o segnalazioni potrai contattarci dalla sezione supporto dell’app.',style:TextStyle(height:1.4)),const SizedBox(height:18),FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('Chiudi'))]))));}
 void allergenSettingsPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AllergenSettingsPage(selected:avoidedAllergens,onChanged:(key,value)async{setState(()=>value?avoidedAllergens.add(key):avoidedAllergens.remove(key));final p=await SharedPreferences.getInstance();await p.setStringList('rdm_avoided_allergens',avoidedAllergens.toList());})));
 void foodSafetyPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const FoodSafetyPage()));

 void premiumPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PremiumPage()));
 void shoppingPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ShoppingPage(items:shopping)));
 void openRecipe(Recipe recipe){
  _openRecipeAfterAd(recipe);
 }

 Future<void> _openRecipeAfterAd(Recipe recipe) async {
  if (!recipe.premium) {
    await AdService.instance.showInterstitialIfReady();
    if (!mounted) return;
  }
  final conflicts=detectAllergens(recipe).intersection(avoidedAllergens);
  if(conflicts.isNotEmpty){
    final names=conflicts.map((x)=>allergenLabels[x]??x).join(', ');
    showDialog(context:context,builder:(d)=>AlertDialog(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
      title:const Row(children:[Icon(Icons.warning_amber_rounded,color:orange),SizedBox(width:8),Expanded(child:Text('Attenzione allergeni',style:TextStyle(fontWeight:FontWeight.w900,color:ink)))]),
      content:Text('Questa ricetta contiene o potrebbe contenere: $names. Controlla sempre gli ingredienti e le etichette dei prodotti prima di consumare il piatto.',style:const TextStyle(height:1.45)),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Indietro')),FilledButton(onPressed:(){Navigator.pop(d);Navigator.push(context,MaterialPageRoute(builder:(_)=>RecipePage(
        recipe:recipe, selected:favorites.contains(recipe.id),
        onFavorite:(){setState((){if(favorites.contains(recipe.id)){favorites.remove(recipe.id);}else{favorites.add(recipe.id);}});},
        onAdd:(item)=>setState(()=>shopping.add(item)), onAddAll:()=>setState(()=>shopping.addAll(recipe.ingredients)),
        rating:avgFor(recipe), tasteRating:avgFor(recipe,taste:true), ratingCount:countFor(recipe), tasteCount:countFor(recipe),
        onRate:(stars)=>castVote(recipe,stars,taste:false), onTaste:(stars)=>castVote(recipe,stars,taste:true),
      )));},child:const Text('Visualizza comunque'))],
    ));
    return;
  }
  Navigator.push(context,MaterialPageRoute(builder:(_)=>RecipePage(
    recipe:recipe,
    selected:favorites.contains(recipe.id),
    onFavorite:(){setState((){if(favorites.contains(recipe.id)){favorites.remove(recipe.id);}else{favorites.add(recipe.id);}});},
    onAdd:(item)=>setState(()=>shopping.add(item)),
    onAddAll:()=>setState(()=>shopping.addAll(recipe.ingredients)),
    rating:avgFor(recipe),
    tasteRating:avgFor(recipe,taste:true),
    ratingCount:countFor(recipe),
    tasteCount:countFor(recipe,taste:true),
    onRate:(stars)=>castVote(recipe,stars,taste:false),
    onTaste:(stars)=>castVote(recipe,stars,taste:true),
  )));
 }

 void fridgePage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>FridgePage(recipes:all,onOpen:openRecipe)));
 void showFilters(){showModalBottomSheet(context:context,showDragHandle:true,isScrollControlled:true,builder:(c)=>StatefulBuilder(builder:(c,setM)=>Padding(padding:EdgeInsets.fromLTRB(20,8,20,20+MediaQuery.of(c).viewInsets.bottom),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Filtri',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:category,items:['Tutte','Antipasti','Primi','Secondi','Zuppe','Dolci','Pizze','Insalate'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setM(()=>category=v!)),const SizedBox(height:12),const Text('Stile alimentare',style:TextStyle(fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:7),Wrap(spacing:8,runSpacing:8,children:['Tutte','Vegetariano','Vegano','Senza glutine','Senza lattosio'].map((x)=>ChoiceChip(label:Text(x),selected:diet==x,onSelected:(_)=>setM(()=>diet=x))).toList()),const SizedBox(height:12),Text('Tempo massimo: $maxTime min',style:const TextStyle(fontWeight:FontWeight.w800,color:ink)),Slider(min:15,max:180,divisions:11,value:maxTime.toDouble(),label:'$maxTime min',onChanged:(v)=>setM(()=>maxTime=v.round())),const SizedBox(height:8),SizedBox(width:double.infinity,child:FilledButton(onPressed:(){Navigator.pop(c);_invalidateFilteredCache();setState((){});},child:const Text('Applica filtri')))])))));}
}

class AppPrivacySettingsPage extends StatefulWidget{const AppPrivacySettingsPage({super.key});@override State<AppPrivacySettingsPage> createState()=>_AppPrivacySettingsPageState();}
class _AppPrivacySettingsPageState extends State<AppPrivacySettingsPage>{
 bool analytics=true,promotional=false,serviceNotifications=true;
 @override void initState(){super.initState();SharedPreferences.getInstance().then((p){if(!mounted)return;setState((){analytics=p.getBool('rdm_pref_analytics')??true;promotional=p.getBool('rdm_pref_promotional')??false;serviceNotifications=p.getBool('rdm_pref_service_notifications')??true;});});}
 Future<void> save(String key,bool value)async{final p=await SharedPreferences.getInstance();await p.setBool(key,value);}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:cream,appBar:AppBar(backgroundColor:cream,title:const Text('Gestisci Privacy',style:TextStyle(fontWeight:FontWeight.w900))),body:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,30),children:[
  Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[green,green2]),borderRadius:BorderRadius.circular(26)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.shield_rounded,color:Colors.white,size:38),SizedBox(height:10),Text('Le tue preferenze, sotto il tuo controllo',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),SizedBox(height:7),Text('Puoi modificarle in qualsiasi momento.',style:TextStyle(color:Colors.white70,height:1.4))])),
  const SizedBox(height:14),Card(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),child:Column(children:[
   SwitchListTile(value:analytics,onChanged:(v){setState(()=>analytics=v);save('rdm_pref_analytics',v);},title:const Text('Statistiche di utilizzo',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Aiutano a migliorare l’app.'),secondary:const Icon(Icons.analytics_outlined,color:green)),
   if(AdConsentService.instance.privacyOptionsRequired)ListTile(leading:const Icon(Icons.ads_click_outlined,color:green),title:const Text('Gestisci consenso pubblicità',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Modifica in qualsiasi momento le scelte sulla pubblicità e sulla privacy.'),trailing:const Icon(Icons.chevron_right_rounded),onTap:()async{final ok=await AdConsentService.instance.showPrivacyOptions();if(!context.mounted)return;if(!ok)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Non è stato possibile aprire le preferenze pubblicitarie.')));}),
   SwitchListTile(value:promotional,onChanged:(v){setState(()=>promotional=v);save('rdm_pref_promotional',v);},title:const Text('Comunicazioni promozionali',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Offerte, novità e promozioni.'),secondary:const Icon(Icons.campaign_outlined,color:green)),
   SwitchListTile(value:serviceNotifications,onChanged:(v)async{setState(()=>serviceNotifications=v);await save('rdm_pref_service_notifications',v);await NotificationService.instance.setEnabled(v);if(!context.mounted)return;if(v)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Notifiche di servizio abilitate.')));},title:const Text('Notifiche di servizio',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Nuove ricette, comunicazioni importanti e aggiornamenti.'),secondary:const Icon(Icons.notifications_none_rounded,color:green)),
  ])),const SizedBox(height:12),
  ListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),leading:const Icon(Icons.description_outlined,color:green),title:const Text('Privacy Policy',style:TextStyle(fontWeight:FontWeight.w800)),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PrivacyPolicyPage()))),const SizedBox(height:8),
  ListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),leading:const Icon(Icons.gavel_outlined,color:green),title:const Text('Termini e Condizioni',style:TextStyle(fontWeight:FontWeight.w800)),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const TermsPage()))),const SizedBox(height:8),
  ListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),leading:const Icon(Icons.workspace_premium_outlined,color:green),title:const Text('Condizioni Premium',style:TextStyle(fontWeight:FontWeight.w800)),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PremiumTermsPage()))),const SizedBox(height:8),
  ListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),leading:const Icon(Icons.email_outlined,color:green),title:const Text('Contatta il titolare del trattamento',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('hardwaresolutionviterbo@gmail.com'),onTap:()=>showDialog(context:context,builder:(d)=>AlertDialog(title:const Text('Privacy e contatti'),content:const Text('Per richieste relative ai dati personali scrivi a hardwaresolutionviterbo@gmail.com.'),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Chiudi'))]))),const SizedBox(height:12),
  OutlinedButton.icon(onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('La richiesta di copia dei dati è stata registrata. Sarà collegata al sistema account online.'))),icon:const Icon(Icons.download_outlined),label:const Text('Richiedi una copia dei miei dati')),const SizedBox(height:8),
  OutlinedButton.icon(onPressed:()=>showDialog(context:context,builder:(d)=>AlertDialog(title:const Text('Elimina account e dati'),content:const Text('Questa operazione eliminerà account e dati associati dopo la conferma. Il collegamento alla cancellazione cloud sarà attivo con il sistema account.'),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Annulla')),FilledButton(onPressed:(){Navigator.pop(d);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Procedura di cancellazione pronta per l’account.')));},child:const Text('Continua'))])),icon:const Icon(Icons.delete_outline_rounded),label:const Text('Elimina account e dati')),
 ]));
}

class FavoriteButton extends StatefulWidget{final bool selected;final VoidCallback onTap;const FavoriteButton({super.key,required this.selected,required this.onTap});@override State<FavoriteButton> createState()=>_FavoriteButtonState();}
class _FavoriteButtonState extends State<FavoriteButton> with SingleTickerProviderStateMixin{late final c=AnimationController(vsync:this,duration:const Duration(milliseconds:260));@override void didUpdateWidget(covariant FavoriteButton old){super.didUpdateWidget(old);if(widget.selected&&!old.selected)c.forward(from:0);}@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext x)=>ScaleTransition(scale:Tween(begin:1.0,end:1.25).animate(CurvedAnimation(parent:c,curve:Curves.elasticOut)),child:IconButton(onPressed:(){widget.onTap();c.forward(from:0);},icon:Icon(widget.selected?Icons.favorite:Icons.favorite_border,color:widget.selected?Colors.red:Colors.black45)));}

class AllergenSettingsPage extends StatelessWidget{
 final Set<String> selected;
 final void Function(String,bool) onChanged;

 const AllergenSettingsPage({
   super.key,
   required this.selected,
   required this.onChanged,
 });

 @override
 Widget build(BuildContext context)=>Scaffold(
   backgroundColor:cream,
   appBar:AppBar(
     title:const Text(
       'Allergeni da evitare',
       style:TextStyle(fontWeight:FontWeight.w900),
     ),
     backgroundColor:cream,
   ),
   body:ListView(
     padding:const EdgeInsets.fromLTRB(16,10,16,30),
     children:[
       Container(
         padding:const EdgeInsets.all(20),
         decoration:BoxDecoration(
           gradient:const LinearGradient(
             begin:Alignment.topLeft,
             end:Alignment.bottomRight,
             colors:[Color(0xFF075B3A),Color(0xFF0C7A4B)],
           ),
           borderRadius:BorderRadius.circular(26),
         ),
         child:const Column(
           crossAxisAlignment:CrossAxisAlignment.start,
           children:[
             Icon(Icons.shield_outlined,color:Colors.white,size:38),
             SizedBox(height:10),
             Text(
               'Proteggi le tue preferenze',
               style:TextStyle(
                 color:Colors.white,
                 fontSize:24,
                 fontWeight:FontWeight.w900,
               ),
             ),
             SizedBox(height:7),
             Text(
               'Seleziona gli allergeni che vuoi evitare. Le ricette compatibili verranno filtrate e, se ne apri una con un possibile conflitto, riceverai un avviso prima di continuare.',
               style:TextStyle(color:Colors.white70,height:1.45),
             ),
           ],
         ),
       ),
       const SizedBox(height:16),
       ...allergenLabels.entries.map(
         (e)=>Card(
           margin:const EdgeInsets.only(bottom:8),
           shape:RoundedRectangleBorder(
             borderRadius:BorderRadius.circular(18),
           ),
           child:SwitchListTile(
             value:selected.contains(e.key),
             onChanged:(v)=>onChanged(e.key,v),
             secondary:Container(
               width:42,
               height:42,
               decoration:BoxDecoration(
                 color:const Color(0xFFEAF4EE),
                 borderRadius:BorderRadius.circular(13),
               ),
               child:const Icon(
                 Icons.warning_amber_rounded,
                 color:green,
               ),
             ),
             title:Text(
               e.value,
               style:const TextStyle(
                 fontWeight:FontWeight.w800,
                 color:ink,
               ),
             ),
             subtitle:const Text(
               'Usa sempre anche le etichette e le informazioni del prodotto.',
             ),
           ),
         ),
       ),
       const SizedBox(height:8),
       Container(
         padding:const EdgeInsets.all(16),
         decoration:BoxDecoration(
           color:const Color(0xFFFFF4DE),
           borderRadius:BorderRadius.circular(18),
           border:Border.all(
             color:const Color(0xFFE7C77D),
           ),
         ),
         child:const Text(
           "Il filtro è un aiuto informativo: non garantisce l'assenza di contaminazioni o tracce e non sostituisce il controllo dell'etichetta. In caso di allergia, verifica sempre gli ingredienti del prodotto utilizzato.",
           style:TextStyle(
             color:ink,
             fontSize:12.5,
             height:1.45,
             fontWeight:FontWeight.w600,
           ),
         ),
       ),
     ],
   ),
 );
}

class FoodSafetyPage extends StatelessWidget{const FoodSafetyPage({super.key});
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:cream,appBar:AppBar(title:const Text('Sicurezza alimentare',style:TextStyle(fontWeight:FontWeight.w900)),backgroundColor:cream),body:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,30),children:[
  Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF075B3A),Color(0xFF0C7A4B)]),borderRadius:BorderRadius.circular(28),boxShadow:[BoxShadow(color:Colors.black26,blurRadius:16,offset:Offset(0,7))]),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Icon(Icons.health_and_safety_rounded,color:Colors.white,size:42),SizedBox(height:12),
   Text('Cucina bene, cucina in sicurezza.',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900,height:1.1)),SizedBox(height:8),
   Text('Piccole attenzioni fanno la differenza quando prepari, conservi e servi il cibo.',style:TextStyle(color:Colors.white70,fontSize:14.5,height:1.45)),
  ])),
  const SizedBox(height:18),
  _SafetyCard(icon:Icons.warning_amber_rounded,title:'Allergeni',text:'Controlla sempre gli ingredienti e le etichette dei prodotti, soprattutto in presenza di allergie o intolleranze. Le ricette dell’app non sostituiscono il parere di un medico o di un professionista sanitario.'),
  _SafetyCard(icon:Icons.thermostat_rounded,title:'Cottura sicura',text:'Rispetta tempi e temperature indicati dalla ricetta e assicurati che carne, pesce, uova e altri alimenti a rischio siano cotti adeguatamente. Evita di consumare alimenti crudi o poco cotti quando possono comportare rischi.'),
  _SafetyCard(icon:Icons.kitchen_rounded,title:'Conservazione',text:'Conserva gli alimenti deperibili alla temperatura corretta, riponili rapidamente in frigorifero quando necessario e segui sempre le indicazioni riportate sulla confezione.'),
  _SafetyCard(icon:Icons.clean_hands_rounded,title:'Igiene in cucina',text:'Lava le mani, pulisci le superfici e separa gli alimenti crudi da quelli pronti al consumo per ridurre il rischio di contaminazioni.'),
  const SizedBox(height:8),
  Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFFFF4DE),borderRadius:BorderRadius.circular(22),border:Border.all(color:const Color(0xFFE7C77D))),child:const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.info_outline_rounded,color:Color(0xFFB66B13),size:24),SizedBox(width:12),Expanded(child:Text('Queste indicazioni hanno carattere generale e informativo. Per allergie, intolleranze, gravidanza, patologie o esigenze alimentari specifiche, segui le indicazioni del tuo medico o di un professionista qualificato.',style:TextStyle(color:ink,fontSize:13,height:1.45,fontWeight:FontWeight.w600)))])),
 ]));
}

class _SafetyCard extends StatelessWidget{final IconData icon;final String title;final String text;const _SafetyCard({required this.icon,required this.title,required this.text});
 @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),boxShadow:[BoxShadow(color:Colors.black12,blurRadius:12,offset:Offset(0,4))]),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:46,height:46,decoration:BoxDecoration(color:const Color(0xFFEAF4EE),borderRadius:BorderRadius.circular(15)),child:Icon(icon,color:green,size:25)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:6),Text(text,style:const TextStyle(fontSize:13.5,height:1.5,color:Colors.black54))]))]));
}

class PremiumPage extends StatefulWidget{const PremiumPage({super.key});@override State<PremiumPage> createState()=>_PremiumPageState();}
class _PremiumPageState extends State<PremiumPage>{
 int selectedPlan=1;
 final plans=const [('1 mese','€2,99','Rinnovo automatico','Si rinnova ogni mese'),('6 mesi','€14,99','Rinnovo automatico','Si rinnova ogni 6 mesi'),('12 mesi','€24,99','Rinnovo automatico','Si rinnova ogni 12 mesi'),('1 mese','€3,49','Una tantum','Nessun rinnovo automatico'),('6 mesi','€16,99','Una tantum','Nessun rinnovo automatico'),('12 mesi','€29,99','Una tantum','Nessun rinnovo automatico')];
 @override
 Widget build(BuildContext c) {
  return Scaffold(
   backgroundColor:cream,
   appBar:AppBar(title:const Text('Premium',style:TextStyle(fontWeight:FontWeight.w900))),
   body:ListView(
    padding:const EdgeInsets.fromLTRB(16,8,16,28),
    children:[
     Container(
      padding:const EdgeInsets.fromLTRB(22,24,22,26),
      decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF063D28),Color(0xFF0C7A4B)]),borderRadius:BorderRadius.circular(30),boxShadow:[BoxShadow(color:Colors.black26,blurRadius:16,offset:Offset(0,8))]),
      child:Column(children:[
       const Icon(Icons.workspace_premium,size:58,color:orange),
       const SizedBox(height:8),
       const Text('Ricette del Mondo Premium',textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.w900)),
       const SizedBox(height:7),
       const Text('Più ricette. Più viaggi. Più sapori.',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFFFFD889),fontSize:18,fontWeight:FontWeight.w700)),
       const SizedBox(height:8),
       const Text('Un mondo di ricette esclusive, raccolte speciali e strumenti per organizzare la tua cucina.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white70,fontSize:14)),
      ]),
     ),
     const SizedBox(height:18),
     Card(
      color:Colors.white,elevation:1,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
      child:Padding(
       padding:const EdgeInsets.fromLTRB(12,8,12,10),
       child:Column(children:[
        const Padding(padding:EdgeInsets.all(8),child:Row(children:[Icon(Icons.workspace_premium,color:orange),SizedBox(width:8),Expanded(child:Text('Cosa ottieni con Premium',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:ink)))])),
        ...['Accesso a tutte le ricette Premium','Ingredienti e procedimenti completi','Storie, varianti e curiosità','Raccolte speciali: Impasti, Hamburger e Braceria','Lista della spesa e funzione frigo','Esperienza senza pubblicità'].map((x)=>ListTile(dense:true,leading:const Icon(Icons.check_circle,color:green),title:Text(x,style:const TextStyle(fontWeight:FontWeight.w600)))),
       ]),
      ),
     ),
     const SizedBox(height:18),
     const Text('Scegli il tuo abbonamento',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:ink)),
     const SizedBox(height:6),
     const Text('Puoi scegliere il rinnovo automatico oppure un acquisto una tantum.',style:TextStyle(fontSize:13,color:Colors.black54)),
     const SizedBox(height:8),
     ...List.generate(plans.length,(i){
      final p=plans[i];
      final sel=selectedPlan==i;
      return Padding(
       padding:const EdgeInsets.only(bottom:10),
       child:InkWell(
        borderRadius:BorderRadius.circular(20),
        onTap:()=>setState(()=>selectedPlan=i),
        child:AnimatedContainer(
         duration:const Duration(milliseconds:180),
         padding:const EdgeInsets.all(16),
         decoration:BoxDecoration(color:sel?const Color(0xFFFFF4DE):Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:sel?orange:Colors.black12,width:sel?2:1),boxShadow:sel?[const BoxShadow(color:Colors.black12,blurRadius:8,offset:Offset(0,4))]:null),
         child:Row(children:[
          Container(width:28,height:28,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:sel?orange:Colors.black38,width:2),color:sel?orange:Colors.transparent),child:sel?const Icon(Icons.check,color:Colors.white,size:18):null),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Row(children:[Text(p.$1,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:ink)),if(i==1)Container(margin:const EdgeInsets.only(left:8),padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:green,borderRadius:BorderRadius.circular(10)),child:const Text('PIÙ SCELTO',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w900)))]),
           Text(p.$3,style:const TextStyle(color:green,fontWeight:FontWeight.w700)),
           Text(p.$4,style:const TextStyle(fontSize:11,color:Colors.black54)),
          ])),
          Text(p.$2,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:green)),
         ]),
        ),
       ),
      );
     }),
     const SizedBox(height:8),
     FilledButton(
      style:FilledButton.styleFrom(backgroundColor:orange,foregroundColor:ink,minimumSize:const Size.fromHeight(54),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),
      onPressed:(){final p=plans[selectedPlan];ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('${p.$1} — ${p.$2} (${p.$3}). Il pagamento reale sarà collegato a Google Play Billing in fase di pubblicazione.')));},
      child:Text('${plans[selectedPlan].$3 == 'Una tantum' ? 'Acquista' : 'Attiva'} ${plans[selectedPlan].$1} — ${plans[selectedPlan].$2}',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
     ),
     const SizedBox(height:8),
     const Text('Puoi scegliere il piano prima del pagamento. Le condizioni di acquisto e rinnovo saranno mostrate chiaramente prima della conferma.',textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Colors.black54)),
    ],
   ),
  );
 }
}

class PaywallPage extends StatelessWidget{final Recipe recipe;final VoidCallback onPremium;const PaywallPage({super.key,required this.recipe,required this.onPremium});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Anteprima Premium')),body:ListView(padding:const EdgeInsets.all(18),children:[recipeVisual(recipe,height:260),const SizedBox(height:12),Text('${flag(recipe.country)} ${recipe.country}',style:const TextStyle(fontWeight:FontWeight.w800,color:green)),Text(recipe.title,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:7),Text(recipe.description),const SizedBox(height:14),Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:pale,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('📖 La storia del piatto',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:7),Text(recipe.history,maxLines:5,overflow:TextOverflow.ellipsis)])),const SizedBox(height:14),const Text('🔒 Ingredienti e procedimento completo sono disponibili con Premium.',style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:16),FilledButton(onPressed:onPremium,child:const Text('Scopri i piani Premium'))]));}

class RecipePage extends StatefulWidget{
  final Recipe recipe; final bool selected; final VoidCallback onFavorite; final ValueChanged<String> onAdd; final VoidCallback onAddAll;
  final double rating,tasteRating; final int ratingCount,tasteCount; final ValueChanged<int> onRate,onTaste;
  const RecipePage({super.key,required this.recipe,required this.selected,required this.onFavorite,required this.onAdd,required this.onAddAll,required this.rating,required this.tasteRating,required this.ratingCount,required this.tasteCount,required this.onRate,required this.onTaste});
  @override State<RecipePage> createState()=>_RecipePageState();
}

class _RecipePageState extends State<RecipePage>{
  late int servings;
  late bool isFavorite;
  late final ScrollController scrollController;
  final ingredientsKey=GlobalKey();
  final preparationKey=GlobalKey();
  final ratingsKey=GlobalKey();
  final historyKey=GlobalKey();
  int activeTab=0;

  @override void initState(){
    super.initState();
    servings=widget.recipe.servings;
    isFavorite=widget.selected;
    scrollController=ScrollController();
  }

  @override void didUpdateWidget(covariant RecipePage oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.selected!=widget.selected)isFavorite=widget.selected;
  }

  @override void dispose(){scrollController.dispose();super.dispose();}

  String scaleIng(String s){
    final factor=widget.recipe.servings==0?1.0:servings/widget.recipe.servings;
    String fmt(double v)=>v==v.roundToDouble()?v.toInt().toString():v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'),'');
    String scale(String raw){final v=double.tryParse(raw.replaceAll(',','.'));return v==null?raw:fmt(v*factor);}
    final range=RegExp(r'^\s*(\d+(?:[\.,]\d+)?)\s*[–-]\s*(\d+(?:[\.,]\d+)?)(\s+.*)$').firstMatch(s);
    if(range!=null)return '${scale(range.group(1)!)}–${scale(range.group(2)!)}${range.group(3)!}';
    final fraction=RegExp(r'^\s*(\d+)\s*/\s*(\d+)(\s+.*)$').firstMatch(s);
    if(fraction!=null){final v=int.parse(fraction.group(1)!)/int.parse(fraction.group(2)!);return '${fmt(v*factor)}${fraction.group(3)!}';}
    final leading=RegExp(r'^\s*(\d+(?:[\.,]\d+)?)(\s+.*)$').firstMatch(s);
    if(leading!=null)return '${scale(leading.group(1)!)}${leading.group(2)!}';
    return s;
  }

  void jumpTo(GlobalKey key,int index){
    setState(()=>activeTab=index);
    WidgetsBinding.instance.addPostFrameCallback((_){
      final ctx=key.currentContext;
      if(ctx!=null && mounted){
        Scrollable.ensureVisible(ctx,duration:const Duration(milliseconds:450),curve:Curves.easeOutCubic,alignment:0.08);
      }
    });
  }

  @override Widget build(BuildContext c){
    final r=widget.recipe;
    return Scaffold(
      backgroundColor:cream,
      appBar:AppBar(
        backgroundColor:cream,
        elevation:0,
        surfaceTintColor:Colors.transparent,
        title:const Text('Ricetta',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),
        actions:[
          IconButton(tooltip:'Condividi',onPressed:()=>SharePlus.instance.share(ShareParams(text:'${r.title} — Ricette del Mondo')),icon:const Icon(Icons.ios_share_rounded,color:ink)),
          Padding(padding:const EdgeInsets.only(right:8),child:FavoriteButton(selected:isFavorite,onTap:(){setState(()=>isFavorite=!isFavorite);widget.onFavorite();})),
        ],
      ),
      body:ListView(
        controller:scrollController,
        padding:const EdgeInsets.fromLTRB(16,4,16,118),
        children:[
          _hero(r),
          const SizedBox(height:14),
          _overview(r),
          const SizedBox(height:12),
          _sectionTabs(),
          const SizedBox(height:14),
          KeyedSubtree(key:ingredientsKey,child:_ingredientsSection(r)),
          const SizedBox(height:16),
          KeyedSubtree(key:preparationKey,child:_preparationSection(r)),
          const SizedBox(height:16),
          KeyedSubtree(key:ratingsKey,child:_ratingsSection(r)),
          const SizedBox(height:16),
          KeyedSubtree(key:historyKey,child:_historyAndVariants(r)),
        ],
      ),
      bottomNavigationBar:_bottomActions(),
    );
  }

  Widget _hero(Recipe r)=>ClipRRect(
    borderRadius:BorderRadius.circular(30),
    child:SizedBox(
      height:300,
      child:Stack(fit:StackFit.expand,children:[
        recipeVisual(r,height:300,radius:BorderRadius.circular(30)),
        DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black.withValues(alpha:.08),Colors.transparent,Colors.black.withValues(alpha:.22)]))),
        Positioned(left:14,top:14,child:_glassLabel('${flag(r.country)}  ${r.country}')),
        Positioned(right:14,top:14,child:Row(children:[
          _heroAction(Icons.favorite,isFavorite?Colors.red:ink,(){setState(()=>isFavorite=!isFavorite);widget.onFavorite();}),
          const SizedBox(width:8),
          _heroAction(Icons.ios_share_rounded,ink,()=>SharePlus.instance.share(ShareParams(text:'${r.title} — Ricette del Mondo'))),
        ])),
      ]),
    ),
  );

  Widget _glassLabel(String text)=>Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:8),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.93),borderRadius:BorderRadius.circular(18)),child:Text(text,style:const TextStyle(color:green,fontWeight:FontWeight.w900,fontSize:14)));
  Widget _heroAction(IconData icon,Color color,VoidCallback onTap)=>Material(color:Colors.white.withValues(alpha:.94),shape:const CircleBorder(),child:InkWell(customBorder:const CircleBorder(),onTap:onTap,child:SizedBox(width:44,height:44,child:Icon(icon,color:color,size:22))));

  Widget _overview(Recipe r)=>Container(
    padding:const EdgeInsets.fromLTRB(18,18,18,16),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(28),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.055),blurRadius:18,offset:const Offset(0,7))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(r.title,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900,color:ink,height:1.08)),
          if(r.description.isNotEmpty)Padding(padding:const EdgeInsets.only(top:7),child:Text(r.description,maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:14,height:1.35,color:Colors.black54))),
        ])),
      ]),
      const SizedBox(height:14),
      LayoutBuilder(builder:(context,box){
        final itemWidth=(box.maxWidth-18)/4;
        return Wrap(spacing:6,runSpacing:6,children:[
          _overviewStat(itemWidth,Icons.timer_outlined,'${r.prepMin} min','Preparazione'),
          _overviewStat(itemWidth,Icons.soup_kitchen_outlined,'${r.cookMin} min','Cottura'),
          _overviewStat(itemWidth,Icons.bar_chart_rounded,r.difficulty,'Difficoltà'),
          _overviewStat(itemWidth,Icons.people_alt_outlined,'$servings','Porzioni'),
        ]);
      }),
      const SizedBox(height:12),
      Row(children:[
        Expanded(child:FilledButton.icon(onPressed:()=>jumpTo(preparationKey,1),icon:const Icon(Icons.restaurant_rounded),label:const Text('Inizia a cucinare',style:TextStyle(fontWeight:FontWeight.w900)))),
        const SizedBox(width:8),
        _squareAction(Icons.favorite_border,'Salva',isFavorite?Colors.red:green,(){setState(()=>isFavorite=!isFavorite);widget.onFavorite();}),
        const SizedBox(width:8),
        _squareAction(Icons.playlist_add,'Piano',green,widget.onAddAll),
      ]),
    ]),
  );

  Widget _overviewStat(double width,IconData icon,String value,String label)=>SizedBox(width:width,child:Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:9),decoration:BoxDecoration(color:const Color(0xFFF4F8F5),borderRadius:BorderRadius.circular(16)),child:Column(children:[Icon(icon,color:green,size:19),const SizedBox(height:3),Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,color:ink,fontSize:12)),Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:8,color:Colors.black54))])));
  Widget _squareAction(IconData icon,String label,Color color,VoidCallback onTap)=>Material(color:const Color(0xFFF4F8F5),borderRadius:BorderRadius.circular(16),child:InkWell(borderRadius:BorderRadius.circular(16),onTap:onTap,child:SizedBox(width:58,height:54,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:color,size:20),Text(label,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:ink))]))));

  Widget _sectionTabs()=>Container(
    padding:const EdgeInsets.all(5),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.05),blurRadius:14,offset:const Offset(0,5))]),
    child:Row(children:[
      _tab('Ingredienti',Icons.eco_outlined,ingredientsKey,0),
      _tab('Preparazione',Icons.restaurant_menu,preparationKey,1),
      _tab('Valutazioni',Icons.star_border,ratingsKey,2),
      _tab('Storia',Icons.menu_book_outlined,historyKey,3),
    ]),
  );

  Widget _tab(String text,IconData icon,GlobalKey key,int index)=>Expanded(child:InkWell(onTap:()=>jumpTo(key,index),borderRadius:BorderRadius.circular(17),child:AnimatedContainer(duration:const Duration(milliseconds:220),padding:const EdgeInsets.symmetric(vertical:10,horizontal:2),decoration:BoxDecoration(color:activeTab==index?const Color(0xFFE5F3EB):Colors.transparent,borderRadius:BorderRadius.circular(17)),child:Column(children:[Icon(icon,size:20,color:activeTab==index?green:ink),const SizedBox(height:4),Text(text,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:10,fontWeight:activeTab==index?FontWeight.w900:FontWeight.w600,color:activeTab==index?green:ink))]))));

  Widget _ingredientsSection(Recipe r)=>Container(
    padding:const EdgeInsets.fromLTRB(16,17,16,15),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(28),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.045),blurRadius:16,offset:const Offset(0,6))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFFE7F4EC),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.shopping_basket_outlined,color:green)),
        const SizedBox(width:10),
        const Expanded(child:Text('Ingredienti',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink))),
        _servingsControl(),
      ]),
      const SizedBox(height:12),
      Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:(){widget.onAddAll();ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('🛒 Tutti gli ingredienti sono stati aggiunti alla lista della spesa'),behavior:SnackBarBehavior.floating));},icon:const Icon(Icons.add_shopping_cart,color:green,size:18),label:const Text('Aggiungi tutti',style:TextStyle(color:green,fontWeight:FontWeight.w900)))),
      const SizedBox(height:2),
      ...r.ingredients.map((x)=>Padding(padding:const EdgeInsets.only(bottom:7),child:_ingredientTile(scaleIng(x)))),
    ]),
  );

  Widget _servingsControl()=>Container(padding:const EdgeInsets.symmetric(horizontal:3,vertical:2),decoration:BoxDecoration(color:const Color(0xFFF0F6F2),borderRadius:BorderRadius.circular(18)),child:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'Diminuisci porzioni',visualDensity:VisualDensity.compact,onPressed:servings>1?()=>setState(()=>servings--):null,icon:const Icon(Icons.remove,size:19)),Text('$servings',style:const TextStyle(fontWeight:FontWeight.w900,color:ink)),IconButton(tooltip:'Aumenta porzioni',visualDensity:VisualDensity.compact,onPressed:()=>setState(()=>servings++),icon:const Icon(Icons.add,size:19))]));

  Widget _ingredientTile(String text)=>Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:10),decoration:BoxDecoration(color:const Color(0xFFFBFAF6),borderRadius:BorderRadius.circular(17),border:Border.all(color:const Color(0xFFF0ECE3))),child:Row(children:[Container(width:8,height:8,decoration:const BoxDecoration(color:green,shape:BoxShape.circle)),const SizedBox(width:10),Expanded(child:Text(text,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:ink))),IconButton(tooltip:'Aggiungi alla spesa',visualDensity:VisualDensity.compact,onPressed:(){widget.onAdd(text);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('🛒 Aggiunto alla lista della spesa'),behavior:SnackBarBehavior.floating));},icon:const Icon(Icons.add_shopping_cart,color:green,size:20))]));

  Widget _preparationSection(Recipe r)=>Container(
    padding:const EdgeInsets.fromLTRB(16,17,16,15),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(28),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.045),blurRadius:16,offset:const Offset(0,6))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFFE7F4EC),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.restaurant_menu,color:green)),const SizedBox(width:10),const Expanded(child:Text('Preparazione',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink))),if(r.cookMin>0)Text('${r.cookMin} min',style:const TextStyle(color:green,fontWeight:FontWeight.w900))]),
      const SizedBox(height:14),
      CookingGuide(recipe:r),
      if(r.cookMin>0 || r.cookingDetail.isNotEmpty)const SizedBox(height:12),
      ...r.steps.asMap().entries.map((e)=>_stepCard(e.key+1,e.value)),
    ]),
  );

  Widget _stepCard(int number,String text)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:const Color(0xFFFCFBF8),borderRadius:BorderRadius.circular(19),border:Border.all(color:const Color(0xFFEDE8DE))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:38,height:38,alignment:Alignment.center,decoration:const BoxDecoration(color:green,shape:BoxShape.circle),child:Text('$number',style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w900))),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Passaggio $number',style:const TextStyle(color:green,fontWeight:FontWeight.w900,fontSize:11)),const SizedBox(height:4),Text(text,style:const TextStyle(fontSize:14,height:1.42,color:ink))]))]));

  Widget _ratingsSection(Recipe r)=>Container(padding:const EdgeInsets.all(2),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(28),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.045),blurRadius:16,offset:const Offset(0,6))]),child:RatingPanel(recipe:r,rating:widget.rating,taste:widget.tasteRating,ratingCount:widget.ratingCount,tasteCount:widget.tasteCount,onRate:widget.onRate,onTaste:widget.onTaste));

  Widget _historyAndVariants(Recipe r)=>Column(children:[
    Container(
      padding:const EdgeInsets.fromLTRB(17,18,17,17),
      decoration:BoxDecoration(
        color:Colors.white,
        borderRadius:BorderRadius.circular(28),
        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.045),blurRadius:16,offset:const Offset(0,6))],
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFFF4EBD8),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.menu_book_outlined,color:green)),
          const SizedBox(width:10),
          const Text('La storia',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),
        ]),
        const SizedBox(height:13),
        Text(r.history,style:const TextStyle(height:1.5,color:ink)),
      ]),
    ),
    if(r.variants.isNotEmpty)
      Padding(
        padding:const EdgeInsets.only(top:12),
        child:Container(
          padding:const EdgeInsets.fromLTRB(17,17,17,14),
          decoration:BoxDecoration(color:const Color(0xFFF6F1E7),borderRadius:BorderRadius.circular(28)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Varianti della ricetta',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:ink)),
            const SizedBox(height:9),
            ...r.variants.map((v)=>Padding(
              padding:const EdgeInsets.only(bottom:8),
              child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Icon(Icons.check_circle_outline,color:green,size:18),
                const SizedBox(width:8),
                Expanded(child:Text(v,style:const TextStyle(height:1.35))),
              ]),
            )),
          ]),
        ),
      ),
  ]);

  Widget _bottomActions()=>SafeArea(
    top:false,
    child:Container(
      padding:const EdgeInsets.fromLTRB(12,9,12,8),
      decoration:BoxDecoration(
        color:Colors.white,
        borderRadius:const BorderRadius.vertical(top:Radius.circular(25)),
        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.10),blurRadius:20,offset:const Offset(0,-6))],
      ),
      child:Row(children:[
        Expanded(
          child:SizedBox(
            height:54,
            child:FilledButton.icon(
              onPressed:()=>jumpTo(preparationKey,1),
              icon:const Icon(Icons.restaurant_rounded),
              label:const Text('Inizia a cucinare',style:TextStyle(fontWeight:FontWeight.w900,fontSize:15)),
            ),
          ),
        ),
        const SizedBox(width:8),
        SizedBox(
          width:56,
          height:54,
          child:FilledButton.tonal(
            onPressed:(){setState(()=>isFavorite=!isFavorite);widget.onFavorite();},
            child:Icon(isFavorite?Icons.favorite:Icons.favorite_border,color:isFavorite?Colors.red:green),
          ),
        ),
        const SizedBox(width:8),
        SizedBox(
          width:56,
          height:54,
          child:FilledButton.tonal(
            onPressed:widget.onAddAll,
            child:const Icon(Icons.playlist_add,color:green),
          ),
        ),
      ]),
    ),
  );

}

class CookingGuide extends StatelessWidget {
  final Recipe recipe;
  const CookingGuide({super.key, required this.recipe});

  @override
  Widget build(BuildContext c) {
    if (recipe.cookMin <= 0 && recipe.cookingDetail.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DFD1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔥 Cottura precisa',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (recipe.cookingMethod.isNotEmpty)
                infoChip(Icons.soup_kitchen, recipe.cookingMethod),
              infoChip(Icons.timer_outlined, '${recipe.cookMin} min'),
              if (recipe.cookingTempC != null)
                infoChip(Icons.thermostat_outlined, '${recipe.cookingTempC} °C'),
            ],
          ),
          if (recipe.cookingDetail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(recipe.cookingDetail, style: const TextStyle(height: 1.35)),
            ),
        ],
      ),
    );
  }
}
Widget infoChip(IconData icon,String text)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),decoration:BoxDecoration(color:pale,borderRadius:BorderRadius.circular(13)),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:17,color:green),const SizedBox(width:5),Text(text,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:ink))]));

class RatingPanel extends StatefulWidget {
  final Recipe recipe;
  final double rating, taste;
  final int ratingCount, tasteCount;
  final ValueChanged<int> onRate, onTaste;

  const RatingPanel({
    super.key,
    required this.recipe,
    required this.rating,
    this.taste=0,
    required this.ratingCount,
    required this.tasteCount,
    required this.onRate,
    required this.onTaste,
  });

  @override
  State<RatingPanel> createState() => _RatingPanelState();
}

class _RatingPanelState extends State<RatingPanel> {
  late double _rating;
  late double _taste;
  late int _ratingCount;
  late int _tasteCount;
  int _myRating = 0;
  int _myTaste = 0;

  @override
  void initState() {
    super.initState();
    _rating = widget.rating;
    _taste = widget.taste;
    _ratingCount = widget.ratingCount;
    _tasteCount = widget.tasteCount;
  }

  void _vote({required int stars, required bool taste}) {
    setState(() {
      if (taste) {
        final firstVote = _myTaste == 0;
        _myTaste = stars;
        _taste = stars.toDouble();
        _tasteCount = firstVote ? (widget.tasteCount + 1) : widget.tasteCount;
      } else {
        final firstVote = _myRating == 0;
        _myRating = stars;
        _rating = stars.toDouble();
        _ratingCount = firstVote ? (widget.ratingCount + 1) : widget.ratingCount;
      }
    });

    if (taste) {
      widget.onTaste(stars);
    } else {
      widget.onRate(stars);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(taste
            ? '⭐ Bontà: $stars/5 — voto registrato'
            : '⭐ Valutazione ricetta: $stars/5 — voto registrato'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget row(String title, double value, int count, int selected,
      ValueChanged<int> onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 2,
          children: List.generate(5, (i) {
            final active = selected > 0 ? i < selected : i < value.round();
            return IconButton(
              tooltip: '${i + 1} stelle',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              onPressed: () => onTap(i + 1),
              icon: Icon(
                active ? Icons.star : Icons.star_border,
                color: orange,
                size: 27,
              ),
            );
          }),
        ),
        const SizedBox(height: 2),
        Text(
          count == 0
              ? 'Ancora nessun voto'
              : '${value.toStringAsFixed(1)} / 5 • $count voti',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⭐ La tua valutazione',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink),
          ),
          const SizedBox(height: 8),
          row('Voto della ricetta', _rating, _ratingCount, _myRating,
              (v) => _vote(stars: v, taste: false)),
          const SizedBox(height: 10),
          row('Bontà', _taste, _tasteCount, _myTaste,
              (v) => _vote(stars: v, taste: true)),
        ],
      ),
    );
  }
}

class SpecialCollectionPage extends StatelessWidget {
  final String title, subtitle;
  final List<Recipe> recipes;
  final IconData icon;

  const SpecialCollectionPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.recipes,
    required this.icon,
  });

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [green, green2]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(icon, color: orange, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (recipes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Icon(Icons.auto_awesome, color: orange, size: 40),
                    const SizedBox(height: 8),
                    const Text(
                      'Questa raccolta è pronta per essere ampliata con nuove ricette editoriali.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recipes.map(
              (r) => Card(
                child: ListTile(
                  leading: SizedBox(
                    width: 72,
                    height: 72,
                    child: specialVisual(r, height: 72, radius: BorderRadius.circular(12)),
                  ),
                  title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w900, color: ink)),
                  subtitle: Text(
                    r.chef.isEmpty
                        ? '${flag(r.country)} ${r.country} • ${r.cookMin} min'
                        : '${flag(r.country)} ${r.country} • Ricetta di ${r.chef}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    c,
                    MaterialPageRoute(builder: (_) => SimpleRecipePreview(recipe: r)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SimpleRecipePreview extends StatelessWidget{final Recipe recipe;const SimpleRecipePreview({super.key,required this.recipe});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(recipe.title)),body:ListView(padding:const EdgeInsets.all(18),children:[specialVisual(recipe,height:250,radius:BorderRadius.circular(22)),const SizedBox(height:12),Text('${flag(recipe.country)} ${recipe.country}',style:const TextStyle(color:green,fontWeight:FontWeight.w800)),Text(recipe.title,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:ink)),if(recipe.chef.isNotEmpty)Padding(padding:const EdgeInsets.only(top:6),child:Text('Ricetta di ${recipe.chef}',style:const TextStyle(fontWeight:FontWeight.w800,color:orange))),const SizedBox(height:14),CookingGuide(recipe:recipe),const SizedBox(height:14),const Text('Ingredienti',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:ink)),...recipe.ingredients.map((x)=>ListTile(leading:const Icon(Icons.circle,size:7,color:green),title:Text(x))),const Text('Preparazione',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:ink)),...recipe.steps.asMap().entries.map((e)=>ListTile(leading:CircleAvatar(radius:14,backgroundColor:green,child:Text('${e.key+1}',style:const TextStyle(color:Colors.white,fontSize:12))),title:Text(e.value)))]));}

class ShoppingPage extends StatefulWidget{final Set<String> items;const ShoppingPage({super.key,required this.items});@override State<ShoppingPage> createState()=>_ShoppingPageState();}
class _ShoppingPageState extends State<ShoppingPage>{final done=<String>{};@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Lista della spesa')),body:ListView(padding:const EdgeInsets.all(18),children:[Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[const Row(children:[Icon(Icons.shopping_cart,color:green),SizedBox(width:8),Text('I tuoi ingredienti',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:ink))]),const SizedBox(height:8),...widget.items.map((x)=>CheckboxListTile(value:done.contains(x),onChanged:(v)=>setState(()=>v==true?done.add(x):done.remove(x)),title:Text(x),controlAffinity:ListTileControlAffinity.leading)),FilledButton.icon(onPressed:(){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Lista pronta per la spesa')));},icon:const Icon(Icons.check),label:const Text('Ho finito'))])))]));}

class FridgePage extends StatefulWidget{final List<Recipe> recipes;final ValueChanged<Recipe> onOpen;const FridgePage({super.key,required this.recipes,required this.onOpen});@override State<FridgePage> createState()=>_FridgePageState();}
class _FridgePageState extends State<FridgePage>{final selected=<String>{};final search=TextEditingController();final ingredients=['uova','farina','pomodori','cipolla','aglio','olio','burro','latte','formaggio','pollo','riso','pasta','patate','pesce','carne','limone','basilico','pepe','zucchine','melanzane'];@override Widget build(BuildContext c){final q=search.text.toLowerCase();final shown=ingredients.where((x)=>q.isEmpty||x.contains(q)).toList();final ranked=widget.recipes.map((r){final hay=r.ingredients.join(' ').toLowerCase();final missing=selected.where((s)=>!hay.contains(s)).length;final match=selected.isEmpty?0:missing;return (r,match);}).where((x)=>selected.isEmpty||x.$2<selected.length).toList()..sort((a,b)=>a.$2.compareTo(b.$2));return Scaffold(appBar:AppBar(title:const Text('Cosa hai nel frigo?')),body:ListView(padding:const EdgeInsets.all(18),children:[const Text('Scegli gli ingredienti che hai',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:8),TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Cerca un ingrediente...')),const SizedBox(height:10),Wrap(spacing:7,runSpacing:7,children:shown.map((x)=>FilterChip(label:Text(x),selected:selected.contains(x),onSelected:(v)=>setState(()=>v?selected.add(x):selected.remove(x)))).toList()),const SizedBox(height:16),Text(selected.isEmpty?'Seleziona almeno un ingrediente.':'${ranked.length} ricette con pochi ingredienti mancanti',style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),...ranked.take(20).map((x)=>Card(child:ListTile(leading:SizedBox(width:62,height:62,child:recipeVisual(x.$1,height:62,radius:BorderRadius.circular(10))),title:Text(x.$1.title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${flag(x.$1.country)} ${x.$1.country} • ${x.$2} mancanti'),trailing:const Icon(Icons.chevron_right),onTap:()=>widget.onOpen(x.$1))))]));}}
