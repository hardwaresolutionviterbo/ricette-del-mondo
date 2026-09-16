import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'notification_service.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'recipe.dart';
import 'recipe_photo_service.dart';
import 'ingredient_photo_service.dart';
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
  // La UI parte immediatamente. Firebase, consenso, annunci e notifiche sono
  // servizi non critici e non devono bloccare il primo frame.
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

  await Future<void>.delayed(const Duration(milliseconds: 1800));
  try {
    final canRequestAds = await AdConsentService.instance.initialize();
    if (canRequestAds) {
      await MobileAds.instance.initialize();
      if (AdConsentService.instance.canRequestAds) {
        AdService.instance.preload();
      }
    }
  } catch (_) {
    // Gli annunci sono opzionali.
  }

  await Future<void>.delayed(const Duration(milliseconds: 1200));
  try {
    await NotificationService.instance.initialize();
  } catch (_) {
    // Le notifiche sono opzionali.
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

Widget recipeVisual(Recipe r,{double height=170,BorderRadius? radius,bool allowNetwork=false})=>RecipePhoto(recipe:r,height:height,radius:radius??BorderRadius.circular(18),allowNetwork:allowNetwork);

Widget specialVisual(Recipe r,{double height=170,BorderRadius? radius,bool allowNetwork=false})=>recipeVisual(r,height:height,radius:radius,allowNetwork:allowNetwork);

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  double progress = 0;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      await RecipeRepository().loadRecipes(onProgress: (value) {
        if (mounted) setState(() => progress = value.clamp(0.0, 1.0));
      });
    } catch (_) {
      // AppShell tenterà comunque di usare il repository/cache disponibile.
    }
    if (!mounted) return;
    setState(() {
      progress = 1;
      ready = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    final count = (progress * 10000).round().clamp(0, 10000);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/splash_v6.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .08),
                      Colors.black.withValues(alpha: .20),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 42,
              child: Column(
                children: [
                  Text(
                    ready ? 'Catalogo pronto' : 'Caricamento ricette...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 5)],
                    ),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .35),
                        border: Border.all(color: Colors.white70),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFD89A32), Color(0xFFFFE0A0)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 5)],
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '$count di 10.000 ricette caricate',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 5)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RicetteApp extends StatelessWidget{const RicetteApp({super.key});@override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Ricette del Mondo',theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:cream,colorScheme:ColorScheme.fromSeed(seedColor:green),fontFamily:'sans-serif',appBarTheme:const AppBarTheme(backgroundColor:cream,foregroundColor:ink,elevation:0)),home:const SplashPage());}

class AppShell extends StatefulWidget{const AppShell({super.key});@override State<AppShell> createState()=>_AppShellState();}
class _AppShellState extends State<AppShell>{
 String? profilePhotoPath;
 final ImagePicker _profilePicker = ImagePicker();
 final repo=RecipeRepository(), search=TextEditingController();
 List<Recipe> all=[];
 late List<Recipe> _catalog;
 Map<String,Recipe> _recipeById=<String,Recipe>{};
 List<Recipe> _premiumFreeCache=const [];
 List<Recipe> _hamburgerCache=const [];
 List<Recipe> _braceriaCache=const [];
 List<Recipe> _gourmetCache=const [];
 final favorites=<String>{}, shopping=<String>{};
 final ratings=<String,RatingStats>{}, tasteRatings=<String,RatingStats>{};
 final userRatings=<String,int>{}, userTasteRatings=<String,int>{};
 final avoidedAllergens=<String>{};
 final Map<String,String> _searchHaystack=<String,String>{};
 final Map<String,String> _fullTextCache=<String,String>{};
 final Map<String,Set<String>> _allergenCache=<String,Set<String>>{};
 Timer? _searchDebounce;
 List<Recipe>? _filteredCache;
 String _filteredSignature='';
 int _italianCount=0;
 int tab=0;
 String category='Tutte',diet='Tutte',language='Italiano';
 int maxTime=180;

 List<Recipe> get catalog=>_catalog;
 List<Recipe> get premiumFreeRecipes=>_premiumFreeCache;

 void _invalidateFilterCache(){
  _filteredCache=null;
  _filteredSignature='';
 }

 void _prepareCatalog(List<Recipe> recipes) {
  all=recipes;
  _catalog=List<Recipe>.unmodifiable([...recipes,...specialDoughRecipes]);
  _recipeById={for(final r in _catalog)r.id:r};
  _italianCount=all.where((r)=>r.country.toLowerCase()=='italia').length;

  final pool=all.where((r)=>!r.premium).toList(growable:false);
  if(pool.length<=10){
    _premiumFreeCache=List<Recipe>.unmodifiable(pool);
  }else{
    final day=DateTime.now().difference(DateTime(2020,1,1)).inDays;
    final cycle=day%5;
    final shuffled=List<Recipe>.from(pool)..shuffle(math.Random(0x5A17));
    final start=cycle*10;
    _premiumFreeCache=List<Recipe>.unmodifiable(
      start+10<=shuffled.length ? shuffled.sublist(start,start+10) : shuffled.take(10),
    );
  }

  _hamburgerCache=List<Recipe>.unmodifiable([
    ...specialHamburgerRecipes,
    ...catalog.where((r)=>r.title.toLowerCase().contains('hamburger') || r.tags.any((t)=>t.toLowerCase().contains('burger'))),
  ]);
  _braceriaCache=List<Recipe>.unmodifiable([
    ...specialBraceriaRecipes,
    ...catalog.where((r)=>r.tags.any((t)=>['carne','griglia','brace','bbq','pollo'].contains(t.toLowerCase())) || r.title.toLowerCase().contains('asado') || r.title.toLowerCase().contains('pulled')),
  ]);
  _gourmetCache=List<Recipe>.unmodifiable(
    catalog.where((r)=>r.tags.any((t)=>t.toLowerCase()=='gourmet')),
  );
  _invalidateFilterCache();
 }

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
  final cached=RecipeRepository.cachedRecipes;
  if(cached!=null){
    _prepareCatalog(cached);
  }else{
    repo.loadRecipes().then((r){if(!mounted)return;setState(()=>_prepareCatalog(r));});
  }
  SharedPreferences.getInstance().then((p){
    if(!mounted)return;
    final allergens=p.getStringList('rdm_avoided_allergens')??const [];
    final photo=p.getString('rdm_profile_photo_path');
    if(allergens.isEmpty && photo==null)return;
    setState((){
      avoidedAllergens.addAll(allergens);
      profilePhotoPath=photo;
      _invalidateFilterCache();
    });
  });
}

 @override void dispose(){_searchDebounce?.cancel();search.dispose();super.dispose();}

 String _dietText(Recipe r)=>_fullTextCache.putIfAbsent(r.id,()=> '${r.title} ${r.description} ${r.ingredients.join(' ')} ${r.tags.join(' ')}'.toLowerCase());

 bool dietMatches(Recipe r,String selected){
  if(selected=='Tutte')return true;
  final t=_dietText(r);
  if(selected=='Vegetariano')return !RegExp(r'\b(carne|manzo|maiale|prosciutto|pollo|tacchino|agnello|salsiccia|pesce|salmone|tonno|merluzzo|gamberi|gambero|acciuga|acciughe)\b').hasMatch(t);
  if(selected=='Vegano')return !RegExp(r'\b(carne|manzo|maiale|prosciutto|pollo|tacchino|agnello|salsiccia|pesce|salmone|tonno|merluzzo|gamberi|gambero|uova|uovo|latte|burro|panna|formaggio|parmigiano|mozzarella|ricotta|yogurt|miele)\b').hasMatch(t);
  if(selected=='Senza glutine')return !allergenTerms['glutine']!.any((x)=>t.contains(x));
  if(selected=='Senza lattosio')return !allergenTerms['latte']!.any((x)=>t.contains(x));
  return true;
 }

 List<Recipe> get filtered{
  final s=search.text.trim().toLowerCase();
  final signature='$s|$category|$diet|$maxTime|${avoidedAllergens.join(',')}';
  if(_filteredCache!=null && _filteredSignature==signature)return _filteredCache!;
  if(s.isEmpty && category=='Tutte' && diet=='Tutte' && maxTime>=180 && avoidedAllergens.isEmpty){
    _filteredSignature=signature;
    _filteredCache=catalog;
    return catalog;
  }
  final tokens=s.split(RegExp(r'[, ]+')).where((x)=>x.isNotEmpty).toList(growable:false);
  final result=<Recipe>[];
  for(final r in catalog){
    if(category!='Tutte' && r.category!=category)continue;
    if(r.timeMin>maxTime)continue;
    if(diet!='Tutte' && !dietMatches(r,diet))continue;
    if(avoidedAllergens.isNotEmpty && _allergenCache.putIfAbsent(r.id,()=>detectAllergens(r)).intersection(avoidedAllergens).isNotEmpty)continue;
    if(tokens.isNotEmpty){
      final hay=_searchHaystack.putIfAbsent(r.id,()=> '${r.title} ${r.country} ${r.cuisine} ${r.category} ${r.ingredients.join(' ')} ${r.tags.join(' ')}'.toLowerCase());
      if(!tokens.every(hay.contains))continue;
    }
    result.add(r);
  }
  _filteredSignature=signature;
  _filteredCache=List<Recipe>.unmodifiable(result);
  return _filteredCache!;
 }

 Widget _currentPage(){
  switch(tab){
    case 1:return searchPage();
    case 2:return categoriesPage();
    case 3:return favoritesPage();
    case 4:return profilePage();
    default:return home();
  }
 }

 @override Widget build(BuildContext c){
  if(all.isEmpty)return const Scaffold(body:Center(child:CircularProgressIndicator()));
  return Scaffold(
    body:SafeArea(child:_currentPage()),
    bottomNavigationBar:NavigationBar(
      backgroundColor:Colors.white,
      indicatorColor:const Color(0xFFDCEFE5),
      selectedIndex:tab,
      onDestinationSelected:(i){if(i==tab)return;setState(()=>tab=i);},
      destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
        NavigationDestination(icon:Icon(Icons.search),label:'Cerca'),
        NavigationDestination(icon:Icon(Icons.grid_view_rounded),label:'Categorie'),
        NavigationDestination(icon:Icon(Icons.favorite_border),selectedIcon:Icon(Icons.favorite),label:'Preferiti'),
        NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profilo'),
      ],
    ),
  );
 }
 Widget logo({double h=96})=>Image.asset('assets/logo_rdm.png',height:h,fit:BoxFit.contain);
 Widget home(){final total=all.length;final italian=_italianCount;final world=total-italian;return ListView(padding:const EdgeInsets.fromLTRB(16,12,16,30),children:[homeHero(total,italian,world),const SizedBox(height:14),searchBox(),const SizedBox(height:14),dailyRecipeCard(),const SizedBox(height:14),fridgeBanner(),section('Speciali di Ricette del Mondo'),specialBanner('assets/banners/banner_impasti.png',onTap:()=>openSpecialPage('Speciale Impasti','Impasti per pizza e focaccia da fare a casa.',specialDoughRecipes,Icons.local_pizza)),specialBanner('assets/banners/banner_hamburger.png',onTap:()=>openSpecialPage('Speciale Hamburger','Una raccolta dedicata agli hamburger.',_hamburgerCache,Icons.lunch_dining)),specialBanner('assets/banners/banner_braceria.png',onTap:()=>openSpecialPage('Speciale Braceria','Ricette per griglia, brace e cotture lente.',_braceriaCache,Icons.outdoor_grill)),specialBanner('assets/banners/banner_gourmet.png',onTap:()=>openSpecialPage('Speciale Gourmet Stellato','Una raccolta editoriale di alta cucina.',_gourmetCache,Icons.auto_awesome)),section('Le 10 ricette gratuite',action:'Vedi tutte',onAction:()=>setState(()=>tab=1)),SizedBox(height:264,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.only(bottom:4),children:premiumFreeRecipes.map((r)=>miniCard(r)).toList())),ratingHomeSection('🏆 Ricette più votate',false),ratingHomeSection('😋 Ricette più buone',true),section('Esplora il mondo'),continentGrid(),section('Seguici sui social'),socialSection(),section('Scopri Premium'),premiumBanner(),section('Idee per te'),...all.skip(10).take(5).map(recipeCard)]);}
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
          Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Colors.transparent,Colors.black.withValues(alpha:.72)])))),
          Positioned(left:15,top:14,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:green,borderRadius:BorderRadius.circular(18),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.18),blurRadius:10)]),child:const Text('RICETTA DEL GIORNO',style:TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.8)))),
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
      boxShadow:[BoxShadow(color:green.withValues(alpha:.18),blurRadius:28,offset:const Offset(0,12))],
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
          Positioned(right:-70,top:-80,child:Container(width:250,height:250,decoration:BoxDecoration(shape:BoxShape.circle,color:Colors.white.withValues(alpha:.055)))),
          Positioned(left:-90,bottom:-115,child:Container(width:300,height:300,decoration:BoxDecoration(shape:BoxShape.circle,color:orange.withValues(alpha:.10)))),
          Padding(
            padding:const EdgeInsets.fromLTRB(20,18,20,18),
            child:Column(children:[
              Row(children:[
                Container(
                  padding:const EdgeInsets.symmetric(horizontal:13,vertical:8),
                  decoration:BoxDecoration(color:Colors.white.withValues(alpha:.10),borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white.withValues(alpha:.13))),
                  child:const Text('SAPORI SENZA CONFINI',style:TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.7)),
                ),
                const Spacer(),
                IconButton(
                  tooltip:'Profilo',
                  style:IconButton.styleFrom(backgroundColor:Colors.white.withValues(alpha:.12),foregroundColor:Colors.white),
                  onPressed:()=>setState(()=>tab=4),
                  icon:const Icon(Icons.person_outline_rounded,size:25),
                ),
              ]),
              const SizedBox(height:2),
              SizedBox(height:156,child:logo(h:154)),
              const Text('Ogni ricetta è un viaggio.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900,letterSpacing:.15)),
              const SizedBox(height:4),
              Text('Scopri sapori, tradizioni e cucine da tutto il mondo.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white.withValues(alpha:.82),fontSize:12.5,fontWeight:FontWeight.w500)),
              const SizedBox(height:17),
              Container(
                padding:const EdgeInsets.symmetric(horizontal:8,vertical:13),
                decoration:BoxDecoration(color:Colors.white.withValues(alpha:.105),borderRadius:BorderRadius.circular(22),border:Border.all(color:Colors.white.withValues(alpha:.15))),
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
 Widget homeStat(String value,String label,IconData icon)=>Expanded(child:Column(children:[Icon(icon,color:Colors.white.withValues(alpha:.82),size:19),const SizedBox(height:4),Text(value,style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)),Text(label,style:TextStyle(color:Colors.white.withValues(alpha:.70),fontSize:8.5,fontWeight:FontWeight.w800,letterSpacing:.7))]));
 Widget homeDivider()=>Container(width:1,height:48,color:Colors.white.withValues(alpha:.16));
 Widget heroAction(IconData icon,String label,VoidCallback onTap)=>Material(color:Colors.white,borderRadius:BorderRadius.circular(16),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(16),child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:11),child:Row(children:[Container(width:34,height:34,decoration:BoxDecoration(color:const Color(0xFFE1F1E8),borderRadius:BorderRadius.circular(11)),child:Icon(icon,color:green,size:19)),const SizedBox(width:8),Expanded(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:ink,fontSize:11.5,fontWeight:FontWeight.w900))),const Icon(Icons.arrow_forward_ios_rounded,color:green,size:13)]))));
 Widget countStat(String value,String label)=>Column(children:[Text(value,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:green)),Text(label,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:ink,letterSpacing:.5))]);
 Widget quickHomeAction(IconData icon,String label,VoidCallback onTap)=>FilledButton.tonalIcon(onPressed:onTap,icon:Icon(icon,size:19),label:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),style:FilledButton.styleFrom(foregroundColor:green,backgroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:12,horizontal:9),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))));
 Widget specialBanner(String assetPath,{required VoidCallback onTap})=>Card(clipBehavior:Clip.antiAlias,elevation:3,margin:const EdgeInsets.only(bottom:10),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(22),child:AspectRatio(aspectRatio:4.859375,child:Image.asset(assetPath,fit:BoxFit.contain,filterQuality:FilterQuality.high,errorBuilder:(_,__,___)=>Container(color:pale,alignment:Alignment.center,child:const Icon(Icons.image_not_supported_outlined,color:green,size:32))))));
 void openSpecialPage(String title,String subtitle,List<Recipe> recipes,IconData icon)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SpecialCollectionPage(title:title,subtitle:subtitle,recipes:recipes,icon:icon)));
 Widget socialSection()=>Card(clipBehavior:Clip.antiAlias,elevation:2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),child:Container(padding:const EdgeInsets.all(18),decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFFF5E9D7),Color(0xFFE5F1E8)])),child:Column(crossAxisAlignment:CrossAxisAlignment.center,children:[const Text('Seguici sui social',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:4),const Text('Ricette, curiosità, novità e tanto altro!',textAlign:TextAlign.center,style:TextStyle(color:ink)),const SizedBox(height:14),Row(children:[Expanded(child:socialButton('f','Facebook',const Color(0xFF1877F2),socialFacebook)),const SizedBox(width:9),Expanded(child:socialButton('◎','Instagram',const Color(0xFFE1306C),socialInstagram)),const SizedBox(width:9),Expanded(child:socialButton('♪','TikTok',Colors.black,socialTikTok))]),const SizedBox(height:10),const Text('Unisciti alla nostra community ❤️',style:TextStyle(fontWeight:FontWeight.w700,color:green))])));
 Widget socialButton(String mark,String label,Color color,String url)=>InkWell(onTap:()=>openSocial(url,label),borderRadius:BorderRadius.circular(18),child:Container(padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),boxShadow:[BoxShadow(color:Colors.black12,blurRadius:8,offset:Offset(0,3))]),child:Column(children:[CircleAvatar(radius:21,backgroundColor:color,child:Text(mark,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900))),const SizedBox(height:5),Text(label,style:const TextStyle(fontWeight:FontWeight.w800,color:ink,fontSize:12))])));
 void openSocial(String url,String label){if(url.isEmpty){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Collegheremo $label al tuo profilo ufficiale.')));return;}}

 Widget ratingHomeSection(String title,bool taste){final map=taste?tasteRatings:ratings;final ranked=<Recipe>[];for(final entry in map.entries){if(entry.value.count>0){final recipe=_recipeById[entry.key];if(recipe!=null)ranked.add(recipe);}}ranked.sort((a,b)=>avgFor(b,taste:taste).compareTo(avgFor(a,taste:taste)));final shown=ranked.take(5).toList(growable:false);return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[section(title,action:'Vedi tutte',onAction:()=>showRatingRanking(taste)),if(shown.isEmpty)Card(color:Colors.white,child:const Padding(padding:EdgeInsets.all(18),child:Text('Ancora nessun voto: sii il primo a valutare una ricetta ⭐',style:TextStyle(fontWeight:FontWeight.w700,color:ink)))) else ...shown.map((r)=>ratingRow(r,taste))]);}
 Widget ratingRow(Recipe r,bool taste)=>Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(leading:SizedBox(width:58,height:58,child:recipeVisual(r,height:58,radius:BorderRadius.circular(12))),title:Text(r.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,color:ink)),subtitle:Row(children:[stars(avgFor(r,taste:taste)),const SizedBox(width:5),Text('${avgFor(r,taste:taste).toStringAsFixed(1)} • ${countFor(r,taste:taste)} voti',style:const TextStyle(fontSize:11))]),trailing:const Icon(Icons.chevron_right),onTap:()=>openRecipe(r)));
 Widget stars(double value)=>Row(mainAxisSize:MainAxisSize.min,children:List.generate(5,(i)=>Icon(i<value.round()?Icons.star:Icons.star_border,size:17,color:orange)));
 void showRatingRanking(bool taste)=>showModalBottomSheet(context:context,showDragHandle:true,builder:(_){final map=taste?tasteRatings:ratings;final ranked=<Recipe>[];for(final entry in map.entries){if(entry.value.count>0){final recipe=_recipeById[entry.key];if(recipe!=null)ranked.add(recipe);}}ranked.sort((a,b)=>avgFor(b,taste:taste).compareTo(avgFor(a,taste:taste)));return SafeArea(child:ListView(padding:const EdgeInsets.all(18),children:[Text(taste?'Ricette più buone':'Ricette più votate',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:10),...ranked.map((r)=>ratingRow(r,taste))]));});
 Widget searchBox()=>TextField(
  controller:search,
  onChanged:(_){
    _searchDebounce?.cancel();
    _searchDebounce=Timer(const Duration(milliseconds:140),(){
      if(!mounted)return;
      _invalidateFilterCache();
      setState((){});
    });
  },
  onSubmitted:(_){
    _searchDebounce?.cancel();
    _invalidateFilterCache();
    setState(()=>tab=1);
  },decoration:InputDecoration(hintText:'Cerca ricette, Paesi o ingredienti',prefixIcon:const Icon(Icons.search,color:green),suffixIcon:IconButton(onPressed:showFilters,icon:const Icon(Icons.tune,color:green)),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(30),borderSide:BorderSide.none),contentPadding:const EdgeInsets.symmetric(vertical:14)));
 Widget fridgeBanner()=>Card(elevation:0,color:const Color(0xFFE4F1E8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),child:InkWell(borderRadius:BorderRadius.circular(22),onTap:fridgePage,child:Padding(padding:const EdgeInsets.all(17),child:Row(children:[Container(width:52,height:52,decoration:BoxDecoration(color:green,borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.kitchen,color:Colors.white)),const SizedBox(width:14),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Cosa hai nel frigo?',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:ink)),SizedBox(height:4),Text('Seleziona gli ingredienti e scopri cosa puoi cucinare.',style:TextStyle(color:ink))])),const Icon(Icons.arrow_forward_ios_rounded,size:18,color:green)]))));
 Widget section(String t,{String? action,VoidCallback? onAction})=>Padding(padding:const EdgeInsets.only(top:22,bottom:10),child:Row(children:[Expanded(child:Text(t,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:ink))),if(action!=null)TextButton(onPressed:onAction,child:Text(action,style:const TextStyle(color:green,fontWeight:FontWeight.w800)))]));
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
 Widget miniCard(Recipe r)=>GestureDetector(onTap:()=>openRecipe(r),child:SizedBox(width:172,height:254,child:Container(margin:const EdgeInsets.only(right:12),child:Card(clipBehavior:Clip.antiAlias,elevation:2,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[recipeVisual(r,height:112,radius:BorderRadius.zero),Padding(padding:const EdgeInsets.fromLTRB(10,7,10,8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:4),Text('${flag(r.country)} ${r.country}',style:const TextStyle(fontSize:12)),const SizedBox(height:3),Text('${r.timeMin} min • ${cost(r,r.servings)}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11))]))])))));
 Widget continentGrid()=>GridView.count(crossAxisCount:3,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:8,mainAxisSpacing:8,childAspectRatio:1.1,children:[['Europa','🇪🇺'],['Asia','🌏'],['Americhe','🌎'],['Africa','🌍'],['Oceania','🌊'],['Medio Oriente','🕌']].map((x)=>InkWell(onTap:()=>openContinentPage(x[0]),borderRadius:BorderRadius.circular(18),child:Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFE8DFD1))),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(x[1],style:const TextStyle(fontSize:32)),const SizedBox(height:5),Text(x[0],style:const TextStyle(fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:3),const Text('Tocca per esplorare',style:TextStyle(fontSize:9,color:Colors.black45))])))).toList());
 void openContinentPage(String continent){final rs=all.where((r)=>r.continent.toLowerCase()==continent.toLowerCase()).toList();Navigator.push(context,MaterialPageRoute(builder:(_)=>SpecialCollectionPage(title:'Ricette $continent',subtitle:'Scopri le ricette di $continent.',recipes:rs,icon:Icons.public)));}
 Widget premiumBanner()=>Card(clipBehavior:Clip.antiAlias,elevation:3,child:Container(decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF075B3A),Color(0xFF0C7A4B)])),padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.workspace_premium,color:orange,size:32),SizedBox(width:8),Text('Passa a Premium',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900))]),const SizedBox(height:6),const Text('Sblocca tutte le ricette Premium, le raccolte speciali, storie, procedimenti e funzioni esclusive.',style:TextStyle(color:Colors.white,fontSize:15)),const SizedBox(height:12),Row(children:[priceChip('1 mese','€2,99'),priceChip('6 mesi','€14,99'),priceChip('12 mesi','€24,99')]),const SizedBox(height:12),FilledButton(style:FilledButton.styleFrom(backgroundColor:orange,foregroundColor:ink,minimumSize:const Size.fromHeight(48)),onPressed:premiumPage,child:const Text('Scopri Premium',style:TextStyle(fontWeight:FontWeight.w900)))])));
 Widget priceChip(String a,String b)=>Expanded(child:Container(margin:const EdgeInsets.only(right:6),padding:const EdgeInsets.symmetric(vertical:9,horizontal:5),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.95),borderRadius:BorderRadius.circular(14)),child:Column(children:[Text(a,style:const TextStyle(fontSize:11,color:ink)),Text(b,style:const TextStyle(fontWeight:FontWeight.w900,color:green))])));
 Widget searchPage(){
  final results=filtered;
  return ListView.builder(
    padding:const EdgeInsets.all(16),
    itemCount:results.length+5,
    itemBuilder:(context,index){
      if(index==0)return const Text('Cerca',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink));
      if(index==1)return const SizedBox(height:12);
      if(index==2)return searchBox();
      if(index==3)return Padding(padding:const EdgeInsets.only(top:10,bottom:8),child:Text('${results.length} ricette',style:const TextStyle(fontWeight:FontWeight.w700)));
      if(index==4)return const SizedBox(height:8);
      return recipeCard(results[index-5]);
    },
  );
 }
 Widget categoriesPage(){
  const categories=['Tutte','Antipasti','Primi','Secondi','Zuppe','Dolci','Pizze','Insalate'];
  final shown=all.take(20).toList(growable:false);
  return ListView.builder(
    padding:const EdgeInsets.all(16),
    itemCount:shown.length+4,
    itemBuilder:(context,index){
      if(index==0)return const Text('Categorie',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink));
      if(index==1)return const SizedBox(height:12);
      if(index==2)return Wrap(spacing:9,runSpacing:9,children:categories.map((x)=>ChoiceChip(label:Text(x),selected:category==x,onSelected:(_){_invalidateFilterCache();setState(()=>category=x);})).toList(growable:false));
      if(index==3)return section('Esplora per Paese');
      return recipeCard(shown[index-4]);
    },
  );
 }
 Widget favoritesPage(){
  final list=favorites.isEmpty ? const <Recipe>[] : all.where((r)=>favorites.contains(r.id)).toList(growable:false);
  if(list.isEmpty){
    return ListView(padding:const EdgeInsets.all(16),children:[
      const Text('I tuoi preferiti',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink)),
      const Text('0 ricette salvate'),
      const SizedBox(height:12),
      Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[const Icon(Icons.favorite_border,size:48,color:green),const SizedBox(height:10),const Text('Le tue ricette preferite appariranno qui.',textAlign:TextAlign.center)]))),
    ]);
  }
  return ListView.builder(
    padding:const EdgeInsets.all(16),
    itemCount:list.length+3,
    itemBuilder:(context,index){
      if(index==0)return const Text('I tuoi preferiti',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink));
      if(index==1)return Text('${list.length} ricette salvate');
      if(index==2)return const SizedBox(height:12);
      return recipeCard(list[index-3]);
    },
  );
 }
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
  final File? file=path==null?null:File(path);
  final hasPhoto=file!=null && file.existsSync();
  return Stack(clipBehavior:Clip.none,children:[
    CircleAvatar(radius:48,backgroundColor:const Color(0xFFDCEFE5),backgroundImage:hasPhoto?FileImage(file):null,child:hasPhoto?null:const Icon(Icons.person_rounded,size:56,color:green)),
    Positioned(right:-2,bottom:0,child:InkWell(onTap:pickProfilePhoto,borderRadius:BorderRadius.circular(18),child:Container(width:34,height:34,decoration:const BoxDecoration(color:green,shape:BoxShape.circle),child:const Icon(Icons.camera_alt_rounded,size:17,color:Colors.white)))),
  ]);
 }
 Widget profilePage()=>ListView(padding:const EdgeInsets.fromLTRB(16,8,16,28),children:[
  Container(
    padding:const EdgeInsets.fromLTRB(10,10,10,18),
    decoration:BoxDecoration(
      color:const Color(0xFFFFFBF3),
      borderRadius:BorderRadius.circular(30),
      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.07),blurRadius:18,offset:const Offset(0,7))],
    ),
    child:Column(children:[
      Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          logo(h:62),
          const Padding(padding:EdgeInsets.only(left:2),child:Text('Ogni ricetta è un viaggio.',style:TextStyle(fontSize:15,fontWeight:FontWeight.w700,color:Color(0xFFB66B13),fontStyle:FontStyle.italic))),
        ])),
        IconButton(onPressed:showProfileSettings,icon:const Icon(Icons.settings_outlined,size:28,color:ink)),
      ]),
      const SizedBox(height:8),
      Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
        profileAvatar(),
        const SizedBox(width:16),
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Ciao!',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink)),
          SizedBox(height:2),Text('Esplora, cucina, viaggia.',style:TextStyle(fontSize:18,fontWeight:FontWeight.w600,color:Colors.black87)),
          SizedBox(height:4),Text('Il tuo spazio personale',style:TextStyle(fontSize:13,color:Colors.black54)),
        ])),
      ]),
      const SizedBox(height:14),
      InkWell(onTap:premiumPage,borderRadius:BorderRadius.circular(22),child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:13),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFFFF4DE),Color(0xFFFFE7B5)]),borderRadius:BorderRadius.circular(22),border:Border.all(color:const Color(0xFFE7C77D))),child:Row(children:[
        Container(width:44,height:44,decoration:const BoxDecoration(color:Color(0xFFD18B22),shape:BoxShape.circle),child:const Icon(Icons.workspace_premium_rounded,color:Colors.white,size:25)),
        const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Utente gratuito',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:ink)),Text('Scopri tutti i vantaggi Premium',style:TextStyle(fontSize:12,color:Colors.black54))])),const Icon(Icons.chevron_right_rounded,color:ink,size:28),
      ]))),
    ]),
  ),
  const SizedBox(height:14),
  Container(padding:const EdgeInsets.symmetric(vertical:14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.06),blurRadius:14,offset:const Offset(0,5))]),child:Row(children:[
    Expanded(child:profileStat(Icons.favorite_rounded,'${favorites.length}','Ricette salvate',Colors.red)),
    profileDivider(),
    Expanded(child:profileStat(Icons.menu_book_rounded,'0','Ricette private',green)),
    profileDivider(),
    Expanded(child:profileStat(Icons.format_list_bulleted_rounded,'${shopping.length}','Liste della spesa',green)),
    profileDivider(),
    Expanded(child:profileStat(Icons.kitchen_rounded,'0','Ingredienti salvati',green)),
  ])),
  const SizedBox(height:16),
  profileTile(Icons.account_circle_rounded,'Il mio account','Registrazione, accesso e sincronizzazione',green,onTap:accountPage),
  profileTile(Icons.workspace_premium_rounded,'Premium','Scegli o gestisci il tuo piano',orange,onTap:premiumPage,highlight:true,action:'Scopri di più'),
  profileTile(Icons.language_rounded,'Lingua','Scegli la lingua dell’app',green,trailing:DropdownButtonHideUnderline(child:DropdownButton<String>(value:language,icon:const Icon(Icons.chevron_right_rounded,color:ink),items:['Italiano','English','Français','Español','Deutsch','Português'].map((x)=>DropdownMenuItem(value:x,child:Text(x,style:const TextStyle(fontWeight:FontWeight.w800,color:ink)))).toList(),onChanged:(v){if(v!=null)setState(()=>language=v);})) ),
  profileTile(Icons.favorite_rounded,'I miei preferiti','Le tue ricette salvate',Colors.red,trailing:Text('${favorites.length}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17,color:ink)),onTap:()=>setState(()=>tab=3)),
  profileTile(Icons.shopping_cart_rounded,'Lista della spesa','Gestisci i tuoi ingredienti',green,trailing:Text('${shopping.length}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17,color:ink)),onTap:shoppingPage),
  profileTile(Icons.kitchen_rounded,'Cosa hai nel frigo?','Trova ricette con quello che hai',green,onTap:fridgePage),
  profileTile(Icons.health_and_safety_rounded,'Sicurezza alimentare','Allergeni, conservazione e cottura sicura',green,onTap:foodSafetyPage),
  profileTile(Icons.shield_outlined,'Allergeni da evitare','Personalizza le ricette che vuoi evitare',green,onTap:allergenSettingsPage),
  profileTile(Icons.privacy_tip_outlined,'Gestisci Privacy','Consensi, dati, notifiche e pubblicità',green,onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AppPrivacySettingsPage()))),
  profileTile(Icons.description_outlined,'Privacy Policy','Come trattiamo i dati',green,onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PrivacyPolicyPage()))),
  profileTile(Icons.gavel_outlined,'Termini e Condizioni','Regole di utilizzo dell’app',green,onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const TermsPage()))),
  profileTile(Icons.fact_check_outlined,'Licenze e crediti','Foto e contenuti di terze parti',green,onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const LicensesPage()))),
  profileTile(Icons.settings_rounded,'Impostazioni','Notifiche, tema e preferenze',Colors.blueGrey,onTap:showProfileSettings),
  profileTile(Icons.help_rounded,'Aiuto e supporto','FAQ e contatti',Colors.blueGrey,onTap:showHelp),
  const SizedBox(height:16),
  Container(height:120,padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(25),gradient:const LinearGradient(begin:Alignment.centerLeft,end:Alignment.centerRight,colors:[Color(0xFFF2F2E6),Color(0xFFE4F0E6)]),image:const DecorationImage(image:AssetImage('assets/logo_rdm.png'),alignment:Alignment.centerRight,opacity:.10,fit:BoxFit.contain)),child:const Align(alignment:Alignment.centerLeft,child:Text('La buona cucina\nunisce il mondo.',style:TextStyle(fontSize:24,fontWeight:FontWeight.w700,fontStyle:FontStyle.italic,color:ink,height:1.15)))),
]);
 Widget profileStat(IconData icon,String value,String label,Color color)=>Column(children:[Icon(icon,color:color,size:25),const SizedBox(height:5),Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:Colors.black)),const SizedBox(height:2),Text(label,textAlign:TextAlign.center,maxLines:2,style:const TextStyle(fontSize:10,color:Colors.black54,fontWeight:FontWeight.w600))]);
 Widget profileDivider()=>Container(width:1,height:55,color:const Color(0xFFE5E0D8));
 Widget profileTile(IconData icon,String title,String subtitle,Color iconColor,{Widget? trailing,VoidCallback? onTap,bool highlight=false,String? action})=>Padding(padding:const EdgeInsets.only(bottom:10),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(22),child:Container(padding:const EdgeInsets.fromLTRB(16,14,12,14),decoration:BoxDecoration(color:highlight?const Color(0xFFFFF8E9):Colors.white,borderRadius:BorderRadius.circular(22),border:highlight?Border.all(color:const Color(0xFFE8C87C)):null,boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.055),blurRadius:12,offset:const Offset(0,4))]),child:Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:highlight?const Color(0xFFFFE8B7):const Color(0xFFEAF4EE),borderRadius:BorderRadius.circular(14)),child:Icon(icon,color:iconColor,size:24)),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:2),Text(subtitle,style:const TextStyle(fontSize:12.5,color:Colors.black54))])),if(action!=null)Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),decoration:BoxDecoration(color:orange,borderRadius:BorderRadius.circular(18)),child:Text(action,style:const TextStyle(color:ink,fontWeight:FontWeight.w900,fontSize:12))),if(trailing!=null)Padding(padding:const EdgeInsets.only(left:8),child:trailing),if(action==null&&trailing==null)const Padding(padding:EdgeInsets.only(left:8),child:Icon(Icons.chevron_right_rounded,color:ink,size:27))]))));
 void accountPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccountPage()));
 void showProfileSettings(){showModalBottomSheet(context:context,showDragHandle:true,backgroundColor:cream,builder:(c)=>SafeArea(child:ListView(shrinkWrap:true,padding:const EdgeInsets.fromLTRB(20,8,20,20),children:[const Text('Impostazioni',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:8),ListTile(leading:const Icon(Icons.notifications_none_rounded,color:green),title:const Text('Notifiche'),subtitle:const Text('Gestisci gli avvisi dell’app'),onTap:(){Navigator.pop(c);Navigator.push(context,MaterialPageRoute(builder:(_)=>const AppPrivacySettingsPage()));}),const ListTile(leading:Icon(Icons.dark_mode_outlined,color:green),title:Text('Aspetto'),subtitle:Text('Tema chiaro dell’app')),ListTile(leading:const Icon(Icons.privacy_tip_outlined,color:green),title:const Text('Privacy'),subtitle:const Text('Gestisci le tue preferenze'),onTap:(){Navigator.pop(c);Navigator.push(context,MaterialPageRoute(builder:(_)=>const AppPrivacySettingsPage()));}),const SizedBox(height:8),FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('Chiudi'))])));}
 void showHelp(){showModalBottomSheet(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Aiuto e supporto',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:10),const Text('Per assistenza, suggerimenti o segnalazioni potrai contattarci dalla sezione supporto dell’app.',style:TextStyle(height:1.4)),const SizedBox(height:18),FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('Chiudi'))]))));}
 void allergenSettingsPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AllergenSettingsPage(selected:avoidedAllergens,onChanged:(key,value)async{setState(()=>value?avoidedAllergens.add(key):avoidedAllergens.remove(key));_invalidateFilterCache();final p=await SharedPreferences.getInstance();await p.setStringList('rdm_avoided_allergens',avoidedAllergens.toList());})));
 void foodSafetyPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const FoodSafetyPage()));

 void premiumPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PremiumPage()));
 void shoppingPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ShoppingPage(items:shopping)));
 void openRecipe(Recipe recipe){
  _openRecipeAfterAd(recipe);
 }

 Future<void> _openRecipeAfterAd(Recipe recipe) async {
  if (!recipe.premium) {
    await AdService.instance.showInterstitialIfReady();
  }
  if (!mounted) return;
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
 void showFilters(){showModalBottomSheet(context:context,showDragHandle:true,isScrollControlled:true,builder:(c)=>StatefulBuilder(builder:(c,setM)=>Padding(padding:EdgeInsets.fromLTRB(20,8,20,20+MediaQuery.of(c).viewInsets.bottom),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Filtri',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:category,items:['Tutte','Antipasti','Primi','Secondi','Zuppe','Dolci','Pizze','Insalate'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)setM(()=>category=v);}),const SizedBox(height:12),const Text('Stile alimentare',style:TextStyle(fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:7),Wrap(spacing:8,runSpacing:8,children:['Tutte','Vegetariano','Vegano','Senza glutine','Senza lattosio'].map((x)=>ChoiceChip(label:Text(x),selected:diet==x,onSelected:(_)=>setM(()=>diet=x))).toList()),const SizedBox(height:12),Text('Tempo massimo: $maxTime min',style:const TextStyle(fontWeight:FontWeight.w800,color:ink)),Slider(min:15,max:180,divisions:11,value:maxTime.toDouble(),label:'$maxTime min',onChanged:(v)=>setM(()=>maxTime=v.round())),const SizedBox(height:8),SizedBox(width:double.infinity,child:FilledButton(onPressed:(){Navigator.pop(c);_invalidateFilterCache();setState((){});},child:const Text('Applica filtri')))])))));}
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
      backgroundColor: cream,
      appBar: AppBar(title: const Text('Premium', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF063D28), Color(0xFF0C7A4B)]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: const Column(
              children: [
                Icon(Icons.workspace_premium, size: 58, color: orange),
                SizedBox(height: 8),
                Text('Ricette del Mondo Premium', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                SizedBox(height: 7),
                Text('Più ricette. Più viaggi. Più sapori.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFD889), fontSize: 18, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('Un mondo di ricette esclusive, raccolte speciali e strumenti per organizzare la tua cucina.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(children: [Icon(Icons.workspace_premium, color: orange), SizedBox(width: 8), Expanded(child: Text('Cosa ottieni con Premium', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)))]),
                  ),
                  ...['Accesso a tutte le ricette Premium', 'Ingredienti e procedimenti completi', 'Storie, varianti e curiosità', 'Raccolte speciali: Impasti, Hamburger e Braceria', 'Lista della spesa e funzione frigo', 'Esperienza senza pubblicità'].map(
                    (x) => ListTile(dense: true, leading: const Icon(Icons.check_circle, color: green), title: Text(x, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Scegli il tuo abbonamento', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink)),
          const SizedBox(height: 6),
          const Text('Puoi scegliere il rinnovo automatico oppure un acquisto una tantum.', style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 8),
          ...List.generate(plans.length, (i) {
            final p = plans[i];
            final sel = selectedPlan == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => selectedPlan = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFFFFF4DE) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? orange : Colors.black12, width: sel ? 2 : 1),
                    boxShadow: sel ? const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))] : null,
                  ),
                  child: Row(
                    children: [
                      Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: sel ? orange : Colors.black38, width: 2), color: sel ? orange : Colors.transparent), child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [Text(p.$1, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ink)), if (i == 1) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(10)), child: const Text('PIÙ SCELTO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)))]),
                            Text(p.$3, style: const TextStyle(color: green, fontWeight: FontWeight.w700)),
                            Text(p.$4, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Text(p.$2, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: green)),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: ink, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            onPressed: () {
              final p = plans[selectedPlan];
              ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('${p.$1} — ${p.$2} (${p.$3}). Il pagamento reale sarà collegato a Google Play Billing in fase di pubblicazione.')));
            },
            child: Text('${plans[selectedPlan].$3 == 'Una tantum' ? 'Acquista' : 'Attiva'} ${plans[selectedPlan].$1} — ${plans[selectedPlan].$2}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 8),
          const Text('Puoi scegliere il piano prima del pagamento. Le condizioni di acquisto e rinnovo saranno mostrate chiaramente prima della conferma.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}

class PaywallPage extends StatelessWidget{final Recipe recipe;final VoidCallback onPremium;const PaywallPage({super.key,required this.recipe,required this.onPremium});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Anteprima Premium')),body:ListView(padding:const EdgeInsets.all(18),children:[recipeVisual(recipe,height:260,allowNetwork:true),const SizedBox(height:12),Text('${flag(recipe.country)} ${recipe.country}',style:const TextStyle(fontWeight:FontWeight.w800,color:green)),Text(recipe.title,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:7),Text(recipe.description),const SizedBox(height:14),Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:pale,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('📖 La storia del piatto',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:7),Text(recipe.history,maxLines:5,overflow:TextOverflow.ellipsis)])),const SizedBox(height:14),const Text('🔒 Ingredienti e procedimento completo sono disponibili con Premium.',style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:16),FilledButton(onPressed:onPremium,child:const Text('Scopri i piani Premium'))]));}

class RecipePage extends StatefulWidget{
  final Recipe recipe; final bool selected; final VoidCallback onFavorite; final ValueChanged<String> onAdd; final VoidCallback onAddAll;
  final double rating,tasteRating; final int ratingCount,tasteCount; final ValueChanged<int> onRate,onTaste;
  const RecipePage({super.key,required this.recipe,required this.selected,required this.onFavorite,required this.onAdd,required this.onAddAll,required this.rating,required this.tasteRating,required this.ratingCount,required this.tasteCount,required this.onRate,required this.onTaste});
  @override State<RecipePage> createState()=>_RecipePageState();
}

class _RecipePageState extends State<RecipePage> with SingleTickerProviderStateMixin{
  late int servings;
  late bool isFavorite;
  late final ScrollController scrollController;
  final ingredientsKey=GlobalKey();
  final preparationKey=GlobalKey();
  final ratingsKey=GlobalKey();
  final historyKey=GlobalKey();
  late final AnimationController heroController;

  @override void initState(){
    super.initState();
    servings=widget.recipe.servings;
    isFavorite=widget.selected;
    scrollController=ScrollController();
    heroController=AnimationController(vsync:this,duration:const Duration(milliseconds:700))..forward();
  }
  @override void didUpdateWidget(covariant RecipePage oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.selected!=widget.selected)isFavorite=widget.selected;}
  @override void dispose(){scrollController.dispose();heroController.dispose();super.dispose();}

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

  void jumpTo(GlobalKey key){
    final ctx=key.currentContext;
    if(ctx!=null)Scrollable.ensureVisible(ctx,duration:const Duration(milliseconds:500),curve:Curves.easeOutCubic,alignment:0.08);
  }

  @override Widget build(BuildContext c){
    final r=widget.recipe;
    return Scaffold(
      backgroundColor:cream,
      appBar:AppBar(
        backgroundColor:Colors.transparent,
        title:const Text('Ricetta',style:TextStyle(fontWeight:FontWeight.w800)),
        actions:[
          IconButton(onPressed:()=>SharePlus.instance.share(ShareParams(text:'${r.title} — Ricette del Mondo')),icon:const Icon(Icons.share_outlined)),
          FavoriteButton(selected:isFavorite,onTap:(){setState(()=>isFavorite=!isFavorite);widget.onFavorite();}),
        ],
      ),
      body:ListView(
        controller:scrollController,
        padding:const EdgeInsets.fromLTRB(16,0,16,115),
        children:[
          _recipeHero(r),
          const SizedBox(height:12),
          _sectionTabs(),
          const SizedBox(height:14),
          KeyedSubtree(key:historyKey,child:_historyAndVariants(r)),
          const SizedBox(height:18),
          KeyedSubtree(key:ingredientsKey,child:_ingredientsSection(r)),
          const SizedBox(height:18),
          KeyedSubtree(key:preparationKey,child:_preparationSection(r)),
          const SizedBox(height:18),
          KeyedSubtree(key:ratingsKey,child:RatingPanel(recipe:r,rating:widget.rating,taste:widget.tasteRating,ratingCount:widget.ratingCount,tasteCount:widget.tasteCount,onRate:widget.onRate,onTaste:widget.onTaste)),
        ],
      ),
      bottomNavigationBar:_bottomActions(),
    );
  }

  Widget _recipeHero(Recipe r){
    return AnimatedBuilder(animation:heroController,builder:(context,child){
      final t=Curves.easeOutCubic.transform(heroController.value);
      return Opacity(opacity:t,child:Transform.translate(offset:Offset(0,18*(1-t)),child:child));
    },child:ClipRRect(borderRadius:BorderRadius.circular(30),child:SizedBox(height:365,child:Stack(fit:StackFit.expand,children:[
      recipeVisual(r,height:365,radius:BorderRadius.circular(30),allowNetwork:true),
      DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black.withValues(alpha:.05),Colors.transparent,Colors.black.withValues(alpha:.72)]))),
      Positioned(left:18,top:18,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.92),borderRadius:BorderRadius.circular(20)),child:Text('${flag(r.country)}  ${r.country}',style:const TextStyle(color:green,fontWeight:FontWeight.w900)))),
      Positioned(left:18,right:18,bottom:18,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(r.title,style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w900,height:1.05,shadows:[Shadow(color:Colors.black54,blurRadius:8)])),
        if(r.description.isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text(r.description,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w600,height:1.3))),
        const SizedBox(height:12),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[_heroStat(Icons.timer_outlined,'${r.prepMin} min','Preparazione'),_heroStat(Icons.soup_kitchen_outlined,'${r.cookMin} min','Cottura'),_heroStat(Icons.bar_chart_rounded,r.difficulty,'Difficoltà'),_heroStat(Icons.people_alt_outlined,'$servings','Porzioni')])),
      ]),),
    ]))));
  }
  Widget _heroStat(IconData icon, String value, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .93),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: green),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: ink,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTabs()=>Container(padding:const EdgeInsets.all(5),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.05),blurRadius:12,offset:const Offset(0,4))]),child:Row(children:[_tab('Storia',Icons.menu_book_outlined,historyKey,true),_tab('Ingredienti',Icons.eco_outlined,ingredientsKey,false),_tab('Preparazione',Icons.restaurant_menu,preparationKey,false),_tab('Valutazioni',Icons.star_border,ratingsKey,false)]));
  Widget _tab(String text,IconData icon,GlobalKey key,bool active)=>Expanded(child:InkWell(onTap:()=>jumpTo(key),borderRadius:BorderRadius.circular(17),child:AnimatedContainer(duration:const Duration(milliseconds:250),padding:const EdgeInsets.symmetric(vertical:10,horizontal:3),decoration:BoxDecoration(color:active?const Color(0xFFEAF5EF):Colors.transparent,borderRadius:BorderRadius.circular(17)),child:Column(children:[Icon(icon,size:19,color:active?green:ink),const SizedBox(height:3),Text(text,style:TextStyle(fontSize:10,fontWeight:active?FontWeight.w900:FontWeight.w600,color:active?green:ink))]))));

  Widget _ingredientsSection(Recipe r) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7E1D6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5EF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.shopping_basket_outlined,
                  color: green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Ingredienti',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
              ),
              _servingsControl(),
              const SizedBox(width: 6),
              SizedBox(
                width: 46,
                height: 46,
                child: FilledButton.tonal(
                  onPressed: widget.onAddAll,
                  child: const Icon(
                    Icons.add_shopping_cart,
                    color: green,
                    size: 21,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...r.ingredients.map(
            (raw) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _ingredientTile(scaleIng(raw)),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: widget.onAddAll,
              icon: const Icon(Icons.playlist_add, color: green),
              label: const Text(
                'Aggiungi tutti gli ingredienti',
                style: TextStyle(
                  color: green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _servingsControl()=>Container(padding:const EdgeInsets.symmetric(horizontal:3,vertical:2),decoration:BoxDecoration(color:const Color(0xFFF3F7F3),borderRadius:BorderRadius.circular(18)),child:Row(children:[IconButton(visualDensity:VisualDensity.compact,onPressed:servings>1?()=>setState(()=>servings--):null,icon:const Icon(Icons.remove_circle_outline,color:green,size:21)),Text('$servings',style:const TextStyle(fontWeight:FontWeight.w900,color:ink)),IconButton(visualDensity:VisualDensity.compact,onPressed:()=>setState(()=>servings++),icon:const Icon(Icons.add_circle_outline,color:green,size:21))]));

  Widget _ingredientTile(String text){
    final name = _ingredientName(text);
    final amount = _ingredientAmount(text);
    return Container(
      constraints:const BoxConstraints(minHeight:66),
      padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),
      decoration:BoxDecoration(color:const Color(0xFFFCFAF5),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFECE7DD))),
      child:Row(children:[
        _ingredientPhoto(name),
        const SizedBox(width:10),
        Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:ink)),
          if(amount.isNotEmpty)Padding(padding:const EdgeInsets.only(top:2),child:Text(amount,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,color:Colors.black54,fontWeight:FontWeight.w600))),
        ])),
        const SizedBox(width:6),
        SizedBox(width:42,height:42,child:FilledButton.tonal(onPressed:(){widget.onAdd(text);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('🛒 Aggiunto alla lista della spesa'),behavior:SnackBarBehavior.floating));},child:const Icon(Icons.shopping_cart_outlined,color:green,size:19))),
      ])
    );
  }

  String _ingredientName(String text){
    var value=text.trim();
    value=value.replaceFirst(RegExp(r'^\s*\d+(?:[\.,]\d+)?\s*(?:g|kg|mg|ml|cl|l|dl|oz|lb|cucchiai?|cucchiaini?|pezzi?|fette?|spicchi?|rametti?)?\s*',caseSensitive:false),'');
    value=value.replaceFirst(RegExp(r'^\s*\d+\s*/\s*\d+\s*'),'');
    value=value.replaceAll(RegExp(r'\s*\([^)]*\)'),'');
    return value.replaceAll(RegExp(r'\s+'),' ').trim();
  }

  String _ingredientAmount(String text){
    final name=_ingredientName(text);
    if(name==text.trim()) return '';
    final raw=text.trim();
    final idx=raw.toLowerCase().indexOf(name.toLowerCase());
    if(idx>0) return raw.substring(0,idx).trim();
    return '';
  }

  Widget _ingredientPhoto(String name)=>FutureBuilder<String?>(
    future:IngredientPhotoService.instance.resolve(name),
    builder:(context,snapshot){
      final url=snapshot.data;
      return Container(width:54,height:54,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:const Color(0xFFEAF5EF),borderRadius:BorderRadius.circular(16)),child:url==null?const Icon(Icons.eco_outlined,color:green,size:27):Image.network(url,fit:BoxFit.cover,filterQuality:FilterQuality.low,errorBuilder:(_,__,___)=>const Icon(Icons.eco_outlined,color:green,size:27)));
    },
  );

  Widget _preparationSection(Recipe r)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Icon(Icons.restaurant_menu,color:green,size:29),const SizedBox(width:8),const Expanded(child:Text('Preparazione',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:ink))),if(r.cookMin>0)FilledButton.tonalIcon(onPressed:(){},icon:const Icon(Icons.timer_outlined,color:green),label:Text('Cottura ${r.cookMin} min',style:const TextStyle(color:green,fontWeight:FontWeight.w800)))]),
    const SizedBox(height:10),
    CookingGuide(recipe:r),
    const SizedBox(height:10),
    ...r.steps.asMap().entries.map((e)=>_stepCard(e.key+1,e.value)),
  ]);
  Widget _stepCard(int number,String text)=>TweenAnimationBuilder<double>(tween:Tween(begin:0,end:1),duration:Duration(milliseconds:350+number*45),curve:Curves.easeOutCubic,builder:(context,v,child)=>Opacity(opacity:v,child:Transform.translate(offset:Offset(0,18*(1-v)),child:child)),child:Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(23),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.045),blurRadius:12,offset:const Offset(0,4))]),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:45,height:45,alignment:Alignment.center,decoration:const BoxDecoration(color:green,shape:BoxShape.circle),child:Text('$number',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900))),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Passaggio $number',style:const TextStyle(color:green,fontWeight:FontWeight.w900,fontSize:12)),const SizedBox(height:4),Text(text,style:const TextStyle(fontSize:14,height:1.42,color:ink))])),const SizedBox(width:4),const Icon(Icons.chevron_right_rounded,color:Color(0xFFB7C9BF))])));

  Widget _historyAndVariants(Recipe r) => Container(
    padding:const EdgeInsets.fromLTRB(17,18,17,16),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(28),border:Border.all(color:const Color(0xFFE7E1D6)),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.045),blurRadius:16,offset:const Offset(0,6))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:const Color(0xFFEAF5EF),borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.menu_book_rounded,color:green,size:27)),const SizedBox(width:10),const Expanded(child:Text('Storia e tradizione',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:ink)))]),
      const SizedBox(height:14),
      if(r.history.trim().isNotEmpty) ...[
        const Text('La storia del piatto',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:green)),
        const SizedBox(height:7),
        Text(r.history.trim(),style:const TextStyle(fontSize:15,height:1.55,color:ink)),
      ],
      const SizedBox(height:14),
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:pale,borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Contesto della ricetta',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:ink)),
        const SizedBox(height:7),
        Text('Paese: ${flag(r.country)} ${r.country}',style:const TextStyle(fontWeight:FontWeight.w800)),
        if(r.cuisine.trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:4),child:Text('Cucina: ${r.cuisine}')),
        if(r.category.trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:4),child:Text('Categoria: ${r.category}')),
        if(r.continent.trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:4),child:Text('Area: ${r.continent}')),
        if(r.macroArea.trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:4),child:Text('Macro-area: ${r.macroArea}')),
      ])),
      if(r.tags.isNotEmpty) ...[
        const SizedBox(height:14),
        const Text('Parole chiave',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:ink)),
        const SizedBox(height:7),
        Wrap(spacing:6,runSpacing:6,children:r.tags.take(8).map((tag)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:const Color(0xFFF6F0E4),borderRadius:BorderRadius.circular(14)),child:Text(tag,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:ink)))).toList()),
      ],
      if(r.variants.isNotEmpty) ...[
        const SizedBox(height:16),
        const Text('Varianti della ricetta',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:green)),
        const SizedBox(height:7),
        ...r.variants.map((v)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.check_circle_outline,color:green,size:18),const SizedBox(width:8),Expanded(child:Text(v,style:const TextStyle(height:1.4,color:ink)))]))),
      ],
    ]),
  );

  Widget _bottomActions()=>SafeArea(top:false,child:Container(padding:const EdgeInsets.fromLTRB(12,9,12,8),decoration:BoxDecoration(color:Colors.white,borderRadius:const BorderRadius.vertical(top:Radius.circular(24)),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.10),blurRadius:18,offset:const Offset(0,-5))]),child:Row(children:[Expanded(child:SizedBox(height:52,child:FilledButton.icon(onPressed:()=>jumpTo(preparationKey),icon:const Icon(Icons.restaurant_rounded),label:const Text('Inizia a cucinare',style:TextStyle(fontWeight:FontWeight.w900,fontSize:15))))),const SizedBox(width:8),SizedBox(width:56,height:52,child:FilledButton.tonal(onPressed:(){setState(()=>isFavorite=!isFavorite);widget.onFavorite();},child:Icon(isFavorite?Icons.favorite:Icons.favorite_border,color:isFavorite?Colors.red:green))),const SizedBox(width:8),SizedBox(width:56,height:52,child:FilledButton.tonal(onPressed:widget.onAddAll,child:const Icon(Icons.playlist_add,color:green)))])));
}

 Widget info(String a,String b)=>Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),child:Column(children:[Text(a,style:const TextStyle(fontWeight:FontWeight.w900,color:green)),Text(b,style:const TextStyle(fontSize:10,color:Colors.black54))]));

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

  Widget _headerCard() {
    return Container(
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
    );
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: recipes.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _headerCard(),
                const SizedBox(height: 14),
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
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recipes.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) return _headerCard();
                if (index == 1) return const SizedBox(height: 14);
                final r = recipes[index - 2];
                return Card(
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
                      context,
                      MaterialPageRoute(builder: (_) => SimpleRecipePreview(recipe: r)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SimpleRecipePreview extends StatelessWidget{final Recipe recipe;const SimpleRecipePreview({super.key,required this.recipe});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(recipe.title)),body:ListView(padding:const EdgeInsets.all(18),children:[specialVisual(recipe,height:250,radius:BorderRadius.circular(22),allowNetwork:true),const SizedBox(height:12),Text('${flag(recipe.country)} ${recipe.country}',style:const TextStyle(color:green,fontWeight:FontWeight.w800)),Text(recipe.title,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:ink)),if(recipe.chef.isNotEmpty)Padding(padding:const EdgeInsets.only(top:6),child:Text('Ricetta di ${recipe.chef}',style:const TextStyle(fontWeight:FontWeight.w800,color:orange))),const SizedBox(height:14),CookingGuide(recipe:recipe),const SizedBox(height:14),const Text('Ingredienti',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:ink)),...recipe.ingredients.map((x)=>ListTile(leading:const Icon(Icons.circle,size:7,color:green),title:Text(x))),const Text('Preparazione',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:ink)),...recipe.steps.asMap().entries.map((e)=>ListTile(leading:CircleAvatar(radius:14,backgroundColor:green,child:Text('${e.key+1}',style:const TextStyle(color:Colors.white,fontSize:12))),title:Text(e.value)))]));}

