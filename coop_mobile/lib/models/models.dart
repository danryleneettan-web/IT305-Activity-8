class ChildModel {
  String name;
  int age;

  ChildModel({
    required this.name,
    required this.age,
  });

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      name: json['name']?.toString() ?? json['child_name']?.toString() ?? '',
      age: int.tryParse(json['age']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
    };
  }
}

class MemberModel {
  String id;
  String accountNumber;
  // Kept as a transient onboarding field only; never serialized to Firebase.
  String password;
  String authUid;
  String email;
  bool forcePasswordChange;
  String firstName;
  String lastName;
  String middleName;
  String extensionName;
  String civilStatus;
  String address;
  String contactNumber;
  String birthday;
  String occupation;
  String employer;
  String employerAddress;
  String spouseName;
  String spouseOccupation;
  String spouseEmployer;
  String fatherName;
  String motherName;
  String referenceOne;
  String referenceTwo;
  String photo;
  String createdAt;
  String updatedAt;
  List<ChildModel> children;

  MemberModel({
    required this.id,
    required this.accountNumber,
    required this.password,
    this.authUid = '',
    this.email = '',
    this.forcePasswordChange = true,
    required this.firstName,
    required this.lastName,
    this.middleName = '',
    this.extensionName = '',
    required this.civilStatus,
    required this.address,
    required this.contactNumber,
    required this.birthday,
    this.occupation = '',
    this.employer = '',
    this.employerAddress = '',
    this.spouseName = '',
    this.spouseOccupation = '',
    this.spouseEmployer = '',
    this.fatherName = '',
    this.motherName = '',
    this.referenceOne = '',
    this.referenceTwo = '',
    this.photo = '',
    required this.createdAt,
    required this.updatedAt,
    List<ChildModel>? children,
  }) : children = children ?? [];

