import 'package:flutter/material.dart';
import 'recipe.dart';
import 'recipe_repository.dart';
import 'special_recipes.dart';
import 'package:share_plus/share_plus.dart';

void main()=>runApp(const RicetteApp());

class RatingStats { double sum=0; int count=0; double get avg=>count==0?0:sum/count; }

const green=Color(0xFF075B3A), green2=Color(0xFF0C7A4B), orange=Color(0xFFF39A19), cream=Color(0xFFFFFBF3), ink=Color(0xFF12324A), pale=Color(0xFFF2E8D8);
const flags={'Italia':'🇮🇹','Giappone':'🇯🇵','Messico':'🇲🇽','India':'🇮🇳','Grecia':'🇬🇷','Thailandia':'🇹🇭','Spagna':'🇪🇸','Corea del Sud':'🇰🇷','Perù':'🇵🇪','Francia':'🇫🇷','Turchia':'🇹🇷','Cina':'🇨🇳','Stati Uniti':'🇺🇸','USA':'🇺🇸','Marocco':'🇲🇦','Brasile':'🇧🇷','Argentina':'🇦🇷','Vietnam':'🇻🇳','Indonesia':'🇮🇩','Portogallo':'🇵🇹','Germania':'🇩🇪','Regno Unito':'🇬🇧','Etiopia':'🇪🇹','Libano':'🇱🇧','Israele':'🇮🇱','Egitto':'🇪🇬','Australia':'🇦🇺','Filippine':'🇵🇭'};
String flag(String c)=>flags[c]??'🌍';

Widget recipeVisual(Recipe r,{double height=170,BorderRadius? radius})=>ClipRRect(borderRadius:radius??BorderRadius.circular(18),child:SizedBox(height:height,width:double.infinity,child:Image.asset('assets/images/${r.id}.jpg',fit:BoxFit.cover,filterQuality:FilterQuality.high,errorBuilder:(_,__,___)=>Container(color:pale,padding:const EdgeInsets.all(14),child:Image.asset('assets/logo_rdm.png',fit:BoxFit.contain)))));
Widget specialVisual(Recipe r,{double height=170,BorderRadius? radius})=>recipeVisual(r,height:height,radius:radius);

