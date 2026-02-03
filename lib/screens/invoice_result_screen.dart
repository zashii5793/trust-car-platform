import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/maintenance_record.dart';
import '../services/invoice_ocr_service.dart';
import '../core/constants/colors.dart';

/// 請求書OCR結果確認・編集画面
class InvoiceResultScreen extends StatefulWidget {
  final File imageFile;
  final InvoiceData ocrData;

  const InvoiceResultScreen({
    super.key,
    required this.imageFile,
    required this.ocrData,
  });

  @override
  State<InvoiceResultScreen> createState() => _InvoiceResultScreenState();
}

class _InvoiceResultScreenState extends State<InvoiceResultScreen> {
  late DateTime? _date;
  late TextEditingController _amountController;
  late TextEditingController _shopNameController;
  late TextEditingController _mileageController;
  late TextEditingController _descriptionController;
  MaintenanceType? _selectedType;
  bool _showImage = false;

  final _currencyFormat = NumberFormat('#,###', 'ja_JP');

  @override
  void initState() {
    super.initState();
    final data = widget.ocrData;

    _date = data.date;
    _amountController = TextEditingController(
      text: data.totalAmount?.toString() ?? '',
    );
    _shopNameController = TextEditingController(text: data.shopName ?? '');
    _mileageController = TextEditingController(
      text: data.mileage?.toString() ?? '',
    );

    // 明細から説明文を生成
    final description = data.items.map((i) => i.name).join('、');
    _descriptionController = TextEditingController(text: description);

    _selectedType = data.estimatedMaintenanceType ?? MaintenanceType.other;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _shopNameController.dispose();
    _mileageController.dispose();
    _descriptionController.dispose();
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
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 信頼度スコア
          _buildConfidenceCard(theme),
          const SizedBox(height: 16),

          // 整備タイプ選択
          _buildSectionHeader(theme, '整備タイプ', Icons.build),
          const SizedBox(height: 8),
          _buildMaintenanceTypeSelector(theme),
          const SizedBox(height: 24),

          // 基本情報
          _buildSectionHeader(theme, '基本情報', Icons.info_outline),
          const SizedBox(height: 8),
          _buildDateTile(theme),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _amountController,
            label: '金額 (円)',
            icon: Icons.payments,
            keyboardType: TextInputType.number,
            isExtracted: widget.ocrData.totalAmount != null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _mileageController,
            label: '走行距離 (km)',
            icon: Icons.speed,
            keyboardType: TextInputType.number,
            isExtracted: widget.ocrData.mileage != null,
          ),
          const SizedBox(height: 24),

          // 店舗情報
          _buildSectionHeader(theme, '店舗情報', Icons.store),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _shopNameController,
            label: '店舗名/整備工場',
            icon: Icons.business,
            isExtracted: widget.ocrData.shopName != null,
          ),
          const SizedBox(height: 24),

          // 明細
          if (widget.ocrData.items.isNotEmpty) ...[
            _buildSectionHeader(theme, '明細項目', Icons.list),
            const SizedBox(height: 8),
            _buildItemsList(theme),
            const SizedBox(height: 24),
          ],

          // 説明
          _buildSectionHeader(theme, '説明', Icons.description),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '作業内容の詳細',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: widget.ocrData.items.isNotEmpty
                  ? Colors.amber.withValues(alpha: 0.05)
                  : null,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildConfidenceCard(ThemeData theme) {
    final score = widget.ocrData.confidenceScore;
    final percentage = (score * 100).toInt();

    Color color;
    String message;
    IconData icon;

    if (score >= 0.5) {
      color = Colors.green;
      message = '多くの項目を読み取れました';
      icon = Icons.check_circle;
    } else if (score >= 0.3) {
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

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceTypeSelector(ThemeData theme) {
    // よく使うタイプを先頭に
    final frequentTypes = [
      MaintenanceType.oilChange,
      MaintenanceType.carInspection,
      MaintenanceType.legalInspection12,
      MaintenanceType.tireChange,
      MaintenanceType.repair,
      MaintenanceType.other,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: frequentTypes.map((type) {
        final isSelected = _selectedType == type;
        return ChoiceChip(
          avatar: Icon(
            type.icon,
            size: 18,
            color: isSelected ? Colors.white : type.color,
          ),
          label: Text(type.displayName),
          selected: isSelected,
          selectedColor: type.color,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : null,
          ),
          onSelected: (selected) {
            setState(() {
              _selectedType = selected ? type : null;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildDateTile(ThemeData theme) {
    final hasDate = _date != null;
    final isExtracted = widget.ocrData.date != null;

    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasDate ? Colors.grey[300]! : Colors.orange,
            width: hasDate ? 1 : 2,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isExtracted ? Colors.amber.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.event,
              color: hasDate ? theme.colorScheme.primary : Colors.orange,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '作業日',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasDate
                        ? DateFormat('yyyy年M月d日').format(_date!)
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

  Widget _buildItemsList(ThemeData theme) {
    return Card(
      child: Column(
        children: widget.ocrData.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == widget.ocrData.items.length - 1;

          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(item.name),
                trailing: item.amount != null
                    ? Text(
                        '¥${_currencyFormat.format(item.amount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: '作業日を選択',
    );

    if (picked != null) {
      setState(() {
        _date = picked;
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
                label: const Text('整備記録を登録'),
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
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('整備タイプを選択してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('作業日を設定してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 結果を返す
    final result = MaintenanceRegistrationData(
      type: _selectedType!,
      date: _date!,
      cost: int.tryParse(_amountController.text.replaceAll(',', '')),
      mileage: int.tryParse(_mileageController.text.replaceAll(',', '')),
      shopName: _shopNameController.text.isNotEmpty
          ? _shopNameController.text
          : null,
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
      items: widget.ocrData.items,
    );

    Navigator.of(context).pop(result);
  }
}

/// 整備記録登録用データクラス
class MaintenanceRegistrationData {
  final MaintenanceType type;
  final DateTime date;
  final int? cost;
  final int? mileage;
  final String? shopName;
  final String? description;
  final List<InvoiceItem> items;

  MaintenanceRegistrationData({
    required this.type,
    required this.date,
    this.cost,
    this.mileage,
    this.shopName,
    this.description,
    this.items = const [],
  });
}
