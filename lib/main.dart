import 'package:flutter/material.dart';
import 'recipe_repository.dart';

void main() => runApp(const RicetteApp());

String? recipeImage(String id) {
  // V3: tutte le ricette hanno una superficie visuale; le foto reali
  // disponibili vengono usate direttamente, le altre mostrano una card
  // Premium illustrata finché non vengono sostituite da fotografie licenziate.
  return 'assets/images/$id.jpg';
}

String countryFlag(String country) {
  const flags = {
    'Italia': '🇮🇹', 'Giappone': '🇯🇵', 'Messico': '🇲🇽', 'India': '🇮🇳',
    'Grecia': '🇬🇷', 'Nord Europa': '🌍', 'Thailandia': '🇹🇭', 'Spagna': '🇪🇸',
    'Medio Oriente': '🌍', 'Corea del Sud': '🇰🇷', 'Perù': '🇵🇪',
    'Francia': '🇫🇷', 'Turchia': '🇹🇷', 'Cina': '🇨🇳', 'Stati Uniti': '🇺🇸',
    'Marocco': '🇲🇦', 'Brasile': '🇧🇷', 'Argentina': '🇦🇷', 'Vietnam': '🇻🇳',
    'Indonesia': '🇮🇩', 'Portogallo': '🇵🇹', 'Germania': '🇩🇪',
    'Regno Unito': '🇬🇧', 'Etiopia': '🇪🇹', 'Libano': '🇱🇧', 'Israele': '🇮🇱',
    'Egitto': '🇪🇬', 'Australia': '🇦🇺', 'Filippine': '🇵🇭',
  };
  return flags[country] ?? '🌍';
}

