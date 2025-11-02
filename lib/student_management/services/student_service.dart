import 'package:sqflite/sqflite.dart';
import 'package:school_app/core/database_helper.dart' as db_helper;
import 'package:school_app/student_management/models/student.dart';
import 'package:school_app/student_management/models/attendance.dart';
import 'package:school_app/student_management/models/grade.dart';
import 'package:school_app/student_management/models/student_report.dart';
import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

// Re-export the models for convenience
export 'package:school_app/student_management/models/student.dart';
export 'package:school_app/student_management/models/attendance.dart';
export 'package:school_app/student_management/models/grade.dart';
export 'package:school_app/student_management/models/student_report.dart';

class StudentService {
  static final StudentService _instance = StudentService._internal();
  factory StudentService() => _instance;

  final _logger = Logger('StudentService');
  final db_helper.DatabaseHelper _dbHelper = db_helper.DatabaseHelper();

  // Singleton pattern
  StudentService._internal();

  // Tables
  static const String tableStudents = 'students';
  static const String tableAttendance = 'attendance';
  static const String tableGrades = 'grades';

  // Common columns (aligned with DatabaseHelper schema - camelCase)
  static const String columnId = 'id';
  static const String columnStudentId = 'studentId';
  static const String columnSchoolId = 'schoolId';
  static const String columnClassGroupId = 'classGroupId';
  static const String columnStageId = 'stageId';
  static const String columnDate = 'date';
  static const String columnStatus = 'status';
  // Students table uses created_at/updated_at but we don't rely on them here
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  // Students table columns (actual)
  static const String columnFullName = 'fullName';
  static const String columnStudentCode = 'studentId';
  static const String columnGender = 'gender';
  static const String columnBirthDate = 'birthDate';
  static const String columnAddress = 'address';
  static const String columnPhone = 'phone';
  static const String columnParentPhone = 'parentPhone';
  static const String columnIsActive = 'is_active';

  // Attendance table columns
  static const String columnAttendanceType = 'attendance_type';
  static const String columnNotes = 'notes';

  // Grades table columns (actual)
  static const String columnSubject = 'subject';
  static const String columnGradeType = 'gradeType';
  static const String columnScore = 'score';
  static const String columnMaxScore = 'maxScore';

  // Add a new student
  Future<bool> addStudent(Student student) async {
    try {
      final db = await _dbHelper.database;

      await db.insert(
        tableStudents,
        _studentToMap(student),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return true;
    } catch (e) {
      _logger.severe('Error adding student', e);
      return false;
    }
  }

  // Get grades filtered by subject and gradeType for a student
  Future<List<Grade>> getStudentGradesBy(
    String studentId, {
    String? subject,
    String? gradeType,
    String? schoolId,
  }) async {
    try {
      final db = await _dbHelper.database;
      final whereClauses = <String>[];
      final whereArgs = <Object?>[];
      whereClauses.add('$columnStudentId = ?');
      whereArgs.add(studentId);
      if (subject != null) {
        whereClauses.add('$columnSubject = ?');
        whereArgs.add(subject);
      }
      if (gradeType != null) {
        whereClauses.add('$columnGradeType = ?');
        whereArgs.add(gradeType);
      }
      if (schoolId != null) {
        whereClauses.add('$columnSchoolId = ?');
        whereArgs.add(schoolId);
      }
      final List<Map<String, dynamic>> maps = await db.query(
        tableGrades,
        where: whereClauses.join(' AND '),
        whereArgs: whereArgs,
        orderBy: '$columnDate DESC',
      );
      return List.generate(maps.length, (i) => _gradeFromMap(maps[i]));
    } catch (e) {
      _logger.severe('Error getting filtered student grades', e);
      return [];
    }
  }

  // Delete grades for student+subject+gradeType (bulk delete)
  Future<int> deleteGradesForStudentSubjectTerm(
    String studentId,
    String subject,
    String gradeType,
  ) async {
    try {
      final db = await _dbHelper.database;
      return await db.delete(
        tableGrades,
        where:
            '$columnStudentId = ? AND $columnSubject = ? AND $columnGradeType = ?',
        whereArgs: [studentId, subject, gradeType],
      );
    } catch (e) {
      _logger.severe('Error deleting grades by filters', e);
      return 0;
    }
  }

  // Get all active students
  Future<List<Student>> getAllStudents() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableStudents,
        where: '$columnIsActive = ?',
        whereArgs: [1],
      );

