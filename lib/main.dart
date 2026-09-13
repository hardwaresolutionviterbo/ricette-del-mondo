
import 'package:flutter/material.dart';
import 'recipe_repository.dart';

void main() => runApp(const RicetteApp());

const flags = {
  'Italia':'🇮🇹','Giappone':'🇯🇵','Messico':'🇲🇽','India':'🇮🇳','Grecia':'🇬🇷',
  'Nord Europa':'🌍','Thailandia':'🇹🇭','Spagna':'🇪🇸','Medio Oriente':'🌍',
  'Corea del Sud':'🇰🇷','Perù':'🇵🇪','Francia':'🇫🇷','Turchia':'🇹🇷','Cina':'🇨🇳',
  'Stati Uniti':'🇺🇸','USA':'🇺🇸','Marocco':'🇲🇦','Brasile':'🇧🇷','Argentina':'🇦🇷',
  'Vietnam':'🇻🇳','Indonesia':'🇮🇩','Portogallo':'🇵🇹','Germania':'🇩🇪',
  'Regno Unito':'🇬🇧','Etiopia':'🇪🇹','Libano':'🇱🇧','Israele':'🇮🇱',
  'Egitto':'🇪🇬','Australia':'🇦🇺','Filippine':'🇵🇭'
};
String countryFlag(String c) => flags[c] ?? '🌍';

Widget recipeVisual(Recipe r, {double height=170, BorderRadius? radius}) => ClipRRect(
  borderRadius: radius ?? BorderRadius.circular(20),
  child: SizedBox(
    height: height,
    width: double.infinity,
    child: Image.asset(
      'assets/images/${r.id}.jpg',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFE8EFE5),
        alignment: Alignment.center,
        child: Text(
          '${countryFlag(r.country)}\n${r.title}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
    ),
  ),
);

class Recipe {
  final String id,title,country,cuisine,category,difficulty,description,history;
  final int timeMin,servings,prepMin,cookMin;
  final bool premium;
  final List<String> ingredients,steps,tags;
  final String editorialStatus;
  const Recipe({required this.id,required this.title,required this.country,required this.cuisine,
    required this.category,required this.timeMin,required this.servings,required this.prepMin,
    required this.cookMin,required this.difficulty,required this.premium,required this.description,required this.history,
    required this.ingredients,required this.steps,required this.tags,required this.editorialStatus});
  factory Recipe.fromJson(Map<String,dynamic> j)=>Recipe(
    id:j['id']??'',title:j['title']??'',country:j['country']??'',cuisine:j['cuisine']??'',
    category:j['category']??'',timeMin:j['timeMin']??0,servings:j['servings']??4,
    prepMin:j['prepMin']??0,cookMin:j['cookMin']??0,difficulty:j['difficulty']??'Media',
    premium:j['premium']==true,description:j['description']??'',history:j['history']??'',
    ingredients:List<String>.from(j['ingredients']??const []),
    steps:List<String>.from(j['steps']??const []),tags:List<String>.from(j['tags']??const []),
    editorialStatus:j['editorialStatus']??'draft');
}

class RicetteApp extends StatelessWidget {
  const RicetteApp({super.key});
  @override Widget build(BuildContext c)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'Ricette del Mondo',
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF2F6B45)),
      scaffoldBackgroundColor:const Color(0xFFFFFBF3),inputDecorationTheme:InputDecorationTheme(
        filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none))),
    home:const AppShell());
}

class AppShell extends StatefulWidget { const AppShell({super.key}); @override State<AppShell> createState()=>_AppShellState(); }
class _AppShellState extends State<AppShell> {
  final repo=RecipeRepository(), search=TextEditingController();
  List<Recipe> all=[]; final favorites=<String>{}; final shopping=<String>{};
  int tab=0; String category='Tutte',diet='Tutte',language='Italiano'; int maxTime=180;
  @override void initState(){super.initState();repo.loadRecipes().then((r)=>setState(()=>all=r));}

