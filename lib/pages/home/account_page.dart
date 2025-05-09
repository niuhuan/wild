import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wild/pages/home/account_cubit.dart';

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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '用户名：${userDetail.username}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '积分：${userDetail.holdingPoints}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '等级：${userDetail.level}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
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
} 