import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MobileAdminManagementPage extends StatefulWidget {
  const MobileAdminManagementPage({super.key});

  @override
  State<MobileAdminManagementPage> createState() =>
      _MobileAdminManagementPageState();
}

class _MobileAdminManagementPageState extends State<MobileAdminManagementPage> {
  // 🚀 Firebase Firestore의 'admins' 컬렉션을 사용합니다.
  final CollectionReference _adminsDb = FirebaseFirestore.instance.collection(
    'admins',
  );

  // 신규 관리자 추가 팝업
  void _showAddAdminDialog() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "신규 관리자 추가",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("권한을 부여할 구글 이메일을 정확히 입력하세요."),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "구글 이메일 (필수)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "이름/직급 (선택)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007580),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                String email = emailController.text.trim().toLowerCase();
                String name = nameController.text.trim();

                if (email.isNotEmpty && email.contains("@")) {
                  // 🚀 DB에 이메일을 문서 ID로 하여 저장합니다.
                  await _adminsDb.doc(email).set({
                    'email': email,
                    'name': name.isEmpty ? "이름 없음" : name,
                    'addedAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("올바른 이메일 형식을 입력해주세요.")),
                  );
                }
              },
              child: const Text("추가하기"),
            ),
          ],
        );
      },
    );
  }

  // 관리자 권한 삭제
  void _deleteAdmin(String email) async {
    // ⚠️ 최고 관리자(본인)는 삭제되지 않도록 보호
    if (email == 'gnsl5@gmail.com') {
      // 💡 여기에 사용자님 이메일을 적어두면 안전합니다!
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("최고 관리자 계정은 삭제할 수 없습니다!")));
      return;
    }

    await _adminsDb.doc(email).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF007580),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "관리자 권한 관리",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _adminsDb.orderBy('addedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF007580)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "등록된 관리자가 없습니다.\n우측 하단 버튼을 눌러 추가해주세요.",
                textAlign: TextAlign.center,
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final email = data['email'] ?? "이메일 없음";
              final name = data['name'] ?? "이름 없음";

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF007580),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(email),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteAdmin(email),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF007580),
        foregroundColor: Colors.white,
        onPressed: _showAddAdminDialog,
        icon: const Icon(Icons.add),
        label: const Text(
          "관리자 추가",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
