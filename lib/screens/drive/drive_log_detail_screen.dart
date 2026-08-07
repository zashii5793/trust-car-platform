import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../core/utils/route_privacy.dart';
import '../../models/drive_log.dart';
import '../../providers/auth_provider.dart';
import '../../services/drive_log_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_indicator.dart';

/// ドライブログの詳細・編集画面。
///
/// 一覧はあったが詳細が無く、記録した後にできることが何も無かった。
/// 「どこに行ったか」「日記」「写真」「共有」はすべてモデルに項目が
/// ありながら、画面が繋がっていなかった。
///
/// 公開する場合は自宅が割れないよう、経路の両端と住所をぼかす
/// （[buildBlurredRoute]）。ぼかした結果は公開設定を入れた時点で
/// 画面にも反映し、「何が他人に見えるのか」をその場で確認できるようにする。
class DriveLogDetailScreen extends StatefulWidget {
  final DriveLog driveLog;

  const DriveLogDetailScreen({super.key, required this.driveLog});

  @override
  State<DriveLogDetailScreen> createState() => _DriveLogDetailScreenState();
}

class _DriveLogDetailScreenState extends State<DriveLogDetailScreen> {
  late DriveLog _log;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  List<DriveWaypoint> _waypoints = [];
  bool _isLoadingRoute = true;
  bool _isSaving = false;
  bool _isUploading = false;

  /// 公開時のプレビュー。true のとき「他人に見える姿」を表示する。
  bool _previewAsPublic = false;

  DriveLogService get _service => sl.get<DriveLogService>();
  FirebaseService get _firebaseService => sl.get<FirebaseService>();

  static final _dateFormat = DateFormat('yyyy年MM月dd日 HH:mm');

  @override
  void initState() {
    super.initState();
    _log = widget.driveLog;
    _titleController = TextEditingController(text: _log.title ?? '');
    _descriptionController =
        TextEditingController(text: _log.description ?? '');
    _loadWaypoints();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadWaypoints() async {
    final result = await _service.getWaypoints(_log.id);
    if (!mounted) return;
    result.when(
      success: (waypoints) => setState(() {
        _waypoints = waypoints;
        _isLoadingRoute = false;
      }),
      // 経路が取れなくても日記や写真は編集できる。ここで画面全体を
      // エラーにしない。
      failure: (_) => setState(() => _isLoadingRoute = false),
    );
  }

  String? get _userId => context.read<AuthProvider>().firebaseUser?.uid;

  // ---------------------------------------------------------------------------
  // 保存
  // ---------------------------------------------------------------------------

  Future<void> _save({bool? isPublic}) async {
    final userId = _userId;
    if (userId == null) {
      showErrorSnackBar(context, 'ログインセッションが切れました。再ログインしてください');
      return;
    }

    setState(() => _isSaving = true);
    final result = await _service.updateDriveLog(
      driveLogId: _log.id,
      userId: userId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      isPublic: isPublic,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    result.when(
      success: (updated) {
        setState(() => _log = updated);
        showSuccessSnackBar(context, '保存しました');
      },
      failure: (error) => showErrorSnackBar(context, error.userMessage),
    );
  }

  Future<void> _addPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty || !mounted) return;

    final userId = _userId;
    if (userId == null) return;

    setState(() => _isUploading = true);

    final urls = <String>[..._log.photoUrls];
    for (var i = 0; i < picked.length; i++) {
      final Uint8List bytes = await picked[i].readAsBytes();
      final path =
          'drive_logs/$userId/${_log.id}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final upload = await _firebaseService.uploadImageBytes(bytes, path);
      final url = upload.valueOrNull;
      if (url != null) urls.add(url);
    }

    if (!mounted) return;
    final result = await _service.updateDriveLog(
      driveLogId: _log.id,
      userId: userId,
      photoUrls: urls,
      thumbnailUrl: _log.thumbnailUrl ?? (urls.isNotEmpty ? urls.first : null),
    );
    if (!mounted) return;
    setState(() => _isUploading = false);

    result.when(
      success: (updated) => setState(() => _log = updated),
      failure: (error) => showErrorSnackBar(context, error.userMessage),
    );
  }

  // ---------------------------------------------------------------------------
  // 表示
  // ---------------------------------------------------------------------------

