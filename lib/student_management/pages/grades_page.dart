import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_app/core/app_config.dart';
import 'package:school_app/student_management/services/student_service.dart';
import 'package:school_app/school_management/services/school_service.dart';

import 'package:school_app/school_management/models/school.dart';

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:async';
import 'package:school_app/core/database/db_helper.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;


class _GradeColCfg {
  String label;
  String term; // أحد عناصر _terms
  int monthIndex; // 1..3 وفق _months

  _GradeColCfg({
    required this.label,
    required this.term,
    required this.monthIndex,
  });

  _GradeColCfg copyWith({String? label, String? term, int? monthIndex}) {
    return _GradeColCfg(
      label: label ?? this.label,
      term: term ?? this.term,
      monthIndex: monthIndex ?? this.monthIndex,
    );
  }
}

enum DynColType { text, number, percent }

class _DynCol {
  final String id;
  String title;
  final DynColType type;
  final bool readOnly;
  final double? maxScore; // optional per-column max

  _DynCol({required this.id, required this.title, required this.type, this.readOnly = false, this.maxScore});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'readOnly': readOnly,
        'maxScore': maxScore,
      };

  static _DynCol fromJson(Map<String, dynamic> j) => _DynCol(
        id: j['id'] as String,
        title: j['title'] as String,
        type: DynColType.values.firstWhere((t) => t.name == j['type']),
        readOnly: (j['readOnly'] as bool?) ?? false,
        maxScore: (j['maxScore'] as num?)?.toDouble(),
      );
}

