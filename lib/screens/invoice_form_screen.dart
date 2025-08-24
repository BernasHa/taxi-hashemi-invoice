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
  final _purposeController = TextEditingController();
  
  // Controller für neue Fahrt-Eingabe
  final _tripDateController = TextEditingController();
  final _tripDescriptionController = TextEditingController();
  final _tripFromController = TextEditingController();
  final _tripToController = TextEditingController();
  final _tripPriceController = TextEditingController();

  DateTime _invoiceDate = DateTime.now();
  DateTime _tripDate = DateTime.now();
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
    // Keine Standard-Fahrten mehr - User soll alles selbst eingeben
    _trips.clear();
  }
  
  void _addTrip() {
    if (_tripDescriptionController.text.isEmpty || 
        _tripFromController.text.isEmpty ||
        _tripToController.text.isEmpty ||
        _tripPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte alle Fahrt-Felder ausfüllen')),
      );
      return;
    }
    
    final price = double.tryParse(_tripPriceController.text.replaceAll(',', '.'));
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gültigen Preis eingeben')),
      );
      return;
    }
    
    setState(() {
      _trips.add(TripEntry(
        date: _tripDate,
        description: _tripDescriptionController.text,
        fromAddress: _tripFromController.text,
        toAddress: _tripToController.text,
        price: price,
      ));
      
      // Felder zurücksetzen
      _tripDescriptionController.clear();
      _tripFromController.clear();
      _tripToController.clear();
      _tripPriceController.clear();
      _tripDate = DateTime.now();
    });
  }

  void _duplicateLastTrip() {
    if (_trips.isEmpty) return;
    
    final lastTrip = _trips.last;
    
    showDialog(
      context: context,
      builder: (context) => _DuplicateTripDialog(
        originalTrip: lastTrip,
        onTripDuplicated: (duplicatedTrip) {
          setState(() {
            _trips.add(duplicatedTrip);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Duplikat-Fahrt wurde hinzugefügt')),
          );
        },
      ),
    );
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
              _buildCustomerDataCard(),
              const SizedBox(height: 16),
              _buildTripInputCard(),
              const SizedBox(height: 16),
              _buildTripListCard(),
              const SizedBox(height: 16),
              _buildInvoiceDetailsCard(),
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
              textCapitalization: TextCapitalization.words,
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
              textCapitalization: TextCapitalization.words,
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
                    textCapitalization: TextCapitalization.words,
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

  Widget _buildTripInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Neue Fahrt hinzufügen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            
            // Datum auswählen
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _tripDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _tripDate = date;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fahrt-Datum *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('dd.MM.yyyy').format(_tripDate)),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Fahrt-Beschreibung
            TextFormField(
              controller: _tripDescriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Fahrt/en *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
                hintText: 'z.B. Arztfahrt, Einkauf, Therapie',
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Von-Adresse
            TextFormField(
              controller: _tripFromController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Von *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                hintText: 'z.B. Tamm (Ulmer Str.51)',
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Nach-Adresse
            TextFormField(
              controller: _tripToController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nach *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
                hintText: 'z.B. Stuttgart Hauptbahnhof',
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Preis
            TextFormField(
              controller: _tripPriceController,
              decoration: const InputDecoration(
                labelText: 'Preis *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro),
                hintText: '25.50',
                suffixText: 'EUR',
              ),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 16),
            
            // Hinzufügen-Button und Duplicate-Button
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _addTrip,
                    icon: const Icon(Icons.add),
                    label: const Text('Fahrt hinzufügen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: _trips.isEmpty ? null : _duplicateLastTrip,
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Duplicate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange[600],
                      side: BorderSide(color: _trips.isEmpty ? Colors.grey[300]! : Colors.orange[600]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Hinzugefügte Fahrten',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_trips.length} Fahrt${_trips.length == 1 ? '' : 'en'}',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_trips.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.directions_car_outlined, 
                         size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Noch keine Fahrten hinzugefügt',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fügen Sie oben Ihre erste Fahrt hinzu',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _trips.length,
                itemBuilder: (context, index) {
                  final trip = _trips[index];
                  final isDuplicate = trip.isDuplicate;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDuplicate ? Colors.orange[50] : Colors.white,
                      border: Border.all(
                        color: isDuplicate ? Colors.orange[300]! : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDuplicate ? Colors.orange[600] : Colors.blue[600],
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${DateFormat('dd.MM.yy').format(trip.date)} - ${trip.description}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDuplicate ? Colors.orange[800] : null,
                              ),
                            ),
                          ),
                          if (isDuplicate)
                            Icon(
                              Icons.content_copy,
                              size: 16,
                              color: Colors.orange[600],
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDuplicate 
                                ? "Von/Nach: '' (Duplikat - wird in PDF als '' angezeigt)"
                                : 'Von: ${trip.fromAddress}\nNach: ${trip.toAddress}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDuplicate ? Colors.orange[700] : Colors.grey[600],
                              fontStyle: isDuplicate ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${trip.price.toStringAsFixed(2)} EUR',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.green[700],
                                ),
                              ),
                              if (isDuplicate)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "''",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editTrip(index);
                              } else if (value == 'delete') {
                                _deleteTrip(index);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 16),
                                    SizedBox(width: 8),
                                    Text('Bearbeiten'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Löschen', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            child: const Icon(Icons.more_vert, color: Colors.grey),
                          ),
                        ],
                      ),
                      onTap: () {
                        _editTrip(index);
                      },
                    ),
                  );
                },
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
  
  void _editTrip(int index) {
    final trip = _trips[index];
    
    // Felder mit aktuellen Werten füllen
    _tripDescriptionController.text = trip.description;
    _tripFromController.text = trip.fromAddress;
    _tripToController.text = trip.toAddress;
    _tripPriceController.text = trip.price.toString();
    _tripDate = trip.date;
    
    // Prüfe ob Widget noch gemountet ist vor setState
    if (mounted) {
      setState(() {
        // Fahrt temporär entfernen für Bearbeitung
        _trips.removeAt(index);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fahrt wird bearbeitet - Änderungen vornehmen und erneut hinzufügen')),
      );
    }
  }
  
  void _deleteTrip(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fahrt löschen'),
        content: const Text('Möchten Sie diese Fahrt wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (mounted) {
                setState(() {
                  _trips.removeAt(index);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fahrt wurde gelöscht')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
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



  Future<void> _generatePreview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final invoiceData = _createInvoiceData();
      await PDFService.generateAndPreview(invoiceData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF Vorschau erfolgreich erstellt!')),
        );
      }
    } catch (e) {
      print('Fehler in _generatePreview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Generieren der PDF: $e')),
        );
      }
    } finally {
      // Immer den Status zurücksetzen, auch bei Fehlern
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
      
      // Zusätzliche Sicherheit: Nach 2 Sekunden nochmal prüfen
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isGenerating) {
          setState(() {
            _isGenerating = false;
          });
        }
      });
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
      _purposeController.clear();
      
      // Neue Fahrt-Controller zurücksetzen
      _tripDescriptionController.clear();
      _tripFromController.clear();
      _tripToController.clear();
      _tripPriceController.clear();
      
      // Datum zurücksetzen
      _invoiceDate = DateTime.now();
      _tripDate = DateTime.now();
      
      // Fahrten zurücksetzen
      _trips.clear();
      _addInitialTrips();
      
      // Location zurücksetzen
      _selectedLocation = TaxiLocation.tamm;
      
      _isGenerating = false; // Sicherstellen, dass PDF-Generation zurückgesetzt wird
    });
    
    // Formular-Key zurücksetzen für saubere Validierung
    _formKey.currentState?.reset();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Formular wurde zurückgesetzt - bereit für neue Rechnung')),
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
    _purposeController.dispose();
    
    // Neue Fahrt-Controller dispose
    _tripDescriptionController.dispose();
    _tripFromController.dispose();
    _tripToController.dispose();
    _tripPriceController.dispose();
    
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
                fromAddress: 'Standard Von-Adresse', // Placeholder
                toAddress: 'Standard Nach-Adresse',  // Placeholder
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

