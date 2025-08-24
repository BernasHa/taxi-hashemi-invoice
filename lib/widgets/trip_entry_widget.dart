import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_data.dart';

class TripEntryWidget extends StatelessWidget {
  final TripEntry trip;
  final Function(TripEntry) onEdit;
  final VoidCallback onDelete;

  const TripEntryWidget({
    super.key,
    required this.trip,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.yellow[700],
          foregroundColor: Colors.black,
          child: const Icon(Icons.local_taxi),
        ),
        title: Text(
          trip.description,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datum: ${DateFormat('dd.MM.yyyy').format(trip.date)}'),
            const SizedBox(height: 2),
            Text(
              'Von: Tamm, Ulmer Str. 51',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Nach: Ludwigsburg, Erlachhof Str. 1 und zurück',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trip.formattedPrice,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditDialog(context);
                    break;
                  case 'delete':
                    _showDeleteDialog(context);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Bearbeiten'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Löschen', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _EditTripDialog(
        trip: trip,
        onEdit: onEdit,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
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
          ElevatedButton(
            onPressed: () {
              onDelete();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}

class _EditTripDialog extends StatefulWidget {
  final TripEntry trip;
  final Function(TripEntry) onEdit;

  const _EditTripDialog({
    required this.trip,
    required this.onEdit,
  });

  @override
  State<_EditTripDialog> createState() => _EditTripDialogState();
}

class _EditTripDialogState extends State<_EditTripDialog> {
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late DateTime _tripDate;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.trip.price.toStringAsFixed(2));
    _descriptionController = TextEditingController(text: widget.trip.description);
    _tripDate = widget.trip.date;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fahrt bearbeiten'),
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
              widget.onEdit(TripEntry(
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
          child: const Text('Speichern'),
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