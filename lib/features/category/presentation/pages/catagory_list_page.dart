import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_error_message.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../data/models/category_add_request_model.dart';
import '../bloc/category_bloc.dart';

class CatagoryListPage extends StatefulWidget {
  const CatagoryListPage({super.key});

  @override
  State<CatagoryListPage> createState() => _CatagoryListPageState();
}

class _CatagoryListPageState extends State<CatagoryListPage> {
  final TextEditingController _categoryController = TextEditingController();

  static const List<Map<String, dynamic>> _quickSuggestions = [
    {"name": "Food & Dining", "icon": Icons.restaurant},
    {"name": "Salary", "icon": Icons.work_outline},
    {"name": "Freelance", "icon": Icons.laptop_chromebook},
    {"name": "Groceries", "icon": Icons.local_grocery_store_outlined},
    {"name": "Rent", "icon": Icons.home_outlined},
    {"name": "Transportation", "icon": Icons.directions_car_outlined},
    {"name": "Bills & Utilities", "icon": Icons.receipt_long_outlined},
    {"name": "Shopping", "icon": Icons.shopping_bag_outlined},
    {"name": "Health & Medical", "icon": Icons.medical_services_outlined},
    {"name": "Entertainment", "icon": Icons.movie_outlined},
    {"name": "Investment", "icon": Icons.trending_up},
  ];

  @override
  void initState() {
    super.initState();
    context.read<CategoryBloc>().add(CategoryGetEvent());
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains("food") ||
        lower.contains("dining") ||
        lower.contains("lunch") ||
        lower.contains("dinner") ||
        lower.contains("restaurant")) {
      return Icons.restaurant;
    }
    if (lower.contains("job") ||
        lower.contains("salary") ||
        lower.contains("work")) {
      return Icons.work_outline;
    }
    if (lower.contains("freelance") ||
        lower.contains("code") ||
        lower.contains("dev")) {
      return Icons.laptop_chromebook;
    }
    if (lower.contains("rent") ||
        lower.contains("home") ||
        lower.contains("house")) {
      return Icons.home_outlined;
    }
    if (lower.contains("transport") ||
        lower.contains("car") ||
        lower.contains("fuel") ||
        lower.contains("gas") ||
        lower.contains("bus") ||
        lower.contains("train")) {
      return Icons.directions_car_outlined;
    }
    if (lower.contains("grocery") ||
        lower.contains("groceries") ||
        lower.contains("market")) {
      return Icons.local_grocery_store_outlined;
    }
    if (lower.contains("bill") ||
        lower.contains("utility") ||
        lower.contains("electricity") ||
        lower.contains("water") ||
        lower.contains("wifi")) {
      return Icons.receipt_long_outlined;
    }
    if (lower.contains("shop") || lower.contains("store")) {
      return Icons.shopping_bag_outlined;
    }
    if (lower.contains("health") ||
        lower.contains("medical") ||
        lower.contains("doctor") ||
        lower.contains("medicine")) {
      return Icons.medical_services_outlined;
    }
    if (lower.contains("entertainment") ||
        lower.contains("movie") ||
        lower.contains("fun")) {
      return Icons.movie_outlined;
    }
    if (lower.contains("invest") || lower.contains("saving")) {
      return Icons.trending_up;
    }
    return Icons.category_outlined;
  }

  void _addCategory(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    context.read<CategoryBloc>().add(
      CategoryAddEvent(
        category: CategoryAddRequestModel(
          name: cleanName,
          createdAt: Timestamp.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Category List',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () {
              context.read<CategoryBloc>().add(CategoryAddDefaultEvent());
            },
            icon: const Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 16,
            ),
            label: const Text(
              'Add Defaults',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocListener<CategoryBloc, CategoryState>(
        listener: (context, state) {
          if (state is CategoryAddSuccess) {
            _categoryController.clear();
            CustomSnackbar.showSuccess(
              context: context,
              message: "Category updated successfully",
            );
            context.read<CategoryBloc>().add(CategoryGetEvent());
          } else if (state is CategoryAddError) {
            CustomSnackbar.showError(context: context, message: state.message);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add Category input field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _categoryController,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (value) => _addCategory(value),
                        decoration: const InputDecoration(
                          hintText: 'Add Category',
                          hintStyle: TextStyle(color: Colors.white60),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: IconButton(
                      onPressed: () => _addCategory(_categoryController.text),
                      icon: BlocBuilder<CategoryBloc, CategoryState>(
                        buildWhen: (previous, current) =>
                            current is CategoryAddLoading ||
                            current is CategoryAddError ||
                            current is CategoryAddSuccess ||
                            current is CategoryInitial,
                        builder: (context, state) {
                          if (state is CategoryAddLoading) {
                            return const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            );
                          }
                          return const Icon(Icons.add, color: Colors.white);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Suggested Default Categories Chips
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: const Text(
                'Suggested Categories:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = _quickSuggestions[index];
                  final name = item["name"] as String;
                  final icon = item["icon"] as IconData;

                  return ActionChip(
                    avatar: Icon(icon, color: AppColors.primaryLight, size: 15),
                    backgroundColor: const Color.fromARGB(255, 18, 22, 50),
                    side: const BorderSide(color: Colors.white12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    label: Text(
                      "+ $name",
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    onPressed: () => _addCategory(name),
                  );
                },
              ),
            ),

            const Divider(height: 1, color: Colors.white12),

            // Category List
            BlocBuilder<CategoryBloc, CategoryState>(
              buildWhen: (previous, current) {
                return current is CategoryGetLoading ||
                    current is CategoryGetError ||
                    current is CategoryGetSuccess;
              },
              builder: (context, state) {
                if (state is CategoryGetLoading) {
                  return const Expanded(
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  );
                }
                if (state is CategoryGetError) {
                  return Expanded(
                    child: Center(
                      child: AppErrorMessage(message: state.message),
                    ),
                  );
                }
                if (state is CategoryGetSuccess) {
                  if (state.categories.isEmpty) {
                    return Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.category_outlined,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No Categories Found",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Tap below to add standard income & expense categories with one click:",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  context.read<CategoryBloc>().add(
                                    CategoryAddDefaultEvent(),
                                  );
                                },
                                icon: const Icon(Icons.auto_awesome, size: 18),
                                label: const Text("✨ Add Default Categories"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return Expanded(
                    child: ListView.builder(
                      itemCount: state.categories.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemBuilder: (context, index) {
                        final cat = state.categories[index];
                        final catIcon = _getCategoryIcon(cat.name);

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                catIcon,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              cat.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white30,
                              size: 14,
                            ),
                            onTap: () {
                              Navigator.pop(context, cat);
                            },
                          ),
                        );
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
