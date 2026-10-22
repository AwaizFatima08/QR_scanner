import 'package:flutter_test/flutter_test.dart';
import 'package:scanlink/core/scan_content.dart';

void main() {
  group('web links', () {
    test('https link opens as-is and shows the host', () {
      final c = ScanContent.parse('https://www.example.com/menu?table=4');
      expect(c.kind, ContentKind.url);
      expect(c.title, 'example.com');
      expect(c.action.toString(), 'https://www.example.com/menu?table=4');
      expect(c.insecure, isFalse);
    });

    test('http link is flagged as not secure', () {
      final c = ScanContent.parse('HTTP://shop.example.org/');
      expect(c.kind, ContentKind.url);
      expect(c.insecure, isTrue);
    });

    test('bare domain becomes an https link', () {
      final c = ScanContent.parse('example.com/promo');
      expect(c.kind, ContentKind.url);
      expect(c.action.toString(), 'https://example.com/promo');
    });

    test('surrounding whitespace is ignored', () {
      expect(ScanContent.parse('  https://a.io/x \n').action.toString(), 'https://a.io/x');
    });

    test('dangerous or unknown schemes are never opened as links', () {
      for (final raw in [
        'javascript:alert(1)',
        'intent://scan/#Intent;scheme=zxing;end',
        'file:///sdcard/secret.txt',
        'data:text/html,<b>hi</b>',
      ]) {
        final c = ScanContent.parse(raw);
        expect(c.kind, ContentKind.text, reason: raw);
        expect(c.action?.host, 'www.google.com', reason: '$raw is only searched, never launched');
      }
    });

    test('a sentence with a dot is text, not a link', () {
      expect(ScanContent.parse('Table 4. Thank you!').kind, ContentKind.text);
    });
  });

  group('other content', () {
    test('Wi-Fi with escaped characters', () {
      final c = ScanContent.parse(r'WIFI:T:WPA;S:Home\;Net;P:pa\:ss;H:true;;');
      expect(c.kind, ContentKind.wifi);
      expect(c.title, 'Home;Net');
      expect(c.fields['Password'], 'pa:ss');
      expect(c.fields['Security'], 'WPA');
      expect(c.fields['Hidden'], 'Yes');
      expect(c.action, isNull);
    });

    test('open Wi-Fi network', () {
      final c = ScanContent.parse('WIFI:S:Cafe;T:nopass;;');
      expect(c.fields['Security'], 'None (open)');
      expect(c.fields.containsKey('Password'), isFalse);
    });

    test('mailto with subject', () {
      final c = ScanContent.parse('mailto:info@example.com?subject=Hello%20there');
      expect(c.kind, ContentKind.email);
      expect(c.title, 'info@example.com');
      expect(c.fields['Subject'], 'Hello there');
      expect(c.action!.scheme, 'mailto');
    });

    test('MATMSG email encodes spaces as %20', () {
      final c = ScanContent.parse('MATMSG:TO:a@b.com;SUB:Hi there;BODY:See you;;');
      expect(c.kind, ContentKind.email);
      expect(c.action.toString(), 'mailto:a@b.com?subject=Hi%20there&body=See%20you');
    });

    test('plain email address', () {
      expect(ScanContent.parse('someone@example.pk').kind, ContentKind.email);
    });

    test('phone number', () {
      final c = ScanContent.parse('tel:+923001234567');
      expect(c.kind, ContentKind.phone);
      expect(c.action.toString(), 'tel:+923001234567');
    });

    test('SMSTO with message', () {
      final c = ScanContent.parse('SMSTO:+15551234:Running late');
      expect(c.kind, ContentKind.sms);
      expect(c.title, '+15551234');
      expect(c.action.toString(), 'sms:+15551234?body=Running%20late');
    });

    test('geo point opens maps', () {
      final c = ScanContent.parse('geo:24.8607,67.0011?q=Karachi');
      expect(c.kind, ContentKind.geo);
      expect(c.action!.host, 'www.google.com');
      expect(c.action!.queryParameters['query'], '24.8607,67.0011');
    });

    test('invalid geo point has no action', () {
      expect(ScanContent.parse('geo:999,0').action, isNull);
    });

    test('vCard', () {
      final c = ScanContent.parse(
        'BEGIN:VCARD\nVERSION:3.0\nN:Khan;Ayesha;;;\nORG:HomiLabs\nTEL;TYPE=CELL:+92300111\n'
        'EMAIL:ayesha@example.com\nEND:VCARD',
      );
      expect(c.kind, ContentKind.contact);
      expect(c.title, 'Ayesha Khan');
      expect(c.fields['Phone'], '+92300111');
      expect(c.action.toString(), 'tel:+92300111');
    });

    test('MECARD', () {
      final c = ScanContent.parse('MECARD:N:Ali,Raza;TEL:0300123;EMAIL:ali@x.com;;');
      expect(c.kind, ContentKind.contact);
      expect(c.title, 'Ali Raza');
      expect(c.fields['Email'], 'ali@x.com');
    });

    test('product barcode is looked up on the web', () {
      final c = ScanContent.parse('5012345678900', isProductFormat: true);
      expect(c.kind, ContentKind.product);
      expect(c.action!.queryParameters['q'], '5012345678900');
    });

    test('13 digits without a product format still count as a product', () {
      expect(ScanContent.parse('4006381333931').kind, ContentKind.product);
    });

    test('plain text offers a web search', () {
      final c = ScanContent.parse('Hello world');
      expect(c.kind, ContentKind.text);
      expect(c.action!.queryParameters['q'], 'Hello world');
    });

    test('empty code has no action', () {
      expect(ScanContent.parse('   ').action, isNull);
    });
  });
}
