import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:school_app/core/app_config.dart';
import 'package:school_app/student_management/services/student_service.dart';

class StudentFormPage extends StatefulWidget {
  final Student? student;

  const StudentFormPage({super.key, this.student});

  @override
  @override
  State<StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends State<StudentFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _birthDateController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _parentPhoneController;

  String _gender = 'ذكر';
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _firstNameController = TextEditingController(
      text: student?.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: student?.lastName ?? '');
    _birthDateController = TextEditingController(
      text: student?.birthDate.toString().split(' ')[0] ?? '',
    );
    _addressController = TextEditingController(text: student?.address ?? '');
    _phoneController = TextEditingController(text: student?.phone ?? '');
    _parentPhoneController = TextEditingController(
      text: student?.parentPhone ?? '',
    );

    if (student != null) {
      _gender = student.gender;
      _status = student.status;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.student == null ? 'إضافة طالب جديد' : 'تعديل بيانات الطالب',
          style: GoogleFonts.cairo(
            fontSize: AppConfig.fontSizeXXLarge,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppConfig.primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField('الاسم الأول', _firstNameController),
              const SizedBox(height: 16),
              _buildTextField('اللقب', _lastNameController),
              const SizedBox(height: 16),
              _buildDateField('تاريخ الميلاد', _birthDateController),
              const SizedBox(height: 16),
              _buildDropdownField('الجنس', _gender, [
                'ذكر',
                'أنثى',
              ], (value) => setState(() => _gender = value!)),
              const SizedBox(height: 16),
              _buildTextField('العنوان', _addressController, maxLines: 2),
              const SizedBox(height: 16),
              _buildTextField(
                'رقم الهاتف',
                _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'هاتف ولي الأمر',
                _parentPhoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildDropdownField('الحالة', _status, [
                'active',
                'inactive',
                'graduated',
                'transferred',
              ], (value) => setState(() => _status = value!)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                  ),
                ),
                child: Text(
                  'حفظ',
                  style: GoogleFonts.cairo(
                    fontSize: AppConfig.fontSizeLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      readOnly: true,
      onTap: () => _selectDate(controller),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
    );
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        controller.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _buildDropdownField<T>(
    String label,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged,
  ) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      items: items.map<DropdownMenuItem<T>>((T value) {
        return DropdownMenuItem<T>(value: value, child: Text(value.toString()));
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
    );
  }

  Future<void> _saveStudent() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final fullName =
            '${_firstNameController.text} ${_lastNameController.text}';
        final now = DateTime.now();
        final generatedStudentId =
            widget.student?.studentId ?? 'STD-${DateTime.now().millisecondsSinceEpoch}';

        final student = Student(
          id:
              widget.student?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          fullName: fullName,
          studentId: generatedStudentId,
          birthDate: DateTime.parse(_birthDateController.text),
          gender: _gender,
          address: _addressController.text,
          phone: _phoneController.text,
          parentPhone: _parentPhoneController.text,
          status: _status,
          classGroupId: widget.student?.classGroupId ?? '',
          schoolId: widget.student?.schoolId ?? '',
          stageId: widget.student?.stageId ?? 'stage_1', // Default stage
          enrollmentDate:
              widget.student?.enrollmentDate ??
              DateTime(now.year, now.month, 1),
        );

        // Save the student
        final studentService = StudentService();
        if (widget.student == null) {
          await studentService.addStudent(student);
        } else {
          await studentService.updateStudent(student);
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ أثناء حفظ بيانات الطالب: ${e.toString()}'),
            ),
          );
        }
      }
    }
  }
}
