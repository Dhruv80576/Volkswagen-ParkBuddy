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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Book Parking',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Search
                    _buildLocationSearch(),
                    const SizedBox(height: 16),
                    
                    // Date & Time Selection
                    _buildDateTimeSelection(),
                    const SizedBox(height: 16),
                    
                    // Requirements
                    _buildRequirements(),
                    const SizedBox(height: 16),
                    
                    // Available Slots
                    if (_availableSlots.isNotEmpty) _buildAvailableSlots(),
                    
                    // Selected Slot Details
                    if (_selectedSlot != null) ...[
                      const SizedBox(height: 16),
                      _buildSelectedSlotDetails(),
                    ],
                    
                    // Vehicle Information
                    if (_selectedSlot != null) ...[
                      const SizedBox(height: 16),
                      _buildVehicleInfo(),
                    ],
                    
                    // Add bottom padding to prevent content from being hidden behind button
                    if (_selectedSlot != null) const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          
          // Book Button - Fixed at bottom
          if (_selectedSlot != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16.0),
              child: SafeArea(
                child: _buildBookButton(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationSearch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_on, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Search Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter location (e.g., Bandra West, Mumbai)',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            
            // Search Results
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.grey[300],
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final place = _searchResults[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on, color: Colors.red, size: 20),
                      ),
                      title: Text(
                        place.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        place.address,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPlace!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedPlace!.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.access_time, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Date & Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      _selectedTime.format(context),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            Text(
              'Duration',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.black,
                inactiveTrackColor: Colors.grey[300],
                thumbColor: Colors.black,
                overlayColor: Colors.black.withOpacity(0.1),
                valueIndicatorColor: Colors.black,
                valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Slider(
                value: _durationHours.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                label: '$_durationHours hrs',
                onChanged: (value) {
                  setState(() {
                    _durationHours = value.toInt();
                  });
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Parking Duration',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$_durationHours ${_durationHours == 1 ? 'hour' : 'hours'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirements() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Requirements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            _buildRequirementTile(
              icon: Icons.ev_station,
              title: 'EV Charging',
              subtitle: 'Requires electric vehicle charging',
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
            
            const SizedBox(height: 4),
            
            _buildRequirementTile(
              icon: Icons.accessible,
              title: 'Handicap Accessible',
              subtitle: 'Requires handicap accessibility',
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

  Widget _buildRequirementTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: value ? Colors.black.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value ? Colors.black : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: value ? Colors.white : Colors.black, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: value ? Colors.black : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildAvailableSlots() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_parking, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Available Parking (${_availableSlots.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isLoadingSlots)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _availableSlots.length,
                itemBuilder: (context, index) {
                  final slot = _availableSlots[index];
                  final isSelected = _selectedSlot?.id == slot.id;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.local_parking,
                          color: isSelected ? Colors.black : Colors.grey[700],
                          size: 24,
                        ),
                      ),
                      title: Text(
                        '${slot.area} - ${slot.type}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '₹${slot.effectivePrice}/hr',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white.withOpacity(0.9) : Colors.black87,
                            ),
                          ),
                          if (slot.isEVCharging || slot.isHandicap) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (slot.isEVCharging)
                                  _buildFeatureBadge(
                                    '⚡ EV Charging',
                                    isSelected,
                                  ),
                                if (slot.isHandicap)
                                  _buildFeatureBadge(
                                    '♿ Accessible',
                                    isSelected,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.white)
                          : Icon(Icons.circle_outlined, color: Colors.grey[400]),
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

  Widget _buildFeatureBadge(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected 
            ? Colors.white.withOpacity(0.2) 
            : Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSelectedSlotDetails() {
    if (_selectedSlot == null) return const SizedBox.shrink();
    
    final totalPrice = _selectedSlot!.effectivePrice * _durationHours;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, Colors.grey[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Booking Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            _buildDetailRow(
              'Location',
              '${_selectedSlot!.area}, ${_selectedSlot!.city}',
              isLight: true,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Type',
              _selectedSlot!.type,
              isLight: true,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Price/hour',
              '₹${_selectedSlot!.effectivePrice}',
              isLight: true,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Duration',
              '$_durationHours ${_durationHours == 1 ? 'hour' : 'hours'}',
              isLight: true,
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
            ),
            
            _buildDetailRow(
              'Total Price',
              '₹${totalPrice.toStringAsFixed(2)}',
              isBold: true,
              isLight: true,
              fontSize: 18,
            ),
            
            // Availability Prediction
            if (_availabilityPrediction != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.psychology, color: Colors.blue, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ML Prediction',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Availability',
                _availabilityPrediction!.statusText,
                isLight: true,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Confidence',
                '${(_availabilityPrediction!.confidence * 100).toStringAsFixed(0)}% - ${_availabilityPrediction!.confidenceLevel}',
                isLight: true,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Probability',
                '${(_availabilityPrediction!.availabilityProbability * 100).toStringAsFixed(0)}% likely available',
                isLight: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    bool isLight = false,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isLight ? Colors.white.withOpacity(0.7) : Colors.grey[700],
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isLight ? Colors.white : Colors.black,
              fontSize: fontSize,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_car, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Vehicle Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _vehicleNumberController,
              decoration: InputDecoration(
                labelText: 'Vehicle Number',
                hintText: 'e.g., MH 01 AB 1234',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.pin, color: Colors.black),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                labelStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _vehicleModelController,
              decoration: InputDecoration(
                labelText: 'Vehicle Model (Optional)',
                hintText: 'e.g., Honda City',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.car_rental, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                labelStyle: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
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
      height: 56,
      child: ElevatedButton(
        onPressed: _isBooking ? null : _createBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF000000),
          disabledBackgroundColor: Colors.grey[400],
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isBooking
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Confirm Booking',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
