import 'package:flutter/material.dart';

import '../../../core/constants/spacing.dart';
import '../../../models/shop_ledger.dart';
import '../../../services/shop_ledger_service.dart';

/// 顧客の登録・編集。保存したら、その顧客を返して閉じる。
class CustomerEditScreen extends StatefulWidget {
  final ShopLedgerService service;
  final String shopId;

  /// 編集するときに渡す。null なら新規登録。
  final LedgerCustomer? existing;

  const CustomerEditScreen({
    super.key,
    required this.service,
    required this.shopId,
    this.existing,
  });

  @override
  State<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends State<CustomerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late LedgerCustomerKind _kind =
      widget.existing?.kind ?? LedgerCustomerKind.individual;
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _kana = TextEditingController(text: widget.existing?.nameKana);
  late final _contact =
      TextEditingController(text: widget.existing?.contactPerson);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _postal = TextEditingController(text: widget.existing?.postalCode);
  late final _address = TextEditingController(text: widget.existing?.address);
  late final _note = TextEditingController(text: widget.existing?.note);
  bool _saving = false;
  String? _error;

  bool get _isCorporate => _kind == LedgerCustomerKind.corporate;

  @override
  void dispose() {
    for (final c in [
      _name,
      _kana,
      _contact,
      _phone,
      _email,
      _postal,
      _address,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final existing = widget.existing;
    final result = existing == null
        ? await widget.service.createCustomer(
            shopId: widget.shopId,
            kind: _kind,
            name: _name.text,
            nameKana: _kana.text,
            contactPerson: _isCorporate ? _contact.text : null,
            phone: _phone.text,
            email: _email.text,
            postalCode: _postal.text,
            address: _address.text,
            note: _note.text,
          )
        : await widget.service.updateCustomer(
            shopId: widget.shopId,
            customer: existing.copyWith(
              kind: _kind,
              name: _name.text,
              nameKana: _kana.text,
              contactPerson: _isCorporate ? _contact.text : '',
              phone: _phone.text,
              email: _email.text,
              postalCode: _postal.text,
              address: _address.text,
              note: _note.text,
            ),
          );

    if (!mounted) return;
    result.when(
      success: (customer) => Navigator.pop(context, customer),
      failure: (error) => setState(() {
        _error = error.userMessage;
        _saving = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? '顧客を追加' : '顧客を編集')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.paddingScreen,
          children: [
            SegmentedButton<LedgerCustomerKind>(
              segments: [
                for (final k in LedgerCustomerKind.values)
                  ButtonSegment(value: k, label: Text(k.label)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            AppSpacing.verticalMd,
            TextFormField(
              key: const Key('customer_name'),
              controller: _name,
              decoration: InputDecoration(
                labelText: _isCorporate ? '会社名 *' : 'お名前 *',
                border: const OutlineInputBorder(),
              ),
              validator: ShopLedgerService.validateName,
            ),
            AppSpacing.verticalMd,
            TextFormField(
              key: const Key('customer_kana'),
              controller: _kana,
              decoration: const InputDecoration(
                labelText: 'フリガナ',
                helperText: '検索はフリガナの先頭から引きます',
                border: OutlineInputBorder(),
              ),
            ),
            if (_isCorporate) ...[
              AppSpacing.verticalMd,
              TextFormField(
                controller: _contact,
                decoration: const InputDecoration(
                  labelText: 'ご担当者',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            AppSpacing.verticalMd,
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '電話番号',
                border: OutlineInputBorder(),
              ),
            ),
            AppSpacing.verticalMd,
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
            ),
            AppSpacing.verticalMd,
            TextFormField(
              controller: _postal,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '郵便番号',
                border: OutlineInputBorder(),
              ),
            ),
            AppSpacing.verticalMd,
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: '住所',
                border: OutlineInputBorder(),
              ),
            ),
            AppSpacing.verticalMd,
            TextFormField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'メモ',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              AppSpacing.verticalMd,
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            AppSpacing.verticalLg,
            FilledButton(
              key: const Key('customer_save'),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.tapTargetMin),
              ),
              child: Text(_saving ? '保存しています…' : '保存する'),
            ),
          ],
        ),
      ),
    );
  }
}
