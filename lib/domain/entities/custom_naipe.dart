/// A naipe beyond the 4 standard ones ("Solista", "Mezzo"), created once on
/// this device and reusable across songs (RF17). Equal by [id].
class CustomNaipe {
  final String id;
  final String name;

  const CustomNaipe({required this.id, required this.name})
      : assert(id.length > 0, 'CustomNaipe.id must not be empty'),
        assert(name.length > 0, 'CustomNaipe.name must not be empty');

  @override
  bool operator ==(Object other) => other is CustomNaipe && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
