import 'package:expense_tracker_app/app/route/app_routes.dart';
import 'package:expense_tracker_app/features/auth/presentation/pages/registion_page.dart';
import 'package:expense_tracker_app/features/splash/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/add_income_expense/presentation/pages/add_income_expense_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/ai_assistant/presentation/pages/ai_assistant_page.dart';
import '../../features/category/presentation/pages/catagory_list_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/menu/presentation/pages/menu_page.dart';
import '../../features/root/presentation/pages/root_page.dart';
import '../../features/transactions/data/models/transaction_list_response_model.dart';
import '../../features/transactions/presentation/bloc/transaction_bloc.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => LoginPage());
      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => RegistrationPage());
      case AppRoutes.dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardPage());
      case AppRoutes.root:
        return MaterialPageRoute(builder: (_) => const RootPage());
      case AppRoutes.transaction:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => TransactionBloc(),
            child: const TransactionsPage(),
          ),
        );
      case AppRoutes.menu:
        return MaterialPageRoute(builder: (_) => const MenuPage());
      case AppRoutes.addIncomeExpense:
        final transaction = settings.arguments as TransactionListResponseModel?;
        return MaterialPageRoute(
          builder: (_) => AddIncomeExpensePage(transaction: transaction),
        );
      case AppRoutes.catagoryList:
        return MaterialPageRoute(builder: (_) => CatagoryListPage());
      case AppRoutes.aiAssistant:
        return MaterialPageRoute(builder: (_) => const AiAssistantPage());
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}