class ShoppingPage extends StatefulWidget{final Set<String> items;const ShoppingPage({super.key,required this.items});@override State<ShoppingPage> createState()=>_ShoppingPageState();}
class _ShoppingPageState extends State<ShoppingPage>{final done=<String>{};@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Lista della spesa')),body:ListView(padding:const EdgeInsets.all(18),children:[Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[const Row(children:[Icon(Icons.shopping_cart,color:green),SizedBox(width:8),Text('I tuoi ingredienti',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:ink))]),const SizedBox(height:8),...widget.items.map((x)=>CheckboxListTile(value:done.contains(x),onChanged:(v)=>setState(()=>v==true?done.add(x):done.remove(x)),title:Text(x),controlAffinity:ListTileControlAffinity.leading)),FilledButton.icon(onPressed:(){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Lista pronta per la spesa')));},icon:const Icon(Icons.check),label:const Text('Ho finito'))])))]));}

class FridgePage extends StatefulWidget{final List<Recipe> recipes;final ValueChanged<Recipe> onOpen;const FridgePage({super.key,required this.recipes,required this.onOpen});@override State<FridgePage> createState()=>_FridgePageState();}
class _FridgePageState extends State<FridgePage>{final selected=<String>{};final search=TextEditingController();final ingredients=['uova','farina','pomodori','cipolla','aglio','olio','burro','latte','formaggio','pollo','riso','pasta','patate','pesce','carne','limone','basilico','pepe','zucchine','melanzane'];@override void dispose(){search.dispose();super.dispose();}@override Widget build(BuildContext c){final q=search.text.toLowerCase();final shown=ingredients.where((x)=>q.isEmpty||x.contains(q)).toList();final ranked=<({Recipe recipe,int missing})>[];if(selected.isNotEmpty){for(final r in widget.recipes){final hay=r.ingredients.join(' ').toLowerCase();final missing=selected.where((s)=>!hay.contains(s)).length;if(missing<selected.length)ranked.add((recipe:r,missing:missing));}ranked.sort((a,b)=>a.missing.compareTo(b.missing));}return Scaffold(appBar:AppBar(title:const Text('Cosa hai nel frigo?')),body:ListView(padding:const EdgeInsets.all(18),children:[const Text('Scegli gli ingredienti che hai',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:8),TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Cerca un ingrediente...')),const SizedBox(height:10),Wrap(spacing:7,runSpacing:7,children:shown.map((x)=>FilterChip(label:Text(x),selected:selected.contains(x),onSelected:(v)=>setState(()=>v?selected.add(x):selected.remove(x)))).toList()),const SizedBox(height:16),Text(selected.isEmpty?'Seleziona almeno un ingrediente.':'${ranked.length} ricette con pochi ingredienti mancanti',style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),...ranked.take(20).map((x)=>Card(child:ListTile(leading:SizedBox(width:62,height:62,child:recipeVisual(x.recipe,height:62,radius:BorderRadius.circular(10))),title:Text(x.recipe.title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${flag(x.recipe.country)} ${x.recipe.country} • ${x.missing} mancanti'),trailing:const Icon(Icons.chevron_right),onTap:()=>widget.onOpen(x.recipe))))]));}}
