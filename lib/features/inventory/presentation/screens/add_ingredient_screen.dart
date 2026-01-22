import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/ai_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../../data/models/ingredient_category_map.dart' hide ingredientCategories;
import '../../data/models/ingredient_model.dart';
import '../providers/inventory_provider.dart';

class AddIngredientScreen extends ConsumerStatefulWidget {
  const AddIngredientScreen({super.key});

  @override
  ConsumerState<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends ConsumerState<AddIngredientScreen> {
  int _currentStep = 0; // 0: 选择方式, 1: 手动输入表单, 2: 拍照识别结果

  // 拍照识别相关状态
  bool _isRecognizing = false;
  List<IngredientRecognition> _recognizedIngredients = [];
  Set<int> _selectedIndices = {};
  String? _recognitionError;
  Uint8List? _capturedImage;

  @override
  Widget build(BuildContext context) {
    String title;
    switch (_currentStep) {
      case 0:
        title = '添加食材';
        break;
      case 1:
        title = '手动输入';
        break;
      case 2:
        title = _isRecognizing ? '识别中...' : '识别结果';
        break;
      default:
        title = '添加食材';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == 0) {
              context.pop();
            } else {
              setState(() {
                _currentStep = 0;
                _recognizedIngredients = [];
                _selectedIndices = {};
                _recognitionError = null;
                _capturedImage = null;
              });
            }
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case 0:
        return _buildMethodSelection();
      case 1:
        return const _ManualInputForm();
      case 2:
        return _buildRecognitionResult();
      default:
        return _buildMethodSelection();
    }
  }

