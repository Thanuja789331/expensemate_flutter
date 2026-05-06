import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  // Default categories list
  static List<CategoryModel> defaultCategories = [
    CategoryModel(
      id: '1',
      name: 'Food & Drinks',
      icon: Icons.restaurant,
      color: Colors.orange,
    ),
    CategoryModel(
      id: '2',
      name: 'Transport',
      icon: Icons.directions_car,
      color: Colors.blue,
    ),
    CategoryModel(
      id: '3',
      name: 'Shopping',
      icon: Icons.shopping_bag,
      color: Colors.pink,
    ),
    CategoryModel(
      id: '4',
      name: 'Bills',
      icon: Icons.receipt_long,
      color: Colors.red,
    ),
    CategoryModel(
      id: '5',
      name: 'Health',
      icon: Icons.local_hospital,
      color: Colors.green,
    ),
    CategoryModel(
      id: '6',
      name: 'Entertainment',
      icon: Icons.movie,
      color: Colors.purple,
    ),
    CategoryModel(
      id: '7',
      name: 'Education',
      icon: Icons.school,
      color: Colors.teal,
    ),
    CategoryModel(
      id: '8',
      name: 'Salary',
      icon: Icons.account_balance_wallet,
      color: Colors.green,
    ),
    CategoryModel(
      id: '9',
      name: 'Freelance',
      icon: Icons.computer,
      color: Colors.indigo,
    ),
    CategoryModel(
      id: '10',
      name: 'Other',
      icon: Icons.category,
      color: Colors.grey,
    ),
  ];
}