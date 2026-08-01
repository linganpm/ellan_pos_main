import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/currency_format.dart';
import '../../core/utils/font_utility.dart';

class ReceiptPreviewItem {
  final String name;
  final String quantityLabel;
  final double amount;

  const ReceiptPreviewItem({
    required this.name,
    required this.quantityLabel,
    required this.amount,
  });
}

class ReceiptPreviewData {
  final int orderId;
  final String storeName;
  final String pricingMode;
  final String partyName;
  final String partyId;
  final String paymentLabel;
  final double previousBalance;
  final double subtotal;
  final double offerAmount;
  final double discountAmount;
  final double deliveryAmount;
  final double taxAmount;
  final double tipsAmount;
  final double total;
  final double paid;
  final double balanceDue;
  final List<ReceiptPreviewItem> items;

  const ReceiptPreviewData({
    required this.orderId,
    required this.storeName,
    required this.pricingMode,
    required this.partyName,
    required this.partyId,
    required this.paymentLabel,
    required this.previousBalance,
    required this.subtotal,
    required this.offerAmount,
    required this.discountAmount,
    required this.deliveryAmount,
    required this.taxAmount,
    required this.tipsAmount,
    required this.total,
    required this.paid,
    required this.balanceDue,
    required this.items,
  });

  bool get isPurchase => pricingMode == 'buying';
  String get directionLabel => isPurchase ? 'PURCHASES' : 'SALES';
  String get partyLabel => isPurchase ? 'Supplier' : 'Customer';
  String get displayPartyName =>
      partyName.trim().isEmpty ? '—' : partyName.trim();
  String get displayPartyId => partyId.trim().isEmpty ? '—' : partyId.trim();
  bool get showPreviousBalance {
    final mode = paymentLabel.toLowerCase();
    return previousBalance.abs() > 0.0001 ||
        mode.contains('credit') ||
        mode.contains('advance') ||
        mode.contains('payable');
  }
}

Future<void> showReceiptPreviewDialog(
  BuildContext context,
  ReceiptPreviewData data,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Thermal receipt preview',
                      style: FontUtility.heading.copyWith(fontSize: 20),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _ReceiptPaper(data: data),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _printReceipt(data),
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Print'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReceiptPaper extends StatelessWidget {
  final ReceiptPreviewData data;

  const _ReceiptPaper({required this.data});

  @override
  Widget build(BuildContext context) {
    final partyDetailStyle = FontUtility.body.copyWith(
      fontSize: data.isPurchase ? 11 : 13,
      color: Colors.black87,
    );
    return Container(
      width: 340,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black26),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            data.storeName,
            textAlign: TextAlign.center,
            style: FontUtility.heading.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            data.directionLabel,
            textAlign: TextAlign.center,
            style: FontUtility.heading.copyWith(
              fontSize: 13,
              color: data.isPurchase
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFF178A45),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Order #${data.orderId}',
            textAlign: TextAlign.center,
            style: FontUtility.body.copyWith(fontSize: 12),
          ),
          const Divider(height: 20),
          Text(
            '${data.partyLabel}: ${data.displayPartyName}',
            style: partyDetailStyle,
          ),
          Text(
            '${data.partyLabel} ID: ${data.displayPartyId}',
            style: partyDetailStyle,
          ),
          Text('Payment: ${data.paymentLabel}', style: partyDetailStyle),
          if (data.showPreviousBalance)
            Text(
              'Previous balance: ${PosCurrency.format(data.previousBalance)}',
              style: partyDetailStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          const Divider(height: 20),
          for (final item in data.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 42, child: Text(item.quantityLabel)),
                  Expanded(child: Text(item.name)),
                  Text(PosCurrency.format(item.amount)),
                ],
              ),
            ),
          const Divider(height: 20),
          _row('Subtotal', data.subtotal),
          if (data.offerAmount > 0.0001) _row('Offer', -data.offerAmount),
          if (data.discountAmount > 0.0001)
            _row('Discount', -data.discountAmount),
          if (data.deliveryAmount > 0.0001)
            _row('Delivery', data.deliveryAmount),
          if (data.taxAmount > 0.0001) _row('Tax', data.taxAmount),
          if (data.tipsAmount > 0.0001) _row('Tips', data.tipsAmount),
          const Divider(height: 16),
          _row('TOTAL', data.total, bold: true),
          _row('Paid', data.paid),
          if (data.balanceDue > 0.0001)
            _row('Balance due', data.balanceDue, bold: true),
          const SizedBox(height: 18),
          const Text('Thank you', textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _row(String label, double amount, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(PosCurrency.format(amount), style: style),
        ],
      ),
    );
  }
}

Future<void> _printReceipt(ReceiptPreviewData data) async {
  await Printing.layoutPdf(
    name: '${data.isPurchase ? 'purchase' : 'sale'}-${data.orderId}',
    format: PdfPageFormat(
      80 * PdfPageFormat.mm,
      (150 + data.items.length * 12) * PdfPageFormat.mm,
      marginAll: 4 * PdfPageFormat.mm,
    ),
    onLayout: (_) => _buildReceiptPdf(data),
  );
}

Future<Uint8List> _buildReceiptPdf(ReceiptPreviewData data) async {
  final document = pw.Document();
  final partyDetailFontSize = data.isPurchase ? 7.0 : 8.0;
  pw.Widget moneyRow(String label, double amount, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 8,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(PosCurrency.format(amount), style: style),
        ],
      ),
    );
  }

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        80 * PdfPageFormat.mm,
        (150 + data.items.length * 12) * PdfPageFormat.mm,
        marginAll: 4 * PdfPageFormat.mm,
      ),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            data.storeName,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            data.isPurchase ? 'PURCHASES' : 'SALES',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Order #${data.orderId}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Divider(),
          pw.Text(
            '${data.partyLabel}: ${data.displayPartyName}',
            style: pw.TextStyle(fontSize: partyDetailFontSize),
          ),
          pw.Text(
            '${data.partyLabel} ID: ${data.displayPartyId}',
            style: pw.TextStyle(fontSize: partyDetailFontSize),
          ),
          pw.Text(
            'Payment: ${data.paymentLabel}',
            style: pw.TextStyle(fontSize: partyDetailFontSize),
          ),
          if (data.showPreviousBalance)
            pw.Text(
              'Previous balance: ${PosCurrency.format(data.previousBalance)}',
              style: pw.TextStyle(
                fontSize: partyDetailFontSize,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          pw.Divider(),
          for (final item in data.items)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 22,
                    child: pw.Text(
                      item.quantityLabel,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      item.name,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Text(
                    PosCurrency.format(item.amount),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
          pw.Divider(),
          moneyRow('Subtotal', data.subtotal),
          if (data.offerAmount > 0.0001) moneyRow('Offer', -data.offerAmount),
          if (data.discountAmount > 0.0001)
            moneyRow('Discount', -data.discountAmount),
          if (data.deliveryAmount > 0.0001)
            moneyRow('Delivery', data.deliveryAmount),
          if (data.taxAmount > 0.0001) moneyRow('Tax', data.taxAmount),
          if (data.tipsAmount > 0.0001) moneyRow('Tips', data.tipsAmount),
          pw.Divider(),
          moneyRow('TOTAL', data.total, bold: true),
          moneyRow('Paid', data.paid),
          if (data.balanceDue > 0.0001)
            moneyRow('Balance due', data.balanceDue, bold: true),
          pw.SizedBox(height: 8),
          pw.Text(
            'Thank you',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    ),
  );
  return document.save();
}