Widget recipeVisual(Recipe r, {double height = 150, BorderRadius? radius}) {
  final path = recipeImage(r.id);
  return Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      borderRadius: radius ?? BorderRadius.circular(18),
      gradient: LinearGradient(
        colors: [const Color(0xFFE8EFE5), const Color(0xFFFFE8C7)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Image.asset(
      path!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(countryFlag(r.country), style: const TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            Text(r.title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('Anteprima Premium', style: TextStyle(
              color: Colors.black.withOpacity(.62), fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ),
  );
}

class Recipe {
  final String id, title, country, cuisine, category, difficulty, description;
  final int timeMin, servings, prepMin, cookMin;
  final bool premium;
  final List<String> ingredients, steps, tags;
  final String editorialStatus;

  const Recipe({
    required this.id, required this.title, required this.country,
    required this.cuisine, required this.category, required this.timeMin,
    required this.servings, required this.prepMin, required this.cookMin, required this.difficulty, required this.premium,
    required this.description, required this.ingredients, required this.steps,
    required this.tags, required this.editorialStatus,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
    id: j['id'] ?? '', title: j['title'] ?? '', country: j['country'] ?? '',
    cuisine: j['cuisine'] ?? '', category: j['category'] ?? '',
    timeMin: j['timeMin'] ?? 0, servings: j['servings'] ?? 0,
    prepMin: j['prepMin'] ?? 0, cookMin: j['cookMin'] ?? 0,
    difficulty: j['difficulty'] ?? 'Media', premium: j['premium'] == true,
    description: j['description'] ?? '',
    ingredients: List<String>.from(j['ingredients'] ?? const []),
    steps: List<String>.from(j['steps'] ?? const []),
    tags: List<String>.from(j['tags'] ?? const []),
    editorialStatus: j['editorialStatus'] ?? 'draft',
  );
}

class RicetteApp extends StatelessWidget {
  const RicetteApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ricette del Mondo',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6B45)),
      scaffoldBackgroundColor: const Color(0xFFFFFBF3),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final repo = RecipeRepository();
  final search = TextEditingController();
  List<Recipe> all = [];
  final favorites = <String>{};
  final shopping = <String>{};
  int tab = 0;
  String category = 'Tutte';
  String diet = 'Tutte';
  int maxTime = 180;

  @override
  void initState() {
    super.initState();
    repo.loadRecipes().then((r) => setState(() => all = r));
  }

  List<Recipe> get filtered {
    final s = search.text.trim().toLowerCase();
    return all.where((r) {
      final hay = '${r.title} ${r.country} ${r.cuisine} ${r.category} '
          '${r.ingredients.join(' ')} ${r.tags.join(' ')}'.toLowerCase();
      final okText = s.isEmpty || s.split(RegExp(r'[, ]+'))
          .where((x) => x.isNotEmpty).every(hay.contains);
      final okCat = category == 'Tutte' || r.category == category;
      final okTime = r.timeMin <= maxTime;
      final okDiet = diet == 'Tutte' || r.tags.map((x) => x.toLowerCase()).contains(diet.toLowerCase());
      return okText && okCat && okTime && okDiet;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = [home(), searchPage(), favoritesPage(), premiumPage(), profilePage()];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Cerca'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Preferiti'),
          NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: 'Premium'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profilo'),
        ],
      ),
    );
  }

  Widget home() {
    final popular = all.take(6).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Ricette del Mondo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          SizedBox(height: 3), Text('Ogni ricetta è un viaggio.'),
        ])),
        CircleAvatar(child: IconButton(onPressed: () => setState(() => tab = 4), icon: const Icon(Icons.person_outline))),
      ]),
      const SizedBox(height: 18),
      searchBox(),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFFE8EFE5), borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ricetta del giorno', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(all.first.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          recipeVisual(all.first, height: 150),
          const SizedBox(height: 4),
          Text('${all.first.country} • ${all.first.timeMin} min'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => openRecipe(all.first), child: const Text('Scopri la ricetta')),
        ]),
      ),
      section('Esplora per categoria'),
      SizedBox(height: 45, child: ListView(
        scrollDirection: Axis.horizontal,
        children: ['Tutte','Primi','Secondi','Antipasti','Zuppe','Dolci','Pizze'].map((c) =>
          Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
            label: Text(c), selected: category == c,
            onSelected: (_) => setState(() { category = c; tab = 1; }),
          ))).toList(),
      )),
      section('Esigenze alimentari'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        'Senza glutine','Ridotto sodio','Senza lattosio','Vegano','Vegetariano'
      ].map((d) => ActionChip(label: Text(d), onPressed: () {
        setState(() { diet = d; tab = 1; });
      })).toList()),
      section('Idee per te'),
      ...popular.map(recipeCard),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: surprise, icon: const Icon(Icons.auto_awesome), label: const Text('Sorprendimi!')),
    ]);
  }

  Widget searchBox() => TextField(
    controller: search, onChanged: (_) => setState(() {}),
    onSubmitted: (_) => setState(() => tab = 1),
    decoration: InputDecoration(
      hintText: 'Cosa vuoi cucinare?',
      prefixIcon: const Icon(Icons.search),
      suffixIcon: IconButton(onPressed: () => showFilters(), icon: const Icon(Icons.tune)),
    ),
  );

  Widget searchPage() => ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
    const Text('Cerca', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
    const SizedBox(height: 14), searchBox(), const SizedBox(height: 12),
    Row(children: [
      if (category != 'Tutte') FilterChip(label: Text(category), onSelected: (_) => setState(() => category = 'Tutte')),
      if (diet != 'Tutte') Padding(padding: const EdgeInsets.only(left: 8), child:
        FilterChip(label: Text(diet), onSelected: (_) => setState(() => diet = 'Tutte'))),
      const Spacer(), Text('${filtered.length} risultati'),
    ]),
    const SizedBox(height: 8),
    if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Nessuna ricetta trovata. Prova altri ingredienti.')))
    else ...filtered.map(recipeCard),
  ]);

  Widget favoritesPage() {
    final list = all.where((r) => favorites.contains(r.id)).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('I miei preferiti', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('${list.length} ricette salvate'),
      const SizedBox(height: 14),
      if (list.isEmpty) const Text('Tocca il cuore su una ricetta per salvarla qui.')
      else ...list.map(recipeCard),
    ]);
  }

  Widget premiumPage() => ListView(padding: const EdgeInsets.all(20), children: [
    Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
      color: const Color(0xFFE8EFE5), borderRadius: BorderRadius.circular(24)), child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.workspace_premium, size: 44),
        SizedBox(height: 12),
        Text('Ricette del Mondo Premium', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        Text('Scopri il catalogo completo oltre le prime 10 ricette gratuite.'),
      ])),
    section('Cosa include'),
    const ListTile(leading: Icon(Icons.menu_book), title: Text('Catalogo internazionale')),
    const ListTile(leading: Icon(Icons.filter_alt), title: Text('Filtri e collezioni')),
    const ListTile(leading: Icon(Icons.shopping_cart_outlined), title: Text('Lista della spesa')),
    const SizedBox(height: 10),
    FilledButton(onPressed: () {}, child: const Text('Attiva Premium')),
  ]);

  Widget profilePage() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Profilo', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
    const SizedBox(height: 18),
    Card(child: ListTile(leading: const Icon(Icons.favorite), title: const Text('Preferiti'), trailing: Text('${favorites.length}'))),
    Card(child: ListTile(leading: const Icon(Icons.shopping_cart), title: const Text('Lista della spesa'), trailing: Text('${shopping.length}'))),
    Card(child: const ListTile(leading: Icon(Icons.tune), title: Text('Preferenze alimentari'))),
    Card(child: const ListTile(leading: Icon(Icons.settings_outlined), title: Text('Impostazioni'))),
  ]);

  Widget section(String title) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)));

  Widget recipeCard(Recipe r) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: () => openRecipe(r), child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(width: 82, height: 82, decoration: BoxDecoration(
          color: const Color(0xFFE8EFE5), borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(recipeImage(r.id)!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(child: Text(countryFlag(r.country),
              style: const TextStyle(fontSize: 30)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4), Text('${countryFlag(r.country)} ${r.country} • ${r.cuisine}'),
          const SizedBox(height: 4), Text('${r.timeMin} min • ${r.difficulty}'),
        ])),
        IconButton(onPressed: () => toggleFavorite(r),
          icon: Icon(favorites.contains(r.id) ? Icons.favorite : Icons.favorite_border)),
      ]),
    )),
  );

  void toggleFavorite(Recipe r) {
    final adding = !favorites.contains(r.id);
    setState(() => adding ? favorites.add(r.id) : favorites.remove(r.id));
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(adding ? '❤️ Aggiunto ai preferiti' : 'Rimosso dai preferiti'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void openRecipe(Recipe r) {
    if (r.premium) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PaywallPage(recipe: r)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RecipePage(
        recipe: r, favorite: favorites.contains(r.id),
        onFavorite: () => toggleFavorite(r),
        onAddIngredient: (i) => setState(() => shopping.add(i)),
      )));
    }
  }

  void surprise() {
    final r = all[DateTime.now().millisecond % all.length];
    openRecipe(r);
  }

  void showFilters() {
    showModalBottomSheet(context: context, builder: (_) => StatefulBuilder(
      builder: (context, setModal) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Filtri', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: category, decoration: const InputDecoration(labelText: 'Categoria'),
            items: ['Tutte','Primi','Secondi','Antipasti','Zuppe','Dolci','Pizze']
              .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) => setModal(() => category = v ?? 'Tutte'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: diet, decoration: const InputDecoration(labelText: 'Esigenza alimentare'),
            items: ['Tutte','Senza glutine','Ridotto sodio','Senza lattosio','Vegano','Vegetariano']
              .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) => setModal(() => diet = v ?? 'Tutte'),
          ),
          const SizedBox(height: 10),
          Text('Tempo massimo: $maxTime minuti'),
          Slider(min: 15, max: 180, divisions: 11, value: maxTime.toDouble(),
            onChanged: (v) => setModal(() => maxTime = v.round())),
          FilledButton(onPressed: () { Navigator.pop(context); setState(() {}); }, child: const Text('Applica')),
        ]),
      ),
    ));
  }
}