// Dialog für das Duplizieren von Fahrten
class _DuplicateTripDialog extends StatefulWidget {
  final TripEntry originalTrip;
  final Function(TripEntry) onTripDuplicated;

  const _DuplicateTripDialog({
    required this.originalTrip,
    required this.onTripDuplicated,
  });

  @override
  State<_DuplicateTripDialog> createState() => _DuplicateTripDialogState();
}

class _DuplicateTripDialogState extends State<_DuplicateTripDialog> {
  late TextEditingController _priceController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.originalTrip.price.toString());
    _selectedDate = widget.originalTrip.date;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fahrt duplizieren'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fahrt/en: ${widget.originalTrip.description}', 
               style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Von: ${widget.originalTrip.fromAddress}', 
               style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Nach: ${widget.originalTrip.toAddress}', 
               style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Editierbare Felder:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          // Datum auswählen
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                });
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Datum',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                '${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Preis editieren
          TextFormField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Preis (EUR)',
              border: OutlineInputBorder(),
              prefixText: '€ ',
            ),
            keyboardType: TextInputType.number,
            textCapitalization: TextCapitalization.none,
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
            final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
            if (price == null || price <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bitte gültigen Preis eingeben')),
              );
              return;
            }

            // Erstelle Duplikat mit isDuplicate = true
            final duplicatedTrip = TripEntry(
              date: _selectedDate,
              description: widget.originalTrip.description,
              fromAddress: widget.originalTrip.fromAddress,
              toAddress: widget.originalTrip.toAddress,
              price: price,
              isDuplicate: true, // Markiere als Duplikat!
            );

            widget.onTripDuplicated(duplicatedTrip);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[600],
            foregroundColor: Colors.white,
          ),
          child: const Text('Duplizieren'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }
}