  List<Recipe> get filtered {
    final s=search.text.trim().toLowerCase();
    return all.where((r){
      final hay='${r.title} ${r.country} ${r.cuisine} ${r.category} ${r.ingredients.join(' ')} ${r.tags.join(' ')}'.toLowerCase();
      return (s.isEmpty||s.split(RegExp(r'[, ]+')).where((x)=>x.isNotEmpty).every(hay.contains))
        &&(category=='Tutte'||r.category==category)&&(r.timeMin<=maxTime)
        &&(diet=='Tutte'||r.tags.any((x)=>x.toLowerCase()==diet.toLowerCase()));
    }).toList();
  }

  @override Widget build(BuildContext c){
    if(all.isEmpty)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    final pages=[home(),searchPage(),favoritesPage(),premiumPage(),profilePage()];
    return Scaffold(body:SafeArea(child:pages[tab]),bottomNavigationBar:NavigationBar(selectedIndex:tab,
      onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
        NavigationDestination(icon:Icon(Icons.search),label:'Cerca'),
        NavigationDestination(icon:Icon(Icons.favorite_border),selectedIcon:Icon(Icons.favorite),label:'Preferiti'),
        NavigationDestination(icon:Icon(Icons.workspace_premium_outlined),selectedIcon:Icon(Icons.workspace_premium),label:'Premium'),
        NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profilo')]));
  }

  Widget home()=>ListView(padding:const EdgeInsets.fromLTRB(20,18,20,30),children:[
    Row(children:[
      Expanded(child:Image.asset('assets/logo_rdm.png',height:92,fit:BoxFit.contain,alignment:Alignment.centerLeft)),
      CircleAvatar(child:IconButton(onPressed:()=>setState(()=>tab=4),icon:const Icon(Icons.person_outline)))
    ]),
    const SizedBox(height:18),searchBox(),const SizedBox(height:14),
    Card(color:const Color(0xFFE8EFE5),child:InkWell(onTap:fridgePage,child:Padding(padding:const EdgeInsets.all(18),child:const Row(children:[
      CircleAvatar(child:Icon(Icons.kitchen)),SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Cosa hai nel frigo?',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
        SizedBox(height:4),Text('Seleziona gli ingredienti e trova cosa puoi cucinare.') ])),Icon(Icons.chevron_right)]))),
    section('Ricetta del giorno'),Card(clipBehavior:Clip.antiAlias,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      recipeVisual(all.first,height:190,radius:BorderRadius.zero),Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${countryFlag(all.first.country)} ${all.first.country}',style:const TextStyle(fontWeight:FontWeight.w700)),
        const SizedBox(height:4),Text(all.first.title,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)),
        const SizedBox(height:4),Text('${all.first.timeMin} min • ${all.first.servings} persone • ${estimatedCost(all.first,all.first.servings)}'),
        const SizedBox(height:10),FilledButton(onPressed:()=>openRecipe(all.first),child:const Text('Scopri la ricetta'))]))])),
    section('Esplora per categoria'),SizedBox(height:45,child:ListView(scrollDirection:Axis.horizontal,children:[
      'Tutte','Primi','Secondi','Antipasti','Zuppe','Dolci','Pizze'].map((x)=>Padding(padding:const EdgeInsets.only(right:8),
        child:ChoiceChip(label:Text(x),selected:category==x,onSelected:(_)=>setState((){category=x;tab=1;})))).toList())),
    section('Idee per te'),...all.take(6).map(recipeCard),
  ]);

  Widget searchBox()=>TextField(controller:search,onChanged:(_)=>setState((){}),onSubmitted:(_)=>setState(()=>tab=1),
    decoration:InputDecoration(hintText:'Cosa vuoi cucinare?',prefixIcon:const Icon(Icons.search),
      suffixIcon:IconButton(onPressed:showFilters,icon:const Icon(Icons.tune))));
  Widget searchPage()=>ListView(padding:const EdgeInsets.fromLTRB(20,18,20,30),children:[
    const Text('Cerca',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:14),searchBox(),
    const SizedBox(height:12),Text('${filtered.length} risultati'),const SizedBox(height:8),...filtered.map(recipeCard)]);
  Widget favoritesPage(){final list=all.where((r)=>favorites.contains(r.id)).toList();return ListView(padding:const EdgeInsets.all(20),children:[
    const Text('I miei preferiti',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900)),Text('${list.length} ricette salvate'),
    const SizedBox(height:14),if(list.isEmpty)const Text('Tocca il cuore per salvare una ricetta.') else ...list.map(recipeCard)]);}
  Widget premiumPage()=>ListView(padding:const EdgeInsets.all(20),children:[
    const Text('Premium',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:8),
    const Text('Scopri il catalogo completo. Anche le ricette Premium mostrano foto, Paese e anteprima.'),
    const SizedBox(height:16),...all.where((r)=>r.premium).take(8).map(recipeCard)]);
  Widget profilePage()=>ListView(padding:const EdgeInsets.all(20),children:[
    const Text('Profilo',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:18),
    Card(child:ListTile(leading:const Icon(Icons.language),title:const Text('Lingua'),subtitle:Text(language),
      trailing:DropdownButton<String>(value:language,items:['Italiano','English','Français','Español','Deutsch','Português']
        .map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>language=v!)))),
    Card(child:ListTile(leading:const Icon(Icons.favorite),title:const Text('Preferiti'),trailing:Text('${favorites.length}'))),
    Card(child:ListTile(leading:const Icon(Icons.shopping_cart),title:const Text('Lista della spesa'),trailing:Text('${shopping.length}'))),
    Card(child:ListTile(leading:const Icon(Icons.kitchen),title:const Text('Cosa hai nel frigo?'),onTap:fridgePage))]);

  Widget section(String t)=>Padding(padding:const EdgeInsets.only(top:22,bottom:10),child:Text(t,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)));

  Widget recipeCard(Recipe r)=>Card(margin:const EdgeInsets.only(bottom:12),clipBehavior:Clip.antiAlias,child:InkWell(onTap:()=>openRecipe(r),
    child:Row(children:[SizedBox(width:112,height:112,child:recipeVisual(r,height:112,radius:BorderRadius.zero)),
      Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(12,10,4,10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(r.title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),const SizedBox(height:4),
        Text('${countryFlag(r.country)} ${r.country}'),const SizedBox(height:4),
        Text('${r.timeMin} min • ${r.servings} persone • ${estimatedCost(r,r.servings)}',style:const TextStyle(fontSize:12)),
      ]))),FavoriteButton(selected:favorites.contains(r.id),onTap:()=>toggleFavorite(r))])));

  void toggleFavorite(Recipe r){final adding=!favorites.contains(r.id);setState(()=>adding?favorites.add(r.id):favorites.remove(r.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(adding?'❤️ Aggiunto ai preferiti':'Rimosso dai preferiti'),
      behavior:SnackBarBehavior.floating,duration:const Duration(milliseconds:1600)));}

  void openRecipe(Recipe r){if(r.premium){Navigator.push(context,MaterialPageRoute(builder:(_)=>PaywallPage(recipe:r)));}else{
    Navigator.push(context,MaterialPageRoute(builder:(_)=>RecipePage(recipe:r,favorite:favorites.contains(r.id),
      onFavorite:()=>toggleFavorite(r),onAddIngredient:(i){setState(()=>shopping.add(i));},
      onAddAll:(){setState(()=>shopping.addAll(r.ingredients));})));}}

  void fridgePage(){Navigator.push(context,MaterialPageRoute(builder:(_)=>FridgePage(recipes:all,onOpen:openRecipe)));}
  void showFilters(){
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, setM) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                items: ['Tutte','Primi','Secondi','Antipasti','Zuppe','Dolci','Pizze']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                onChanged: (v) => setM(() => category = v!),
              ),
              Slider(
                min: 15,
                max: 180,
                divisions: 11,
                value: maxTime.toDouble(),
                onChanged: (v) => setM(() => maxTime = v.round()),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(c);
                  setState(() {});
                },
                child: const Text('Applica'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String estimatedCost(Recipe r,int servings){final base=1.80+r.ingredients.length*0.95;final value=base*(servings/(r.servings==0?4:r.servings));return '€${value.toStringAsFixed(2)} stimati';}
}

