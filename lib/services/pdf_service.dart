import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import '../models/invoice_data.dart';

class PDFService {
  static const PdfColor yellowColor = PdfColor.fromInt(0xFFFFD700);
  static const PdfColor blackColor = PdfColor.fromInt(0xFF000000);
  static const PdfColor darkGrayColor = PdfColor.fromInt(0xFF333333);
  static const PdfColor lightGrayColor = PdfColor.fromInt(0xFF666666);

  // Logo-Caching
  static pw.ImageProvider? _companyLogo;
  static pw.ImageProvider? _tammStamp;
  static pw.ImageProvider? _sersheimStamp;
  
  // Font-Caching für Unicode-Unterstützung
  static pw.Font? _unicodeFont;

  // Font-Lade-Funktion für Unicode-Unterstützung
  static Future<pw.Font> _loadUnicodeFont() async {
    if (_unicodeFont != null) return _unicodeFont!;
    try {
      // Verwende Standard-Font erstmal für Test
      _unicodeFont = pw.Font.helvetica();
      return _unicodeFont!;
    } catch (e) {
      print('Fehler beim Laden der Unicode-Font: $e');
      return pw.Font.helvetica();
    }
  }

  // Logo-Lade-Funktionen
  static Future<pw.ImageProvider?> _loadCompanyLogo() async {
    if (_companyLogo != null) return _companyLogo;
    
    try {
      final ByteData data = await rootBundle.load('assets/images/company_logo.png');
      _companyLogo = pw.MemoryImage(data.buffer.asUint8List());
      return _companyLogo;
    } catch (e) {
      return null;
    }
  }

  static Future<pw.ImageProvider?> _loadTammStamp() async {
    if (_tammStamp != null) return _tammStamp;
    
    try {
      final ByteData data = await rootBundle.load('assets/images/tamm_stamp.png');
      _tammStamp = pw.MemoryImage(data.buffer.asUint8List());
      return _tammStamp;
    } catch (e) {
      return null;
    }
  }

  static Future<pw.ImageProvider?> _loadSersheimStamp() async {
    if (_sersheimStamp != null) return _sersheimStamp;
    
    try {
      final ByteData data = await rootBundle.load('assets/images/sersheim_stamp.png');
      _sersheimStamp = pw.MemoryImage(data.buffer.asUint8List());
      return _sersheimStamp;
    } catch (e) {
      return null;
    }
  }

