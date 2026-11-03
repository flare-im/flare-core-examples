import 'dart:async';

import 'package:flare_im/infrastructure/location/device_location_service.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as kit_sizes show FlareSizes;
import 'package:flare_im_ui/flare_im_ui.dart' as kit_theme show FlareColors;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PickedLocation {
  final double latitude;
  final double longitude;
  final String title;
  final String? address;
  final int zoom;
  final String snapshotUrl;

  const PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.title,
    this.address,
    required this.zoom,
    required this.snapshotUrl,
  });
}

Future<PickedLocation?> showLocationPickerSheet(BuildContext context) {
  return showModalBottomSheet<PickedLocation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LocationPickerSheet(),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  static const _fallbackPoint = LatLng(31.2304, 121.4737);
  static const _defaultZoom = 16;

  final _service = const DeviceLocationService();
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();

  LatLng _selectedPoint = _fallbackPoint;
  double _zoom = _defaultZoom.toDouble();
  bool _initializing = true;
  bool _searching = false;
  String? _errorText;
  List<LocationSearchResult> _results = const [];
  Timer? _reverseTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrentLocation());
  }

  @override
  void dispose() {
    _reverseTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    _titleController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _initializing = true;
      _errorText = null;
    });
    try {
      final current = await _service.currentLocation();
      if (!mounted) return;
      _applySnapshot(current, moveMap: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = '$e';
        _titleController.text = '选择位置';
        _addressController.text = '搜索地点，或在地图上点选位置';
      });
      _mapController.move(_fallbackPoint, _defaultZoom.toDouble());
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _applySnapshot(
    DeviceLocationSnapshot snapshot, {
    required bool moveMap,
  }) {
    final point = LatLng(snapshot.latitude, snapshot.longitude);
    setState(() {
      _selectedPoint = point;
      _titleController.text = (snapshot.title ?? '').trim().isNotEmpty
          ? snapshot.title!.trim()
          : '地图位置';
      _addressController.text = (snapshot.address ?? '').trim();
      _zoom = _defaultZoom.toDouble();
    });
    if (moveMap) {
      _mapController.move(point, _defaultZoom.toDouble());
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _errorText = null;
    });
    try {
      final results = await _service.search(query);
      if (!mounted) return;
      setState(() => _results = results);
      if (results.isNotEmpty) {
        _selectSearchResult(results.first);
      } else {
        setState(() => _errorText = '没有找到相关地点');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '搜索失败：$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectSearchResult(LocationSearchResult result) {
    _applySnapshot(result.toSnapshot(), moveMap: true);
  }

  void _selectPoint(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _titleController.text = '地图选点';
      _addressController.text =
          '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
    });
    _reverseTimer?.cancel();
    _reverseTimer = Timer(const Duration(milliseconds: 260), () async {
      final place = await _service.reverseGeocode(
        point.latitude,
        point.longitude,
      );
      if (!mounted || point != _selectedPoint || place == null) return;
      setState(() {
        final title = place.title?.trim() ?? '';
        final address = place.address?.trim() ?? '';
        if (title.isNotEmpty) _titleController.text = title;
        if (address.isNotEmpty) _addressController.text = address;
      });
    });
  }

  void _confirm() {
    final title = _titleController.text.trim();
    final address = _addressController.text.trim();
    final z = _zoom.round().clamp(1, 18);
    Navigator.pop(
      context,
      PickedLocation(
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
        title: title.isNotEmpty ? title : '地图位置',
        address: address.isNotEmpty ? address : null,
        zoom: z,
        snapshotUrl: DeviceLocationSnapshot.staticMapUrl(
          latitude: _selectedPoint.latitude,
          longitude: _selectedPoint.longitude,
          zoom: z,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(left: 10, right: 10, bottom: bottom + 10),
      child: Material(
        color: kit_theme.FlareColors.of(context).bgPrimary,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildSearch(),
              if (_errorText != null) _buildError(_errorText!),
              Flexible(
                child: Column(
                  children: [
                    Expanded(child: _buildMap()),
                    _buildResultList(),
                    _buildSelectedPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kit_theme.FlareColors.of(
                context,
              ).info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.explore_outlined,
              color: kit_theme.FlareColors.of(context).info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择位置',
                  style: TextStyle(
                    fontSize: kit_sizes.FlareSizes.fontSize4xl,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: kit_theme.FlareColors.of(context).textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '搜索地点，或在地图上点选要发送的位置',
                  style: TextStyle(
                    fontSize: kit_sizes.FlareSizes.fontSizeSm,
                    height: 1.25,
                    color: kit_theme.FlareColors.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => unawaited(_search()),
              decoration: InputDecoration(
                hintText: '搜索地点、小区、公司或地址',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: kit_theme.FlareColors.of(context).bgSecondary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: kit_theme.FlareColors.of(context).borderSecondary,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: kit_theme.FlareColors.of(context).borderSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _searching ? null : () => unawaited(_search()),
              style: FilledButton.styleFrom(
                backgroundColor: kit_theme.FlareColors.of(context).primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('搜索'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: kit_theme.FlareColors.of(
            context,
          ).warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: kit_sizes.FlareSizes.fontSizeSm,
            height: 1.35,
            color: kit_theme.FlareColors.of(context).textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedPoint,
                initialZoom: _defaultZoom.toDouble(),
                minZoom: 3,
                maxZoom: 18,
                onTap: (_, point) => _selectPoint(point),
                onPositionChanged: (camera, _) {
                  _zoom = camera.zoom;
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.flare_im',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint,
                      width: 46,
                      height: 46,
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 42,
                        color: kit_theme.FlareColors.of(context).error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_initializing)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.64),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            Positioned(
              right: 10,
              top: 10,
              child: _MapFab(
                tooltip: '回到当前位置',
                icon: Icons.my_location_rounded,
                onPressed: () => unawaited(_loadCurrentLocation()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultList() {
    if (_results.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemBuilder: (context, index) {
          final result = _results[index];
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Icon(
              Icons.place_outlined,
              color: kit_theme.FlareColors.of(context).info,
            ),
            title: Text(
              result.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: result.address == null
                ? null
                : Text(
                    result.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            onTap: () => _selectSearchResult(result),
          );
        },
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemCount: _results.length,
      ),
    );
  }

  Widget _buildSelectedPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: _inputDecoration('位置名称', Icons.place_outlined),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: _inputDecoration('详细地址', Icons.map_outlined),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedPoint.latitude.toStringAsFixed(6)}, ${_selectedPoint.longitude.toStringAsFixed(6)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: kit_sizes.FlareSizes.fontSizeSm,
                    color: kit_theme.FlareColors.of(context).textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: kit_theme.FlareColors.of(context).primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('发送位置'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        size: 19,
        color: kit_theme.FlareColors.of(context).textSecondary,
      ),
      filled: true,
      fillColor: kit_theme.FlareColors.of(context).bgSecondary,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(
        fontSize: kit_sizes.FlareSizes.fontSizeSm,
        fontWeight: FontWeight.w600,
        color: kit_theme.FlareColors.of(context).textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: kit_theme.FlareColors.of(context).borderSecondary,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: kit_theme.FlareColors.of(context).borderSecondary,
        ),
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: kit_theme.FlareColors.of(context).textPrimary),
      ),
    );
  }
}
