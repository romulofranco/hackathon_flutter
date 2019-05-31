
const languages = const [
  const Language('Portugues', 'pt_BR'),
  const Language('English', 'en_US'),
];

class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);
}