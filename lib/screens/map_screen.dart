import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_popup/flutter_popup.dart';

import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/call_out_result.dart';
import '../models/category_item.dart';
import '../models/map_place.dart';
import '../repositories/transaction_repository.dart';
import '../services/sms_service.dart';
import '../services/spending_service.dart';
import '../utils/marker_utils.dart';
import '../widgets/dynamic_island.dart';
import '../widgets/category_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  bool _islandExpanded = false;
  bool _amountsVisible = false;
  late AnimationController _bounceController;
  late Animation<double> _bounceScale;

  mp.PointAnnotationManager? _annotationManager;
  bool _isAnimating = false;
  List<MapPlace> _places = [];
  mp.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;
  StreamSubscription? _bgServiceSub;

  int _annotationUpdateVersion = 0;

  final GlobalKey<CustomPopupState> _popupKey = GlobalKey<CustomPopupState>();
  mp.ScreenCoordinate? _popupPosition;
  MapPlace? _selectedPlace;

  final List<CategoryItem> _availableIcons = [
    CategoryItem(
      name: 'Home',
      icon: HugeIcons.strokeRoundedHome01,
      color: CupertinoColors.systemIndigo,
    ),
    CategoryItem(
      name: 'Shopping',
      icon: HugeIcons.strokeRoundedShoppingCart01,
      color: CupertinoColors.systemGreen,
    ),
    CategoryItem(
      name: 'Dining',
      icon: HugeIcons.strokeRoundedRestaurant01,
      color: CupertinoColors.systemOrange,
    ),
    CategoryItem(
      name: 'Transport',
      icon: HugeIcons.strokeRoundedCar01,
      color: CupertinoColors.systemBlue,
    ),
    CategoryItem(
      name: 'Health',
      icon: HugeIcons.strokeRoundedHospital01,
      color: CupertinoColors.systemRed,
    ),
    CategoryItem(
      name: 'Bills',
      icon: HugeIcons.strokeRoundedIdea01,
      color: CupertinoColors.systemYellow,
    ),
    CategoryItem(
      name: 'Travel',
      icon: HugeIcons.strokeRoundedAirplane01,
      color: CupertinoColors.systemTeal,
    ),
    CategoryItem(
      name: 'Entertainment',
      icon: HugeIcons.strokeRoundedTicket01,
      color: CupertinoColors.systemPurple,
    ),
    CategoryItem(
      name: 'Education',
      icon: HugeIcons.strokeRoundedBook01,
      color: CupertinoColors.systemBrown,
    ),
    CategoryItem(
      name: 'Music',
      icon: HugeIcons.strokeRoundedMusicNote01,
      color: CupertinoColors.systemPink,
    ),
    CategoryItem(
      name: 'Fitness',
      icon: HugeIcons.strokeRoundedDumbbell01,
      color: CupertinoColors.activeBlue,
    ),
    CategoryItem(
      name: 'Work',
      icon: HugeIcons.strokeRoundedBriefcase01,
      color: CupertinoColors.activeGreen,
    ),
    CategoryItem(
      name: 'Hobby',
      icon: HugeIcons.strokeRoundedCamera01,
      color: CupertinoColors.systemCyan,
    ),
    CategoryItem(
      name: 'Pizza',
      icon: HugeIcons.strokeRoundedPizza01,
      color: CupertinoColors.systemOrange,
    ),
    CategoryItem(
      name: 'Bus',
      icon: HugeIcons.strokeRoundedBus01,
      color: CupertinoColors.systemYellow,
    ),
    CategoryItem(
      name: 'Bicycle',
      icon: HugeIcons.strokeRoundedBicycle,
      color: CupertinoColors.systemGreen,
    ),
    CategoryItem(
      name: 'Groceries',
      icon: HugeIcons.strokeRoundedApple01,
      color: CupertinoColors.systemRed,
    ),
    CategoryItem(
      name: 'Sports',
      icon: HugeIcons.strokeRoundedBasketball01,
      color: CupertinoColors.systemOrange,
    ),
    CategoryItem(
      name: 'Nightlife',
      icon: HugeIcons.strokeRoundedMoon01,
      color: CupertinoColors.systemIndigo,
    ),
    CategoryItem(
      name: 'Favorite',
      icon: HugeIcons.strokeRoundedStar,
      color: CupertinoColors.systemYellow,
    ),
    CategoryItem(
      name: 'Clothing',
      icon: HugeIcons.strokeRoundedTShirt,
      color: CupertinoColors.systemBlue,
    ),
    CategoryItem(
      name: 'Audio',
      icon: HugeIcons.strokeRoundedHeadphones,
      color: CupertinoColors.systemPink,
    ),
    CategoryItem(
      name: 'Security',
      icon: HugeIcons.strokeRoundedKey01,
      color: CupertinoColors.systemGrey2,
    ),
    CategoryItem(
      name: 'Tech',
      icon: HugeIcons.strokeRoundedLaptop,
      color: CupertinoColors.systemBlue,
    ),
    CategoryItem(
      name: 'Cloud',
      icon: HugeIcons.strokeRoundedCloud,
      color: CupertinoColors.systemGreen,
    ),
    CategoryItem(
      name: 'Passport',
      icon: HugeIcons.strokeRoundedPassport,
      color: CupertinoColors.systemTeal,
    ),
    CategoryItem(
      name: 'Weather',
      icon: HugeIcons.strokeRoundedUmbrella,
      color: CupertinoColors.systemBlue,
    ),
    CategoryItem(
      name: 'Finance',
      icon: HugeIcons.strokeRoundedWallet01,
      color: CupertinoColors.systemBrown,
    ),
    CategoryItem(
      name: 'Gaming',
      icon: HugeIcons.strokeRoundedGameController01,
      color: CupertinoColors.systemPurple,
    ),
    CategoryItem(
      name: 'Tools',
      icon: HugeIcons.strokeRoundedPencil,
      color: CupertinoColors.systemGrey,
    ),
    CategoryItem(
      name: 'Phone',
      icon: HugeIcons.strokeRoundedSmartPhone01,
      color: CupertinoColors.systemMint,
    ),
  ];

  // Initialised once onMapCreated fires
  SmsService? _smsService;

  @override
  void initState() {
    super.initState();
    _positionTracking();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.95,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
    ]).animate(_bounceController);

    // Listen for background service events to trigger Dynamic Island
    _bgServiceSub = FlutterBackgroundService().on('transaction_saved').listen((
      _,
    ) {
      _triggerIslandAutoExpand();
      if (mounted) {
        context.read<SpendingService>().refresh();
      }
    });

    FlutterBackgroundService().on('location_attached').listen((_) {
      if (mounted) {
        context.read<SpendingService>().refresh();
      }
    });
  }

  void _triggerIslandAutoExpand() {
    if (!mounted) return;
    setState(() {
      _amountsVisible = true;
      _islandExpanded = true;
    });

    // Fold back up after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _amountsVisible = false;
          _islandExpanded = false;
        });
        _bounceController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    userPositionStream?.cancel();
    _bgServiceSub?.cancel();
    mapboxMapController?.dispose();
    _smsService?.dispose();

    // Remove listener to prevent memory leaks
    final spending = Provider.of<SpendingService>(context, listen: false);
    spending.removeListener(_refreshAnnotations);

    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 12;
    final spending = context.watch<SpendingService>();

    // Sync places with spending service mapped transactions
    final saved = spending.mappedTransactions;
    _places = saved
        .map(
          (tx) => MapPlace(
            id: tx.id,
            name: tx.merchant,
            price: tx.formattedAmount,
            latitude: tx.latitude!,
            longitude: tx.longitude!,
            rawMessage: tx.rawMessage,
            category: tx.category,
          ),
        )
        .toList();

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          mp.MapWidget(
            styleUri: mp.MapboxStyles.LIGHT,
            onMapCreated: onMapCreated,
          ),
          Positioned(
            top: topPadding,
            left: 16,
            right: 16,
            child: DynamicIsland(
              spent: spending.spent,
              limit: spending.limit,
              amountsVisible: _amountsVisible,
              islandExpanded: _islandExpanded,
              selectedPeriod: spending.period,
              bounceScale: _bounceScale,
              onTapCircle: () {
                setState(() => _amountsVisible = true);
                _bounceController.value = 0.0;
              },
              onTapClose: () {
                setState(() {
                  _amountsVisible = false;
                  _islandExpanded = false;
                });
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) _bounceController.forward(from: 0.0);
                });
              },
              onToggleExpand: () =>
                  setState(() => _islandExpanded = !_islandExpanded),
              onTapEditLimit: () => _showLimitSettings(spending),
              onPeriodSelected: (period) =>
                  context.read<SpendingService>().setPeriod(period),
            ),
          ),
          // FABs moved into the stack as Positioned widgets
          Positioned(
            bottom: 32,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _flyToUserLocation,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: CupertinoColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.location_fill,
                      color: CupertinoColors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_places.isNotEmpty)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isAnimating ? null : _animateAnnotations,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isAnimating
                            ? CupertinoColors.systemGrey
                            : CupertinoColors.black,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 10,
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
                              color: CupertinoColors.white,
                            ),
                    ),
                  ),
              ],
            ),
          ),
          if (_popupPosition != null)
            Positioned(
              left: _popupPosition!.x,
              top: _popupPosition!.y,
              child: CustomPopup(
                key: _popupKey,
                contentPadding: EdgeInsets.zero,
                content: DefaultTextStyle(
                  style: GoogleFonts.spaceGrotesk(
                    color: CupertinoColors.label,
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
                                .getCategoryByName(_selectedPlace?.category);
                            return CustomPopup(
                              barrierColor: CupertinoColors.transparent,
                              contentPadding: EdgeInsets.zero,
                              content: _buildCategoryDropdown(
                                context,
                                _selectedPlace!,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: cat == null
                                      ? CupertinoColors.systemGrey5
                                      : cat.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (cat != null) ...[
                                      HugeIcon(
                                        icon: cat.icon,
                                        color: cat.color,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      _selectedPlace?.category ??
                                          'Set Category',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: cat == null
                                            ? CupertinoColors.systemGrey
                                            : cat.color,
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
                          color: CupertinoColors.systemGrey5,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedPlace?.rawMessage ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: CupertinoColors.label,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                child: const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(BuildContext context, MapPlace place) {
    final spending = context.read<SpendingService>();
    final categories = spending.categories;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = place.category == cat.name;
                return GestureDetector(
                  onTap: () {
                    spending.updateCategory(place.id, cat.name);
                    // Navigator.pop(context); // Close the popup
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: isSelected
                        ? CupertinoColors.systemGrey6
                        : CupertinoColors.white,
                    child: Row(
                      children: [
                        HugeIcon(icon: cat.icon, color: cat.color, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            cat.name,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(height: 1, color: CupertinoColors.systemGrey5),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.pop(context);
              _showCreateCategorySheet(place);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              width: double.infinity,
              alignment: Alignment.centerLeft,
              child: Text(
                '+ Create New',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateCategorySheet(MapPlace place) {
    showCupertinoSheet(
      context: context,
      builder: (context) =>
          CreateCategorySheet(place: place, availableIcons: _availableIcons),
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

  // ── Map ────────────────────────────────────────────────────────────────────

  Future<void> onMapCreated(mp.MapboxMap controller) async {
    setState(() => mapboxMapController = controller);

    final locationPermission = await Permission.location.status;
    if (locationPermission != PermissionStatus.granted) return;

    mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: false),
    );

    _annotationManager = await mapboxMapController?.annotations
        .createPointAnnotationManager();

    // Handle marker taps using modern API
    _annotationManager?.tapEvents(
      onTap: (annotation) async {
        final place = _places.firstWhere(
          (p) =>
              (p.longitude - annotation.geometry.coordinates.lng).abs() <
                  0.0001 &&
              (p.latitude - annotation.geometry.coordinates.lat).abs() < 0.0001,
          orElse: () => _places.first,
        );

        final screenCoord = await mapboxMapController?.pixelForCoordinate(
          annotation.geometry,
        );

        if (screenCoord != null && mounted) {
          setState(() {
            _selectedPlace = place;
            _popupPosition = screenCoord;
          });

          // Show popup in next frame after Positioned has moved the anchor
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _popupKey.currentState?.show();
          });
        }
      },
    );

    if (!mounted) return;
    final spending = context.read<SpendingService>();
    _smsService = SmsService(repo: TransactionRepository(), spending: spending);
    await _smsService!.init();

    // The build method will handle syncing _places and rendering annotations
    // via its reactivity to SpendingService.
    // However, we need to trigger the first set of annotations manually
    // or rely on the build method's reactivity if we wrap annotation creation.
    // Let's add a listener to spending service to refresh annotations.
    spending.addListener(_refreshAnnotations);
    _refreshAnnotations();
  }

  void _refreshAnnotations() async {
    if (_annotationManager == null) return;

    final spending = context.read<SpendingService>();
    // Skip updates during the loading phase to avoid redundant/stale redrawing
    if (spending.isLoading) return;

    // Versioning prevents rapid consecutive refreshes from
    // clobbering each other (race conditions).
    final int currentVersion = ++_annotationUpdateVersion;

    final saved = spending.mappedTransactions;

    final newPlaces = saved
        .map(
          (tx) => MapPlace(
            id: tx.id,
            name: tx.merchant,
            price: tx.formattedAmount,
            latitude: tx.latitude!,
            longitude: tx.longitude!,
            rawMessage: tx.rawMessage,
            category: tx.category,
          ),
        )
        .toList();

    await _annotationManager?.deleteAll();

    // If a newer refresh has started, abort this outdated one.
    if (currentVersion != _annotationUpdateVersion || !mounted) return;

    await _addAllAnnotations(newPlaces);
  }

  Future<void> _addAllAnnotations(List<MapPlace> places) async {
    final spending = context.read<SpendingService>();

    // Generate all callout images in parallel to speed up the process
    final List<Future<mp.PointAnnotationOptions>> futures = places.map((
      place,
    ) async {
      final cat = spending.getCategoryByName(place.category);
      final CalloutResult callout = await createCalloutImage(
        place.name,
        place.price,
        color: cat?.color,
      );

      return mp.PointAnnotationOptions(
        image: callout.image,
        iconSize: 1.5,
        iconOpacity: 1.0,
        geometry: mp.Point(
          coordinates: mp.Position(place.longitude, place.latitude),
        ),
      );
    }).toList();

    final List<mp.PointAnnotationOptions> optionsList = await Future.wait(
      futures,
    );

    // Batch create all annotations in a single platform call
    await _annotationManager?.createMulti(optionsList);
  }

  // ── Animate FAB ────────────────────────────────────────────────────────────

  Future<void> _animateAnnotations() async {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    await _annotationManager?.deleteAll();
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
        zoom: 11.7,
        center: mp.Point(
          coordinates: mp.Position(place.longitude, place.latitude),
        ),
      ),
      mp.MapAnimationOptions(duration: 1000),
    );

    if (!mounted) return;
    final spending = context.read<SpendingService>();
    final cat = spending.getCategoryByName(place.category);
    final CalloutResult callout = await createCalloutImage(
      place.name,
      place.price,
      color: cat?.color,
    );

    final mp.PointAnnotation? calloutAnnotation = await _annotationManager
        ?.create(
          mp.PointAnnotationOptions(
            image: callout.image,
            iconSize: 1.5,
            iconOpacity: 0.0,
            geometry: mp.Point(
              coordinates: mp.Position(place.longitude, place.latitude),
            ),
          ),
        );

    await _fadeInAnnotations(calloutAnnotation);
  }

  Future<void> _fadeInAnnotations(mp.PointAnnotation? callout) async {
    for (int i = 1; i <= 25; i++) {
      final double opacity = i / 25;
      if (callout != null) {
        callout.iconOpacity = opacity;
        await _annotationManager?.update(callout);
      }
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  void _showLimitSettings(SpendingService spending) {
    final controller = TextEditingController(
      text: spending.limit.toStringAsFixed(0),
    );
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Set ${spending.period} Limit'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text('Ksh '),
            ),
            placeholder: 'Limit Amount',
            style: GoogleFonts.spaceGrotesk(),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0.0;
              spending.setLimit(spending.period, amount);
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}
