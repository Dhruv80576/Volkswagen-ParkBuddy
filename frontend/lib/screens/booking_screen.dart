import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../models/parking_model.dart';
import '../services/booking_service.dart';
import '../services/google_places_service.dart';
import 'dart:async';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final BookingService _bookingService = BookingService();
  final GooglePlacesService _placesService = GooglePlacesService();
  
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  
  List<PlaceSearchResult> _searchResults = [];
  PlaceSearchResult? _selectedPlace;
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _durationHours = 2;
  
  bool _requireEVCharging = false;
  bool _requireHandicap = false;
  
  List<ParkingSlot> _availableSlots = [];
  ParkingSlot? _selectedSlot;
  AvailabilityPrediction? _availabilityPrediction;
  
  bool _isSearching = false;
  bool _isLoadingSlots = false;
  bool _isBooking = false;
  
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _vehicleNumberController.dispose();
    _vehicleModelController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _placesService.searchPlaces(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      _showSnackBar('Error searching places: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectPlace(PlaceSearchResult place) {
    setState(() {
      _selectedPlace = place;
      _searchResults = [];
      _searchController.text = place.name;
    });
    
    // Search for parking near this place
    _searchParkingSlots();
  }

  Future<void> _searchParkingSlots() async {
    if (_selectedPlace == null) {
      _showSnackBar('Please select a location first');
      return;
    }

    setState(() => _isLoadingSlots = true);

    try {
      final desiredDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final slots = await _bookingService.searchParkingWithAvailability(
        latitude: _selectedPlace!.latitude,
        longitude: _selectedPlace!.longitude,
        desiredTime: desiredDateTime,
        requireEVCharging: _requireEVCharging,
        requireHandicap: _requireHandicap,
      );

      setState(() {
        _availableSlots = slots;
      });

      if (slots.isEmpty) {
        _showSnackBar('No parking slots found near this location');
      }
    } catch (e) {
      _showSnackBar('Error searching parking: $e');
    } finally {
      setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _selectSlot(ParkingSlot slot) async {
    setState(() {
      _selectedSlot = slot;
    });

    // Predict availability for this slot
    final desiredDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      final prediction = await _bookingService.predictAvailability(
        city: slot.city,
        area: slot.area,
        parkingType: slot.type,
        timestamp: desiredDateTime,
        isEVCharging: slot.isEVCharging,
        isHandicap: slot.isHandicap,
        pricePerHour: slot.pricePerHour,
      );

      setState(() {
        _availabilityPrediction = prediction;
      });
    } catch (e) {
      print('Error predicting availability: $e');
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      
      if (_selectedPlace != null) {
        _searchParkingSlots();
      }
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
      
      if (_selectedPlace != null) {
        _searchParkingSlots();
      }
    }
  }

  Future<void> _createBooking() async {
    if (_selectedSlot == null) {
      _showSnackBar('Please select a parking slot');
      return;
    }

    if (_vehicleNumberController.text.isEmpty) {
      _showSnackBar('Please enter vehicle number');
      return;
    }

    setState(() => _isBooking = true);

    try {
      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      final endTime = startTime.add(Duration(hours: _durationHours));

      final booking = await _bookingService.createBooking(
        userId: 'user-123', // TODO: Get from auth
        slotId: _selectedSlot!.id,
        startTime: startTime,
        endTime: endTime,
        vehicleNumber: _vehicleNumberController.text,
        vehicleModel: _vehicleModelController.text.isEmpty 
            ? null 
            : _vehicleModelController.text,
      );

      if (booking != null) {
        _showSnackBar('Booking created successfully!');
        Navigator.pop(context, booking);
      } else {
        _showSnackBar('Failed to create booking');
      }
    } catch (e) {
      _showSnackBar('Error creating booking: $e');
    } finally {
      setState(() => _isBooking = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Parking'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Search
              _buildLocationSearch(),
              const SizedBox(height: 20),
              
              // Date & Time Selection
              _buildDateTimeSelection(),
              const SizedBox(height: 20),
              
              // Requirements
              _buildRequirements(),
              const SizedBox(height: 20),
              
              // Available Slots
              if (_availableSlots.isNotEmpty) _buildAvailableSlots(),
              
              // Selected Slot Details
              if (_selectedSlot != null) ...[
                const SizedBox(height: 20),
                _buildSelectedSlotDetails(),
              ],
              
              // Vehicle Information
              if (_selectedSlot != null) ...[
                const SizedBox(height: 20),
                _buildVehicleInfo(),
              ],
              
              // Book Button
              if (_selectedSlot != null) ...[
                const SizedBox(height: 30),
                _buildBookButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSearch() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📍 Search Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter location (e.g., Bandra West, Mumbai)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            
            // Search Results
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = _searchResults[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.red),
                      title: Text(place.name),
                      subtitle: Text(place.address),
                      onTap: () => _selectPlace(place),
                    );
                  },
                ),
              ),
            ],
            
            // Selected Place
            if (_selectedPlace != null && _searchResults.isEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPlace!.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _selectedPlace!.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSelection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🕐 Date & Time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime.format(context)),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            const Text('Duration (hours):'),
            Slider(
              value: _durationHours.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              label: '$_durationHours hours',
              onChanged: (value) {
                setState(() {
                  _durationHours = value.toInt();
                });
              },
            ),
            Text(
              'Parking duration: $_durationHours hours',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirements() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚙️ Requirements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            CheckboxListTile(
              title: const Text('EV Charging'),
              subtitle: const Text('Requires electric vehicle charging'),
              value: _requireEVCharging,
              onChanged: (value) {
                setState(() {
                  _requireEVCharging = value ?? false;
                });
                if (_selectedPlace != null) {
                  _searchParkingSlots();
                }
              },
            ),
            
            CheckboxListTile(
              title: const Text('Handicap Accessible'),
              subtitle: const Text('Requires handicap accessibility'),
              value: _requireHandicap,
              onChanged: (value) {
                setState(() {
                  _requireHandicap = value ?? false;
                });
                if (_selectedPlace != null) {
                  _searchParkingSlots();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableSlots() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🅿️ Available Parking (${_availableSlots.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            if (_isLoadingSlots)
              const Center(child: CircularProgressIndicator())
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _availableSlots.length,
                itemBuilder: (context, index) {
                  final slot = _availableSlots[index];
                  final isSelected = _selectedSlot?.id == slot.id;
                  
                  return Card(
                    color: isSelected ? Colors.blue.shade50 : null,
                    child: ListTile(
                      leading: Icon(
                        Icons.local_parking,
                        color: isSelected ? Colors.blue : Colors.grey,
                      ),
                      title: Text('${slot.area} - ${slot.type}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('₹${slot.effectivePrice}/hr'),
                          if (slot.isEVCharging) 
                            const Text('⚡ EV Charging', 
                              style: TextStyle(color: Colors.green)),
                          if (slot.isHandicap) 
                            const Text('♿ Handicap Accessible',
                              style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : null,
                      onTap: () => _selectSlot(slot),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSlotDetails() {
    if (_selectedSlot == null) return const SizedBox.shrink();
    
    final totalPrice = _selectedSlot!.effectivePrice * _durationHours;
    
    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📋 Booking Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            _buildDetailRow('Location', '${_selectedSlot!.area}, ${_selectedSlot!.city}'),
            _buildDetailRow('Type', _selectedSlot!.type),
            _buildDetailRow('Price/hour', '₹${_selectedSlot!.effectivePrice}'),
            _buildDetailRow('Duration', '$_durationHours hours'),
            const Divider(),
            _buildDetailRow('Total Price', '₹${totalPrice.toStringAsFixed(2)}',
                isBold: true),
            
            // Availability Prediction
            if (_availabilityPrediction != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const Text(
                '🤖 ML Prediction',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Availability',
                _availabilityPrediction!.statusText,
              ),
              _buildDetailRow(
                'Confidence',
                '${(_availabilityPrediction!.confidence * 100).toStringAsFixed(0)}% - ${_availabilityPrediction!.confidenceLevel}',
              ),
              _buildDetailRow(
                'Probability',
                '${(_availabilityPrediction!.availabilityProbability * 100).toStringAsFixed(0)}% likely available',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: isBold ? FontWeight.bold : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🚗 Vehicle Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _vehicleNumberController,
              decoration: InputDecoration(
                labelText: 'Vehicle Number *',
                hintText: 'e.g., MH 01 AB 1234',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            
            const SizedBox(height: 12),
            
            TextField(
              controller: _vehicleModelController,
              decoration: InputDecoration(
                labelText: 'Vehicle Model (Optional)',
                hintText: 'e.g., Honda City',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isBooking ? null : _createBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isBooking
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Confirm Booking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
