// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_list_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShoppingListModelAdapter extends TypeAdapter<ShoppingListModel> {
  @override
  final int typeId = 40;

  @override
  ShoppingListModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShoppingListModel(
      id: fields[0] as String,
      familyId: fields[1] as String,
      mealPlanId: fields[2] as String?,
      items: (fields[3] as List).cast<ShoppingItemModel>(),
      generatedAt: fields[4] as DateTime,
      notes: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ShoppingListModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.familyId)
      ..writeByte(2)
      ..write(obj.mealPlanId)
      ..writeByte(3)
      ..write(obj.items)
      ..writeByte(4)
      ..write(obj.generatedAt)
      ..writeByte(5)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingListModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ShoppingItemModelAdapter extends TypeAdapter<ShoppingItemModel> {
  @override
  final int typeId = 41;

  @override
  ShoppingItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShoppingItemModel(
      id: fields[0] as String,
      category: fields[1] as String?,
      name: fields[2] as String,
      quantity: fields[3] as double,
      unit: fields[4] as String,
      notes: fields[5] as String?,
      purchased: fields[6] as bool,
      source: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ShoppingItemModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.unit)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.purchased)
      ..writeByte(7)
      ..write(obj.source);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
