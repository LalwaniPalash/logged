import 'package:flutter/material.dart';

class ExercisePrescriptionValues {
  const ExercisePrescriptionValues({
    this.targetSets,
    this.sidesPerSet,
    this.minReps,
    this.maxReps,
    this.targetDurationSec,
    this.targetDistanceMeters,
    this.restSeconds,
    this.eccentricSec,
    this.bottomPauseSec,
    this.concentricSec,
    this.topPauseSec,
    this.prescriptionNotes,
    this.formUrl,
  });

  final int? targetSets;
  final int? sidesPerSet;
  final int? minReps;
  final int? maxReps;
  final int? targetDurationSec;
  final double? targetDistanceMeters;
  final int? restSeconds;
  final int? eccentricSec;
  final int? bottomPauseSec;
  final int? concentricSec;
  final int? topPauseSec;
  final String? prescriptionNotes;
  final String? formUrl;
}

String formatPrescription({
  int? targetSets,
  int? sidesPerSet,
  int? minReps,
  int? maxReps,
  int? targetDurationSec,
  double? targetDistanceMeters,
  int? restSeconds,
  int? eccentricSec,
  int? bottomPauseSec,
  int? concentricSec,
  int? topPauseSec,
}) {
  final parts = <String>[];
  final eachSide = sidesPerSet != null && sidesPerSet > 1;
  if (targetSets != null) {
    parts.add('$targetSets ${targetSets == 1 ? 'set' : 'sets'}');
  }
  if (minReps != null || maxReps != null) {
    if (minReps != null && maxReps != null && minReps != maxReps) {
      parts.add('$minReps–$maxReps reps${eachSide ? ' each side' : ''}');
    } else {
      parts.add('${minReps ?? maxReps} reps${eachSide ? ' each side' : ''}');
    }
  }
  if (targetDurationSec != null) {
    parts.add(
      '${_formatPrescriptionDuration(targetDurationSec)}${eachSide ? ' each side' : ''}',
    );
  }
  if (targetDistanceMeters != null) {
    parts.add(
      '${_formatPrescriptionDistance(targetDistanceMeters)}${eachSide ? ' each side' : ''}',
    );
  }
  if (eccentricSec != null ||
      bottomPauseSec != null ||
      concentricSec != null ||
      topPauseSec != null) {
    parts.add(
      'Tempo ${eccentricSec ?? 0}-${bottomPauseSec ?? 0}-${concentricSec ?? 0}-${topPauseSec ?? 0}',
    );
  }
  if (restSeconds != null) {
    parts.add('${_formatPrescriptionDuration(restSeconds)} rest');
  }
  return parts.join(' · ');
}

class PrescriptionEditorSheet extends StatefulWidget {
  const PrescriptionEditorSheet({
    super.key,
    required this.exerciseName,
    required this.initialValues,
    this.saveLabel = 'Save',
  });

  final String exerciseName;
  final ExercisePrescriptionValues initialValues;
  final String saveLabel;

  @override
  State<PrescriptionEditorSheet> createState() =>
      _PrescriptionEditorSheetState();
}

class _PrescriptionEditorSheetState extends State<PrescriptionEditorSheet> {
  late final TextEditingController _sets = TextEditingController(
    text: widget.initialValues.targetSets?.toString() ?? '',
  );
  late bool _eachSide = widget.initialValues.sidesPerSet == 2;
  late final TextEditingController _minReps = TextEditingController(
    text: widget.initialValues.minReps?.toString() ?? '',
  );
  late final TextEditingController _maxReps = TextEditingController(
    text: widget.initialValues.maxReps?.toString() ?? '',
  );
  late final TextEditingController _duration = TextEditingController(
    text: widget.initialValues.targetDurationSec?.toString() ?? '',
  );
  late final TextEditingController _distance = TextEditingController(
    text: widget.initialValues.targetDistanceMeters?.toString() ?? '',
  );
  late final TextEditingController _rest = TextEditingController(
    text: widget.initialValues.restSeconds?.toString() ?? '',
  );
  late final TextEditingController _eccentric = TextEditingController(
    text: widget.initialValues.eccentricSec?.toString() ?? '',
  );
  late final TextEditingController _bottomPause = TextEditingController(
    text: widget.initialValues.bottomPauseSec?.toString() ?? '',
  );
  late final TextEditingController _concentric = TextEditingController(
    text: widget.initialValues.concentricSec?.toString() ?? '',
  );
  late final TextEditingController _topPause = TextEditingController(
    text: widget.initialValues.topPauseSec?.toString() ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.initialValues.prescriptionNotes ?? '',
  );
  late final TextEditingController _formUrl = TextEditingController(
    text: widget.initialValues.formUrl ?? '',
  );

  @override
  void dispose() {
    _sets.dispose();
    _minReps.dispose();
    _maxReps.dispose();
    _duration.dispose();
    _distance.dispose();
    _rest.dispose();
    _eccentric.dispose();
    _bottomPause.dispose();
    _concentric.dispose();
    _topPause.dispose();
    _notes.dispose();
    _formUrl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      ExercisePrescriptionValues(
        targetSets: _intOrNull(_sets.text),
        sidesPerSet: _eachSide ? 2 : null,
        minReps: _intOrNull(_minReps.text),
        maxReps: _intOrNull(_maxReps.text),
        targetDurationSec: _intOrNull(_duration.text),
        targetDistanceMeters: _doubleOrNull(_distance.text),
        restSeconds: _intOrNull(_rest.text),
        eccentricSec: _intOrNull(_eccentric.text),
        bottomPauseSec: _intOrNull(_bottomPause.text),
        concentricSec: _intOrNull(_concentric.text),
        topPauseSec: _intOrNull(_topPause.text),
        prescriptionNotes: _blankToNull(_notes.text),
        formUrl: _blankToNull(_formUrl.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: ListView(
        shrinkWrap: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(
            widget.exerciseName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _field(_sets, 'Sets')),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('Each side'),
                selected: _eachSide,
                onSelected: (value) => setState(() => _eachSide = value),
              ),
              const SizedBox(width: 10),
              Expanded(child: _field(_minReps, 'Min reps')),
              const SizedBox(width: 10),
              Expanded(child: _field(_maxReps, 'Max reps')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_duration, 'Duration sec')),
              const SizedBox(width: 10),
              Expanded(child: _field(_rest, 'Rest sec')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_eccentric, 'Eccentric')),
              const SizedBox(width: 10),
              Expanded(child: _field(_bottomPause, 'Bottom pause')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_concentric, 'Concentric')),
              const SizedBox(width: 10),
              Expanded(child: _field(_topPause, 'Top pause')),
            ],
          ),
          const SizedBox(height: 10),
          _field(_distance, 'Distance meters'),
          const SizedBox(height: 10),
          _field(
            _formUrl,
            'YouTube / form URL',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes / cues'),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(widget.saveLabel)),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.number,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
  );

  int? _intOrNull(String value) => int.tryParse(value.trim());
  double? _doubleOrNull(String value) => double.tryParse(value.trim());

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

String _formatPrescriptionDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  if (minutes <= 0) return '${seconds}s';
  return remaining == 0 ? '${minutes}m' : '${minutes}m ${remaining}s';
}

String _formatPrescriptionDistance(double meters) {
  if (meters >= 1000) return '${_trimPrescription(meters / 1000)} km';
  return '${_trimPrescription(meters)} m';
}

String _trimPrescription(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
