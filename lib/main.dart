import 'package:expense_tracker_app/app/app_theme.dart';
import 'package:expense_tracker_app/features/category/presentation/bloc/category_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker_app/app/route/app_routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_value.dart';
import 'features/add_income_expense/presentation/bloc/add_income_expense_bloc.dart';
import 'features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/transactions/presentation/bloc/transaction_bloc.dart';
import 'firebase_options.dart';
import 'app/route/app_router.dart';
import 'core/widgets/mesh_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (context) => AuthBloc()),
        BlocProvider<CategoryBloc>(create: (context) => CategoryBloc()),
        BlocProvider<AddIncomeExpenseBloc>(create: (context) => AddIncomeExpenseBloc()),
        BlocProvider<TransactionBloc>(create: (context) => TransactionBloc()),
        BlocProvider<DashboardBloc>(create: (context) => DashboardBloc()),
        BlocProvider<AiAssistantBloc>(create: (context) => AiAssistantBloc()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppValue.appName,
        theme: appTheme,
        builder: (context, child) {
          return MeshBackground(child: child!);
        },
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: AppRoutes.splash,
      ),
    ); 
  }
}
