import 'package:flutter/material.dart';
import '../../models/vehicle_master.dart';
import '../../services/vehicle_master_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';

/// Searchable dropdown for selecting vehicle maker
class MakerSelectorField extends StatefulWidget {
  final VehicleMaker? selectedMaker;
  final ValueChanged<VehicleMaker?> onChanged;
  final String? Function(VehicleMaker?)? validator;
  final bool enabled;

  const MakerSelectorField({
    super.key,
    this.selectedMaker,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  State<MakerSelectorField> createState() => _MakerSelectorFieldState();
}

class _MakerSelectorFieldState extends State<MakerSelectorField> {
  List<VehicleMaker> _makers = [];
  bool _isLoading = true;

  VehicleMasterService get _masterService => sl.get<VehicleMasterService>();

  @override
  void initState() {
    super.initState();
    _loadMakers();
  }

  Future<void> _loadMakers() async {
    final result = await _masterService.getMakers();
    result.when(
      success: (makers) {
        if (mounted) {
          setState(() {
            _makers = makers;
            _isLoading = false;
          });
        }
      },
      failure: (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return _buildLoadingField(context, 'メーカー *');
    }

    return FormField<VehicleMaker>(
      initialValue: widget.selectedMaker,
      validator: widget.validator,
      builder: (FormFieldState<VehicleMaker> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.enabled ? () => _showMakerPicker(context, state) : null,
              borderRadius: AppSpacing.borderRadiusSm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: AppSpacing.borderRadiusSm,
                  border: Border.all(
                    color: state.hasError
                        ? theme.colorScheme.error
                        : (isDark ? AppColors.darkTextTertiary : AppColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.business,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    AppSpacing.horizontalMd,
                    Expanded(
                      child: Text(
                        widget.selectedMaker?.name ?? 'メーカーを選択 *',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: widget.selectedMaker == null
                              ? (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)
                              : null,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: Text(
                  state.errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showMakerPicker(BuildContext context, FormFieldState<VehicleMaker> state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MakerPickerSheet(
        makers: _makers,
        selectedMaker: widget.selectedMaker,
        onSelected: (maker) {
          widget.onChanged(maker);
          state.didChange(maker);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildLoadingField(BuildContext context, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(
          color: isDark ? AppColors.darkTextTertiary : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          AppSpacing.horizontalMd,
          Text(
            '読み込み中...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MakerPickerSheet extends StatefulWidget {
  final List<VehicleMaker> makers;
  final VehicleMaker? selectedMaker;
  final ValueChanged<VehicleMaker> onSelected;

  const _MakerPickerSheet({
    required this.makers,
    this.selectedMaker,
    required this.onSelected,
  });

  @override
  State<_MakerPickerSheet> createState() => _MakerPickerSheetState();
}

class _MakerPickerSheetState extends State<_MakerPickerSheet> {
  final _searchController = TextEditingController();
  List<VehicleMaker> _filteredMakers = [];

  @override
  void initState() {
    super.initState();
    _filteredMakers = widget.makers;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMakers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMakers = widget.makers;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredMakers = widget.makers.where((maker) =>
          maker.name.toLowerCase().contains(lowerQuery) ||
          maker.nameEn.toLowerCase().contains(lowerQuery)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AppSpacing.verticalMd,
                  Text(
                    'メーカーを選択',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.verticalMd,
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '検索...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: _filterMakers,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filteredMakers.length,
                itemBuilder: (context, index) {
                  final maker = _filteredMakers[index];
                  final isSelected = widget.selectedMaker?.id == maker.id;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? theme.colorScheme.primary
                          : Colors.grey[200],
                      child: Text(
                        maker.name.substring(0, 1),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(maker.name),
                    subtitle: Text(maker.nameEn),
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () => widget.onSelected(maker),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Searchable dropdown for selecting vehicle model
class ModelSelectorField extends StatefulWidget {
  final String? makerId;
  final VehicleModel? selectedModel;
  final ValueChanged<VehicleModel?> onChanged;
  final String? Function(VehicleModel?)? validator;
  final bool enabled;

  const ModelSelectorField({
    super.key,
    this.makerId,
    this.selectedModel,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  State<ModelSelectorField> createState() => _ModelSelectorFieldState();
}

class _ModelSelectorFieldState extends State<ModelSelectorField> {
  List<VehicleModel> _models = [];
  bool _isLoading = false;

  VehicleMasterService get _masterService => sl.get<VehicleMasterService>();

  @override
  void didUpdateWidget(ModelSelectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.makerId != oldWidget.makerId) {
      _loadModels();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.makerId != null) {
      _loadModels();
    }
  }

  Future<void> _loadModels() async {
    if (widget.makerId == null) {
      setState(() {
        _models = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _masterService.getModelsForMaker(widget.makerId!);
    result.when(
      success: (models) {
        if (mounted) {
          setState(() {
            _models = models;
            _isLoading = false;
          });
        }
      },
      failure: (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDisabled = !widget.enabled || widget.makerId == null;

    if (_isLoading) {
      return _buildLoadingField(context);
    }

    return FormField<VehicleModel>(
      initialValue: widget.selectedModel,
      validator: widget.validator,
      builder: (FormFieldState<VehicleModel> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: isDisabled ? null : () => _showModelPicker(context, state),
              borderRadius: AppSpacing.borderRadiusSm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? (isDark ? AppColors.darkCard.withValues(alpha: 0.5) : Colors.grey[100])
                      : (isDark ? AppColors.darkCard : Colors.white),
                  borderRadius: AppSpacing.borderRadiusSm,
                  border: Border.all(
                    color: state.hasError
                        ? theme.colorScheme.error
                        : (isDark ? AppColors.darkTextTertiary : AppColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_car,
                      color: isDisabled
                          ? Colors.grey
                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                    AppSpacing.horizontalMd,
                    Expanded(
                      child: Text(
                        widget.selectedModel?.name ?? (widget.makerId == null ? 'メーカーを先に選択' : '車種を選択 *'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: widget.selectedModel == null || isDisabled
                              ? (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)
                              : null,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: isDisabled
                          ? Colors.grey
                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: Text(
                  state.errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showModelPicker(BuildContext context, FormFieldState<VehicleModel> state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ModelPickerSheet(
        models: _models,
        selectedModel: widget.selectedModel,
        onSelected: (model) {
          widget.onChanged(model);
          state.didChange(model);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildLoadingField(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(
          color: isDark ? AppColors.darkTextTertiary : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          AppSpacing.horizontalMd,
          Text(
            '読み込み中...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelPickerSheet extends StatefulWidget {
  final List<VehicleModel> models;
  final VehicleModel? selectedModel;
  final ValueChanged<VehicleModel> onSelected;

  const _ModelPickerSheet({
    required this.models,
    this.selectedModel,
    required this.onSelected,
  });

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  final _searchController = TextEditingController();
  List<VehicleModel> _filteredModels = [];

  @override
  void initState() {
    super.initState();
    _filteredModels = widget.models;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterModels(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredModels = widget.models;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredModels = widget.models.where((model) =>
          model.name.toLowerCase().contains(lowerQuery) ||
          (model.nameEn?.toLowerCase().contains(lowerQuery) ?? false)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AppSpacing.verticalMd,
                  Text(
                    '車種を選択',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.verticalMd,
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '検索...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: _filterModels,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filteredModels.length,
                itemBuilder: (context, index) {
                  final model = _filteredModels[index];
                  final isSelected = widget.selectedModel?.id == model.id;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? theme.colorScheme.primary
                          : Colors.grey[200],
                      child: Icon(
                        _getBodyTypeIcon(model.bodyType),
                        color: isSelected ? Colors.white : Colors.black54,
                        size: 20,
                      ),
                    ),
                    title: Text(model.name),
                    subtitle: model.bodyType != null
                        ? Text(model.bodyType!.displayName)
                        : null,
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () => widget.onSelected(model),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getBodyTypeIcon(BodyType? bodyType) {
    switch (bodyType) {
      case BodyType.sedan:
        return Icons.directions_car;
      case BodyType.suv:
        return Icons.directions_car_filled;
      case BodyType.minivan:
        return Icons.airport_shuttle;
      case BodyType.wagon:
        return Icons.directions_car;
      case BodyType.hatchback:
        return Icons.directions_car;
      case BodyType.coupe:
        return Icons.sports_motorsports;
      case BodyType.convertible:
        return Icons.directions_car;
      case BodyType.kei:
        return Icons.electric_car;
      case BodyType.truck:
        return Icons.local_shipping;
      case BodyType.van:
        return Icons.airport_shuttle;
      default:
        return Icons.directions_car;
    }
  }
}

/// Searchable dropdown for selecting vehicle grade
class GradeSelectorField extends StatefulWidget {
  final String? modelId;
  final VehicleGrade? selectedGrade;
  final ValueChanged<VehicleGrade?> onChanged;
  final String? Function(VehicleGrade?)? validator;
  final bool enabled;
  final bool allowCustom;

  const GradeSelectorField({
    super.key,
    this.modelId,
    this.selectedGrade,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.allowCustom = true,
  });

  @override
  State<GradeSelectorField> createState() => _GradeSelectorFieldState();
}

class _GradeSelectorFieldState extends State<GradeSelectorField> {
  List<VehicleGrade> _grades = [];
  bool _isLoading = false;
  final _customGradeController = TextEditingController();

  VehicleMasterService get _masterService => sl.get<VehicleMasterService>();

  @override
  void didUpdateWidget(GradeSelectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.modelId != oldWidget.modelId) {
      _loadGrades();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.modelId != null) {
      _loadGrades();
    }
  }

  @override
  void dispose() {
    _customGradeController.dispose();
    super.dispose();
  }

  Future<void> _loadGrades() async {
    if (widget.modelId == null) {
      setState(() {
        _grades = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _masterService.getGradesForModel(widget.modelId!);
    result.when(
      success: (grades) {
        if (mounted) {
          setState(() {
            _grades = grades;
            _isLoading = false;
          });
        }
      },
      failure: (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDisabled = !widget.enabled || widget.modelId == null;

    if (_isLoading) {
      return _buildLoadingField(context);
    }

    return FormField<VehicleGrade>(
      initialValue: widget.selectedGrade,
      validator: widget.validator,
      builder: (FormFieldState<VehicleGrade> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: isDisabled ? null : () => _showGradePicker(context, state),
              borderRadius: AppSpacing.borderRadiusSm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? (isDark ? AppColors.darkCard.withValues(alpha: 0.5) : Colors.grey[100])
                      : (isDark ? AppColors.darkCard : Colors.white),
                  borderRadius: AppSpacing.borderRadiusSm,
                  border: Border.all(
                    color: state.hasError
                        ? theme.colorScheme.error
                        : (isDark ? AppColors.darkTextTertiary : AppColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star_outline,
                      color: isDisabled
                          ? Colors.grey
                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                    AppSpacing.horizontalMd,
                    Expanded(
                      child: Text(
                        widget.selectedGrade?.name ?? (widget.modelId == null ? '車種を先に選択' : 'グレードを選択 *'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: widget.selectedGrade == null || isDisabled
                              ? (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)
                              : null,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: isDisabled
                          ? Colors.grey
                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: Text(
                  state.errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showGradePicker(BuildContext context, FormFieldState<VehicleGrade> state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _GradePickerSheet(
        grades: _grades,
        selectedGrade: widget.selectedGrade,
        allowCustom: widget.allowCustom,
        modelId: widget.modelId!,
        onSelected: (grade) {
          widget.onChanged(grade);
          state.didChange(grade);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildLoadingField(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(
          color: isDark ? AppColors.darkTextTertiary : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          AppSpacing.horizontalMd,
          Text(
            '読み込み中...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradePickerSheet extends StatefulWidget {
  final List<VehicleGrade> grades;
  final VehicleGrade? selectedGrade;
  final bool allowCustom;
  final String modelId;
  final ValueChanged<VehicleGrade> onSelected;

  const _GradePickerSheet({
    required this.grades,
    this.selectedGrade,
    required this.allowCustom,
    required this.modelId,
    required this.onSelected,
  });

  @override
  State<_GradePickerSheet> createState() => _GradePickerSheetState();
}

class _GradePickerSheetState extends State<_GradePickerSheet> {
  final _customController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AppSpacing.verticalMd,
                  Text(
                    'グレードを選択',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (_showCustomInput)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customController,
                        decoration: InputDecoration(
                          hintText: 'グレード名を入力',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        autofocus: true,
                      ),
                    ),
                    AppSpacing.horizontalSm,
                    ElevatedButton(
                      onPressed: () {
                        if (_customController.text.isNotEmpty) {
                          final customGrade = VehicleGrade(
                            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                            modelId: widget.modelId,
                            name: _customController.text,
                          );
                          widget.onSelected(customGrade);
                        }
                      },
                      child: const Text('決定'),
                    ),
                  ],
                ),
              ),
            AppSpacing.verticalSm,
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: widget.grades.length + (widget.allowCustom ? 1 : 0),
                itemBuilder: (context, index) {
                  if (widget.allowCustom && index == widget.grades.length) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: const Icon(Icons.edit, color: Colors.black54),
                      ),
                      title: const Text('カスタム入力'),
                      subtitle: const Text('一覧にないグレードを入力'),
                      onTap: () {
                        setState(() {
                          _showCustomInput = !_showCustomInput;
                        });
                      },
                    );
                  }

                  final grade = widget.grades[index];
                  final isSelected = widget.selectedGrade?.id == grade.id;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? theme.colorScheme.primary
                          : Colors.grey[200],
                      child: Text(
                        grade.name.substring(0, 1),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(grade.name),
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () => widget.onSelected(grade),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
