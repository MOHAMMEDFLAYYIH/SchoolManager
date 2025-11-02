import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_app/core/app_config.dart';
import 'package:school_app/student_management/services/student_service.dart';
import 'package:school_app/school_management/models/school.dart';
import 'package:school_app/school_management/services/school_service.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class AttendancePage extends StatefulWidget {
  final School? school;
  final VoidCallback? onBack;
  const AttendancePage({super.key, this.school, this.onBack});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with TickerProviderStateMixin {
  List<Student> _students = [];
  final StudentService _studentService = StudentService();
  final SchoolService _schoolService = SchoolService.instance;
  final Map<String, String> _attendanceStatus = {};
  bool _isLoading = true;
  List<School> _schools = [];
  School? _selectedSchool;
  int _presentCount = 0;
  int _absentCount = 0;
  int _excusedCount = 0;
  int _lateCount = 0;
  DateTime _selectedDate = DateTime.now();

  late AnimationController _saveButtonController;
  late AnimationController _statsController;
  late Animation<double> _saveButtonScale;
  late Animation<double> _statsSlide;

  @override
  void initState() {
    super.initState();

    // متحكم تأثير زر الحفظ
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // متحكم تأثير الإحصائيات
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // تأثير تكبير زر الحفظ
    _saveButtonScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_saveButtonController);

    // تأثير انزلاق الإحصائيات
    _statsSlide = Tween<double>(
      begin: -50.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _statsController, curve: Curves.easeOut));

    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    if (widget.school != null) {
      // عندما يتم تمرير مدرسة محددة، لا يزال يجب تحميل جميع المدارس للسماح بالتبديل
      final schools = await _schoolService.getSchools();
      final selectedSchool = schools.firstWhere(
        (s) => s.id == widget.school!.id,
        orElse: () => widget.school!,
      );

      // إحضار جميع الطلاب حسب المدرسة فقط
      final students = await _studentService.getStudentsBySchool(
        selectedSchool.id,
      );

      setState(() {
        _schools = schools;
        _selectedSchool = selectedSchool;
        _students = students;
        _initializeAttendanceStatus();
        _calculateStats();
        _isLoading = false;
      });
    } else {
      // Initialize demo data
      await SchoolService.instance.initializeDemoData();
      await _studentService.initializeDemoStudents();

      // Get all schools
      final schools = await _schoolService.getSchools();
      // احترم الاختيار الحالي إذا كان موجودًا، وإلا اختر أول مدرسة
      School? selectedSchool =
          _selectedSchool ?? (schools.isNotEmpty ? schools.first : null);

      // الحصول على جميع الطلاب حسب المدرسة المحددة فقط
      final students = selectedSchool != null
          ? await _studentService.getStudentsBySchool(selectedSchool.id)
          : <Student>[];

      setState(() {
        _schools = schools;
        _selectedSchool = selectedSchool;
        _students = students;
        _initializeAttendanceStatus();
        _calculateStats();
        _isLoading = false;
      });

      if (_students.isNotEmpty) {
        // بدء تأثير الإحصائيات
        _statsController.forward();
      }
    }
  }

  // تم إلغاء منطق الشعب: سيتم التحميل حسب المدرسة فقط

  void _initializeAttendanceStatus() {
    // تهيئة جميع الطلاب كـ "حاضر" افتراضياً
    _attendanceStatus.clear();
    for (var student in _students) {
      _attendanceStatus[student.id] = AppConfig.attendancePresent;
    }
  }

  void _calculateStats() {
    _presentCount = _attendanceStatus.values
        .where((status) => status == AppConfig.attendancePresent)
        .length;
    _absentCount = _attendanceStatus.values
        .where((status) => status == AppConfig.attendanceAbsent)
        .length;
    _excusedCount = _attendanceStatus.values
        .where((status) => status == AppConfig.attendanceExcused)
        .length;
    _lateCount = _attendanceStatus.values
        .where((status) => status == AppConfig.attendanceLate)
        .length;
  }

  void _updateAttendanceStatus(String studentId, String status) {
    setState(() {
      _attendanceStatus[studentId] = status;
      _calculateStats();
    });

    // تشغيل تأثير الإحصائيات عند كل تحديث
    _statsController.forward(from: 0.0);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConfig.attendancePresent:
        return AppConfig.presentColor;
      case AppConfig.attendanceAbsent:
        return AppConfig.absentColor;
      case AppConfig.attendanceExcused:
        return AppConfig.excusedColor;
      case AppConfig.attendanceLate:
        return AppConfig.lateColor;
      default:
        return AppConfig.borderColor;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case AppConfig.attendancePresent:
        return 'حاضر';
      case AppConfig.attendanceAbsent:
        return 'غائب';
      case AppConfig.attendanceExcused:
        return 'مجاز';
      case AppConfig.attendanceLate:
        return 'متأخر';
      default:
        return 'غير محدد';
    }
  }

  Future<void> _saveAttendance() async {
    // تشغيل تأثير زر الحفظ
    await _saveButtonController.forward();

    // حفظ سجلات الحضور
    for (var entry in _attendanceStatus.entries) {
      final student = _students.firstWhere((s) => s.id == entry.key);
      final attendance = Attendance(
        id: 'attendance_${student.id}_${DateTime.now().millisecondsSinceEpoch}',
        studentId: student.id,
        schoolId: student.schoolId,
        date: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        ),
        status: entry.value,
        recordedBy: 'teacher_1',
        recordedAt: DateTime.now(),
      );

      await StudentService().recordAttendance(attendance);
    }

    // إظهار رسالة النجاح المتحركة
    if (mounted) {
      _showSuccessMessage();
    }
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'تم حفظ سجل الحضور بنجاح',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: AppConfig.successColor,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );

    // العودة إلى لوحة التحكم بعد فترة قصيرة
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _onSchoolChanged(String? schoolId) async {
    if (schoolId == null) return;

    final exists = _schools.any((s) => s.id == schoolId);
    final selected = exists
        ? _schools.firstWhere((s) => s.id == schoolId)
        : null;

    setState(() {
      _selectedSchool = selected;
      _students = [];
      _attendanceStatus.clear();
      _presentCount = 0;
      _absentCount = 0;
      _excusedCount = 0;
      _lateCount = 0;
      _isLoading = true;
    });

    if (selected != null) {
      final students = await _studentService.getStudentsBySchool(selected.id);
      setState(() {
        _students = students;
        _initializeAttendanceStatus();
        _calculateStats();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // تم إزالة تبديل الشعب

  @override
  void dispose() {
    _saveButtonController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  Future<Uint8List> _buildAttendancePdfBytes() async {
    final doc = pw.Document();
    final headers = ['الرقم', 'اسم الطالب', 'الحالة'];
    final rows = _students.map((s) {
      final status = _attendanceStatus[s.id] ?? AppConfig.attendancePresent;
      return [s.studentId, s.fullName, _getStatusText(status)];
    }).toList();
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    // Try to load Arabic-capable fonts (assets path then project root)
    pw.Font? regularFont;
    pw.Font? boldFont;
    Future<pw.Font?> tryLoad(String path) async {
      try {
        final data = await rootBundle.load(path);
        return pw.Font.ttf(data);
      } catch (_) {
        return null;
      }
    }

    regularFont =
        await tryLoad('assets/fonts/Cairo-Regular.ttf') ??
        await tryLoad('Cairo-Regular.ttf');
    boldFont =
        await tryLoad('assets/fonts/Cairo-Bold.ttf') ??
        await tryLoad('Cairo-Bold.ttf');
    if (boldFont == null && regularFont != null) {
      boldFont = regularFont; // fallback
    }

    final pageTheme = (regularFont != null && boldFont != null)
        ? pw.PageTheme(
            textDirection: pw.TextDirection.rtl,
            theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
          )
        : const pw.PageTheme(textDirection: pw.TextDirection.rtl);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'تقرير الحضور',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('المدرسة: ${_selectedSchool?.name ?? '-'}'),
              pw.Text('التاريخ: $dateStr'),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                border: null,
                cellAlignment: pw.Alignment.centerRight,
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'حاضرون: $_presentCount | غائبون: $_absentCount | مجازون: $_excusedCount | متأخرون: $_lateCount',
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _printAttendanceReport() async {
    await Printing.layoutPdf(
      onLayout: (format) async => await _buildAttendancePdfBytes(),
    );
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        title: Text(
          'تسجيل الحضور',
          style: GoogleFonts.cairo(
            fontSize: AppConfig.fontSizeXXLarge,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppConfig.primaryColor,
        elevation: AppConfig.cardElevation,
        shadowColor: AppConfig.primaryColor.withValues(alpha: 0.3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.white),
            onPressed: _printAttendanceReport,
            tooltip: 'طباعة تقرير الحضور',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _selectedSchool?.name ?? '',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: AppConfig.fontSizeMedium,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSelectionSection(),
          // شريط الإحصائيات المتحرك
          AnimatedBuilder(
            animation: _statsController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_statsSlide.value, 0),
                child: Opacity(
                  opacity: _statsController.value,
                  child: Container(
                    padding: const EdgeInsets.all(AppConfig.spacingMD),
                    decoration: BoxDecoration(
                      color: AppConfig.surfaceColor,
                      boxShadow: [
                        BoxShadow(
                          color: AppConfig.borderColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildStatCard(
                          'الحاضرون',
                          _presentCount.toString(),
                          AppConfig.presentColor,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'الغائبون',
                          _absentCount.toString(),
                          AppConfig.absentColor,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'المجازون',
                          _excusedCount.toString(),
                          AppConfig.excusedColor,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'المتأخرون',
                          _lateCount.toString(),
                          AppConfig.lateColor,
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          'نسبة الحضور',
                          _students.isEmpty
                              ? '0%'
                              : '${((_presentCount / _students.length) * 100).toStringAsFixed(0)}%',
                          AppConfig.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // قائمة الطلاب
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppConfig.primaryColor,
                    ),
                  )
                : ListView.builder(
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final status =
                          _attendanceStatus[student.id] ??
                          AppConfig.attendancePresent;

                      return _buildStudentAttendanceCard(student, status);
                    },
                  ),
          ),

          // زر الحفظ المتحرك
          Container(
            padding: const EdgeInsets.all(AppConfig.spacingMD),
            decoration: BoxDecoration(
              color: AppConfig.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: AppConfig.borderColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _saveButtonScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _saveButtonScale.value,
                  child: ElevatedButton(
                    onPressed: _saveAttendance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.secondaryColor,
                      foregroundColor: Colors.white,
                      elevation: AppConfig.buttonElevation,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConfig.spacingXXL,
                        vertical: AppConfig.spacingLG,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConfig.borderRadius,
                        ),
                      ),
                      shadowColor: AppConfig.secondaryColor.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.save_rounded, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'حفظ وتأكيد',
                          style: GoogleFonts.cairo(
                            fontSize: AppConfig.fontSizeLarge,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppConfig.spacingMD),
      padding: const EdgeInsets.all(AppConfig.spacingMD),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedSchool?.id,
            decoration: InputDecoration(
              labelText: 'اختر المدرسة',
              labelStyle: GoogleFonts.cairo(
                color: AppConfig.textSecondaryColor,
              ),
              filled: true,
              fillColor: AppConfig.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                borderSide: BorderSide.none,
              ),
            ),
            items: _schools
                .map(
                  (school) => DropdownMenuItem(
                    value: school.id,
                    child: Text(
                      school.name,
                      style: GoogleFonts.cairo(
                        color: AppConfig.textPrimaryColor,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              _onSchoolChanged(value);
            },
          ),

          const SizedBox(height: AppConfig.spacingMD),

          // محدد التاريخ بنفس أسلوب التصميم القديم
          InkWell(
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                helpText: 'اختر التاريخ',
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: AppConfig.primaryColor,
                        onPrimary: Colors.white,
                        onSurface: AppConfig.textPrimaryColor,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConfig.spacingMD,
                vertical: AppConfig.spacingMD,
              ),
              decoration: BoxDecoration(
                color: AppConfig.surfaceColor,
                borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                border: Border.all(color: AppConfig.borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: AppConfig.textSecondaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: AppConfig.spacingSM),
                  Text(
                    'تاريخ الحضور: ${_selectedDate.toString().split(' ')[0]}',
                    style: GoogleFonts.cairo(
                      color: AppConfig.textPrimaryColor,
                      fontSize: AppConfig.fontSizeMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: AppConfig.fontSizeXLarge,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: AppConfig.fontSizeSmall,
                color: AppConfig.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAttendanceCard(Student student, String status) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacingMD,
        vertical: AppConfig.spacingSM,
      ),
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
        border: Border.all(
          color: _getStatusColor(status).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
          onTap: () {
            _showStatusOptions(student);
          },
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacingMD),
            child: Row(
              children: [
                // صورة الطالب
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppConfig.primaryColor.withValues(
                    alpha: 0.1,
                  ),
                  child: Text(
                    student.initials,
                    style: GoogleFonts.cairo(
                      fontSize: AppConfig.fontSizeLarge,
                      fontWeight: FontWeight.bold,
                      color: AppConfig.primaryColor,
                    ),
                  ),
                ),

                const SizedBox(width: AppConfig.spacingMD),

                // معلومات الطالب
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: GoogleFonts.cairo(
                          fontSize: AppConfig.fontSizeLarge,
                          fontWeight: FontWeight.w600,
                          color: AppConfig.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'رقم الطالب: ${student.studentId}',
                        style: GoogleFonts.cairo(
                          fontSize: AppConfig.fontSizeMedium,
                          color: AppConfig.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // حالة الحضور مع أيقونة
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConfig.spacingMD,
                    vertical: AppConfig.spacingSM,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    border: Border.all(
                      color: _getStatusColor(status).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        status == AppConfig.attendancePresent
                            ? Icons.check_circle
                            : status == AppConfig.attendanceAbsent
                            ? Icons.cancel
                            : status == AppConfig.attendanceExcused
                            ? Icons.info
                            : Icons.schedule,
                        color: _getStatusColor(status),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusText(status),
                        style: GoogleFonts.cairo(
                          fontSize: AppConfig.fontSizeSmall,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatusOptions(Student student) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConfig.borderRadius),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(AppConfig.spacingMD),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحديد حالة ${student.firstName}',
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeLarge,
                  fontWeight: FontWeight.bold,
                  color: AppConfig.textPrimaryColor,
                ),
              ),
              const SizedBox(height: AppConfig.spacingLG),

              _buildStatusOption(
                'حاضر',
                AppConfig.attendancePresent,
                AppConfig.presentColor,
                Icons.check_circle,
                () {
                  _updateAttendanceStatus(
                    student.id,
                    AppConfig.attendancePresent,
                  );
                  Navigator.of(context).pop();
                },
                student.id,
              ),

              _buildStatusOption(
                'غائب',
                AppConfig.attendanceAbsent,
                AppConfig.absentColor,
                Icons.cancel,
                () {
                  _updateAttendanceStatus(
                    student.id,
                    AppConfig.attendanceAbsent,
                  );
                  Navigator.of(context).pop();
                },
                student.id,
              ),

              _buildStatusOption(
                'مجاز',
                AppConfig.attendanceExcused,
                AppConfig.excusedColor,
                Icons.info,
                () {
                  _updateAttendanceStatus(
                    student.id,
                    AppConfig.attendanceExcused,
                  );
                  Navigator.of(context).pop();
                },
                student.id,
              ),

              _buildStatusOption(
                'متأخر',
                AppConfig.attendanceLate,
                AppConfig.lateColor,
                Icons.schedule,
                () {
                  _updateAttendanceStatus(student.id, AppConfig.attendanceLate);
                  Navigator.of(context).pop();
                },
                student.id,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusOption(
    String label,
    String status,
    Color color,
    IconData icon,
    VoidCallback onTap,
    String studentId,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConfig.spacingSM),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          child: Container(
            padding: const EdgeInsets.all(AppConfig.spacingMD),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: AppConfig.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const Spacer(),
                if (_attendanceStatus[studentId] == status)
                  Icon(Icons.check, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
