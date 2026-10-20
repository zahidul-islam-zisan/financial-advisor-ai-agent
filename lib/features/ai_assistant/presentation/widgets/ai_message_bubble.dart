import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../data/models/ai_message_model.dart';
import '../../data/models/pending_financial_action_model.dart';
import '../bloc/ai_assistant_bloc.dart';
import '../bloc/ai_assistant_event.dart';

class AiMessageBubble extends StatelessWidget {
  final AiMessageModel message;

  const AiMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final timeStr = DateFormat('hh:mm a').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : message.isError
                        ? Colors.red.withValues(alpha: 0.15)
                        : const Color.fromARGB(255, 20, 24, 52),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
                border: Border.all(
                  color: isUser
                      ? Colors.transparent
                      : message.isError
                          ? Colors.redAccent.withValues(alpha: 0.4)
                          : Colors.white12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isUser && message.isOffline) ...[
                    _buildOfflineBadge(),
                    const SizedBox(height: 6),
                  ],
                  if (message.isLoading)
                    _buildLoadingDots()
                  else
                    _buildFormattedText(message.text, isUser),

                  // Interactive Human Confirmation Card
                  if (message.pendingAction != null) ...[
                    const SizedBox(height: 10),
                    ConfirmationCardWidget(action: message.pendingAction!),
                  ],

                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser ? Colors.white70 : Colors.white38,
                        ),
                      ),
                      if (!isUser && !message.isLoading) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: message.text));
                            CustomSnackbar.showSuccess(
                              context: context,
                              message: 'Copied to clipboard',
                            );
                          },
                          child: const Icon(
                            Icons.copy,
                            size: 12,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(isUser: true),
          ],
        ],
      ),
    );
  }

  Widget _buildOfflineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.bolt, size: 12, color: Colors.amber),
          SizedBox(width: 4),
          Text(
            "Offline Mode",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({required bool isUser}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser
            ? AppColors.primaryLight.withValues(alpha: 0.2)
            : AppColors.primary.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(
          color: isUser ? AppColors.primaryLight : AppColors.primary,
          width: 1.2,
        ),
      ),
      child: Icon(
        isUser ? Icons.person : Icons.auto_awesome,
        size: 16,
        color: isUser ? Colors.white : AppColors.primary,
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          "Pulse AI is thinking...",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildFormattedText(String text, bool isUser) {
    final textColor = isUser ? Colors.white : Colors.white.withValues(alpha: 0.95);
    final spans = <TextSpan>[];

    final boldRegex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final match in boldRegex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.primaryLight,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontFamily: 'Poppins'),
    );
  }
}

/// Dedicated Confirmation Card with single-tap protection and loading indicator
class ConfirmationCardWidget extends StatefulWidget {
  final PendingFinancialActionModel action;

  const ConfirmationCardWidget({super.key, required this.action});

  @override
  State<ConfirmationCardWidget> createState() => _ConfirmationCardWidgetState();
}

class _ConfirmationCardWidgetState extends State<ConfirmationCardWidget> {
  bool _isProcessing = false;
  String? _processingType;

  void _onConfirm() {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingType = 'confirm';
    });
    context
        .read<AiAssistantBloc>()
        .add(ConfirmPendingActionEvent(widget.action.id));
  }

  void _onCancel() {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingType = 'cancel';
    });
    context
        .read<AiAssistantBloc>()
        .add(RejectPendingActionEvent(widget.action.id));
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final isPending = action.isPending;
    final isConfirmed = action.isConfirmed;
    final isRejected = action.isRejected;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isConfirmed
            ? AppColors.primary.withValues(alpha: 0.1)
            : isRejected
                ? Colors.red.withValues(alpha: 0.1)
                : const Color.fromARGB(255, 30, 36, 75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfirmed
              ? AppColors.primary
              : isRejected
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : AppColors.primaryLight.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConfirmed
                    ? Icons.check_circle
                    : isRejected
                        ? Icons.cancel
                        : Icons.security,
                size: 16,
                color: isConfirmed
                    ? AppColors.primary
                    : isRejected
                        ? Colors.redAccent
                        : AppColors.primaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                isConfirmed
                    ? "Action Confirmed & Executed"
                    : isRejected
                        ? "Action Cancelled"
                        : "Human Authorization Required",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isConfirmed
                      ? AppColors.primary
                      : isRejected
                          ? Colors.redAccent
                          : AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            action.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _onCancel,
                    child: _isProcessing && _processingType == 'cancel'
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          )
                        : const Text("Cancel", style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _onConfirm,
                    child: _isProcessing && _processingType == 'confirm'
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Confirm & Save",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
