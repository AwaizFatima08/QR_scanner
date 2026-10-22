/// What a scanned code contains, worked out from its raw text alone, so the
/// camera, a gallery photo and the history all go through the same rules.
library;

enum ContentKind { url, email, phone, sms, geo, wifi, contact, product, text }

class ScanContent {
  const ScanContent._({
    required this.kind,
    required this.raw,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.fields = const {},
    this.insecure = false,
  });

  final ContentKind kind;

  /// The exact text stored in the code.
  final String raw;

  /// Short, human-readable summary (the host of a link, a phone number, ...).
  final String title;
  final String? subtitle;

  /// What "Open" does; null when there is nothing safe to open.
  final Uri? action;
  final String? actionLabel;

  /// Extra details shown in the result sheet (Wi-Fi password, contact name, ...).
  final Map<String, String> fields;

  /// A plain http:// link: shown with a "not secure" warning.
  final bool insecure;

  bool get isLink => kind == ContentKind.url;

  /// Classifies [raw]. [isProductFormat] is true for retail barcodes
  /// (EAN-8/13, UPC-A/E), whose digits are looked up on the web.
  factory ScanContent.parse(String raw, {bool isProductFormat = false}) {
    final text = raw.trim();
    final lower = text.toLowerCase();

    if (lower.startsWith('wifi:')) return _wifi(raw, text);
    if (lower.startsWith('begin:vcard') || lower.startsWith('mecard:')) return _contact(raw, text);
    if (lower.startsWith('mailto:')) return _email(raw, Uri.tryParse(text));
    if (lower.startsWith('matmsg:')) return _matmsg(raw, text);
    if (lower.startsWith('tel:')) return _phone(raw, text.substring(4));
    if (lower.startsWith('smsto:') || lower.startsWith('sms:')) return _sms(raw, text);
    if (lower.startsWith('geo:')) return _geo(raw, text);

    final link = _asWebLink(text);
    if (link != null) return _url(raw, link);

    if (_emailPattern.hasMatch(text)) return _email(raw, Uri(scheme: 'mailto', path: text));
    if (isProductFormat || _productPattern.hasMatch(text)) {
      return ScanContent._(
        kind: ContentKind.product,
        raw: raw,
        title: text,
        subtitle: 'Product barcode',
        action: _search(text),
        actionLabel: 'Look up product',
      );
    }
    return ScanContent._(
      kind: ContentKind.text,
      raw: raw,
      title: text.isEmpty ? '(empty code)' : text,
      action: text.isEmpty ? null : _search(text),
      actionLabel: text.isEmpty ? null : 'Search the web',
    );
  }

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[a-z]{2,}$', caseSensitive: false);
  static final _productPattern = RegExp(r'^\d{8}$|^\d{12,13}$');
  static final _bareDomain = RegExp(
    r'^(www\.)?[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}(:\d+)?([/?#]\S*)?$',
    caseSensitive: false,
  );

  static Uri _search(String q) => Uri.https('www.google.com', '/search', {'q': q});

