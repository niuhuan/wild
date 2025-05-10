import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'account_cubit.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AccountCubit()..loadUserDetail(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('账户'),
        ),
        body: BlocBuilder<AccountCubit, AccountState>(
          builder: (context, state) {
            switch (state.status) {
              case AccountStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case AccountStatus.error:
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(state.errorMessage ?? '加载失败'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<AccountCubit>().loadUserDetail();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                );
              case AccountStatus.loaded:
                final userDetail = state.userDetail;
                if (userDetail == null) {
                  return const Center(child: Text('未找到用户信息'));
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSection(
                      context,
                      '基本信息',
                      [
                        _buildInfoRow('用户名', userDetail.username),
                        _buildInfoRow('昵称', userDetail.nickname),
                        _buildInfoRow('用户ID', userDetail.userId),
                        _buildInfoRow('等级', userDetail.level),
                        _buildInfoRow('头衔', userDetail.title),
                        _buildInfoRow('性别', userDetail.sex),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context,
                      '联系方式',
                      [
                        _buildInfoRow('邮箱', userDetail.email),
                        _buildInfoRow('QQ', userDetail.qq),
                        _buildInfoRow('MSN', userDetail.msn),
                        _buildInfoRow('网站', userDetail.web),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context,
                      '账户信息',
                      [
                        _buildInfoRow('注册日期', userDetail.registerDate),
                        _buildInfoRow('贡献值', userDetail.contributePoint),
                        _buildInfoRow('经验值', userDetail.experienceValue),
                        _buildInfoRow('持有积分', userDetail.holdingPoints),
                        _buildInfoRow('好友数量', userDetail.quantityOfFriends),
                        _buildInfoRow('邮件数量', userDetail.quantityOfMail),
                        _buildInfoRow('收藏数量', userDetail.quantityOfCollection),
                        _buildInfoRow('每日推荐', userDetail.quantityOfRecommendDaily),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      context,
                      '个人签名',
                      [
                        _buildInfoRow('签名', userDetail.personalizedSignature),
                        _buildInfoRow('描述', userDetail.personalizedDescription),
                      ],
                    ),
                  ],
                );
              default:
                return const SizedBox();
            }
          },
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '未设置' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 