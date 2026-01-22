// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_history_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealHistoryModelAdapter extends TypeAdapter<MealHistoryModel> {
  @override
  final int typeId = 50;

  @override
  MealHistoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealHistoryModel(
      id: fields[0] as String,
      familyId: fields[1] as String,
      date: fields[2] as DateTime,
      mealType: fields[3] as String,
      recipes: (fields[4] as List).cast<MealHistoryRecipeModel>(),
      notes: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MealHistoryModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.familyId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.mealType)
      ..writeByte(4)
      ..write(obj.recipes)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealHistoryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MealHistoryRecipeModelAdapter
    extends TypeAdapter<MealHistoryRecipeModel> {
  @override
  final int typeId = 51;

  @override
  MealHistoryRecipeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealHistoryRecipeModel(
      recipeId: fields[0] as String,
      recipeName: fields[1] as String,
      rating: fields[2] as int?,
      comment: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MealHistoryRecipeModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.recipeId)
      ..writeByte(1)
      ..write(obj.recipeName)
      ..writeByte(2)
      ..write(obj.rating)
      ..writeByte(3)
      ..write(obj.comment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealHistoryRecipeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
