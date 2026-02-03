import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/vehicle.dart';
import '../services/vehicle_certificate_ocr_service.dart';
import '../core/constants/colors.dart';

/// 車検証OCR結果確認・編集画面
class VehicleCertificateResultScreen extends StatefulWidget {
  final File imageFile;
  final VehicleCertificateData ocrData;

  const VehicleCertificateResultScreen({
    super.key,
    required this.imageFile,
    required this.ocrData,
  });

  @override
  State<VehicleCertificateResultScreen> createState() =>
      _VehicleCertificateResultScreenState();
}

class _VehicleCertificateResultScreenState
    extends State<VehicleCertificateResultScreen> {
  late TextEditingController _makerController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _licensePlateController;
  late TextEditingController _vinNumberController;
  late TextEditingController _modelCodeController;
  late TextEditingController _engineDisplacementController;
  late TextEditingController _colorController;
  DateTime? _inspectionExpiryDate;
  FuelType? _selectedFuelType;

  bool _showImage = false;

  @override
  void initState() {
    super.initState();
    final data = widget.ocrData;

    _makerController = TextEditingController(text: data.maker ?? '');
    _modelController = TextEditingController(text: data.model ?? '');
    _yearController = TextEditingController(text: data.year?.toString() ?? '');
    _licensePlateController =
        TextEditingController(text: data.registrationNumber ?? '');
    _vinNumberController = TextEditingController(text: data.vinNumber ?? '');
    _modelCodeController = TextEditingController(text: data.modelCode ?? '');
    _engineDisplacementController =
        TextEditingController(text: data.engineDisplacement?.toString() ?? '');
    _colorController = TextEditingController(text: data.color ?? '');
    _inspectionExpiryDate = data.inspectionExpiryDate;
    _selectedFuelType = data.fuelTypeEnum;
  }

  @override
  void dispose() {
    _makerController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _licensePlateController.dispose();
    _vinNumberController.dispose();
    _modelCodeController.dispose();
    _engineDisplacementController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('読み取り結果の確認'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showImage = !_showImage),
            icon: Icon(_showImage ? Icons.edit_note : Icons.image),
            tooltip: _showImage ? 'フォームを表示' : '画像を表示',
          ),
        ],
      ),
      body: _showImage ? _buildImageView() : _buildFormView(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildImageView() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.file(
        widget.imageFile,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 信頼度スコア表示
          _buildConfidenceCard(),
          const SizedBox(height: 16),

          // 基本情報セクション
          _buildSectionHeader('基本情報', Icons.directions_car),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _makerController,
            label: 'メーカー',
            icon: Icons.business,
            isExtracted: widget.ocrData.maker != null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _modelController,
            label: '車種',
            icon: Icons.directions_car,
            isExtracted: widget.ocrData.model != null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _yearController,
            label: '年式',
            icon: Icons.calendar_today,
            keyboardType: TextInputType.number,
            isExtracted: widget.ocrData.year != null,
          ),
          const SizedBox(height: 24),

          // 識別情報セクション
          _buildSectionHeader('識別情報', Icons.badge),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _licensePlateController,
            label: 'ナンバープレート',
            icon: Icons.pin,
            isExtracted: widget.ocrData.registrationNumber != null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _vinNumberController,
            label: '車台番号',
            icon: Icons.tag,
            isExtracted: widget.ocrData.vinNumber != null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _modelCodeController,
            label: '型式',
            icon: Icons.code,
            isExtracted: widget.ocrData.modelCode != null,
          ),
          const SizedBox(height: 24),

          // 車検情報セクション（重要）
          _buildSectionHeader('車検・保険', Icons.verified, isImportant: true),
          const SizedBox(height: 8),
          _buildInspectionDateTile(),
          const SizedBox(height: 24),

          // 詳細情報セクション
          _buildSectionHeader('詳細情報', Icons.info_outline),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _engineDisplacementController,
            label: '排気量 (cc)',
            icon: Icons.speed,
            keyboardType: TextInputType.number,
            isExtracted: widget.ocrData.engineDisplacement != null,
          ),
          const SizedBox(height: 12),
          _buildFuelTypeSelector(),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _colorController,
            label: '車体色',
            icon: Icons.palette,
            isExtracted: widget.ocrData.color != null,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildConfidenceCard() {
    final score = widget.ocrData.confidenceScore;
    final percentage = (score * 100).toInt();

    Color color;
    String message;
    IconData icon;

    if (score >= 0.7) {
      color = Colors.green;
      message = '多くの項目を読み取れました';
      icon = Icons.check_circle;
    } else if (score >= 0.4) {
      color = Colors.orange;
      message = '一部の項目を読み取れました';
      icon = Icons.info;
    } else {
      color = Colors.red;
      message = '読み取りが難しい箇所があります';
      icon = Icons.warning;
    }

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '読み取り精度: $percentage%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showImage = true),
              child: const Text('画像を確認'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon,
      {bool isImportant = false}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isImportant ? Colors.orange : Colors.grey),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isImportant ? Colors.orange[800] : null,
          ),
        ),
        if (isImportant) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '重要',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isExtracted = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: isExtracted
            ? const Tooltip(
                message: 'OCRで読み取り済み',
                child: Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              )
            : null,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: isExtracted ? Colors.amber.withValues(alpha: 0.05) : null,
      ),
    );
  }

  Widget _buildInspectionDateTile() {
    final hasDate = _inspectionExpiryDate != null;
    final isExtracted = widget.ocrData.inspectionExpiryDate != null;

    return InkWell(
      onTap: _selectInspectionDate,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasDate ? Colors.green : Colors.orange,
            width: hasDate ? 1 : 2,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isExtracted ? Colors.amber.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.event,
              color: hasDate ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '車検満了日',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasDate
                        ? DateFormat('yyyy年M月d日').format(_inspectionExpiryDate!)
                        : '未設定（タップして設定）',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasDate ? null : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            if (isExtracted)
              const Tooltip(
                message: 'OCRで読み取り済み',
                child: Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelTypeSelector() {
    final isExtracted = widget.ocrData.fuelTypeEnum != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '燃料タイプ',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (isExtracted) ...[
              const SizedBox(width: 8),
              const Tooltip(
                message: 'OCRで読み取り済み',
                child: Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FuelType.values.map((type) {
            final isSelected = _selectedFuelType == type;
            return ChoiceChip(
              label: Text(type.displayName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFuelType = selected ? type : null;
                });
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _selectInspectionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectionExpiryDate ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      helpText: '車検満了日を選択',
    );

    if (picked != null) {
      setState(() {
        _inspectionExpiryDate = picked;
      });
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _validateAndSubmit,
                icon: const Icon(Icons.check),
                label: const Text('この内容で登録'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _validateAndSubmit() {
    // バリデーション
    if (_makerController.text.isEmpty && _modelController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メーカーまたは車種を入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 結果を返す
    final result = VehicleRegistrationData(
      maker: _makerController.text,
      model: _modelController.text,
      year: int.tryParse(_yearController.text),
      licensePlate: _licensePlateController.text.isNotEmpty
          ? _licensePlateController.text
          : null,
      vinNumber:
          _vinNumberController.text.isNotEmpty ? _vinNumberController.text : null,
      modelCode:
          _modelCodeController.text.isNotEmpty ? _modelCodeController.text : null,
      inspectionExpiryDate: _inspectionExpiryDate,
      engineDisplacement: int.tryParse(_engineDisplacementController.text),
      fuelType: _selectedFuelType,
      color: _colorController.text.isNotEmpty ? _colorController.text : null,
    );

    Navigator.of(context).pop(result);
  }
}

/// 車両登録用データクラス
class VehicleRegistrationData {
  final String maker;
  final String model;
  final int? year;
  final String? licensePlate;
  final String? vinNumber;
  final String? modelCode;
  final DateTime? inspectionExpiryDate;
  final int? engineDisplacement;
  final FuelType? fuelType;
  final String? color;

  VehicleRegistrationData({
    required this.maker,
    required this.model,
    this.year,
    this.licensePlate,
    this.vinNumber,
    this.modelCode,
    this.inspectionExpiryDate,
    this.engineDisplacement,
    this.fuelType,
    this.color,
  });
}
