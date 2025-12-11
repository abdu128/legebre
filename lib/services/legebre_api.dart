import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../models/animal.dart';
import '../models/course.dart';
import '../models/feed_item.dart';
import '../models/user.dart';
import '../models/vet_drug.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_storage.dart';

class LegebreApi {
  LegebreApi({ApiClient? client, AuthStorage? storage})
    : _client = client ?? ApiClient(),
      _storage = storage ?? AuthStorage();

  final ApiClient _client;
  final AuthStorage _storage;

  Map<String, dynamic> _extractObject(
    dynamic response, {
    List<String> preferredKeys = const [],
  }) {
    if (response is Map<String, dynamic>) {
      for (final key in preferredKeys) {
        final value = response[key];
        if (value is Map<String, dynamic>) return value;
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is Map<String, dynamic>) return first;
        }
        if (value is Map) {
          final nested = _extractObject(value, preferredKeys: preferredKeys);
          if (nested.isNotEmpty) return nested;
        }
      }
      return response;
    }
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) return first;
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractList(
    dynamic response, {
    List<String> preferredKeys = const [],
  }) {
    if (response is List) {
      return response.whereType<Map<String, dynamic>>().toList();
    }
    if (response is Map<String, dynamic>) {
      for (final key in preferredKeys) {
        final value = response[key];
        if (value is List) {
          return value.whereType<Map<String, dynamic>>().toList();
        }
        if (value is Map<String, dynamic>) {
          final nested = _extractList(value, preferredKeys: preferredKeys);
          if (nested.isNotEmpty) return nested;
        }
      }
      for (final value in response.values) {
        if (value is List) {
          return value.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, String> _cleanFields(Map<String, String> fields) {
    final result = <String, String>{};
    fields.forEach((key, value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      result[key] = trimmed;
    });
    return result;
  }

  Future<http.MultipartFile> _fileFromXFile(
    XFile file, {
    String fieldName = 'photos',
  }) async {
    // Ensure backend sees a real image/* MIME type, not application/octet-stream
    final lower = file.path.toLowerCase();
    String subtype = 'jpeg';
    if (lower.endsWith('.png')) {
      subtype = 'png';
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      subtype = 'jpeg';
    }

    return http.MultipartFile.fromBytes(
      fieldName,
      await file.readAsBytes(),
      filename: file.name,
      contentType: MediaType('image', subtype),
    );
  }

  Future<void> _persistToken(String token) async {
    await _storage.saveToken(token);
    _client.cacheToken(token);
  }

  Future<(AppUser user, String token)> register({
    required String name,
    String? email,
    String? phone,
    String? whatsapp,
    required String password,
    String role = 'BUYER',
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'password': password,
      'role': role,
    };
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    if (whatsapp != null && whatsapp.isNotEmpty) {
      body['whatsapp'] = whatsapp;
    }

    final response = await _client.post(
      '/auth/register',
      body: body,
      authorized: false,
    );
    final token = response['token']?.toString();
    if (token == null) throw ApiException('Missing token from server');
    await _persistToken(token);
    final user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    return (user, token);
  }

  Future<(AppUser user, String token)> login({
    String? identifier,
    String? email,
    String? phone,
    required String password,
  }) async {
    final body = <String, dynamic>{'password': password};

    // Prefer the single identifier field from the UI
    if (identifier != null && identifier.trim().isNotEmpty) {
      final trimmed = identifier.trim();
      if (trimmed.contains('@')) {
        body['email'] = trimmed;
      } else {
        body['phone'] = trimmed;
      }
    } else {
      // Fallback to explicit email / phone params if provided
      if (email != null && email.trim().isNotEmpty) {
        body['email'] = email.trim();
      }
      if (phone != null && phone.trim().isNotEmpty) {
        body['phone'] = phone.trim();
      }
    }

    if (!body.containsKey('email') && !body.containsKey('phone')) {
      throw ApiException('Provide email or phone to login');
    }

    final response = await _client.post(
      '/auth/login',
      body: body,
      authorized: false,
    );
    final token = response['token']?.toString();
    if (token == null) throw ApiException('Missing token from server');
    await _persistToken(token);
    final user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    return (user, token);
  }

  Future<AppUser> getProfile() async {
    Future<AppUser> fetch(String path) async {
      final response = await _client.get(path, authorized: true);
      if (response is! Map<String, dynamic>) {
        throw ApiException('Invalid profile response');
      }
      return AppUser.fromJson(response);
    }

    try {
      return await fetch('/me');
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
    }

    return fetch('/users/me');
  }

  Future<AppUser> getSellerProfile(int id) async {
    final response = await _client.get('/users/$id');
    Map<String, dynamic> data = {};
    if (response is Map<String, dynamic>) {
      data = _extractObject(response, preferredKeys: const ['user', 'data']);
      if (data.isEmpty) data = response;
    }
    if (data.isEmpty) {
      throw ApiException('Invalid seller profile response');
    }
    return AppUser.fromJson(data);
  }

  Future<AppUser> updateProfile(Map<String, dynamic> fields) async {
    final response =
        await _client.put('/users/me', authorized: true, body: fields)
            as Map<String, dynamic>;
    return AppUser.fromJson(response);
  }

  Future<AppUser> updateProfilePhoto({XFile? file, String? photoUrl}) async {
    if (file == null && (photoUrl == null || photoUrl.isEmpty)) {
      throw ApiException('Provide a file or a photo url');
    }

    if (file != null) {
      final multipart = await _fileFromXFile(file, fieldName: 'photo');
      final response =
          await _client.uploadMultipart(
                '/users/me/photo',
                fields: const {},
                files: [multipart],
                authorized: true,
              )
              as Map<String, dynamic>;
      return AppUser.fromJson(response);
    } else {
      final response =
          await _client.put(
                '/users/me/photo',
                authorized: true,
                body: {'photoUrl': photoUrl},
              )
              as Map<String, dynamic>;
      return AppUser.fromJson(response);
    }
  }

  Future<List<Animal>> getAnimals({
    Map<String, dynamic>? filters,
    int limit = 20,
    int page = 1,
  }) async {
    final response = await _client.get(
      '/animals',
      query: {'limit': limit, 'page': page, if (filters != null) ...filters},
    );
    final items = _extractList(
      response,
      preferredKeys: const ['animals', 'data', 'results'],
    );
    return items.map(Animal.fromJson).toList();
  }

  Future<Animal> getAnimal(int id) async {
    final response = await _client.get('/animals/$id');
    final data = _extractObject(
      response,
      preferredKeys: const ['animal', 'data'],
    );
    return Animal.fromJson(data);
  }

  Future<Map<String, dynamic>> getAnimalContact(int id) async {
    final response = await _client.get('/contact/animals/$id');
    if (response is Map<String, dynamic>) return response;
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) return first;
    }
    throw ApiException('Unexpected contact response');
  }

  Future<Map<String, dynamic>> getFeedContact(int id) async {
    final response = await _client.get('/contact/feeds/$id');
    if (response is Map<String, dynamic>) return response;
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) return first;
    }
    throw ApiException('Unexpected contact response');
  }

  Future<Map<String, dynamic>> getVetDrugContact(int id) async {
    final response = await _client.get('/contact/vet-drugs/$id');
    if (response is Map<String, dynamic>) return response;
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) return first;
    }
    throw ApiException('Unexpected contact response');
  }

  Future<Map<String, dynamic>> logContactEvent({
    required String resourceType,
    required int resourceId,
    required String channel,
    String? message,
  }) async {
    final payload = <String, String>{
      'resourceType': resourceType,
      'resourceId': resourceId.toString(),
      'channel': channel,
    };
    if (message != null && message.trim().isNotEmpty) {
      payload['message'] = message.trim();
    }

    final response = await _client.post(
      '/contact/events',
      body: payload,
      authorized: true,
    );

    if (response is Map<String, dynamic>) return response;
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) return first;
    }
    return {'data': response};
  }

  Future<Animal> createAnimal({
    required Map<String, String> fields,
    List<XFile> photos = const [],
  }) async {
    final payload = _cleanFields(fields);
    if (photos.isEmpty) {
      final response = await _client.post(
        '/animals',
        body: payload,
        authorized: true,
      );
      final data = _extractObject(
        response,
        preferredKeys: const ['animal', 'data'],
      );
      return Animal.fromJson(data.isEmpty ? response : data);
    }

    final multipartFiles = <http.MultipartFile>[];
    for (final photo in photos) {
      multipartFiles.add(await _fileFromXFile(photo));
    }

    final response = await _client.uploadMultipart(
      '/animals',
      fields: payload,
      files: multipartFiles,
      authorized: true,
    );
    final data = _extractObject(
      response,
      preferredKeys: const ['animal', 'data'],
    );
    return Animal.fromJson(data.isEmpty ? response : data);
  }

  Future<Animal> updateAnimal(
    int id, {
    required Map<String, String> fields,
    List<XFile> newPhotos = const [],
  }) async {
    final payload = _cleanFields(fields);
    dynamic response;

    if (newPhotos.isEmpty) {
      response = await _client.put(
        '/animals/$id',
        body: payload,
        authorized: true,
      );
    } else {
      final files = <http.MultipartFile>[];
      for (final photo in newPhotos) {
        files.add(await _fileFromXFile(photo));
      }
      response = await _client.uploadMultipart(
        '/animals/$id',
        method: 'PUT',
        fields: payload,
        files: files,
        authorized: true,
      );
    }

    final data = _extractObject(
      response,
      preferredKeys: const ['animal', 'data'],
    );
    return Animal.fromJson(data.isEmpty ? response : data);
  }

  Future<void> deleteAnimal(int id) async {
    await _client.delete('/animals/$id', authorized: true);
  }

  Future<void> changeAnimalStatus(int id, String status) async {
    await _client.patch(
      '/animals/$id/status',
      body: {'status': status.toUpperCase()},
      authorized: true,
    );
  }

  Future<List<Animal>> getFavorites() async {
    final response = await _client.get('/favorites', authorized: true);
    final items = _extractList(
      response,
      preferredKeys: const ['favorites', 'animals', 'data'],
    );
    return items.map(Animal.fromJson).toList();
  }

  Future<void> addFavorite(int animalId) async {
    await _client.post(
      '/favorites',
      body: {'animalId': animalId},
      authorized: true,
    );
  }

  Future<void> removeFavorite(int animalId) async {
    await _client.delete('/favorites/$animalId', authorized: true);
  }

  Future<void> submitRating({
    required int sellerId,
    int? animalId,
    required int rating,
    String? comment,
  }) async {
    final body = {
      'sellerId': sellerId,
      'rating': rating,
      if (animalId != null) 'animalId': animalId,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    };
    await _client.post(
      '/ratings',
      body: body.map((key, value) => MapEntry(key, value.toString())),
      authorized: true,
    );
  }

  Future<List<Map<String, dynamic>>> getSellerRatings(int sellerId) async {
    final response = await _client.get('/ratings/seller/$sellerId');
    return _extractList(
      response,
      preferredKeys: const ['ratings', 'data', 'results'],
    );
  }

  Future<List<FeedItem>> getFeeds({
    Map<String, dynamic>? filters,
    int limit = 20,
    int page = 1,
  }) async {
    final response = await _client.get(
      '/feeds',
      query: {'limit': limit, 'page': page, if (filters != null) ...filters},
    );
    final items = _extractList(
      response,
      preferredKeys: const ['feeds', 'data', 'results'],
    );
    return items.map(FeedItem.fromJson).toList();
  }

  Future<FeedItem> getFeed(int id) async {
    final response = await _client.get('/feeds/$id');
    final data = _extractObject(
      response,
      preferredKeys: const ['feed', 'data'],
    );
    return FeedItem.fromJson(data.isEmpty ? response : data);
  }

  Future<FeedItem> createFeed({
    required Map<String, String> fields,
    List<XFile> photos = const [],
  }) {
    return saveFeed(fields: fields, photos: photos);
  }

  Future<FeedItem> updateFeed(
    int id, {
    required Map<String, String> fields,
    List<XFile> photos = const [],
  }) {
    return saveFeed(id: id, fields: fields, photos: photos, isUpdate: true);
  }

  Future<FeedItem> saveFeed({
    int? id,
    required Map<String, String> fields,
    List<XFile> photos = const [],
    bool isUpdate = false,
  }) async {
    final payload = _cleanFields(fields);
    final files = <http.MultipartFile>[];
    for (final photo in photos) {
      files.add(await _fileFromXFile(photo));
    }

    dynamic response;
    final path = id == null ? '/feeds' : '/feeds/$id';

    if (files.isEmpty) {
      response = isUpdate
          ? await _client.put(path, body: payload, authorized: true)
          : await _client.post(path, body: payload, authorized: true);
    } else {
      response = await _client.uploadMultipart(
        path,
        method: isUpdate ? 'PUT' : 'POST',
        fields: payload,
        files: files,
        authorized: true,
      );
    }

    final data = _extractObject(
      response,
      preferredKeys: const ['feed', 'data'],
    );
    return FeedItem.fromJson(data.isEmpty ? response : data);
  }

  Future<void> deleteFeed(int id) async {
    await _client.delete('/feeds/$id', authorized: true);
  }

  Future<void> changeFeedStatus(int id, String status) async {
    await _client.patch(
      '/feeds/$id/status',
      body: {'status': status.toUpperCase()},
      authorized: true,
    );
  }

  Future<List<VetDrug>> getVetDrugs({
    Map<String, dynamic>? filters,
    int limit = 20,
    int page = 1,
  }) async {
    final response = await _client.get(
      '/vet-drugs',
      query: {'limit': limit, 'page': page, if (filters != null) ...filters},
    );
    final items = _extractList(
      response,
      preferredKeys: const ['drugs', 'vetDrugs', 'data'],
    );
    return items.map(VetDrug.fromJson).toList();
  }

  Future<VetDrug> getVetDrug(int id) async {
    final response = await _client.get('/vet-drugs/$id');
    final data = _extractObject(
      response,
      preferredKeys: const ['drug', 'data'],
    );
    return VetDrug.fromJson(data.isEmpty ? response : data);
  }

  Future<VetDrug> createVetDrug({
    required Map<String, String> fields,
    XFile? photo,
  }) {
    return saveVetDrug(fields: fields, photo: photo);
  }

  Future<VetDrug> updateVetDrug(
    int id, {
    required Map<String, String> fields,
    XFile? photo,
  }) {
    return saveVetDrug(id: id, fields: fields, photo: photo, isUpdate: true);
  }

  Future<VetDrug> saveVetDrug({
    int? id,
    required Map<String, String> fields,
    XFile? photo,
    bool isUpdate = false,
  }) async {
    final payload = _cleanFields(fields);
    http.MultipartFile? file;
    if (photo != null) {
      file = await _fileFromXFile(photo);
    }

    dynamic response;
    final path = id == null ? '/vet-drugs' : '/vet-drugs/$id';

    if (file == null) {
      response = isUpdate
          ? await _client.put(path, body: payload, authorized: true)
          : await _client.post(path, body: payload, authorized: true);
    } else {
      response = await _client.uploadMultipart(
        path,
        method: isUpdate ? 'PUT' : 'POST',
        fields: payload,
        files: [file],
        authorized: true,
      );
    }

    final data = _extractObject(
      response,
      preferredKeys: const ['drug', 'data'],
    );
    return VetDrug.fromJson(data.isEmpty ? response : data);
  }

  Future<void> deleteVetDrug(int id) async {
    await _client.delete('/vet-drugs/$id', authorized: true);
  }

  Future<void> changeVetDrugStatus(int id, String status) async {
    await _client.patch(
      '/vet-drugs/$id/status',
      body: {'status': status.toUpperCase()},
      authorized: true,
    );
  }

  Future<List<Course>> getCourses({
    Map<String, dynamic>? filters,
    int limit = 20,
    int page = 1,
  }) async {
    final response = await _client.get(
      '/courses',
      query: {'limit': limit, 'page': page, if (filters != null) ...filters},
      authorized: true, // Now includes enrollment status if authenticated
    );
    final items = _extractList(
      response,
      preferredKeys: const ['courses', 'data', 'results'],
    );
    return items.map(Course.fromJson).toList();
  }

  Future<Course> getCourse(int id) async {
    final response = await _client.get(
      '/courses/$id',
      authorized: true, // Now includes enrollment status if authenticated
    );
    final data = _extractObject(
      response,
      preferredKeys: const ['course', 'data'],
    );
    return Course.fromJson(data.isEmpty ? response : data);
  }

  Future<Course> createCourse({
    required Map<String, String> fields,
    XFile? thumbnail,
  }) {
    return saveCourse(fields: fields, thumbnail: thumbnail);
  }

  Future<Course> updateCourse(
    int id, {
    required Map<String, String> fields,
    XFile? thumbnail,
  }) {
    return saveCourse(
      id: id,
      fields: fields,
      thumbnail: thumbnail,
      isUpdate: true,
    );
  }

  Future<Course> saveCourse({
    int? id,
    required Map<String, String> fields,
    XFile? thumbnail,
    bool isUpdate = false,
  }) async {
    final payload = _cleanFields(fields);
    http.MultipartFile? file;
    if (thumbnail != null) {
      file = await _fileFromXFile(thumbnail, fieldName: 'thumbnail');
    }

    dynamic response;
    final path = id == null ? '/courses' : '/courses/$id';

    if (file == null) {
      response = isUpdate
          ? await _client.put(path, body: payload, authorized: true)
          : await _client.post(path, body: payload, authorized: true);
    } else {
      response = await _client.uploadMultipart(
        path,
        method: isUpdate ? 'PUT' : 'POST',
        fields: payload,
        files: [file],
        authorized: true,
      );
    }

    final data = _extractObject(
      response,
      preferredKeys: const ['course', 'data'],
    );
    return Course.fromJson(data.isEmpty ? response : data);
  }

  Future<void> deleteCourse(int id) async {
    await _client.delete('/courses/$id', authorized: true);
  }

  Future<void> enrollInCourse(int id) async {
    await _client.post('/courses/$id/enroll', authorized: true);
  }

  Future<List<Course>> getUserEnrollments() async {
    final response = await _client.get(
      '/courses/user/enrollments',
      authorized: true,
    );
    final items = _extractList(
      response,
      preferredKeys: const ['enrollments', 'courses', 'data'],
    );
    return items.map(Course.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> getCourseVideos(int courseId) async {
    final response = await _client.get('/videos/course/$courseId');
    return _extractList(
      response,
      preferredKeys: const ['videos', 'data', 'results'],
    );
  }

  Future<Map<String, dynamic>> getVideo(int id) async {
    final response = await _client.get('/videos/$id');
    return _extractObject(response, preferredKeys: const ['video', 'data']);
  }

  Future<Map<String, dynamic>> saveVideo({
    int? id,
    required Map<String, dynamic> payload,
    bool isUpdate = false,
  }) async {
    final body = payload.map((key, value) => MapEntry(key, value.toString()));
    final path = id == null ? '/videos' : '/videos/$id';
    final response = isUpdate
        ? await _client.put(path, body: body, authorized: true)
        : await _client.post(path, body: body, authorized: true);
    return _extractObject(response, preferredKeys: const ['video', 'data']);
  }

  Future<Map<String, dynamic>> createVideo(Map<String, dynamic> payload) =>
      saveVideo(payload: payload);

  Future<Map<String, dynamic>> updateVideo(
    int id,
    Map<String, dynamic> payload,
  ) => saveVideo(id: id, payload: payload, isUpdate: true);

  Future<void> deleteVideo(int id) async {
    await _client.delete('/videos/$id', authorized: true);
  }

  Future<List<Map<String, dynamic>>> getTextLessons(int courseId) async {
    final response = await _client.get('/text-lessons/course/$courseId');
    return _extractList(
      response,
      preferredKeys: const ['lessons', 'textLessons', 'data'],
    );
  }

  Future<Map<String, dynamic>> getTextLesson(int id) async {
    final response = await _client.get('/text-lessons/$id');
    return _extractObject(response, preferredKeys: const ['lesson', 'data']);
  }

  Future<Map<String, dynamic>> saveTextLesson({
    int? id,
    required Map<String, dynamic> payload,
    bool isUpdate = false,
  }) async {
    final body = payload.map((key, value) => MapEntry(key, value.toString()));
    final path = id == null ? '/text-lessons' : '/text-lessons/$id';
    final response = isUpdate
        ? await _client.put(path, body: body, authorized: true)
        : await _client.post(path, body: body, authorized: true);
    return _extractObject(response, preferredKeys: const ['lesson', 'data']);
  }

  Future<Map<String, dynamic>> createTextLesson(Map<String, dynamic> payload) =>
      saveTextLesson(payload: payload);

  Future<Map<String, dynamic>> updateTextLesson(
    int id,
    Map<String, dynamic> payload,
  ) => saveTextLesson(id: id, payload: payload, isUpdate: true);

  Future<void> deleteTextLesson(int id) async {
    await _client.delete('/text-lessons/$id', authorized: true);
  }

  Future<List<Map<String, dynamic>>> getQuizzes(int courseId) async {
    final response = await _client.get(
      '/quizzes/course/$courseId',
      authorized: true, // Now includes completion status if authenticated
    );
    return _extractList(
      response,
      preferredKeys: const ['quizzes', 'data', 'results'],
    );
  }

  Future<Map<String, dynamic>> getQuiz(
    int id, {
    bool includeAnswers = false,
  }) async {
    final response = await _client.get(
      '/quizzes/$id',
      query: includeAnswers ? {'includeAnswers': 'true'} : null,
      authorized: true,
    );
    return _extractObject(response, preferredKeys: const ['quiz', 'data']);
  }

  Future<Map<String, dynamic>> saveQuiz({
    int? id,
    required Map<String, dynamic> payload,
    bool isUpdate = false,
  }) async {
    final body = payload.map((key, value) => MapEntry(key, value.toString()));
    final path = id == null ? '/quizzes' : '/quizzes/$id';
    final response = isUpdate
        ? await _client.put(path, body: body, authorized: true)
        : await _client.post(path, body: body, authorized: true);
    return _extractObject(response, preferredKeys: const ['quiz', 'data']);
  }

  Future<Map<String, dynamic>> createQuiz(Map<String, dynamic> payload) =>
      saveQuiz(payload: payload);

  Future<Map<String, dynamic>> updateQuiz(
    int id,
    Map<String, dynamic> payload,
  ) => saveQuiz(id: id, payload: payload, isUpdate: true);

  Future<Map<String, dynamic>> submitQuiz(
    int id, {
    required Map<String, dynamic> answers,
  }) async {
    final normalizedAnswers = answers.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final response = await _client.post(
      '/quizzes/$id/submit',
      body: {'answers': normalizedAnswers},
      authorized: true,
    );
    return _extractObject(response, preferredKeys: const ['attempt', 'data']);
  }

  Future<List<Map<String, dynamic>>> getQuizAttempts(int id) async {
    final response = await _client.get(
      '/quizzes/$id/attempts',
      authorized: true,
    );
    return _extractList(response, preferredKeys: const ['attempts', 'data']);
  }

  Future<Map<String, dynamic>> getQuizBestAttempt(int id) async {
    final response = await _client.get(
      '/quizzes/$id/best-attempt',
      authorized: true,
    );
    return _extractObject(
      response,
      preferredKeys: const ['attempt', 'bestAttempt', 'data'],
    );
  }

  Future<Map<String, dynamic>> getQuizAttemptDetails(int attemptId) async {
    final response = await _client.get(
      '/quizzes/attempts/$attemptId/details',
      authorized: true,
    );
    return _extractObject(
      response,
      preferredKeys: const ['attempt', 'data', 'details'],
    );
  }

  Future<Map<String, dynamic>> getQuizCompletionStatus(int id) async {
    final response = await _client.get(
      '/quizzes/$id/completion-status',
      authorized: true,
    );
    return _extractObject(
      response,
      preferredKeys: const ['status', 'completion', 'data'],
    );
  }

  Future<Map<String, dynamic>> getCourseProgress(int courseId) async {
    final response = await _client.get(
      '/courses/$courseId/progress',
      authorized: true,
    );
    return _extractObject(
      response,
      preferredKeys: const ['course', 'progress', 'data'],
    );
  }

  Future<List<Map<String, dynamic>>> getQuizQuestions(int quizId) async {
    final response = await _client.get('/quiz-questions/quiz/$quizId');
    return _extractList(response, preferredKeys: const ['questions', 'data']);
  }

  Future<Map<String, dynamic>> getQuizQuestion(int id) async {
    final response = await _client.get('/quiz-questions/$id');
    return _extractObject(response, preferredKeys: const ['question', 'data']);
  }

  Future<Map<String, dynamic>> saveQuizQuestion({
    int? id,
    required Map<String, dynamic> payload,
    bool isUpdate = false,
  }) async {
    final body = payload.map((key, value) => MapEntry(key, value.toString()));
    final path = id == null ? '/quiz-questions' : '/quiz-questions/$id';
    final response = isUpdate
        ? await _client.put(path, body: body, authorized: true)
        : await _client.post(path, body: body, authorized: true);
    return _extractObject(response, preferredKeys: const ['question', 'data']);
  }

  Future<Map<String, dynamic>> createQuizQuestion(
    Map<String, dynamic> payload,
  ) => saveQuizQuestion(payload: payload);

  Future<Map<String, dynamic>> updateQuizQuestion(
    int id,
    Map<String, dynamic> payload,
  ) => saveQuizQuestion(id: id, payload: payload, isUpdate: true);

  Future<void> deleteQuizQuestion(int id) async {
    await _client.delete('/quiz-questions/$id', authorized: true);
  }

  Future<Map<String, dynamic>> getCertificate(int id) async {
    final response = await _client.get('/certificates/$id', authorized: true);
    return _extractObject(
      response,
      preferredKeys: const ['certificate', 'data'],
    );
  }

  Future<List<Map<String, dynamic>>> getMyCertificates() async {
    final response = await _client.get(
      '/certificates/user/my-certificates',
      authorized: true,
    );
    return _extractList(
      response,
      preferredKeys: const ['certificates', 'data'],
    );
  }

  Future<Map<String, dynamic>> getCourseCertificate(int courseId) async {
    final response = await _client.get(
      '/certificates/course/$courseId',
      authorized: true,
    );
    return _extractObject(
      response,
      preferredKeys: const ['certificate', 'data'],
    );
  }

  Future<void> logout() async {
    await _storage.clearToken();
    _client.cacheToken(null);
  }
}
