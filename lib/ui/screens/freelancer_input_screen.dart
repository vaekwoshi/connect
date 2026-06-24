import 'package:flutter/material.dart';
import '../components/amount_field.dart';
import '../../core/data/occupation_data.dart';
import '../components/occupation_search_bottom_sheet.dart';

class FreelancerInputScreen extends StatefulWidget {
  final OccupationInfo? initialOccupation;
  final String initialIncome;
  final bool initialHasYellowUmbrella;
  final String initialYellowUmbrella;

  const FreelancerInputScreen({
    super.key,
    this.initialOccupation,
    this.initialIncome = '',
    this.initialHasYellowUmbrella = false,
    this.initialYellowUmbrella = '',
  });

  @override
  State<FreelancerInputScreen> createState() => _FreelancerInputScreenState();
}

class _FreelancerInputScreenState extends State<FreelancerInputScreen> {
  late OccupationInfo? _selectedOccupation;
  late TextEditingController _incomeController;
  late bool _hasYellowUmbrella;
  late TextEditingController _yellowUmbrellaController;

  @override
  void initState() {
    super.initState();
    _selectedOccupation = widget.initialOccupation;
    _incomeController = TextEditingController(text: widget.initialIncome);
    _hasYellowUmbrella = widget.initialHasYellowUmbrella;
    _yellowUmbrellaController = TextEditingController(text: widget.initialYellowUmbrella);
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _yellowUmbrellaController.dispose();
    super.dispose();
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        AmountField(controller: controller, expand: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).textTheme.bodyLarge!.color!),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('프리랜서 소득 정보', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('정확한 5월 종합소득세를 위해\n수입 정보를 입력해주세요.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.w800, height: 1.4)),
                  const SizedBox(height: 32),
                  Text('나의 프리랜서 업종코드', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final result = await OccupationSearchBottomSheet.show(context);
                      if (result != null) {
                        setState(() => _selectedOccupation = result);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedOccupation?.code ?? '업종코드를 검색해주세요',
                              style: TextStyle(color: _selectedOccupation != null ? Theme.of(context).textTheme.bodyLarge!.color! : Theme.of(context).textTheme.labelMedium!.color!, fontSize: 16),
                            ),
                          ),
                          Icon(Icons.search, color: Theme.of(context).primaryColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInputField('현재까지 누적 수입 (3.3% 떼기 전)', _incomeController, '예: 30,000,000'),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('노란우산공제 가입', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.bold)),
                      Switch(
                        value: _hasYellowUmbrella,
                        onChanged: (val) => setState(() => _hasYellowUmbrella = val),
                        activeColor: Theme.of(context).scaffoldBackgroundColor,
                        activeTrackColor: Theme.of(context).primaryColor,
                        inactiveTrackColor: Theme.of(context).dividerColor,
                      ),
                    ],
                  ),
                  if (_hasYellowUmbrella) ...[
                    const SizedBox(height: 16),
                    _buildInputField('올해 총 납입 예상액', _yellowUmbrellaController, '예: 3,000,000'),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context, {
                    'occupation': _selectedOccupation,
                    'income': _incomeController.text,
                    'hasYellowUmbrella': _hasYellowUmbrella,
                    'yellowUmbrella': _yellowUmbrellaController.text,
                  });
                },
                child: Container(
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Theme.of(context).textTheme.bodyLarge!.color!, borderRadius: BorderRadius.circular(16)),
                  child: Text('저장하기', style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
