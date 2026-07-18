class Registry {
  final Map<String, dynamic> data;

  const Registry({required this.data});

  @override
  String toString() {
    return this.data.toString();
  }
}
