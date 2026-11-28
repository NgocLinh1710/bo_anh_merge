import 'package:flutter/material.dart';

import '../main.dart';
import '../models/collection_quiz.dart';

class CollectionQuizDialog extends StatefulWidget {
  final String collectionName;
  final int price;
  final CollectionQuiz quiz;
  final Future<QuizAnswerResult> Function(QuizAnswer) onSubmit;

  const CollectionQuizDialog({
    super.key,
    required this.collectionName,
    required this.price,
    required this.quiz,
    required this.onSubmit,
  });

  @override
  State<CollectionQuizDialog> createState() => _CollectionQuizDialogState();
}

class _CollectionQuizDialogState extends State<CollectionQuizDialog> {
  DateTime? _date;
  int? _option;
  bool _submitting = false;
  QuizAnswerResult? _result;
  String? _error;

  bool get _hasAnswer =>
      widget.quiz.isDateQuestion ? _date != null : _option != null;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2026),
      lastDate: DateTime(2026, 12, 31),
      initialDate: _date ?? DateTime(2026),
      helpText: 'Chọn ngày trong năm 2026',
      cancelText: 'Hủy',
      confirmText: 'Chọn ngày',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (!mounted || date == null) return;
    setState(() => _date = date);
  }

  Future<void> _submit() async {
    if (_submitting || !_hasAnswer || _result != null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit(
        widget.quiz.isDateQuestion
            ? QuizAnswer.date(_date!)
            : QuizAnswer.option(_option!),
      );
      if (!mounted) return;
      if (result == QuizAnswerResult.correct) {
        Navigator.pop(context, true);
      } else {
        setState(() => _result = result);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa xác nhận được kết quả. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final closed = _result != null;
    final dateLabel = _date == null
        ? '--/--/2026'
        : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/2026';
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        backgroundColor: AppColors.cream,
        scrollable: true,
        title: Text('Câu hỏi • ${widget.collectionName}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.quiz.question,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.quiz.isDateQuestion)
                OutlinedButton.icon(
                  onPressed: _submitting || closed ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(dateLabel),
                )
              else
                ...List.generate(
                  widget.quiz.options.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      selected: _option == i,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _option == i
                              ? AppColors.butterLight
                              : Colors.white,
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: _submitting || closed
                            ? null
                            : () => setState(() => _option = i),
                        child: Row(
                          children: [
                            Icon(
                              _option == i
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(widget.quiz.options[i])),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                _result == QuizAnswerResult.incorrect
                    ? 'Trả lời chưa đúng. Ver đã khóa lại. Muốn thử lại, bạn cần mở khóa với ${widget.price} xu.'
                    : _result == QuizAnswerResult.locked
                    ? 'Ver đang khóa. Hãy quay lại mở khóa trước khi trả lời.'
                    : 'Mỗi lần vào chơi cần trả lời đúng. Trả lời sai sẽ khóa lại ver; lần mở tiếp theo tốn ${widget.price} xu. Đóng câu hỏi khi chưa gửi không bị tính sai.',
                style: TextStyle(
                  color: closed ? Colors.deepOrange : AppColors.text,
                  fontSize: 13,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.deepOrange)),
              ],
            ],
          ),
        ),
        actions: closed
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Về bộ sưu tập'),
                ),
              ]
            : [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Để sau'),
                ),
                FilledButton(
                  onPressed: !_hasAnswer || _submitting ? null : _submit,
                  child: Text(_submitting ? 'Đang lưu...' : 'Trả lời'),
                ),
              ],
      ),
    );
  }
}