  String get fullName {
    final parts = [firstName, middleName, lastName, extensionName]
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return parts.join(' ');
  }

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l'.isEmpty ? 'CC' : '$f$l';
  }

  factory MemberModel.fromJson(Map<String, dynamic> json, [String? keyId]) {
    final childrenList = <ChildModel>[];
    if (json['children'] != null) {
      if (json['children'] is Map) {
        (json['children'] as Map).forEach((_, val) {
          if (val is Map<String, dynamic>) {
            childrenList.add(ChildModel.fromJson(val));
          } else if (val is Map) {
            childrenList.add(ChildModel.fromJson(Map<String, dynamic>.from(val)));
          }
        });
      } else if (json['children'] is List) {
        for (final item in json['children']) {
          if (item is Map) {
            childrenList.add(ChildModel.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
    }

    return MemberModel(
      id: keyId ?? json['id']?.toString() ?? json['accountNumber']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? json['account_number']?.toString() ?? '',
      password: '',
      authUid: json['authUid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      forcePasswordChange: json['forcePasswordChange'] == true ||
          json['force_password_change'] == true ||
          json['force_password_change'] == 1 ||
          json['forcePasswordChange'] == 1,
      firstName: json['firstName']?.toString() ?? json['first_name']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? json['last_name']?.toString() ?? '',
      middleName: json['middleName']?.toString() ?? json['middle_name']?.toString() ?? '',
      extensionName: json['extensionName']?.toString() ?? json['extension_name']?.toString() ?? '',
      civilStatus: json['civilStatus']?.toString() ?? json['civil_status']?.toString() ?? 'Single',
      address: json['address']?.toString() ?? '',
      contactNumber: json['contactNumber']?.toString() ?? json['contact_number']?.toString() ?? '',
      birthday: json['birthday']?.toString() ?? '',
      occupation: json['occupation']?.toString() ?? '',
      employer: json['employer']?.toString() ?? '',
      employerAddress: json['employerAddress']?.toString() ?? json['employer_address']?.toString() ?? '',
      spouseName: json['spouseName']?.toString() ?? json['spouse_name']?.toString() ?? '',
      spouseOccupation: json['spouseOccupation']?.toString() ?? json['spouse_occupation']?.toString() ?? '',
      spouseEmployer: json['spouseEmployer']?.toString() ?? json['spouse_employer']?.toString() ?? '',
      fatherName: json['fatherName']?.toString() ?? json['father_name']?.toString() ?? '',
      motherName: json['motherName']?.toString() ?? json['mother_name']?.toString() ?? '',
      referenceOne: json['referenceOne']?.toString() ?? json['reference_one']?.toString() ?? '',
      referenceTwo: json['referenceTwo']?.toString() ?? json['reference_two']?.toString() ?? '',
      photo: json['photo']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      children: childrenList,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> childrenMap = {};
    for (int i = 0; i < children.length; i++) {
      childrenMap['child_$i'] = children[i].toJson();
    }

    return {
      'accountNumber': accountNumber,
      'authUid': authUid,
      'email': email,
      'forcePasswordChange': forcePasswordChange,
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'extensionName': extensionName,
      'civilStatus': civilStatus,
      'address': address,
      'contactNumber': contactNumber,
      'birthday': birthday,
      'occupation': occupation,
      'employer': employer,
      'employerAddress': employerAddress,
      'spouseName': spouseName,
      'spouseOccupation': spouseOccupation,
      'spouseEmployer': spouseEmployer,
      'fatherName': fatherName,
      'motherName': motherName,
      'referenceOne': referenceOne,
      'referenceTwo': referenceTwo,
      'photo': photo,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'children': childrenMap,
    };
  }
}

class SurveyQuestion {
  String id;
  int order;
  String text;
  String type; // 'rating', 'yes_no', 'multiple_choice', 'short_answer'
  bool isRequired;
  List<String> choices;

  SurveyQuestion({
    required this.id,
    required this.order,
    required this.text,
    required this.type,
    this.isRequired = true,
    List<String>? choices,
  }) : choices = choices ?? [];

  factory SurveyQuestion.fromJson(Map<String, dynamic> json, [String? keyId]) {
    final list = <String>[];
    if (json['choices'] != null) {
      if (json['choices'] is List) {
        for (final item in json['choices']) {
          list.add(item.toString());
        }
      } else if (json['choices'] is Map) {
        (json['choices'] as Map).values.forEach((v) => list.add(v.toString()));
      }
    }

    return SurveyQuestion(
      id: keyId ?? json['id']?.toString() ?? '',
      order: int.tryParse(json['order']?.toString() ?? '0') ?? 0,
      text: json['text']?.toString() ?? json['question_text']?.toString() ?? '',
      type: json['type']?.toString() ?? json['question_type']?.toString() ?? 'multiple_choice',
      isRequired: json['isRequired'] == true || json['is_required'] == 1 || json['is_required'] == true,
      choices: list,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'text': text,
      'type': type,
      'isRequired': isRequired,
      'choices': choices,
    };
  }
}

class SurveyModel {
  String id;
  String title;
  String description;
  String status; // 'draft', 'active', 'inactive'
  String opensAt;
  String closesAt;
  String createdBy;
  String createdAt;
  String updatedAt;
  List<SurveyQuestion> questions;

  SurveyModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.opensAt,
    required this.closesAt,
    this.createdBy = 'admin',
    required this.createdAt,
    required this.updatedAt,
    List<SurveyQuestion>? questions,
  }) : questions = questions ?? [];

  bool get isActive {
    if (status != 'active') return false;
    final now = DateTime.now();
    try {
      final open = DateTime.tryParse(opensAt);
      final close = DateTime.tryParse(closesAt);
      if (open != null && now.isBefore(open)) return false;
      if (close != null && now.isAfter(close)) return false;
    } catch (_) {}
    return true;
  }

  factory SurveyModel.fromJson(Map<String, dynamic> json, [String? keyId]) {
    final qList = <SurveyQuestion>[];
    if (json['questions'] != null) {
      if (json['questions'] is Map) {
        (json['questions'] as Map).forEach((qKey, val) {
          if (val is Map) {
            qList.add(SurveyQuestion.fromJson(Map<String, dynamic>.from(val), qKey.toString()));
          }
        });
      } else if (json['questions'] is List) {
        for (int i = 0; i < (json['questions'] as List).length; i++) {
          final item = json['questions'][i];
          if (item is Map) {
            qList.add(SurveyQuestion.fromJson(Map<String, dynamic>.from(item), 'q$i'));
          }
        }
      }
    }
    qList.sort((a, b) => a.order.compareTo(b.order));

    return SurveyModel(
      id: keyId ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      opensAt: json['opensAt']?.toString() ?? json['opens_at']?.toString() ?? '',
      closesAt: json['closesAt']?.toString() ?? json['closes_at']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? json['created_by']?.toString() ?? 'admin',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '',
      questions: qList,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> qMap = {};
    for (final q in questions) {
      qMap[q.id] = q.toJson();
    }

    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'opensAt': opensAt,
      'closesAt': closesAt,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'questions': qMap,
    };
  }
}

class SurveySubmission {
  String id;
  String surveyId;
  String memberId;
  String memberUid;
  String memberName;
  String submittedAt;
  Map<String, String> answers;

  SurveySubmission({
    required this.id,
    required this.surveyId,
    required this.memberId,
    this.memberUid = '',
    required this.memberName,
    required this.submittedAt,
    required this.answers,
  });

  factory SurveySubmission.fromJson(Map<String, dynamic> json, [String? keyId]) {
    final ansMap = <String, String>{};
    if (json['answers'] is Map) {
      (json['answers'] as Map).forEach((k, v) {
        ansMap[k.toString()] = v?.toString() ?? '';
      });
    }

    return SurveySubmission(
      id: keyId ?? json['id']?.toString() ?? '',
      surveyId: json['surveyId']?.toString() ?? json['survey_id']?.toString() ?? '',
      memberId: json['memberId']?.toString() ?? json['member_id']?.toString() ?? '',
      memberUid: json['memberUid']?.toString() ?? '',
      memberName: json['memberName']?.toString() ?? json['member_name']?.toString() ?? '',
      submittedAt: json['submittedAt']?.toString() ?? json['submitted_at']?.toString() ?? '',
      answers: ansMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surveyId': surveyId,
      'memberId': memberId,
      'memberUid': memberUid,
      'memberName': memberName,
      'submittedAt': submittedAt,
      'answers': answers,
    };
  }
}

class StaffModel {
  String username;
  String fullName;
  String password;
  String role;

  StaffModel({
    required this.username,
    required this.fullName,
    required this.password,
    this.role = 'staff',
  });

  factory StaffModel.fromJson(Map<String, dynamic> json, [String? keyUsername]) {
    return StaffModel(
      username: keyUsername ?? json['username']?.toString() ?? 'admin',
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString() ?? 'Administrator',
      password: '',
      role: json['role']?.toString() ?? 'staff',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'fullName': fullName,
      'role': role,
    };
  }
}