class RicetteApp extends StatelessWidget{const RicetteApp({super.key});@override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Ricette del Mondo',theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:cream,colorScheme:ColorScheme.fromSeed(seedColor:green),fontFamily:'sans-serif',appBarTheme:const AppBarTheme(backgroundColor:cream,foregroundColor:ink,elevation:0)),home:const AppShell());}

class AppShell extends StatefulWidget{const AppShell({super.key});@override State<AppShell> createState()=>_AppShellState();}
class _AppShellState extends State<AppShell>{
 final repo=RecipeRepository(), search=TextEditingController(); List<Recipe> all=[]; final favorites=<String>{}, shopping=<String>{}; final ratings=<String,RatingStats>{}, tasteRatings=<String,RatingStats>{}; final userRatings=<String,int>{}, userTasteRatings=<String,int>{}; int tab=0; String category='Tutte',diet='Tutte',language='Italiano'; int maxTime=180;
 List<Recipe> get catalog=>[...all,...specialDoughRecipes];
 RatingStats statsFor(Map<String,RatingStats> map,String id)=>map.putIfAbsent(id,()=>RatingStats());
 void castVote(Recipe r,int stars,{required bool taste}){final map=taste?tasteRatings:ratings; final mine=taste?userTasteRatings:userRatings; final old=mine[r.id]; final st=statsFor(map,r.id); if(old!=null)st.sum-=old; else st.count++; st.sum+=stars; mine[r.id]=stars; setState((){});}
 double avgFor(Recipe r,{bool taste=false})=>(taste?tasteRatings:ratings)[r.id]?.avg??0;
 int countFor(Recipe r,{bool taste=false})=>(taste?tasteRatings:ratings)[r.id]?.count??0;
 @override void initState(){super.initState();repo.loadRecipes().then((r){if(mounted)setState(()=>all=r);});}
 List<Recipe> get filtered{final s=search.text.trim().toLowerCase();return catalog.where((r){final hay='${r.title} ${r.country} ${r.cuisine} ${r.category} ${r.ingredients.join(' ')} ${r.tags.join(' ')}'.toLowerCase();return (s.isEmpty||s.split(RegExp(r'[, ]+')).where((x)=>x.isNotEmpty).every(hay.contains))&&(category=='Tutte'||r.category==category)&&(r.timeMin<=maxTime)&&(diet=='Tutte'||r.tags.any((x)=>x.toLowerCase()==diet.toLowerCase()));}).toList();}
 @override Widget build(BuildContext c){if(all.isEmpty)return const Scaffold(body:Center(child:CircularProgressIndicator()));final pages=[home(),searchPage(),categoriesPage(),favoritesPage(),profilePage()];return Scaffold(body:SafeArea(child:pages[tab]),bottomNavigationBar:NavigationBar(backgroundColor:Colors.white,indicatorColor:const Color(0xFFDCEFE5),selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),NavigationDestination(icon:Icon(Icons.search),label:'Cerca'),NavigationDestination(icon:Icon(Icons.grid_view_rounded),label:'Categorie'),NavigationDestination(icon:Icon(Icons.favorite_border),selectedIcon:Icon(Icons.favorite),label:'Preferiti'),NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profilo')]));}
 Widget logo({double h=96})=>Image.asset('assets/logo_rdm.png',height:h,fit:BoxFit.contain);
 Widget home()=>ListView(padding:const EdgeInsets.fromLTRB(16,12,16,30),children:[Row(children:[Expanded(child:logo(h:104)),IconButton(style:IconButton.styleFrom(backgroundColor:Colors.white),onPressed:()=>setState(()=>tab=4),icon:const Icon(Icons.person_outline,color:green))]),const SizedBox(height:4),searchBox(),const SizedBox(height:14),fridgeBanner(),section('Speciali di Ricette del Mondo'),specialBanner('Speciale Impasti','Tutti gli impasti per pizza e focaccia, dalla napoletana alla romana.','Impasti',Icons.local_pizza,orange,onTap:()=>openSpecialPage('Speciale Impasti','Impasti per pizza e focaccia da fare a casa.',specialDoughRecipes,Icons.local_pizza)),specialBanner('Speciale Hamburger','Classici, smash, gourmet e tutte le varianti da fare a casa.','Hamburger',Icons.lunch_dining,green2,onTap:()=>openSpecialPage('Speciale Hamburger','Una raccolta dedicata agli hamburger.',[...specialHamburgerRecipes,...catalog.where((r)=>r.title.toLowerCase().contains('hamburger')||r.tags.any((t)=>t.toLowerCase().contains('burger')))],Icons.lunch_dining)),specialBanner('Speciale Braceria','Carni, costine, spiedini, pulled pork e cotture alla brace.','Braceria',Icons.outdoor_grill,Color(0xFF8A3B12),onTap:()=>openSpecialPage('Speciale Braceria','Ricette per griglia, brace e cotture lente.',[...specialBraceriaRecipes,...catalog.where((r)=>r.tags.any((t)=>['carne','griglia','brace','bbq','pollo'].contains(t.toLowerCase()))||r.title.toLowerCase().contains('asado')||r.title.toLowerCase().contains('pulled'))],Icons.outdoor_grill)),specialBanner('Speciale Gourmet Stellato','Piatti gourmet e grandi ispirazioni d’alta cucina, con attribuzione dello chef quando presente.','Gourmet Stellato',Icons.auto_awesome,Color(0xFF9A7A18),onTap:()=>openSpecialPage('Speciale Gourmet Stellato','Una raccolta editoriale di alta cucina.',catalog.where((r)=>r.tags.any((t)=>t.toLowerCase()=='gourmet')).toList(),Icons.auto_awesome)),section('Le 10 ricette gratuite',action:'Vedi tutte',onAction:()=>setState(()=>tab=1)),SizedBox(height:205,child:ListView(scrollDirection:Axis.horizontal,children:all.take(10).map((r)=>miniCard(r)).toList())),ratingHomeSection('🏆 Ricette più votate',false),ratingHomeSection('😋 Ricette più buone',true),section('Esplora il mondo'),continentGrid(),section('Scopri Premium'),premiumBanner(),section('Idee per te'),...all.skip(10).take(5).map(recipeCard)]);
 Widget specialBanner(String title,String subtitle,String label,IconData icon,Color accent,{required VoidCallback onTap})=>Card(clipBehavior:Clip.antiAlias,elevation:2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),child:InkWell(onTap:onTap,child:Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(gradient:LinearGradient(colors:[const Color(0xFF16372A),accent.withOpacity(.92)])),child:Row(children:[Container(width:58,height:58,decoration:BoxDecoration(color:Colors.white.withOpacity(.14),borderRadius:BorderRadius.circular(18)),child:Icon(icon,color:Colors.white,size:32)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(subtitle,style:const TextStyle(color:Colors.white70,fontSize:13),maxLines:2,overflow:TextOverflow.ellipsis),const SizedBox(height:8),Row(children:[Text('SCOPRI $label',style:TextStyle(color:accent==orange?const Color(0xFFFFD98A):Colors.white,fontWeight:FontWeight.w900,fontSize:12)),const SizedBox(width:5),const Icon(Icons.arrow_forward_rounded,color:Colors.white,size:17)])]))]))));
 void openSpecialPage(String title,String subtitle,List<Recipe> recipes,IconData icon)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SpecialCollectionPage(title:title,subtitle:subtitle,recipes:recipes,icon:icon)));
 Widget ratingHomeSection(String title,bool taste){final ranked=catalog.where((r)=>countFor(r,taste:taste)>0).toList()..sort((a,b)=>avgFor(b,taste:taste).compareTo(avgFor(a,taste:taste))); final shown=ranked.take(5).toList(); return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[section(title,action:'Vedi tutte',onAction:()=>showRatingRanking(taste)),if(shown.isEmpty)Card(color:Colors.white,child:const Padding(padding:EdgeInsets.all(18),child:Text('Ancora nessun voto: sii il primo a valutare una ricetta ⭐',style:TextStyle(fontWeight:FontWeight.w700,color:ink)))) else ...shown.map((r)=>ratingRow(r,taste))]);}
 Widget ratingRow(Recipe r,bool taste)=>Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(leading:SizedBox(width:58,height:58,child:recipeVisual(r,height:58,radius:BorderRadius.circular(12))),title:Text(r.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,color:ink)),subtitle:Row(children:[stars(avgFor(r,taste:taste)),const SizedBox(width:5),Text('${avgFor(r,taste:taste).toStringAsFixed(1)} • ${countFor(r,taste:taste)} voti',style:const TextStyle(fontSize:11))]),trailing:const Icon(Icons.chevron_right),onTap:()=>openRecipe(r)));
 Widget stars(double value)=>Row(mainAxisSize:MainAxisSize.min,children:List.generate(5,(i)=>Icon(i<value.round()?Icons.star:Icons.star_border,size:17,color:orange)));
 void showRatingRanking(bool taste)=>showModalBottomSheet(context:context,showDragHandle:true,builder:(_){final ranked=catalog.where((r)=>countFor(r,taste:taste)>0).toList()..sort((a,b)=>avgFor(b,taste:taste).compareTo(avgFor(a,taste:taste)));return SafeArea(child:ListView(padding:const EdgeInsets.all(18),children:[Text(taste?'Ricette più buone':'Ricette più votate',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:10),...ranked.map((r)=>ratingRow(r,taste))]));});
 Widget searchBox()=>TextField(controller:search,onChanged:(_)=>setState((){}),onSubmitted:(_)=>setState(()=>tab=1),decoration:InputDecoration(hintText:'Cerca ricette, Paesi o ingredienti',prefixIcon:const Icon(Icons.search,color:green),suffixIcon:IconButton(onPressed:showFilters,icon:const Icon(Icons.tune,color:green)),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(30),borderSide:BorderSide.none),contentPadding:const EdgeInsets.symmetric(vertical:14)));
 Widget fridgeBanner()=>Card(elevation:0,color:const Color(0xFFE4F1E8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),child:InkWell(borderRadius:BorderRadius.circular(22),onTap:fridgePage,child:Padding(padding:const EdgeInsets.all(17),child:Row(children:[Container(width:52,height:52,decoration:BoxDecoration(color:green,borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.kitchen,color:Colors.white)),const SizedBox(width:14),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Cosa hai nel frigo?',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:ink)),SizedBox(height:4),Text('Seleziona gli ingredienti e scopri cosa puoi cucinare.',style:TextStyle(color:ink))])),const Icon(Icons.arrow_forward_ios_rounded,size:18,color:green)]))));
 Widget section(String t,{String? action,VoidCallback? onAction})=>Padding(padding:const EdgeInsets.only(top:22,bottom:10),child:Row(children:[Expanded(child:Text(t,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:ink))),if(action!=null)TextButton(onPressed:onAction,child:Text(action,style:const TextStyle(color:green,fontWeight:FontWeight.w800)))]));
 Widget miniCard(Recipe r)=>GestureDetector(onTap:()=>openRecipe(r),child:Container(width:165,margin:const EdgeInsets.only(right:12),child:Card(clipBehavior:Clip.antiAlias,elevation:2,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[recipeVisual(r,height:120,radius:BorderRadius.zero),Padding(padding:const EdgeInsets.fromLTRB(10,8,10,10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:4),Text('${flag(r.country)} ${r.country}',style:const TextStyle(fontSize:12)),const SizedBox(height:3),Text('${r.timeMin} min • ${cost(r,r.servings)}',style:const TextStyle(fontSize:11))]))]))));
 Widget continentGrid()=>GridView.count(crossAxisCount:3,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:8,mainAxisSpacing:8,childAspectRatio:1.1,children:[['Europa','🇪🇺'],['Asia','🌏'],['Americhe','🌎'],['Africa','🌍'],['Oceania','🌊'],['Medio Oriente','🕌']].map((x)=>Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFE8DFD1))),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(x[1],style:const TextStyle(fontSize:32)),const SizedBox(height:5),Text(x[0],style:const TextStyle(fontWeight:FontWeight.w800,color:ink))]))).toList());
 Widget premiumBanner()=>Card(clipBehavior:Clip.antiAlias,elevation:3,child:Container(decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF075B3A),Color(0xFF0C7A4B)])),padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Row(children:[Icon(Icons.workspace_premium,color:orange,size:32),SizedBox(width:8),Text('Passa a Premium',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900))]),const SizedBox(height:6),const Text('Sblocca tutte le ricette Premium, le raccolte speciali, storie, procedimenti e funzioni esclusive.',style:TextStyle(color:Colors.white,fontSize:15)),const SizedBox(height:12),Row(children:[priceChip('1 mese','€2,99'),priceChip('6 mesi','€14,99'),priceChip('12 mesi','€24,99')]),const SizedBox(height:12),FilledButton(style:FilledButton.styleFrom(backgroundColor:orange,foregroundColor:ink,minimumSize:const Size.fromHeight(48)),onPressed:premiumPage,child:const Text('Scopri Premium',style:TextStyle(fontWeight:FontWeight.w900)))])));
 Widget priceChip(String a,String b)=>Expanded(child:Container(margin:const EdgeInsets.only(right:6),padding:const EdgeInsets.symmetric(vertical:9,horizontal:5),decoration:BoxDecoration(color:Colors.white.withOpacity(.95),borderRadius:BorderRadius.circular(14)),child:Column(children:[Text(a,style:const TextStyle(fontSize:11,color:ink)),Text(b,style:const TextStyle(fontWeight:FontWeight.w900,color:green))])));
 Widget searchPage()=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Cerca',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:12),searchBox(),const SizedBox(height:10),Text('${filtered.length} ricette',style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:8),...filtered.map(recipeCard)]);
 Widget categoriesPage()=>ListView(padding:const EdgeInsets.all(16),children:[const Text('Categorie',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:12),Wrap(spacing:9,runSpacing:9,children:['Tutte','Antipasti','Primi','Secondi','Zuppe','Dolci','Pizze','Insalate'].map((x)=>ChoiceChip(label:Text(x),selected:category==x,onSelected:(_)=>setState(()=>category=x))).toList()),section('Esplora per Paese'),...all.take(20).map(recipeCard)]);
 Widget favoritesPage(){final list=all.where((r)=>favorites.contains(r.id)).toList();return ListView(padding:const EdgeInsets.all(16),children:[const Text('I tuoi preferiti',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink)),Text('${list.length} ricette salvate'),const SizedBox(height:12),if(list.isEmpty)Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[const Icon(Icons.favorite_border,size:48,color:green),const SizedBox(height:10),const Text('Le tue ricette preferite appariranno qui.',textAlign:TextAlign.center)]))) else ...list.map(recipeCard)]);}
 Widget profilePage()=>ListView(padding:const EdgeInsets.all(16),children:[Row(children:[CircleAvatar(radius:30,backgroundColor:const Color(0xFFDCEFE5),child:const Icon(Icons.person,color:green,size:34)),const SizedBox(width:12),const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Il tuo profilo',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:ink)),Text('Cucina, salva e scopri il mondo.')])]),const SizedBox(height:18),Card(child:ListTile(leading:const Icon(Icons.workspace_premium,color:orange),title:const Text('Premium',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Scegli o gestisci il tuo piano'),onTap:premiumPage)),Card(child:ListTile(leading:const Icon(Icons.language,color:green),title:const Text('Lingua'),subtitle:Text(language),trailing:DropdownButton<String>(value:language,items:['Italiano','English','Français','Español','Deutsch','Português'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>language=v!)))),Card(child:ListTile(leading:const Icon(Icons.favorite,color:Colors.red),title:const Text('Preferiti'),trailing:Text('${favorites.length}'),onTap:()=>setState(()=>tab=3))),Card(child:ListTile(leading:const Icon(Icons.shopping_cart,color:green),title:const Text('Lista della spesa'),trailing:Text('${shopping.length}'),onTap:shoppingPage)),Card(child:ListTile(leading:const Icon(Icons.kitchen,color:green),title:const Text('Cosa hai nel frigo?'),onTap:fridgePage)),const SizedBox(height:10),const Text('Le lingue sono disponibili nell’interfaccia; la traduzione editoriale completa delle 120 ricette sarà una fase dedicata.',style:TextStyle(fontSize:12,color:Colors.black54))]);
 Widget recipeCard(Recipe r)=>Card(margin:const EdgeInsets.only(bottom:11),clipBehavior:Clip.antiAlias,elevation:1,child:InkWell(onTap:()=>openRecipe(r),child:Row(children:[SizedBox(width:124,height:124,child:recipeVisual(r,height:124,radius:BorderRadius.zero)),Expanded(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(r.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16,color:ink))),if(r.premium)const Icon(Icons.workspace_premium,size:18,color:orange)]),const SizedBox(height:5),Text('${flag(r.country)} ${r.country}',style:const TextStyle(fontWeight:FontWeight.w600)),const SizedBox(height:5),Text('${r.prepMin} min prep • ${r.cookMin} min cottura • ${r.servings} porzioni',style:const TextStyle(fontSize:11)),Text(cost(r,r.servings),style:const TextStyle(fontSize:11,color:green,fontWeight:FontWeight.w800))]))),FavoriteButton(selected:favorites.contains(r.id),onTap:()=>toggleFavorite(r))])));
