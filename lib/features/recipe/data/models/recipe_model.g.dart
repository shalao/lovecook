// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeModelAdapter extends TypeAdapter<RecipeModel> {
  @override
  final int typeId = 20;

  @override
  RecipeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeModel(
      id: fields[0] as String,
      familyId: fields[1] as String?,
      name: fields[2] as String,
      description: fields[3] as String?,
      tags: (fields[4] as List).cast<String>(),
      prepTime: fields[5] as int,
      cookTime: fields[6] as int,
      servings: fields[7] as int,
      ingredients: (fields[8] as List).cast<RecipeIngredientModel>(),
      steps: (fields[9] as List).cast<String>(),
      tips: fields[10] as String?,
      nutrition: fields[11] as NutritionInfoModel?,
      isFavorite: fields[12] as bool,
      createdAt: fields[13] as DateTime,
      imageUrl: fields[14] as String?,
      difficulty: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.familyId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.prepTime)
      ..writeByte(6)
      ..write(obj.cookTime)
      ..writeByte(7)
      ..write(obj.servings)
      ..writeByte(8)
      ..write(obj.ingredients)
      ..writeByte(9)
      ..write(obj.steps)
      ..writeByte(10)
      ..write(obj.tips)
      ..writeByte(11)
      ..write(obj.nutrition)
      ..writeByte(12)
      ..write(obj.isFavorite)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.imageUrl)
      ..writeByte(15)
      ..write(obj.difficulty);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecipeIngredientModelAdapter extends TypeAdapter<RecipeIngredientModel> {
  @override
  final int typeId = 21;

  @override
  RecipeIngredientModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeIngredientModel(
      name: fields[0] as String,
      quantity: fields[1] as double,
      unit: fields[2] as String,
      isOptional: fields[3] as bool,
      substitute: fields[4] as String?,
      note: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeIngredientModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.isOptional)
      ..writeByte(4)
      ..write(obj.substitute)
      ..writeByte(5)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeIngredientModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NutritionInfoModelAdapter extends TypeAdapter<NutritionInfoModel> {
  @override
  final int typeId = 22;

  @override
  NutritionInfoModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NutritionInfoModel(
      calories: fields[0] as double?,
      protein: fields[1] as double?,
      carbs: fields[2] as double?,
      fat: fields[3] as double?,
      fiber: fields[4] as double?,
      sodium: fields[5] as double?,
      summary: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NutritionInfoModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.calories)
      ..writeByte(1)
      ..write(obj.protein)
      ..writeByte(2)
      ..write(obj.carbs)
      ..writeByte(3)
      ..write(obj.fat)
      ..writeByte(4)
      ..write(obj.fiber)
      ..writeByte(5)
      ..write(obj.sodium)
      ..writeByte(6)
      ..write(obj.summary);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionInfoModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
