import 'package:flutter_bloc/flutter_bloc.dart';

class ChainState {
  const ChainState({
    this.selectedKey = 'hedera',
    this.isLoading = false,
  });

  final String selectedKey;
  final bool isLoading;

  ChainState copyWith({String? selectedKey, bool? isLoading}) {
    return ChainState(
      selectedKey: selectedKey ?? this.selectedKey,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChainStore extends Cubit<ChainState> {
  ChainStore() : super(const ChainState());

  Future<void> selectChain(String key) async {
    if (state.selectedKey == key) return;
    emit(state.copyWith(isLoading: true));
    // Simulate fetching chain data
    await Future.delayed(const Duration(milliseconds: 1200));
    if (isClosed) return;
    emit(state.copyWith(selectedKey: key, isLoading: false));
  }
}