  /// Only http(s) links, or bare domains like "example.com/menu", count as
  /// links. Other schemes (intent:, javascript:, file:, ...) are shown as text
  /// and never opened.
  static Uri? _asWebLink(String text) {
    if (text.contains(RegExp(r'\s'))) return null;
    final lower = text.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final uri = Uri.tryParse(text);
      return (uri != null && uri.host.isNotEmpty) ? uri : null;
    }
    if (_bareDomain.hasMatch(text)) return Uri.tryParse('https://$text');
    return null;
  }

  static ScanContent _url(String raw, Uri uri) {
    final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
    return ScanContent._(
      kind: ContentKind.url,
      raw: raw,
      title: host,
      subtitle: uri.toString(),
      action: uri,
      actionLabel: 'Open link',
      insecure: uri.scheme == 'http',
    );
  }

  static ScanContent _email(String raw, Uri? uri) {
    final address = uri?.path ?? '';
    final q = uri?.queryParameters ?? const {};
    return ScanContent._(
      kind: ContentKind.email,
      raw: raw,
      title: address.isEmpty ? 'Email' : address,
      subtitle: q['subject'],
      action: address.isEmpty ? null : uri,
      actionLabel: 'Write email',
      fields: {
        for (final (label, value) in [('Subject', q['subject']), ('Message', q['body'])])
          if (value != null && value.isNotEmpty) label: value,
      },
    );
  }

  /// MATMSG:TO:a@b.com;SUB:Hi;BODY:Text;;
  static ScanContent _matmsg(String raw, String text) {
    final f = _fields(text.substring(7));
    final to = f['TO'] ?? '';
    return _email(raw, _withQuery('mailto', to, {'subject': f['SUB'] ?? '', 'body': f['BODY'] ?? ''}));
  }

  static ScanContent _phone(String raw, String number) {
    final n = number.trim();
    return ScanContent._(
      kind: ContentKind.phone,
      raw: raw,
      title: n,
      action: n.isEmpty ? null : Uri(scheme: 'tel', path: n),
      actionLabel: 'Call',
    );
  }

  /// SMSTO:+123:message  or  sms:+123?body=message
  static ScanContent _sms(String raw, String text) {
    String number;
    String message = '';
    if (text.toLowerCase().startsWith('smsto:')) {
      final rest = text.substring(6);
      final i = rest.indexOf(':');
      number = i < 0 ? rest : rest.substring(0, i);
      message = i < 0 ? '' : rest.substring(i + 1);
    } else {
      final uri = Uri.tryParse(text);
      number = uri?.path ?? text.substring(4);
      message = uri?.queryParameters['body'] ?? '';
    }
    number = number.trim();
    return ScanContent._(
      kind: ContentKind.sms,
      raw: raw,
      title: number.isEmpty ? 'Text message' : number,
      subtitle: message.isEmpty ? null : message,
      action: number.isEmpty ? null : _withQuery('sms', number, {'body': message}),
      actionLabel: 'Send text message',
      fields: {if (message.isNotEmpty) 'Message': message},
    );
  }

  static ScanContent _geo(String raw, String text) {
    final coords = text.substring(4).split(RegExp(r'[?;]')).first;
    final parts = coords.split(',');
    final lat = parts.isNotEmpty ? double.tryParse(parts[0]) : null;
    final lng = parts.length > 1 ? double.tryParse(parts[1]) : null;
    final ok = lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180;
    return ScanContent._(
      kind: ContentKind.geo,
      raw: raw,
      title: ok ? '$lat, $lng' : 'Location',
      subtitle: 'Map location',
      action: ok ? Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$lat,$lng'}) : null,
      actionLabel: 'Show on map',
    );
  }

  /// WIFI:T:WPA;S:MyNet;P:secret;H:false;;
  static ScanContent _wifi(String raw, String text) {
    final f = _fields(text.substring(5));
    final ssid = f['S'] ?? '';
    final type = (f['T'] ?? '').toUpperCase();
    return ScanContent._(
      kind: ContentKind.wifi,
      raw: raw,
      title: ssid.isEmpty ? 'Wi-Fi network' : ssid,
      subtitle: 'Wi-Fi network',
      fields: {
        'Network': ssid,
        'Security': switch (type) {
          '' || 'NOPASS' => 'None (open)',
          _ => type,
        },
        if ((f['P'] ?? '').isNotEmpty) 'Password': f['P']!,
        if ((f['H'] ?? '').toLowerCase() == 'true') 'Hidden': 'Yes',
      },
    );
  }

  static ScanContent _contact(String raw, String text) {
    final lower = text.toLowerCase();
    final f = <String, String>{};
    if (lower.startsWith('mecard:')) {
      final m = _fields(text.substring(7));
      void put(String label, String key) {
        final v = m[key];
        if (v != null && v.isNotEmpty) f[label] = v.replaceAll(',', ' ').trim();
      }

      put('Name', 'N');
      put('Organisation', 'ORG');
      put('Phone', 'TEL');
      put('Email', 'EMAIL');
      put('Website', 'URL');
      put('Address', 'ADR');
    } else {
      for (final line in text.split(RegExp(r'\r?\n'))) {
        final i = line.indexOf(':');
        if (i < 0) continue;
        final key = line.substring(0, i).split(';').first.toUpperCase();
        final value = line.substring(i + 1).trim();
        if (value.isEmpty) continue;
        final label = switch (key) {
          'FN' => 'Name',
          'ORG' => 'Organisation',
          'TITLE' => 'Job title',
          'TEL' => 'Phone',
          'EMAIL' => 'Email',
          'URL' => 'Website',
          'ADR' => 'Address',
          _ => null,
        };
        if (label != null && !f.containsKey(label)) {
          f[label] = value.replaceAll(';', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        }
      }
      if (!f.containsKey('Name')) {
        final n = RegExp(r'^N[;:](?:[^:\n]*:)?(.*)$', multiLine: true).firstMatch(text);
        if (n != null) {
          final parts = n.group(1)!.split(';').where((s) => s.trim().isNotEmpty).toList();
          if (parts.length > 1) parts.insert(0, parts.removeAt(1)); // given name first
          if (parts.isNotEmpty) f['Name'] = parts.join(' ');
        }
      }
    }
    final phone = f['Phone'];
    return ScanContent._(
      kind: ContentKind.contact,
      raw: raw,
      title: f['Name'] ?? f['Organisation'] ?? 'Contact',
      subtitle: 'Contact card',
      fields: f,
      action: phone == null ? null : Uri(scheme: 'tel', path: phone),
      actionLabel: 'Call',
    );
  }

  /// Splits "K:v;K2:v2;;" fields (Wi-Fi, MECARD, MATMSG), honouring "\;" escapes.
  static Map<String, String> _fields(String body) {
    final out = <String, String>{};
    final buf = StringBuffer();
    final parts = <String>[];
    for (var i = 0; i < body.length; i++) {
      final ch = body[i];
      if (ch == r'\' && i + 1 < body.length) {
        buf.write(body[++i]);
      } else if (ch == ';') {
        parts.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) parts.add(buf.toString());
    for (final p in parts) {
      final i = p.indexOf(':');
      if (i <= 0) continue;
      out.putIfAbsent(p.substring(0, i).toUpperCase(), () => p.substring(i + 1));
    }
    return out;
  }
}

/// Builds e.g. mailto:a@b.com?subject=Hi%20there. Spaces are encoded as %20,
/// not "+", which mail and SMS apps would otherwise show literally.
Uri _withQuery(String scheme, String path, Map<String, String> params) {
  final q = params.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return Uri(scheme: scheme, path: path, query: q.isEmpty ? null : q);
}