class FavoriteButton extends StatefulWidget{final bool selected;final VoidCallback onTap;const FavoriteButton({super.key,required this.selected,required this.onTap});
@override State<FavoriteButton> createState()=>_FavoriteButtonState();}
class _FavoriteButtonState extends State<FavoriteButton> with SingleTickerProviderStateMixin{
 late final AnimationController c=AnimationController(vsync:this,duration:const Duration(milliseconds:260));
 @override void didUpdateWidget(covariant FavoriteButton old){super.didUpdateWidget(old);if(widget.selected&&!old.selected)c.forward(from:0);}
 @override void dispose(){c.dispose();super.dispose();}
 @override Widget build(BuildContext context) => ScaleTransition(
   scale: Tween(begin:1.0,end:1.28).animate(
     CurvedAnimation(parent:c,curve:Curves.elasticOut),
   ),
   child: IconButton(
     onPressed: () { widget.onTap(); c.forward(from:0); },
     icon: Icon(
       widget.selected ? Icons.favorite : Icons.favorite_border,
       color: widget.selected ? Colors.red : Colors.grey.shade700,
     ),
   ),
 );}

class PaywallPage extends StatelessWidget{final Recipe recipe;const PaywallPage({super.key,required this.recipe});
@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Ricetta Premium')),body:ListView(padding:const EdgeInsets.all(20),children:[
 recipeVisual(recipe,height:270,radius:BorderRadius.circular(24)),const SizedBox(height:14),
 Text('${countryFlag(recipe.country)} ${recipe.country}',style:const TextStyle(fontWeight:FontWeight.w800)),Text(recipe.title,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900)),
 const SizedBox(height:8),Text(recipe.description),const SizedBox(height:12),
 Wrap(spacing:8,children:[Chip(label:Text('${recipe.servings} porzioni')),Chip(label:Text('${recipe.timeMin} min')),Chip(label:Text(estimatedCostStatic(recipe)))]),
 const SizedBox(height:14),Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFFFF1D9),borderRadius:BorderRadius.circular(20)),
 child:const Text('🔒 Contenuto Premium\n\nPuoi vedere foto, Paese, costo stimato e anteprima. Ingredienti completi e preparazione dettagliata sono riservati agli abbonati.')),
 const SizedBox(height:20),FilledButton.icon(onPressed:(){},icon:const Icon(Icons.workspace_premium),label:const Text('Scopri Premium'))]));}
