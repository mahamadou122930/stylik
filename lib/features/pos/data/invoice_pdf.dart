import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show networkImage;

import '../../../core/utils/formatters.dart';
import '../../settings/domain/salon.dart';
import '../domain/ticket.dart';

/// Génération du ticket / facture au format thermique 80 mm pour salon de coiffure.
///
/// Les salons de coiffure utilisent quasi-exclusivement des imprimantes tickets
/// de 80 mm (Epson, Sunmi, Xprinter, Star, etc.). Ce document est calibré sur
/// un rouleau continu de 80 mm (`PdfPageFormat.roll80`) et reprend fidèlement
/// la disposition visuelle de `ReceiptPage` pour l'impression thermique et le
/// partage WhatsApp / client.
abstract final class InvoicePdf {
  /// Format standard rouleau thermique 80 mm (largeur 80 mm, hauteur dynamique).
  static const PdfPageFormat format80mm = PdfPageFormat(
    80 * PdfPageFormat.mm,
    double.infinity,
    marginLeft: 5 * PdfPageFormat.mm,
    marginRight: 5 * PdfPageFormat.mm,
    marginTop: 6 * PdfPageFormat.mm,
    marginBottom: 8 * PdfPageFormat.mm,
  );

  /// Vert de l'identité, repris de `AppColors.primary`.
  static const PdfColor _primary = PdfColor.fromInt(0xFF0C7A50);
  static const PdfColor _ink = PdfColor.fromInt(0xFF17231C);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6C7870);
  static const PdfColor _line = PdfColor.fromInt(0xFFE2E7DE);
  static const PdfColor _tintGreen = PdfColor.fromInt(0xFFE8F5EE);
  static const PdfColor _tintExpense = PdfColor.fromInt(0xFFFDECE9);
  static const PdfColor _expense = PdfColor.fromInt(0xFFC0432C);

  /// Polices de la maquette (Sora pour les titres/chiffres, Manrope pour le texte).
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> _loadTheme() async {
    if (_theme != null) return _theme!;

    final sora = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Sora-VariableFont_wght.ttf'),
    );
    final manrope = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
    );

    return _theme = pw.ThemeData.withFont(base: manrope, bold: sora);
  }

  /// Glyphe Stylik en SVG blanc pour le badge logo par défaut.
  static String? _glyphSvg;

  static Future<String?> _loadGlyphSvg() async {
    if (_glyphSvg != null) return _glyphSvg;
    try {
      final raw = await rootBundle.loadString('assets/icons/glyph.svg');
      return _glyphSvg = raw.replaceAll('#0F9560', '#FFFFFF');
    } catch (_) {
      return null;
    }
  }

  /// Logo du salon, téléchargé pour être incorporé au document.
  static Future<pw.ImageProvider?> _logo(Salon? salon) async {
    final url = salon?.logoUrl;
    if (url == null || url.isEmpty) return null;

    try {
      return await networkImage(url);
    } catch (_) {
      return null;
    }
  }

  /// Construit le ticket de caisse 80 mm et renvoie ses octets.
  static Future<List<int>> build({
    required SalonTransaction transaction,
    Salon? salon,
    PdfPageFormat format = format80mm,
  }) async {
    final document = pw.Document(
      title: 'Facture ${transaction.invoiceNumber}',
      author: salon?.name,
      theme: await _loadTheme(),
    );

    final logo = await _logo(salon);
    final glyphSvg = await _loadGlyphSvg();

    document.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(transaction, salon, logo, glyphSvg),
            if (transaction.clientName != null) ...[_billedTo(transaction)],
            _lines(transaction),
            _totals(transaction),
            _payment(transaction),
            _footer(),
          ],
        ),
      ),
    );

    return document.save();
  }

  /// En-tête : logo/glyphe et infos facture en haut, nom du salon et adresse en dessous.
  static pw.Widget _header(
    SalonTransaction transaction,
    Salon? salon,
    pw.ImageProvider? logo,
    String? glyphSvg,
  ) {
    final contact = [
      if (salon?.address.isNotEmpty ?? false) salon!.address,
      if (salon?.phone.isNotEmpty ?? false) salon!.phone,
    ].join(' · ');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 36,
                height: 36,
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(9),
                  image: pw.DecorationImage(image: logo, fit: pw.BoxFit.cover),
                ),
              )
            else
              pw.Container(
                width: 36,
                height: 36,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: _primary,
                  borderRadius: pw.BorderRadius.circular(9),
                ),
                child: glyphSvg != null
                    ? pw.SvgImage(svg: glyphSvg)
                    : pw.SizedBox(),
              ),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Facture',
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  '#${transaction.invoiceNumber}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                if (transaction.createdAt != null) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    Formatters.dayMonthYear(transaction.createdAt!),
                    style: const pw.TextStyle(fontSize: 8, color: _muted),
                  ),
                ],
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          salon?.name ?? 'Stylik',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        if (contact.isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            contact,
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Divider(
          color: _line,
          thickness: 0.8,
          borderStyle: pw.BorderStyle.dashed,
        ),
      ],
    );
  }

  /// Bloc client « Facturé à ».
  static pw.Widget _billedTo(SalonTransaction transaction) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        pw.Text(
          'Facturé à',
          style: const pw.TextStyle(fontSize: 7.5, color: _muted),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          transaction.clientName!,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        if (transaction.clientPhone?.isNotEmpty ?? false) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            transaction.clientPhone!,
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Divider(color: _line, thickness: 0.8),
      ],
    );
  }

  /// Liste des prestations et produits achetés.
  static pw.Widget _lines(SalonTransaction transaction) {
    return pw.Column(
      children: [
        for (var i = 0; i < transaction.lines.length; i++) ...[
          if (i > 0) pw.Divider(color: _line, thickness: 0.5),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        transaction.lines[i].label,
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        [
                          if (transaction.lines[i].category?.isNotEmpty ??
                              false)
                            transaction.lines[i].category!,
                          'x${transaction.lines[i].quantity}',
                        ].join(' · '),
                        style: const pw.TextStyle(fontSize: 7.5, color: _muted),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  Formatters.fcfa(transaction.lines[i].totalFcfa),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
        pw.Divider(color: _line, thickness: 0.8),
      ],
    );
  }

  /// Sous-total, remise éventuelle et total dû.
  static pw.Widget _totals(SalonTransaction transaction) {
    final hasDiscount = transaction.discountFcfa > 0;

    return pw.Column(
      children: [
        pw.SizedBox(height: 6),
        if (hasDiscount) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Sous-total',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
              pw.Text(
                Formatters.fcfa(transaction.subtotalFcfa),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Remise',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
              pw.Text(
                '− ${Formatters.fcfa(transaction.discountFcfa)}',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _primary,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
        ],
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.Text(
              Formatters.fcfa(transaction.totalAmountFcfa),
              style: pw.TextStyle(
                fontSize: 13.5,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(
          color: _line,
          thickness: 0.8,
          borderStyle: pw.BorderStyle.dashed,
        ),
      ],
    );
  }

  /// Statut de paiement et référence de transaction.
  static pw.Widget _payment(SalonTransaction transaction) {
    final refunded = transaction.isRefund;
    final label = refunded
        ? 'Remboursé'
        : 'Payé · ${transaction.paymentMethod.label}';

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: pw.BoxDecoration(
              color: refunded ? _tintExpense : _tintGreen,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: refunded ? _expense : _primary,
              ),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              'Réf. ${transaction.reference.replaceFirst('#', '')}',
              style: const pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
          ),
        ],
      ),
    );
  }

  /// Pied de ticket.
  static pw.Widget _footer() {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Center(
        child: pw.Text(
          'Merci de votre confiance.',
          style: const pw.TextStyle(fontSize: 7.5, color: _muted),
        ),
      ),
    );
  }
}
