import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';

class ProfileException implements Exception {
  const ProfileException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.dob,
    this.gender,
    this.cccd,
    this.permanentAddress,
    this.tier,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String? dob;
  final String? gender;
  final String? cccd;
  final String? permanentAddress;
  final String? tier;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      avatar: json['avatar']?.toString(),
      dob: json['dob']?.toString(),
      gender: json['gender']?.toString(),
      cccd: json['cccd']?.toString(),
      permanentAddress: json['permanentAddress']?.toString(),
      tier: json['tier']?.toString(),
    );
  }

  String get genderLabel {
    switch (gender) {
      case 'male': return 'Nam';
      case 'female': return 'Nữ';
      case 'other': return 'Khác';
      default: return gender ?? '';
    }
  }
}

class ProfileRepository {
  ProfileRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;

  Future<ProfileModel> getProfile() async {
    try {
      final res = await _api.get('/user/get-profile');
      final payload = _check(res.data);
      final data = payload['data'];
      if (data is Map<String, dynamic>) return ProfileModel.fromJson(data);
      throw const ProfileException('Phản hồi không hợp lệ.');
    } on DioException catch (e) {
      throw ProfileException(_extractMsg(e.response?.data) ?? 'Không tải được profile.');
    }
  }

  Future<ProfileModel> updateProfile({String? name, String? phone, String? avatar}) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (phone != null) body['phone'] = phone;
      if (avatar != null) body['avatar'] = avatar;
      final res = await _api.put('/user/update-profile', data: body);
      final payload = _check(res.data);
      final data = payload['data'];
      if (data is Map<String, dynamic>) return ProfileModel.fromJson(data);
      throw const ProfileException('Phản hồi không hợp lệ.');
    } on DioException catch (e) {
      throw ProfileException(_extractMsg(e.response?.data) ?? 'Cập nhật profile thất bại.');
    }
  }

  Future<String> uploadAvatar(Uint8List bytes, String filename) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final res = await _api.post('/upload', data: formData,
          options: Options(contentType: 'multipart/form-data'));
      final payload = _check(res.data);
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return data['url']?.toString() ?? data['path']?.toString() ?? '';
      }
      if (data is String) return data;
      throw const ProfileException('Upload failed.');
    } on DioException catch (e) {
      throw ProfileException(_extractMsg(e.response?.data) ?? 'Upload avatar thất bại.');
    }
  }

  Map<String, dynamic> _check(dynamic payload) {
    if (payload is! Map<String, dynamic>) throw const ProfileException('Phản hồi không hợp lệ.');
    if (payload['isSuccess'] == false) {
      final err = payload['error'];
      final msg = err is Map ? err['message']?.toString() : err?.toString();
      throw ProfileException(msg ?? 'Yêu cầu thất bại.');
    }
    return payload;
  }

  String? _extractMsg(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final err = data['error'];
    if (err is Map<String, dynamic>) return err['message']?.toString();
    if (err is String) return err;
    return data['message']?.toString();
  }
}

int _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
