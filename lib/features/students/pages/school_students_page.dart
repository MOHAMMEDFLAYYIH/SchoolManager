import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_app/core/app_config.dart';
import 'package:school_app/school_management/models/school.dart';
import 'package:school_app/school_management/services/school_service.dart';
import 'package:school_app/student_management/models/student.dart';
import 'package:uuid/uuid.dart';

class SchoolStudentsPage extends StatefulWidget {
  final School school;

  const SchoolStudentsPage({super.key, required this.school});

  @override
  State<SchoolStudentsPage> createState() => _SchoolStudentsPageState();
}

class _SchoolStudentsPageState extends State<SchoolStudentsPage> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load real students for this school
      final students = await SchoolService.instance.getStudentsBySchool(
        widget.school.id,
      );

      // Map each student to UI map, resolving class group name
      final List<Map<String, dynamic>> items = [];
      for (final Student s in students) {
        String classLabel = '';
        try {
          final group = await SchoolService.instance.getClassGroupById(
            s.classGroupId,
          );
          if (group != null) {
            classLabel = group.name;
          }
        } catch (_) {}

        items.add({
          'id': s.id,
          'name': s.fullName.isNotEmpty
              ? s.fullName
              : '${s.firstName} ${s.lastName}',
          'class': classLabel.isNotEmpty ? classLabel : 'غير محدد',
          'grade': '-',
          'attendance': 0,
        });
      }

      if (!mounted) return;
      setState(() {
        _students = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _students = [];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    if (_searchQuery.isEmpty) {
      return _students;
    }
    return _students
        .where(
          (student) =>
              student['name'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              student['class'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        title: Text(
          'طلاب ${widget.school.name}',
          style: GoogleFonts.cairo(
            fontSize: AppConfig.fontSizeXXLarge,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppConfig.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStudents,
          ),
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: _showAddStudentDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // معلومات المدرسة مختصرة
          _buildSchoolInfo(),

          // شريط البحث
          Container(
            padding: const EdgeInsets.all(AppConfig.spacingMD),
            decoration: BoxDecoration(
              color: AppConfig.cardColor,
              boxShadow: [
                BoxShadow(
                  color: AppConfig.borderColor.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'البحث في الطلاب...',
                hintStyle: GoogleFonts.cairo(
                  color: AppConfig.textSecondaryColor,
                  fontSize: AppConfig.fontSizeMedium,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppConfig.textSecondaryColor,
                ),
                filled: true,
                fillColor: AppConfig.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                  borderSide: BorderSide(color: AppConfig.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                  borderSide: BorderSide(color: AppConfig.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                  borderSide: BorderSide(color: AppConfig.primaryColor),
                ),
              ),
              style: GoogleFonts.cairo(
                fontSize: AppConfig.fontSizeMedium,
                color: AppConfig.textPrimaryColor,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // قائمة الطلاب
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppConfig.primaryColor,
                    ),
                  )
                : _filteredStudents.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(AppConfig.spacingMD),
                    itemCount: _filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = _filteredStudents[index];
                      return _buildStudentCard(student);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        backgroundColor: AppConfig.secondaryColor,
        foregroundColor: Colors.white,
        elevation: AppConfig.buttonElevation,
        icon: const Icon(Icons.person_add),
        label: Text(
          'إضافة طالب',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSchoolInfo() {
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacingMD),
      margin: const EdgeInsets.all(AppConfig.spacingMD),
      decoration: BoxDecoration(
        color: AppConfig.cardColor,
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppConfig.borderColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppConfig.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
            ),
            child: Icon(Icons.school, color: AppConfig.primaryColor, size: 25),
          ),
          const SizedBox(width: AppConfig.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.school.name,
                  style: GoogleFonts.cairo(
                    fontSize: AppConfig.fontSizeLarge,
                    fontWeight: FontWeight.bold,
                    color: AppConfig.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.school.educationLevel} - شعبة ${widget.school.section}',
                  style: GoogleFonts.cairo(
                    fontSize: AppConfig.fontSizeMedium,
                    color: AppConfig.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacingSM,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppConfig.infoColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
            ),
            child: Text(
              '${_students.length} طالب',
              style: GoogleFonts.cairo(
                fontSize: AppConfig.fontSizeSmall,
                fontWeight: FontWeight.w600,
                color: AppConfig.infoColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppConfig.textLightColor),
          const SizedBox(height: AppConfig.spacingLG),
          Text(
            'لا يوجد طلاب مضافون',
            style: GoogleFonts.cairo(
              fontSize: AppConfig.fontSizeLarge,
              color: AppConfig.textSecondaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppConfig.spacingSM),
          Text(
            'اضغط على زر إضافة طالب لبدء إضافة الطلاب',
            style: GoogleFonts.cairo(
              fontSize: AppConfig.fontSizeMedium,
              color: AppConfig.textLightColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConfig.spacingMD),
      decoration: BoxDecoration(
        color: AppConfig.cardColor,
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppConfig.borderColor.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacingLG),
        child: Row(
          children: [
            // صورة الطالب
            CircleAvatar(
              radius: 25,
              backgroundColor: AppConfig.primaryColor.withValues(alpha: 0.1),
              child: Text(
                student['name'].toString().substring(0, 1),
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
                    student['name'].toString(),
                    style: GoogleFonts.cairo(
                      fontSize: AppConfig.fontSizeLarge,
                      fontWeight: FontWeight.bold,
                      color: AppConfig.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    student['class'].toString(),
                    style: GoogleFonts.cairo(
                      fontSize: AppConfig.fontSizeMedium,
                      color: AppConfig.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.grade,
                        color: AppConfig.warningColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        student['grade'].toString(),
                        style: GoogleFonts.cairo(
                          fontSize: AppConfig.fontSizeSmall,
                          color: AppConfig.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppConfig.spacingMD),
                      Icon(
                        Icons.access_time,
                        color: AppConfig.infoColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${student['attendance']}% حضور',
                        style: GoogleFonts.cairo(
                          fontSize: AppConfig.fontSizeSmall,
                          color: AppConfig.infoColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // أزرار العمليات (تعديل وحذف)
            Column(
              children: [
                // زر التعديل
                IconButton(
                  onPressed: () => _showEditStudentDialog(student),
                  icon: Icon(
                    Icons.edit,
                    color: AppConfig.primaryColor,
                    size: 20,
                  ),
                  tooltip: 'تعديل',
                ),

                // زر الحذف
                IconButton(
                  onPressed: () => _showDeleteConfirmationDialog(student),
                  icon: Icon(
                    Icons.delete,
                    color: AppConfig.errorColor,
                    size: 20,
                  ),
                  tooltip: 'حذف',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تأكيد الحذف',
          style: GoogleFonts.cairo(
            fontSize: AppConfig.fontSizeLarge,
            fontWeight: FontWeight.bold,
            color: AppConfig.textPrimaryColor,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف الطالب "${student['name']}"؟\n\nلا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(
            fontSize: AppConfig.fontSizeMedium,
            color: AppConfig.textSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                color: AppConfig.textSecondaryColor,
                fontSize: AppConfig.fontSizeMedium,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteStudent(student);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
              ),
            ),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w600,
                fontSize: AppConfig.fontSizeMedium,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
      ),
    );
  }

  void _deleteStudent(Map<String, dynamic> student) {
    () async {
      await SchoolService.instance.deleteStudent(student['id'] as String);
      await _loadStudents();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حذف الطالب ${student['name']} بنجاح',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppConfig.successColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
          ),
        ),
      );
    }();
  }

  void _showEditStudentDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => EditStudentDialog(
        school: widget.school,
        student: student,
        onStudentUpdated: (updatedStudent) {
          // تحديث بيانات الطالب في القائمة
          final index = _students.indexWhere(
            (s) => s['id'] == updatedStudent['id'],
          );
          if (index != -1) {
            setState(() {
              _students[index] = updatedStudent;
            });
          }
        },
      ),
    );
  }

  Future<void> _showAddStudentDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AddStudentDialog(school: widget.school),
    );
    if (mounted) {
      await _loadStudents();
    }
  }
}

class EditStudentDialog extends StatefulWidget {
  final School school;
  final Map<String, dynamic> student;
  final Function(Map<String, dynamic>) onStudentUpdated;

  const EditStudentDialog({
    super.key,
    required this.school,
    required this.student,
    required this.onStudentUpdated,
  });

  @override
  State<EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<EditStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _familyNameController;
  String _selectedEducationLevel = '';
  String _selectedSection = '';
  bool _isLoading = false;

  // Education levels and sections
  final List<String> _detailedEducationLevels = [
    'الصف الأول الابتدائي',
    'الصف الثاني الابتدائي',
    'الصف الثالث الابتدائي',
    'الصف الرابع الابتدائي',
    'الصف الخامس الابتدائي',
    'الصف السادس الابتدائي',
    'الصف الأول المتوسط',
    'الصف الثاني المتوسط',
    'الصف الثالث المتوسط',
    'الصف الأول الثانوي',
    'الصف الثاني الثانوي',
    'الصف الثالث الثانوي',
  ];

  final List<String> _availableSections = ['أ', 'ب', 'ج', 'د', 'هـ'];

  @override
  void initState() {
    super.initState();
    // Initialize with current student data
    final nameParts = widget.student['name'].toString().split(' ');
    _firstNameController = TextEditingController(
      text: nameParts.isNotEmpty ? nameParts[0] : '',
    );
    _middleNameController = TextEditingController(
      text: nameParts.length > 1 ? nameParts[1] : '',
    );
    _lastNameController = TextEditingController(
      text: nameParts.length > 2 ? nameParts[2] : '',
    );
    _familyNameController = TextEditingController(
      text: nameParts.length > 3 ? nameParts[3] : '',
    );

    // Extract current education level and section from student data
    final classInfo = widget.student['class'].toString();
    _selectedEducationLevel = _extractEducationLevel(classInfo);
    _selectedSection = _extractSection(classInfo);
  }

  String _extractEducationLevel(String classInfo) {
    for (var level in _detailedEducationLevels) {
      if (classInfo.contains(level)) {
        return level;
      }
    }
    return _detailedEducationLevels.first;
  }

  String _extractSection(String classInfo) {
    final sectionMatch = RegExp(r'شعبة (\w)').firstMatch(classInfo);
    if (sectionMatch != null) {
      return sectionMatch.group(1) ?? 'أ';
    }
    return 'أ';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Create updated student data
    final fullName =
        '${_firstNameController.text.trim()} ${_middleNameController.text.trim()} ${_lastNameController.text.trim()} ${_familyNameController.text.trim()}';

    await Future.delayed(const Duration(seconds: 1));

    final updatedStudent = {
      'id': widget.student['id'],
      'name': fullName,
      'class':
          '${widget.school.name} - $_selectedEducationLevel - شعبة $_selectedSection',
      'grade': widget.student['grade'],
      'attendance': widget.student['attendance'],
    };

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
    widget.onStudentUpdated(updatedStudent);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديث بيانات الطالب $fullName بنجاح',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppConfig.successColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'تعديل بيانات الطالب',
        style: GoogleFonts.cairo(
          fontSize: AppConfig.fontSizeLarge,
          fontWeight: FontWeight.bold,
          color: AppConfig.textPrimaryColor,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // School name (disabled)
              TextFormField(
                initialValue: widget.school.name,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'اسم المدرسة',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeMedium,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.borderColor),
                  ),
                  filled: true,
                  fillColor: AppConfig.backgroundColor,
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textSecondaryColor,
                ),
              ),
              const SizedBox(height: AppConfig.spacingMD),

              // Education level dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedEducationLevel,
                decoration: InputDecoration(
                  labelText: 'مرحلة الدراسة',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeMedium,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                items: _detailedEducationLevels.map((level) {
                  return DropdownMenuItem(value: level, child: Text(level));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEducationLevel = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى اختيار مرحلة الدراسة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConfig.spacingMD),

              // Section dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedSection,
                decoration: InputDecoration(
                  labelText: 'الشعبة',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeMedium,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                items: _availableSections.map((section) {
                  return DropdownMenuItem(
                    value: section,
                    child: Text('شعبة $section'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSection = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى اختيار الشعبة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConfig.spacingMD),

              // Name fields section
              Text(
                'الاسم الرباعي',
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  fontWeight: FontWeight.bold,
                  color: AppConfig.textPrimaryColor,
                ),
              ),
              const SizedBox(height: AppConfig.spacingSM),

              // First name
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'الاسم الأول',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeSmall,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال الاسم الأول';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConfig.spacingSM),

              // Middle name
              TextFormField(
                controller: _middleNameController,
                decoration: InputDecoration(
                  labelText: 'الاسم الثاني',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeSmall,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال الاسم الثاني';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConfig.spacingSM),

              // Last name
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'الاسم الثالث',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeSmall,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال الاسم الثالث';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConfig.spacingSM),

              // Family name
              TextFormField(
                controller: _familyNameController,
                decoration: InputDecoration(
                  labelText: 'اسم العائلة',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeSmall,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال اسم العائلة';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'إلغاء',
            style: GoogleFonts.cairo(
              color: AppConfig.textSecondaryColor,
              fontSize: AppConfig.fontSizeMedium,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConfig.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacingLG,
              vertical: AppConfig.spacingSM,
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'حفظ التغييرات',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w600,
                    fontSize: AppConfig.fontSizeMedium,
                  ),
                ),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
      ),
    );
  }
}

// Add Student Dialog
class AddStudentDialog extends StatefulWidget {
  final School school;

  const AddStudentDialog({super.key, required this.school});

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _familyNameController = TextEditingController();
  String _selectedEducationLevel = '';
  String _selectedSection = '';
  bool _isLoading = false;

  // Education levels and sections
  final List<String> _detailedEducationLevels = [
    'الصف الأول الابتدائي',
    'الصف الثاني الابتدائي',
    'الصف الثالث الابتدائي',
    'الصف الرابع الابتدائي',
    'الصف الخامس الابتدائي',
    'الصف السادس الابتدائي',
    'الصف الأول المتوسط',
    'الصف الثاني المتوسط',
    'الصف الثالث المتوسط',
    'الصف الأول الثانوي',
    'الصف الثاني الثانوي',
    'الصف الثالث الثانوي',
  ];

  final List<String> _availableSections = ['أ', 'ب', 'ج', 'د', 'هـ'];

  @override
  void initState() {
    super.initState();
    // Set default values based on school
    _selectedEducationLevel = _getEducationLevelFromSchool(widget.school);
    _selectedSection = widget.school.section;
  }

  String _getEducationLevelFromSchool(School school) {
    switch (school.educationLevel) {
      case 'ابتدائي':
        return 'الصف الأول الابتدائي';
      case 'متوسط':
        return 'الصف الأول المتوسط';
      case 'ثانوي':
        return 'الصف الأول الثانوي';
      default:
        return _detailedEducationLevels.first;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Ensure stages and groups exist for this school and resolve IDs
    await SchoolService.instance.ensureDefaultStagesAndGroups(widget.school.id);

    // Resolve stage by selected education level name
    final stages = await SchoolService.instance.getStagesBySchool(
      widget.school.id,
    );
    final stage = stages.firstWhere(
      (s) => s.name == _selectedEducationLevel,
      orElse: () => stages.isNotEmpty ? stages.first : stages.single,
    );

    // Resolve class group by name like "شعبة أ/ب..."
    final groups = await SchoolService.instance.getClassGroupsByStage(stage.id);
    final groupName = 'شعبة $_selectedSection';
    final group = groups.firstWhere(
      (g) => g.name == groupName,
      orElse: () => groups.first,
    );

    // Create full name
    final fullName =
        '${_firstNameController.text.trim()} ${_middleNameController.text.trim()} ${_lastNameController.text.trim()} ${_familyNameController.text.trim()}';

    // Build Student model
    final student = Student(
      id: const Uuid().v4(),
      firstName: _firstNameController.text.trim(),
      lastName: _familyNameController.text.trim(),
      fullName: fullName,
      studentId: DateTime.now().millisecondsSinceEpoch.toString(),
      birthDate: DateTime.now(),
      gender: 'ذكر',
      address: '',
      phone: '',
      parentPhone: '',
      schoolId: widget.school.id,
      stageId: stage.id,
      classGroupId: group.id,
      status: 'active',
      photo: null,
      enrollmentDate: DateTime.now(),
      additionalInfo: {},
    );

    // Persist and check result
    final bool added = await SchoolService.instance.addStudent(student);

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;
    if (!context.mounted) return;

    if (!added) {
      // Show error and keep dialog open for retry
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل إضافة الطالب. يرجى المحاولة مرة أخرى',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppConfig.errorColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
          ),
        ),
      );
      return;
    }

    // Refresh parent list on success
    final parentState = context
        .findAncestorStateOfType<_SchoolStudentsPageState>();
    await parentState?._loadStudents();
    if (!mounted) return;

    // Capture messenger before popping to avoid using a disposed context
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    // Schedule snackbar after pop in next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'تم إضافة الطالب $fullName بنجاح',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppConfig.successColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'إضافة طالب جديد',
        style: GoogleFonts.cairo(
          fontSize: AppConfig.fontSizeLarge,
          fontWeight: FontWeight.bold,
          color: AppConfig.textPrimaryColor,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // School name (disabled)
              TextFormField(
                initialValue: widget.school.name,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'اسم المدرسة',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeMedium,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.borderColor),
                  ),
                  filled: true,
                  fillColor: AppConfig.backgroundColor,
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textSecondaryColor,
                ),
              ),
              const SizedBox(height: AppConfig.spacingMD),

              // Education level dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedEducationLevel,
                decoration: InputDecoration(
                  labelText: 'مرحلة الدراسة',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeMedium,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                items: _detailedEducationLevels.map((level) {
                  return DropdownMenuItem(value: level, child: Text(level));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEducationLevel = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى اختيار مرحلة الدراسة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConfig.spacingMD),

              // Section dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedSection,
                decoration: InputDecoration(
                  labelText: 'الشعبة',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeMedium,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                items: _availableSections.map((section) {
                  return DropdownMenuItem(
                    value: section,
                    child: Text('شعبة $section'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSection = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى اختيار الشعبة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConfig.spacingMD),

              // Name fields section
              Text(
                'الاسم الرباعي',
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  fontWeight: FontWeight.bold,
                  color: AppConfig.textPrimaryColor,
                ),
              ),
              const SizedBox(height: AppConfig.spacingSM),

              // First name
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'الاسم الأول',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeSmall,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال الاسم الأول';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConfig.spacingSM),

              // Middle name
              TextFormField(
                controller: _middleNameController,
                decoration: InputDecoration(
                  labelText: 'الاسم الثاني',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeSmall,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال الاسم الثاني';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConfig.spacingSM),

              // Last name
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'الاسم الثالث',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeSmall,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال الاسم الثالث';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConfig.spacingSM),

              // Family name
              TextFormField(
                controller: _familyNameController,
                decoration: InputDecoration(
                  labelText: 'اسم العائلة',
                  labelStyle: GoogleFonts.cairo(
                    color: AppConfig.textSecondaryColor,
                    fontSize: AppConfig.fontSizeSmall,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConfig.borderRadius / 2,
                    ),
                    borderSide: BorderSide(color: AppConfig.primaryColor),
                  ),
                ),
                style: GoogleFonts.cairo(
                  fontSize: AppConfig.fontSizeMedium,
                  color: AppConfig.textPrimaryColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال اسم العائلة';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'إلغاء',
            style: GoogleFonts.cairo(
              color: AppConfig.textSecondaryColor,
              fontSize: AppConfig.fontSizeMedium,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConfig.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacingLG,
              vertical: AppConfig.spacingSM,
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'إضافة الطالب',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w600,
                    fontSize: AppConfig.fontSizeMedium,
                  ),
                ),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
      ),
    );
  }
}
