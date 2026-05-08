/// Request payload to register a new device.
final class DeviceRegisterRequest {
  const DeviceRegisterRequest({
    required this.stableDeviceKey,
    required this.platform,
    this.deviceName,
    this.osVersion,
    this.appVersion,
    this.pushToken,
    this.metadata = const {},
  });

  /// Stable, idempotent key that uniquely identifies this device installation.
  /// Example: a UUID stored in secure storage on first launch.
  final String stableDeviceKey;

  /// Platform identifier (e.g. 'android', 'ios', 'macos', 'windows', 'linux').
  final String platform;
  final String? deviceName;
  final String? osVersion;
  final String? appVersion;
  final String? pushToken;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'stable_device_key': stableDeviceKey,
        'platform': platform,
        if (deviceName != null) 'device_name': deviceName,
        if (osVersion != null) 'os_version': osVersion,
        if (appVersion != null) 'app_version': appVersion,
        if (pushToken != null) 'push_token': pushToken,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

/// Request payload to update an existing registered device.
final class DeviceUpdateRequest {
  const DeviceUpdateRequest({
    this.deviceName,
    this.osVersion,
    this.appVersion,
    this.pushToken,
    this.metadata,
  });

  final String? deviceName;
  final String? osVersion;
  final String? appVersion;
  final String? pushToken;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
        if (deviceName != null) 'device_name': deviceName,
        if (osVersion != null) 'os_version': osVersion,
        if (appVersion != null) 'app_version': appVersion,
        if (pushToken != null) 'push_token': pushToken,
        if (metadata != null) 'metadata': metadata,
      };
}

/// A device that has been successfully registered with the backend.
final class RegisteredDevice {
  const RegisteredDevice({
    required this.id,
    required this.stableDeviceKey,
    required this.platform,
    this.deviceName,
    this.registeredAt,
  });

  final String id;
  final String stableDeviceKey;
  final String platform;
  final String? deviceName;
  final DateTime? registeredAt;

  factory RegisteredDevice.fromJson(Map<String, dynamic> json) =>
      RegisteredDevice(
        id: json['id'] as String,
        stableDeviceKey: json['stable_device_key'] as String,
        platform: json['platform'] as String,
        deviceName: json['device_name'] as String?,
        registeredAt: json['registered_at'] != null
            ? DateTime.parse(json['registered_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'stable_device_key': stableDeviceKey,
        'platform': platform,
        if (deviceName != null) 'device_name': deviceName,
        if (registeredAt != null)
          'registered_at': registeredAt!.toIso8601String(),
      };

  @override
  String toString() => 'RegisteredDevice(id: $id, platform: $platform)';
}
