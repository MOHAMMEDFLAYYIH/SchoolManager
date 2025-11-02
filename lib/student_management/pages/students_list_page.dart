import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_app/student_management/services/student_service.dart';
import 'package:school_app/core/app_config.dart';
import 'package:school_app/attendance_management/pages/attendance_page.dart';
import 'grades_page.dart';

class StudentsListPage extends StatefulWidget {
  const StudentsListPage({super.key});

  @override
  State<StudentsListPage> createState() => _StudentsListPageState();
}

class _StudentsListPageState extends State<StudentsListPage> {
  List<Student> _students = [];
  List<Student> _filteredStudents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'الكل';
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    // تهيئة البيانات التجريبية
    await StudentService().initializeDemoStudents();

    // الحصول على الطلاب حسب الفلتر المحدد
    List<Student> students;
    switch (_selectedFilter) {
      case 'المرحلة الأولى':
        students = await StudentService().getStudentsByClassGroup('group_1');
        break;
      case 'المرحلة الثانية':
        students = await StudentService().getStudentsByStage('stage_2');
        break;
      case 'المرحلة الثالثة':
        students = await StudentService().getStudentsByStage('stage_3');
        break;
      default:
        students = await StudentService().getAllStudents();
    }

    setState(() {
      _students = students;
      _filteredStudents = _applySearchFilter(students);
      _isLoading = false;
    });
  }

  List<Student> _applySearchFilter(List<Student> students) {
    if (_searchQuery.isEmpty) {
      return students;
    }

    final query = _searchQuery.toLowerCase();
    return students.where((student) {
      return student.fullName.toLowerCase().contains(query) ||
          student.phone.toLowerCase().contains(query) ||
          student.address.toLowerCase().contains(query);
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredStudents = _applySearchFilter(_students);
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _loadStudents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'قائمة الطلاب',
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
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: () {
              // الانتقال إلى صفحة إضافة طالب جديد
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والفلترة
          Container(
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
            child: Column(
              children: [
                // شريط البحث
                TextField(
                  decoration: InputDecoration(
                    hintText: 'البحث عن طالب...',
                    hintStyle: GoogleFonts.cairo(
                      color: AppConfig.textLightColor,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppConfig.primaryColor,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: AppConfig.textLightColor,
                            ),
                            onPressed: () {
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConfig.borderRadius,
                      ),
                      borderSide: BorderSide(color: AppConfig.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConfig.borderRadius,
                      ),
                      borderSide: BorderSide(color: AppConfig.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConfig.borderRadius,
                      ),
                      borderSide: BorderSide(
                        color: AppConfig.primaryColor,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: AppConfig.backgroundColor,
                  ),
                  onChanged: _onSearchChanged,
                ),

                const SizedBox(height: AppConfig.spacingMD),

                // شريط الفلترة
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('الكل'),
                      _buildFilterChip('المرحلة الأولى'),
                      _buildFilterChip('المرحلة الثانية'),
                      _buildFilterChip('المرحلة الثالثة'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // جدول الطلاب (نمط إكسل)
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppConfig.primaryColor,
                    ),
                  )
                : _filteredStudents.isEmpty
                    ? _buildEmptyState()
                    : _buildStudentsTable(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // إضافة طالب جديد
        },
        backgroundColor: AppConfig.primaryColor,
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

  Widget _buildStudentsTable() {
    // لعرض الجدول أفقياً وعمودياً عند الحاجة
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
        child: SingleChildScrollView(
          child: DataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            columns: [
              DataColumn(
                label: const Text('الاسم الكامل'),
                onSort: (i, asc) => _sortBy<String>(i, asc, (s) => s.fullName.toLowerCase()),
              ),
              DataColumn(
                numeric: true,
                label: const Text('العمر'),
                onSort: (i, asc) => _sortBy<num>(i, asc, (s) => s.age),
              ),
              DataColumn(
                label: const Text('الجنس'),
                onSort: (i, asc) => _sortBy<String>(i, asc, (s) => s.gender.toString()),
              ),
              const DataColumn(label: Text('الهاتف')),
              const DataColumn(label: Text('الحالة')),
              const DataColumn(label: Text('إجراءات')),
            ],
            rows: _filteredStudents.map((s) {
              return DataRow(cells: [
                DataCell(Text(s.fullName)),
                DataCell(Text('${s.age}')),
                DataCell(Text(s.gender == 'male' || s.gender == 'ذكر' ? 'ذكر' : 'أنثى')),
                DataCell(Text(s.phone)),
                DataCell(Text(s.status == AppConfig.studentStatusActive ? 'نشط' : 'غير نشط')),
                DataCell(Row(
                  children: [
                    IconButton(
                      tooltip: 'تفاصيل',
                      icon: const Icon(Icons.visibility),
                      onPressed: () => _showStudentDetails(s),
                    ),
                    IconButton(
                      tooltip: 'الحضور',
                      icon: const Icon(Icons.check_circle),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AttendancePage(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'الدرجات',
                      icon: const Icon(Icons.grade),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const GradesPage()),
                        );
                      },
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _sortBy<T>(int columnIndex, bool ascending, Comparable<T> Function(Student s) getField) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _filteredStudents.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        final order = ascending ? 1 : -1;
        return order * Comparable.compare(aValue, bValue);
      });
    });
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Container(
      margin: const EdgeInsets.only(left: AppConfig.spacingSM),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? Colors.white : AppConfig.textPrimaryColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            _onFilterChanged(label);
          }
        },
        backgroundColor: AppConfig.backgroundColor,
        selectedColor: AppConfig.primaryColor,
        checkmarkColor: Colors.white,
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          side: BorderSide(
            color: isSelected ? AppConfig.primaryColor : AppConfig.borderColor,
            width: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: AppConfig.textLightColor),
          const SizedBox(height: AppConfig.spacingLG),
          Text(
            _searchQuery.isEmpty
                ? 'لا يوجد طلاب مضافون بعد'
                : 'لا توجد نتائج للبحث',
            style: GoogleFonts.cairo(
              fontSize: AppConfig.fontSizeXLarge,
              color: AppConfig.textSecondaryColor,
            ),
          ),
          const SizedBox(height: AppConfig.spacingSM),
          Text(
            _searchQuery.isEmpty
                ? 'اضغط على زر الإضافة لبدء إضافة الطلاب'
                : 'جرب كلمات بحث مختلفة',
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

  

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('تصفية الطلاب', style: GoogleFonts.cairo()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'الكل';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedFilter == 'الكل'
                          ? AppConfig.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: _selectedFilter == 'الكل'
                            ? AppConfig.primaryColor
                            : AppConfig.borderColor,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedFilter == 'الكل'
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: _selectedFilter == 'الكل'
                              ? AppConfig.primaryColor
                              : AppConfig.textSecondaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text('الكل', style: GoogleFonts.cairo()),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'المرحلة الأولى';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedFilter == 'المرحلة الأولى'
                          ? AppConfig.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: _selectedFilter == 'المرحلة الأولى'
                            ? AppConfig.primaryColor
                            : AppConfig.borderColor,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedFilter == 'المرحلة الأولى'
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: _selectedFilter == 'المرحلة الأولى'
                              ? AppConfig.primaryColor
                              : AppConfig.textSecondaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text('المرحلة الأولى', style: GoogleFonts.cairo()),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'المرحلة الثانية';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedFilter == 'المرحلة الثانية'
                          ? AppConfig.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: _selectedFilter == 'المرحلة الثانية'
                            ? AppConfig.primaryColor
                            : AppConfig.borderColor,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedFilter == 'المرحلة الثانية'
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: _selectedFilter == 'المرحلة الثانية'
                              ? AppConfig.primaryColor
                              : AppConfig.textSecondaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text('المرحلة الثانية', style: GoogleFonts.cairo()),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'المرحلة الثالثة';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedFilter == 'المرحلة الثالثة'
                          ? AppConfig.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: _selectedFilter == 'المرحلة الثالثة'
                            ? AppConfig.primaryColor
                            : AppConfig.borderColor,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedFilter == 'المرحلة الثالثة'
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: _selectedFilter == 'المرحلة الثالثة'
                              ? AppConfig.primaryColor
                              : AppConfig.textSecondaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text('المرحلة الثالثة', style: GoogleFonts.cairo()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _onFilterChanged(_selectedFilter);
                },
                child: Text('تطبيق', style: GoogleFonts.cairo()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStudentDetails(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل الطالب', style: GoogleFonts.cairo()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('الاسم الكامل', student.fullName),
              // تم حذف عرض رقم الطالب
              _buildDetailRow(
                'تاريخ الميلاد',
                '${student.birthDate.toString().split(' ')[0]} (${student.age} سنة)',
              ),
              _buildDetailRow(
                'الجنس',
                student.gender == 'male' ? 'ذكر' : 'أنثى',
              ),
              _buildDetailRow('العنوان', student.address),
              _buildDetailRow('رقم الهاتف', student.phone),
              if (student.parentPhone != null)
                _buildDetailRow('هاتف ولي الأمر', student.parentPhone!),
              _buildDetailRow(
                'تاريخ التسجيل',
                student.enrollmentDate.toString().split(' ')[0],
              ),
              _buildDetailRow(
                'الحالة',
                student.status == AppConfig.studentStatusActive
                    ? 'نشط'
                    : 'غير نشط',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.cairo(
                fontSize: AppConfig.fontSizeMedium,
                fontWeight: FontWeight.w600,
                color: AppConfig.textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: AppConfig.fontSizeMedium,
                color: AppConfig.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