  Widget _buildMethodSelection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AddMethodCard(
            icon: Icons.camera_alt,
            title: '拍照识别',
            description: '拍摄冰箱或储物柜照片，AI 自动识别食材',
            color: AppColors.primary,
            onTap: () => _showImageSourceDialog(),
          ),
          const SizedBox(height: 16),
          _AddMethodCard(
            icon: Icons.text_fields,
            title: '快速输入',
            description: '一次输入多个食材，如"三根胡萝卜、一斤排骨"',
            color: AppColors.secondary,
            onTap: () => _showQuickInputDialog(),
          ),
          const SizedBox(height: 16),
          _AddMethodCard(
            icon: Icons.edit,
            title: '手动输入',
            description: '手动输入食材名称和数量',
            color: AppColors.info,
            onTap: () => setState(() => _currentStep = 1),
          ),
        ],
      ),
    );
  }

  /// 显示图片来源选择对话框
  void _showImageSourceDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.primary),
                title: Text('拍照', style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                )),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.secondary),
                title: Text('从相册选择', style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                )),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 选择或拍摄图片
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() {
        _currentStep = 2;
        _isRecognizing = true;
        _capturedImage = bytes;
        _recognitionError = null;
      });

      await _recognizeIngredients(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取图片失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 调用 AI 识别食材
  Future<void> _recognizeIngredients(Uint8List imageBytes) async {
    try {
      final aiService = ref.read(aiServiceProvider);
      final results = await aiService.recognizeIngredients(imageBytes);

      if (mounted) {
        setState(() {
          _isRecognizing = false;
          _recognizedIngredients = results;
          // 默认全选所有识别结果
          _selectedIndices = Set.from(List.generate(results.length, (i) => i));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecognizing = false;
          _recognitionError = e.toString();
        });
      }
    }
  }

  /// 构建识别结果页面
  Widget _buildRecognitionResult() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentFamily = ref.watch(currentFamilyProvider);

    if (_isRecognizing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 显示拍摄的图片预览
            if (_capturedImage != null)
              Container(
                width: 200,
                height: 200,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  _capturedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'AI 正在识别食材...',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_recognitionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                '识别失败',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _recognitionError!,
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentStep = 0),
                icon: const Icon(Icons.refresh),
                label: const Text('重新选择'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recognizedIngredients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                '未识别到食材',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请尝试拍摄更清晰的照片，或手动添加食材',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showImageSourceDialog(),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('重新拍照'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _currentStep = 1),
                    icon: const Icon(Icons.edit),
                    label: const Text('手动添加'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final isPhotoMode = _capturedImage != null;

    return Column(
      children: [
        // 顶部统计栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 40 : 13),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 图片缩略图（仅拍照模式）或图标（快速输入模式）
              if (isPhotoMode)
                Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(
                    _capturedImage!,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.text_fields,
                    color: AppColors.secondary,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '识别到 ${_recognizedIngredients.length} 种食材',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已选择 ${_selectedIndices.length} 项',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // 全选/取消按钮
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedIndices.length == _recognizedIngredients.length) {
                      _selectedIndices.clear();
                    } else {
                      _selectedIndices = Set.from(
                        List.generate(_recognizedIngredients.length, (i) => i),
                      );
                    }
                  });
                },
                child: Text(
                  _selectedIndices.length == _recognizedIngredients.length ? '取消全选' : '全选',
                ),
              ),
            ],
          ),
        ),

        // 食材列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _recognizedIngredients.length,
            itemBuilder: (context, index) {
              final item = _recognizedIngredients[index];
              final isSelected = _selectedIndices.contains(index);

              return _RecognizedIngredientCard(
                item: item,
                isSelected: isSelected,
                onToggle: () {
                  setState(() {
                    if (isSelected) {
                      _selectedIndices.remove(index);
                    } else {
                      _selectedIndices.add(index);
                    }
                  });
                },
                onEdit: () => _editRecognizedItem(index),
                onDelete: () {
                  setState(() {
                    _recognizedIngredients.removeAt(index);
                    _selectedIndices.remove(index);
                    // 更新索引
                    _selectedIndices = _selectedIndices
                        .map((i) => i > index ? i - 1 : i)
                        .toSet();
                  });
                },
              );
            },
          ),
        ),

        // 底部按钮
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 40 : 13),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isPhotoMode
                      ? () => _showImageSourceDialog()
                      : () => _showQuickInputDialog(),
                  icon: Icon(isPhotoMode ? Icons.camera_alt : Icons.text_fields),
                  label: Text(isPhotoMode ? '重新拍照' : '重新输入'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectedIndices.isEmpty || currentFamily == null
                      ? null
                      : () => _addSelectedIngredients(currentFamily.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text('添加 ${_selectedIndices.length} 项'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 编辑识别的食材
  void _editRecognizedItem(int index) {
    final item = _recognizedIngredients[index];
    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(text: item.quantity.toString());
    String selectedUnit = item.unit;
    String? selectedCategory = item.category;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('编辑食材'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '名称',
                      prefixIcon: Icon(Icons.restaurant),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: '数量',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedUnit,
                          decoration: const InputDecoration(
                            labelText: '单位',
                          ),
                          items: ingredientUnits.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedUnit = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: '类别',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: ingredientCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedCategory = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newQuantity = double.tryParse(quantityController.text) ?? item.quantity;
                  setState(() {
                    _recognizedIngredients[index] = IngredientRecognition(
                      name: nameController.text.trim(),
                      quantity: newQuantity,
                      unit: selectedUnit,
                      freshness: item.freshness,
                      category: selectedCategory,
                      storageAdvice: item.storageAdvice,
                    );
                  });
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 批量添加选中的食材
  Future<void> _addSelectedIngredients(String familyId) async {
    final selectedItems = _selectedIndices
        .map((i) => _recognizedIngredients[i])
        .toList();

    if (selectedItems.isEmpty) return;

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在添加食材...'),
          ],
        ),
      ),
    );

    try {
      final notifier = ref.read(inventoryProvider.notifier);
      int successCount = 0;

      for (final item in selectedItems) {
        final ingredient = IngredientModel.create(
          familyId: familyId,
          name: item.name,
          category: item.category,
          quantity: item.quantity,
          unit: item.unit,
          freshness: item.freshness,
          storageAdvice: item.storageAdvice,
          source: 'photo',
        );

        await notifier.addIngredient(ingredient);
        successCount++;
      }

      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功添加 $successCount 种食材'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(); // 返回上一页
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 显示快速输入对话框
  void _showQuickInputDialog() {
    final textController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('快速输入食材'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '输入食材名称和数量，多个食材用逗号或顿号分隔',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '例如：三根胡萝卜、一斤排骨、两个鸡蛋、500克牛肉',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              '提示：支持中文数量词，如"三根"、"一斤"、"两个"',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请输入食材'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);
              _parseQuickInput(text);
            },
            child: const Text('识别'),
          ),
        ],
      ),
    );
  }

  /// 解析快速输入的文本
  Future<void> _parseQuickInput(String text) async {
    setState(() {
      _currentStep = 2;
      _isRecognizing = true;
      _capturedImage = null;
      _recognitionError = null;
    });

    try {
      final aiService = ref.read(aiServiceProvider);
      final results = await aiService.parseIngredientText(text);

      if (mounted) {
        setState(() {
          _isRecognizing = false;
          _recognizedIngredients = results;
          // 默认全选所有识别结果
          _selectedIndices = Set.from(List.generate(results.length, (i) => i));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecognizing = false;
          _recognitionError = e.toString();
        });
      }
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature 功能即将上线'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 识别结果卡片
class _RecognizedIngredientCard extends StatelessWidget {
  final IngredientRecognition item;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecognizedIngredientCard({
    required this.item,
    required this.isSelected,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 选择框
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.textTertiaryDark : Colors.grey[400]!),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),

              // 食材信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (item.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(26),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.category!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${item.quantity}${item.unit}',
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                        if (item.freshness != null) ...[
                          const SizedBox(width: 12),
                          _FreshnessChip(freshness: item.freshness!),
                        ],
                      ],
                    ),
                    if (item.storageAdvice != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.storageAdvice!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // 操作按钮
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      size: 20,
                      color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                    ),
                    onPressed: onEdit,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: AppColors.error,
                    ),
                    onPressed: onDelete,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 新鲜度标签
