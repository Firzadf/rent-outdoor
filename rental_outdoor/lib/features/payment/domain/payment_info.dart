import '../../../core/utils/parsers.dart';

/// Satu rekening tujuan dari `GET /payments/info` (API_DOCS.md bagian 8).
class PaymentBankAccount {
  const PaymentBankAccount({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  factory PaymentBankAccount.fromJson(Map<String, dynamic> json) =>
      PaymentBankAccount(
        bankName: parseString(json['bank_name']) ?? '-',
        accountNumber: parseString(json['account_number']) ?? '',
        accountName: parseString(json['account_name']) ?? '-',
      );

  final String bankName;
  final String accountNumber;
  final String accountName;
}
