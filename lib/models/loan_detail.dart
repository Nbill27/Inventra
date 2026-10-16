import 'item.dart';
import 'loan.dart';

/// A loan together with the item it points at, for the list and detail screens.
class LoanDetail {
  const LoanDetail({required this.loan, required this.item});

  final Loan loan;
  final Item item;
}