class _FreshnessChip extends StatelessWidget {
  final String freshness;

  const _FreshnessChip({required this.freshness});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (freshness) {
      case '新鲜':
        color = Colors.green;
        break;
      case '一般':
        color = Colors.orange;
        break;
      case '临期':
        color = Colors.deepOrange;
        break;
      case '过期':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        freshness,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AddMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _AddMethodCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 手动输入表单
class _ManualInputForm extends ConsumerStatefulWidget {
  const _ManualInputForm();

  @override
  ConsumerState<_ManualInputForm> createState() => _ManualInputFormState();
}

class _ManualInputFormState extends ConsumerState<_ManualInputForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  String? _selectedCategory;
  String _selectedUnit = '个';
  DateTime? _expiryDate;
  bool _isSubmitting = false;
  bool _isAutoMatched = false; // 是否自动匹配的类别
  bool _isClassifying = false; // AI 正在分类中
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  /// 食材名称变化时自动匹配类别和单位
  void _onNameChanged() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _selectedCategory = null;
        _isAutoMatched = false;
        _isClassifying = false;
      });
      _debounceTimer?.cancel();
      return;
    }

    // 1. 本地映射表匹配
    final localMatch = matchIngredientCategory(name);
    if (localMatch != null) {
      setState(() {
        _selectedCategory = localMatch;
        _isAutoMatched = true;
        _isClassifying = false;
        // 同时匹配推荐单位
        _selectedUnit = getRecommendedUnit(name, localMatch);
      });
      _debounceTimer?.cancel();
      return;
    }

    // 2. 本地未匹配，延迟触发 AI 分类（避免频繁调用）
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _classifyWithAI(name);
    });
  }

  /// 使用 AI 分类食材
  Future<void> _classifyWithAI(String name) async {
    if (!mounted) return;

    setState(() => _isClassifying = true);

    try {
      final aiService = ref.read(aiServiceProvider);
      final category = await aiService.classifyIngredient(name);

      if (!mounted) return;

      if (category != null && ingredientCategories.contains(category)) {
        setState(() {
          _selectedCategory = category;
          _isAutoMatched = true;
          _isClassifying = false;
          // 根据 AI 识别的类别设置推荐单位
          _selectedUnit = getRecommendedUnit(name, category);
        });
      } else {
        setState(() {
          _isAutoMatched = false;
          _isClassifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClassifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentFamily = ref.watch(currentFamilyProvider);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 食材名称
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '食材名称 *',
              hintText: '如：胡萝卜、鸡蛋、牛奶',
              prefixIcon: Icon(Icons.restaurant),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入食材名称';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // 类别选择
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: _isClassifying
                  ? '类别（AI 识别中...）'
                  : _isAutoMatched
                      ? '类别（已自动匹配）'
                      : '类别',
              prefixIcon: _isClassifying
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(
                      _isAutoMatched ? Icons.auto_awesome : Icons.category,
                      color: _isAutoMatched ? AppColors.primary : null,
                    ),
              suffixIcon: _isAutoMatched
                  ? Icon(Icons.check_circle, color: AppColors.success, size: 20)
                  : null,
            ),
            items: ingredientCategories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) => setState(() {
              _selectedCategory = value;
              _isAutoMatched = false; // 用户手动选择时清除自动匹配标记
            }),
          ),
          const SizedBox(height: 16),

          // 数量和单位
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: '数量 *',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入数量';
                    }
                    final num = double.tryParse(value);
                    if (num == null || num <= 0) {
                      return '请输入有效数量';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  decoration: const InputDecoration(
                    labelText: '单位',
                  ),
                  items: ingredientUnits.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedUnit = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 保质期
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('保质期至'),
            subtitle: Text(
              _expiryDate != null
                  ? '${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}'
                  : '未设置',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_expiryDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _expiryDate = null),
                  ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectExpiryDate,
                ),
              ],
            ),
          ),
          const Divider(),

          // 快捷保质期按钮
          const Text(
            '快捷设置保质期',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickExpiryChip(
                label: '3天',
                onTap: () => _setQuickExpiry(3),
              ),
              _QuickExpiryChip(
                label: '7天',
                onTap: () => _setQuickExpiry(7),
              ),
              _QuickExpiryChip(
                label: '14天',
                onTap: () => _setQuickExpiry(14),
              ),
              _QuickExpiryChip(
                label: '1个月',
                onTap: () => _setQuickExpiry(30),
              ),
              _QuickExpiryChip(
                label: '3个月',
                onTap: () => _setQuickExpiry(90),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 提交按钮
          ElevatedButton(
            onPressed: _isSubmitting || currentFamily == null
                ? null
                : () => _submitForm(currentFamily.id),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('添加食材'),
          ),

          if (currentFamily == null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '请先创建家庭才能添加食材',
                style: TextStyle(color: Colors.red.shade400),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      setState(() => _expiryDate = date);
    }
  }

  void _setQuickExpiry(int days) {
    setState(() {
      _expiryDate = DateTime.now().add(Duration(days: days));
    });
  }

  Future<void> _submitForm(String familyId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final quantity = double.parse(_quantityController.text);
      final notifier = ref.read(inventoryProvider.notifier);

      final ingredient = IngredientModel.create(
        familyId: familyId,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        quantity: quantity,
        unit: _selectedUnit,
        expiryDate: _expiryDate,
        source: 'manual',
      );

      await notifier.addIngredient(ingredient);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('食材添加成功'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

/// 快捷保质期按钮
class _QuickExpiryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickExpiryChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return ActionChip(
      label: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
      ),
      onPressed: onTap,
      elevation: 0,
      pressElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
      side: isDark ? BorderSide(color: AppColors.borderDark) : BorderSide.none,
    );
  }
}