Widget recipeVisual(Recipe r,{double height=170,BorderRadius? radius})=>ClipRRect(borderRadius:radius??BorderRadius.circular(18),child:SizedBox(height:height,width:double.infinity,child:Image.asset('assets/images/${r.id}.jpg',fit:BoxFit.cover,filterQuality:FilterQuality.high,errorBuilder:(_,__,___)=>Container(color:pale,padding:const EdgeInsets.all(14),child:Image.asset('assets/logo_rdm.png',fit:BoxFit.contain)))));
 String cost(Recipe r,int servings){final base=1.9+r.ingredients.length*.9;final v=base*(servings/(r.servings==0?4:r.servings));return '€${v.toStringAsFixed(2)} stimati';}
 void toggleFavorite(Recipe r){final add=!favorites.contains(r.id);setState(()=>add?favorites.add(r.id):favorites.remove(r.id));ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(add?'❤️ Aggiunto ai preferiti':'♡ Rimosso dai preferiti'),behavior:SnackBarBehavior.floating,duration:const Duration(milliseconds:1500)));}
 void openRecipe(Recipe r){if(r.premium){Navigator.push(context,MaterialPageRoute(builder:(_)=>PaywallPage(recipe:r,onPremium:premiumPage)));}else Navigator.push(context,MaterialPageRoute(builder:(_)=>RecipePage(recipe:r,selected:favorites.contains(r.id),onFavorite:()=>toggleFavorite(r),onAdd:(i){setState(()=>shopping.add(i));},onAddAll:(){setState(()=>shopping.addAll(r.ingredients));},rating:avgFor(r),taste:avgFor(r,taste:true),ratingCount:countFor(r),tasteCount:countFor(r,taste:true),onRate:(v)=>castVote(r,v),onTaste:(v)=>castVote(r,v,taste:true))));}
 void premiumPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PremiumPage()));
 void shoppingPage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ShoppingPage(items:shopping)));
 void fridgePage()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>FridgePage(recipes:all,onOpen:openRecipe)));
 void showFilters(){showModalBottomSheet(context:context,showDragHandle:true,builder:(c)=>StatefulBuilder(builder:(c,setM)=>Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:category,items:['Tutte','Antipasti','Primi','Secondi','Zuppe','Dolci','Pizze','Insalate'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setM(()=>category=v!)),Slider(min:15,max:180,divisions:11,value:maxTime.toDouble(),label:'$maxTime min',onChanged:(v)=>setM(()=>maxTime=v.round())),FilledButton(onPressed:(){Navigator.pop(c);setState((){});},child:const Text('Applica filtri'))]))));}
}

