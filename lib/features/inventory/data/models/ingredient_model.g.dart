// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingredient_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IngredientModelAdapter extends TypeAdapter<IngredientModel> {
  @override
  final int typeId = 10;

  @override
  IngredientModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IngredientModel(
      id: fields[0] as String,
      familyId: fields[1] as String,
      name: fields[2] as String,
      category: fields[3] as String?,
      quantity: fields[4] as double,
      unit: fields[5] as String,
      freshness: fields[6] as String?,
      expiryDate: fields[7] as DateTime?,
      storageAdvice: fields[8] as String?,
      source: fields[9] as String,
      addedAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
      usedQuantity: fields[12] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, IngredientModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.familyId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.unit)
      ..writeByte(6)
      ..write(obj.freshness)
      ..writeByte(7)
      ..write(obj.expiryDate)
      ..writeByte(8)
      ..write(obj.storageAdvice)
      ..writeByte(9)
      ..write(obj.source)
      ..writeByte(10)
      ..write(obj.addedAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.usedQuantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