class PaywallPage extends StatelessWidget {
  final Recipe recipe;
  const PaywallPage({super.key, required this.recipe});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ricetta Premium')),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 30), children: [
      Stack(children: [
        recipeVisual(recipe, height: 260, radius: BorderRadius.circular(24)),
        Positioned(top: 14, right: 14, child: Chip(
          avatar: const Icon(Icons.lock, size: 17),
          label: const Text('PREMIUM'),
        )),
      ]),
      const SizedBox(height: 18),
      Text('${countryFlag(recipe.country)}  ${recipe.country}',
        style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(recipe.title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(recipe.description, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 16),
      Wrap(spacing: 8, children: [
        Chip(label: Text('${recipe.timeMin} min')),
        Chip(label: Text('${recipe.servings} porzioni')),
        Chip(label: Text(recipe.difficulty)),
      ]),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1D9), borderRadius: BorderRadius.circular(20)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🔒 Contenuto Premium', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text('Puoi vedere foto e anteprima della ricetta. Gli ingredienti completi e la preparazione dettagliata sono riservati agli abbonati Premium.'),
        ]),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.workspace_premium),
        label: const Text('Scopri Premium'),
      ),
    ]),
  );
}

class RecipePage extends StatelessWidget {
  final Recipe recipe; final bool favorite;
  final VoidCallback onFavorite; final ValueChanged<String> onAddIngredient;
  const RecipePage({super.key, required this.recipe, required this.favorite,
    required this.onFavorite, required this.onAddIngredient});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ricetta'), actions: [
      IconButton(onPressed: onFavorite, icon: Icon(favorite ? Icons.favorite : Icons.favorite_border))
    ]),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 30), children: [
      recipeVisual(recipe, height: 245, radius: BorderRadius.circular(24)),
      const SizedBox(height: 18),
      Text(recipe.title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text('${countryFlag(recipe.country)} ${recipe.country} • ${recipe.cuisine}'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 6, children: [
        Chip(avatar: const Icon(Icons.timer_outlined, size: 17),
          label: Text('${recipe.timeMin} min')),
        Chip(avatar: const Icon(Icons.people_outline, size: 17),
          label: Text('${recipe.servings} porzioni')),
        Chip(label: Text(recipe.difficulty)),
        if (recipe.prepMin > 0)
          Chip(label: Text('Prep ${recipe.prepMin} min')),
        if (recipe.cookMin > 0)
          Chip(label: Text('Cottura ${recipe.cookMin} min')),
      ]),
      const SizedBox(height: 8), Text(recipe.description),
      const SizedBox(height: 22),
      Row(children: [
        const Expanded(child: Text('Ingredienti', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        TextButton.icon(onPressed: () {
          for (final i in recipe.ingredients) onAddIngredient(i);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🛒 Tutti gli ingredienti sono stati aggiunti alla lista della spesa')));
        }, icon: const Icon(Icons.shopping_cart_outlined), label: const Text('Aggiungi tutto')),
      ]),
      ...recipe.ingredients.map((i) => ListTile(
        dense: true, leading: const Icon(Icons.check_circle_outline), title: Text(i),
        trailing: IconButton(onPressed: () {
          onAddIngredient(i);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('🛒 Aggiunto alla lista della spesa'),
            duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating,
          ));
        }, icon: const Icon(Icons.add_shopping_cart)),
      )),
      const SizedBox(height: 12),
      const Text('Preparazione', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      ...recipe.steps.asMap().entries.map((e) => ListTile(
        contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Text('${e.key + 1}')),
        title: Text(e.value),
      )),
    ]),
  );
}
