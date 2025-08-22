import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/invoice_data.dart';
import '../services/pdf_service.dart';
import '../widgets/trip_entry_widget.dart';

class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({super.key});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerStreetController = TextEditingController();
  final _customerPostalCodeController = TextEditingController();
  final _customerCityController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _vatRateController = TextEditingController(text: '7');
  final _fromAddressController = TextEditingController();
  final _toAddressController = TextEditingController();
  final _purposeController = TextEditingController();

  DateTime _invoiceDate = DateTime.now();
  List<TripEntry> _trips = [];

  bool _isGenerating = false;
  TaxiLocation _selectedLocation = TaxiLocation.tamm;

  @override
  void initState() {
    super.initState();
    _invoiceNumberController.text = 'R-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    _addInitialTrips();
    
    // Listener für Echtzeit-Berechnung
    _vatRateController.addListener(() {
      setState(() {
        // Trigger rebuild für Summary-Card
      });
    });
  }

  void _addInitialTrips() {
    // Füge einige Beispielfahrten hinzu
    _trips.addAll([
      TripEntry(date: DateTime.now(), description: 'Fahrt', price: 10.00),
      TripEntry(date: DateTime.now().subtract(const Duration(days: 1)), description: 'Fahrt', price: 10.00),
      TripEntry(date: DateTime.now().subtract(const Duration(days: 2)), description: 'Fahrt', price: 10.00),
    ]);
    
    // Standard-Adressen setzen
    _fromAddressController.text = 'Tamm (Ulmer Str.51)';
    _toAddressController.text = 'Ludwigsburg (Erlachhof Str.1) und zurück';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taxi Rechnung erstellen'),
        backgroundColor: Colors.yellow[700],
        foregroundColor: Colors.black,
        elevation: 2,
      ),
      body: Form(
        key: _formKey,
        child: GestureDetector(
          onTap: () {
            // Tastatur schließen beim Tippen außerhalb von Eingabefeldern
            // Aber nur wenn kein TextField den Focus hat
            final currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
              currentFocus.unfocus();
            }
          },
          behavior: HitTestBehavior.opaque,
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              // Nur beim tatsächlichen Scrollen schließen, nicht bei Tap-Events
              if (scrollInfo is ScrollUpdateNotification && scrollInfo.dragDetails != null) {
                FocusScope.of(context).unfocus();
              }
              return false;
            },
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLocationCard(),
              const SizedBox(height: 16),
              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildCustomerDataCard(),
              const SizedBox(height: 16),
              _buildRouteCard(),
              const SizedBox(height: 16),
              _buildInvoiceDetailsCard(),
              const SizedBox(height: 16),
              _buildTripsCard(),
              const SizedBox(height: 16),
              _buildSummaryCard(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Standort auswählen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<TaxiLocation>(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Taxi-Service-Tamm',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Heilbronner Str. 30\n71732 Tamm',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    value: TaxiLocation.tamm,
                    groupValue: _selectedLocation,
                    activeColor: Colors.yellow[700],
                    onChanged: (TaxiLocation? value) {
                      setState(() {
                        _selectedLocation = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<TaxiLocation>(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Taxi Sersheim',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Waldeck Str. 7\n74371 Sersheim',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    value: TaxiLocation.sersheim,
                    groupValue: _selectedLocation,
                    activeColor: Colors.yellow[700],
                    onChanged: (TaxiLocation? value) {
                      setState(() {
                        _selectedLocation = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                          Row(
                children: [
                  Icon(Icons.local_taxi, color: Colors.yellow[700], size: 32),
                  const SizedBox(width: 12),
                  Text(
                    CompanyInfo.getName(_selectedLocation),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'Logo wird automatisch aus den App-Ressourcen verwendet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kundendaten',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Kundenname *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Bitte Namen eingeben' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerStreetController,
              decoration: const InputDecoration(
                labelText: 'Straße und Hausnummer *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Bitte Straße eingeben' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _customerPostalCodeController,
                    decoration: const InputDecoration(
                      labelText: 'PLZ *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty ?? true ? 'PLZ eingeben' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _customerCityController,
                    decoration: const InputDecoration(
                      labelText: 'Ort *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Ort eingeben' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fahrtstrecke',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fromAddressController,
              decoration: const InputDecoration(
                labelText: 'Abfahrtsort *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                hintText: 'z.B. Tamm (Ulmer Str.51)',
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Bitte Abfahrtsort eingeben' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _toAddressController,
              decoration: const InputDecoration(
                labelText: 'Ankunftsort *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
                hintText: 'z.B. Ludwigsburg (Erlachhof Str.1) und zurück',
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Bitte Ankunftsort eingeben' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purposeController,
              decoration: const InputDecoration(
                labelText: 'Verwendungszweck',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                hintText: 'z.B. Rechnung Nr. 708-024',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rechnungsdetails',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _invoiceNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Rechnungsnummer *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.receipt),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Rechnungsnummer eingeben' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _vatRateController,
                    decoration: const InputDecoration(
                      labelText: 'MwSt. (%)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.percent),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Rechnungsdatum',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('dd.MM.yyyy').format(_invoiceDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fahrten',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addTrip,
                  icon: const Icon(Icons.add),
                  label: const Text('Fahrt hinzufügen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[700],
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_trips.isEmpty)
              const Center(
                child: Text(
                  'Noch keine Fahrten hinzugefügt',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _trips.length,
                itemBuilder: (context, index) {
                  return TripEntryWidget(
                    trip: _trips[index],
                    onEdit: (updatedTrip) {
                      setState(() {
                        _trips[index] = updatedTrip;
                      });
                    },
                    onDelete: () {
                      setState(() {
                        _trips.removeAt(index);
                      });
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final vatRate = double.tryParse(_vatRateController.text) ?? 7.0;
    final netAmount = _trips.fold(0.0, (sum, trip) => sum + trip.price);
    final vatAmount = netAmount * (vatRate / 100);
    final totalAmount = netAmount + vatAmount;

    return Card(
      color: Colors.yellow[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zusammenfassung',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Netto:', style: TextStyle(fontSize: 16)),
                Text('${netAmount.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('MwSt. ${vatRate.toInt()}%:', style: const TextStyle(fontSize: 16)),
                Text('${vatAmount.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Gesamtbetrag:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  '${totalAmount.toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generatePreview,
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.preview),
            label: Text(_isGenerating ? 'Generiere...' : 'PDF Vorschau'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow[700],
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isGenerating ? null : _saveAndSharePdf,
                icon: const Icon(Icons.save),
                label: const Text('Speichern'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.yellow[700]!),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isGenerating ? null : _shareDirectly,
                icon: const Icon(Icons.share),
                label: const Text('Teilen'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.yellow[700]!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh),
            label: const Text('Neue Rechnung'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }



  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _invoiceDate) {
      setState(() {
        _invoiceDate = picked;
      });
    }
  }

  void _addTrip() {
    showDialog(
      context: context,
      builder: (context) => _AddTripDialog(
        onAdd: (trip) {
          setState(() {
            _trips.add(trip);
          });
        },
      ),
    );
  }

  Future<void> _generatePreview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final invoiceData = _createInvoiceData();
      await PDFService.generateAndPreview(invoiceData);
      
      // Kurze Verzögerung um sicherzustellen, dass PDF-Viewer schließt
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF Vorschau erfolgreich erstellt!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Generieren der PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _saveAndSharePdf() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final invoiceData = _createInvoiceData();
      await PDFService.generateAndSave(invoiceData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF erfolgreich gespeichert!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern der PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _shareDirectly() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final invoiceData = _createInvoiceData();
      await PDFService.generateAndShare(invoiceData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Teilen der PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  InvoiceData _createInvoiceData() {
    final vatRate = (double.tryParse(_vatRateController.text) ?? 7.0) / 100;
    
    return InvoiceData(
      customerName: _customerNameController.text,
      customerStreet: _customerStreetController.text,
      customerPostalCode: _customerPostalCodeController.text,
      customerCity: _customerCityController.text,
      invoiceNumber: _invoiceNumberController.text,
      invoiceDate: _invoiceDate,
      trips: _trips,
      vatRate: vatRate,
      logoPath: null, // Logo aus assets verwenden
      location: _selectedLocation,
      fromAddress: _fromAddressController.text,
      toAddress: _toAddressController.text,
      purpose: _purposeController.text,
    );
  }

  void _resetForm() {
    setState(() {
      // Controller zurücksetzen
      _customerNameController.clear();
      _customerStreetController.clear();
      _customerPostalCodeController.clear();
      _customerCityController.clear();
      _invoiceNumberController.text = 'R-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      _vatRateController.text = '7';
      _fromAddressController.text = 'Tamm, Ulmer Str. 51';
      _toAddressController.text = 'Ludwigsburg, Erlachhof Str. 1 und zurück';
      _purposeController.clear();
      
      // Datum zurücksetzen
      _invoiceDate = DateTime.now();
      
      // Fahrten zurücksetzen
      _trips.clear();
      _addInitialTrips();
      
      // Location zurücksetzen
      _selectedLocation = TaxiLocation.tamm;
      
      _isGenerating = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Formular wurde zurückgesetzt')),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerStreetController.dispose();
    _customerPostalCodeController.dispose();
    _customerCityController.dispose();
    _invoiceNumberController.dispose();
    _vatRateController.dispose();
    _fromAddressController.dispose();
    _toAddressController.dispose();
    _purposeController.dispose();
    super.dispose();
  }
}

class _AddTripDialog extends StatefulWidget {
  final Function(TripEntry) onAdd;

  const _AddTripDialog({required this.onAdd});

  @override
  State<_AddTripDialog> createState() => _AddTripDialogState();
}

class _AddTripDialogState extends State<_AddTripDialog> {
  final _priceController = TextEditingController(text: '10.00');
  final _descriptionController = TextEditingController(text: 'Fahrt');
  DateTime _tripDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Fahrt hinzufügen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _tripDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() {
                  _tripDate = picked;
                });
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Datum',
                border: OutlineInputBorder(),
              ),
              child: Text(DateFormat('dd.MM.yyyy').format(_tripDate)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Preis (€)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            final price = double.tryParse(_priceController.text) ?? 0.0;
            if (price > 0) {
              widget.onAdd(TripEntry(
                date: _tripDate,
                description: _descriptionController.text,
                price: price,
              ));
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow[700],
            foregroundColor: Colors.black,
          ),
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}