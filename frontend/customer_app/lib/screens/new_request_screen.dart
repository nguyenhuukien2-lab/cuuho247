import '../core/utils/display_code.dart';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/user_session.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../services/request_photo_service.dart';
import '../services/customer_vehicle_service.dart';
import '../widgets/saved_vehicle_picker.dart';
import '../widgets/saved_address_picker.dart';
import '../services/customer_saved_address_service.dart';
import '../widgets/rescue_widgets.dart';
import '../widgets/booking_ui.dart';
import '../widgets/customer_ui.dart';
import '../widgets/rescue_location_map.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({
    super.key,
    required this.controller,
    this.locationService = const GeolocatorLocationService(),
    this.photoPicker = const DeviceRequestPhotoPicker(),
    this.photoRepository = const SupabaseRequestPhotoRepository(),
    this.addressRepository = const SupabaseCustomerSavedAddressRepository(),
    this.vehicleRepository = const SupabaseCustomerVehicleRepository(),
  });
  final AppController controller;
  final CustomerLocationService locationService;
  final RequestPhotoPicker photoPicker;
  final RequestPhotoRepository photoRepository;
  final CustomerVehicleRepository vehicleRepository;
  final CustomerSavedAddressRepository addressRepository;

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen>
    with AutomaticKeepAliveClientMixin {
  final formKey = GlobalKey<FormState>();
  final addressKey = GlobalKey<FormFieldState<String>>();
  final addressFocus = FocusNode();
  final nameKey = GlobalKey<FormFieldState<String>>();
  final phoneKey = GlobalKey<FormFieldState<String>>();
  final nameFocus = FocusNode();
  final phoneFocus = FocusNode();
  String? nameError;
  String? phoneError;
  final scrollController = ScrollController();
  String? addressError;
  late final TextEditingController address;
  late final TextEditingController description;
  late final TextEditingController name;
  late final TextEditingController phone;
  bool submitting = false;
  bool locationConfirmed = false;
  String? submitError;
  String? serviceError;
  String? clientRequestId;
  final photos = <SelectedRequestPhoto>[];
  final uploadedPhotos = <String>{};
  RescueRequestData? createdRequest;
  bool pickingPhoto = false;
  String? photoError;
  bool get formLocked => submitting || createdRequest != null;

  Future<void> recoverPhotos() async {
    try {
      final recovered = await widget.photoPicker.recoverLostPhotos();
      if (!mounted || recovered.isEmpty || photos.isNotEmpty || formLocked)
        return;
      setState(() {
        photos.addAll(recovered.take(3));
        photoError =
            'Đã khôi phục ảnh sau khi mở camera. Hãy kiểm tra ảnh và nhập lại thông tin trước khi gửi.';
      });
    } on AppFailure catch (error) {
      if (mounted) setState(() => photoError = error.message);
    }
  }

  Future<void> pickPhoto(bool camera) async {
    if (pickingPhoto || formLocked || photos.length >= 3) return;
    setState(() {
      pickingPhoto = true;
      photoError = null;
    });
    try {
      final photo = await widget.photoPicker.pick(camera: camera);
      if (!mounted || photo == null) return;
      setState(() => photos.add(photo));
    } on AppFailure catch (error) {
      if (mounted) setState(() => photoError = error.message);
    } finally {
      if (mounted) setState(() => pickingPhoto = false);
    }
  }

  LocationResult location = const LocationResult(
    LocationStatus.idle,
    'GPS giúp gửi kèm tọa độ hiện tại. Bạn vẫn cần nhập địa chỉ cụ thể và có thể gửi khi không dùng GPS.',
  );
  int _locationGeneration = 0;
  bool usingSavedAddress = false;

  void selectSavedAddress(CustomerSavedAddress saved) {
    if (formLocked) return;
    _locationGeneration++;
    setState(() {
      usingSavedAddress = true;
      address.text = saved.address;
      addressError = null;
      final coordinates = saved.latitude != null && saved.longitude != null
          ? RescueCoordinates(saved.latitude!, saved.longitude!)
          : null;
      location = LocationResult(
        coordinates == null ? LocationStatus.idle : LocationStatus.acquired,
        'Đã chọn địa chỉ ${saved.label}. Hãy kiểm tra và xác nhận vị trí cứu hộ.',
        coordinates: coordinates,
      );
      locationConfirmed = false;
    });
  }

  void selectMapLocation(RescueCoordinates point) {
    if (formLocked) return;
    _locationGeneration++;
    setState(() {
      usingSavedAddress = false;
      location = LocationResult(
        LocationStatus.acquired,
        'Đã chọn vị trí trên bản đồ. Hãy kiểm tra địa chỉ và xác nhận lại.',
        coordinates: point,
      );
      locationConfirmed = false;
    });
  }

  void addressEdited() {
    setState(() => addressError = null);
    if (usingSavedAddress) {
      usingSavedAddress = false;
      useManualAddress();
    } else {
      setState(() => locationConfirmed = false);
    }
  }

  Future<void> locate() async {
    if (formLocked || location.status == LocationStatus.loading) return;
    usingSavedAddress = false;
    final generation = ++_locationGeneration;
    setState(() {
      locationConfirmed = false;
      location = const LocationResult(
        LocationStatus.loading,
        'Bạn có thể tiếp tục nhập địa chỉ và gửi yêu cầu trong lúc chờ.',
      );
    });
    final result = await widget.locationService.getCurrentLocation();
    if (!mounted || generation != _locationGeneration) return;
    setState(() {
      location = result;
      locationConfirmed = false;
    });
  }

  void useManualAddress() {
    usingSavedAddress = false;
    _locationGeneration++;
    setState(() {
      location = const LocationResult(
        LocationStatus.idle,
        'Yêu cầu sẽ chỉ gửi địa chỉ bạn nhập.',
      );
      locationConfirmed = false;
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    address = TextEditingController();
    description = TextEditingController();
    name = TextEditingController(text: UserSession.fullName ?? '');
    phone = TextEditingController(text: UserSession.phoneNumber ?? '');
    recoverPhotos();
  }

  @override
  void dispose() {
    _locationGeneration++;
    address.dispose();
    description.dispose();
    name.dispose();
    phone.dispose();
    addressFocus.dispose();
    nameFocus.dispose();
    phoneFocus.dispose();
    scrollController.dispose();
    super.dispose();
  }

  int _step = 0;
  int _lastTabIndex = -1;
  void _goStep(int value) {
    FocusScope.of(context).unfocus();
    setState(() => _step = value);
    if (scrollController.hasClients) scrollController.jumpTo(0);
  }

  Future<void> _nextStep() async {
    if (_step == 0 && widget.controller.selectedService == null) {
      setState(() => serviceError = 'Vui lòng chọn loại sự cố.');
      return;
    }
    if (_step == 2 && address.text.trim().isEmpty) {
      await showAddressError();
      return;
    }
    _goStep(_step + 1);
  }

  Future<void> showAddressError() async {
    setState(() {
      _step = 2;
      addressError = 'Vui lòng nhập địa chỉ cứu hộ';
    });
    await WidgetsBinding.instance.endOfFrame;
    // SliverList can dispose the field when the submit button is visible.
    // Return to the top to mount it before revealing and focusing the field.
    if (addressKey.currentContext == null && scrollController.hasClients) {
      await scrollController.animateTo(
        0,
        duration: customerMotion(context),
        curve: Curves.easeOut,
      );
    }
    if (!mounted) return;
    final fieldContext = addressKey.currentContext;
    if (fieldContext != null) {
      await Scrollable.ensureVisible(
        fieldContext,
        duration: customerMotion(context),
        alignment: 0.2,
      );
    }
    if (mounted) addressFocus.requestFocus();
  }

  Future<void> showContactError(bool isName) async {
    setState(() {
      _step = 4;
      if (isName) {
        nameError = 'Vui lòng nhập họ tên';
      } else {
        phoneError = 'Vui lòng nhập số điện thoại';
      }
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final key = isName ? nameKey : phoneKey;
    if (key.currentContext == null && scrollController.hasClients) {
      await scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: customerMotion(context),
        curve: Curves.easeOut,
      );
    }
    if (!mounted) return;
    final fieldContext = key.currentContext;
    if (fieldContext != null)
      await Scrollable.ensureVisible(
        fieldContext,
        duration: customerMotion(context),
        alignment: 0.2,
      );
    if (mounted) (isName ? nameFocus : phoneFocus).requestFocus();
  }

  Future<void> submit() async {
    if (submitting || pickingPhoto) return;
    if (!widget.controller.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập trước khi tạo yêu cầu cứu hộ.'),
        ),
      );
      Navigator.pushNamed(context, '/login');
      return;
    }
    if (widget.controller.selectedService == null) {
      setState(() {
        _step = 0;
        serviceError = 'Vui lòng chọn loại sự cố.';
      });
      return;
    }
    // Validate controller text even if the address FormField is off-screen.
    final locationText = address.text.trim();
    if (locationText.isEmpty) {
      await showAddressError();
      return;
    }
    if (name.text.trim().isEmpty) {
      await showContactError(true);
      return;
    }
    if (phone.text.trim().isEmpty) {
      await showContactError(false);
      return;
    }
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (!locationConfirmed) {
      setState(
        () => submitError = 'Vui lòng xác nhận đây là vị trí cần cứu hộ.',
      );
      if (scrollController.hasClients) {
        await scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: customerMotion(context),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    setState(() {
      submitting = true;
      submitError = null;
      // A late GPS response must not attach coordinates to a manual submission.
      _locationGeneration++;
      if (location.status == LocationStatus.loading) {
        location = const LocationResult(
          LocationStatus.idle,
          'Yêu cầu sẽ chỉ gửi địa chỉ bạn nhập.',
        );
      }
    });
    clientRequestId ??= SupabaseService.newClientRequestId();
    try {
      final request = createdRequest ??
          await widget.controller.createRequest(
            clientRequestId: clientRequestId!,
            address: locationText,
            description: description.text.trim(),
            contactName: name.text.trim(),
            contactPhone: phone.text.trim(),
            latitude: location.coordinates?.latitude,
            longitude: location.coordinates?.longitude,
            openTracking: photos.isEmpty,
          );
      if (!mounted) return;
      if (photos.isNotEmpty) {
        // The P0 RPC can return a different existing active request. Never
        // silently attach this new draft's photos to that other request.
        if (request.clientRequestId != clientRequestId) {
          throw const AppFailure(
            'Bạn đã có yêu cầu đang xử lý khác. Ảnh chưa được gửi. Hãy mở tab Đang xử lý để kiểm tra đơn hiện tại.',
          );
        }
        createdRequest = request;
        for (final photo in photos) {
          if (uploadedPhotos.contains(photo.id)) continue;
          try {
            await widget.photoRepository.upload(request.id, photo);
          } on AppFailure catch (error) {
            throw AppFailure(
              'Đơn đã tạo. Đã gửi ${uploadedPhotos.length}/${photos.length} ảnh. ${error.message} Dữ liệu và ảnh vẫn được giữ; bấm Thử lại để tiếp tục.',
              sessionExpired: error.sessionExpired,
            );
          }
          if (!mounted) return;
          setState(() => uploadedPhotos.add(photo.id));
        }
        if (!mounted) return;
        photos.clear();
        uploadedPhotos.clear();
        createdRequest = null;
        widget.controller.selectTab(request.stage.isTerminal ? 3 : 2);
      }
      clientRequestId = null;
      if (!mounted) return;
      // IndexedStack keeps the form alive: never reuse GPS for the next order.
      useManualAddress();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 8, 16, 88),
          content: Text('Yêu cầu đã được máy chủ tiếp nhận.'),
        ),
      );
    } on AppFailure catch (error) {
      if (!mounted) return;
      setState(() => submitError = error.message);
      if (error.locationRequired) await showAddressError();
      if (!mounted) return;
      if (error.sessionExpired) Navigator.pushNamed(context, '/login');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    if (_lastTabIndex != controller.tabIndex) {
      if (controller.tabIndex == 1 &&
          _lastTabIndex != 1 &&
          createdRequest == null) {
        _step = 0;
      }
      _lastTabIndex = controller.tabIndex;
    }
    return Theme(
      data: BookingStyle.theme(context),
      child: Material(
        color: BookingStyle.background,
        child: Column(
          children: [
            CustomerAppHeader(onAccount: () => controller.selectTab(4)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: CustomerStepIndicator(
                step: _step,
                onStep: formLocked ? null : _goStep,
              ),
            ),
            Expanded(
              child: Form(
                key: formKey,
                child: CustomScrollView(
                  controller: scrollController,
                  key: const PageStorageKey('request-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: AppSpacing.page,
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              const [
                                'Chọn dịch vụ',
                                'Chọn xe',
                                'Vị trí cứu hộ',
                                'Mô tả / ảnh',
                                'Xác nhận yêu cầu',
                              ][_step],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: BookingStyle.ink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (controller.selectedService != null &&
                                _step > 0) ...[
                              SelectedServiceCard(
                                service: controller.selectedService!,
                                onChange: formLocked ? null : () => _goStep(0),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (createdRequest != null) ...[
                              InlineNotice(
                                'Đơn ${displayCode(createdRequest!.requestCode)} đã tạo. Đã gửi ${uploadedPhotos.length}/${photos.length} ảnh. Thử lại sẽ chỉ gửi ảnh còn thiếu.',
                                isError: false,
                              ),
                              const SizedBox(height: 24),
                            ],
                            Visibility(
                              key: const ValueKey('request-section-0'),
                              visible: _step == 0,
                              maintainState: true,
                              child: CustomerCard(
                                icon: Icons.build_outlined,
                                title: 'Sự cố',
                                children: [
                                  ServiceGrid(
                                    selectedColor: BookingStyle.blue,
                                    selectedBackground: BookingStyle.pale,
                                    selected: controller.selectedService,
                                    onSelected: formLocked
                                        ? null
                                        : (service) {
                                            controller.selectService(service);
                                            setState(() => serviceError = null);
                                          },
                                  ),
                                  if (serviceError != null) ...[
                                    const SizedBox(height: 8),
                                    InlineNotice(serviceError!),
                                  ],
                                ],
                              ),
                            ),
                            if (_step == 0) const SizedBox(height: 16),
                            Visibility(
                              key: const ValueKey('request-section-1'),
                              visible: _step == 1,
                              maintainState: true,
                              child: CustomerCard(
                                icon: Icons.directions_car_outlined,
                                title: 'Chọn phương tiện gặp sự cố',
                                children: [
                                  SavedVehiclePicker(
                                    cardLayout: true,
                                    controller: controller,
                                    locked: formLocked,
                                    repository: widget.vehicleRepository,
                                  ),
                                  const SizedBox(height: 8),
                                  AnimatedContainer(
                                    duration: customerMotion(context, 160),
                                    decoration: BoxDecoration(
                                      color: AppColors.selected,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: DropdownButtonFormField<VehicleKind>(
                                      initialValue: controller.vehicle,
                                      key: ValueKey(controller.vehicle),
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Loại phương tiện',
                                        prefixIcon: Icon(
                                          vehicleIcon(controller.vehicle),
                                        ),
                                      ),
                                      items: VehicleKind.values
                                          .map(
                                            (kind) => DropdownMenuItem(
                                              value: kind,
                                              child: Text(kind.label),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: formLocked
                                          ? null
                                          : (kind) {
                                              if (kind != null)
                                                setState(
                                                  () => controller
                                                      .selectVehicle(kind),
                                                );
                                            },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_step == 1) const SizedBox(height: 16),
                            Visibility(
                              key: const ValueKey('request-section-2'),
                              visible: _step == 2,
                              maintainState: true,
                              child: CustomerCard(
                                icon: Icons.location_on_outlined,
                                title: 'Lộ trình cứu hộ',
                                subtitle:
                                    'Địa chỉ cụ thể là bắt buộc, kể cả khi có GPS.',
                                children: [
                                  RouteCard(
                                    address: address.text.trim(),
                                    coordinates: location.coordinates,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    key: addressKey,
                                    focusNode: addressFocus,
                                    controller: address,
                                    readOnly: formLocked,
                                    textInputAction: TextInputAction.next,
                                    minLines: 1,
                                    maxLines: 3,
                                    onChanged: (_) => addressEdited(),
                                    decoration: InputDecoration(
                                      labelText: 'Địa chỉ',
                                      hintText:
                                          'Số nhà, đường, khu vực hoặc mốc dễ nhận biết',
                                      errorText: addressError,
                                      prefixIcon: const Icon(
                                        Icons.location_on_outlined,
                                      ),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Vui lòng nhập địa chỉ cứu hộ'
                                            : null,
                                  ),
                                  const SizedBox(height: 12),
                                  SavedAddressPicker(
                                    controller: controller,
                                    locked: formLocked,
                                    repository: widget.addressRepository,
                                    onSelected: selectSavedAddress,
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.selected,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.my_location_rounded,
                                              color: AppColors.navy,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                switch (location.status) {
                                                  LocationStatus.idle =>
                                                    'Chưa lấy vị trí',
                                                  LocationStatus.loading =>
                                                    'Đang lấy vị trí…',
                                                  LocationStatus.acquired =>
                                                    'Đã lấy vị trí',
                                                  LocationStatus.denied =>
                                                    'Bạn đã từ chối quyền vị trí',
                                                  LocationStatus.unavailable =>
                                                    'Không hỗ trợ/lỗi vị trí',
                                                },
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(location.message),
                                        if (location.coordinates != null) ...[
                                          const SizedBox(height: 8),
                                          SelectableText(
                                            'Tọa độ: ${location.coordinates!.label}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                        if (location.status ==
                                            LocationStatus.loading) ...[
                                          const SizedBox(height: 8),
                                          const LinearProgressIndicator(),
                                        ],
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          onPressed: formLocked ||
                                                  location.status ==
                                                      LocationStatus.loading
                                              ? null
                                              : locate,
                                          icon: const Icon(
                                            Icons.my_location_rounded,
                                          ),
                                          label: const Text(
                                            'Lấy vị trí hiện tại',
                                          ),
                                        ),
                                        if (location.status !=
                                            LocationStatus.idle)
                                          TextButton(
                                            onPressed: formLocked
                                                ? null
                                                : useManualAddress,
                                            child: const Text(
                                              'Chỉ dùng địa chỉ nhập tay',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  RescueLocationMap(
                                    coordinates: location.coordinates,
                                    showDefaultLocation: true,
                                    locked: formLocked,
                                    onSelected: selectMapLocation,
                                  ),
                                ],
                              ),
                            ),
                            if (_step == 2) const SizedBox(height: 16),
                            Visibility(
                              key: const ValueKey('request-section-3'),
                              visible: _step == 3,
                              maintainState: true,
                              child: CustomerCard(
                                icon: Icons.photo_camera_outlined,
                                title: 'Mô tả sự cố & Hiện trường',
                                subtitle:
                                    'Tùy chọn · Tối đa 3 ảnh, 5 MB mỗi ảnh',
                                children: [
                                  Visibility(
                                    key: const ValueKey('request-section-4'),
                                    visible: true,
                                    maintainState: true,
                                    child: TextFormField(
                                      controller: description,
                                      readOnly: formLocked,
                                      minLines: 2,
                                      maxLines: 5,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Tình trạng xe, dấu hiệu sự cố…',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('${photos.length}/3 hình ảnh',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: BookingStyle.muted)),
                                  const SizedBox(height: 8),
                                  PhotoPickerGrid(
                                    photos: photos,
                                    uploaded: uploadedPhotos,
                                    onRemove: formLocked || pickingPhoto
                                        ? null
                                        : (slot) => setState(
                                              () => photos.removeAt(slot),
                                            ),
                                    onAdd: formLocked ||
                                            pickingPhoto ||
                                            photos.length >= 3
                                        ? null
                                        : () => pickPhoto(false),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: formLocked ||
                                                  pickingPhoto ||
                                                  photos.length >= 3
                                              ? null
                                              : () => pickPhoto(true),
                                          icon: const Icon(
                                            Icons.add_a_photo_outlined,
                                          ),
                                          label: const Text('Chụp ảnh'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: formLocked ||
                                                  pickingPhoto ||
                                                  photos.length >= 3
                                              ? null
                                              : () => pickPhoto(false),
                                          icon: const Icon(
                                            Icons.photo_library_outlined,
                                          ),
                                          label: const Text('Chọn ảnh'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (pickingPhoto)
                                    const LinearProgressIndicator(),
                                  if (photoError != null) ...[
                                    const SizedBox(height: 8),
                                    InlineNotice(photoError!),
                                  ],
                                ],
                              ),
                            ),
                            if (_step == 3) const SizedBox(height: 16),
                            Visibility(
                              key: const ValueKey('request-section-5'),
                              visible: _step == 4,
                              maintainState: true,
                              child: CustomerCard(
                                icon: Icons.person_outline_rounded,
                                title: 'Thông tin liên hệ',
                                children: [
                                  TextFormField(
                                    key: nameKey,
                                    focusNode: nameFocus,
                                    controller: name,
                                    readOnly: formLocked,
                                    onChanged: (_) =>
                                        setState(() => nameError = null),
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      labelText: 'Họ và tên',
                                      errorText: nameError,
                                      prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                      ),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Vui lòng nhập họ tên'
                                            : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    key: phoneKey,
                                    focusNode: phoneFocus,
                                    controller: phone,
                                    readOnly: formLocked,
                                    onChanged: (_) =>
                                        setState(() => phoneError = null),
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      labelText: 'Số điện thoại',
                                      errorText: phoneError,
                                      prefixIcon: const Icon(
                                        Icons.phone_outlined,
                                      ),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Vui lòng nhập số điện thoại'
                                            : null,
                                  ),
                                ],
                              ),
                            ),
                            if (_step == 4) const SizedBox(height: 16),
                            if (_step == 4) ...[
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        controller.selectedService?.label ??
                                            'Chưa chọn dịch vụ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(controller
                                              .selectedSavedVehicle?.label ??
                                          controller.vehicle.label),
                                      Text(
                                        address.text.trim().isEmpty
                                            ? 'Chưa có địa chỉ'
                                            : address.text.trim(),
                                      ),
                                      if (photos.isNotEmpty)
                                        Text('${photos.length} ảnh sự cố'),
                                    ],
                                  ),
                                ),
                              ),
                              const SectionTitle('Xác nhận yêu cầu'),
                              CheckboxListTile(
                                value: locationConfirmed,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text(
                                  'Tôi xác nhận đây là vị trí cần cứu hộ',
                                ),
                                subtitle: const Text(
                                  'Kiểm tra địa chỉ và tọa độ (nếu có) trước khi gửi.',
                                ),
                                onChanged: formLocked
                                    ? null
                                    : (value) => setState(
                                          () => locationConfirmed =
                                              value ?? false,
                                        ),
                              ),
                            ],
                            if (submitError != null) ...[
                              const SizedBox(height: 12),
                              InlineNotice(
                                submitError!,
                                onRetry: submitting ? null : submit,
                              ),
                            ],
                            if (_step == 4) ...[
                              const SizedBox(height: 16),
                              const QuoteSummaryCard(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PrimaryActionButton(
                        label: _step < 4
                            ? 'Tiếp tục'
                            : createdRequest == null
                                ? 'XÁC NHẬN ĐẶT CỨU HỘ'
                                : 'Gửi lại ảnh còn thiếu',
                        loading: submitting,
                        onPressed: pickingPhoto || submitting
                            ? null
                            : _step < 4
                                ? _nextStep
                                : submit,
                      ),
                      if (_step == 4)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Đối tác sẽ tiếp nhận và phản hồi sớm.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: BookingStyle.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
