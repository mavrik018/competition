import 'dart:typed_data';

import 'package:competition_toolkit/12_common_features/data_export.dart';
import 'package:competition_toolkit/12_common_features/file_rules.dart';
import 'package:competition_toolkit/12_common_features/location_service.dart';
import 'package:competition_toolkit/12_common_features/media_picker.dart';
import 'package:competition_toolkit/12_common_features/ocr.dart';
import 'package:competition_toolkit/12_common_features/qr_code.dart';
import 'package:competition_toolkit/12_common_features/reminder_scheduler.dart';
import 'package:competition_toolkit/12_common_features/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Uint8List bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  group('FileRules', () {
    final jpeg = bytes([0xFF, 0xD8, 0xFF, 0xE0, 1, 2]);
    final png = bytes([0x89, 0x50, 0x4E, 0x47, 0, 0]);

    test('extension, size, empty and content checks', () {
      const rules = FileRules(
        maxBytes: 10,
        allowedExtensions: {'jpg', 'png', 'pdf'},
      );
      expect(rules.check('photo.JPG', jpeg), isNull);
      expect(
        rules.check('notes.txt', jpeg),
        'Only JPG, PDF, PNG files are allowed.',
      );
      expect(
        rules.check('big.png', Uint8List(20)),
        startsWith('That file is 20 B.'),
      );
      expect(rules.check('empty.png', Uint8List(0)), 'That file is empty.');
      expect(
        rules.check('fake.jpg', png),
        "That file's contents don't match its .jpg name.",
      );
      expect(
        const FileRules(checkContent: false).check('fake.jpg', png),
        isNull,
      );
    });

    test('helpers', () {
      expect(extensionOf('a.tar.GZ'), 'gz');
      expect(extensionOf('README'), '');
      expect(mimeTypeFor('x.pdf'), 'application/pdf');
      expect(mimeTypeFor('x.unknown'), 'application/octet-stream');
      expect(isImageFile('x.webp'), isTrue);
      expect(sniffFileType(bytes([0x25, 0x50, 0x44, 0x46, 0x2D])), 'pdf');
      expect(sniffFileType(bytes([1, 2, 3])), isNull);
    });
  });

  test('FakeMediaPicker returns queued results and filters files', () async {
    final picker = FakeMediaPicker(
      images: [
        PickedMedia(name: 'a.jpg', bytes: bytes([1])),
        null,
      ],
      files: [
        PickedMedia(name: 'r.pdf', bytes: bytes([1])),
        PickedMedia(name: 'd.csv', bytes: bytes([1])),
      ],
    );
    expect(
      (await picker.pickImage(source: MediaSource.camera))!.isImage,
      isTrue,
    );
    expect(await picker.pickImage(), isNull); // simulated cancel
    expect(
      (await picker.pickFiles(allowedExtensions: ['csv'])).single.name,
      'd.csv',
    );
    expect(await picker.pickFiles(multiple: true), hasLength(2));
    expect(picker.calls.first, 'pickImage(camera)');
  });

  group('QR payloads', () {
    test('parse common formats', () {
      expect(parseQr('https://example.com/x'), isA<QrUrl>());
      final wifi = parseQr(r'WIFI:T:WPA;S:Cafe\;Guest;P:p\:ss;;') as QrWifi;
      expect(
        [wifi.ssid, wifi.password, wifi.security],
        ['Cafe;Guest', 'p:ss', 'WPA'],
      );
      expect((parseQr('mailto:a@b.co?subject=Hi') as QrEmail).subject, 'Hi');
      expect(
        (parseQr('SMSTO:+123:hello: there') as QrSms).message,
        'hello: there',
      );
      expect((parseQr('tel:+44123') as QrPhone).number, '+44123');
      expect((parseQr('geo:51.5,-0.12') as QrGeo).longitude, -0.12);
      final contact =
          parseQr(
                'BEGIN:VCARD\nVERSION:3.0\nFN:Ana Lima\nTEL;TYPE=CELL:+351 900\nEND:VCARD',
              )
              as QrContact;
      expect([contact.name, contact.phone], ['Ana Lima', '+351 900']);
      final link =
          parseQr('myapp://checkin?event=42', appSchemes: {'myapp'})
              as QrAppLink;
      expect([link.path, link.params['event']], ['checkin', '42']);
      expect(parseQr('myapp://checkin'), isA<QrText>()); // scheme not trusted
      expect(parseQr('hello'), isA<QrText>());
    });

    test('encode round-trips through parse', () {
      const payloads = <QrPayload>[
        QrWifi(ssid: 'Home;Net', password: 'a,b"c'),
        QrWifi(ssid: 'Open', security: 'nopass'),
        QrEmail('x@y.io', subject: 'A & B'),
        QrSms('+1555', 'hi'),
        QrGeo(1.5, -2.25),
        QrContact(name: 'Ana', phone: '+1', email: 'a@b.c'),
        QrAppLink('myapp', 'invite', {'code': 'XY12'}),
      ];
      for (final payload in payloads) {
        final parsed = parseQr(payload.encode(), appSchemes: {'myapp'});
        expect(
          parsed.runtimeType,
          payload.runtimeType,
          reason: payload.encode(),
        );
        expect(parsed.encode(), payload.encode());
      }
    });

    testWidgets('QrCodeView renders', (tester) async {
      await tester.pumpWidget(
        wrap(const Center(child: QrCodeView(data: 'https://example.com'))),
      );
      expect(find.bySemanticsLabel('QR code'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('OCR extraction (rule-based)', () {
    const receipt = '''
SUPERMART LTD
www.supermart.example
Tel: +44 20 7946 0958
Date: 14/10/2026 18:42
Milk          1.20
Bread         2.35
Subtotal      3.55
VAT           0.71
TOTAL        £4.26
Card payment  4.26
Thanks! help@supermart.example
''';

    test('finds total, amounts, dates and contacts', () {
      final data = extractFromText(receipt);
      expect(data.total, 4.26);
      expect(data.amounts, [1.20, 2.35, 3.55, 0.71, 4.26, 4.26]);
      expect(data.dates, [DateTime(2026, 10, 14)]);
      expect(data.emails, ['help@supermart.example']);
      expect(data.phones, ['+44 20 7946 0958']);
      expect(data.urls, ['www.supermart.example']);
    });

    test('date formats, month-first and invalid dates', () {
      final data = extractFromText(
        '2026-03-05, Oct 9, 2026, 3 Jan 2027, 31/02/2026',
      );
      expect(data.dates, [
        DateTime(2026, 3, 5),
        DateTime(2026, 10, 9),
        DateTime(2027, 1, 3),
      ]);
      expect(extractFromText('03/05/2026', monthFirst: true).dates, [
        DateTime(2026, 3, 5),
      ]);
    });

    test('thousands separators and fallback total', () {
      final data = extractFromText('Laptop 1,299.00\nMouse 25.50');
      expect(data.amounts, [1299.00, 25.50]);
      expect(data.total, 1299.00); // no total line → largest amount
      expect(extractFromText('no numbers here').total, isNull);
    });

    test('FakeTextRecognizer is a labelled double', () async {
      final fake = FakeTextRecognizer('TOTAL 9.99');
      expect(
        extractFromText(await fake.recognizeFile('/tmp/x.jpg')).total,
        9.99,
      );
      expect(fake.recognizedPaths, ['/tmp/x.jpg']);
    });
  });

  group('Location', () {
    const london = GeoPoint(51.5072, -0.1276);
    const paris = GeoPoint(48.8566, 2.3522);
    const brighton = GeoPoint(50.8225, -0.1372);

    test('geofence and nearest places', () {
      const fence = Geofence(london, radiusMeters: 500);
      expect(fence.contains(const GeoPoint(51.5090, -0.1280)), isTrue);
      expect(fence.contains(brighton), isFalse);
      final near = nearestPlaces(
        [paris, brighton],
        london,
        positionOf: (p) => p,
        limit: 1,
      );
      expect(near.single.item, brighton);
      expect(near.single.km, closeTo(76, 3));
      expect(
        nearestPlaces(
          [paris, brighton],
          london,
          positionOf: (p) => p,
          maxKm: 100,
        ),
        hasLength(1),
      );
    });

    test('FakeLocationService plays back a route or a problem', () async {
      final fake = FakeLocationService([london, brighton]);
      expect(await fake.currentPosition(), london);
      expect(await fake.positions().toList(), [london, brighton]);
      final denied = FakeLocationService(
        const [],
        problem: LocationProblem.deniedForever,
      );
      await expectLater(
        denied.currentPosition(),
        throwsA(
          isA<LocationException>().having(
            (e) => e.message,
            'message',
            contains('Settings'),
          ),
        ),
      );
    });
  });

  test('FakeShareService records shares', () async {
    final share = FakeShareService();
    await share.shareText('Hi');
    await share.shareFile(
      name: 'a.csv',
      bytes: bytes([1, 2]),
      mimeType: 'text/csv',
    );
    expect(share.shared.map((s) => s.fileName), [null, 'a.csv']);
    expect(share.shared.last.bytes, 2);
  });

  group('Data export', () {
    test('CSV escapes and round-trips', () {
      final rows = [
        ['Name', 'Note', 'Amount'],
        ['Ana', 'said "hi", left', 1.5],
        ['Bo', 'line1\nline2', null],
      ];
      final csv = toCsv(rows);
      expect(csv.split('\r\n').first, 'Name,Note,Amount');
      expect(csv, contains('"said ""hi"", left"'));
      expect(parseCsv(csv), [
        ['Name', 'Note', 'Amount'],
        ['Ana', 'said "hi", left', '1.5'],
        ['Bo', 'line1\nline2', ''],
      ]);
      expect(csvToMaps(parseCsv(csv)).first, {
        'Name': 'Ana',
        'Note': 'said "hi", left',
        'Amount': '1.5',
      });
    });

    test('parseCsv handles BOM, LF and semicolons', () {
      expect(parseCsv('﻿a;b\n1;2\n', separator: ';'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
      expect(utf8Bytes('é', bom: true), [0xEF, 0xBB, 0xBF, 0xC3, 0xA9]);
      expect(toPrettyJson({'a': 1}), '{\n  "a": 1\n}');
    });

    test('buildPdfReport produces a multi-page PDF', () async {
      final pdf = await buildPdfReport(
        title: 'Report',
        subtitle: 'October',
        summary: {'Total': '42'},
        headers: ['Item', 'Qty'],
        rows: [
          for (var i = 0; i < 120; i++) ['Item $i', '$i'],
        ],
      );
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      expect(pdf.length, greaterThan(2000));
    });
  });

  test('nextDailyOccurrence', () {
    final now = DateTime(2026, 10, 14, 9, 30);
    expect(nextDailyOccurrence(10, 0, now), DateTime(2026, 10, 14, 10));
    expect(nextDailyOccurrence(9, 30, now), DateTime(2026, 10, 15, 9, 30));
    expect(
      nextDailyOccurrence(8, 0, DateTime(2026, 12, 31, 23)),
      DateTime(2027, 1, 1, 8),
    );
  });
}
