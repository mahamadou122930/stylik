import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show networkImage;

import '../../../core/utils/formatters.dart';
import '../../settings/domain/salon.dart';
import '../domain/ticket.dart';

/// Génération du document de facture remis au client.
///
/// Volontairement à l'écart des widgets Flutter : `package:pdf` a son propre
/// arbre de composition, et mélanger les deux dans l'écran rendrait la page
/// illisible. Le rendu suit la même mise en page que `ReceiptPage` pour que le
/// document imprimé et l'écran ne se contredisent pas.
abstract final class InvoicePdf {
  /// Vert de l'identité, repris de `AppColors.primary`.
  static const PdfColor _primary = PdfColor.fromInt(0xFF0C7A50);
  static const PdfColor _ink = PdfColor.fromInt(0xFF17231C);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6C7870);
  static const PdfColor _line = PdfColor.fromInt(0xFFE6EBE1);

  /// Polices de la maquette, déjà embarquées dans l'app.
  ///
  /// Indispensable : les polices par défaut de `package:pdf` (Helvetica) ne
  /// gèrent pas l'Unicode, et une facture française pleine d'accents —
  /// « Facturé à », « Réf. », « Espèces » — sortirait avec des caractères
  /// erronés. Chargées une fois puis mémorisées, la lecture d'un fichier de
  /// police à chaque impression étant inutile.
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

  /// Logo du salon, téléchargé pour être incorporé au document.
  ///
  /// `null` si le salon n'en a pas déposé, ou si l'image est injoignable —
  /// une facture doit sortir même hors ligne, sans logo plutôt que pas du tout.
  static Future<pw.ImageProvider?> _logo(Salon? salon) async {
    final url = salon?.logoUrl;
    if (url == null || url.isEmpty) return null;

    try {
      return await networkImage(url);
    } catch (_) {
      return null;
    }
  }

  /// Construit la facture et renvoie ses octets, prêts à imprimer ou partager.
  static Future<List<int>> build({
    required SalonTransaction transaction,
    Salon? salon,
  }) async {
    final document = pw.Document(
      title: 'Facture ${transaction.invoiceNumber}',
      author: salon?.name,
      theme: await _loadTheme(),
    );
    final logo = await _logo(salon);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(transaction, salon, logo),
            pw.SizedBox(height: 22),
            if (transaction.clientName != null) ...[
              _billedTo(transaction),
              pw.SizedBox(height: 18),
            ],
            _linesTable(transaction),
            pw.SizedBox(height: 14),
            _totals(transaction),
            pw.Spacer(),
            _footer(transaction, salon),
          ],
        ),
      ),
    );

    return document.save();
  }

  static pw.Widget _header(
    SalonTransaction transaction,
    Salon? salon,
    pw.ImageProvider? logo,
  ) {
    // Adresse et téléphone joints en sautant ce qui manque : un salon sans
    // adresse ne doit pas afficher un séparateur esseulé.
    final contact = [
      if (salon?.address.isNotEmpty ?? false) salon!.address,
      if (salon?.phone.isNotEmpty ?? false) salon!.phone,
    ].join(' · ');

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null) ...[
          pw.Container(
            width: 44,
            height: 44,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(8),
              image: pw.DecorationImage(image: logo, fit: pw.BoxFit.cover),
            ),
          ),
          pw.SizedBox(width: 12),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                salon?.name ?? 'Salon',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              if (contact.isNotEmpty)
                pw.Text(
                  contact,
                  style: const pw.TextStyle(fontSize: 9, color: _muted),
                ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'FACTURE',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              transaction.invoiceNumber,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _primary,
              ),
            ),
            if (transaction.createdAt != null)
              pw.Text(
                Formatters.dayMonthYear(transaction.createdAt!),
                style: const pw.TextStyle(fontSize: 9, color: _muted),
              ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _billedTo(SalonTransaction transaction) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Facturé à',
          style: const pw.TextStyle(fontSize: 9, color: _muted),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          transaction.clientName!,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        if (transaction.clientPhone?.isNotEmpty ?? false)
          pw.Text(
            transaction.clientPhone!,
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
      ],
    );
  }

  static pw.Widget _linesTable(SalonTransaction transaction) {
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line, width: 1)),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(flex: 5, child: _th('Désignation')),
              pw.Expanded(flex: 1, child: _th('Qté', right: true)),
              pw.Expanded(flex: 2, child: _th('P.U.', right: true)),
              pw.Expanded(flex: 2, child: _th('Montant', right: true)),
            ],
          ),
        ),
        for (final line in transaction.lines)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 7),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _line, width: 0.5),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        line.label,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      if (line.category?.isNotEmpty ?? false)
                        pw.Text(
                          line.category!,
                          style: const pw.TextStyle(fontSize: 8, color: _muted),
                        ),
                    ],
                  ),
                ),
                pw.Expanded(flex: 1, child: _td('${line.quantity}')),
                pw.Expanded(
                  flex: 2,
                  child: _td(Formatters.fcfa(line.unitPriceFcfa)),
                ),
                pw.Expanded(
                  flex: 2,
                  child: _td(Formatters.fcfa(line.totalFcfa), bold: true),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _totals(SalonTransaction transaction) {
    final hasDiscount = transaction.discountFcfa > 0;

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 220,
        child: pw.Column(
          children: [
            // Sous-total et remise n'apparaissent qu'en présence d'une remise :
            // sinon ils répéteraient le total.
            if (hasDiscount) ...[
              _totalRow(
                'Sous-total',
                Formatters.fcfa(transaction.subtotalFcfa),
              ),
              _totalRow(
                'Remise',
                '- ${Formatters.fcfa(transaction.discountFcfa)}',
              ),
              pw.SizedBox(height: 4),
            ],
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: _line, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  pw.Text(
                    Formatters.fcfa(transaction.totalAmountFcfa),
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _footer(SalonTransaction transaction, Salon? salon) {
    final settled = transaction.isRefund
        ? 'Remboursé'
        : 'Payé · ${transaction.paymentMethod.label}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: _line, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Text(
              settled,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: transaction.isRefund
                    ? const PdfColor.fromInt(0xFFC0432C)
                    : _primary,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'Réf. ${transaction.reference.replaceFirst('#', '')}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
            pw.Spacer(),
            pw.Text(
              'Merci de votre confiance.',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _th(String label, {bool right = false}) => pw.Text(
    label,
    textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: _muted,
      letterSpacing: 0.5,
    ),
  );

  static pw.Widget _td(String value, {bool bold = false}) => pw.Text(
    value,
    textAlign: pw.TextAlign.right,
    style: pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: _ink,
    ),
  );

  static pw.Widget _totalRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9, color: _ink)),
      ],
    ),
  );
}
