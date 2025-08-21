# 🚕 Taxi Rechnung Generator - Bedienungsanleitung

## 📱 App starten

```bash
flutter run
```

Die App startet mit dem Hauptbildschirm zur Rechnungserstellung.

## 🖥️ Hauptfunktionen

### 1. **Logo hinzufügen** (optional)
- Tippen Sie auf "Logo wählen"
- Wählen Sie ein Bild aus der Galerie oder Dateien
- Das Logo wird automatisch in der PDF integriert

### 2. **Kundendaten eingeben**
- **Name**: Vollständiger Name des Kunden
- **Straße**: Straße und Hausnummer
- **PLZ**: Postleitzahl
- **Ort**: Wohnort

### 3. **Rechnungsdetails**
- **Rechnungsnummer**: Wird automatisch generiert (kann bearbeitet werden)
- **MwSt. (%)**: Standard 7% (anpassbar)
- **Datum**: Tippen zum Ändern des Datums

### 4. **Fahrten verwalten**
- **Fahrt hinzufügen**: Grüner "+" Button
- **Fahrt bearbeiten**: 3-Punkte-Menü → "Bearbeiten"
- **Fahrt löschen**: 3-Punkte-Menü → "Löschen"

Für jede Fahrt:
- **Beschreibung**: z.B. "Fahrt", "Rückfahrt"
- **Datum**: Fahrtdatum auswählen
- **Preis**: Fahrtpreis in Euro

### 5. **PDF erstellen**
- **"PDF Vorschau"**: Zeigt die fertige Rechnung an
- **"Speichern"**: Speichert PDF lokal
- **"Teilen"**: Teilt PDF über andere Apps

## 📄 PDF-Layout

### Seite 1: Hauptrechnung
- ✅ Logo (falls hochgeladen)
- ✅ Firmenname mit gelbem Akzent
- ✅ Absender: Taxi-Service-Tamm, Heilbronner Str. 30, 71732 Tamm
- ✅ Empfänger: Ihre eingegebenen Kundendaten
- ✅ Kontaktdaten rechtsbündig
- ✅ Rechnungsdetails (Nummer, IK Nr., Steuernummer, Datum)
- ✅ Gelbe "Rechnung:" Überschrift
- ✅ Einleitungstext
- ✅ Tabelle mit bis zu 12 Fahrtzeilen:
  - Datum
  - Fahrt/en
  - Von: Tamm, Ulmer Str. 51 (fest)
  - Nach: Ludwigsburg, Erlachhof Str. 1 und zurück (fest)
  - Preis

### Seite 2: Zusammenfassung
- ✅ Verwendungszweck
- ✅ Netto-Betrag
- ✅ MwSt. (7% oder individuell)
- ✅ **Gesamtbetrag** (fett hervorgehoben)
- ✅ Grußformel: "Mit freundlichen Grüßen – A. Hashemi"
- ✅ Footer mit:
  - Bankdaten (IBAN, BIC)
  - Kontaktinformationen
  - Adresse, Telefon, E-Mail, Website

## 🎨 Design-Features

- **Gelb-schwarze Farbgebung** entsprechend Ihren Vorgaben
- **Professionelles Layout** mit klarer Struktur
- **Responsive Design** für verschiedene Bildschirmgrößen
- **Taxi-Icons** für bessere Benutzerfreundlichkeit

## 💡 Tipps

### Effiziente Nutzung:
1. **Stammdaten**: Rechnungsnummer wird automatisch generiert
2. **Schnelle Eingabe**: Standard-Fahrtpreis ist 10,00 €
3. **Batch-Verarbeitung**: Fügen Sie mehrere Fahrten auf einmal hinzu
4. **Vorschau nutzen**: Prüfen Sie die Rechnung vor dem Speichern

### Anpassungen:
- **Firmendaten ändern**: In `lib/models/invoice_data.dart` → `CompanyInfo`
- **Farben anpassen**: In `lib/services/pdf_service.dart`
- **Standard-Fahrtroute ändern**: In `CompanyInfo.fromLocation` und `CompanyInfo.toLocation`

## 🔧 Fehlerbehebung

### App startet nicht:
```bash
flutter clean
flutter pub get
flutter run
```

### PDF wird nicht erstellt:
- Prüfen Sie, ob alle Pflichtfelder (*) ausgefüllt sind
- Stellen Sie sicher, dass mindestens eine Fahrt hinzugefügt wurde

### Logo wird nicht angezeigt:
- Verwenden Sie unterstützte Bildformate (PNG, JPG, JPEG)
- Achten Sie auf die Dateigröße (max. 5 MB empfohlen)

## 📞 Support

Bei Fragen oder Problemen können Sie:
1. Die Firmendaten in der `CompanyInfo` Klasse anpassen
2. Die PDF-Vorlage in `PDFService` modifizieren
3. Das App-Design in `main.dart` und den Screen-Dateien ändern

Die App ist vollständig funktionsfähig und bereit für den produktiven Einsatz! 🚀