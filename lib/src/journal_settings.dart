part of '../main.dart';

void _openJournalSettings(BuildContext context, ManualTimerController timer) =>
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => _JournalSettings(timer: timer)),
    );

class _ManualExperience extends StatefulWidget {
  const _ManualExperience({required this.timer, required this.onConnect});
  final ManualTimerController timer;
  final VoidCallback? onConnect;
  @override
  State<_ManualExperience> createState() => _ManualExperienceState();
}

class _ManualExperienceState extends State<_ManualExperience> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chronos'),
      actions: [
        IconButton(
          tooltip: '手账设置',
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => _JournalSettings(
                timer: widget.timer,
                onConnect: widget.onConnect,
              ),
            ),
          ),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 610),
        child: IndexedStack(
          index: tab,
          children: [
            _page([
              _Eyebrow('${_manualDate(DateTime.now())} · 本机记录'),
              const SizedBox(height: 8),
              const _Heading('今天的手账'),
              const SizedBox(height: 20),
              _TimerHero(timer: widget.timer),
              const SizedBox(height: 24),
              _ManualToday(timer: widget.timer),
            ]),
            _page([
              const _Eyebrow('最近七天'),
              const SizedBox(height: 8),
              const _Heading('时间的轨迹'),
              const SizedBox(height: 24),
              _ManualWeek(timer: widget.timer),
            ]),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 610),
          child: _Nav(
            tab: tab,
            journalOnly: true,
            timer: widget.timer,
            onTap: (value) => setState(() => tab = value),
            onTimerOpen: () => _showManualEntryEditor(
              context,
              widget.timer,
              entry: widget.timer.active,
            ),
          ),
        ),
      ),
    ),
  );
}

class _JournalSettings extends StatefulWidget {
  const _JournalSettings({required this.timer, this.onConnect});
  final ManualTimerController timer;
  final VoidCallback? onConnect;
  @override
  State<_JournalSettings> createState() => _JournalSettingsState();
}

class _JournalSettingsState extends State<_JournalSettings> {
  bool busy = false;
  String version = '正在读取版本';
  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() => version = '${info.version} (${info.buildNumber})');
          }
        })
        .catchError((Object _) {
          if (mounted) setState(() => version = '开发预览');
        });
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> perform(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } on FormatException catch (error) {
      message(error.message.toString());
    } catch (_) {
      message('操作未完成，请检查文件与设备可用空间后重试。原有记录保持不变。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export({bool csv = false}) => perform(() async {
    final payload = csv
        ? await widget.timer.exportCsv()
        : await widget.timer.exportBackup();
    final date = _dateKey(DateTime.now());
    final result = await FilePicker.saveFile(
      fileName: 'chronos-$date.${csv ? 'csv' : 'json'}',
      bytes: Uint8List.fromList(utf8.encode(payload)),
      mimeType: csv ? 'text/csv' : 'application/json',
    );
    if (result != null) {
      message(csv ? 'CSV 已导出，可用于查看；恢复记录请使用 JSON 备份。' : '手账备份已导出。');
    }
  });

  Future<void> restore() => perform(() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return;
    const maxBytes = 8 * 1024 * 1024;
    if ((await file.length() ?? 0) > maxBytes) {
      throw const FormatException('备份超过 8 MB');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('备份超过 8 MB');
      }
      bytes.add(chunk);
    }
    final raw = utf8.decode(bytes.takeBytes());
    final entries = ManualTimerController.readBackup(raw);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('合并手账备份？'),
        content: Text(
          '文件中有 ${entries.length} 段记录。相同记录会跳过；遇到冲突或时间重叠会停止，保留本机原有记录。备份不包含目标、系统使用数据和外观偏好。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('合并恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await widget.timer.importBackup(raw);
    message(error ?? '手账已合并恢复。');
  });

  Future<void> clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除全部手账记录？'),
        content: const Text(
          '将删除本机全部手动记录和进行中的计时。此操作不能撤销，建议先导出备份。系统使用时间和设备目标不会删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除手账'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await perform(() async {
        message(
          await widget.timer.clear()
              ? '本机手账已删除。'
              : widget.timer.error ?? '删除失败',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('手账设置')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 610),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _Section('你的数据，由你保管', '手账默认保存在本机'),
            const SizedBox(height: 10),
            const _Hint('备份只包含手动记录，文件不加密。请选择你信任的保存位置。'),
            const SizedBox(height: 14),
            if (busy) const LinearProgressIndicator(),
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: const Text('导出手账备份'),
              subtitle: const Text('JSON · 可恢复到另一台设备'),
              enabled: !busy,
              onTap: () => export(),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('导出 CSV'),
              subtitle: const Text('用于表格查看 · 不作为恢复文件'),
              enabled: !busy,
              onTap: () => export(csv: true),
            ),
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('从备份恢复'),
              subtitle: const Text('先检查，再确认合并'),
              enabled: !busy,
              onTap: restore,
            ),
            const ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 16),
              title: Text('备份包含什么？', style: TextStyle(fontSize: 13)),
              childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  'JSON 包含手动记录的分类、备注和计时区间，不包含目标、系统使用数据和外观偏好。导出运行中的计时会生成截至导出时刻的已结束备份，手机上的计时继续。系统文件选择器可能提供云盘，由你选择是否使用。',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
            const Divider(height: 30),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('外观主题'),
              subtitle: Text(ChronosThemeScope.of(context).choice.label),
              onTap: () => showChronosThemePicker(context),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('使用指南'),
              onTap: () => _showInformation(context, privacy: false),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('隐私与数据说明'),
              onTap: () => _showInformation(context, privacy: true),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('开源许可'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Chronos · 柯罗诺斯',
                applicationVersion: version,
              ),
            ),
            if (widget.onConnect != null)
              ListTile(
                leading: const Icon(Icons.phone_android_outlined),
                title: const Text('连接设备使用时间'),
                subtitle: const Text('手账无需此权限；已有目标仍按原设置检查，可连接后管理'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onConnect!();
                },
              ),
            const Divider(height: 30),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: chronosColors(context).danger,
              ),
              title: const Text('删除全部手账记录'),
              enabled: !busy,
              onTap: clear,
            ),
            const SizedBox(height: 20),
            Center(child: _Hint('Chronos · $version\n开发者 Elton · 当前版本免费')),
          ],
        ),
      ),
    ),
  );
}

