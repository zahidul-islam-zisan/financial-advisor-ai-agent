import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Represents a deterministic financial transaction for demo purposes.
class DemoTransaction {
  final String id;
  final double amount;
  final String categoryName;
  final String date;
  final String time;
  final String description;
  final bool isIncome;
  final bool isDemo;

  const DemoTransaction({
    required this.id,
    required this.amount,
    required this.categoryName,
    required this.date,
    required this.time,
    required this.description,
    required this.isIncome,
    this.isDemo = true,
  });

  Map<String, dynamic> toMap({String categoryId = '', Timestamp? createdAt}) {
    return {
      'amount': amount,
      'category_id': categoryId,
      'category_name': categoryName,
      'date': date,
      'time': time,
      'description': description,
      'isIncome': isIncome,
      'createdAt': createdAt ?? Timestamp.now(),
      'isDemo': isDemo,
    };
  }
}

/// Pure generator creating deterministic demo transactions for Aug, Sep, and Oct 2026.
class DemoDataGenerator {
  /// Cutoff date invariant: no transaction may have a date after 2026-10-20.
  static const String maxDate = '2026-10-20';

  static List<DemoTransaction> generate() {
    final List<DemoTransaction> list = [];
    final random = Random(42);

    // =========================================================================
    // 1. INCOME
    // Aug & Sep: Salary 60000 on the 1st; Freelance 12000 on Aug 15, 8000 on Sep 18.
    // October has NO salary or freelance.
    // =========================================================================
    list.add(const DemoTransaction(
      id: 'demo_2026-08-01_salary',
      amount: 60000.0,
      categoryName: 'Salary',
      date: '2026-08-01',
      time: '09:00 AM',
      description: 'Monthly Salary',
      isIncome: true,
    ));

    list.add(const DemoTransaction(
      id: 'demo_2026-08-15_freelance',
      amount: 12000.0,
      categoryName: 'Freelance',
      date: '2026-08-15',
      time: '04:30 PM',
      description: 'Freelance Mobile App Project',
      isIncome: true,
    ));

    list.add(const DemoTransaction(
      id: 'demo_2026-09-01_salary',
      amount: 60000.0,
      categoryName: 'Salary',
      date: '2026-09-01',
      time: '09:00 AM',
      description: 'Monthly Salary',
      isIncome: true,
    ));

    list.add(const DemoTransaction(
      id: 'demo_2026-09-18_freelance',
      amount: 8000.0,
      categoryName: 'Freelance',
      date: '2026-09-18',
      time: '05:15 PM',
      description: 'Freelance UI Design',
      isIncome: true,
    ));

    // =========================================================================
    // 2. RECURRING BILLS (Same day each month across Aug, Sep, Oct)
    // House rent: 12000 on the 3rd (Rent & Housing)
    // Electricity bill: 1800/2100/2500 on the 5th (Bills & Utilities)
    // Internet bill: 1000/1000/1050 on the 10th (Bills & Utilities)
    // Mobile recharge: 300/300/350 on the 12th (Bills & Utilities)
    // =========================================================================
    const months = ['2026-08', '2026-09', '2026-10'];

    final rentAmounts = [12000.0, 12000.0, 12000.0];
    final electricityAmounts = [1800.0, 2100.0, 2500.0];
    final internetAmounts = [1000.0, 1000.0, 1050.0];
    final mobileAmounts = [300.0, 300.0, 350.0];

    for (var i = 0; i < months.length; i++) {
      final m = months[i];

      // House rent on 3rd
      list.add(DemoTransaction(
        id: 'demo_$m-03_rent',
        amount: rentAmounts[i],
        categoryName: 'Rent & Housing',
        date: '$m-03',
        time: '10:00 AM',
        description: 'House rent',
        isIncome: false,
      ));

      // Electricity on 5th
      list.add(DemoTransaction(
        id: 'demo_$m-05_electricity',
        amount: electricityAmounts[i],
        categoryName: 'Bills & Utilities',
        date: '$m-05',
        time: '11:30 AM',
        description: 'Electricity bill',
        isIncome: false,
      ));

      // Internet on 10th
      list.add(DemoTransaction(
        id: 'demo_$m-10_internet',
        amount: internetAmounts[i],
        categoryName: 'Bills & Utilities',
        date: '$m-10',
        time: '02:00 PM',
        description: 'Internet bill',
        isIncome: false,
      ));

      // Mobile recharge on 12th
      list.add(DemoTransaction(
        id: 'demo_$m-12_mobile',
        amount: mobileAmounts[i],
        categoryName: 'Bills & Utilities',
        date: '$m-12',
        time: '06:15 PM',
        description: 'Mobile recharge',
        isIncome: false,
      ));
    }

    // =========================================================================
    // 3. SHOPPING
    // Aug: 1500 (T-shirt), Sep: 1800 (Shoes), Oct: 9500 (Headphones)
    // =========================================================================
    list.add(const DemoTransaction(
      id: 'demo_2026-08-20_shopping_tshirt',
      amount: 1500.0,
      categoryName: 'Shopping',
      date: '2026-08-20',
      time: '04:00 PM',
      description: 'T-shirt',
      isIncome: false,
    ));

    list.add(const DemoTransaction(
      id: 'demo_2026-09-22_shopping_shoes',
      amount: 1800.0,
      categoryName: 'Shopping',
      date: '2026-09-22',
      time: '04:45 PM',
      description: 'Shoes',
      isIncome: false,
    ));

    list.add(const DemoTransaction(
      id: 'demo_2026-10-15_shopping_headphones',
      amount: 9500.0,
      categoryName: 'Shopping',
      date: '2026-10-15',
      time: '03:30 PM',
      description: 'Headphones',
      isIncome: false,
    ));

    // =========================================================================
    // 4. FOOD & DINING
    // Aug & Sep: 9 per month, amounts 120-600, varied descriptions
    // October: 3 small food expenses (Oct 2, Oct 7, Oct 14)
    // =========================================================================
    final foodDescriptions = ['Lunch', 'Dinner', 'Cafe', 'Street food', 'Delivery'];

    // August food expenses (9 items)
    final augFoodDays = [2, 4, 7, 11, 14, 18, 22, 26, 29];
    for (var i = 0; i < augFoodDays.length; i++) {
      final day = augFoodDays[i].toString().padLeft(2, '0');
      final desc = foodDescriptions[random.nextInt(foodDescriptions.length)];
      final amt = 120.0 + random.nextInt(481); // 120 to 600
      list.add(DemoTransaction(
        id: 'demo_2026-08-${day}_food_${i + 1}',
        amount: amt,
        categoryName: 'Food & Dining',
        date: '2026-08-$day',
        time: '${12 + (i % 8)}:${(10 + i * 5) % 60} PM',
        description: desc,
        isIncome: false,
      ));
    }

    // September food expenses (9 items)
    final sepFoodDays = [2, 6, 9, 13, 16, 20, 24, 27, 29];
    for (var i = 0; i < sepFoodDays.length; i++) {
      final day = sepFoodDays[i].toString().padLeft(2, '0');
      final desc = foodDescriptions[random.nextInt(foodDescriptions.length)];
      final amt = 120.0 + random.nextInt(481); // 120 to 600
      list.add(DemoTransaction(
        id: 'demo_2026-09-${day}_food_${i + 1}',
        amount: amt,
        categoryName: 'Food & Dining',
        date: '2026-09-$day',
        time: '${12 + (i % 8)}:${(15 + i * 5) % 60} PM',
        description: desc,
        isIncome: false,
      ));
    }

    // October food expenses (3 small items)
    list.add(const DemoTransaction(
      id: 'demo_2026-10-02_food_1',
      amount: 180.0,
      categoryName: 'Food & Dining',
      date: '2026-10-02',
      time: '01:15 PM',
      description: 'Lunch',
      isIncome: false,
    ));
    list.add(const DemoTransaction(
      id: 'demo_2026-10-07_food_2',
      amount: 220.0,
      categoryName: 'Food & Dining',
      date: '2026-10-07',
      time: '05:30 PM',
      description: 'Cafe',
      isIncome: false,
    ));
    list.add(const DemoTransaction(
      id: 'demo_2026-10-14_food_3',
      amount: 350.0,
      categoryName: 'Food & Dining',
      date: '2026-10-14',
      time: '08:45 PM',
      description: 'Dinner',
      isIncome: false,
    ));

    // =========================================================================
    // 5. GROCERIES
    // Aug & Sep: 4 per month, amounts 700-1500
    // =========================================================================
    final augGroceryDays = [6, 13, 21, 28];
    for (var i = 0; i < augGroceryDays.length; i++) {
      final day = augGroceryDays[i].toString().padLeft(2, '0');
      final amt = 700.0 + random.nextInt(801); // 700 to 1500
      list.add(DemoTransaction(
        id: 'demo_2026-08-${day}_groceries_${i + 1}',
        amount: amt,
        categoryName: 'Groceries',
        date: '2026-08-$day',
        time: '11:00 AM',
        description: 'Weekly Groceries',
        isIncome: false,
      ));
    }

    final sepGroceryDays = [4, 11, 19, 26];
    for (var i = 0; i < sepGroceryDays.length; i++) {
      final day = sepGroceryDays[i].toString().padLeft(2, '0');
      final amt = 700.0 + random.nextInt(801); // 700 to 1500
      list.add(DemoTransaction(
        id: 'demo_2026-09-${day}_groceries_${i + 1}',
        amount: amt,
        categoryName: 'Groceries',
        date: '2026-09-$day',
        time: '11:15 AM',
        description: 'Weekly Groceries',
        isIncome: false,
      ));
    }

    // =========================================================================
    // 6. TRANSPORTATION
    // Aug & Sep: 8 per month, amounts 40-250
    // =========================================================================
    final augTransportDays = [3, 8, 10, 16, 19, 23, 27, 30];
    for (var i = 0; i < augTransportDays.length; i++) {
      final day = augTransportDays[i].toString().padLeft(2, '0');
      final amt = 40.0 + random.nextInt(211); // 40 to 250
      list.add(DemoTransaction(
        id: 'demo_2026-08-${day}_transport_${i + 1}',
        amount: amt,
        categoryName: 'Transportation',
        date: '2026-08-$day',
        time: '09:30 AM',
        description: 'Ride fare',
        isIncome: false,
      ));
    }

    final sepTransportDays = [3, 7, 10, 14, 17, 21, 25, 28];
    for (var i = 0; i < sepTransportDays.length; i++) {
      final day = sepTransportDays[i].toString().padLeft(2, '0');
      final amt = 40.0 + random.nextInt(211); // 40 to 250
      list.add(DemoTransaction(
        id: 'demo_2026-09-${day}_transport_${i + 1}',
        amount: amt,
        categoryName: 'Transportation',
        date: '2026-09-$day',
        time: '09:30 AM',
        description: 'Ride fare',
        isIncome: false,
      ));
    }

    // =========================================================================
    // 7. ENTERTAINMENT
    // Aug & Sep: 2 per month, amounts 300-800
    // =========================================================================
    final augEntertainmentDays = [9, 24];
    for (var i = 0; i < augEntertainmentDays.length; i++) {
      final day = augEntertainmentDays[i].toString().padLeft(2, '0');
      final amt = 300.0 + random.nextInt(501); // 300 to 800
      list.add(DemoTransaction(
        id: 'demo_2026-08-${day}_entertainment_${i + 1}',
        amount: amt,
        categoryName: 'Entertainment',
        date: '2026-08-$day',
        time: '07:00 PM',
        description: 'Movie & Outing',
        isIncome: false,
      ));
    }

    final sepEntertainmentDays = [8, 23];
    for (var i = 0; i < sepEntertainmentDays.length; i++) {
      final day = sepEntertainmentDays[i].toString().padLeft(2, '0');
      final amt = 300.0 + random.nextInt(501); // 300 to 800
      list.add(DemoTransaction(
        id: 'demo_2026-09-${day}_entertainment_${i + 1}',
        amount: amt,
        categoryName: 'Entertainment',
        date: '2026-09-$day',
        time: '07:30 PM',
        description: 'Movie & Outing',
        isIncome: false,
      ));
    }

    // =========================================================================
    // 8. HEALTH & MEDICAL
    // Aug & Sep: 1 per month, amounts 500-900
    // =========================================================================
    list.add(DemoTransaction(
      id: 'demo_2026-08-17_health_1',
      amount: 500.0 + random.nextInt(401), // 500 to 900
      categoryName: 'Health & Medical',
      date: '2026-08-17',
      time: '03:00 PM',
      description: 'Pharmacy & Medicine',
      isIncome: false,
    ));

    list.add(DemoTransaction(
      id: 'demo_2026-09-15_health_1',
      amount: 500.0 + random.nextInt(401), // 500 to 900
      categoryName: 'Health & Medical',
      date: '2026-09-15',
      time: '03:15 PM',
      description: 'Pharmacy & Medicine',
      isIncome: false,
    ));

    // Safety assert: verify all generated transactions obey invariants
    for (final t in list) {
      assert(t.amount > 0, 'Amount must be positive');
      assert(t.date.compareTo(maxDate) <= 0, 'Date cannot be after $maxDate');
      assert(t.isDemo == true, 'isDemo must be true');
    }

    return list;
  }
}