String estimatedCostStatic(Recipe r)=>'€${(1.80+r.ingredients.length*.95).toStringAsFixed(2)} stimati';

class RecipePage extends StatefulWidget{final Recipe recipe;final bool favorite;final VoidCallback onFavorite;final ValueChanged<String> onAddIngredient;final VoidCallback onAddAll;
const RecipePage({super.key,required this.recipe,required this.favorite,required this.onFavorite,required this.onAddIngredient,required this.onAddAll});
@override State<RecipePage> createState()=>_RecipePageState();}
class _RecipePageState extends State<RecipePage>{late int servings;@override void initState(){super.initState();servings=widget.recipe.servings;}
double scale(String s){final n=double.tryParse(s.replaceAll(',','.'))??0;return n*servings/widget.recipe.servings;}
String scaledIngredient(String s){final m=RegExp(r'^(\\d+(?:[\\.,]\\d+)?)\\s*(.*)$').firstMatch(s);if(m==null)return s;final v=scale(m.group(1)!);return '${v%1==0?v.toInt():v.toStringAsFixed(1)} ${m.group(2)}';}
@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Ricetta'),actions:[FavoriteButton(selected:widget.favorite,onTap:widget.onFavorite)]),
body:ListView(padding:const EdgeInsets.fromLTRB(20,10,20,30),children:[
recipeVisual(widget.recipe,height:260,radius:BorderRadius.circular(24)),const SizedBox(height:14),
Text('${countryFlag(widget.recipe.country)} ${widget.recipe.country}',style:const TextStyle(fontWeight:FontWeight.w800)),Text(widget.recipe.title,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900)),
const SizedBox(height:8),Text('${widget.recipe.cuisine} • ${widget.recipe.category}'),
const SizedBox(height:10),Row(children:[const Text('Porzioni',style:TextStyle(fontWeight:FontWeight.w800)),IconButton(onPressed:servings>1?()=>setState(()=>servings--):null,icon:const Icon(Icons.remove_circle_outline)),Text('$servings',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),IconButton(onPressed:()=>setState(()=>servings++),icon:const Icon(Icons.add_circle_outline))]),
Wrap(spacing:8,runSpacing:6,children:[Chip(label:Text('${widget.recipe.timeMin} min')),Chip(label:Text('${widget.recipe.prepMin} min prep')),Chip(label:Text('${widget.recipe.cookMin} min cottura')),Chip(label:Text('€${(1.80+widget.recipe.ingredients.length*.95*servings/widget.recipe.servings).toStringAsFixed(2)} stimati'))]),
const SizedBox(height:8),const Text('Costo: stima indicativa, può variare in base a prezzi, marca e offerte.',style:TextStyle(fontSize:12)),const SizedBox(height:16),Text(widget.recipe.description),const SizedBox(height:20),
Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFFE8EFE5),borderRadius:BorderRadius.circular(18)),
child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('📖 La storia del piatto',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:8),
Text(widget.recipe.history) ])),
const SizedBox(height:20),Row(children:[const Expanded(child:Text('Ingredienti',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),),
TextButton.icon(onPressed:(){widget.onAddAll();ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('🛒 Tutti gli ingredienti sono stati aggiunti alla lista della spesa'),behavior:SnackBarBehavior.floating));},icon:const Icon(Icons.shopping_cart_outlined),label:const Text('Aggiungi tutto'))]),
...widget.recipe.ingredients.map((i)=>ListTile(leading:const Icon(Icons.check_circle_outline),title:Text(scaledIngredient(i)),trailing:IconButton(onPressed:(){widget.onAddIngredient(scaledIngredient(i));ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('🛒 Aggiunto alla lista della spesa'),behavior:SnackBarBehavior.floating));},icon:const Icon(Icons.add_shopping_cart)))),
const SizedBox(height:12),const Text('Preparazione',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
...widget.recipe.steps.asMap().entries.map((e)=>ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(child:Text('${e.key+1}')),title:Text(e.value))),
]));}

