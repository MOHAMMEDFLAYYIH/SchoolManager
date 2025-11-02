import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_app/core/app_config.dart';
import 'package:school_app/school_management/services/school_service.dart';
import 'package:school_app/school_management/pages/schools_list_page.dart';
import 'package:school_app/reports/pages/reports_page.dart';
import 'package:school_app/attendance_management/pages/attendance_page.dart';
import 'package:school_app/student_management/pages/grades_page.dart';
 

class SmartTeacherHomePage extends StatefulWidget {
  const SmartTeacherHomePage({super.key});

  @override
  State<SmartTeacherHomePage> createState() => _SmartTeacherHomePageState();
}

class _SmartTeacherHomePageState extends State<SmartTeacherHomePage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  int _currentIndex = 0; // مؤشر العنصر النشط في شريط التنقل السفلي

  @override
  void initState() {
    super.initState();

    _loadSchoolData();
  }

  Widget _buildPageForIndex(int index) {
    switch (index) {
      case 0:
        return _buildMainContent();
      case 1:
        return ReportsPage(
          onBack: () {
            setState(() {
              _currentIndex = 0;
            });
          },
        );
      case 2:
        return SchoolsListPage(
          onBack: () {
            setState(() {
              _currentIndex = 0;
            });
          },
        );
      case 3:
        return AttendancePage(
          onBack: () {
            setState(() {
              _currentIndex = 0;
            });
          },
        );
      case 4:
        return GradesPage(
          onBack: () {
            setState(() {
              _currentIndex = 0;
            });
          },
        );
      default:
        return _buildMainContent();
    }
  }

  Future<void> _loadSchoolData() async {
    setState(() {
      _isLoading = true;
    });

    // تهيئة البيانات التجريبية (قاعدة البيانات SQLite)
    await SchoolService.instance.initializeDemoData();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        appBar: _currentIndex == 0
            ? AppBar(
                title: Text(
                  'مدرستي الذكية',
                  style: GoogleFonts.cairo(
                    fontSize: AppConfig.fontSizeXXLarge,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: AppConfig.primaryColor,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      // الانتقال إلى صفحة الإشعارات
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  ),
                ],
              )
            : null,
        body: _isLoading
            ? _buildLoadingView()
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_currentIndex),
                  child: _buildPageForIndex(_currentIndex),
                ),
              ),
        floatingActionButton: _currentIndex == 0
            ? FloatingActionButton.extended(
                onPressed: () {
                  // الانتقال إلى قسم المدرسة لاختيار مدرسة ثم إضافة طالب
                  setState(() {
                    _currentIndex = 2; // المدرسة
                  });
                },
                backgroundColor: AppConfig.secondaryColor,
                foregroundColor: Colors.white,
                elevation: AppConfig.buttonElevation,
                icon: const Icon(Icons.person_add),
                label: Text(
                  'إضافة طالب',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                ),
              )
            : null,
        drawer: _buildDrawer(),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(color: AppConfig.primaryColor),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppConfig.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppConfig.spacingMD),

          // الإجراءات السريعة البسيطة
          _buildQuickActions(),

          const SizedBox(height: AppConfig.spacingXXL),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: AppConfig.spacingMD,
      mainAxisSpacing: AppConfig.spacingMD,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildQuickActionCard(
          'تسجيل الحضور',
          Icons.check_circle_outline,
          AppConfig.secondaryColor,
          () {
            setState(() {
              _currentIndex = 3; // الحضور
            });
          },
        ),
        _buildQuickActionCard(
          'إدخال الدرجات',
          Icons.grade_outlined,
          AppConfig.successColor,
          () {
            setState(() {
              _currentIndex = 4; // الدرجات
            });
          },
        ),
        _buildQuickActionCard(
          'إدارة الطلاب',
          Icons.people_outline,
          AppConfig.primaryColor,
          () {
            // الانتقال إلى قسم المدرسة لاختيار مدرسة وإدارة الطلاب
            setState(() {
              _currentIndex = 2; // المدرسة
            });
          },
        ),
        _buildQuickActionCard(
          'عرض التقارير',
          Icons.analytics_outlined,
          AppConfig.warningColor,
          () {
            // الانتقال إلى صفحة التقارير
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppConfig.cardColor,
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppConfig.borderColor.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacingMD),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppConfig.spacingMD),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: AppConfig.spacingMD),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: AppConfig.fontSizeMedium,
                    fontWeight: FontWeight.w600,
                    color: AppConfig.textPrimaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: AppConfig.surfaceColor,
        child: Column(
          children: [
            // رأس القائمة الجانبية
            Container(
              padding: const EdgeInsets.all(AppConfig.spacingLG),
              decoration: BoxDecoration(color: AppConfig.primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      'م',
                      style: GoogleFonts.cairo(
                        fontSize: AppConfig.fontSizeXLarge,
                        fontWeight: FontWeight.bold,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConfig.spacingMD),
                  Text(
                    'مدرسة الرياض الذكية',
                    style: GoogleFonts.cairo(
                      fontSize: AppConfig.fontSizeLarge,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'نظام إدارة تعليمي متطور',
                    style: GoogleFonts.cairo(
                      fontSize: AppConfig.fontSizeSmall,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            // عناصر القائمة الرئيسية
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: AppConfig.spacingMD,
                ),
                children: [
                  _buildDrawerItem(
                    Icons.dashboard_outlined,
                    'لوحة التحكم',
                    () {
                      Navigator.of(context).pop();
                    },
                    color: AppConfig.primaryColor,
                  ),
                  _buildDrawerItem(Icons.school_outlined, 'إدارة المدرسة', () {
                    Navigator.of(context).pop();
                    setState(() {
                      _currentIndex = 2; // المدرسة
                    });
                  }),
                  _buildDrawerItem(Icons.people_outline, 'إدارة الطلاب', () {
                    Navigator.of(context).pop();
                    setState(() {
                      _currentIndex = 2; // المدرسة
                    });
                  }),
                  _buildDrawerItem(
                    Icons.check_circle_outline,
                    'تسجيل الحضور',
                    () {
                      Navigator.of(context).pop();
                      setState(() {
                        _currentIndex = 3; // الحضور
                      });
                    },
                  ),
                  _buildDrawerItem(Icons.grade_outlined, 'إدارة الدرجات', () {
                    Navigator.of(context).pop();
                    setState(() {
                      _currentIndex = 4; // الدرجات
                    });
                  }),
                  _buildDrawerItem(
                    Icons.analytics_outlined,
                    'التقارير والإحصائيات',
                    () {
                      Navigator.of(context).pop();
                      setState(() {
                        _currentIndex = 1; // التقارير
                      });
                    },
                  ),
                ],
              ),
            ),

            // قسم الإعدادات والمساعدة
            Container(
              padding: const EdgeInsets.all(AppConfig.spacingMD),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppConfig.borderColor)),
              ),
              child: Column(
                children: [
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacingMD,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color != null
            ? color.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: color ?? AppConfig.textPrimaryColor,
          size: 28,
        ),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            color: color ?? AppConfig.textPrimaryColor,
            fontSize: AppConfig.fontSizeLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacingLG,
          vertical: AppConfig.spacingSM,
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppConfig.cardColor,
        boxShadow: [
          BoxShadow(
            color: AppConfig.borderColor.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: AppConfig.borderColor)),
      ),
      child: BottomNavigationBar(
        backgroundColor: AppConfig.cardColor,
        selectedItemColor: AppConfig.primaryColor,
        unselectedItemColor: AppConfig.textSecondaryColor,
        selectedFontSize: AppConfig.fontSizeSmall,
        unselectedFontSize: AppConfig.fontSizeSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        currentIndex: _currentIndex,
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
              ),
              child: const Icon(Icons.dashboard, size: 20),
            ),
            label: 'لوحة التحكم',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConfig.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
              ),
              child: const Icon(Icons.analytics, size: 20),
            ),
            label: 'التقارير',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConfig.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
              ),
              child: const Icon(Icons.school, size: 20),
            ),
            label: 'المدرسة',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConfig.infoColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
              ),
              child: const Icon(Icons.calendar_today, size: 20),
            ),
            label: 'الحضور',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
              ),
              child: const Icon(Icons.grade, size: 20),
            ),
            label: 'الدرجات',
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
