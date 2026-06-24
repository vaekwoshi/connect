import 'package:flutter/material.dart';
import '../../core/data/expense_item.dart';

class FreelancerBookScreen extends StatefulWidget {
  const FreelancerBookScreen({super.key});

  @override
  State<FreelancerBookScreen> createState() => _FreelancerBookScreenState();
}

class _FreelancerBookScreenState extends State<FreelancerBookScreen> {
  // 현재 지출 내역 리스트 (Phase 1 에서는 일단 비워둠)
  final List<ExpenseItem> _expenses = [];

  void _onAddExpensePressed() {
    // Phase 2에서 바텀시트 열기 구현 예정
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phase 2에서 지출 추가 바텀시트가 열립니다!'),
        backgroundColor: Theme.of(context).cardColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // 앱 배경색
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyLarge!.color!),
        title: Text(
          '나의 간편장부',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge!.color!,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _expenses.isEmpty ? _buildEmptyState() : _buildExpenseList(),
            ),
            // 하단 고정 버튼 (안전영역 포함)
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 16),
              child: BookTossButton(
                text: '지출 내역 추가하기',
                onTap: _onAddExpensePressed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 64,
            color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.2),
          ),
          const SizedBox(height: 24),
          Text(
            '아직 기록된 지출이 없어요',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color!,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '세금을 줄이는 첫 걸음,\n오늘의 지출을 꼼꼼하게 기록해보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.6),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    // Phase 2에서 구현될 리스트 뷰
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _expenses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return const SizedBox.shrink();
      },
    );
  }
}

// 토스 스타일 물리적 스케일 애니메이션 버튼 컴포넌트 (장부 전용)
class BookTossButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const BookTossButton({super.key, required this.text, required this.onTap});

  @override
  State<BookTossButton> createState() => _BookTossButtonState();
}

class _BookTossButtonState extends State<BookTossButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).textTheme.bodyLarge!.color!, // 포인트 컬러 규칙: 백그라운드 White
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              color: Theme.of(context).scaffoldBackgroundColor, // 텍스트는 대비되는 딥블랙
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
