import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_app/core/app_config.dart';
import 'package:school_app/school_management/models/school.dart';
import 'package:school_app/school_management/services/school_service.dart';
import 'package:school_app/student_management/services/student_service.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsPage extends StatefulWidget {
  final VoidCallback? onBack;
  const ReportsPage({super.key, this.onBack});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with TickerProviderStateMixin {
  final StudentService _studentService = StudentService();
  String _selectedReportType = 'تقرير الأداء الشهري';
  String _selectedPeriod = 'الشهر الحالي';
  bool _isGenerating = false;
  bool _isDataLoading = true;
  bool _isStudentsLoading = false;
  List<School> _schools = [];
  School? _selectedSchool;
  List<Student> _availableStudents = [];
  Set<String> _selectedStudentIds = {};
  List<StudentReport> _latestReports = [];

  late AnimationController _generateButtonController;
  late AnimationController _previewController;
  late Animation<double> _generateButtonScale;
  late Animation<double> _previewSlide;

  // PDF helpers
  Future<pw.Font?> _tryLoadFont(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _buildReportsPdfBytes() async {
    final doc = pw.Document();

    // Load Arabic-capable fonts
    pw.Font? regularFont = await _tryLoadFont('assets/fonts/Cairo-Regular.ttf')
        ?? await _tryLoadFont('Cairo-Regular.ttf');
    pw.Font? boldFont = await _tryLoadFont('assets/fonts/Cairo-Bold.ttf')
        ?? await _tryLoadFont('Cairo-Bold.ttf')
        ?? regularFont;

    final theme = (regularFont != null && boldFont != null)
        ? pw.ThemeData.withFont(base: regularFont, bold: boldFont)
        : null;

    final pageTheme = pw.PageTheme(
      textDirection: pw.TextDirection.rtl,
      theme: theme,
    );

    final headers = <String>['الطالب', 'التقييم', 'الدرجة العامة %', 'متوسط الدرجات %'];
    final data = _latestReports.map((r) => [
          r.student.fullName,
          r.getEvaluationText(),
          r.overallScore.toStringAsFixed(1),
          r.gradeAverage.toStringAsFixed(1),
        ]).toList();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (ctx) => [
          pw.Text('تقرير الطلاب', style: const pw.TextStyle(fontSize: 20)),
          pw.SizedBox(height: 8),
          if (_selectedSchool != null)
            pw.Text('المدرسة: ${_selectedSchool!.name}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerRight,
            border: null,
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _exportReportsPdf() async {
    if (_latestReports.isEmpty) return;
    await Printing.layoutPdf(onLayout: (_) => _buildReportsPdfBytes());
  }

  @override
  void initState() {
    super.initState();

    // متحكم تأثير زر الإنشاء
    _generateButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // متحكم تأثير المعاينة
    _previewController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // تأثير تكبير زر الإنشاء
    _generateButtonScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_generateButtonController);

    // تأثير انزلاق المعاينة
    _previewSlide = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _previewController, curve: Curves.easeOut),
    );

    // بدء تأثير المعاينة
    _previewController.forward();

    _loadInitialData();
  }

  Future<void> _generateReport() async {
    if (_selectedSchool == null) {
      _showStatusMessage(
        'يرجى اختيار مدرسة أولاً',
        AppConfig.warningColor,
        Icons.info_outline,
      );
      return;
    }

    if (_selectedStudentIds.isEmpty) {
      _showStatusMessage(
        'اختر طالبًا واحدًا على الأقل لإنشاء التقرير',
        AppConfig.warningColor,
        Icons.info_outline,
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    // تشغيل تأثير زر الإنشاء
    await _generateButtonController.forward(from: 0);

    try {
      final reports = <StudentReport>[];
      for (final studentId in _selectedStudentIds) {
        final report = await StudentService().generateStudentReport(studentId);
        reports.add(report);
      }

      setState(() {
        _latestReports = reports;
        _isGenerating = false;
      });

      if (mounted) {
        _showSuccessMessage(reports.length);
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });

      if (mounted) {
        _showStatusMessage(
          'تعذر إنشاء التقرير، حاول مرة أخرى',
          AppConfig.errorColor,
          Icons.error_outline,
        );
      }
    }
  }

  void _showSuccessMessage(int studentsCount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'تم إنشاء التقرير لعدد $studentsCount من الطلاب',
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
        action: SnackBarAction(
          label: 'عرض',
          textColor: Colors.white,
          onPressed: () {
            // الانتقال إلى عرض التقرير
          },
        ),
      ),
    );
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isDataLoading = true;
      _isStudentsLoading = true;
      _schools = [];
      _selectedSchool = null;
      _availableStudents = [];
      _selectedStudentIds.clear();
      _latestReports = [];
    });

    // Initialize demo data
    await SchoolService.instance.initializeDemoData();
    await StudentService().initializeDemoStudents();

    // Get all schools
    final schools = await SchoolService.instance.getSchools();
    School? initialSchool;
    if (schools.isNotEmpty) {
      initialSchool = schools.first;
    }

    // Get students for the selected school
    List<Student> students = [];
    if (initialSchool != null) {
      students = await StudentService().getStudentsBySchool(initialSchool.id);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _schools = schools;
      _selectedSchool = initialSchool;
      _availableStudents = students;
      _selectedStudentIds = students.map((student) => student.id).toSet();
      _isStudentsLoading = false;
      _isDataLoading = false;
    });
  }

  Future<void> _onSchoolChanged(String? schoolId) async {
    if (schoolId == null || _selectedSchool?.id == schoolId) {
      return;
    }

    final selected = _schools.firstWhere(
      (school) => school.id == schoolId,
      orElse: () => _selectedSchool ?? _schools.first,
    );

    setState(() {
      _selectedSchool = selected;
      _isStudentsLoading = true;
      _availableStudents = [];
      _selectedStudentIds.clear();
    });

    final students = await _studentService.getStudentsBySchool(selected.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _availableStudents = students;
      _selectedStudentIds = students.map((student) => student.id).toSet();
      _isStudentsLoading = false;
    });
  }

  void _toggleStudentSelection(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }

  void _selectAllStudents() {
    setState(() {
      _selectedStudentIds = _availableStudents
          .map((student) => student.id)
          .toSet();
    });
  }

  void _clearSelectedStudents() {
    setState(() {
      _selectedStudentIds.clear();
    });
  }

  void _showStatusMessage(
    String message,
    Color backgroundColor,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              message,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _generateButtonController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        title: Text(
          'إنشاء تقرير',
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
            tooltip: 'تصدير PDF',
            onPressed: _latestReports.isEmpty ? null : _exportReportsPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
          ),
        ],
      ),
      body: _isDataLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppConfig.primaryColor,
                ),
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppConfig.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // عنوان الصفحة
                  Text(
                    'إنشاء تقرير أداء شامل',
                    style: GoogleFonts.cairo(
                      fontSize: AppConfig.fontSizeXXLarge,
                      fontWeight: FontWeight.bold,
                      color: AppConfig.textPrimaryColor,
                    ),
                  ),

                  const SizedBox(height: AppConfig.spacingSM),

                  Text(
                    'اختر إعدادات التقرير وقم بإنشائه بسهولة',
                    style: GoogleFonts.cairo(
                      fontSize: AppConfig.fontSizeMedium,
                      color: AppConfig.textSecondaryColor,
                    ),
                  ),

                  const SizedBox(height: AppConfig.spacingXXL),

                  _buildStudentSelectionSection(),

                  const SizedBox(height: AppConfig.spacingLG),

                  // نوع التقرير
                  _buildSectionCard(
                    title: 'نوع التقرير',
                    icon: Icons.analytics_outlined,
                    color: AppConfig.primaryColor,
                    child: Column(
                      children: [
                        _buildRadioOption(
                          'تقرير الأداء الشهري',
                          _selectedReportType == 'تقرير الأداء الشهري',
                        ),
                        _buildRadioOption(
                          'تقرير الحضور والدرجات',
                          _selectedReportType == 'تقرير الحضور والدرجات',
                        ),
                        _buildRadioOption(
                          'تقرير الدرجات التفصيلي',
                          _selectedReportType == 'تقرير الدرجات التفصيلي',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConfig.spacingLG),

                  // نطاق البيانات
                  _buildSectionCard(
                    title: 'نطاق البيانات',
                    icon: Icons.date_range_outlined,
                    color: AppConfig.secondaryColor,
                    child: Column(
                      children: [
                        _buildDropdownOption(
                          'الفترة الزمنية',
                          _selectedPeriod,
                          [
                            'الشهر الحالي',
                            'الشهر الماضي',
                            'الفصل الحالي',
                            'السنة الحالية',
                          ],
                          (value) => setState(() => _selectedPeriod = value!),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConfig.spacingLG),

                  const SizedBox(height: AppConfig.spacingLG),

                  // معاينة التقرير
                  AnimatedBuilder(
                    animation: _previewController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_previewSlide.value, 0),
                        child: Opacity(
                          opacity: _previewController.value,
                          child: _buildSectionCard(
                            title: 'معاينة التقرير',
                            icon: Icons.preview_outlined,
                            color: AppConfig.infoColor,
                            child: _buildReportPreview(),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: AppConfig.spacingXXL),

                  // زر الإنشاء المتحرك
                  AnimatedBuilder(
                    animation: _generateButtonScale,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _generateButtonScale.value,
                        child: ElevatedButton(
                          onPressed: _isGenerating ? null : _generateReport,
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
                          child: _isGenerating
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'جاري الإنشاء...',
                                      style: GoogleFonts.cairo(
                                        fontSize: AppConfig.fontSizeLarge,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.analytics_outlined,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'إنشاء التقرير',
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

                  const SizedBox(height: AppConfig.spacingMD),

                  if (_latestReports.isNotEmpty)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ElevatedButton.icon(
                        onPressed: _exportReportsPdf,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: AppConfig.buttonElevation,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConfig.spacingXL,
                            vertical: AppConfig.spacingMD,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConfig.borderRadius,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          'تصدير PDF',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: AppConfig.spacingLG),

                  // خيارات إضافية
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // حفظ كمسودة
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: Text('حفظ كمسودة', style: GoogleFonts.cairo()),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppConfig.borderColor),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppConfig.spacingMD,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppConfig.borderRadius,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConfig.spacingXXL),
                ],
              ),
            ),
    );
  }

  Widget _buildStudentSelectionSection() {
    return _buildSectionCard(
      title: 'اختيار المدرسة والطلاب',
      icon: Icons.school_outlined,
      color: AppConfig.secondaryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSchoolDropdown(),
          const SizedBox(height: AppConfig.spacingMD),
          if (_isStudentsLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppConfig.primaryColor,
                ),
              ),
            )
          else if (_availableStudents.isEmpty)
            Text(
              'لا توجد طلاب مرتبطة بهذه المدرسة',
              style: GoogleFonts.cairo(
                fontSize: AppConfig.fontSizeMedium,
                color: AppConfig.textSecondaryColor,
              ),
            )
          else ...[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: AppConfig.spacingSM,
                children: [
                  TextButton(
                    onPressed: _selectAllStudents,
                    style: TextButton.styleFrom(
                      foregroundColor: AppConfig.primaryColor,
                    ),
                    child: Text(
                      'تحديد الكل',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearSelectedStudents,
                    style: TextButton.styleFrom(
                      foregroundColor: AppConfig.textSecondaryColor,
                    ),
                    child: Text(
                      'مسح التحديد',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConfig.spacingSM),
            Column(
              children: _availableStudents
                  .map((student) => _buildStudentSelectionItem(student))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSchoolDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اختر المدرسة',
          style: GoogleFonts.cairo(
            fontSize: AppConfig.fontSizeMedium,
            fontWeight: FontWeight.w600,
            color: AppConfig.textSecondaryColor,
          ),
        ),
        const SizedBox(height: AppConfig.spacingSM),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppConfig.borderColor, width: 1.0),
            borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          ),
          child: DropdownButton<String>(
            value: _selectedSchool?.id,
            onChanged: _schools.isEmpty ? null : _onSchoolChanged,
            items: _schools
                .map(
                  (school) => DropdownMenuItem(
                    value: school.id,
                    child: Text(
                      school.name,
                      style: GoogleFonts.cairo(
                        fontSize: AppConfig.fontSizeMedium,
                        color: AppConfig.textPrimaryColor,
                      ),
                    ),
                  ),
                )
                .toList(),
            style: GoogleFonts.cairo(
              fontSize: AppConfig.fontSizeMedium,
              color: AppConfig.textPrimaryColor,
            ),
            underline: Container(),
            isExpanded: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacingMD,
            ),
            hint: Text(
              'اختر مدرسة',
              style: GoogleFonts.cairo(
                fontSize: AppConfig.fontSizeMedium,
                color: AppConfig.textSecondaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentSelectionItem(Student student) {
    final isSelected = _selectedStudentIds.contains(student.id);
    return Container(
      margin: const EdgeInsets.only(bottom: AppConfig.spacingSM),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
        border: Border.all(
          color: isSelected
              ? AppConfig.primaryColor.withValues(alpha: 0.3)
              : AppConfig.borderColor,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          onTap: () => _toggleStudentSelection(student.id),
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacingMD),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleStudentSelection(student.id),
                  activeColor: AppConfig.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppConfig.primaryColor.withValues(
                    alpha: 0.1,
                  ),
                  foregroundColor: AppConfig.primaryColor,
                  child: Text(
                    student.initials,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
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
                        student.locationInfo,
                        style: GoogleFonts.cairo(
                          fontSize: AppConfig.fontSizeSmall,
                          color: AppConfig.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.studentId,
                        style: GoogleFonts.cairo(
                          fontSize: AppConfig.fontSizeSmall,
                          color: AppConfig.textLightColor,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1 : 0,
                  child: Icon(
                    Icons.check_circle,
                    color: AppConfig.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
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
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: AppConfig.fontSizeXLarge,
                    fontWeight: FontWeight.bold,
                    color: AppConfig.textPrimaryColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppConfig.spacingLG),

            child,
          ],
        ),
      ),
    );
  }

  Widget _buildReportPreview() {
    if (_latestReports.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'لم يتم إنشاء تقارير بعد',
            style: GoogleFonts.cairo(
              fontSize: AppConfig.fontSizeLarge,
              fontWeight: FontWeight.w600,
              color: AppConfig.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppConfig.spacingSM),
          Text(
            'قم بإنشاء التقرير للاطلاع على ملخص الأداء الأخير للطلاب المختارين.',
            style: GoogleFonts.cairo(
              fontSize: AppConfig.fontSizeMedium,
              color: AppConfig.textSecondaryColor,
            ),
          ),
        ],
      );
    }

    return Column(
      children: _latestReports.map((report) {
        final evaluationColor = report.getEvaluationColor();
        return Container(
          margin: const EdgeInsets.only(bottom: AppConfig.spacingMD),
          padding: const EdgeInsets.all(AppConfig.spacingMD),
          decoration: BoxDecoration(
            color: AppConfig.surfaceColor,
            borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
            border: Border.all(
              color: evaluationColor.withValues(alpha: 0.4),
              width: 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: evaluationColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  report.getEvaluationIcon(),
                  color: evaluationColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppConfig.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.student.fullName,
                      style: GoogleFonts.cairo(
                        fontSize: AppConfig.fontSizeLarge,
                        fontWeight: FontWeight.w600,
                        color: AppConfig.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'التقييم العام: ${report.getEvaluationText()} (${report.overallScore.toStringAsFixed(1)}%)',
                      style: GoogleFonts.cairo(
                        fontSize: AppConfig.fontSizeMedium,
                        color: evaluationColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.bar_chart_outlined,
                          size: 16,
                          color: AppConfig.textSecondaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'متوسط الدرجات: ${report.gradeAverage.toStringAsFixed(1)}%',
                          style: GoogleFonts.cairo(
                            fontSize: AppConfig.fontSizeSmall,
                            color: AppConfig.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: AppConfig.textSecondaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'نسبة الحضور: ${(report.attendanceRate * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.cairo(
                            fontSize: AppConfig.fontSizeSmall,
                            color: AppConfig.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRadioOption(String title, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConfig.spacingSM),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          onTap: () {
            setState(() => _selectedReportType = title);
          },
          child: Container(
            padding: const EdgeInsets.all(AppConfig.spacingMD),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppConfig.primaryColor.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
              border: Border.all(
                color: isSelected
                    ? AppConfig.primaryColor.withValues(alpha: 0.3)
                    : AppConfig.borderColor,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppConfig.primaryColor
                          : AppConfig.borderColor,
                      width: 2,
                    ),
                    color: isSelected
                        ? AppConfig.primaryColor
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: AppConfig.fontSizeMedium,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: AppConfig.textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownOption(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: AppConfig.fontSizeMedium,
            fontWeight: FontWeight.w600,
            color: AppConfig.textSecondaryColor,
          ),
        ),
        const SizedBox(height: AppConfig.spacingSM),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppConfig.borderColor, width: 1),
            borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          ),
          child: DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  style: GoogleFonts.cairo(
                    fontSize: AppConfig.fontSizeMedium,
                    color: AppConfig.textPrimaryColor,
                  ),
                ),
              );
            }).toList(),
            style: GoogleFonts.cairo(
              fontSize: AppConfig.fontSizeMedium,
              color: AppConfig.textPrimaryColor,
            ),
            underline: Container(),
            isExpanded: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacingMD,
            ),
          ),
        ),
      ],
    );
  }
}
