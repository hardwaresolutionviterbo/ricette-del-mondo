class Recipe {
  final String id,title,country,cuisine,category,difficulty,description,history;
  final String flag;
  final int timeMin,servings,prepMin,cookMin;
  final bool premium;
  final List<String> ingredients,steps,tags,variants;
  final String editorialStatus,chef,cookingMethod,cookingDetail,continent,macroArea,imageUrl;
  final int? cookingTempC;
  const Recipe({required this.id,required this.title,required this.country,required this.cuisine,
    required this.category,required this.timeMin,required this.servings,required this.prepMin,
    required this.cookMin,required this.difficulty,required this.premium,required this.description,required this.history,
    required this.ingredients,required this.steps,required this.tags,required this.editorialStatus, this.variants=const [], this.chef='', this.cookingMethod='', this.cookingDetail='', this.cookingTempC, this.continent='', this.macroArea='', this.imageUrl='', this.flag=''});
  factory Recipe.fromJson(Map<String,dynamic> j)=>Recipe(
    id:j['id']??'',title:j['title']??'',country:j['country']??'',cuisine:j['cuisine']??'',
    category:j['category']??'',timeMin:j['timeMin']??0,servings:j['servings']??4,
    prepMin:j['prepMin']??0,cookMin:j['cookMin']??0,difficulty:j['difficulty']??'Media',
    premium:j['premium']==true,description:j['description']??'',history:j['history']??'',
    ingredients:List<String>.from(j['ingredients']??const []),
    steps:List<String>.from(j['steps']??const []),tags:List<String>.from(j['tags']??const []),variants:List<String>.from(j['variants']??const []),
    editorialStatus:j['editorialStatus']??'draft',chef:j['chef']??'',cookingMethod:j['cookingMethod']??'',cookingDetail:j['cookingDetail']??'',cookingTempC:j['cookingTempC'] is int ? j['cookingTempC'] as int : null,continent:j['continent']??'',macroArea:j['macroArea']??'',imageUrl:j['imageUrl']??'',flag:j['flag']?.toString()??'');
}