class FridgePage extends StatefulWidget{final List<Recipe> recipes;final ValueChanged<Recipe> onOpen;const FridgePage({super.key,required this.recipes,required this.onOpen});
@override State<FridgePage> createState()=>_FridgePageState();}
class _FridgePageState extends State<FridgePage>{final selected=<String>{};final ingredients=['uova','farina','pomodori','cipolla','aglio','olio','burro','latte','formaggio','pollo','riso','pasta','patate','pesce','carne','limone','basilico','pepe'];
@override Widget build(BuildContext c){final matches=widget.recipes.where((r){final names=r.ingredients.map((x)=>x.toLowerCase()).toList();return selected.isEmpty||selected.every((s)=>names.any((n)=>n.contains(s)));}).toList();
return Scaffold(appBar:AppBar(title:const Text('Cosa hai nel frigo?')),body:ListView(padding:const EdgeInsets.all(20),children:[
const Text('Seleziona ciò che hai',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:8),Wrap(spacing:7,runSpacing:7,children:ingredients.map((x)=>FilterChip(label:Text(x),selected:selected.contains(x),onSelected:(v)=>setState(()=>v?selected.add(x):selected.remove(x)))).toList()),
const SizedBox(height:20),Text(selected.isEmpty?'Seleziona ingredienti per trovare idee.':'${matches.length} ricette trovate',style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:10),
...matches.take(20).map((r)=>Card(child:ListTile(leading:SizedBox(width:58,height:58,child:recipeVisual(r,height:58,radius:BorderRadius.circular(10))),title:Text(r.title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${countryFlag(r.country)} ${r.country}'),onTap:()=>widget.onOpen(r))))]));}}
