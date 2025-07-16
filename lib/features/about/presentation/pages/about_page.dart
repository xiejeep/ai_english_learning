import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于我们'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 应用Logo和名称
            Center(
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '版本 ${AppConstants.appVersion}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // 应用介绍
            _buildSection(
              context,
              '应用介绍',
              '趣TALK伙伴是一款专为英语学习者设计的智能对话应用。通过AI技术，为用户提供个性化的英语学习体验，让英语学习变得更加有趣和高效。',
              Icons.info_outline,
            ),
            
            // 核心功能
            _buildSection(
              context,
              '核心功能',
              '• 智能AI对话：与AI进行自然的英语对话练习\n'
              '• 文本转语音：AI朗读功能，帮助改善发音\n'
              '• 个性化学习：根据用户水平调整对话难度\n'
              '• 积分系统：通过学习获得积分奖励',
              Icons.star_outline,
            ),
            
            // 学习理念
            _buildSection(
              context,
              '学习理念',
              '我们相信最好的语言学习方式是通过实际对话练习。趣TALK伙伴提供一个安全、友好的环境，让用户可以自信地练习英语，不用担心犯错或被评判。',
              Icons.lightbulb_outline,
            ),
            
            // 技术支持
            _buildSection(
              context,
              '技术支持',
              '本应用采用先进的AI技术，包括自然语言处理、语音识别和文本转语音技术，为用户提供流畅的学习体验。我们持续优化算法，确保对话的自然性和教育价值。',
              Icons.computer_outlined,
            ),
            
            // 联系我们
            _buildSection(
              context,
              '联系我们',
              '如果您有任何问题、建议或反馈，欢迎通过以下方式联系我们：\n\n'
              '邮箱：support@qutalk.com\n'
              '官网：www.qutalk.com\n\n'
              '我们重视每一位用户的意见，您的反馈将帮助我们不断改进产品。',
              Icons.contact_mail_outlined,
            ),
            
            const SizedBox(height: 32),
            
            // 版权信息
            Center(
              child: Column(
                children: [
                  Text(
                    '© 2024 趣TALK伙伴',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '让英语学习更有趣',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection(BuildContext context, String title, String content, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppConstants.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}