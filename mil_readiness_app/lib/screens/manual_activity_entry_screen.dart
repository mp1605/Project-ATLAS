import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/manual_activity_entry.dart';
import '../repositories/manual_activity_repository.dart';
import '../services/local_secure_store.dart';
import '../utils/validation_utils.dart';
import '../theme/app_theme.dart';

class ManualActivityEntryScreen extends StatefulWidget {
  final String? activityId;
  const ManualActivityEntryScreen({super.key, this.activityId});

  @override
  State<ManualActivityEntryScreen> createState() => _ManualActivityEntryScreenState();
}

class _ManualActivityEntryScreenState extends State<ManualActivityEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final ManualActivityRepository _repository = ManualActivityRepository();
  
  // Form State
  ActivityType _activityType = ActivityType.walking;
  final _customNameController = TextEditingController();
  DateTime _startTime = DateTime.now();
  final _durationController = TextEditingController(text: '30');
  double _rpe = 5.0;
  String _feelAfter = 'same';
  
  // Advanced State
  bool _showAdvanced = false;
  Purpose? _purpose;
  double _fatigue = 2.0;
  PainSeverity _painSeverity = PainSeverity.none;
  final _painLocationController = TextEditingController();
  final _distanceController = TextEditingController();
  String _distanceUnit = 'mi';
  final _loadController = TextEditingController();
  String _loadUnit = 'lb';
  IndoorOutdoor? _indoorOutdoor;
  HeatLevel? _heatLevel;
  final _notesController = TextEditingController();

  // FocusNodes for blur validation
  final _durationFocus = FocusNode();
  final _distanceFocus = FocusNode();
  final _loadFocus = FocusNode();

  bool _isSaving = false;

   @override
  void initState() {
    super.initState();
    _durationFocus.addListener(_onFocusChange);
    _distanceFocus.addListener(_onFocusChange);
    _loadFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_durationFocus.hasFocus && !_distanceFocus.hasFocus && !_loadFocus.hasFocus) {
       // Trigger validation when any field loses focus
       _formKey.currentState?.validate();
    }
  }

  @override
  void dispose() {
    _durationFocus.dispose();
    _distanceFocus.dispose();
    _loadFocus.dispose();
    _customNameController.dispose();
    _durationController.dispose();
    _painLocationController.dispose();
    _distanceController.dispose();
    _loadController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      final userEmail = await LocalSecureStore.instance.getActiveSessionEmail();
      if (userEmail == null) throw Exception('No active user session');

      final entry = ManualActivityEntry.create(
        userEmail: userEmail,
        activityType: _activityType,
        customName: _activityType == ActivityType.other ? _customNameController.text : null,
        startTime: _startTime,
        durationMinutes: int.parse(_durationController.text),
        rpe: _rpe.toInt(),
        feelAfter: _feelAfter,
        purpose: _purpose,
        fatigueAfter0to5: _fatigue.toInt(),
        painSeverity: _painSeverity,
        painLocation: _painSeverity != PainSeverity.none ? _painLocationController.text : null,
        distanceValue: _distanceController.text.isNotEmpty ? double.tryParse(_distanceController.text) : null,
        distanceUnit: _distanceController.text.isNotEmpty ? _distanceUnit : null,
        loadValue: _loadController.text.isNotEmpty ? double.tryParse(_loadController.text) : null,
        loadUnit: _loadController.text.isNotEmpty ? _loadUnit : null,
        indoorOutdoor: _indoorOutdoor,
        heatLevel: _heatLevel,
        notes: _notesController.text,
      );

      await _repository.upsert(entry);
      
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity logged successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('❌ Error saving activity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDarker,
      appBar: AppBar(
        title: Text(widget.activityId == null ? 'Log Activity' : 'Edit Activity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.bgDarker, AppTheme.bgDark],
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('QUICK LOG'),
                const SizedBox(height: 16),
                _buildGlassCard(
                  child: Column(
                    children: [
                      _buildDropdown<ActivityType>(
                        label: 'Activity Type',
                        value: _activityType,
                        items: ActivityType.values,
                        onChanged: (val) => setState(() => _activityType = val!),
                      ),
                      if (_activityType == ActivityType.other)
                        _buildTextField(
                          controller: _customNameController,
                          label: 'Custom Activity Name',
                          hint: 'e.g. Boxing, Rock Climbing',
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      _buildDateTimePicker(),
                       _buildTextField(
                        controller: _durationController,
                        focusNode: _durationFocus,
                        label: 'Duration (minutes)',
                        keyboardType: TextInputType.number,
                        validator: ValidationUtils.validateActivityDuration,
                      ),
                      _buildRpeSlider(),
                      _buildFeelSegmented(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildAdvancedToggle(),
                if (_showAdvanced) ...[
                  const SizedBox(height: 16),
                  _buildGlassCard(
                    child: Column(
                      children: [
                        _buildDropdown<Purpose>(
                          label: 'Primary Purpose',
                          value: _purpose,
                          items: Purpose.values,
                          allowNull: true,
                          onChanged: (val) => setState(() => _purpose = val),
                        ),
                        _buildFatigueSlider(),
                        _buildDropdown<PainSeverity>(
                          label: 'Pain / Injury Severity',
                          value: _painSeverity,
                          items: PainSeverity.values,
                          onChanged: (val) => setState(() => _painSeverity = val!),
                        ),
                        if (_painSeverity != PainSeverity.none)
                          _buildTextField(
                            controller: _painLocationController,
                            label: 'Pain Location',
                            hint: 'e.g. Right Knee',
                          ),
                        _buildDistanceSection(),
                        _buildLoadSection(),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown<IndoorOutdoor>(
                                label: 'Environment',
                                value: _indoorOutdoor,
                                items: IndoorOutdoor.values,
                                allowNull: true,
                                onChanged: (val) => setState(() => _indoorOutdoor = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDropdown<HeatLevel>(
                                label: 'Heat Level',
                                value: _heatLevel,
                                items: HeatLevel.values,
                                allowNull: true,
                                onChanged: (val) => setState(() => _heatLevel = val),
                              ),
                            ),
                          ],
                        ),
                        _buildTextField(
                          controller: _notesController,
                          label: 'Notes',
                          maxLines: 2,
                          maxLength: 200,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Text(
                  'Manual logs affect training load trends but won’t override recovery signals.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
                const SizedBox(height: 16),
                _buildSaveButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
          color: AppTheme.primaryCyan.withOpacity(0.8), 
          fontSize: 12, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 2),
    );
  }

  Widget _buildDropdown<T extends Enum>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
    bool allowNull = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
          DropdownButtonFormField<T>(
            value: value,
            items: [
              if (allowNull) const DropdownMenuItem(value: null, child: Text('None (Select)', style: TextStyle(color: Colors.white54))),
              ...items.map((e) => DropdownMenuItem(value: e, child: Text(_formatEnum(e.name)))),
            ],
            onChanged: onChanged,
            dropdownColor: AppTheme.bgDark,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: const InputDecoration(enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12))),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    FocusNode? focusNode,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
          counterStyle: const TextStyle(color: Colors.white24),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker() {
    final format = DateFormat('MMM dd, yyyy - HH:mm');
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _startTime,
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime.now(),
          );
          if (date != null && mounted) {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(_startTime),
            );
            if (time != null) {
              setState(() {
                _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
              });
            }
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start Time', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: AppTheme.primaryCyan, size: 18),
                const SizedBox(width: 12),
                Text(format.format(_startTime), style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRpeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Intensity (RPE)', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            Text('${_rpe.toInt()} / 10', style: const TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: _rpe,
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: AppTheme.primaryCyan,
          inactiveColor: Colors.white10,
          onChanged: (val) => setState(() => _rpe = val),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Very Easy', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
            Text('Max Effort', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFeelSegmented() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How do you feel now?', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
        const SizedBox(height: 12),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: ['better', 'same', 'worse'].map((feel) {
              final isSelected = _feelAfter == feel;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _feelAfter = feel),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryCyan : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      feel.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white60,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedToggle() {
    return InkWell(
      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _showAdvanced ? 'Hide Details' : 'Add More Details',
            style: const TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold),
          ),
          Icon(
            _showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: AppTheme.primaryCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildFatigueSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Current Fatigue', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            Text('${_fatigue.toInt()} / 5', style: const TextStyle(color: AppTheme.primaryCyan)),
          ],
        ),
        Slider(
          value: _fatigue,
          min: 0,
          max: 5,
          divisions: 5,
          activeColor: AppTheme.primaryCyan,
          onChanged: (val) => setState(() => _fatigue = val),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDistanceSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 2,
          child: _buildTextField(
            controller: _distanceController,
            label: 'Distance',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButton<String>(
              value: _distanceUnit,
              items: ['mi', 'km'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _distanceUnit = v!),
              dropdownColor: AppTheme.bgDark,
              style: const TextStyle(color: Colors.white),
              isExpanded: true,
              underline: Container(height: 1, color: Colors.white12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 2,
          child: _buildTextField(
            controller: _loadController,
            label: 'Load Carried',
            hint: 'e.g. Ruck weight',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButton<String>(
              value: _loadUnit,
              items: ['lb', 'kg'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _loadUnit = v!),
              dropdownColor: AppTheme.bgDark,
              style: const TextStyle(color: Colors.white),
              isExpanded: true,
              underline: Container(height: 1, color: Colors.white12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryCyan,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: AppTheme.primaryCyan.withOpacity(0.5),
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.black)
            : const Text('Save Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _formatEnum(String name) {
    final result = name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}');
    return result[0].toUpperCase() + result.substring(1).toLowerCase();
  }
}
