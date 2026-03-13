// lib/core/provider/transactions_provider.dart
// Fetches transactions list from /v1/transactions.
// Falls back to MockData on error.

import 'package:flutter/foundation.dart';
import '../../shared/models/transaction.dart';
import '../services/api_service.dart';
import '../utils/mock_data.dart';

enum TransactionsLoadState { idle, loading, loaded, error }

class TransactionsProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];
  TransactionsLoadState _state = TransactionsLoadState.idle;
  String? _errorMessage;

  List<Transaction> get transactions => List.unmodifiable(_transactions);
  TransactionsLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == TransactionsLoadState.loading;
  bool get hasData => _state == TransactionsLoadState.loaded;

  Future<void> loadTransactions() async {
    if (_state == TransactionsLoadState.loading) return;
    _state = TransactionsLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions = await ApiService.fetchTransactions();
      _state = TransactionsLoadState.loaded;
    } catch (e) {
      // Fallback to mock data
      _transactions = MockData.transactions;
      _errorMessage = e.toString();
      _state = TransactionsLoadState.loaded;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _state = TransactionsLoadState.idle;
    await loadTransactions();
  }
}

