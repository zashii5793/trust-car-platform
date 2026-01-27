import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// アプリケーション全体で使用するテキストフィールドウィジェット
/// DESIGN_SYSTEM.md に準拠
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final void Function()? onTap;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final FocusNode? focusNode;
  final bool autofocus;

  const AppTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.focusNode,
    this.autofocus = false,
  });

  /// 数値入力用テキストフィールド
  factory AppTextField.number({
    Key? key,
    TextEditingController? controller,
    String? labelText,
    String? hintText,
    String? errorText,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    Widget? prefixIcon,
    String? prefixText,
    String? suffixText,
    bool enabled = true,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      errorText: errorText,
      validator: validator,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      prefixIcon: prefixIcon,
      prefixText: prefixText,
      suffixText: suffixText,
      enabled: enabled,
    );
  }

  /// メールアドレス入力用テキストフィールド
  factory AppTextField.email({
    Key? key,
    TextEditingController? controller,
    String? labelText,
    String? hintText,
    String? errorText,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool enabled = true,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      labelText: labelText ?? 'メールアドレス',
      hintText: hintText ?? 'example@email.com',
      errorText: errorText,
      validator: validator,
      onChanged: onChanged,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      prefixIcon: const Icon(Icons.email_outlined),
      enabled: enabled,
    );
  }

  /// パスワード入力用テキストフィールド
  factory AppTextField.password({
    Key? key,
    TextEditingController? controller,
    String? labelText,
    String? hintText,
    String? errorText,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool enabled = true,
    bool obscureText = true,
    Widget? suffixIcon,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      labelText: labelText ?? 'パスワード',
      hintText: hintText,
      errorText: errorText,
      validator: validator,
      onChanged: onChanged,
      obscureText: obscureText,
      prefixIcon: const Icon(Icons.lock_outlined),
      suffixIcon: suffixIcon,
      enabled: enabled,
    );
  }

  /// 複数行テキスト入力用テキストフィールド
  factory AppTextField.multiline({
    Key? key,
    TextEditingController? controller,
    String? labelText,
    String? hintText,
    String? errorText,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    int maxLines = 4,
    int? minLines,
    int? maxLength,
    bool enabled = true,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      errorText: errorText,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      minLines: minLines ?? 2,
      maxLength: maxLength,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        prefixText: prefixText,
        suffixText: suffixText,
      ),
    );
  }
}

/// 日付選択用テキストフィールド
class AppDateField extends StatelessWidget {
  final DateTime? value;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final void Function(DateTime)? onChanged;
  final bool enabled;

  const AppDateField({
    super.key,
    this.value,
    this.labelText,
    this.hintText,
    this.errorText,
    this.firstDate,
    this.lastDate,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value != null
        ? '${value!.year}/${value!.month.toString().padLeft(2, '0')}/${value!.day.toString().padLeft(2, '0')}'
        : '';

    return AppTextField(
      controller: TextEditingController(text: displayValue),
      labelText: labelText,
      hintText: hintText ?? 'YYYY/MM/DD',
      errorText: errorText,
      readOnly: true,
      enabled: enabled,
      prefixIcon: const Icon(Icons.calendar_today),
      onTap: enabled
          ? () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: firstDate ?? DateTime(2000),
                lastDate: lastDate ?? DateTime.now(),
              );
              if (selectedDate != null && onChanged != null) {
                onChanged!(selectedDate);
              }
            }
          : null,
    );
  }
}

/// ドロップダウン選択用フィールド
class AppDropdownField<T> extends StatelessWidget {
  final T? value;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final bool enabled;
  final Widget? prefixIcon;

  const AppDropdownField({
    super.key,
    this.value,
    this.labelText,
    this.hintText,
    this.errorText,
    required this.items,
    this.onChanged,
    this.enabled = true,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: prefixIcon,
      ),
    );
  }
}