/// Service managing Firestore writes and cleanup for demo transactions.
class DemoDataService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DemoDataService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get docId {
    final user = _auth.currentUser;
    final email = user?.email?.toLowerCase().trim();
    final uid = user?.uid.trim();
    if (email != null && email.isNotEmpty && uid != null && uid.isNotEmpty) {
      return '${email}_$uid';
    }
    return null;
  }

  /// Loads deterministic demo data into `users/{docId}/income_expenses`.
  /// Uses existing categories (read-only) to link category_id when available.
  /// Never creates categories, budgets, goals, or audit logs.
  Future<int> loadDemoData() async {
    final currentDocId = docId;
    if (currentDocId == null) {
      throw Exception('User is not authenticated. Please log in first.');
    }

    // 1. Read existing categories (read-only)
    final Map<String, String> categoryNameToId = {};
    try {
      final categoriesSnapshot = await _firestore
          .collection('users')
          .doc(currentDocId)
          .collection('categories')
          .get();

      for (final doc in categoriesSnapshot.docs) {
        final data = doc.data();
        final name = (data['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          categoryNameToId[name.toLowerCase()] = doc.id;
        }
      }
    } catch (_) {
      // If categories read fails or is empty, fallback to empty category_id
    }

    // 2. Generate transactions
    final transactions = DemoDataGenerator.generate();

    // 3. Commit in batches of max 400
    const int batchSize = 400;
    for (var i = 0; i < transactions.length; i += batchSize) {
      final end = (i + batchSize < transactions.length) ? i + batchSize : transactions.length;
      final chunk = transactions.sublist(i, end);
      final batch = _firestore.batch();

      for (final tx in chunk) {
        final catId = categoryNameToId[tx.categoryName.toLowerCase()] ?? '';
        final docRef = _firestore
            .collection('users')
            .doc(currentDocId)
            .collection('income_expenses')
            .doc(tx.id);

        batch.set(docRef, tx.toMap(categoryId: catId));
      }

      await batch.commit();
    }

    return transactions.length;
  }

  /// Removes all transactions where isDemo == true from `users/{docId}/income_expenses`.
  /// Never deletes a document without isDemo == true.
  Future<int> removeDemoData() async {
    final currentDocId = docId;
    if (currentDocId == null) {
      throw Exception('User is not authenticated. Please log in first.');
    }

    final querySnapshot = await _firestore
        .collection('users')
        .doc(currentDocId)
        .collection('income_expenses')
        .where('isDemo', isEqualTo: true)
        .get();

    final docs = querySnapshot.docs;
    if (docs.isEmpty) return 0;

    const int batchSize = 400;
    for (var i = 0; i < docs.length; i += batchSize) {
      final end = (i + batchSize < docs.length) ? i + batchSize : docs.length;
      final chunk = docs.sublist(i, end);
      final batch = _firestore.batch();

      for (final doc in chunk) {
        // Safety invariant: never delete a doc without isDemo == true
        final data = doc.data();
        if (data['isDemo'] == true) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
    }

    return docs.length;
  }
}