void _showInformation(
  BuildContext context, {
  required bool privacy,
}) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text(privacy ? '隐私与数据说明' : '使用指南')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 610),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (privacy) ...[
                const _Section('保存在你手里的时间', '更新于 2026年11月5日 · 开发者 Elton'),
                const SizedBox(height: 20),
                const Text(
                  'Chronos 保存你主动创建的活动分类、备注、起止时间和暂停区间。Android 和 iOS 手账使用应用私有的本地数据库；Web 预览使用浏览器存储。应用不建立账号，不接入广告、第三方行为分析或云端 AI，也不主动把手账发送到开发者服务器。',
                ),
                const SizedBox(height: 18),
                const Text(
                  '设备使用数据是独立功能。Android 仅在你允许“使用情况访问权限”后读取系统提供的应用使用统计；目标、提醒状态和偏好保存在本机。通知权限仅用于你启用的目标。iOS 屏幕使用功能尚未接入，不能读取或显示真实报告。',
                ),
                const SizedBox(height: 18),
                const Text(
                  '导出由你主动选择文件位置，备份和 CSV 不加密。文件提供商可能是本地存储或你自己的云盘。不要把含私人备注的文件交给不信任的人。系统可能按平台和设备设置备份或迁移应用数据；这与 Chronos 的主动上传不同。',
                ),
                const SizedBox(height: 18),
                const Text(
                  '你可在设置删除手账，或在设备数据设置删除目标与偏好。删除导出的文件需到对应文件位置操作。卸载应用可能丢失本机数据；撤销使用权限不会删除已有手账或系统历史，系统历史由操作系统管理。',
                ),
                const SizedBox(height: 18),
                const Text(
                  '手动计时不依赖使用时间或通知权限。你可在系统设置撤销权限。开发者 Elton；可通过以下项目反馈地址联系。反馈区公开，请勿提交私人记录、备份文件或敏感设备数据。',
                ),
                const SizedBox(height: 12),
                const SelectableText(
                  'https://github.com/Xhp1193345142/Chronos/issues',
                ),
              ] else ...[
                const _Section('从一段时间开始', '不必把一天填满'),
                const SizedBox(height: 20),
                const Text(
                  '首页点“开始计时”即可记录，也可以点工作、学习或阅读直接开始对应分类。暂停时间不累计；结束后点记录可修改分类和备注。',
                ),
                const SizedBox(height: 18),
                const Text(
                  '补记可以记录已经发生的活动。为避免重复统计，结束时间须晚于开始时间、不能在未来，也不能与已有计时区间重叠。含暂停的记录只能改分类与备注，需要调整起止时间时先导出备份，再删除后补记。',
                ),
                const SizedBox(height: 18),
                const Text(
                  '时间轴上的留白表示尚未记录；分类颜色与文字一起帮助辨认活动。跨午夜的记录会分配到对应的本地日期。运行中的计时按已保存的起始时间恢复，无需一直保持应用前台。',
                ),
                const SizedBox(height: 18),
                const Text(
                  '手账和手机使用可能重叠，因此分开统计。设备数据无法核对时会隐藏相关总量。目标提醒依赖系统权限与后台调度，可能延迟，不代表应用已经被封锁。',
                ),
                const SizedBox(height: 18),
                const Text(
                  '建议定期导出 JSON 备份。恢复会合并相同记录；有冲突时不会覆盖本机内容。CSV 用于查看，不能用于恢复。只读样例与真实记录分开，也不会自动保存。',
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
