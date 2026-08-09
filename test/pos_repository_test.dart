import 'package:flutter_test/flutter_test.dart';
import 'package:stylik/features/pos/domain/ticket.dart';

void main() {
  group('Ticket & Transaction ID generation', () {
    test('Ticket calculations and line formatting', () {
      const ticket = Ticket(
        clientName: 'Awa Diop',
        lines: [
          TicketLine(
            refId: 'serv_1',
            label: 'Brushing',
            unitPriceFcfa: 5000,
            quantity: 2,
          ),
          TicketLine(
            refId: 'prod_1',
            label: 'Shampoing Bio',
            unitPriceFcfa: 3500,
            quantity: 1,
            isProduct: true,
          ),
        ],
      );

      expect(ticket.subtotalFcfa, 13500);
      expect(ticket.totalFcfa, 13500);
      expect(ticket.serviceLines.length, 1);
      expect(ticket.productLines.length, 1);
    });

    test('TicketLine.toMap includes both snake_case and camelCase keys', () {
      const line = TicketLine(
        refId: 's1',
        label: 'Coupe',
        unitPriceFcfa: 4000,
        quantity: 1,
        stylistId: 'coiff_1',
        stylistName: 'Karim',
      );

      final map = line.toMap();
      expect(map['ref_id'], 's1');
      expect(map['refId'], 's1');
      expect(map['unit_price_fcfa'], 4000);
      expect(map['unitPriceFcfa'], 4000);
      expect(map['stylist_id'], 'coiff_1');
      expect(map['stylistId'], 'coiff_1');
    });
  });
}