class FavoriteButton extends StatefulWidget{final bool selected;final VoidCallback onTap;const FavoriteButton({super.key,required this.selected,required this.onTap});@override State<FavoriteButton> createState()=>_FavoriteButtonState();}
class _FavoriteButtonState extends State<FavoriteButton> with SingleTickerProviderStateMixin{late final c=AnimationController(vsync:this,duration:const Duration(milliseconds:260));@override void didUpdateWidget(covariant FavoriteButton old){super.didUpdateWidget(old);if(widget.selected&&!old.selected)c.forward(from:0);}@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext x)=>ScaleTransition(scale:Tween(begin:1.0,end:1.25).animate(CurvedAnimation(parent:c,curve:Curves.elasticOut)),child:IconButton(onPressed:(){widget.onTap();c.forward(from:0);},icon:Icon(widget.selected?Icons.favorite:Icons.favorite_border,color:widget.selected?Colors.red:Colors.black45)));}

class PremiumPage extends StatelessWidget{const PremiumPage({super.key});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Premium')),body:ListView(padding:const EdgeInsets.all(18),children:[Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[green,green2]),borderRadius:BorderRadius.circular(28)),child:Column(children:[const Icon(Icons.workspace_premium,size:64,color:orange),const SizedBox(height:8),const Text('Sblocca tutto il mondo delle ricette',textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)),const SizedBox(height:8),const Text('120 ricette base, raccolte speciali, storie, procedimenti completi e nuove destinazioni.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white))])),const SizedBox(height:18),...['Accesso a tutte le 120 ricette','Ingredienti e procedimenti completi','Storia, varianti e curiosità','Lista della spesa e funzione frigo','Nessuna pubblicità'].map((x)=>ListTile(leading:const Icon(Icons.check_circle,color:green),title:Text(x))),const SizedBox(height:10),Row(children:[plan('1 mese','€2,99'),plan('6 mesi','€14,99'),plan('12 mesi','€24,99')]),const SizedBox(height:14),FilledButton(style:FilledButton.styleFrom(backgroundColor:orange,foregroundColor:ink,minimumSize:const Size.fromHeight(52)),onPressed:(){ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Il pagamento reale sarà collegato a Google Play Billing dopo la configurazione dei prodotti in Play Console.')));},child:const Text('Attiva Premium',style:TextStyle(fontWeight:FontWeight.w900))),const SizedBox(height:8),const Text('Prezzi indicativi decisi per il lancio. Le condizioni di acquisto e rinnovo saranno mostrate chiaramente prima del pagamento.',textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Colors.black54))]));}
 Widget plan(String a,String b)=>Expanded(child:Card(child:Padding(padding:const EdgeInsets.symmetric(vertical:14,horizontal:5),child:Column(children:[Text(a,style:const TextStyle(fontWeight:FontWeight.w700)),Text(b,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:green))]))));

class PaywallPage extends StatelessWidget{final Recipe recipe;final VoidCallback onPremium;const PaywallPage({super.key,required this.recipe,required this.onPremium});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Anteprima Premium')),body:ListView(padding:const EdgeInsets.all(18),children:[recipeVisual(recipe,height:260),const SizedBox(height:12),Text('${flag(recipe.country)} ${recipe.country}',style:const TextStyle(fontWeight:FontWeight.w800,color:green)),Text(recipe.title,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:7),Text(recipe.description),const SizedBox(height:14),Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:pale,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('📖 La storia del piatto',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:7),Text(recipe.history,maxLines:5,overflow:TextOverflow.ellipsis)])),const SizedBox(height:14),const Text('🔒 Ingredienti e procedimento completo sono disponibili con Premium.',style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:16),FilledButton(onPressed:onPremium,child:const Text('Scopri i piani Premium'))]));}

class RecipePage extends StatefulWidget{final Recipe recipe;final bool selected;final VoidCallback onFavorite;final ValueChanged<String> onAdd;final VoidCallback onAddAll;final double rating,taste;final int ratingCount,tasteCount;final ValueChanged<int> onRate,onTaste;const RecipePage({super.key,required this.recipe,required this.selected,required this.onFavorite,required this.onAdd,required this.onAddAll,required this.rating, double? tasteRating, double? taste,required this.ratingCount,required this.tasteCount,required this.onRate,required this.onTaste}):taste=taste??tasteRating??0;@override State<RecipePage> createState()=>_RecipePageState();}
class _RecipePageState extends State<RecipePage>{late int servings;@override void initState(){super.initState();servings=widget.recipe.servings;}String scaleIng(String s){final m=RegExp(r'^(\d+(?:[\.,]\d+)?)\s*(.*)$').firstMatch(s);if(m==null||widget.recipe.servings==0)return s;final n=(double.tryParse(m.group(1)!.replaceAll(',','.'))??0)*servings/widget.recipe.servings;return '${n%1==0?n.toInt():n.toStringAsFixed(1)} ${m.group(2)}';}@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Ricetta'),actions:[IconButton(onPressed:()=>SharePlus.instance.share(ShareParams(text:'${widget.recipe.title} — Ricette del Mondo')),icon:const Icon(Icons.share_outlined)),FavoriteButton(selected:widget.selected,onTap:widget.onFavorite)]),body:ListView(padding:const EdgeInsets.fromLTRB(18,8,18,30),children:[recipeVisual(widget.recipe,height:285,radius:BorderRadius.circular(26)),const SizedBox(height:13),Text('${flag(widget.recipe.country)} ${widget.recipe.country}',style:const TextStyle(fontWeight:FontWeight.w800,color:green)),Text(widget.recipe.title,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:4),Text(widget.recipe.cuisine,style:const TextStyle(color:Colors.black54)),const SizedBox(height:10),Wrap(spacing:7,runSpacing:7,children:[info('${widget.recipe.prepMin} min','Prep'),info('${widget.recipe.cookMin} min','Cottura'),info(widget.recipe.difficulty,'Difficoltà'),info('$servings','Porzioni')]),const SizedBox(height:12),CookingGuide(recipe:widget.recipe),const SizedBox(height:12),RatingPanel(recipe:widget.recipe,rating:widget.rating,taste:widget.taste,ratingCount:widget.ratingCount,tasteCount:widget.tasteCount,onRate:widget.onRate,onTaste:widget.onTaste),const SizedBox(height:12),Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:pale,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('La storia del piatto',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:7),Text(widget.recipe.history)])),const SizedBox(height:18),Row(children:[const Expanded(child:Text('Ingredienti',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:ink))),IconButton(onPressed:servings>1?()=>setState(()=>servings--):null,icon:const Icon(Icons.remove_circle_outline)),Text('$servings',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18)),IconButton(onPressed:()=>setState(()=>servings++),icon:const Icon(Icons.add_circle_outline)),TextButton.icon(onPressed:(){widget.onAddAll();ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('🛒 Tutti gli ingredienti sono stati aggiunti alla lista della spesa'),behavior:SnackBarBehavior.floating));},icon:const Icon(Icons.shopping_cart_outlined),label:const Text('Tutti'))]),...widget.recipe.ingredients.map((i)=>ListTile(contentPadding:EdgeInsets.zero,title:Text(scaleIng(i)),leading:const Icon(Icons.circle,size:7,color:green),trailing:IconButton(onPressed:(){widget.onAdd(scaleIng(i));ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('🛒 Aggiunto alla lista della spesa'),behavior:SnackBarBehavior.floating));},icon:const Icon(Icons.add_shopping_cart,color:green)))),const SizedBox(height:10),const Text('Preparazione',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:ink)),const SizedBox(height:7),...widget.recipe.steps.asMap().entries.map((e)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(radius:16,backgroundColor:green,child:Text('${e.key+1}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900))),const SizedBox(width:10),Expanded(child:Text(e.value,style:const TextStyle(height:1.35)))]))) ]));}
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

class RatingPanel extends StatelessWidget {
  final Recipe recipe;
  final double rating, taste;
  final int ratingCount, tasteCount;
  final ValueChanged<int> onRate, onTaste;

  const RatingPanel({
    super.key,
    required this.recipe,
    required this.rating,
    required this.taste,
    required this.ratingCount,
    required this.tasteCount,
    required this.onRate,
    required this.onTaste,
  });

  Widget row(String title, double value, int count, ValueChanged<int> onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 5),
        Row(
          children: [
            ...List.generate(5, (i) => IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: () => onTap(i + 1),
              icon: Icon(
                i < value.round() ? Icons.star : Icons.star_border,
                color: orange,
                size: 28,
              ),
            )),
            const SizedBox(width: 5),
            Text(
              count == 0 ? 'Ancora nessun voto' : '${value.toStringAsFixed(1)} / 5  •  $count voti',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext c) {
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
          row('Voto della ricetta', rating, ratingCount, onRate),
          const SizedBox(height: 10),
          row('Bontà', taste, tasteCount, onTaste),
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
