import 'package:flutter/material.dart';

class SecretTaxGuideScreen extends StatelessWidget {
  const SecretTaxGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).textTheme.bodyLarge!.color!),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('비밀 신고 가이드', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '회사에 알리기 싫은 내역,\n조용히 환급받는 법',
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                '월세 내역이나 민감한 의료비 등 회사에 제출하기 껄끄러운 자료는 연말정산 때 빼고, 5월 종합소득세 정기신고 때 개인이 직접 추가하여 동일한 혜택을 받을 수 있습니다.',
                style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 32),
              
              _buildSectionTitle(context, '주요 민감 정보 공제 항목 및 필요 서류', Icons.folder_special_rounded),
              const SizedBox(height: 16),
              _buildInfoCard(context, title: '월세 세액공제',
                description: '집주인 눈치 보거나 회사에 알리기 싫어서 연말정산 때 신청하지 않은 월세 내역',
                documents: ['임대차계약서 사본', '월세 이체 내역(이체확인증)', '주민등록등본'],
              ),
              const SizedBox(height: 12),
              _buildInfoCard(context, title: '민감한 의료비 세액공제',
                description: '난임시술비, 정신과 진료비, 특정 질환 수술비 등 사생활 보호가 필요한 병원비 내역',
                documents: ['의료비 영수증', '진료비 납입 확인서 (해당 병원 발급)'],
              ),
              const SizedBox(height: 12),
              _buildInfoCard(context, title: '부양가족 공제 (가족관계)',
                description: '부모님 부양 사실이나 특정 가족관계를 회사에 노출하고 싶지 않은 경우',
                documents: ['가족관계증명서', '주민등록등본'],
              ),
              const SizedBox(height: 32),
              
              _buildSectionTitle(context, '홈택스(손택스) 신고 방법 가이드', Icons.devices_rounded),
              const SizedBox(height: 16),
              _buildStepCard(context, step: 'STEP 1',
                title: '5월 종합소득세 신고 기간에 홈택스 접속',
                description: '매년 5월 1일 ~ 5월 31일 사이에 홈택스에 로그인합니다. (간편인증 지원)',
              ),
              const SizedBox(height: 12),
              _buildStepCard(context, step: 'STEP 2',
                title: '종합소득세 정기신고 작성',
                description: '[신고/납부] > [종합소득세] > [근로소득 신고] 또는 [일반신고서] 메뉴로 들어갑니다.',
              ),
              const SizedBox(height: 12),
              _buildStepCard(context, step: 'STEP 3',
                title: '기존 연말정산 내역 불러오기',
                description: '회사에서 이미 진행했던 연말정산 데이터가 자동으로 불려옵니다. 이 데이터는 건드리지 마세요.',
              ),
              const SizedBox(height: 12),
              _buildStepCard(context, step: 'STEP 4',
                title: '누락했던 민감 정보 추가 입력',
                description: '다음 단계로 넘어가며 [세액공제] 항목에서 월세, 의료비 등 회사에 제출하지 않았던 금액을 추가로 입력합니다.',
              ),
              const SizedBox(height: 12),
              _buildStepCard(context, step: 'STEP 5',
                title: '증빙 서류 제출 및 신고 완료',
                description: '준비한 증빙 서류를 스캔(또는 사진 촬영)하여 파일로 첨부한 후 제출하면 추가 환급이 접수됩니다.',
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required String description, required List<String> documents}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFFFFC107), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Color(0xFFE5E8EB), fontSize: 14, height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.file_copy_rounded, color: Theme.of(context).textTheme.labelMedium!.color!, size: 14),
                    SizedBox(width: 6),
                    Text('필요 서류', style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ...documents.map((doc) => Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Color(0xFFE5E8EB), fontSize: 14)),
                      Expanded(child: Text(doc, style: const TextStyle(color: Color(0xFFE5E8EB), fontSize: 14))),
                    ],
                  ),
                )),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStepCard(BuildContext context, {required String step, required String title, required String description}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(step, style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(description, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 14, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
