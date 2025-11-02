import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_app/core/app_config.dart';
import 'package:school_app/dashboard/widgets/quick_action_card.dart';
import 'package:school_app/dashboard/widgets/recent_activity_card.dart';
import 'package:school_app/attendance_management/pages/attendance_page.dart';
import 'package:school_app/student_management/pages/grades_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // متحكم تأثير الظهور التدريجي
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // تأثير الظهور التدريجي
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // بدء التأثيرات
    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        title: Text(
          'لوحة التحكم',
          style: GoogleFonts.cairo(
            fontSize: AppConfig.fontSizeXXLarge,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppConfig.primaryColor,
        elevation: AppConfig.cardElevation,
        shadowColor: AppConfig.primaryColor.withValues(alpha: 0.3),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              // الانتقال إلى صفحة الإشعارات
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppConfig.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppConfig.spacingMD),

              // عنوان الإجراءات السريعة
              Text(
                'إجراءات سريعة',
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeXLarge,
                  fontWeight: FontWeight.bold,
                  color: AppConfig.textPrimaryColor,
                ),
              ),

              const SizedBox(height: AppConfig.spacingLG),

              // شبكة الإجراءات السريعة
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: AppConfig.spacingMD,
                mainAxisSpacing: AppConfig.spacingMD,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  QuickActionCard(
                    title: 'إضافة طالب جديد',
                    icon: Icons.person_add_outlined,
                    color: AppConfig.primaryColor,
                    onTap: () {
                      // الانتقال إلى صفحة إضافة طالب
                    },
                  ),
                  QuickActionCard(
                    title: 'تسجيل الحضور',
                    icon: Icons.check_circle_outline,
                    color: AppConfig.secondaryColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AttendancePage(),
                        ),
                      );
                    },
                  ),
                  QuickActionCard(
                    title: 'إدخال الدرجات',
                    icon: Icons.grade_outlined,
                    color: AppConfig.secondaryColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const GradesPage(),
                        ),
                      );
                    },
                  ),
                  QuickActionCard(
                    title: 'عرض التقارير',
                    icon: Icons.analytics_outlined,
                    color: AppConfig.infoColor,
                    onTap: () {
                      // الانتقال إلى صفحة التقارير
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppConfig.spacingXXL),

              // عنوان النشاطات الأخيرة
              Text(
                'النشاطات الأخيرة',
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeXLarge,
                  fontWeight: FontWeight.bold,
                  color: AppConfig.textPrimaryColor,
                ),
              ),

              const SizedBox(height: AppConfig.spacingLG),

              // قائمة النشاطات الأخيرة
             
              const SizedBox(height: AppConfig.spacingXXL),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // إجراء سريع - إضافة عنصر جديد
        },
        backgroundColor: AppConfig.primaryColor,
        foregroundColor: Colors.white,
        elevation: AppConfig.buttonElevation,
        // shadowColor: AppConfig.primaryColor.withValues(alpha: 0.3), // Commented out as undefined
        icon: const Icon(Icons.add),
        label: Text(
          'إضافة جديد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
