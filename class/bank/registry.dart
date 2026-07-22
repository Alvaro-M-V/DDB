class Registry {
  final Map<String, dynamic> data;

  const Registry({required this.data});

  @override
  String toString() {
    return this.data.toString();
  }

  Map<String, dynamic> toJson() {
    return {'data': data};
  }

  factory Registry.fromJson(Map<String, dynamic> json) {
    return Registry(data: json['data'] as Map<String, dynamic>);
  }
}
