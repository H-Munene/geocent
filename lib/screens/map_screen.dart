import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_popup/flutter_popup.dart';

import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/call_out_result.dart';
import '../models/map_place.dart';
import '../models/app_transaction.dart';
import '../repositories/transaction_repository.dart';
import '../services/sms_service.dart';
import '../services/spending_service.dart';
import '../utils/marker_utils.dart';
import '../widgets/animated_spending_analytics.dart';
import '../widgets/category_dropdown_widget.dart';
import '../widgets/category_messages_sheet.dart';
import '../widgets/custom_toast.dart';
import '../widgets/map_style_picker_modal.dart';
import '../widgets/search_messages_sheet.dart';
import 'location_picker_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  mp.PointAnnotationManager? _annotationManager;
  mp.CircleAnnotationManager? _dotManager;
  final Map<String, MapPlace> _annotationToPlaceMap = {};
  bool _isAnimating = false;
  List<MapPlace> _places = [];
  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;
  StreamSubscription? _bgServiceSub;

  int _annotationUpdateVersion = 0;
  String _currentMapStyle = mp.MapboxStyles.STANDARD;
  bool _isMapUpdating = false;
  bool _isSearching = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showAnalytics = true;

  bool _showDynamicIsland = false;
  List<AppTransaction> _newTransactions = [];
  Timer? _txDisplayTimer;

  String? _selectedCategory;
  String? _selectedTxId;

  final GlobalKey<CustomPopupState> _popupKey = GlobalKey<CustomPopupState>();
  mp.ScreenCoordinate? _popupPosition;
  MapPlace? _selectedPlace;

  // Initialised once onMapCreated fires
  SmsService? _smsService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMapStyle();
    _positionTracking();

    _searchFocusNode.addListener(_onSearchFocusChanged);
    _searchController.addListener(_onSearchTextChanged);

    // Listen for background service events
    _bgServiceSub = FlutterBackgroundService().on('transaction_saved').listen((
      _,
    ) {
      if (mounted) {
        context.read<SpendingService>().refresh();
      }
    });

    FlutterBackgroundService().on('location_attached').listen((event) async {
      if (mounted) {
        final spending = context.read<SpendingService>();
        // Explicitly await refresh to ensure the new transaction is in mappedTransactions
        await spending.refresh();

        if (event != null && event['id'] != null) {
          final txId = event['id'].toString();
          if (mounted) {
            final mappedTxs = spending.mappedTransactions;
            final txIndex = mappedTxs.indexWhere((t) => t.id == txId);
            if (txIndex != -1) {
              _showDynamicIslandForTransaction(mappedTxs[txIndex]);
            }
          }
        }
      }
    });

    // Add listener for selected transaction from Messages screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SpendingService>().addListener(_handleSelectedTransaction);
    });

    // Check for recently mapped transactions on app startup
    _checkRecentTransactions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchController.removeListener(_onSearchTextChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();

    userPositionStream?.cancel();
    _bgServiceSub?.cancel();
    _txDisplayTimer?.cancel();
    mapboxMapController?.dispose();
    _smsService?.dispose();

    // Remove listener to prevent memory leaks
    final spending = Provider.of<SpendingService>(context, listen: false);
    spending.removeListener(_refreshAnnotations);
    spending.removeListener(_handleSelectedTransaction);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data and check for recent transactions whenever we return to the foreground
      context.read<SpendingService>().refresh().then((_) {
        _checkRecentTransactions();
      });
    }
  }

  Future<void> _checkRecentTransactions() async {
    // Slight delay to ensure Provider context is ready
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final spending = context.read<SpendingService>();

    // Wait for the SpendingService to finish its initial data fetch
    while (spending.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    final now = DateTime.now();
    // Scan for any mapped transactions that occurred in the last 5 minutes
    for (final tx in spending.mappedTransactions) {
      if (now.difference(tx.timestamp).inMinutes <= 5) {
        _showDynamicIslandForTransaction(tx);
      }
    }
  }

  void _onSearchFocusChanged() {
    setState(() {
      _showAnalytics =
          !_searchFocusNode.hasFocus && _searchController.text.isEmpty;
    });
  }

  void _onSearchTextChanged() {
    setState(() {
      _showAnalytics =
          !_searchFocusNode.hasFocus && _searchController.text.isEmpty;
    });
  }

  Future<void> _loadMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStyle = prefs.getString('map_style');
    if (savedStyle != null && mounted) {
      setState(() {
        _currentMapStyle = savedStyle;
      });

      // If controller is already ready, load the style now
      if (mapboxMapController != null) {
        await mapboxMapController!.loadStyleURI(savedStyle);
        // Style load takes a moment, expressions need re-applying
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _applyStyleLayerExpressions();
            _refreshAnnotations();
          }
        });
      }
    }
  }

  void _handleMapTap(mp.MapContentGestureContext context) {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
  }

  Future<void> _saveMapStyle(String styleUri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_style', styleUri);
  }

  void _handleSelectedTransaction() async {
    final spending = context.read<SpendingService>();
    final txId = spending.selectedTxId;
    if (txId == null || mapboxMapController == null) return;

    // Find the transaction in either mapped or period transactions
    final allTxs = [
      ...spending.mappedTransactions,
      ...spending.periodTransactions,
    ];
    final txIndex = allTxs.indexWhere((t) => t.id == txId);
    if (txIndex == -1) {
      spending.clearSelectedTransaction();
      return;
    }
    final tx = allTxs[txIndex];

    if (tx.latitude == null || tx.longitude == null) {
      spending.clearSelectedTransaction();
      return;
    }

    final place = MapPlace(
      name: tx.merchant,
      latitude: tx.latitude!,
      longitude: tx.longitude!,
      transactions: [tx],
    );

    // Fly to the location
    await mapboxMapController?.flyTo(
      mp.CameraOptions(
        zoom: 17,
        center: mp.Point(
          coordinates: mp.Position(place.longitude, place.latitude),
        ),
      ),
      mp.MapAnimationOptions(duration: 1000),
    );

    // Wait for camera animation to finish
    await Future.delayed(const Duration(milliseconds: 1100));

    if (!mounted) return;

    final screenCoord = await mapboxMapController?.pixelForCoordinate(
      mp.Point(coordinates: mp.Position(place.longitude, place.latitude)),
    );

    if (screenCoord != null && mounted) {
      setState(() {
        _selectedPlace = place;
        _popupPosition = screenCoord;
        _selectedTxId = tx.id;
      });

      // Boost priority of the selected annotation so it wins collision
      await _updateAnnotationPriority();

      // Clear the selection so it doesn't trigger again on every rebuild
      spending.clearSelectedTransaction();

      // Show popup in next frame after Positioned has moved the anchor
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _popupKey.currentState?.show();
      });
    }
  }

  Future<void> _updateAnnotationPriority() async {
    if (_annotationManager == null || _selectedTxId == null) return;

    final allAnnotations = await _annotationManager!.getAnnotations();
    for (final ann in allAnnotations) {
      final place = _annotationToPlaceMap[ann.id];
      if (place == null) continue;

      final double newSortKey = _getSortKey(place);

      if (ann.symbolSortKey != newSortKey) {
        ann.symbolSortKey = newSortKey;
        await _annotationManager!.update(ann);
      }
    }
  }

  List<MapPlace> _groupTransactions(List<AppTransaction> transactions) {
    final Map<String, List<AppTransaction>> groups = {};

    for (var tx in transactions) {
      if (tx.latitude == null || tx.longitude == null) continue;
      // Using a rounded coordinate string as key to handle precision issues if any,
      // but the requirement says "exact same location".
      final key = '${tx.latitude},${tx.longitude}';
      groups.putIfAbsent(key, () => []).add(tx);
    }

    return groups.values.map((group) {
      return MapPlace(
        name: group.first.merchant,
        latitude: group.first.latitude!,
        longitude: group.first.longitude!,
        transactions: group,
      );
    }).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 12;
    final spending = context.watch<SpendingService>();

    // Sync places with spending service mapped transactions
    final saved = spending.mappedTransactions;
    _places = _groupTransactions(saved);

    return CupertinoPageScaffold(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
        },
        child: Stack(
          children: [
            mp.MapWidget(
              styleUri: _currentMapStyle,
              onMapCreated: onMapCreated,
              onTapListener: _handleMapTap,
            ),
            if (spending.isLoading || _isMapUpdating)
              const Center(
                child: CupertinoActivityIndicator(
                  radius: 16,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            Positioned(
              top: topPadding,
              left: 16,
              right: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 46),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12, left: 12),
                            child: Row(
                              children: [
                                CupertinoActivityIndicator(radius: 8),
                                SizedBox(width: 8),
                                Text(
                                  'Searching...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: spending.categories.map((cat) {
                              final isSelected = _selectedCategory == cat.name;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      if (_selectedCategory == cat.name) {
                                        _selectedCategory = null;
                                      } else {
                                        _selectedCategory = cat.name;
                                      }
                                    });

                                    // If we just selected a category, show the sheet with its messages
                                    if (_selectedCategory != null) {
                                      // Capture the navigator before the async gap
                                      final navigator = Navigator.of(context);

                                      final results = await spending
                                          .getMessagesByCategory(cat.name);

                                      if (!mounted) return;

                                      showCupertinoSheet(
                                        context: navigator.context,
                                        builder: (context) =>
                                            CategoryMessagesSheet(
                                              results: results,
                                              categoryName: cat.name,
                                              onMessageSelected: (tx) {
                                                spending.selectTransaction(
                                                  tx.id,
                                                );
                                              },
                                            ),
                                      );
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? spending.getCategoryColor(cat.name)
                                          : CupertinoColors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? spending.getCategoryColor(
                                                cat.name,
                                              )
                                            : CupertinoColors.systemGrey5,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: CupertinoColors.black
                                              .withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        HugeIcon(
                                          icon: cat.icon,
                                          color: isSelected
                                              ? CupertinoColors.white
                                              : CupertinoColors.black,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          cat.name,
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? CupertinoColors.white
                                                : CupertinoColors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    // Reduced duration for faster closing/opening transitions
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutBack,
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(
                        _showDynamicIsland ? 32 : 14,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withValues(alpha: 0.1),
                          blurRadius: _showDynamicIsland ? 24 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        _showDynamicIsland ? 32 : 14,
                      ),
                      child: AnimatedSize(
                        // Match the duration of AnimatedSwitcher for synchronized scaling and fading
                        duration: const Duration(milliseconds: 550),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 550),
                          // Custom layoutBuilder to stack children top-aligned,
                          // preventing the container from holding its large size during crossfade.
                          layoutBuilder:
                              (
                                Widget? currentChild,
                                List<Widget> previousChildren,
                              ) {
                                return Stack(
                                  alignment: Alignment.topCenter,
                                  children: <Widget>[
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                          // Custom transition for blur effect and delayed search bar appearance
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                final isIsland =
                                    child.key == const ValueKey('island');

                                if (isIsland) {
                                  final blurCurve = CurvedAnimation(
                                    parent: animation,
                                    curve: const Interval(
                                      0.0,
                                      0.8,
                                      curve: Curves.easeIn,
                                    ),
                                  );
                                  return AnimatedBuilder(
                                    animation: blurCurve,
                                    builder: (context, child) {
                                      final blurAmount =
                                          (1.0 - blurCurve.value) * 15.0;
                                      return ImageFiltered(
                                        imageFilter: ui.ImageFilter.blur(
                                          sigmaX: blurAmount,
                                          sigmaY: blurAmount,
                                        ),
                                        child: child!,
                                      );
                                    },
                                    child: child,
                                  );
                                } else {
                                  // Search bar only fades in during the very last 10%
                                  // (animation 0.0 → 0.1 on the incoming child = nearly closed)
                                  final delayedOpacity = CurvedAnimation(
                                    parent: animation,
                                    curve: const Interval(
                                      0.9,
                                      1.0,
                                      curve: Curves.easeIn,
                                    ),
                                  );
                                  return FadeTransition(
                                    opacity: delayedOpacity,
                                    child: child,
                                  );
                                }
                              },
                          child: _showDynamicIsland
                              ? _buildIslandContent()
                              : _buildSearchBarContent(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // FABs moved into the stack as Positioned widgets
            Positioned(
              bottom: 40,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _showMapStylePicker();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: CupertinoColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.square_stack_3d_up,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _flyToUserLocation();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: CupertinoColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.location_fill,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_places.isNotEmpty)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _isAnimating
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _animateAnnotations();
                            },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isAnimating
                              ? CupertinoColors.systemGrey3
                              : CupertinoColors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isAnimating
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                            : const Icon(
                                CupertinoIcons.play_fill,
                                color: CupertinoColors.black,
                              ),
                      ),
                    ),
                ],
              ),
            ),
            if (_popupPosition != null && _selectedPlace != null)
              Positioned(
                left: _popupPosition!.x,
                top: _popupPosition!.y,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: CustomPopup(
                      key: _popupKey,
                      backgroundColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      content: DefaultTextStyle(
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.black,
                          decoration: TextDecoration.none,
                        ),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  final cat = context
                                      .read<SpendingService>()
                                      .getCategoryByName(
                                        _selectedPlace?.category,
                                      );
                                  return CustomPopup(
                                    barrierColor: CupertinoColors.transparent,
                                    contentPadding: EdgeInsets.zero,
                                    content: CategoryDropdownWidget(
                                      transactionId: _selectedPlace!.id,
                                      currentCategory: _selectedPlace!.category,
                                      onCategorySelected: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.popUntil(
                                          context,
                                          (route) => route.isFirst,
                                        );
                                      },
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cat == null
                                            ? CupertinoColors.systemGrey5
                                            : spending
                                                  .getCategoryColor(cat.name)
                                                  .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (cat != null) ...[
                                            HugeIcon(
                                              icon: cat.icon,
                                              color: spending.getCategoryColor(
                                                cat.name,
                                              ),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            _selectedPlace?.category ??
                                                'Set Category',
                                            style: GoogleFonts.spaceGrotesk(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: cat == null
                                                  ? CupertinoColors.systemGrey
                                                  : spending.getCategoryColor(
                                                      cat.name,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 1,
                                color: Colors.black.withValues(alpha: 0.1),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectedPlace?.transactions.first.rawMessage ??
                                    '',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _flyToUserLocation() async {
    try {
      final position = await gl.Geolocator.getCurrentPosition(
        locationSettings: const gl.LocationSettings(
          accuracy: gl.LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      await mapboxMapController?.flyTo(
        mp.CameraOptions(
          zoom: 17,
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
        ),
        mp.MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      debugPrint('[Home] Could not get user location: $e');
    }
  }

  // ── Location tracking ──────────────────────────────────────────────────────

  Future<void> _positionTracking() async {
    final bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[Home] Location service is off');
      return;
    }

    userPositionStream?.cancel();
    userPositionStream =
        gl.Geolocator.getPositionStream(
          locationSettings: const gl.LocationSettings(
            accuracy: gl.LocationAccuracy.high,
            distanceFilter: 50,
          ),
        ).listen((gl.Position? position) {
          if (position != null &&
              mapboxMapController != null &&
              !_isAnimating) {
            mapboxMapController?.setCamera(
              mp.CameraOptions(
                zoom: 17,
                center: mp.Point(
                  coordinates: mp.Position(
                    position.longitude,
                    position.latitude,
                  ),
                ),
              ),
            );
          }
        });
  }

  void _showMapStylePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => MapStylePickerModal(
        currentStyle: _currentMapStyle,
        onStyleChanged: (newStyle) async {
          if (newStyle == _currentMapStyle) return;
          setState(() => _currentMapStyle = newStyle);
          await _saveMapStyle(newStyle);
          await mapboxMapController?.loadStyleURI(newStyle);
          // Wait for style to load before re-applying layer properties
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _applyStyleLayerExpressions();
              _refreshAnnotations();
            }
          });
        },
      ),
    );
  }

  Future<void> _applyStyleLayerExpressions() async {
    if (mapboxMapController == null) return;

    // 2. Configure Callout Collision & Native Opacity Expressions
    if (_annotationManager != null) {
      await _annotationManager!.setIconAllowOverlap(false);
      await _annotationManager!.setIconIgnorePlacement(false);
      await _annotationManager!.setTextAllowOverlap(false);
      await _annotationManager!.setTextIgnorePlacement(false);

      // Detailed Callouts: Visible only >= 13.0
      await mapboxMapController?.style.setStyleLayerProperty(
        _annotationManager!.id,
        'icon-opacity',
        [
          'step',
          ['zoom'],
          0.0,
          11.0,
          1.0,
        ],
      );
      await mapboxMapController?.style.setStyleLayerProperty(
        _annotationManager!.id,
        'text-opacity',
        [
          'step',
          ['zoom'],
          0.0,
          11.0,
          1.0,
        ],
      );
    }

    // 3. Configure Dot Native Opacity Expressions
    if (_dotManager != null) {
      // Dots: Hidden < 11.0, Visible >= 11.0
      // By staying visible, they act as a fallback when the Callout above them is hidden by collision.
      await mapboxMapController?.style.setStyleLayerProperty(
        _dotManager!.id,
        'circle-opacity',
        [
          'step',
          ['zoom'],
          0.0,
          9.0,
          1.0,
        ],
      );
      await mapboxMapController?.style.setStyleLayerProperty(
        _dotManager!.id,
        'circle-stroke-opacity',
        [
          'step',
          ['zoom'],
          0.0,
          9.0,
          1.0,
        ],
      );
    }
  }

  // ── Map ────────────────────────────────────────────────────────────────────

  Future<void> onMapCreated(mp.MapboxMap controller) async {
    setState(() => mapboxMapController = controller);

    // Ensure the persisted style is loaded if it's not the default
    if (_currentMapStyle != mp.MapboxStyles.STANDARD) {
      await controller.loadStyleURI(_currentMapStyle);
    }

    final locationPermission = await Permission.location.status;
    if (locationPermission != PermissionStatus.granted) return;

    // Center map on user's last known position immediately to avoid New York
    try {
      final lastPos = await gl.Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        controller.setCamera(
          mp.CameraOptions(
            zoom: 17,
            center: mp.Point(
              coordinates: mp.Position(lastPos.longitude, lastPos.latitude),
            ),
          ),
        );
      }
      // Trigger a fresh location fetch for high accuracy
      gl.Geolocator.getCurrentPosition(
        locationSettings: const gl.LocationSettings(
          accuracy: gl.LocationAccuracy.high,
        ),
      ).then((pos) {
        if (mounted) {
          controller.flyTo(
            mp.CameraOptions(
              zoom: 17,
              center: mp.Point(
                coordinates: mp.Position(pos.longitude, pos.latitude),
              ),
            ),
            mp.MapAnimationOptions(duration: 1000),
          );
        }
      });
    } catch (e) {
      debugPrint('[MapScreen] Initial location fetch failed: $e');
    }

    controller.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: false),
    );

    controller.compass.updateSettings(
      mp.CompassSettings(
        enabled: true,
        position: mp.OrnamentPosition.BOTTOM_RIGHT,
        marginTop: 0,
        marginBottom: 210, // Positioned above the FABs
        marginLeft: 0,
        marginRight: 16,
      ),
    );

    controller.scaleBar.updateSettings(
      mp.ScaleBarSettings(
        enabled: false,
        position: mp.OrnamentPosition.BOTTOM_RIGHT,
        marginBottom: 60, // Positioned just above the tab bar
        marginRight: 16,
      ),
    );

    // 1. Initialize Managers
    // Important: Initialize _dotManager FIRST so it renders BELOW the _annotationManager.
    _dotManager = await controller.annotations.createCircleAnnotationManager();
    _annotationManager = await controller.annotations
        .createPointAnnotationManager();

    await _applyStyleLayerExpressions();

    // 3. Configure Dot Native Opacity Expressions (continued)
    if (_dotManager != null) {
      // Shared tap events for dots
      _dotManager!.tapEvents(
        onTap: (annotation) =>
            _onMarkerTapped(annotation.id, annotation.geometry),
      );
      _dotManager!.longPressEvents(
        onLongPress: (annotation) =>
            _onMarkerLongPressed(annotation.id, annotation.geometry),
      );
    }

    // Handle marker taps for full callouts
    _annotationManager?.tapEvents(
      onTap: (annotation) =>
          _onMarkerTapped(annotation.id, annotation.geometry),
    );
    _annotationManager?.longPressEvents(
      onLongPress: (annotation) {
        HapticFeedback.heavyImpact();
        _onMarkerLongPressed(annotation.id, annotation.geometry);
      },
    );

    if (!mounted) return;
    final spending = context.read<SpendingService>();
    _smsService = SmsService(repo: TransactionRepository(), spending: spending);
    await _smsService!.init();

    spending.addListener(_refreshAnnotations);
    _refreshAnnotations();
  }

  void _onMarkerTapped(String annotationId, mp.Point geometry) async {
    final place = _annotationToPlaceMap[annotationId];
    if (place == null) return;

    if (place.transactions.length > 1) {
      _showGroupedTransactionsSheet(place);
      return;
    }

    final screenCoord = await mapboxMapController?.pixelForCoordinate(geometry);

    if (screenCoord != null && mounted) {
      setState(() {
        _selectedPlace = place;
        _popupPosition = screenCoord;
        _selectedTxId = place.id;
      });

      // Boost priority of the tapped marker
      await _updateAnnotationPriority();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _popupKey.currentState?.show();
      });
    }
  }

  void _showGroupedTransactionsSheet(MapPlace place) {
    showCupertinoSheet(
      showDragHandle: true,
      context: context,
      builder: (context) {
        final spending = context.watch<SpendingService>();
        final totalFormatted = 'KES ${place.totalAmount.toStringAsFixed(0)}';
        final cat = spending.getCategoryByName(place.category);

        return Container(
          color: CupertinoColors.systemBackground,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              place.name,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color: CupertinoColors.systemGrey3,
                              size: 28,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Standardized Pills Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStandardPill(
                              text: totalFormatted,
                              bgColor: const Color(0xFF1D1D1F),
                              textColor: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            _buildStandardPill(
                              text: '${place.transactions.length} messages',
                              bgColor: CupertinoColors.systemGrey6,
                              textColor: CupertinoColors.secondaryLabel,
                            ),
                            const SizedBox(width: 8),
                            // Category Pill
                            GestureDetector(
                              onTap: () {
                                showCupertinoDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (dialogContext) => Center(
                                    child: DefaultTextStyle(
                                      style: GoogleFonts.spaceGrotesk(
                                        color: CupertinoColors.label,
                                        decoration: TextDecoration.none,
                                      ),
                                      child: CategoryDropdownWidget(
                                        onCategorySelectedOverride:
                                            (categoryName) async {
                                              final ids = place.transactions
                                                  .map((tx) => tx.id)
                                                  .toList();
                                              final dialogNavigator =
                                                  Navigator.of(dialogContext);
                                              final sheetNavigator =
                                                  Navigator.of(context);

                                              await spending.bulkUpdateCategory(
                                                ids,
                                                categoryName,
                                              );
                                              if (mounted) {
                                                dialogNavigator
                                                    .pop(); // Pop picker
                                                sheetNavigator
                                                    .pop(); // Pop sheet
                                                showCustomToast(
                                                  '${place.transactions.length} messages successfully categorized',
                                                );
                                              }
                                            },
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: _buildStandardPill(
                                text: cat?.name ?? 'Set Category',
                                bgColor: cat == null
                                    ? CupertinoColors.systemGrey5
                                    : spending
                                          .getCategoryColor(cat.name)
                                          .withValues(alpha: 0.15),
                                textColor: cat == null
                                    ? CupertinoColors.systemGrey
                                    : spending.getCategoryColor(cat.name),
                                icon: cat != null
                                    ? cat.icon
                                    : CupertinoIcons.tag,
                                isCategory: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: place.transactions.length,
                    separatorBuilder: (context, index) =>
                        const Divider(indent: 20, endIndent: 20),
                    itemBuilder: (context, index) {
                      final tx = place.transactions[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tx.formattedAmount,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _formatDate(tx.timestamp),
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tx.rawMessage,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                color: CupertinoColors.label,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStandardPill({
    required String text,
    required Color bgColor,
    required Color textColor,
    dynamic icon,
    bool isCategory = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: isCategory
            ? Border.all(color: textColor.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            if (icon is IconData)
              Icon(icon, color: textColor, size: 16)
            else
              HugeIcon(icon: icon, color: textColor, size: 16),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _onMarkerLongPressed(String annotationId, mp.Point geometry) async {
    final place = _annotationToPlaceMap[annotationId];
    if (place == null) return;

    HapticFeedback.heavyImpact();

    // For grouped messages, we use the first one for the picker initial state
    final tx = place.transactions.first;

    if (mounted) {
      // Close any open popups first
      if (_selectedPlace != null) {
        setState(() {
          _selectedPlace = null;
          _popupPosition = null;
        });
      }

      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (context) => LocationPickerScreen(transactions: [tx]),
        ),
      );
    }
  }

  void _refreshAnnotations() async {
    if (_annotationManager == null) return;

    final spending = context.read<SpendingService>();

    // If spending service is loading, ensure we show our local indicator
    if (spending.isLoading) {
      if (!_isMapUpdating) {
        setState(() => _isMapUpdating = true);
      }
      return;
    }

    // Start local update phase
    if (!_isMapUpdating) {
      setState(() => _isMapUpdating = true);
    }

    // Versioning prevents rapid consecutive refreshes from
    // clobbering each other (race conditions).
    final int currentVersion = ++_annotationUpdateVersion;

    final saved = spending.mappedTransactions;
    final newPlaces = _groupTransactions(saved);

    // If a newer refresh has started, abort this outdated one.
    if (currentVersion != _annotationUpdateVersion || !mounted) return;

    await _addAllAnnotations(newPlaces);

    // Finalize update phase
    if (currentVersion == _annotationUpdateVersion && mounted) {
      setState(() => _isMapUpdating = false);
    }
  }

  Future<void> _addAllAnnotations(List<MapPlace> places) async {
    if (_annotationManager == null || _dotManager == null) return;
    final spending = context.read<SpendingService>();

    // Generate callout options and dot options in parallel
    final List<Future<(mp.PointAnnotationOptions, mp.CircleAnnotationOptions)>>
    futures = places.map((place) async {
      final catColor = spending.getCategoryColor(place.category ?? '');
      final CalloutResult callout = await createCalloutImage(
        place.name,
        place.displayPrice,
        color: catColor,
      );

      final geometry = mp.Point(
        coordinates: mp.Position(place.longitude, place.latitude),
      );
      final sortKey = _getSortKey(place);

      final pointOptions = mp.PointAnnotationOptions(
        image: callout.image,
        iconSize: 1.5,
        iconAnchor: mp.IconAnchor.CENTER,
        iconOffset: [0.0, 0.0],
        symbolSortKey: sortKey,
        geometry: geometry,
      );

      final circleOptions = mp.CircleAnnotationOptions(
        geometry: geometry,
        circleColor: catColor.toARGB32(),
        circleRadius: 1.575,
        circleStrokeWidth: 1.0,
        circleStrokeColor: CupertinoColors.white.toARGB32(),
        circleSortKey: sortKey,
      );

      return (pointOptions, circleOptions);
    }).toList();

    final List<(mp.PointAnnotationOptions, mp.CircleAnnotationOptions)>
    results = await Future.wait(futures);

    final pointOptionsList = results.map((r) => r.$1).toList();
    final circleOptionsList = results.map((r) => r.$2).toList();

    // Perform instantaneous swap on both layers
    await _annotationManager?.deleteAll();
    await _dotManager?.deleteAll();
    _annotationToPlaceMap.clear();

    final pointAnnotations = await _annotationManager?.createMulti(
      pointOptionsList,
    );
    final circleAnnotations = await _dotManager?.createMulti(circleOptionsList);

    if (pointAnnotations != null) {
      for (int i = 0; i < pointAnnotations.length; i++) {
        final ann = pointAnnotations[i];
        if (ann != null) {
          _annotationToPlaceMap[ann.id] = places[i];
        }
      }
    }
    if (circleAnnotations != null) {
      for (int i = 0; i < circleAnnotations.length; i++) {
        final ann = circleAnnotations[i];
        if (ann != null) {
          _annotationToPlaceMap[ann.id] = places[i];
        }
      }
    }
  }

  // ── Animate FAB ────────────────────────────────────────────────────────────

  Future<void> _animateAnnotations() async {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    await _annotationManager?.deleteAll();
    await _dotManager?.deleteAll();
    _annotationToPlaceMap.clear();

    for (final place in _places) {
      if (!_isAnimating) break;
      await _addAnnotationForPlace(place);
      await Future.delayed(const Duration(seconds: 1));
    }
    setState(() => _isAnimating = false);
  }

  Future<void> _addAnnotationForPlace(MapPlace place) async {
    await mapboxMapController?.flyTo(
      mp.CameraOptions(
        zoom: 13.5, // Fly in closer to reveal the callout immediately
        center: mp.Point(
          coordinates: mp.Position(place.longitude, place.latitude),
        ),
      ),
      mp.MapAnimationOptions(duration: 1000),
    );

    if (!mounted) return;
    final spending = context.read<SpendingService>();
    final catColor = spending.getCategoryColor(place.category ?? '');
    final CalloutResult callout = await createCalloutImage(
      place.name,
      place.displayPrice,
      color: catColor,
    );

    final geometry = mp.Point(
      coordinates: mp.Position(place.longitude, place.latitude),
    );
    final sortKey = _getSortKey(place);

    final pointAnn = await _annotationManager?.create(
      mp.PointAnnotationOptions(
        image: callout.image,
        iconSize: 1.5,
        iconAnchor: mp.IconAnchor.CENTER,
        iconOffset: [0.0, 0.0],
        symbolSortKey: sortKey,
        geometry: geometry,
      ),
    );

    final circleAnn = await _dotManager?.create(
      mp.CircleAnnotationOptions(
        geometry: geometry,
        circleColor: catColor.toARGB32(),
        circleRadius: 1.575,
        circleStrokeWidth: 1.0,
        circleStrokeColor: CupertinoColors.white.toARGB32(),
        circleSortKey: sortKey,
      ),
    );

    if (pointAnn != null) {
      _annotationToPlaceMap[pointAnn.id] = place;
    }
    if (circleAnn != null) {
      _annotationToPlaceMap[circleAnn.id] = place;
    }
  }

  double _getSortKey(MapPlace place) {
    if (place.id == _selectedTxId) return -1000000.0;
    // For grouped markers, use a large priority so they stay visible
    if (place.transactions.length > 1) return -500000.0;

    final clean = place.transactions.first.formattedAmount.replaceAll(
      RegExp(r'[^0-9.]'),
      '',
    );
    return double.tryParse(clean) ?? 0.0;
  }

  Future<void> _showDynamicIslandForTransaction(AppTransaction tx) async {
    // Check if we've already shown the island for this transaction
    final prefs = await SharedPreferences.getInstance();
    final shownList = prefs.getStringList('seen_island_tx_ids') ?? [];

    if (shownList.contains(tx.id)) return; // Already shown

    // Mark as shown
    shownList.add(tx.id);
    // Keep list size bounded to prevent infinite growth
    if (shownList.length > 50) {
      shownList.removeRange(0, shownList.length - 50);
    }
    await prefs.setStringList('seen_island_tx_ids', shownList);

    if (!mounted) return;

    setState(() {
      if (!_newTransactions.any((t) => t.id == tx.id)) {
        _newTransactions.add(tx);
      }
    });
    _processTransactionQueue();
  }

  void _processTransactionQueue() {
    if (_newTransactions.isEmpty) {
      if (_showDynamicIsland) {
        setState(() {
          _showDynamicIsland = false;
        });
      }
      return;
    }

    if (_txDisplayTimer?.isActive ?? false) return;

    setState(() {
      _showDynamicIsland = true;
    });

    _txDisplayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          if (_newTransactions.isNotEmpty) {
            _newTransactions.removeAt(0);
          }
        });
        _txDisplayTimer = null;
        _processTransactionQueue();
      }
    });
  }

  Widget _buildIslandContent() {
    if (_newTransactions.isEmpty) return const SizedBox.shrink();

    // Show the most recent transaction
    final tx = _newTransactions.first;

    return Container(
      key: const ValueKey('island'),
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final inAnimation =
              Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          final outAnimation =
              Tween<Offset>(
                begin: const Offset(0.0, -1.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          if (child.key == ValueKey(tx.id)) {
            return SlideTransition(
              position: inAnimation,
              child: FadeTransition(opacity: animation, child: child),
            );
          } else {
            return SlideTransition(
              position: outAnimation,
              child: FadeTransition(opacity: animation, child: child),
            );
          }
        },
        child: _buildTransactionCard(tx),
      ),
    );
  }

  Widget _buildSearchBarContent() {
    return Container(
      key: const ValueKey('search'),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          TapRegion(
            onTapOutside: (event) {
              if (_searchFocusNode.hasFocus) {
                _searchFocusNode.unfocus();
              }
            },
            child: CupertinoSearchTextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              suffixIcon: _isSearching
                  ? const Icon(CupertinoIcons.clear_thick_circled)
                  : const Icon(CupertinoIcons.search),
              suffixMode: OverlayVisibilityMode.editing,
              onSubmitted: (value) async {
                if (value.trim().isEmpty) return;

                setState(() => _isSearching = true);

                try {
                  final spendingService = context.read<SpendingService>();
                  final results = await spendingService.searchMessages(value);

                  if (!mounted) return;

                  FocusScope.of(context).unfocus();

                  showCupertinoSheet(
                    context: context,
                    builder: (context) => SearchMessagesSheet(
                      results: results,
                      query: value,
                      onMessageSelected: (tx) {
                        spendingService.selectTransaction(tx.id);
                      },
                    ),
                  );
                } catch (e) {
                  debugPrint('Search error: $e');
                } finally {
                  if (mounted) {
                    setState(() => _isSearching = false);
                  }
                }
              },
              placeholder: _showAnalytics ? '' : 'Search transactions...',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                color: const Color(0xFF1D1D1F),
              ),
              backgroundColor: Colors.transparent,
              borderRadius: BorderRadius.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showAnalytics ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: const SizedBox(
                  height: 44,
                  child: Center(child: AnimatedSpendingAnalytics()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    int hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '$hour:$minute $period';
  }

  Widget _buildTransactionCard(AppTransaction tx) {
    final spending = context.read<SpendingService>();
    final cat = spending.getCategoryByName(tx.category);

    return Container(
      key: ValueKey(tx.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Section
          Row(
            children: [
              // Category Icon (electric blue)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: cat != null && cat.icon is IconData
                    ? Icon(
                        cat.icon as IconData,
                        color: const Color(0xFF007AFF),
                        size: 20,
                      )
                    : HugeIcon(
                        icon: cat?.icon ?? HugeIcons.strokeRoundedTag01,
                        color: const Color(0xFF007AFF),
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.merchant,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1C1C1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mapped Location',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
          ),
          // Bottom Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.clock,
                    color: Color(0xFF007AFF),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(tx.timestamp),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.creditcard,
                    color: Color(0xFF007AFF),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tx.formattedAmount,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
