class ReceiptImage {
  final String secureUrl;
  final String publicId;
  final int? width;
  final int? height;
  final String? format;
  final int? bytes;

  ReceiptImage({
    required this.secureUrl,
    required this.publicId,
    this.width,
    this.height,
    this.format,
    this.bytes,
  });

  factory ReceiptImage.fromJson(Map<String, dynamic> json) {
    return ReceiptImage(
      secureUrl: json['secureUrl'] ?? '',
      publicId: json['publicId'] ?? '',
      width: json['width'],
      height: json['height'],
      format: json['format'],
      bytes: json['bytes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'secureUrl': secureUrl,
      'publicId': publicId,
      'width': width,
      'height': height,
      'format': format,
      'bytes': bytes,
    };
  }
}

class BoatReceiptModel {
  final String id;
  final String clientId;
  final DateTime receiptDate;
  final String boatNumber;
  final int weightKg;
  final int pricePerKg;
  final int totalAmount;
  final String note;
  final ReceiptImage? image;
  final String inputMethod;
  final bool wasEdited;
  final List<String> editedFields;
  final DateTime createdAt;

  BoatReceiptModel({
    required this.id,
    required this.clientId,
    required this.receiptDate,
    required this.boatNumber,
    required this.weightKg,
    this.pricePerKg = 0,
    this.totalAmount = 0,
    required this.note,
    this.image,
    required this.inputMethod,
    required this.wasEdited,
    required this.editedFields,
    required this.createdAt,
  });

  double get weightTons => weightKg / 1000.0;
  int get computedTotalAmount =>
      totalAmount > 0 ? totalAmount : weightKg * pricePerKg;

  factory BoatReceiptModel.fromJson(Map<String, dynamic> json) {
    final wKg = json['weightKg'] ?? 0;
    final pKg = json['pricePerKg'] ?? 0;
    final totAmt = json['totalAmount'] ?? (wKg * pKg);
    return BoatReceiptModel(
      id: json['id'] ?? json['_id'] ?? '',
      clientId: json['clientId'] ?? '',
      receiptDate:
          DateTime.tryParse(json['receiptDate'] ?? '') ?? DateTime.now(),
      boatNumber: json['boatNumber'] ?? '',
      weightKg: wKg,
      pricePerKg: pKg,
      totalAmount: totAmt,
      note: json['note'] ?? '',
      image: json['image'] != null
          ? ReceiptImage.fromJson(json['image'])
          : null,
      inputMethod: json['input']?['method'] ?? 'manual',
      wasEdited: json['verification']?['wasEdited'] ?? false,
      editedFields: List<String>.from(
        json['verification']?['editedFields'] ?? [],
      ),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'receiptDate': receiptDate.toIso8601String(),
    'boatNumber': boatNumber,
    'weightKg': weightKg,
    'pricePerKg': pricePerKg,
    'totalAmount': totalAmount,
    'note': note,
    if (image != null) 'image': image!.toJson(),
    'input': {'method': inputMethod},
    'verification': {'wasEdited': wasEdited, 'editedFields': editedFields},
    'createdAt': createdAt.toIso8601String(),
  };
}
