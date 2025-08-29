class InvoiceData {
  final String customerName;
  final String? customerCompany; // Neue Firma-Feld (optional)
  final String customerStreet;
  final String customerPostalCode;
  final String customerCity;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final List<TripEntry> trips;
  final double vatRate;
  final String? logoPath;
  final TaxiLocation location;
  final CustomerGender customerGender;
  final String purpose;     // Verwendungszweck

  InvoiceData({
    required this.customerName,
    this.customerCompany, // Optional: Firma
    required this.customerStreet,
    required this.customerPostalCode,
    required this.customerCity,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.trips,
    this.vatRate = 0.07, // 7% MwSt als Standard
    this.logoPath,
    this.location = TaxiLocation.tamm, // Standard: Tamm
    this.customerGender = CustomerGender.herr, // Standard: Herr
    this.purpose = '',         // Optional
  });

  // KORRIGIERT: Fahrpreise sind bereits Brutto!
  double get totalAmount {
    return trips.fold(0.0, (sum, trip) => sum + trip.price);
  }

  double get netAmount {
    // Netto rückwärts berechnen: Brutto / (1 + MwSt-Satz)
    return totalAmount / (1 + vatRate);
  }

  double get vatAmount {
    return totalAmount - netAmount;
  }

  String get formattedNetAmount => '${netAmount.toStringAsFixed(2)} €';
  String get formattedVatAmount => '${vatAmount.toStringAsFixed(2)} €';
  String get formattedTotalAmount => '${totalAmount.toStringAsFixed(2)} €';
  
  // PDF-Formatierung mit EUR für Kompatibilität
  String get formattedNetAmountPdf => '${netAmount.toStringAsFixed(2)} EUR';
  String get formattedVatAmountPdf => '${vatAmount.toStringAsFixed(2)} EUR';
  String get formattedTotalAmountPdf => '${totalAmount.toStringAsFixed(2)} EUR';
  String get formattedVatRate => '${(vatRate * 100).toInt()}%';
  
  // Korrekte Anrede basierend auf Geschlecht - nur Nachname oder Firma
  String get customerSalutation {
    // Wenn nur Firma ohne Name angegeben
    if (customerName.trim().isEmpty && customerCompany != null && customerCompany!.isNotEmpty) {
      return 'Sehr geehrte Damen und Herren';
    }
    
    // Nachname extrahieren (letztes Wort)
    String lastName = customerName.trim().split(' ').last;
    
    return customerGender == CustomerGender.frau 
        ? 'Sehr geehrte Frau $lastName' 
        : 'Sehr geehrter Herr $lastName';
  }
}

class TripEntry {
  final DateTime date;
  final String description;
  final String fromAddress;
  final String toAddress;
  final double price;
  final bool isDuplicate; // Markiert ob diese Fahrt ein Duplikat ist

  TripEntry({
    required this.date,
    required this.description,
    required this.fromAddress,
    required this.toAddress,
    required this.price,
    this.isDuplicate = false, // Standard: kein Duplikat
  });

  String get formattedPrice => '${price.toStringAsFixed(2)} €';
  
  // PDF-Formatierung mit EUR für Kompatibilität
  String get formattedPricePdf => '${price.toStringAsFixed(2)} EUR';
  
  // Prüft ob diese Fahrt identisch mit einer anderen ist
  bool isIdenticalTo(TripEntry other) {
    return date.isAtSameMomentAs(other.date) &&
           description == other.description &&
           fromAddress == other.fromAddress &&
           toAddress == other.toAddress &&
           price == other.price;
  }
}

enum TaxiLocation {
  tamm,
  sersheim,
}

enum CustomerGender {
  herr,
  frau,
}

class CompanyInfo {
  static const String contactPerson = 'Massih Hashemi';
  static const String phone = '07141 / 9746955';
  static const String email = 'T.K.Hashemi@hotmail.de';
  static const String website = 'www.Taxi-Service-Tamm.de';
  
  static const String bic = 'SOLADES1LBG';
  static const String bank = 'Kreissparkasse Ludwigsburg';
  
  static String getIban(TaxiLocation location) {
    switch (location) {
      case TaxiLocation.tamm:
        return 'DE18 6045 0050 0000 0167 95';
      case TaxiLocation.sersheim:
        return 'DE36 6045 0050 0030 2268 30';
    }
  }
  
  static String getWebsite(TaxiLocation location) {
    switch (location) {
      case TaxiLocation.tamm:
        return 'www.Taxi-Service-Tamm.de';
      case TaxiLocation.sersheim:
        return 'www.Taxi-Sersheim.de';
    }
  }
  
  static const String taxNumber = '7110247350';
  static const String ikNumber = '600851512';
  
  // Feste Fahrtdaten
  static const String fromLocation = 'Tamm, Ulmer Str. 51';
  static const String toLocation = 'Ludwigsburg, Erlachhof Str. 1 und zurück';
  
  // Standort-spezifische Informationen
  static String getName(TaxiLocation location) {
    switch (location) {
      case TaxiLocation.tamm:
        return 'Taxi-Service-Tamm';
      case TaxiLocation.sersheim:
        return 'Taxi Sersheim';
    }
  }
  
  static String getAddress(TaxiLocation location) {
    switch (location) {
      case TaxiLocation.tamm:
        return 'Heilbronner Str.30';
      case TaxiLocation.sersheim:
        return 'Waldeck Str.7';
    }
  }
  
  static String getPostalCode(TaxiLocation location) {
    switch (location) {
      case TaxiLocation.tamm:
        return '71732';
      case TaxiLocation.sersheim:
        return '74372';
    }
  }
  
  static String getCity(TaxiLocation location) {
    switch (location) {
      case TaxiLocation.tamm:
        return 'Tamm';
      case TaxiLocation.sersheim:
        return 'Sersheim';
    }
  }
  
  static String getFullAddress(TaxiLocation location) {
    return '${getName(location)}, ${getAddress(location)}, ${getPostalCode(location)} ${getCity(location)}';
  }
  
  static String getPhone(TaxiLocation location) {
    switch (location) {
      case TaxiLocation.tamm:
        return '07141 / 9746955';
      case TaxiLocation.sersheim:
        return '07042 / 2607267';
    }
  }
  
  static String getEmail(TaxiLocation location) {
    switch (location) {
      case TaxiLocation.tamm:
        return 'Taxi.Tamm@googlemail.com';
      case TaxiLocation.sersheim:
        return 'taxisersheim@gmail.com';
    }
  }
}