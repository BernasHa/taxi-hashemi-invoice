import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
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

    // Seite 1: Hauptrechnung
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return _buildFirstPage(invoiceData, logoToUse);
        },
      ),
    );

    // Seite 2: Zusammenfassung und Footer
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          // Wähle den richtigen Stempel basierend auf der Location
          final stampToUse = invoiceData.location == TaxiLocation.tamm ? tammStamp : sersheimStamp;
          return _buildSecondPage(invoiceData, stampToUse);
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildFirstPage(InvoiceData invoiceData, pw.ImageProvider? logoImage) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header mit Logo und Firmenname
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo Bereich (rundes gelbes Logo)
            pw.Container(
              width: 80,
              height: 80,
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
            
            pw.SizedBox(width: 40),
            
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
                      pw.Text(
                        'Ihr Ansprechpartner: ${CompanyInfo.contactPerson}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
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
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Telefon: ${CompanyInfo.phone}',
                        style: pw.TextStyle(
                          fontSize: 9,
                        ),
                        textAlign: pw.TextAlign.left,
                      ),
                      pw.Text(
                        'E-Mail: ${CompanyInfo.email}',
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

        // Einleitung
        pw.Text(
          'Sehr geehrter Herr ${invoiceData.customerName.split(' ').last},',
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
          height: 3,
          color: blackColor,
        ),

        pw.SizedBox(height: 15),

        // Tabelle
        pw.Expanded(
          child: _buildTripsTable(invoiceData),
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
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Verwendungszweck:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    invoiceData.purpose.isEmpty ? 'Rechnung Nr. ${invoiceData.invoiceNumber}' : invoiceData.purpose,
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 15),
                  _buildSummaryRow('Netto:', invoiceData.formattedNetAmount),
                  _buildSummaryRow('MwSt. ${invoiceData.formattedVatRate}:', invoiceData.formattedVatAmount),
                  pw.Container(
                    height: 1,
                    width: 150,
                    color: blackColor,
                    margin: const pw.EdgeInsets.symmetric(vertical: 3),
                  ),
                  _buildSummaryRow(
                    'Gesamtbetrag:',
                    invoiceData.formattedTotalAmount,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 80),

        // Grußformel und Unterschrift
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Mit freundlichen Grüßen',
                  style: pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 10), // Weniger Abstand
                // Stempel (basierend auf Location)
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
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            // Platz rechts vom Stempel, um ihn nach links zu verschieben
            pw.Expanded(child: pw.Container()),
          ],
        ),

        pw.Expanded(
          child: pw.Container(),
        ),

        // Footer mit Bankdaten (dreispaltig wie im Screenshot)
        pw.Container(
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
                      'IBAN ${CompanyInfo.iban}',
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
                      'Tel: ${CompanyInfo.phone}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      '${CompanyInfo.email}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      '${CompanyInfo.website}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTripsTable(InvoiceData invoiceData) {
    return pw.Column(
      children: [
        // Header-Tabelle
        pw.Table(
          columnWidths: {
            0: const pw.FixedColumnWidth(70),
            1: const pw.FixedColumnWidth(50),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FixedColumnWidth(70),
          },
          children: [
            pw.TableRow(
              children: [
                _buildTableHeader('Datum:'),
                _buildTableHeader('Fahrt/en:'),
                _buildTableHeader('von:'),
                _buildTableHeader('nach:'),
                _buildTableHeader('Preis:'),
              ],
            ),
          ],
        ),
        // Gelbe Linie direkt unter Header
        pw.Container(
          width: double.infinity,
          height: 3,
          color: yellowColor,
        ),
        // Daten-Tabelle
        pw.Table(
          columnWidths: {
            0: const pw.FixedColumnWidth(70),
            1: const pw.FixedColumnWidth(50),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FixedColumnWidth(70),
          },
          children: _buildDataRows(invoiceData),
        ),
      ],
    );
  }

  static List<pw.TableRow> _buildDataRows(InvoiceData invoiceData) {
    final List<pw.TableRow> rows = [];
    
    // Datenzeilen (nur die tatsächlichen Fahrten, keine leeren Zeilen)
    for (int i = 0; i < invoiceData.trips.length; i++) {
      final trip = invoiceData.trips[i];
      
      // Erste Fahrt: echte Adressen, danach "-" Symbol
      String fromText = i == 0 ? '"${invoiceData.fromAddress}"' : '"-"';
      String toText = i == 0 ? '"${invoiceData.toAddress}"' : '"-"';
      
      rows.add(
        pw.TableRow(
          children: [
            _buildTableCell(DateFormat('dd.MM.yy').format(trip.date)),
            _buildTableCell(trip.description),
            _buildTableCell(fromText, fontSize: 8),
            _buildTableCell(toText, fontSize: 8),
            _buildTableCell('${trip.price.toStringAsFixed(2)} EUR', align: pw.TextAlign.right),
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
    final pdfData = await generatePDF(invoiceData);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: 'Rechnung_${invoiceData.invoiceNumber}.pdf',
    );
  }

  static Future<void> generateAndSave(InvoiceData invoiceData) async {
    final pdfData = await generatePDF(invoiceData);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Rechnung_${invoiceData.invoiceNumber}.pdf');
    await file.writeAsBytes(pdfData);
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
}