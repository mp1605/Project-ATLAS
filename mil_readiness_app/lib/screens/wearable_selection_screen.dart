import 'package:flutter/material.dart';
import '../models/wearable_type.dart';
import '../adapters/health_adapter_factory.dart';
import '../services/local_secure_store.dart';

/// Wearable device selection screen
/// 
/// Shows available wearable devices as beautiful cards with:
/// - Device icons and branding
/// - Implementation status badges
/// - Platform compatibility indication
class WearableSelectionScreen extends StatefulWidget {
  /// If true, this is initial onboarding. If false, user is switching devices.
  final bool isOnboarding;
  final String userEmail;

  const WearableSelectionScreen({
    super.key,
    this.isOnboarding = true,
    required this.userEmail,
  });

  @override
  State<WearableSelectionScreen> createState() => _WearableSelectionScreenState();
}

class _WearableSelectionScreenState extends State<WearableSelectionScreen> {
  WearableType? _selectedDevice;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSelection();
  }

  Future<void> _loadCurrentSelection() async {
    if (!widget.isOnboarding) {
      // When switching, load current device
      final currentDevice = await LocalSecureStore.instance.getSelectedWearableFor(widget.userEmail);
      if (currentDevice != null && mounted) {
        try {
          setState(() {
            _selectedDevice = WearableType.values.firstWhere(
              (type) => type.name == currentDevice,
            );
          });
        } catch (e) {
          // Invalid device in storage, ignore
        }
      }
    }
  }

  List<WearableType> _getAvailableDevices() {
    return HealthAdapterFactory.getAvailableWearables();
  }

  Future<void> _confirmSelection() async {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a device')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save selection
      await LocalSecureStore.instance.setSelectedWearableFor(
        widget.userEmail,
        _selectedDevice!.name,
      );

      if (mounted) {
        if (widget.isOnboarding) {
          // Navigate to authorization
          Navigator.pushReplacementNamed(context, '/authorize');
        } else {
          // Return to settings
          Navigator.pop(context, _selectedDevice);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving selection: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableDevices = _getAvailableDevices();
    final implementedDevices = HealthAdapterFactory.getImplementedAdapters();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOnboarding ? 'Select Your Device' : 'Switch Device'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Icon(Icons.watch, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    widget.isOnboarding
                        ? 'Which wearable do you use?'
                        : 'Select your new device',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'ll connect to your device to track your readiness',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Device Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: availableDevices.length,
                itemBuilder: (context, index) {
                  final device = availableDevices[index];
                  final isImplemented = implementedDevices.contains(device);
                  final isSelected = _selectedDevice == device;

                  return _buildDeviceCard(
                    device: device,
                    isImplemented: isImplemented,
                    isSelected: isSelected,
                  );
                },
              ),
            ),

            // Confirm Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading || _selectedDevice == null
                      ? null
                      : _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isOnboarding ? 'Continue' : 'Switch Device',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard({
    required WearableType device,
    required bool isImplemented,
    required bool isSelected,
  }) {
    final gradient = _getDeviceGradient(device);

    return GestureDetector(
      onTap: () => setState(() => _selectedDevice = device),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isSelected ? gradient : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Icon(
                      _getDeviceIcon(device),
                      size: 48,
                      color: isSelected ? Colors.white : Colors.blue[700],
                    ),
                    const SizedBox(height: 12),

                    // Name
                    Text(
                      device.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : (isImplemented ? Colors.green[50] : Colors.orange[50]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isImplemented ? '✅ Available' : '🚧 Coming Soon',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isImplemented ? Colors.green[700] : Colors.orange[700]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Selected Checkmark
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 20,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon(WearableType device) {
    switch (device) {
      case WearableType.appleWatch:
        return Icons.watch;
      case WearableType.garmin:
        return Icons.fitness_center;
      case WearableType.samsung:
      case WearableType.pixelWatch:
        return Icons.watch_later;
      case WearableType.fitbit:
        return Icons.favorite;
      case WearableType.ouraRing:
        return Icons.radio_button_unchecked;
      case WearableType.whoop:
        return Icons.trending_up;
      case WearableType.casio:
        return Icons.timer;
      case WearableType.amazfit:
        return Icons.sports_score;
      case WearableType.polar:
        return Icons.explore;
      case WearableType.other:
        return Icons.devices_other;
    }
  }

  LinearGradient _getDeviceGradient(WearableType device) {
    switch (device) {
      case WearableType.appleWatch:
        return const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WearableType.garmin:
        return const LinearGradient(
          colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WearableType.samsung:
        return const LinearGradient(
          colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WearableType.fitbit:
        return const LinearGradient(
          colors: [Color(0xFF00d2ff), Color(0xFF3a7bd5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WearableType.ouraRing:
        return const LinearGradient(
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WearableType.whoop:
        return const LinearGradient(
          colors: [Color(0xFFf46b45), Color(0xFFeea849)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WearableType.polar:
        return const LinearGradient(
          colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WearableType.amazfit:
        return const LinearGradient(
          colors: [Color(0xFFfa709a), Color(0xFFfee140)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WearableType.casio:
        return const LinearGradient(
          colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WearableType.pixelWatch:
        return const LinearGradient(
          colors: [Color(0xFF5f72bd), Color(0xFF9b23ea)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WearableType.other:
        return const LinearGradient(
          colors: [Color(0xFF757F9A), Color(0xFFD7DDE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}