  static Future<Uint8List> generatePDF(InvoiceData invoiceData) async {
    final pdf = pw.Document();
    
    // Lade Unicode-Font für Euro-Symbol
    final unicodeFont = await _loadUnicodeFont();
    
    // Lade Logos
    final companyLogo = await _loadCompanyLogo();
    final tammStamp = await _loadTammStamp();
    final sersheimStamp = await _loadSersheimStamp();
    
    // Lade benutzerdefiniertes Logo falls vorhanden (hat Priorität)
    pw.ImageProvider? customLogo;
    if (invoiceData.logoPath != null) {
      try {
        final logoFile = File(invoiceData.logoPath!);
        if (await logoFile.exists()) {
          final logoBytes = await logoFile.readAsBytes();
          customLogo = pw.MemoryImage(logoBytes);
        }
      } catch (e) {
        print('Fehler beim Laden des benutzerdefinierten Logos: $e');
      }
    }
    
    // Verwende benutzerdefiniertes Logo oder Standard-Logo
    final logoToUse = customLogo ?? companyLogo;
    final stampToUse = invoiceData.location == TaxiLocation.tamm ? tammStamp : sersheimStamp;

    // VEREINFACHTE Multi-Page Berechnung
    const int tripsOnFirstPage = 13;
    const int tripsPerAdditionalPage = 20;
    final int totalTrips = invoiceData.trips.length;
    
    print('DEBUG: Gesamt Fahrten = $totalTrips');
    
    // NEUE LOGIK: Bei wenigen Fahrten (≤5) alles auf eine Seite
    final bool singlePageLayout = totalTrips <= 5;
    
    int totalPages;
    if (singlePageLayout) {
      totalPages = 1; // Alles auf eine Seite
    } else if (totalTrips <= tripsOnFirstPage) {
      totalPages = 2; // Erste Seite + Zusammenfassung
    } else {
      final int remainingTrips = totalTrips - tripsOnFirstPage;
      final int additionalPages = (remainingTrips / tripsPerAdditionalPage).ceil();
      totalPages = 1 + additionalPages + 1; // Erste + Zusätzliche + Finale
    }
    
    print('DEBUG: Berechnet $totalPages Seiten total (singlePageLayout: $singlePageLayout)');

    // Seite 1: Hauptrechnung mit Header und Fahrten
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return _buildPageWithFooter(
            singlePageLayout 
              ? _buildSinglePage(invoiceData, logoToUse, stampToUse) // Alles auf einer Seite
              : _buildFirstPage(invoiceData, logoToUse, 0, tripsOnFirstPage), // Normal
            invoiceData,
            1,
            totalPages,
          );
        },
      ),
    );

    // KORRIGIERTE Multi-Page Erstellung (nur wenn nicht Single-Page)
    if (!singlePageLayout && totalTrips > tripsOnFirstPage) {
      // Fahrt-Seiten erstellen
      int startIndex = tripsOnFirstPage;
      int pageNumber = 2;
      
      while (startIndex < totalTrips) {
        // KORRIGIERTE endIndex Berechnung
        final int endIndex = (startIndex + tripsPerAdditionalPage < totalTrips) 
            ? startIndex + tripsPerAdditionalPage 
            : totalTrips;
        
        // CLOSURE-FIX: Lokale Kopien für die build-Funktion
        final int currentStartIndex = startIndex;
        final int currentEndIndex = endIndex;
        final int currentPageNumber = pageNumber;
        
        print('DEBUG: Seite $currentPageNumber - Fahrten $currentStartIndex bis ${currentEndIndex-1} (${currentEndIndex - currentStartIndex} Fahrten)');
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(40),
            build: (pw.Context context) {
              print('DEBUG: In build context: startIndex=$currentStartIndex, endIndex=$currentEndIndex');
              return _buildPageWithFooter(
                _buildMiddlePage(invoiceData, logoToUse, currentStartIndex, currentEndIndex),
                invoiceData,
                currentPageNumber,
                totalPages,
              );
            },
          ),
        );
        
        startIndex = endIndex;
        pageNumber++;
      }
      
      // Finale Seite mit Zusammenfassung
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return _buildPageWithFooter(
              _buildFinalPage(invoiceData, stampToUse),
              invoiceData,
              totalPages,
              totalPages,
            );
          },
        ),
      );
    } else if (!singlePageLayout) {
      // Nur 2 Seiten bei ≤13 Fahrten (aber nicht Single-Page)
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return _buildPageWithFooter(
              _buildSecondPage(invoiceData, stampToUse),
              invoiceData,
              2,
              totalPages,
            );
          },
        ),
      );
    }
    // Bei singlePageLayout wird keine zweite Seite erstellt!

    return pdf.save();
  }

  // Wrapper für Seiten mit Footer und Seitenzahl
  static pw.Widget _buildPageWithFooter(pw.Widget content, InvoiceData invoiceData, int currentPage, int totalPages) {
    return pw.Stack(
      children: [
        // Hauptinhalt
        pw.Column(
          children: [
            pw.Expanded(child: content),
            pw.SizedBox(height: 10),
            // Footer mit Bankdaten
            _buildFooter(invoiceData),
            pw.SizedBox(height: 5),
            // Seitenzahl unten rechts
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Seite $currentPage von $totalPages',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
        // Falzmarken am linken Rand
        _buildFoldMarks(),
      ],
    );
  }

  // Falzmarken für manuelles Falten (DIN A4 Standard)
  static pw.Widget _buildFoldMarks() {
    return pw.Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          // Erste Falzmarke bei 105mm (A4 Drittel-Faltung)
          pw.Container(
            margin: pw.EdgeInsets.only(top: 105 * 2.83465), // mm zu PDF-Punkte
            width: 8,
            height: 0.5,
            color: PdfColors.grey400,
          ),
          // Zweite Falzmarke bei 148.5mm (A4 Halbierung)
          pw.Container(
            margin: pw.EdgeInsets.only(top: (148.5 - 105) * 2.83465),
            width: 8,
            height: 0.5,
            color: PdfColors.grey400,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFirstPage(InvoiceData invoiceData, pw.ImageProvider? logoImage, int startIndex, int maxTrips) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header mit Logo und Firmenname
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo Bereich (rundes gelbes Logo) - höher positioniert
            pw.Container(
              width: 80,
              height: 80,
              margin: pw.EdgeInsets.only(top: -5),
              child: logoImage != null
                  ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                  : pw.Container(
                      decoration: pw.BoxDecoration(
                        color: yellowColor,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'T',
                          style: pw.TextStyle(
                            color: blackColor,
                            fontSize: 36,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
            pw.SizedBox(width: 15),
            // Firmenname
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 20),
                  pw.Text(
                    CompanyInfo.getName(invoiceData.location),
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: blackColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 10),
        
        // Absender-Adresse klein unter dem Logo
        pw.Text(
          CompanyInfo.getFullAddress(invoiceData.location),
          style: pw.TextStyle(
            fontSize: 8,
            color: lightGrayColor,
          ),
        ),
        
        pw.SizedBox(height: 30),

        // Empfänger und Kontaktdaten
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Empfänger (links)
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Empfänger ohne Box
                  pw.Text(
                    'Herr',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                  // Firma (falls vorhanden) über dem Namen
                  if (invoiceData.customerCompany != null && invoiceData.customerCompany!.isNotEmpty)
                    pw.Text(
                      '${invoiceData.customerCompany}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold, // Firma fett
                      ),
                    ),
                  // Kundenname (nur wenn vorhanden)
                  if (invoiceData.customerName.isNotEmpty)
                    pw.Text(
                      '${invoiceData.customerName}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  pw.Text(
                    '${invoiceData.customerStreet}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                  pw.Text(
                    '${invoiceData.customerPostalCode} ${invoiceData.customerCity}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(width: 20),
            
            // Kontaktdaten und Rechnungsdetails (rechts)
            pw.Expanded(
              flex: 1,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // Ansprechpartner (linksbündig)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Ansprechpartner: Label fett, Name normal
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: 'Ihr Ansprechpartner: ',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.TextSpan(
                              text: '${CompanyInfo.contactPerson}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.normal, // Name normal
                              ),
                            ),
                          ],
                        ),
                        textAlign: pw.TextAlign.left,
                      ),
                      pw.Text(
                        'Abteilung: Rechnung u. Bearbeitung',
                        style: pw.TextStyle(
                          fontSize: 9,
                        ),
                        textAlign: pw.TextAlign.left,
                      ),
                      pw.SizedBox(height: 8), // Mehr Abstand nach Abteilung
                      pw.Text(
                        'Telefon: ${CompanyInfo.getPhone(invoiceData.location)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                        ),
                        textAlign: pw.TextAlign.left,
                      ),
                      pw.Text(
                        'E-Mail: ${CompanyInfo.getEmail(invoiceData.location)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                        ),
                        textAlign: pw.TextAlign.left,
                      ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 30),
                  
                  // Rechnungsdetails (linksbündig)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildDetailRowLeft('Rechnung Nr.:', invoiceData.invoiceNumber),
                      _buildDetailRowLeft('IK Nr.:', CompanyInfo.ikNumber),
                      _buildDetailRowLeft('Steuer Nr.:', CompanyInfo.taxNumber),
                      _buildDetailRowLeft('Datum:', DateFormat('dd.MM.yyyy').format(invoiceData.invoiceDate)),
                      // Verwendungszweck entfernt von oben rechts
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 30),

        // Überschrift "Rechnung:" (ohne Linie darüber)
        pw.Text(
          'Rechnung:',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: blackColor,
          ),
        ),

        pw.SizedBox(height: 15),

        // Einleitung mit korrekter Anrede
        pw.Text(
          invoiceData.customerSalutation + ',',
          style: pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'hier stellen wir folgende Fahrt/en für Sie in Rechnung.',
          style: pw.TextStyle(fontSize: 11),
        ),
        
        // Dickere schwarze Linie unter Text
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          height: 5,
          color: blackColor,
        ),

        pw.SizedBox(height: 5),

        // Tabelle
        pw.Expanded(
          child: _buildTripsTable(invoiceData, startIndex, maxTrips),
        ),
      ],
    );
  }

  static pw.Widget _buildSecondPage(InvoiceData invoiceData, pw.ImageProvider? stamp) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Platz für eventuell weitere Tabellenzeilen
        pw.SizedBox(height: 200),

        // Rechnungssumme (rechtsbündig)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 200,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Verwendungszweck: ${invoiceData.purpose.isEmpty ? invoiceData.invoiceNumber : invoiceData.purpose}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 15),
                  _buildSummaryRow('Netto:', invoiceData.formattedNetAmountPdf),
                  _buildSummaryRow('MwSt. ${invoiceData.formattedVatRate}:', invoiceData.formattedVatAmountPdf),
                  pw.Container(
                    height: 1,
                    width: 150,
                    color: blackColor,
                    margin: const pw.EdgeInsets.symmetric(vertical: 3),
                  ),
                  _buildSummaryRow(
                    'Gesamtbetrag (brutto):',
                    invoiceData.formattedTotalAmountPdf,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 80),

        // Grußformel und Unterschrift - WEITER LINKS
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 20), // Weniger Abstand vom linken Rand
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Mit freundlichen Grüßen',
                  style: pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 10), // Weniger Abstand
                // Stempel (basierend auf Location) - WEITER LINKS
                if (stamp != null)
                  pw.Container(
                    width: 120, // Größer
                    height: 80,  // Größer
                    child: pw.Image(stamp, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: 80), // Platzhalter ohne Stempel
                pw.SizedBox(height: 5),
                pw.Text(
                  CompanyInfo.contactPerson,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),
              ],
            ),
            // Mehr Platz rechts vom Stempel
            pw.Expanded(child: pw.Container()),
          ],
        ),

        pw.Expanded(
          child: pw.Container(),
        ),
      ],
    );
  }

  // Neue Funktionen für Multi-Page Support
  static pw.Widget _buildMiddlePage(InvoiceData invoiceData, pw.ImageProvider? logoImage, int startIndex, int endIndex) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Vereinfachter Header für Folgeseiten
        pw.Row(
          children: [
            if (logoImage != null)
              pw.Container(
                width: 60,
                height: 60,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
            pw.SizedBox(width: 15),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  CompanyInfo.getName(invoiceData.location),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: blackColor,
                  ),
                ),
                pw.Text(
                  'Rechnung Nr. ${invoiceData.invoiceNumber} (Fortsetzung)',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
        
        pw.SizedBox(height: 20),
        
        // Tabelle für diese Seite
        pw.Expanded(
          child: _buildTripsTableForRange(invoiceData, startIndex, endIndex),
        ),
      ],
    );
  }

  // Finale Seite nur mit Zusammenfassung und Unterschrift (keine Fahrten)
  static pw.Widget _buildFinalPage(InvoiceData invoiceData, pw.ImageProvider? stamp) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 100), // Platz oben
        
        // Zusammenfassung und Unterschrift
        _buildSummaryAndSignature(invoiceData, stamp),
      ],
    );
  }

  static pw.Widget _buildTripsTable(InvoiceData invoiceData, [int startIndex = 0, int? maxTrips]) {
    return pw.Column(
      children: [
        // Header-Tabelle
        pw.Table(
          columnWidths: {
            0: const pw.FixedColumnWidth(70),
            1: const pw.FixedColumnWidth(65), // Erweitert für "Fahrt/en:"
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FixedColumnWidth(70),
          },
          children: [
            pw.TableRow(
              children: [
                _buildTableHeaderCentered('Datum:'),
                _buildTableHeaderCentered('Fahrt/en:'),
                _buildTableHeaderCentered('von:'),
                _buildTableHeaderCentered('nach:'),
                _buildTableHeaderCentered('Preis:'),
              ],
            ),
          ],
        ),
        // Gelbe Linie direkt unter Header
        pw.Container(
          width: double.infinity,
          height: 5,
          color: yellowColor,
        ),
        // Daten-Tabelle
        pw.Table(
          columnWidths: {
            0: const pw.FixedColumnWidth(70),
            1: const pw.FixedColumnWidth(65), // Erweitert für "Fahrt/en:"
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FixedColumnWidth(70),
          },
          children: _buildDataRows(invoiceData, startIndex, maxTrips),
        ),
      ],
    );
  }

  // Spezielle Funktion für Multi-Page mit Start- und End-Index
  static pw.Widget _buildTripsTableForRange(InvoiceData invoiceData, int startIndex, int endIndex) {
    // DEBUG: Sicherstellen, dass wir Fahrten haben
    final clampedEndIndex = endIndex.clamp(0, invoiceData.trips.length);
    final tripsToShow = invoiceData.trips.sublist(startIndex, clampedEndIndex);
    
    print('DEBUG _buildTripsTableForRange: startIndex=$startIndex, endIndex=$endIndex, clampedEndIndex=$clampedEndIndex, tripsToShow.length=${tripsToShow.length}');
    
    return pw.Column(
      children: [
        // Header-Tabelle
        pw.Table(
          columnWidths: {
            0: const pw.FixedColumnWidth(70),
            1: const pw.FixedColumnWidth(65),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FixedColumnWidth(70),
          },
          children: [
            pw.TableRow(
              children: [
                _buildTableHeaderCentered('Datum:'),
                _buildTableHeaderCentered('Fahrt/en:'),
                _buildTableHeaderCentered('von:'),
                _buildTableHeaderCentered('nach:'),
                _buildTableHeaderCentered('Preis:'),
              ],
            ),
          ],
        ),
        // Gelber Strich unter Tabellenköpfen
        pw.Container(
          width: double.infinity,
          height: 3,
          color: yellowColor,
        ),
        // Daten-Tabelle - VEREINFACHT für besseres Debugging
        pw.Table(
          columnWidths: {
            0: const pw.FixedColumnWidth(70),
            1: const pw.FixedColumnWidth(65),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FixedColumnWidth(70),
          },
          children: tripsToShow.asMap().entries.map((entry) {
            final localIndex = entry.key; // 0, 1, 2... innerhalb dieser Seite
            final globalIndex = startIndex + localIndex; // Absoluter Index
            final trip = entry.value;
            
            // Neue Logik: Alle Fahrten zeigen ihre eigenen Daten, '' nur bei identischen aufeinanderfolgenden Fahrten
            String fromText = trip.fromAddress;
            String toText = trip.toAddress;
            String fahrtText = trip.description;
            
            // Prüfe ob diese Fahrt als Duplikat markiert ist
            // WICHTIG: Datum und Preis werden IMMER angezeigt, nur Fahrt/en, von, nach bekommen ''
            if (trip.isDuplicate) {
              fahrtText = "''";
              fromText = "''";
              toText = "''";
              // Datum und Preis bleiben unverändert!
            }
            
            return pw.TableRow(
              children: [
                _buildTableCell(DateFormat('dd.MM.yy').format(trip.date), align: pw.TextAlign.center),
                _buildTableCell(fahrtText, align: pw.TextAlign.center),
                _buildTableCell(fromText, fontSize: 8, align: pw.TextAlign.center),
                _buildTableCell(toText, fontSize: 8, align: pw.TextAlign.center),
                _buildTableCell(trip.formattedPricePdf, align: pw.TextAlign.center),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  static List<pw.TableRow> _buildDataRows(InvoiceData invoiceData, [int startIndex = 0, int? maxTrips]) {
    final List<pw.TableRow> rows = [];
    
    // Bestimme Ende-Index
    final int endIndex = maxTrips != null 
        ? (startIndex + maxTrips).clamp(0, invoiceData.trips.length)
        : invoiceData.trips.length;
    
    // Datenzeilen (nur die tatsächlichen Fahrten für diese Seite)
    for (int i = startIndex; i < endIndex; i++) {
      final trip = invoiceData.trips[i];
      
      // Neue Logik: Alle Fahrten zeigen ihre eigenen Daten, '' nur bei identischen aufeinanderfolgenden Fahrten
      String fromText = trip.fromAddress;
      String toText = trip.toAddress;
      String fahrtText = trip.description;
      
      // Prüfe ob vorherige Fahrt identisch ist (für '' Logik)
      // WICHTIG: Datum und Preis werden IMMER angezeigt, nur Fahrt/en, von, nach bekommen ''
      if (i > 0) {
        final previousTrip = invoiceData.trips[i - 1];
        if (trip.isIdenticalTo(previousTrip)) {
          fahrtText = "''";
          fromText = "''";
          toText = "''";
          // Datum und Preis bleiben unverändert!
        }
      }
      
      rows.add(
        pw.TableRow(
          children: [
            _buildTableCell(DateFormat('dd.MM.yy').format(trip.date), align: pw.TextAlign.center),
            _buildTableCell(fahrtText, align: pw.TextAlign.center), // Verwende fahrtText statt trip.description
            _buildTableCell(fromText, fontSize: 8, align: pw.TextAlign.center),
            _buildTableCell(toText, fontSize: 8, align: pw.TextAlign.center),
            _buildTableCell(trip.formattedPricePdf, align: pw.TextAlign.center),
          ],
        ),
      );
    }
    
    return rows;
  }

  // Spezielle Funktion für Multi-Page mit direktem Start- und End-Index
  static List<pw.TableRow> _buildDataRowsForRange(InvoiceData invoiceData, int startIndex, int endIndex) {
    final List<pw.TableRow> rows = [];
    
    // Datenzeilen (nur die Fahrten zwischen startIndex und endIndex)
    for (int i = startIndex; i < endIndex && i < invoiceData.trips.length; i++) {
      final trip = invoiceData.trips[i];
      
      // Neue Logik: Alle Fahrten zeigen ihre eigenen Daten, '' nur bei identischen aufeinanderfolgenden Fahrten
      String fromText = trip.fromAddress;
      String toText = trip.toAddress;
      String fahrtText = trip.description;
      
      // Prüfe ob vorherige Fahrt identisch ist (für '' Logik)
      // WICHTIG: Datum und Preis werden IMMER angezeigt, nur Fahrt/en, von, nach bekommen ''
      if (i > 0) {
        final previousTrip = invoiceData.trips[i - 1];
        if (trip.isIdenticalTo(previousTrip)) {
          fahrtText = "''";
          fromText = "''";
          toText = "''";
          // Datum und Preis bleiben unverändert!
        }
      }
      
      rows.add(
        pw.TableRow(
          children: [
            _buildTableCell(DateFormat('dd.MM.yy').format(trip.date)),
            _buildTableCell(fahrtText),
            _buildTableCell(fromText, fontSize: 8),
            _buildTableCell(toText, fontSize: 8),
            _buildTableCell(trip.formattedPricePdf, align: pw.TextAlign.center),
          ],
        ),
      );
    }
    
    return rows;
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: blackColor,
        ),
        textAlign: pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _buildTableHeaderCentered(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: blackColor,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {double fontSize = 9, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: fontSize),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDetailRowLeft(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 5),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 11 : 10,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isTotal ? 11 : 10,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Public Methoden für die App
  static Future<void> generateAndPreview(InvoiceData invoiceData) async {
    try {
      final pdfData = await generatePDF(invoiceData);
      
      // Verwende einen timeout für die Vorschau
      await Future.any([
        Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfData,
          name: 'Rechnung_${invoiceData.invoiceNumber}.pdf',
        ),
        Future.delayed(const Duration(seconds: 30)), // 30 Sekunden timeout
      ]);
      
    } catch (e) {
      print('Preview-Fehler: $e');
      rethrow; // Fehler weiterleiten statt fallback
    }
  }

  static Future<void> generateAndSave(InvoiceData invoiceData) async {
    final pdfData = await generatePDF(invoiceData);
    final fileName = 'Rechnung_${invoiceData.invoiceNumber}.pdf';
    
    if (kIsWeb) {
      // Web: Browser-Download verwenden
      final blob = html.Blob([pdfData], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile/Desktop: Dateisystem verwenden
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfData);
    }
  }

  static Future<void> generateAndShare(InvoiceData invoiceData) async {
    final pdfData = await generatePDF(invoiceData);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/Rechnung_${invoiceData.invoiceNumber}.pdf');
    await file.writeAsBytes(pdfData);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Rechnung ${invoiceData.invoiceNumber} von ${CompanyInfo.getName(invoiceData.location)}',
    );
  }

  // Neue Hilfsfunktionen für Multi-Page Support
  static pw.Widget _buildSummaryAndSignature(InvoiceData invoiceData, pw.ImageProvider? stamp) {
    return pw.Column(
      children: [
        // Rechnungssumme (rechtsbündig)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 200,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Verwendungszweck: ${invoiceData.purpose.isEmpty ? invoiceData.invoiceNumber : invoiceData.purpose}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 15),
                  _buildSummaryRow('Netto:', invoiceData.formattedNetAmountPdf),
                  _buildSummaryRow('MwSt. ${invoiceData.formattedVatRate}:', invoiceData.formattedVatAmountPdf),
                  pw.Container(
                    height: 1,
                    width: 150,
                    color: blackColor,
                    margin: const pw.EdgeInsets.symmetric(vertical: 3),
                  ),
                  _buildSummaryRow(
                    'Gesamtbetrag (brutto):',
                    invoiceData.formattedTotalAmountPdf,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 40),

        // Grußformel und Unterschrift
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 20), // Weniger Abstand vom linken Rand
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Mit freundlichen Grüßen',
                  style: pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 10),
                // Stempel (basierend auf Location) - WEITER LINKS
                if (stamp != null)
                  pw.Container(
                    width: 120,
                    height: 80,
                    child: pw.Image(stamp, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: 80),
                pw.SizedBox(height: 5),
                pw.Text(
                  CompanyInfo.contactPerson,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),
              ],
            ),
            // Mehr Platz rechts vom Stempel
            pw.Expanded(child: pw.Container()),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(InvoiceData invoiceData) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: blackColor, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Adresse (links)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  CompanyInfo.getName(invoiceData.location),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${CompanyInfo.getAddress(invoiceData.location)}',
                  style: pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  '${CompanyInfo.getPostalCode(invoiceData.location)} ${CompanyInfo.getCity(invoiceData.location)}',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
          // Bankdaten (mitte)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  CompanyInfo.bank,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'IBAN ${CompanyInfo.getIban(invoiceData.location)}',
                  style: pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  'BIC ${CompanyInfo.bic}',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
          // Kontakt (rechts)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Tel: ${CompanyInfo.getPhone(invoiceData.location)}',
                  style: pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  '${CompanyInfo.getEmail(invoiceData.location)}',
                  style: pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  '${CompanyInfo.getWebsite(invoiceData.location)}',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NEUE METHODE: Alles auf einer Seite für wenige Fahrten
  static pw.Widget _buildSinglePage(InvoiceData invoiceData, pw.ImageProvider? logoImage, pw.ImageProvider? stamp) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header mit Logo und Firmenname (kompakter)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo Bereich (kleiner für Single Page)
            pw.Container(
              width: 60,
              height: 60,
              child: logoImage != null
                  ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                  : pw.Container(
                      decoration: pw.BoxDecoration(
                        color: yellowColor,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'T',
                          style: pw.TextStyle(
                            color: blackColor,
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
            pw.SizedBox(width: 15),
            // Firmenname
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    CompanyInfo.getName(invoiceData.location),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: blackColor,
                    ),
                  ),
                  pw.Text(
                    CompanyInfo.getFullAddress(invoiceData.location),
                    style: pw.TextStyle(
                      fontSize: 7,
                      color: lightGrayColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        pw.SizedBox(height: 20),

        // Empfänger und Kontaktdaten (kompakter)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Empfänger (links)
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Herr',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  // Firma (falls vorhanden)
                  if (invoiceData.customerCompany != null && invoiceData.customerCompany!.isNotEmpty)
                    pw.Text(
                      '${invoiceData.customerCompany}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  // Kundenname (nur wenn vorhanden)
                  if (invoiceData.customerName.isNotEmpty)
                    pw.Text(
                      '${invoiceData.customerName}',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  pw.Text(
                    '${invoiceData.customerStreet}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    '${invoiceData.customerPostalCode} ${invoiceData.customerCity}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 15),
            // Kontaktdaten (kompakter)
            pw.Expanded(
              flex: 1,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Ansprechpartner: Label fett, Name normal
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: 'Ihr Ansprechpartner: ',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.TextSpan(
                          text: '${CompanyInfo.contactPerson}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Text(
                    'Abteilung: Rechnung u. Bearbeitung',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Telefon: ${CompanyInfo.getPhone(invoiceData.location)}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'E-Mail: ${CompanyInfo.getEmail(invoiceData.location)}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 10),
                  _buildDetailRowLeft('Rechnung Nr.:', invoiceData.invoiceNumber),
                  _buildDetailRowLeft('IK Nr.:', CompanyInfo.ikNumber),
                  _buildDetailRowLeft('Steuer Nr.:', CompanyInfo.taxNumber),
                  _buildDetailRowLeft('Datum:', DateFormat('dd.MM.yyyy').format(invoiceData.invoiceDate)),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 15),

        // Überschrift "Rechnung:"
        pw.Text(
          'Rechnung:',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: blackColor,
          ),
        ),

        pw.SizedBox(height: 10),

        // Begrüßung
        pw.Text(
          invoiceData.customerSalutation + ',',
          style: pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          'hier stellen wir folgende Fahrt/en für Sie in Rechnung.',
          style: pw.TextStyle(fontSize: 10),
        ),
        
        // Schwarze Linie
        pw.SizedBox(height: 5),
        pw.Container(
          width: double.infinity,
          height: 3,
          color: blackColor,
        ),

        pw.SizedBox(height: 5),

        // Kompakte Tabelle
        _buildTripsTable(invoiceData, 0, invoiceData.trips.length),
        
        pw.SizedBox(height: 15),

        // Zusammenfassung und Unterschrift in einer Zeile
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Unterschrift (links)
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Mit freundlichen Grüßen',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 25),
                  if (stamp != null)
                    pw.Container(
                      width: 100,
                      height: 40,
                      child: pw.Image(stamp, fit: pw.BoxFit.contain),
                    ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    CompanyInfo.contactPerson,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Zusammenfassung (rechts)
            pw.Container(
              width: 180,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Verwendungszweck: ${invoiceData.purpose.isEmpty ? invoiceData.invoiceNumber : invoiceData.purpose}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  _buildSummaryRow('Netto:', invoiceData.formattedNetAmountPdf),
                  _buildSummaryRow('MwSt. ${invoiceData.formattedVatRate}:', invoiceData.formattedVatAmountPdf),
                  pw.Container(
                    height: 1,
                    width: 120,
                    color: blackColor,
                    margin: const pw.EdgeInsets.symmetric(vertical: 3),
                  ),
                  _buildSummaryRow(
                    'Gesamtbetrag (brutto):',
                    invoiceData.formattedTotalAmountPdf,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Flexible Spacer für verbleibendes Layout
        pw.Expanded(child: pw.Container()),
      ],
    );
  }
}