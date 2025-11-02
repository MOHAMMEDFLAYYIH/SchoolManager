import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import '../../core/database_helper.dart';
import '../models/school.dart';
import '../../features/teacher/models/teacher.dart';
import '../models/school_stage.dart';
import '../models/class_group.dart';
import '../../student_management/models/student.dart';
import 'package:uuid/uuid.dart';
import '../../student_management/models/attendance.dart';

final _logger = Logger('SchoolService');

class SchoolService {
  // Singleton pattern
  SchoolService._privateConstructor();
  static final SchoolService instance = SchoolService._privateConstructor();

  // Database helper instance
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Get database instance
  Future<Database> get _db async {
    return await _dbHelper.database;
  }

  // يضمن إنشاء المراحل (متوسط + إعدادي) والشعب (5 شعب) للمدرسة إن لم تكن موجودة
  Future<void> ensureDefaultStagesAndGroups(String schoolId) async {
    // تعريف أسماء المراحل الافتراضية
    final desiredStages = <String>[
      'الصف الأول المتوسط',
      'الصف الثاني المتوسط',
      'الصف الثالث المتوسط',
      'الرابع الإعدادي',
      'الخامس الإعدادي',
      'السادس الإعدادي',
    ];

    // إحضار المراحل الحالية
    final existing = await getStagesBySchool(schoolId);
    final existingNames = existing.map((e) => e.name).toSet();

    // إضافة المراحل المفقودة
    var order = existing.isEmpty
        ? 1
        : (existing.map((e) => e.order).fold(0, (a, b) => a > b ? a : b) + 1);
    for (final name in desiredStages) {
      if (!existingNames.contains(name)) {
        await addSchoolStage(
          SchoolStage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            schoolId: schoolId,
            name: name,
            order: order++,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
    }

    // بعد ضمان المراحل، نضمن وجود 5 شعب لكل مرحلة
    final stages = await getStagesBySchool(schoolId);
    const sections = ['أ', 'ب', 'ج', 'د', 'هـ'];
    for (final stage in stages) {
      final existingGroups = await getClassGroupsByStage(stage.id);
      final existingGroupNames = existingGroups.map((g) => g.name).toSet();
      int i = 0;
      for (final sec in sections) {
        final name = 'شعبة $sec';
        if (!existingGroupNames.contains(name)) {
          final now = DateTime.now().millisecondsSinceEpoch + i;
          await addClassGroup(
            ClassGroup(
              id: now.toString(),
              schoolId: schoolId,
              stageId: stage.id,
              name: name,
              capacity: 40,
              currentStudents: 0,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          i++;
        }
      }
    }
  }

  // Convert Map to School
  School _schoolFromMap(Map<String, dynamic> map) {
    return School(
      id: map[DatabaseHelper.columnId].toString(),
      name: map[DatabaseHelper.columnName] ?? '',
      address: map[DatabaseHelper.columnAddress] ?? '',
      phone: map[DatabaseHelper.columnPhone] ?? '',
      email: map[DatabaseHelper.columnEmail] ?? '',
      logo: map['logo']?.toString(),
      directorName: map['director_name']?.toString() ?? 'غير محدد',
      isActive: map['is_active'] == 1,
      educationLevel: map['education_level']?.toString() ?? 'غير محدد',
      section: map['section']?.toString() ?? 'أ',
      studentCount: (map['student_count'] is int)
          ? map['student_count'] as int
          : int.tryParse(map['student_count']?.toString() ?? '0') ?? 0,
      createdAt:
          DateTime.tryParse(
            map[DatabaseHelper.columnCreatedAt]?.toString() ?? '',
          ) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(
            map[DatabaseHelper.columnUpdatedAt]?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  // Convert School to Map
  Map<String, dynamic> _schoolToMap(School school) {
    return {
      DatabaseHelper.columnId: int.tryParse(school.id) ?? 0,
      DatabaseHelper.columnName: school.name,
      DatabaseHelper.columnAddress: school.address,
      DatabaseHelper.columnPhone: school.phone,
      DatabaseHelper.columnEmail: school.email,
      'logo': school.logo,
      'director_name': school.directorName,
      'is_active': school.isActive ? 1 : 0,
      'education_level': school.educationLevel,
      'section': school.section,
      'student_count': school.studentCount,
      DatabaseHelper.columnCreatedAt: school.createdAt.toIso8601String(),
      DatabaseHelper.columnUpdatedAt: school.updatedAt.toIso8601String(),
    };
  }

  // Convert Map to SchoolStage
  SchoolStage _schoolStageFromMap(Map<String, dynamic> map) {
    return SchoolStage(
      id: map[DatabaseHelper.columnId].toString(),
      schoolId: map[DatabaseHelper.columnSchoolId].toString(),
      name: map[DatabaseHelper.columnName] ?? '',
      order: map['sort_order'] is int
          ? map['sort_order']
          : int.tryParse(map['sort_order']?.toString() ?? '0') ?? 0,
      isActive: map['is_active'] == 1,
      createdAt:
          DateTime.tryParse(
            map[DatabaseHelper.columnCreatedAt]?.toString() ?? '',
          ) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(
            map[DatabaseHelper.columnUpdatedAt]?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  // Convert SchoolStage to Map
  Map<String, dynamic> _schoolStageToMap(SchoolStage stage) {
    return {
      DatabaseHelper.columnId: int.tryParse(stage.id) ?? 0,
      DatabaseHelper.columnSchoolId: int.tryParse(stage.schoolId) ?? 0,
      DatabaseHelper.columnName: stage.name,
      'sort_order': stage.order,
      'is_active': stage.isActive ? 1 : 0,
      DatabaseHelper.columnCreatedAt: stage.createdAt.toIso8601String(),
      DatabaseHelper.columnUpdatedAt: stage.updatedAt.toIso8601String(),
    };
  }

  // Convert Map to ClassGroup
  ClassGroup _classGroupFromMap(Map<String, dynamic> map) {
    return ClassGroup(
      id: map[DatabaseHelper.columnId].toString(),
      schoolId: map[DatabaseHelper.columnSchoolId].toString(),
      stageId: map['stage_id'].toString(),
      name: map[DatabaseHelper.columnName] ?? '',
      description: map[DatabaseHelper.columnDescription]?.toString(),
      capacity: map['capacity'] is int
          ? map['capacity']
          : int.tryParse(map['capacity']?.toString() ?? '0') ?? 0,
      teacherId: map['teacher_id']?.toString(),
      teacherName: map['teacher_name']?.toString() ?? 'غير محدد',
      isActive: map['is_active'] == 1,
      createdAt:
          DateTime.tryParse(
            map[DatabaseHelper.columnCreatedAt]?.toString() ?? '',
          ) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(
            map[DatabaseHelper.columnUpdatedAt]?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  // Convert ClassGroup to Map
  Map<String, dynamic> _classGroupToMap(ClassGroup group) {
    return {
      DatabaseHelper.columnId: int.tryParse(group.id) ?? 0,
      DatabaseHelper.columnSchoolId: int.tryParse(group.schoolId) ?? 0,
      'stage_id': int.tryParse(group.stageId) ?? 0,
      DatabaseHelper.columnName: group.name,
      'description': group.description,
      'capacity': group.capacity,
      'teacher_id': group.teacherId != null
          ? int.tryParse(group.teacherId!)
          : null,
      'teacher_name': group.teacherName,
      'is_active': group.isActive ? 1 : 0,
      DatabaseHelper.columnCreatedAt: group.createdAt.toIso8601String(),
      DatabaseHelper.columnUpdatedAt: group.updatedAt.toIso8601String(),
    };
  }

  // Add a new school
  Future<bool> addSchool(School school) async {
    final db = await _db;
    try {
      final now = DateTime.now();
      final schoolToAdd = school.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: now,
        updatedAt: now,
      );

      await db.insert(
        DatabaseHelper.tableSchools,
        _schoolToMap(schoolToAdd),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      _logger.severe('Error adding school', e);
      return false;
    }
  }

  // Get all schools
  Future<List<School>> getSchools() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableSchools,
      where: '${DatabaseHelper.columnIsActive} = ?',
      whereArgs: [1],
    );

    return List.generate(maps.length, (i) => _schoolFromMap(maps[i]));
  }

  // Alias for getSchools to maintain backward compatibility
  Future<List<School>> getAllSchools() => getSchools();

  // Get school by ID
  Future<School?> getSchoolById(String id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableSchools,
      where:
          '${DatabaseHelper.columnId} = ? AND ${DatabaseHelper.columnIsActive} = ?',
      whereArgs: [int.tryParse(id) ?? 0, 1],
    );

    if (maps.isNotEmpty) {
      return _schoolFromMap(maps.first);
    }
    return null;
  }

  // Update a school
  Future<bool> updateSchool(School school) async {
    final db = await _db;
    try {
      final updatedSchool = school.copyWith(updatedAt: DateTime.now());
      final count = await db.update(
        DatabaseHelper.tableSchools,
        _schoolToMap(updatedSchool),
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [int.tryParse(school.id) ?? 0],
      );
      return count > 0;
    } catch (e) {
      _logger.severe('Error updating school', e);
      return false;
    }
  }

  // Delete a school (soft delete)
  Future<bool> deleteSchool(String id) async {
    final db = await _db;
    try {
      final school = await getSchoolById(id);
      if (school == null) return false;

      // Start a transaction to ensure data consistency
      await db.transaction((txn) async {
        // First, deactivate all related stages
        await txn.update(
          DatabaseHelper.tableSchoolStages,
          {
            DatabaseHelper.columnIsActive: 0,
            DatabaseHelper.columnUpdatedAt: DateTime.now().toIso8601String(),
          },
          where: '${DatabaseHelper.columnSchoolId} = ?',
          whereArgs: [int.tryParse(id) ?? 0],
        );

        // Then, deactivate all related class groups
        await txn.update(
          DatabaseHelper.tableClassGroups,
          {
            DatabaseHelper.columnIsActive: 0,
            DatabaseHelper.columnUpdatedAt: DateTime.now().toIso8601String(),
          },
          where: '${DatabaseHelper.columnSchoolId} = ?',
          whereArgs: [int.tryParse(id) ?? 0],
        );

        // Finally, deactivate the school
        await txn.update(
          DatabaseHelper.tableSchools,
          {
            DatabaseHelper.columnIsActive: 0,
            DatabaseHelper.columnUpdatedAt: DateTime.now().toIso8601String(),
          },
          where: '${DatabaseHelper.columnId} = ?',
          whereArgs: [int.tryParse(id) ?? 0],
        );
      });

      return true;
    } catch (e) {
      _logger.severe('Error deleting school', e);
      return false;
    }
  }

  // إضافة مرحلة دراسية
  Future<bool> addSchoolStage(SchoolStage stage) async {
    final db = await _db;
    try {
      final now = DateTime.now();
      final stageToAdd = stage.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: now,
        updatedAt: now,
      );

      await db.insert(
        DatabaseHelper.tableSchoolStages,
        _schoolStageToMap(stageToAdd),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      _logger.severe('Error adding school stage', e);
      return false;
    }
  }

  // الحصول على المراحل الدراسية لمدرسة معينة
  Future<List<SchoolStage>> getStagesBySchool(String schoolId) async {
    final db = await _db;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableSchoolStages,
        where:
            '${DatabaseHelper.columnSchoolId} = ? AND ${DatabaseHelper.columnIsActive} = ?',
        whereArgs: [int.tryParse(schoolId) ?? 0, 1],
      );
      return List.generate(maps.length, (i) => _schoolStageFromMap(maps[i]));
    } catch (e) {
      _logger.severe('Error getting school stages', e);
      return [];
    }
  }

  // إضافة شعبة جديدة
  Future<bool> addClassGroup(ClassGroup classGroup) async {
    final db = await _db;
    try {
      await db.insert(
        DatabaseHelper.tableClassGroups,
        _classGroupToMap(classGroup),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      _logger.severe('Error adding class group', e);
      return false;
    }
  }

  // الحصول على الشعب لمرحلة معينة
  Future<List<ClassGroup>> getClassGroupsByStage(String stageId) async {
    final db = await _db;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableClassGroups,
        where:
            '${DatabaseHelper.columnStageId} = ? AND ${DatabaseHelper.columnIsActive} = ?',
        whereArgs: [int.tryParse(stageId) ?? 0, 1],
      );
      return List.generate(maps.length, (i) => _classGroupFromMap(maps[i]));
    } catch (e) {
      _logger.severe('Error getting class groups by stage', e);
      return [];
    }
  }

  // الحصول على شعبة بالمعرف
  Future<ClassGroup?> getClassGroupById(String id) async {
    final db = await _db;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableClassGroups,
        where:
            '${DatabaseHelper.columnId} = ? AND ${DatabaseHelper.columnIsActive} = ?',
        whereArgs: [int.tryParse(id) ?? 0, 1],
      );
      if (maps.isNotEmpty) {
        return _classGroupFromMap(maps.first);
      }
      return null;
    } catch (e) {
      _logger.severe('Error getting class group by ID', e);
      return null;
    }
  }

  // تحديث شعبة
  Future<bool> updateClassGroup(ClassGroup classGroup) async {
    final db = await _db;
    try {
      final updatedGroup = classGroup.copyWith(updatedAt: DateTime.now());
      final count = await db.update(
        DatabaseHelper.tableClassGroups,
        _classGroupToMap(updatedGroup),
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [int.tryParse(classGroup.id) ?? 0],
      );
      return count > 0;
    } catch (e) {
      _logger.severe('Error updating class group', e);
      return false;
    }
  }

  // حذف شعبة (حذف ناعم)
  Future<bool> deleteClassGroup(String id) async {
    final db = await _db;
    try {
      final now = DateTime.now();
      final count = await db.update(
        DatabaseHelper.tableClassGroups,
        {
          DatabaseHelper.columnIsActive: 0,
          DatabaseHelper.columnUpdatedAt: now.toIso8601String(),
        },
        where: '${DatabaseHelper.columnId} = ?',
        whereArgs: [int.tryParse(id) ?? 0],
      );
      return count > 0;
    } catch (e) {
      _logger.severe('Error deleting class group', e);
      return false;
    }
  }

  // البحث عن المدارس
  Future<List<School>> searchSchools(String query) async {
    final db = await _db;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        DatabaseHelper.tableSchools,
        where:
            '${DatabaseHelper.columnName} LIKE ? AND ${DatabaseHelper.columnIsActive} = ?',
        whereArgs: ['%$query%', 1],
      );
      return List.generate(maps.length, (i) => _schoolFromMap(maps[i]));
    } catch (e) {
      _logger.severe('Error searching schools', e);
      return [];
    }
  }

  // Helper to parse stringified maps
  Map<String, dynamic> _parseMapString(String? mapString) {
    if (mapString == null || mapString.isEmpty) return {};
    try {
      // Simple parsing for the demo - in production, use proper JSON parsing
      return Map<String, dynamic>.from(mapString as Map);
    } catch (e) {
      return {};
    }
  }

  // Convert Teacher to map for database
  Map<String, dynamic> _teacherToMap(Teacher teacher) {
    return {
      'id': teacher.id,
      'first_name': teacher.firstName,
      'last_name': teacher.lastName,
      'full_name': teacher.fullName,
      'employee_id': teacher.employeeId,
      'email': teacher.email,
      'phone': teacher.phone,
      'national_id': teacher.nationalId,
      'qualification': teacher.qualification,
      'specialization': teacher.specialization,
      'school_id': teacher.schoolId,
      'status': teacher.status,
      'hire_date': teacher.hireDate.millisecondsSinceEpoch,
      'profile_image': teacher.profileImage,
      'contact_info': teacher.contactInfo.toString(),
      'emergency_contact': teacher.emergencyContact.toString(),
      'settings': teacher.settings.toString(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'is_active': 1,
    };
  }

  // Convert map to Teacher object
  Teacher _teacherFromMap(Map<String, dynamic> map) {
    return Teacher(
      id: map['id'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      fullName: map['full_name'],
      employeeId: map['employee_id'],
      email: map['email'],
      phone: map['phone'],
      nationalId: map['national_id'],
      qualification: map['qualification'],
      specialization: map['specialization'],
      subjects: [], // Will be populated separately
      schoolId: map['school_id'],
      status: map['status'],
      hireDate: DateTime.fromMillisecondsSinceEpoch(map['hire_date']),
      profileImage: map['profile_image'],
      contactInfo: _parseMapString(map['contact_info']),
      emergencyContact: _parseMapString(map['emergency_contact']),
      settings: _parseMapString(map['settings']),
    );
  }

  // Get all teachers in a school
  Future<List<Teacher>> getTeachersBySchool(String schoolId) async {
    final db = await DatabaseHelper().database;
    await _ensureTeachersTableExists();
    final List<Map<String, dynamic>> maps = await db.query(
      'teachers',
      where: 'school_id = ?',
      whereArgs: [schoolId],
    );
    return List.generate(maps.length, (i) => _teacherFromMap(maps[i]));
  }

  // Get teacher by ID
  Future<Teacher?> getTeacherById(String id) async {
    final db = await DatabaseHelper().database;
    await _ensureTeachersTableExists();
    final List<Map<String, dynamic>> maps = await db.query(
      'teachers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return _teacherFromMap(maps.first);
    }
    return null;
  }

  // Add a new teacher
  Future<Teacher> addTeacher(Teacher teacher) async {
    final db = await DatabaseHelper().database;
    await _ensureTeachersTableExists();
    await db.insert('teachers', _teacherToMap(teacher));
    return teacher;
  }

  // Update an existing teacher
  Future<int> updateTeacher(Teacher teacher) async {
    final db = await DatabaseHelper().database;
    await _ensureTeachersTableExists();
    return await db.update(
      'teachers',
      _teacherToMap(teacher),
      where: 'id = ?',
      whereArgs: [teacher.id],
    );
  }

  // Delete a teacher
  Future<int> deleteTeacher(String id) async {
    final db = await DatabaseHelper().database;
    await _ensureTeachersTableExists();
    return await db.delete('teachers', where: 'id = ?', whereArgs: [id]);
  }

  // Assign teacher to class/subject
  Future<void> assignTeacherToClass({
    required String teacherId,
    required String classGroupId,
    String? subjectId,
    String academicYear = '2023-2024',
    bool isHomeroom = false,
  }) async {
    final db = await DatabaseHelper().database;
    await _ensureTeachersTableExists();
    await db.insert('teacher_class_assignments', {
      'id': '${teacherId}_${classGroupId}_${subjectId ?? 'homeroom'}',
      'teacher_id': teacherId,
      'class_group_id': classGroupId,
      'subject_id': subjectId,
      'academic_year': academicYear,
      'is_homeroom': isHomeroom ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Get teacher's class assignments
  Future<List<Map<String, dynamic>>> getTeacherAssignments(
    String teacherId,
  ) async {
    final db = await DatabaseHelper().database;
    await _ensureTeachersTableExists();
    return await db.query(
      'teacher_class_assignments',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
    );
  }

  // Get teachers for a specific class
  Future<List<Teacher>> getTeachersByClass(String classGroupId) async {
    final db = await DatabaseHelper().database;
    await _ensureTeachersTableExists();
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT t.* FROM teachers t
      INNER JOIN teacher_class_assignments tca ON t.id = tca.teacher_id
      WHERE tca.class_group_id = ?
    ''',
      [classGroupId],
    );

    return List.generate(maps.length, (i) => _teacherFromMap(maps[i]));
  }

  // Get student statistics for a school
  Future<Map<String, dynamic>> getStudentStats(String schoolId) async {
    final db = await _db;
    try {
      // Get total students
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM students WHERE schoolId = ? AND is_active = 1',
        [schoolId],
      );

      // Get students by gender
      final genderResult = await db.rawQuery(
        'SELECT gender, COUNT(*) as count FROM students WHERE schoolId = ? AND is_active = 1 GROUP BY gender',
        [schoolId],
      );

      // Get students by stage
      final stageResult = await db.rawQuery(
        'SELECT s.name as stage_name, COUNT(st.studentId) as count '
        'FROM school_stages s '
        'LEFT JOIN students st ON s.id = st.stageId AND st.schoolId = ? AND st.is_active = 1 '
        'WHERE s.school_id = ? AND s.is_active = 1 '
        'GROUP BY s.id, s.name',
        [schoolId, schoolId],
      );

      final totalStudents = totalResult.isNotEmpty
          ? totalResult.first['count'] as int
          : 0;

      return {
        'totalStudents': totalStudents,
        'genderDistribution': genderResult
            .map((row) => {'gender': row['gender'], 'count': row['count']})
            .toList(),
        'stageDistribution': stageResult
            .map((row) => {'stage': row['stage_name'], 'count': row['count']})
            .toList(),
      };
    } catch (e) {
      _logger.severe('Error getting student statistics', e);
      return {'totalStudents': 0, 'error': e.toString()};
    }
  }

  // الحصول على إحصائيات المدرسة
  Future<Map<String, dynamic>> getSchoolStats(String schoolId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final school = await getSchoolById(schoolId);
      if (school == null) return {};

      // Get student statistics using the new method
      final studentStats = await getStudentStats(schoolId);

      // Get all class groups for the school
      final db = await _db;
      final classGroups = await db.query(
        DatabaseHelper.tableClassGroups,
        where:
            '${DatabaseHelper.columnSchoolId} = ? AND ${DatabaseHelper.columnIsActive} = ?',
        whereArgs: [int.tryParse(schoolId) ?? 0, 1],
      );

      // Calculate class group statistics
      final totalCapacity = classGroups.fold(
        0,
        (sum, group) => sum + (group['capacity'] as int? ?? 0),
      );

      // Get total number of teachers in the school
      final teachers = await getTeachersBySchool(schoolId);
      final totalTeachers = teachers.length;

      return {
        'totalStudents': studentStats['totalStudents'] ?? 0,
        'totalTeachers': totalTeachers,
        'totalClassGroups': classGroups.length,
        'totalStages': (await getStagesBySchool(schoolId)).length,
        'occupancyRate': totalCapacity > 0
            ? (studentStats['totalStudents'] ?? 0) / totalCapacity
            : 0.0,
        'genderDistribution': studentStats['genderDistribution'] ?? [],
        'stageDistribution': studentStats['stageDistribution'] ?? [],
      };
    } catch (e) {
      return {};
    }
  }

  // Teacher management methods
  Future<void> _ensureTeachersTableExists() async {
    final db = await DatabaseHelper().database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teachers (
        id TEXT PRIMARY KEY,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        full_name TEXT NOT NULL,
        employee_id TEXT UNIQUE NOT NULL,
        email TEXT,
        phone TEXT,
        national_id TEXT,
        qualification TEXT,
        specialization TEXT,
        school_id TEXT,
        status TEXT,
        hire_date INTEGER,
        profile_image TEXT,
        contact_info TEXT,
        emergency_contact TEXT,
        settings TEXT,
        created_at INTEGER,
        updated_at INTEGER,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (school_id) REFERENCES schools (id) ON DELETE CASCADE
      )
    ''');

    // Teacher-class assignments table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teacher_class_assignments (
        id TEXT PRIMARY KEY,
        teacher_id TEXT NOT NULL,
        class_group_id TEXT NOT NULL,
        subject_id TEXT,
        academic_year TEXT,
        is_homeroom INTEGER DEFAULT 0,
        created_at INTEGER,
        updated_at INTEGER,
        FOREIGN KEY (teacher_id) REFERENCES teachers (id) ON DELETE CASCADE,
        FOREIGN KEY (class_group_id) REFERENCES class_groups (id) ON DELETE CASCADE,
        UNIQUE(teacher_id, class_group_id, subject_id, academic_year)
      )
    ''');
  }

  // Student management methods
  // Convert Student to map for database
  Map<String, dynamic> _studentToMap(Student student) {
    return {
      'id': student.id,
      'firstName': student.firstName,
      'lastName': student.lastName,
      'fullName': student.fullName,
      'studentId': student.studentId,
      'birthDate': student.birthDate.toIso8601String(),
      'gender': student.gender,
      'address': student.address,
      'phone': student.phone,
      'parentPhone': student.parentPhone,
      'schoolId': student.schoolId,
      'stageId': student.stageId,
      'classGroupId': student.classGroupId,
      'status': student.status,
      'photo': student.photo,
      'enrollmentDate': student.enrollmentDate.toIso8601String(),
      'additionalInfo': student.additionalInfo?.toString(),
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // Convert map to Student object
  Student _studentFromMap(Map<String, dynamic> map) {
    // Safely decode additionalInfo which may be stored as a JSON string or null
    Map<String, dynamic>? additionalInfo;
    final dynamic rawAdditional = map['additionalInfo'];
    if (rawAdditional is String && rawAdditional.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAdditional);
        if (decoded is Map<String, dynamic>) {
          additionalInfo = decoded;
        }
      } catch (_) {
        additionalInfo = null;
      }
    } else if (rawAdditional is Map) {
      try {
        additionalInfo = Map<String, dynamic>.from(rawAdditional);
      } catch (_) {
        additionalInfo = null;
      }
    }

    return Student(
      id: map['id'],
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      fullName: map['fullName'] ?? '',
      studentId: map['studentId'] ?? '',
      birthDate:
          DateTime.tryParse(map['birthDate']?.toString() ?? '') ??
          DateTime.now(),
      gender: map['gender'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      parentPhone: map['parentPhone']?.toString(),
      schoolId: map['schoolId'] ?? '',
      stageId: map['stageId'] ?? '',
      classGroupId: map['classGroupId'] ?? '',
      status: map['status'] ?? 'active',
      photo: map['photo']?.toString(),
      enrollmentDate:
          DateTime.tryParse(map['enrollmentDate']?.toString() ?? '') ??
          DateTime.now(),
      additionalInfo: additionalInfo,
    );
  }

  // Helper method to update class group student count
  Future<void> _updateClassGroupStudentCount(String classGroupId) async {
    final db = await _db;
    final count = await db.rawQuery(
      'SELECT COUNT(*) as count FROM students WHERE classGroupId = ? AND is_active = 1',
      [classGroupId],
    );

    if (count.isNotEmpty) {
      await db.update(
        'class_groups',
        {'current_students': count.first['count'] as int},
        where: 'id = ?',
        whereArgs: [classGroupId],
      );
    }
  }

  // Add a new student
  Future<bool> addStudent(Student student) async {
    final db = await _db;
    try {
      await db.insert(
        'students',
        _studentToMap(student),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Update class group student count
      await _updateClassGroupStudentCount(student.classGroupId);

      return true;
    } catch (e) {
      _logger.severe('Error adding student', e);
      return false;
    }
  }

  // Get all students
  Future<List<Student>> getAllStudents() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'is_active = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) => _studentFromMap(maps[i]));
  }

  // Get students by school
  Future<List<Student>> getStudentsBySchool(String schoolId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'schoolId = ? AND is_active = ?',
      whereArgs: [schoolId, 1],
    );
    return List.generate(maps.length, (i) => _studentFromMap(maps[i]));
  }

  // Get students by stage
  Future<List<Student>> getStudentsByStage(String stageId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'stageId = ? AND is_active = ?',
      whereArgs: [stageId, 1],
    );
    return List.generate(maps.length, (i) => _studentFromMap(maps[i]));
  }

  // Get students by class group
  Future<List<Student>> getStudentsByClassGroup(String classGroupId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'classGroupId = ? AND is_active = ?',
      whereArgs: [classGroupId, 1],
    );
    return List.generate(maps.length, (i) => _studentFromMap(maps[i]));
  }

  // Get student by ID
  Future<Student?> getStudentById(String id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return _studentFromMap(maps.first);
    }
    return null;
  }

  // Update a student
  Future<bool> updateStudent(Student student) async {
    final db = await _db;
    try {
      final count = await db.update(
        'students',
        _studentToMap(student),
        where: 'id = ?',
        whereArgs: [student.id],
      );

      if (count > 0) {
        // Update class group student count if class group changed
        await _updateClassGroupStudentCount(student.classGroupId);
      }

      return count > 0;
    } catch (e) {
      _logger.severe('Error updating student', e);
      return false;
    }
  }

  // Delete a student (soft delete)
  Future<bool> deleteStudent(String id) async {
    final db = await _db;
    try {
      // Get student info before deletion
      final student = await getStudentById(id);
      if (student == null) return false;

      final count = await db.update(
        'students',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );

      if (count > 0) {
        // Update class group student count
        await _updateClassGroupStudentCount(student.classGroupId);
      }

      return count > 0;
    } catch (e) {
      _logger.severe('Error deleting student', e);
      return false;
    }
  }

  // Search students
  Future<List<Student>> searchStudents(String query) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: '(fullName LIKE ? OR studentId LIKE ?) AND is_active = ?',
      whereArgs: ['%$query%', '%$query%', 1],
    );
    return List.generate(maps.length, (i) => _studentFromMap(maps[i]));
  }

  // Initialize demo data
  Future<void> initializeDemoData() async {
    try {
      // Check if we already have schools
      final schools = await getSchools();
      if (schools.isNotEmpty) return;

      // Add a demo school
      final school = School(
        id: '1',
        name: 'مدرسة النموذجية',
        address: 'شارع الرياض، الرياض',
        phone: '0112345678',
        email: 'info@school.edu.sa',
        directorName: 'أحمد محمد',
        educationLevel: 'ابتدائي',
        section: 'أ',
        studentCount: 150,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await addSchool(school);

      // Add demo stages
      final stages = [
        SchoolStage(
          id: '1',
          schoolId: '1',
          name: 'الصف الأول الابتدائي',
          order: 1,
          isActive: true,
          createdAt: DateTime.now(),
        ),
        SchoolStage(
          id: 'stage_2',
          schoolId: school.id,
          name: 'الصف الثاني',
          order: 2,
          createdAt: DateTime.now(),
        ),
        SchoolStage(
          id: 'stage_3',
          schoolId: school.id,
          name: 'الصف الثالث',
          order: 3,
          createdAt: DateTime.now(),
        ),
      ];

      for (final stage in stages) {
        await addSchoolStage(stage);
      }

      // إضافة شعب تجريبية
      final classGroups = [
        ClassGroup(
          id: 'group_1',
          schoolId: school.id,
          stageId: stages[0].id,
          name: 'شعبة أ',
          capacity: 30,
          teacherId: 'teacher_1',
          teacherName: 'أ. فاطمة أحمد',
          createdAt: DateTime.now(),
        ),
        ClassGroup(
          id: 'group_2',
          schoolId: school.id,
          stageId: stages[0].id,
          name: 'شعبة ب',
          capacity: 25,
          teacherId: 'teacher_2',
          teacherName: 'أ. محمد علي',
          createdAt: DateTime.now(),
        ),
      ];

      for (final group in classGroups) {
        await addClassGroup(group);
      }

      // Add demo students
      final demoStudents = [
        Student(
          id: const Uuid().v4(),
          firstName: 'أحمد',
          lastName: 'محمد',
          fullName: 'أحمد محمد',
          studentId: 'STD-001',
          birthDate: DateTime(2015, 1, 1),
          gender: 'ذكر',
          address: 'المنزل',
          phone: '1234567890',
          parentPhone: '0987654321',
          schoolId: school.id,
          stageId: stages[0].id,
          classGroupId: classGroups[0].id,
          status: 'active',
          photo: null,
          enrollmentDate: DateTime.now().subtract(const Duration(days: 90)),
          additionalInfo: {},
        ),
        Student(
          id: const Uuid().v4(),
          firstName: 'سارة',
          lastName: 'خالد',
          fullName: 'سارة خالد',
          studentId: 'STD-002',
          birthDate: DateTime(2015, 5, 15),
          gender: 'أنثى',
          address: 'المنزل',
          phone: '1234567891',
          parentPhone: '0987654322',
          schoolId: school.id,
          stageId: stages[0].id,
          classGroupId: classGroups[0].id,
          status: 'active',
          photo: null,
          enrollmentDate: DateTime.now().subtract(const Duration(days: 90)),
          additionalInfo: {},
        ),
        Student(
          id: const Uuid().v4(),
          firstName: 'محمد',
          lastName: 'علي',
          fullName: 'محمد علي',
          studentId: 'STD-003',
          birthDate: DateTime(2015, 3, 10),
          gender: 'ذكر',
          address: 'المنزل',
          phone: '1234567892',
          parentPhone: '0987654323',
          schoolId: school.id,
          stageId: stages[0].id,
          classGroupId: classGroups[1].id,
          status: 'active',
          photo: null,
          enrollmentDate: DateTime.now().subtract(const Duration(days: 80)),
          additionalInfo: {},
        ),
      ];

      for (final student in demoStudents) {
        await addStudent(student);
      }
    } catch (e) {
      _logger.severe('Error initializing demo data', e);
      rethrow; // Re-throw to allow callers to handle the error
    }
  }

  // =================== Attendance integration ===================
  // Convert Attendance to map for database
  Map<String, dynamic> _attendanceToMap(Attendance attendance) {
    return {
      'id': attendance.id,
      'studentId': attendance.studentId,
      'schoolId': attendance.schoolId,
      'date': attendance.date.toIso8601String(),
      'status': attendance.status,
      'notes': attendance.notes,
      'recordedBy': attendance.recordedBy,
      'recordedAt': attendance.recordedAt.toIso8601String(),
      'checkInTime': attendance.checkInTime,
      'checkOutTime': attendance.checkOutTime,
      'additionalData': attendance.additionalData != null
          ? jsonEncode(attendance.additionalData)
          : null,
    };
  }

  // Convert map to Attendance
  Attendance _attendanceFromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as String,
      studentId: map['studentId'] as String,
      schoolId: map['schoolId'] as String,
      date: DateTime.parse(map['date'] as String),
      status: map['status'] as String,
      notes: map['notes'] as String?,
      recordedBy: (map['recordedBy'] ?? 'system') as String,
      recordedAt: DateTime.parse(
        (map['recordedAt'] as String?) ?? DateTime.now().toIso8601String(),
      ),
      checkInTime: map['checkInTime'] as String?,
      checkOutTime: map['checkOutTime'] as String?,
      additionalData:
          map['additionalData'] != null &&
              (map['additionalData'] as String).isNotEmpty
          ? jsonDecode(map['additionalData'] as String) as Map<String, dynamic>
          : null,
    );
  }

  // Record single student attendance
  Future<bool> recordStudentAttendance(Attendance attendance) async {
    final db = await _db;
    try {
      // Ensure schoolId matches student's school if missing/mismatched
      if (attendance.schoolId.isEmpty) {
        final st = await getStudentById(attendance.studentId);
        if (st != null) {
          attendance = attendance.copyWith(schoolId: st.schoolId);
        }
      }

      // Avoid duplicate for same student and day
      final dayPrefix = attendance.date.toIso8601String().substring(0, 10);
      await db.delete(
        'attendance',
        where: 'studentId = ? AND substr(date,1,10) = ?',
        whereArgs: [attendance.studentId, dayPrefix],
      );

      await db.insert(
        'attendance',
        _attendanceToMap(attendance),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      _logger.severe('Error recording attendance', e);
      return false;
    }
  }

  // Bulk mark attendance for a class group for a specific date
  Future<int> markAttendanceForClassGroup({
    required String classGroupId,
    required String schoolId,
    required DateTime date,
    required String status, // present, absent, excused, late
    String recordedBy = 'system',
  }) async {
    final db = await _db;
    int inserted = 0;
    try {
      final students = await getStudentsByClassGroup(classGroupId);
      final dayPrefix = date.toIso8601String().substring(0, 10);

      for (final st in students) {
        // Delete existing record for that day
        await db.delete(
          'attendance',
          where: 'studentId = ? AND substr(date,1,10) = ?',
          whereArgs: [st.id, dayPrefix],
        );

        final att = Attendance(
          id: const Uuid().v4(),
          studentId: st.id,
          schoolId: schoolId,
          date: date,
          status: status,
          notes: null,
          recordedBy: recordedBy,
          recordedAt: DateTime.now(),
        );
        await db.insert('attendance', _attendanceToMap(att));
        inserted++;
      }
    } catch (e) {
      _logger.severe('Error marking class group attendance', e);
    }
    return inserted;
  }

  // Query attendance by school with optional date range and class filter
  Future<List<Attendance>> getAttendanceBySchool(
    String schoolId, {
    DateTime? from,
    DateTime? to,
    String? classGroupId,
  }) async {
    final db = await _db;
    try {
      final whereClauses = <String>['a.schoolId = ?'];
      final whereArgs = <Object?>[schoolId];
      if (from != null) {
        whereClauses.add('a.date >= ?');
        whereArgs.add(from.toIso8601String());
      }
      if (to != null) {
        whereClauses.add('a.date <= ?');
        whereArgs.add(to.toIso8601String());
      }
      if (classGroupId != null) {
        whereClauses.add('s.classGroupId = ?');
        whereArgs.add(classGroupId);
      }

      final rows = await db.rawQuery('''
        SELECT a.* FROM attendance a
        INNER JOIN students s ON s.id = a.studentId
        WHERE ${whereClauses.join(' AND ')}
        ORDER BY a.date DESC
        ''', whereArgs);
      return rows.map((e) => _attendanceFromMap(e)).toList();
    } catch (e) {
      _logger.severe('Error querying attendance by school', e);
      return [];
    }
  }
}