      return List.generate(maps.length, (i) => _studentFromMap(maps[i]));
    } catch (e) {
      _logger.severe('Error getting all students', e);
      return [];
    }
  }

  // Get students by school
  Future<List<Student>> getStudentsBySchool(String schoolId) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableStudents,
        where: '$columnSchoolId = ? AND $columnIsActive = ?',
        whereArgs: [schoolId, 1],
      );

      return List.generate(maps.length, (i) => _studentFromMap(maps[i]));
    } catch (e) {
      _logger.severe('Error getting students by school', e);
      return [];
    }
  }

  // Get students by stage
  Future<List<Student>> getStudentsByStage(String stageId) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableStudents,
        where: '$columnStageId = ? AND $columnIsActive = ?',
        whereArgs: [stageId, 1],
      );

      return List.generate(maps.length, (i) => _studentFromMap(maps[i]));
    } catch (e) {
      _logger.severe('Error getting students by stage', e);
      return [];
    }
  }

  // Get students by class group
  Future<List<Student>> getStudentsByClassGroup(String classGroupId) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableStudents,
        where: '$columnClassGroupId = ? AND $columnIsActive = ?',
        whereArgs: [classGroupId, 1],
      );

      return List.generate(maps.length, (i) => _studentFromMap(maps[i]));
    } catch (e) {
      _logger.severe('Error getting students by class group', e);
      return [];
    }
  }

  // Get student by ID
  Future<Student?> getStudentById(String id) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableStudents,
        where: '$columnId = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return _studentFromMap(maps.first);
      }
      return null;
    } catch (e) {
      _logger.severe('Error getting student by ID', e);
      return null;
    }
  }

  // Update a student
  Future<bool> updateStudent(Student student) async {
    try {
      final db = await _dbHelper.database;
      final int count = await db.update(
        tableStudents,
        _studentToMap(student),
        where: '$columnId = ?',
        whereArgs: [student.id],
      );

      return count > 0;
    } catch (e) {
      _logger.severe('Error updating student', e);
      return false;
    }
  }

  // Delete a student (soft delete)
  Future<bool> deleteStudent(String id) async {
    try {
      final db = await _dbHelper.database;
      final int count = await db.update(
        tableStudents,
        {columnIsActive: 0, columnUpdatedAt: DateTime.now().toIso8601String()},
        where: '$columnId = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      _logger.severe('Error deleting student', e);
      return false;
    }
  }

  // Search for students
  Future<List<Student>> searchStudents(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableStudents,
        where: '($columnFullName LIKE ? OR $columnPhone LIKE ?) AND $columnIsActive = ?',
        whereArgs: ['%$query%', '%$query%', 1],
      );

      return List.generate(maps.length, (i) => _studentFromMap(maps[i]));
    } catch (e) {
      _logger.severe('Error searching students', e);
      return [];
    }
  }

  // Record attendance
  Future<bool> recordAttendance(Attendance attendance) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        tableAttendance,
        _attendanceToMap(attendance),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      _logger.severe('Error recording attendance', e);
      return false;
    }
  }

  // Get student attendance
  Future<List<Attendance>> getStudentAttendance(String studentId) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableAttendance,
        where: '$columnStudentId = ?',
        whereArgs: [studentId],
        orderBy: '$columnDate DESC',
      );

      return List.generate(maps.length, (i) => _attendanceFromMap(maps[i]));
    } catch (e) {
      _logger.severe('Error getting student attendance', e);
      return [];
    }
  }

  // Get student grades
  Future<List<Grade>> getStudentGrades(String studentId) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableGrades,
        where: '$columnStudentId = ?',
        whereArgs: [studentId],
        orderBy: '$columnDate DESC, $columnSubject',
      );

      return List.generate(maps.length, (i) => _gradeFromMap(maps[i]));
    } catch (e) {
      _logger.severe('Error getting student grades', e);
      return [];
    }
  }

  // Initialize demo data
  Future<void> initializeDemoStudents() async {
    try {
      // Check if we already have students
      final students = await getAllStudents();
      if (students.isNotEmpty) return;

      // Add demo students
      final now = DateTime.now();
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
          schoolId: '1',
          stageId: '1',
          classGroupId: 'group_1',
          status: 'active',
          photo: null,
          enrollmentDate: now.subtract(const Duration(days: 90)),
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
          schoolId: '1',
          stageId: '1',
          classGroupId: 'group_1',
          status: 'active',
          photo: null,
          enrollmentDate: now.subtract(const Duration(days: 90)),
          additionalInfo: {},
        ),
      ];

      for (final student in demoStudents) {
        await addStudent(student);
      }

      // Add demo attendance
      await _addDemoAttendance(demoStudents[0].id, demoStudents[1].id);

      // Add demo grades
      await _addDemoGrades(demoStudents[0].id, demoStudents[1].id);
    } catch (e) {
      _logger.severe('Error initializing demo students', e);
      rethrow;
    }
  }

  // Generate student report
  Future<StudentReport> generateStudentReport(String studentId) async {
    try {
      final student = await getStudentById(studentId);
      if (student == null) {
        throw Exception('Student not found');
      }

      final attendance = await getStudentAttendance(studentId);
      final grades = await getStudentGrades(studentId);

      // Calculate attendance statistics
      final totalDays = attendance.length;
      final presentDays = attendance.where((a) => a.status == 'present').length;
      final attendanceRate = totalDays > 0
          ? (presentDays / totalDays) * 100
          : 0;

      // Calculate grade statistics
      final totalGrades = grades.length;
      final totalScore = grades.fold(
        0.0,
        (double sum, grade) => sum + (grade.score / grade.maxScore) * 100,
      );
      final averageScore = totalGrades > 0 ? totalScore / totalGrades : 0.0;

      // Prepare recent records (last 5)
      final recentAttendance = attendance.take(5).toList();
      final recentGrades = grades.take(5).toList();

      // Generate evaluation
      final evaluation = _generateEvaluation(attendanceRate, averageScore);

      return StudentReport(
        student: student,
        attendanceStats: {
          'totalDays': totalDays,
          'presentDays': presentDays,
          'absentDays': totalDays - presentDays,
          'attendanceRate': attendanceRate,
        },
        gradeStats: {
          'totalGrades': totalGrades,
          'averageScore': averageScore,
          'highestScore': totalGrades > 0
              ? grades
                    .map((g) => (g.score / g.maxScore) * 100)
                    .reduce((a, b) => a > b ? a : b)
                    .toDouble()
              : 0.0,
          'lowestScore': totalGrades > 0
              ? grades
                    .map((g) => (g.score / g.maxScore) * 100)
                    .reduce((a, b) => a < b ? a : b)
                    .toDouble()
              : 0.0,
        },
        recentAttendance: recentAttendance,
        recentGrades: recentGrades,
        overallScore:
            (attendanceRate * 0.3) +
            (averageScore * 0.7), // 30% attendance, 70% grades
        evaluation: evaluation,
      );
    } catch (e) {
      _logger.severe('Error generating student report', e);
      rethrow;
    }
  }

  // Helper method to generate evaluation text
  String _generateEvaluation(num attendanceRate, num averageScore) {
    final attendanceText = attendanceRate >= 90
        ? 'ممتاز'
        : attendanceRate >= 80
        ? 'جيد جداً'
        : attendanceRate >= 70
        ? 'جيد'
        : 'ضعيف';

    final scoreText = averageScore >= 90
        ? 'ممتاز'
        : averageScore >= 80
        ? 'جيد جداً'
        : averageScore >= 70
        ? 'جيد'
        : 'ضعيف';

    return 'مستوى الحضور: $attendanceText، المستوى الأكاديمي: $scoreText';
  }

  // Generate reports for all students
  Future<List<StudentReport>> generateAllStudentReports() async {
    try {
      final students = await getAllStudents();
      final List<StudentReport> reports = [];

      for (final student in students) {
        try {
          final report = await generateStudentReport(student.id);
          reports.add(report);
        } catch (e) {
          // Skip students whose reports cannot be generated
          continue;
        }
      }

      return reports;
    } catch (e) {
      throw Exception('فشل في إنشاء تقارير الطلاب: $e');
    }
  }

  // Helper method to convert Student to Map
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
      'additionalInfo': student.additionalInfo != null
          ? jsonEncode(student.additionalInfo)
          : null,
    };
  }

  // Helper method to convert Map to Student
  Student _studentFromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      fullName: map['fullName'],
      studentId: map['studentId'],
      birthDate: DateTime.parse(map['birthDate']),
      gender: map['gender'],
      address: map['address'],
      phone: map['phone'],
      parentPhone: map['parentPhone'],
      schoolId: map['schoolId'],
      stageId: map['stageId'],
      classGroupId: map['classGroupId'],
      status: map['status'],
      photo: map['photo'],
      enrollmentDate: DateTime.parse(map['enrollmentDate']),
      additionalInfo:
          map['additionalInfo'] != null &&
              (map['additionalInfo'] as String).isNotEmpty
          ? jsonDecode(map['additionalInfo'] as String) as Map<String, dynamic>
          : null,
    );
  }

  // Helper method to convert Attendance to Map
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

  // Helper method to convert Map to Attendance
  Attendance _attendanceFromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'],
      studentId: map['studentId'],
      schoolId: map['schoolId'],
      date: DateTime.parse(map['date']),
      status: map['status'],
      notes: map['notes'],
      recordedBy: map['recordedBy'],
      recordedAt: DateTime.parse(map['recordedAt']),
      checkInTime: map['checkInTime'],
      checkOutTime: map['checkOutTime'],
      additionalData:
          map['additionalData'] != null &&
              (map['additionalData'] as String).isNotEmpty
          ? jsonDecode(map['additionalData'] as String) as Map<String, dynamic>
          : null,
    );
  }

  // Helper method to convert Grade to Map
  Map<String, dynamic> _gradeToMap(Grade grade) {
    return {
      'id': grade.id,
      'studentId': grade.studentId,
      'schoolId': grade.schoolId,
      'subject': grade.subject,
      'gradeType': grade.gradeType,
      'score': grade.score,
      'maxScore': grade.maxScore,
      'date': grade.date.toIso8601String(),
      'recordedBy': grade.recordedBy,
      'recordedAt': grade.recordedAt.toIso8601String(),
      'notes': grade.notes,
      'additionalData': grade.additionalData != null
          ? jsonEncode(grade.additionalData)
          : null,
    };
  }

  // Helper method to convert Map to Grade
  Grade _gradeFromMap(Map<String, dynamic> map) {
    return Grade(
      id: map['id'],
      studentId: map['studentId'],
      schoolId: map['schoolId'],
      subject: map['subject'],
      gradeType: map['gradeType'],
      score: (map['score'] as num).toDouble(),
      maxScore: (map['maxScore'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      recordedBy: map['recordedBy'],
      recordedAt: DateTime.parse(map['recordedAt']),
      notes: map['notes'],
      additionalData:
          map['additionalData'] != null &&
              (map['additionalData'] as String).isNotEmpty
          ? jsonDecode(map['additionalData'] as String) as Map<String, dynamic>
          : null,
    );
  }

  // Helper method to add demo attendance records
  Future<void> _addDemoAttendance(String student1Id, String student2Id) async {
    final now = DateTime.now();
    final attendanceList = [
      Attendance(
        id: const Uuid().v4(),
        studentId: student1Id,
        schoolId: '1',
        date: now.subtract(const Duration(days: 2)),
        status: 'present',
        notes: 'حضور عادي',
        recordedBy: 'system',
        recordedAt: now,
        checkInTime: '08:00',
        checkOutTime: '14:00',
        additionalData: {},
      ),
      Attendance(
        id: const Uuid().v4(),
        studentId: student2Id,
        schoolId: '1',
        date: now.subtract(const Duration(days: 2)),
        status: 'absent',
        notes: 'غياب بدون إذن',
        recordedBy: 'system',
        recordedAt: now,
        additionalData: {},
      ),
    ];

    for (final attendance in attendanceList) {
      await recordAttendance(attendance);
    }
  }

  // Helper method to add demo grade records
  Future<void> _addDemoGrades(String student1Id, String student2Id) async {
    final now = DateTime.now();
    final gradesList = [
      Grade(
        id: const Uuid().v4(),
        studentId: student1Id,
        schoolId: '1',
        subject: 'الرياضيات',
        gradeType: 'exam',
        score: 95.0,
        maxScore: 100.0,
        date: now.subtract(const Duration(days: 7)),
        recordedBy: 'system',
        recordedAt: now,
        notes: 'أداء ممتاز',
        additionalData: {},
      ),
      Grade(
        id: const Uuid().v4(),
        studentId: student2Id,
        schoolId: '1',
        subject: 'اللغة العربية',
        gradeType: 'exam',
        score: 88.0,
        maxScore: 100.0,
        date: now.subtract(const Duration(days: 7)),
        recordedBy: 'system',
        recordedAt: now,
        notes: 'أداء جيد',
        additionalData: {},
      ),
    ];

    for (final grade in gradesList) {
      await _addGrade(grade);
    }
  }

  // Helper method to add a grade
  Future<bool> _addGrade(Grade grade) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        tableGrades,
        _gradeToMap(grade),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      _logger.severe('Error adding grade', e);
      return false;
    }
  }

  // Public: Add a grade
  Future<bool> addGrade(Grade grade) async {
    return _addGrade(grade);
  }

  // Public: Update a grade
  Future<bool> updateGrade(Grade grade) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.update(
        tableGrades,
        _gradeToMap(grade),
        where: '$columnId = ?',
        whereArgs: [grade.id],
      );
      return count > 0;
    } catch (e) {
      _logger.severe('Error updating grade', e);
      return false;
    }
  }

  // Public: Delete a grade
  Future<bool> deleteGrade(String gradeId) async {
    try {
      final db = await _dbHelper.database;
      final count = await db.delete(
        tableGrades,
        where: '$columnId = ?',
        whereArgs: [gradeId],
      );
      return count > 0;
    } catch (e) {
      _logger.severe('Error deleting grade', e);
      return false;
    }
  }
}