class GradesPage extends StatefulWidget {
  final VoidCallback? onBack;
  const GradesPage({super.key, this.onBack});

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> with TickerProviderStateMixin {
  final Map<String, List<Grade>> _gradesByStudent = {};
  bool _isLoading = true;
  // Selection state (uses real schools/class groups)
  List<School> _schools = [];
  School? _selectedSchool;
  final String _selectedTerm = 'الفصل الأول';
  final String _selectedMonthLabel = 'الشهر الأول';
  final String _selectedGradeType = 'monthly';
  double _classAverage = 0.0;
  int _excellentCount = 0;
  int _goodCount = 0;
  int _passCount = 0;
  int _failCount = 0;
  final DateTime _selectedDate = DateTime.now();
  

  late AnimationController _saveButtonController;
  late AnimationController _statsController;
  late Animation<double> _saveButtonScale;
  late Animation<double> _statsSlide;
  

  // إعدادات أعمدة مخصصة للـ Spreadsheet (كل عمود يرتبط بفصل وشهر محددين مع عنوان مخصص)
  // هذا يحقق "كل شيء مخصص" من ناحية عدد الأعمدة والعناوين وربط كل عمود بالشهر المطلوب
  final List<_GradeColCfg> _customGradeColumns = [];

  final List<String> _terms = ['الفصل الأول', 'الفصل الثاني'];

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
    ]).animate(_saveButtonController);

    // تأثير انزلاق الإحصائيات
    _statsSlide = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _statsController, curve: Curves.easeOut));

    // بدء التأثيرات
    _startAnimations();

    // تحميل البيانات
    _initializeData();

    // تهيئة أعمدة افتراضية (يمكن للمستخدم تعديلها بالكامل)
    if (_customGradeColumns.isEmpty) {
      _customGradeColumns.addAll([
        _GradeColCfg(label: 'اختبار 1', term: _terms.first, monthIndex: 1),
        _GradeColCfg(label: 'اختبار 2', term: _terms.first, monthIndex: 2),
      ]);
    }
  }

  // ===== Dynamic Table State =====
  String _tableName = 'Table1';
  List<_DynCol> _dynCols = [];
  List<Map<String, String>> _dynRows = [];
  static const String _kvKeyBase = 'grades_table_v1';
  String get _kvKey => '${_kvKeyBase}_${_selectedSchool?.id ?? 'all'}_${_dateKey(_selectedDate)}';

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  Future<void> _ensureKv() async {
    final db = await DatabaseHelper.instance.database;
    await db.execute('CREATE TABLE IF NOT EXISTS app_kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  }

  Future<void> _loadDynTable() async {
    await _ensureKv();
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('app_kv', where: 'key=?', whereArgs: [_kvKey]);
    if (rows.isEmpty) {
      // start from zero: no columns, no rows
      _dynCols = [];
      _dynRows = [];
      await _saveDynTable();
    } else {
      final data = jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
      _tableName = (data['name'] as String?)?.trim().isNotEmpty == true ? data['name'] as String : 'Table1';
      _dynCols = (data['cols'] as List).map((e) => _DynCol.fromJson(e)).toList();
      _dynRows = (data['rows'] as List).map((e) => Map<String, String>.from(e as Map)).toList();
    }
    setState(() {});
  }

  Future<void> _saveDynTable() async {
    await _ensureKv();
    final db = await DatabaseHelper.instance.database;
    final payload = jsonEncode({
      'name': _tableName,
      'cols': _dynCols.map((e) => e.toJson()).toList(),
      'rows': _dynRows,
    });
    await db.insert('app_kv', {'key': _kvKey, 'value': payload}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  

  Future<Uint8List> _buildDynGradesPdfBytes() async {
    final doc = pw.Document();
    // Try to load Arabic-capable fonts
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

    regularFont = await tryLoad('assets/fonts/Cairo-Regular.ttf') ?? await tryLoad('Cairo-Regular.ttf');
    boldFont = await tryLoad('assets/fonts/Cairo-Bold.ttf') ?? await tryLoad('Cairo-Bold.ttf');
    if (boldFont == null && regularFont != null) {
      boldFont = regularFont;
    }

    final pageTheme = (regularFont != null && boldFont != null)
        ? pw.PageTheme(
            textDirection: pw.TextDirection.rtl,
            theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
          )
        : const pw.PageTheme(textDirection: pw.TextDirection.rtl);

    // Build headers from dynamic columns, include max if provided
    final headers = _dynCols
        .map((c) => c.maxScore != null && c.type == DynColType.number && !c.readOnly
            ? '${c.title} / ${c.maxScore!.toStringAsFixed(0)}'
            : c.title)
        .toList();
    // Build data rows in same order
    final dataRows = _dynRows.map((r) => _dynCols.map((c) => r[c.id] ?? '').toList()).toList();
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'تقرير الدرجات - ${_tableName.isEmpty ? 'جدول' : _tableName}',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text('المدرسة: ${_selectedSchool?.name ?? '-'}'),
              pw.Text('التاريخ: $dateStr'),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: dataRows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                border: null,
                cellAlignment: pw.Alignment.centerRight,
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _printDynGrades() async {
    await Printing.layoutPdf(
      onLayout: (format) async => await _buildDynGradesPdfBytes(),
    );
  }

  // Manual table controls
  void _addRow() {
    final id = 'r${DateTime.now().microsecondsSinceEpoch}';
    final row = <String, String>{'id': id};
    for (final c in _dynCols) {
      row[c.id] = '';
    }
    _dynRows.add(row);
    setState(() {});
    _saveDynTable();
  }

  void _deleteRow(String rowId) {
    _dynRows.removeWhere((r) => r['id'] == rowId);
    setState(() {});
    _saveDynTable();
  }

  void _quickAddColumn() {
    final nextIndex = _dynCols.length + 1;
    final title = 'عمود $nextIndex';
    final id = _uniqueColIdFromTitle(title);
    _dynCols.add(_DynCol(id: id, title: title, type: DynColType.text));
    for (final r in _dynRows) {
      r[id] = '';
    }
    setState(() {});
    _saveDynTable();
  }

  String _uniqueColIdFromTitle(String title) {
    String base = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    if (base.isEmpty) base = 'col';
    String candidate = base;
    int i = 1;
    while (_dynCols.any((c) => c.id == candidate)) {
      candidate = '${base}_$i';
      i++;
    }
    return candidate;
  }

  

  

  

  

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _statsController.forward();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SchoolService.instance.initializeDemoData();

      final schools = await SchoolService.instance.getSchools();
      final selectedSchool = schools.isNotEmpty ? schools.first : null;

      // Initialize dynamic table after data load
      _schools = schools;
      await _loadDynTable();
      setState(() {
        _selectedSchool = selectedSchool;
        _calculateStats();
      });
    } catch (e) {
      // التعامل مع الأخطاء - استخدام debugPrint بدلاً من print
      debugPrint('Error loading students: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // تم إزالة تغيير الشعبة. الاعتماد فقط على المدرسة.

  void _calculateStats() {
    double total = 0;
    int count = 0;
    _excellentCount = 0;
    _goodCount = 0;
    _passCount = 0;
    _failCount = 0;

    for (final entry in _gradesByStudent.entries) {
      List<Grade> matching;
      if (_selectedGradeType == 'monthly') {
        final monthIndex = _monthLabelToIndex(_selectedMonthLabel);
        matching = entry.value.where((g) {
          if (g.gradeType != 'monthly') return false;
          final data = g.additionalData ?? {};
          return data['term'] == _selectedTerm && data['month'] == monthIndex;
        }).toList()..sort((a, b) => b.date.compareTo(a.date));
      } else {
        matching = entry.value.where((g) => g.gradeType == 'daily').toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      }
      if (matching.isNotEmpty) {
        final gradePercent =
            (matching.first.score / matching.first.maxScore) * 100.0;
        total += gradePercent;
        count++;
        if (gradePercent >= 90) {
          _excellentCount++;
        } else if (gradePercent >= 80) {
          _goodCount++;
        } else if (gradePercent >= 60) {
          _passCount++;
        } else {
          _failCount++;
        }
      }
    }

    _classAverage = count > 0 ? total / count : 0.0;
  }

  Future<void> _saveGrades() async {
    setState(() {
      _isLoading = true;
    });

    // تشغيل تأثير زر الحفظ
    await _saveButtonController.forward();

    try {
      // محاكاة حفظ الدرجات
      await Future.delayed(const Duration(seconds: 2));

      // إظهار رسالة النجاح
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'تم حفظ الدرجات بنجاح',
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
      }
    } catch (e) {
      // التعامل مع الأخطاء - استخدام debugPrint بدلاً من print
      debugPrint('Error saving grades: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  


  @override
  void dispose() {
    _saveButtonController.dispose();
    _statsController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        title: Text(
          'إدارة الدرجات',
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
            onPressed: _printDynGrades,
            tooltip: 'طباعة تقرير الدرجات',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_add_row',
            onPressed: _addRow,
            backgroundColor: AppConfig.secondaryColor,
            label: const Text('إضافة صف'),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'fab_add_col',
            onPressed: _quickAddColumn,
            backgroundColor: AppConfig.primaryColor,
            label: const Text('إضافة عمود'),
            icon: const Icon(Icons.view_column),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppConfig.primaryColor,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isPhone = width < 600;
                final contentPadding = EdgeInsets.all(
                  width > 1000 ? AppConfig.spacingLG : AppConfig.spacingMD,
                );
                // Reserve bottom padding so content doesn't hide behind fixed button.
                final extraBottomPadding = media.viewPadding.bottom + 96.0;
                return Stack(
                  children: [
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: contentPadding.copyWith(
                        bottom: (contentPadding.bottom) + extraBottomPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSelectionAndFiltersSection(),
                          const SizedBox(height: AppConfig.spacingLG),
                          // إحصائيات الصف
                          AnimatedBuilder(
                            animation: _statsController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_statsSlide.value, 0),
                                child: Opacity(
                                  opacity: _statsController.value,
                                  child: _buildStatsSection(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppConfig.spacingLG),
                          // قائمة الطلاب والدرجات
                          _buildStudentsGradesSection(),
                          const SizedBox(height: AppConfig.spacingXXL),
                        ],
                      ),
                    ),
                    // زر الحفظ مثبت بالأسفل
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SafeArea(
                          minimum: EdgeInsets.only(
                            left: isPhone
                                ? AppConfig.spacingMD
                                : AppConfig.spacingLG,
                            right: isPhone
                                ? AppConfig.spacingMD
                                : AppConfig.spacingLG,
                            bottom: AppConfig.spacingMD,
                          ),
                          child: AnimatedBuilder(
                            animation: _saveButtonScale,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _saveButtonScale.value,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: width > 700
                                        ? 420
                                        : double.infinity,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _saveGrades,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppConfig.secondaryColor,
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
                                        shadowColor: AppConfig.secondaryColor
                                            .withValues(alpha: 0.3),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.save_outlined,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'حفظ الدرجات',
                                              style: GoogleFonts.cairo(
                                                fontSize:
                                                    AppConfig.fontSizeLarge,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSelectionAndFiltersSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
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
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacingLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppConfig.spacingMD,
                  runSpacing: AppConfig.spacingSM,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSchool?.id,
                        decoration: const InputDecoration(labelText: 'المدرسة'),
                        items: _schools
                            .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                            .toList(),
                        onChanged: (id) async {
                          if (id == null) return;
                          final school = _schools.firstWhere((e) => e.id == id);
                          setState(() {
                            _selectedSchool = school;
                            _isLoading = true;
                          });
                          // Load per-school table (no student sync)
                          await _loadDynTable();
                          setState(() {
                            _isLoading = false;
                          });
                        },
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة صف'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _quickAddColumn,
                      icon: const Icon(Icons.view_column),
                      label: const Text('إضافة عمود'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gap = AppConfig.spacingSM;
        // target card width responsive
        double targetWidth;
        if (width >= 1200) {
          targetWidth = (width - gap * 3) / 4; // 4 per row
        } else if (width >= 900) {
          targetWidth = (width - gap * 2) / 3; // 3 per row
        } else if (width >= 600) {
          targetWidth = (width - gap) / 2; // 2 per row
        } else {
          targetWidth = width; // 1 per row
        }

        final cards = <Widget>[
          _buildStatCard(
            'متوسط الدرجات',
            _classAverage.toStringAsFixed(1),
            Icons.analytics_outlined,
            AppConfig.primaryColor,
          ),
          _buildStatCard(
            'ممتاز',
            _excellentCount.toString(),
            Icons.star_outlined,
            AppConfig.successColor,
          ),
          _buildStatCard(
            'جيد',
            _goodCount.toString(),
            Icons.thumb_up_outlined,
            AppConfig.infoColor,
          ),
          _buildStatCard(
            'مقبول',
            _passCount.toString(),
            Icons.check_circle_outline,
            AppConfig.warningColor,
          ),
          _buildStatCard(
            'راسب',
            _failCount.toString(),
            Icons.warning_amber_outlined,
            AppConfig.errorColor,
          ),
        ];

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
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
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacingLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إحصائيات الصف',
                  style: GoogleFonts.cairo(
                    fontSize: AppConfig.fontSizeXLarge,
                    fontWeight: FontWeight.bold,
                    color: AppConfig.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: AppConfig.spacingLG),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: cards
                      .map((c) => SizedBox(width: targetWidth, child: c))
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(AppConfig.spacingMD),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppConfig.spacingSM),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: AppConfig.fontSizeLarge,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: AppConfig.fontSizeSmall,
                color: AppConfig.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsGradesSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
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
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingLG),
        child: LayoutBuilder(
          builder: (context, c) {
            final vw = c.maxWidth;
            final vh = MediaQuery.of(context).size.height;
            final gridHeight = vw < 600 ? (vh * 0.55).clamp(320, 560) : (vw < 900 ? 520.0 : 600.0);

            final columns = <PlutoColumn>[
              PlutoColumn(
                title: '',
                field: '__actions__',
                type: PlutoColumnType.text(),
                readOnly: true,
                width: 56,
                frozen: PlutoColumnFrozen.start,
                renderer: (ctx) {
                  final rowId = ctx.row.cells['id']!.value as String;
                  return IconButton(
                    tooltip: 'حذف الصف',
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteRow(rowId),
                  );
                },
              ),
              ..._dynCols.map((c) {
                if (c.readOnly || c.type == DynColType.percent) {
                  return PlutoColumn(
                    title: c.title,
                    field: c.id,
                    type: PlutoColumnType.text(),
                    readOnly: true,
                    minWidth: 120,
                  );
                }
                if (c.type == DynColType.number) {
                  return PlutoColumn(
                    title: c.title,
                    field: c.id,
                    type: PlutoColumnType.text(),
                    enableEditingMode: true,
                    minWidth: 120,
                  );
                }
                return PlutoColumn(
                  title: c.title,
                  field: c.id,
                  type: PlutoColumnType.text(),
                  enableEditingMode: true,
                  minWidth: 160,
                );
              }),
            ];

            final rows = _dynRows.map((r) {
              final cells = <String, PlutoCell>{
                'id': PlutoCell(value: r['id'] ?? ''),
                '__actions__': PlutoCell(value: ''),
              };
              for (final c in _dynCols) {
                cells[c.id] = PlutoCell(value: r[c.id] ?? '');
              }
              return PlutoRow(cells: cells);
            }).toList();

            return Container(
              height: gridHeight.toDouble(),
              decoration: BoxDecoration(
                border: Border.all(color: AppConfig.borderColor),
                borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
              ),
              child: PlutoGrid(
                columns: columns,
                rows: rows,
                configuration: PlutoGridConfiguration(
                  style: PlutoGridStyleConfig(
                    gridBorderColor: AppConfig.borderColor,
                    evenRowColor: AppConfig.backgroundColor,
                    oddRowColor: AppConfig.cardColor,
                    activatedColor: AppConfig.primaryColor.withValues(alpha: 0.08),
                    cellTextStyle: GoogleFonts.cairo(
                      color: AppConfig.textPrimaryColor,
                      fontSize: AppConfig.fontSizeSmall,
                    ),
                    columnTextStyle: GoogleFonts.cairo(
                      color: AppConfig.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onChanged: (e) {
                  final rowId = e.row.cells['id']!.value as String;
                  final colId = e.column.field;
                  final val = (e.value ?? '').toString();
                  final row = _dynRows.firstWhere((r) => r['id'] == rowId, orElse: () => {});
                  if (row.isEmpty) return;
                  row[colId] = val;
                  _saveDynTable();
                },
              ),
            );
          },
        ),
      ),
    );
  }


  int _monthLabelToIndex(String label) {
    switch (label) {
      case 'الشهر الأول':
        return 1;
      case 'الشهر الثاني':
        return 2;
      case 'الشهر الثالث':
        return 3;
      default:
        return 1;
    }
  }
}
