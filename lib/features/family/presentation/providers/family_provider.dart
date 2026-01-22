import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/family_model.dart';
import '../../data/repositories/family_repository.dart';

// 导出饮食选项供其他文件使用
export '../../data/models/dietary_options.dart';

/// 家庭列表状态
class FamilyListState {
  final List<FamilyModel> families;
  final bool isLoading;
  final String? error;

  const FamilyListState({
    this.families = const [],
    this.isLoading = false,
    this.error,
  });

  FamilyListState copyWith({
    List<FamilyModel>? families,
    bool? isLoading,
    String? error,
  }) {
    return FamilyListState(
      families: families ?? this.families,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 家庭列表通知器
class FamilyListNotifier extends StateNotifier<FamilyListState> {
  final FamilyRepository _repository;

  FamilyListNotifier(this._repository) : super(const FamilyListState()) {
    loadFamilies();
  }

  Future<void> loadFamilies() async {
    state = state.copyWith(isLoading: true);
    try {
      final families = _repository.getAllFamilies();
      state = state.copyWith(families: families, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createFamily(FamilyModel family) async {
    await _repository.saveFamily(family);
    await loadFamilies();
  }

  Future<void> updateFamily(FamilyModel family) async {
    await _repository.saveFamily(family);
    await loadFamilies();
  }

  Future<void> deleteFamily(String id) async {
    await _repository.deleteFamily(id);
    await loadFamilies();
  }
}

/// 家庭列表 Provider
final familyListProvider = StateNotifierProvider<FamilyListNotifier, FamilyListState>((ref) {
  final repository = ref.watch(familyRepositoryProvider);
  return FamilyListNotifier(repository);
});

/// 创建/编辑家庭表单状态
class FamilyFormState {
  final String name;
  final List<FamilyMemberModel> members;
  final MealSettingsModel mealSettings;
  final bool isSubmitting;
  final String? error;

  FamilyFormState({
    this.name = '',
    this.members = const [],
    MealSettingsModel? mealSettings,
    this.isSubmitting = false,
    this.error,
  }) : mealSettings = mealSettings ?? MealSettingsModel();

  FamilyFormState copyWith({
    String? name,
    List<FamilyMemberModel>? members,
    MealSettingsModel? mealSettings,
    bool? isSubmitting,
    String? error,
  }) {
    return FamilyFormState(
      name: name ?? this.name,
      members: members ?? this.members,
      mealSettings: mealSettings ?? this.mealSettings,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }

  bool get isValid => name.isNotEmpty;
}

/// 家庭表单通知器
class FamilyFormNotifier extends StateNotifier<FamilyFormState> {
  FamilyFormNotifier() : super(FamilyFormState());

  void setName(String name) => state = state.copyWith(name: name);

  void addMember(FamilyMemberModel member) {
    state = state.copyWith(members: [...state.members, member]);
  }

  void updateMember(int index, FamilyMemberModel member) {
    final members = [...state.members];
    members[index] = member;
    state = state.copyWith(members: members);
  }

  void removeMember(int index) {
    final members = [...state.members];
    members.removeAt(index);
    state = state.copyWith(members: members);
  }

  void setMealSettings(MealSettingsModel settings) {
    state = state.copyWith(mealSettings: settings);
  }

  void loadFamily(FamilyModel family) {
    state = FamilyFormState(
      name: family.name,
      members: family.members,
      mealSettings: family.mealSettings,
    );
  }

  void reset() => state = FamilyFormState();

  FamilyModel toFamily({String? existingId}) {
    if (existingId != null) {
      return FamilyModel(
        id: existingId,
        name: state.name,
        members: state.members,
        mealSettings: state.mealSettings,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return FamilyModel.create(
      name: state.name,
      members: state.members,
      mealSettings: state.mealSettings,
    );
  }
}

/// 家庭表单 Provider
final familyFormProvider =
    StateNotifierProvider.autoDispose<FamilyFormNotifier, FamilyFormState>((ref) {
  return FamilyFormNotifier();
});

// 选项定义已移至 dietary_options.dart
