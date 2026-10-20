import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/ai_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../bloc/ai_assistant_bloc.dart';
import '../bloc/ai_assistant_event.dart';
import '../bloc/ai_assistant_state.dart';
import '../widgets/ai_message_bubble.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Load user's latest monthly transactions for personalized financial advice
    context.read<AiAssistantBloc>().add(LoadFinancialContextEvent());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? customPrompt]) {
    final text = customPrompt ?? _textController.text;
    if (text.trim().isEmpty) return;

    context.read<AiAssistantBloc>().add(SendAiMessageEvent(text));
    _textController.clear();
    _scrollToBottom();
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 15, 20, 45),
        title: const Text('Clear Chat', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Do you want to reset this conversation?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          TextButton(
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              context.read<AiAssistantBloc>().add(ClearChatEvent());
              Navigator.pop(dialogCtx);
            },
          ),
        ],
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
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Pulse AI Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Financial Advisor & Budget Copilot',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear Conversation',
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () => _showClearConfirmation(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List with snackbar feedback for actions
            Expanded(
              child: BlocConsumer<AiAssistantBloc, AiAssistantState>(
                listener: (context, state) {
                  _scrollToBottom();
                  if (state.successMessage != null && state.successMessage!.isNotEmpty) {
                    CustomSnackbar.showSuccess(
                      context: context,
                      message: state.successMessage!,
                    );
                  } else if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
                    CustomSnackbar.showError(
                      context: context,
                      message: state.errorMessage!,
                    );
                  }
                },
                builder: (context, state) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return AiMessageBubble(message: message);
                    },
                  );
                },
              ),
            ),

            // Quick suggestion chips
            Container(
              height: 42,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: AiConfig.quickSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final suggestion = AiConfig.quickSuggestions[index];
                  return ActionChip(
                    backgroundColor: const Color.fromARGB(255, 20, 24, 52),
                    side: const BorderSide(color: Colors.white12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    label: Text(
                      suggestion,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    onPressed: () => _sendMessage(suggestion),
                  );
                },
              ),
            ),

            // Chat input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 14, 16, 40),
                border: Border(
                  top: BorderSide(color: Colors.white10),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: "Ask Pulse AI about your finances...",
                          hintStyle: TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BlocBuilder<AiAssistantBloc, AiAssistantState>(
                    builder: (context, state) {
                      return InkWell(
                        onTap: state.isLoading ? null : () => _sendMessage(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: state.isLoading
                                ? AppColors.grey
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            state.isLoading ? Icons.hourglass_top : Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Disclaimer footer
            Container(
              width: double.infinity,
              color: const Color.fromARGB(255, 14, 16, 40),
              padding: const EdgeInsets.only(bottom: 6, top: 2),
              child: const Text(
                "This is a suggestion, not professional financial advice.",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white38,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
