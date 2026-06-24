import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/data/db_helper.dart';

class TaxRecordListScreen extends StatefulWidget {
  final String recordType; // '연말정산' or '종합소득세'

  const TaxRecordListScreen({super.key, required this.recordType});

  @override
  State<TaxRecordListScreen> createState() => _TaxRecordListScreenState();
}

class _TaxRecordListScreenState extends State<TaxRecordListScreen> {
  final _numberFormat = NumberFormat('#,###');
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final allRecords = await dbService.getTaxRecords();
    setState(() {
      _records = allRecords.where((r) => r['record_type'] == widget.recordType).toList();
      _isLoading = false;
    });
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
        title: Text('${widget.recordType} 기록부', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : _records.isEmpty
              ? _buildEmptyState()
              : _buildRecordList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, color: Theme.of(context).dividerColor, size: 64),
          const SizedBox(height: 16),
          Text(
            '아직 저장된 ${widget.recordType} 기록이 없어요.',
            style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        final year = record['record_year'] as int;
        final grossIncome = record['gross_income'] as double;
        final refundAmount = record['refund_amount'] as double;
        final createdAt = DateTime.parse(record['created_at']);
        final formattedDate = DateFormat('yyyy.MM.dd HH:mm').format(createdAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$year년 귀속', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(formattedDate, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12)),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Theme.of(context).dividerColor, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('세전연봉', style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 14)),
                  Text('${_numberFormat.format(grossIncome.toInt())}원', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('예상 환급액', style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 14)),
                  Text(
                    '${refundAmount > 0 ? '+' : ''}${_numberFormat.format(refundAmount.toInt())}원',
                    style: TextStyle(
                      color: refundAmount >= 0 ? Theme.of(context).primaryColor : Color(0xFFFF4D4D),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
