// 기록을 프로젝트에 붙이는 칸(10-09 고도화 1번): 압력시험·교정 저장 창에서 "내 프로젝트" 중 하나를 고른다.
// 붙이면 그 프로젝트 개요에 시험·교정 기록이 같이 보인다. 고르지 않아도 된다(예전처럼 따로 저장).
import 'package:flutter/material.dart';
import 'package:tubing_calculator/src/core/theme/app_icon_set.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/field_view.dart';
import '../../../data/repositories/work_project_repository.dart';

/// 고른 프로젝트(아이디·이름). 둘 다 비면 안 붙임.
typedef ProjectLink = ({String id, String name});

const ProjectLink kNoProjectLink = (id: '', name: '');

/// 마지막으로 고른 프로젝트를 기억하는 칸(다음 기록의 기본값).
const String kLastProjectLinkKey = 'last_project_link_v1';

Future<ProjectLink> loadLastProjectLink() async {
  try {
    final l = (await SharedPreferences.getInstance()).getStringList(
      kLastProjectLinkKey,
    );
    if (l != null && l.length == 2) return (id: l[0], name: l[1]);
  } catch (_) {}
  return kNoProjectLink;
}

Future<void> saveLastProjectLink(ProjectLink p) async {
  try {
    await (await SharedPreferences.getInstance()).setStringList(
      kLastProjectLinkKey,
      [p.id, p.name],
    );
  } catch (_) {}
}

/// 시험에서 프로젝트 목록 대신 쓴다.
@visibleForTesting
Future<List<ProjectLink>> Function()? debugProjectLinks;

/// 고를 수 있는 프로젝트(진행 중 먼저). 폰 사본이 비면 서버를 잠깐 읽는다.
Future<List<ProjectLink>> loadProjectLinks() async {
  final fake = debugProjectLinks;
  if (fake != null) return fake();
  final repo = WorkProjectRepository();
  List<Map<String, dynamic>> list = const [];
  try {
    list = await repo.fetchCachedProjects();
  } catch (_) {}
  if (list.isEmpty) {
    try {
      list = await repo.fetchAllProjects();
    } catch (_) {}
  }
  final active = <ProjectLink>[], done = <ProjectLink>[];
  for (final p in list) {
    final id = p['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final link = (id: id, name: p['name']?.toString() ?? '이름 없음');
    (p['status'] == 'DONE' ? done : active).add(link);
  }
  return [...active, ...done];
}

class ProjectLinkField extends StatelessWidget {
  final ProjectLink value;
  final ValueChanged<ProjectLink> onChanged;

  /// 시험에서 프로젝트 목록 대신 넣는다.
  final Future<List<ProjectLink>> Function()? loadLinks;

  const ProjectLinkField({
    super.key,
    required this.value,
    required this.onChanged,
    this.loadLinks,
  });

  Future<void> _pick(BuildContext context) async {
    final links = await (loadLinks ?? loadProjectLinks)();
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<ProjectLink>(
      context: context,
      backgroundColor: fc.surface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  '붙일 프로젝트',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: fc.text,
                  ),
                ),
              ),
              ListTile(
                key: const Key('plink_none'),
                leading: Icon(Icons.link_off_rounded, color: fc.textSub),
                title: const Text('붙이지 않음'),
                onTap: () => Navigator.pop(ctx, kNoProjectLink),
              ),
              if (links.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Text(
                    '내 프로젝트가 없습니다. "내 프로젝트"에서 먼저 만드십시오.',
                    style: TextStyle(color: fc.textSub),
                  ),
                ),
              for (final l in links)
                ListTile(
                  key: Key('plink_${l.id}'),
                  leading: Icon(Icons.folder_outlined, color: fc.brand),
                  title: Text(
                    l.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  selected: l.id == value.id,
                  onTap: () => Navigator.pop(ctx, l),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: fc.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('plink_field'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pick(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 20, color: fc.brand),
              const SizedBox(width: 8),
              Text(
                '프로젝트',
                style: TextStyle(fontWeight: FontWeight.w700, color: fc.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.id.isEmpty ? '붙이지 않음' : value.name,
                  key: const Key('plink_value'),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: value.id.isEmpty ? fc.textSub : fc.text,
                  ),
                ),
              ),
              Icon(AppIcons.forward, color: fc.textSub),
            ],
          ),
        ),
      ),
    ),
  );
}
