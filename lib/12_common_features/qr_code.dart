/// QR codes: understand what a scanned code means (URL, Wi-Fi, email, SMS,
/// phone, location, contact, your own app link), build codes in those
/// formats, render them, and scan them with the camera.
///
/// Newly written. Couple rendered invite codes with `pretty_qr_code` but
/// had no scanner or payload parsing. Parsing is pure Dart and unit-tested;
/// the scanner widget needs a camera (device-only, not unit-tested).
///
/// ```dart
/// // Show a code (e.g. an event check-in or a pairing invite):
/// QrCodeView(data: const QrAppLink('myapp', 'checkin', {'event': '42'}).encode())
///
/// // Scan one:
/// QrScannerView(
///   appSchemes: const {'myapp'},
///   onScanned: (payload) => switch (payload) {
///     QrAppLink(:final path, :final params) when path == 'checkin' => checkIn(params['event']!),
///     QrUrl(:final uri) => launchUrl(uri),
///     _ => showUnsupported(),
///   },
/// )
/// ```
///
/// **Platform setup for scanning** (`mobile_scanner`): iOS `Info.plist`
/// `NSCameraUsageDescription`; Android works with the default manifest. On
/// the web, scanning needs HTTPS.
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../01_design_system/app_tokens.dart';

sealed class QrPayload {
  const QrPayload();

  /// The text to put in a QR code for this payload.
  String encode();
}

class QrUrl extends QrPayload {
  const QrUrl(this.uri);
  final Uri uri;
  @override
  String encode() => uri.toString();
}

class QrWifi extends QrPayload {
  const QrWifi({
    required this.ssid,
    this.password = '',
    this.security = 'WPA',
    this.hidden = false,
  });
  final String ssid;
  final String password;

  /// `WPA`, `WEP` or `nopass`.
  final String security;
  final bool hidden;

  @override
  String encode() =>
      'WIFI:T:$security;S:${_escape(ssid)};'
      '${security == 'nopass' ? '' : 'P:${_escape(password)};'}'
      '${hidden ? 'H:true;' : ''};';
}

class QrEmail extends QrPayload {
  const QrEmail(this.address, {this.subject, this.body});
  final String address;
  final String? subject;
  final String? body;
  @override
  String encode() => Uri(
    scheme: 'mailto',
    path: address,
    query: _query({'subject': subject, 'body': body}),
  ).toString();
}

class QrPhone extends QrPayload {
  const QrPhone(this.number);
  final String number;
  @override
  String encode() => 'tel:$number';
}

class QrSms extends QrPayload {
  const QrSms(this.number, [this.message]);
  final String number;
  final String? message;
  @override
  String encode() => 'SMSTO:$number${message == null ? '' : ':$message'}';
}

class QrGeo extends QrPayload {
  const QrGeo(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
  @override
  String encode() => 'geo:$latitude,$longitude';
}

/// A minimal vCard: name, phone, email.
class QrContact extends QrPayload {
  const QrContact({required this.name, this.phone, this.email});
  final String name;
  final String? phone;
  final String? email;
  @override
  String encode() => [
    'BEGIN:VCARD',
    'VERSION:3.0',
    'FN:$name',
    if (phone != null) 'TEL:$phone',
    if (email != null) 'EMAIL:$email',
    'END:VCARD',
  ].join('\n');
}

/// Your app's own code, e.g. `myapp://checkin?event=42`.
class QrAppLink extends QrPayload {
  const QrAppLink(this.scheme, this.path, [this.params = const {}]);
  final String scheme;