  /// 画面に出す経路と住所。公開プレビュー中はぼかした結果を返す。
  BlurredRoute get _visibleRoute => buildBlurredRoute(
        waypoints: _waypoints.map((w) => w.location).toList(),
        startAddress: _log.startAddress,
        endAddress: _log.endAddress,
        isPublic: _previewAsPublic || _log.isPublic,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ドライブの記録'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              key: const Key('drive_log_save_button'),
              onPressed: _save,
              child: const Text('保存'),
            ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          Text(
            _dateFormat.format(_log.startTime),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          AppSpacing.verticalMd,
          _buildRouteSection(theme),
          AppSpacing.verticalLg,
          _buildDiarySection(theme),
          AppSpacing.verticalLg,
          _buildPhotoSection(theme),
          AppSpacing.verticalLg,
          _buildSharingSection(theme),
          AppSpacing.verticalLg,
        ],
      ),
    );
  }

  // ---- 経路 ----

  Widget _buildRouteSection(ThemeData theme) {
    final route = _visibleRoute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, '経路', Icons.route),
        AppSpacing.verticalSm,
        if (_isLoadingRoute)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: AppLoadingCenter(),
          )
        else ...[
          _placeRow(
            theme,
            Icons.trip_origin,
            '出発',
            route.startAddress ?? '記録なし',
          ),
          _placeRow(
            theme,
            Icons.place,
            '到着',
            route.endAddress ?? '記録なし',
          ),
          AppSpacing.verticalSm,
          _RoutePreview(
            key: const Key('drive_log_route_preview'),
            waypoints: route.waypoints,
            isBlurred: _previewAsPublic || _log.isPublic,
          ),
          AppSpacing.verticalXs,
          Text(
            '${route.waypoints.length}点の記録',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _placeRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          AppSpacing.horizontalXs,
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  // ---- 日記 ----

  Widget _buildDiarySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, '日記', Icons.edit_note),
        AppSpacing.verticalSm,
        AppTextField(
          key: const Key('drive_log_title_field'),
          controller: _titleController,
          labelText: 'タイトル',
          hintText: '例: 箱根の紅葉',
          prefixIcon: const Icon(Icons.title),
        ),
        AppSpacing.verticalSm,
        AppTextField(
          key: const Key('drive_log_description_field'),
          controller: _descriptionController,
          labelText: '本文',
          hintText: '道中のできごと、寄った店、路面の状態など',
          maxLines: 8,
          minLines: 4,
        ),
      ],
    );
  }

  // ---- 写真 ----

  Widget _buildPhotoSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, '写真', Icons.photo_library),
        AppSpacing.verticalSm,
        if (_log.photoUrls.isEmpty)
          Text(
            'まだ写真がありません',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textTertiary),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _log.photoUrls.length,
              separatorBuilder: (_, __) => AppSpacing.horizontalSm,
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: AppSpacing.borderRadiusSm,
                child: Image.network(
                  _log.photoUrls[i],
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 96,
                    height: 96,
                    color: AppColors.divider,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
        AppSpacing.verticalSm,
        OutlinedButton.icon(
          key: const Key('drive_log_add_photo_button'),
          onPressed: _isUploading ? null : _addPhotos,
          icon: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_a_photo_outlined),
          label: Text(_isUploading ? 'アップロード中…' : '写真を追加'),
        ),
      ],
    );
  }

  // ---- 共有 ----

  Widget _buildSharingSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, '共有', Icons.group),
        AppSpacing.verticalSm,
        SwitchListTile(
          key: const Key('drive_log_public_switch'),
          contentPadding: EdgeInsets.zero,
          value: _log.isPublic,
          title: const Text('他のユーザーに公開する'),
          subtitle: const Text('出発地・到着地は市区町村までにぼかし、自宅付近の経路は消して公開します'),
          onChanged: _isSaving ? null : (v) => _save(isPublic: v),
        ),
        if (!_log.isPublic)
          CheckboxListTile(
            key: const Key('drive_log_preview_public'),
            contentPadding: EdgeInsets.zero,
            value: _previewAsPublic,
            title: const Text('公開したときの見え方を確認する'),
            onChanged: (v) => setState(() => _previewAsPublic = v ?? false),
          ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: AppSpacing.borderRadiusSm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.privacy_tip_outlined,
                  size: 16, color: AppColors.info),
              AppSpacing.horizontalXs,
              Expanded(
                child: Text(
                  '公開しても、出発地と到着地から半径'
                  '${kDefaultPrivacyRadiusMeters.toInt()}m以内の経路は表示されません。'
                  '自宅を出発点にしていても、住所が特定される形では共有されません。',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        AppSpacing.horizontalXs,
        Text(title, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 経路プレビュー
// ---------------------------------------------------------------------------

/// 経路の形を示す簡易プレビュー。
///
/// Google Maps のウィジェットは `google_maps_flutter` が入ってから差し替える。
/// それまで真っ白にしておくと「経路が記録されていない」のか
/// 「地図が出ていないだけ」なのか判別できないので、点列だけでも描く。
class _RoutePreview extends StatelessWidget {
  final List<GeoPoint2D> waypoints;
  final bool isBlurred;

  const _RoutePreview({
    super.key,
    required this.waypoints,
    required this.isBlurred,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (waypoints.length < 2) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.divider.withValues(alpha: 0.3),
          borderRadius: AppSpacing.borderRadiusSm,
        ),
        child: Text(
          isBlurred ? '公開できる経路が残っていません' : '経路が記録されていません',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.divider.withValues(alpha: 0.3),
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.borderRadiusSm,
        child: CustomPaint(
          painter: _RoutePainter(
            waypoints: waypoints,
            color: theme.colorScheme.primary,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<GeoPoint2D> waypoints;
  final Color color;

  _RoutePainter({required this.waypoints, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (waypoints.length < 2) return;

    var minLat = waypoints.first.latitude;
    var maxLat = waypoints.first.latitude;
    var minLng = waypoints.first.longitude;
    var maxLng = waypoints.first.longitude;
    for (final p in waypoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // 直線的な経路だと幅か高さが 0 になる。ゼロ除算を避ける。
    final latRange = (maxLat - minLat).abs() < 1e-9 ? 1e-9 : maxLat - minLat;
    final lngRange = (maxLng - minLng).abs() < 1e-9 ? 1e-9 : maxLng - minLng;

    const padding = 12.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    Offset toOffset(GeoPoint2D p) => Offset(
          padding + (p.longitude - minLng) / lngRange * w,
          // 緯度は北が上なので反転する。
          padding + (maxLat - p.latitude) / latRange * h,
        );

    final path = Path()
      ..moveTo(toOffset(waypoints.first).dx, toOffset(waypoints.first).dy);
    for (final p in waypoints.skip(1)) {
      final o = toOffset(p);
      path.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(
      toOffset(waypoints.first),
      4,
      Paint()..color = color,
    );
    canvas.drawCircle(
      toOffset(waypoints.last),
      4,
      Paint()..color = color.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.waypoints != waypoints || oldDelegate.color != color;
}
