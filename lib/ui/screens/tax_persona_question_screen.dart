import 'package:flutter/material.dart';

class TaxPersonaQuestionScreen extends StatefulWidget {
  final String initialUserType;

  const TaxPersonaQuestionScreen({super.key, required this.initialUserType});

  @override
  State<TaxPersonaQuestionScreen> createState() => _TaxPersonaQuestionScreenState();
}

class _TaxPersonaQuestionScreenState extends State<TaxPersonaQuestionScreen> {
  int _currentStep = 0;
  bool _hasExtraIncome = false;

  void _nextStep(bool hasIncome) {
    if (hasIncome) {
      _hasExtraIncome = true;
    }
    
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    String newUserType = widget.initialUserType;
    if (widget.initialUserType == '직장인' && _hasExtraIncome) {
      newUserType = 'N잡러';
    } else if (widget.initialUserType == '프리랜서' && _hasExtraIncome) {
      // 프리랜서인데 다른 소득(직장 등)이 있으면 N잡러일 수 있음
      newUserType = 'N잡러';
    }

    Navigator.pop(context, newUserType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('절세 유형 진단', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_currentStep + 1) / 4,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentQuestion(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentQuestion() {
    switch (_currentStep) {
      case 0:
        return _buildQuestionView(
          key: const ValueKey(0),
          title: '회사 월급 외에 강연료, 상금 등으로 받은 기타소득이 연 300만 원을 넘나요?',
          icon: Icons.mic_external_on_rounded,
        );
      case 1:
        return _buildQuestionView(
          key: const ValueKey(1),
          title: '주식 배당금이나 예적금 이자로 받은 금융소득이 연 2,000만 원을 넘나요?',
          icon: Icons.account_balance_rounded,
        );
      case 2:
        return _buildQuestionView(
          key: const ValueKey(2),
          title: '회사를 이직하셨거나 두 군데 이상에서 일하시면서 연말정산 때 소득을 합치지 않으셨나요?',
          icon: Icons.business_center_rounded,
        );
      case 3:
      default:
        return _buildQuestionView(
          key: const ValueKey(3),
          title: '금액에 상관없이 작년에 배달, 외주 등 본인 명의로 사업/프리랜서 소득이 발생했나요?',
          icon: Icons.storefront_rounded,
        );
    }
  }

  Widget _buildQuestionView({required Key key, required String title, required IconData icon}) {
    return Column(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: Theme.of(context).primaryColor),
        const SizedBox(height: 32),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.4),
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _nextStep(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).dividerColor,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('아니오', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _nextStep(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('예', style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        )
      ],
    );
  }
}