  /// `checkin` for `myapp://checkin?...`.
  final String path;
  final Map<String, String> params;
  @override
  String encode() => Uri(
    scheme: scheme,
    host: path,
    queryParameters: params.isEmpty ? null : params,
  ).toString();
}

class QrText extends QrPayload {
  const QrText(this.text);
  final String text;
  @override
  String encode() => text;
}

/// Classifies a scanned string. [appSchemes] are your own deep-link schemes
/// (without `://`); anything unrecognised becomes [QrText].
QrPayload parseQr(String raw, {Set<String> appSchemes = const {}}) {
  final text = raw.trim();
  final upper = text.toUpperCase();

  if (upper.startsWith('WIFI:')) {
    final fields = _wifiFields(text.substring(5));
    return QrWifi(
      ssid: fields['S'] ?? '',
      password: fields['P'] ?? '',
      security: fields['T']?.isNotEmpty == true ? fields['T']! : 'nopass',
      hidden: fields['H']?.toLowerCase() == 'true',
    );
  }
  if (upper.startsWith('BEGIN:VCARD')) {
    String? field(String key) {
      for (final line in text.split(RegExp(r'\r?\n'))) {
        final colon = line.indexOf(':');
        if (colon < 0) continue;
        // `TEL;TYPE=CELL:+44…` → key `TEL`.
        if (line.substring(0, colon).split(';').first.toUpperCase() == key) {
          return line.substring(colon + 1).trim();
        }
      }
      return null;
    }

    return QrContact(
      name: field('FN') ?? field('N') ?? '',
      phone: field('TEL'),
      email: field('EMAIL'),
    );
  }
  if (upper.startsWith('SMSTO:')) {
    final parts = text.substring(6).split(':');
    return QrSms(
      parts.first,
      parts.length > 1 ? parts.sublist(1).join(':') : null,
    );
  }
  if (upper.startsWith('TEL:')) return QrPhone(text.substring(4));
  if (upper.startsWith('GEO:')) {
    final coords = text.substring(4).split(RegExp('[,;?]'));
    final lat = coords.isNotEmpty ? double.tryParse(coords[0]) : null;
    final lng = coords.length > 1 ? double.tryParse(coords[1]) : null;
    if (lat != null && lng != null) return QrGeo(lat, lng);
  }
  if (upper.startsWith('MAILTO:')) {
    final uri = Uri.tryParse(text);
    if (uri != null) {
      return QrEmail(
        uri.path,
        subject: uri.queryParameters['subject'],
        body: uri.queryParameters['body'],
      );
    }
  }

  final uri = Uri.tryParse(text);
  if (uri != null && appSchemes.contains(uri.scheme.toLowerCase())) {
    return QrAppLink(
      uri.scheme,
      uri.host.isNotEmpty ? uri.host : uri.path,
      uri.queryParameters,
    );
  }
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty) {
    return QrUrl(uri);
  }
  return QrText(text);
}

/// `T:WPA;S:My\;Net;P:pa\:ss;;` → {T: WPA, S: My;Net, P: pa:ss}.
Map<String, String> _wifiFields(String body) {
  final fields = <String, String>{};
  final buffer = StringBuffer();
  String? key;
  for (var i = 0; i < body.length; i++) {
    final char = body[i];
    if (char == r'\' && i + 1 < body.length) {
      buffer.write(body[++i]); // escaped character
    } else if (char == ':' && key == null) {
      key = buffer.toString().toUpperCase();
      buffer.clear();
    } else if (char == ';') {
      if (key != null) fields[key] = buffer.toString();
      key = null;
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  return fields;
}

String _escape(String value) =>
    value.replaceAllMapped(RegExp(r'([\\;,:"])'), (m) => '\\${m[1]}');

String? _query(Map<String, String?> params) {
  final entries = params.entries.where(
    (e) => e.value != null && e.value!.isNotEmpty,
  );
  if (entries.isEmpty) return null;
  return entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value!)}')
      .join('&');
}

/// Renders [data] as a QR code on a white tile (codes need contrast to
/// scan, even in dark mode).
class QrCodeView extends StatelessWidget {
  const QrCodeView({
    super.key,
    required this.data,
    this.size = 200,
    this.semanticLabel,
  });

  final String data;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel ?? 'QR code',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.06),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: PrettyQrView.data(
          data: data,
          decoration: const PrettyQrDecoration(
            shape: PrettyQrSmoothSymbol(color: Colors.black),
          ),
        ),
      ),
    );
  }
}

/// A camera viewfinder that reports each distinct code once. Includes a
/// torch toggle and a "type the code instead" fallback for when the camera
/// is unavailable or denied. **Device-only**: needs a camera.
class QrScannerView extends StatefulWidget {
  const QrScannerView({
    super.key,
    required this.onScanned,
    this.appSchemes = const {},
    this.onManualEntry,
  });

  final void Function(QrPayload payload) onScanned;
  final Set<String> appSchemes;

  /// Shown as a "Type code" button; omit to hide.
  final VoidCallback? onManualEntry;

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  String? _last;
  DateTime _lastAt = DateTime(0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detected(BarcodeCapture capture) {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    // The camera reports the same code many times per second.
    final now = DateTime.now();
    if (raw == _last && now.difference(_lastAt) < const Duration(seconds: 3)) {
      return;
    }
    _last = raw;
    _lastAt = now;
    widget.onScanned(parseQr(raw, appSchemes: widget.appSchemes));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _detected,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Text(
                error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Camera access is off. Allow it in Settings, or type the code.'
                    : "The camera couldn't start.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.primary, width: 3),
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
          ),
        ),
        Positioned(
          bottom: Gap.lg,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: Gap.md,
            children: [
              IconButton.filledTonal(
                tooltip: 'Torch',
                icon: const Icon(Icons.flashlight_on_outlined),
                onPressed: _controller.toggleTorch,
              ),
              if (widget.onManualEntry != null)
                FilledButton.tonal(
                  onPressed: widget.onManualEntry,
                  child: const Text('Type code'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
