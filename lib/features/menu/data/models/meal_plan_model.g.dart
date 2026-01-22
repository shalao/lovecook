// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_plan_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealPlanModelAdapter extends TypeAdapter<MealPlanModel> {
  @override
  final int typeId = 30;

  @override
  MealPlanModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealPlanModel(
      id: fields[0] as String,
      familyId: fields[1] as String,
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime,
      days: (fields[4] as List).cast<DayPlanModel>(),
      createdAt: fields[5] as DateTime,
      notes: fields[6] as String?,
      shoppingListId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MealPlanModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.familyId)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.days)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.shoppingListId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPlanModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DayPlanModelAdapter extends TypeAdapter<DayPlanModel> {
  @override
  final int typeId = 31;

  @override
  DayPlanModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DayPlanModel(
      date: fields[0] as DateTime,
      meals: (fields[1] as List).cast<MealModel>(),
    );
  }

  @override
  void write(BinaryWriter writer, DayPlanModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.meals);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayPlanModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MealModelAdapter extends TypeAdapter<MealModel> {
  @override
  final int typeId = 32;

  @override
  MealModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealModel(
      type: fields[0] as String,
      recipeIds: (fields[1] as List).cast<String>(),
      notes: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MealModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.recipeIds)
      ..writeByte(2)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
