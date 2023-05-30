import 'dart:async';

import 'database.dart';
import 'localstore/localstore.dart';
import 'models.dart';

typedef JsonMap = Map<String, dynamic>;

final _illegalPathCharacters = RegExp(r'[\\/:*?"<>|]');

/// Interface for the persistent storage used to back the downloader
///
/// Defines 'store', 'retrieve', 'retrieveAll' and 'remove' methods for:
/// - [TaskRecord]s, keyed by taskId
/// - paused [Task]s, keyed by taskId
/// - modified [Task]s, keyed by taskId
/// - [ResumeData], keyed by taskId
///
/// Each of the objects has a toJsonMap method and can be created using
/// fromJsonMap (use .createFromJsonMap for [Task] objects)
///
/// Also defined methods to allow migration from one database version to another
abstract interface class PersistentStorage {
  /// Store a [TaskRecord], keyed by taskId
  ///
  /// Returns true if successful
  Future<bool> storeTaskRecord(TaskRecord record);

  /// Retrieve [TaskRecord] with [taskId], or null if not found
  Future<TaskRecord?> retrieveTaskRecord(String taskId);

  /// Retrieve all modified tasks
  Future<List<TaskRecord>> retrieveAllTaskRecords();

  /// Remove [TaskRecord] with [taskId] from storage. If null, remove all
  Future<void> removeTaskRecord(String? taskId);

  /// Store a paused [task], keyed by taskId
  ///
  /// Returns true if successful
  Future<bool> storePausedTask(Task task);

  /// Retrieve paused [Task] with [taskId], or null if not found
  Future<Task?> retrievePausedTask(String taskId);

  /// Retrieve all paused [Task]
  Future<List<Task>> retrieveAllPausedTasks();

  /// Remove paused [Task] with [taskId] from storage. If null, remove all
  Future<void> removePausedTask(String? taskId);

  /// Store a modified [task], keyed by taskId
  ///
  /// Returns true if successful
  Future<bool> storeModifiedTask(Task task);

  /// Retrieve modified [Task] with [taskId], or null if not found
  Future<Task?> retrieveModifiedTask(String taskId);

  /// Retrieve all modified [Task]
  Future<List<Task>> retrieveAllModifiedTasks();

  /// Remove modified [Task] with [taskId] from storage. If null, remove all
  Future<void> removeModifiedTask(String? taskId);

  /// Store [ResumeData], keyed by its taskId
  ///
  /// Returns true if successful
  Future<bool> storeResumeData(ResumeData resumeData);

  /// Retrieve [ResumeData] with [taskId], or null if not found
  Future<ResumeData?> retrieveResumeData(String taskId);

  /// Retrieve all [ResumeData]
  Future<List<ResumeData>> retrieveAllResumeData();

  /// Remove [ResumeData] with [taskId] from storage. If null, remove all
  Future<void> removeResumeData(String? taskId);

  /// Name and version number for this type of persistent storage
  ///
  /// Used for database migration: this is the version represented by the code
  (String, int) get currentDatabaseVersion;

  /// Name and version number for database as stored
  ///
  /// Used for database migration, may be 'older' than the code version
  Future<(String, int)> get storedDatabaseVersion;

  /// Migrate the data from this name and version to the current
  /// name and version, as returned by [currentDatabaseVersion]
  ///
  /// Returns true if successful. If not successful, the old data
  /// may not have been migrated, but the new version will still work
  Future<bool> migrate((String, int) from);
}

/// Default implementation of [PersistentStorage] using Localstore package
class LocalStorePersistentStorage implements PersistentStorage {
  final _db = Localstore.instance;

  static const taskRecordsPath = 'backgroundDownloaderTaskRecords';
  static const resumeDataPath = 'backgroundDownloaderResumeData';
  static const pausedTasksPath = 'backgroundDownloaderPausedTasks';
  static const modifiedTasksPath = 'backgroundDownloaderModifiedTasks';
  static const metaDataCollection = 'backgroundDownloaderDatabase';

  /// Stores [JsonMap] formatted [document] in [collection] keyed under [identifier]
  Future<bool> store(
      JsonMap document, String collection, String identifier) async {
    await _db.collection(collection).doc(identifier).set(document);
    return true;
  }

  /// Returns [document] stored in [collection] under key [identifier]
  /// as a [JsonMap], or null if not found
  Future<JsonMap?> retrieve(String collection, String identifier) =>
      _db.collection(collection).doc(identifier).get();

  /// Returns all documents in collection as a [JsonMap] keyed by the
  /// document identifier, with the value a [JsonMap] representing the document
  Future<JsonMap> retrieveAll(String collection) async {
    return await _db.collection(collection).get() ?? {};
  }

  /// Removes document with [identifier] from [collection]
  ///
  /// If [identifier] is null, removes all documents in the [collection]
  Future<void> remove(String collection, [String? identifier]) async {
    if (identifier == null) {
      await _db.collection(collection).delete();
    } else {
      await _db.collection(collection).doc(identifier).delete();
    }
  }


  /// Returns possibly modified id, safe for storing in the localStore
  String _safeId(String id) => id.replaceAll(_illegalPathCharacters, '_');

  /// Returns possibly modified id, safe for storing in the localStore, or null
  /// if [id] is null
  String? _optionalSafeId(String? id) =>
      id?.replaceAll(_illegalPathCharacters, '_');

  @override
  // TODO: implement currentDatabaseVersion
  (String, int) get currentDatabaseVersion => throw UnimplementedError();

  @override
  Future<bool> migrate((String, int) from) {
    // TODO: implement migrate
    throw UnimplementedError();
  }

  @override
  Future<void> removeModifiedTask(String? taskId) =>
      remove(modifiedTasksPath, _optionalSafeId(taskId));

  @override
  Future<void> removePausedTask(String? taskId) =>
      remove(pausedTasksPath, _optionalSafeId(taskId));

  @override
  Future<void> removeResumeData(String? taskId) =>
      remove(resumeDataPath, _optionalSafeId(taskId));

  @override
  Future<void> removeTaskRecord(String? taskId) =>
      remove(taskRecordsPath, _optionalSafeId(taskId));

  @override
  Future<List<Task>> retrieveAllModifiedTasks() async {
    final jsonMaps = await retrieveAll(modifiedTasksPath);
    return jsonMaps.values
        .map((e) => Task.createFromJsonMap(e))
        .toList(growable: false);
  }

  @override
  Future<List<Task>> retrieveAllPausedTasks() async {
    final jsonMaps = await retrieveAll(pausedTasksPath);
    return jsonMaps.values
        .map((e) => Task.createFromJsonMap(e))
        .toList(growable: false);
  }

  @override
  Future<List<ResumeData>> retrieveAllResumeData() async {
    final jsonMaps = await retrieveAll(resumeDataPath);
    return jsonMaps.values
        .map((e) => ResumeData.fromJsonMap(e))
        .toList(growable: false);
  }

  @override
  Future<List<TaskRecord>> retrieveAllTaskRecords() async {
    final jsonMaps = await retrieveAll(taskRecordsPath);
    return jsonMaps.values
        .map((e) => TaskRecord.fromJsonMap(e))
        .toList(growable: false);
  }

  @override
  Future<Task?> retrieveModifiedTask(String taskId) async {
    return switch (await retrieve(modifiedTasksPath, _safeId(taskId))) {
      var jsonMap? => Task.createFromJsonMap(jsonMap),
      _ => null
    };
  }

  @override
  Future<Task?> retrievePausedTask(String taskId) async {
    return switch (await retrieve(pausedTasksPath, _safeId(taskId))) {
      var jsonMap? => Task.createFromJsonMap(jsonMap),
      _ => null
    };
  }

  @override
  Future<ResumeData?> retrieveResumeData(String taskId) async {
    return switch (await retrieve(resumeDataPath, _safeId(taskId))) {
      var jsonMap? => ResumeData.fromJsonMap(jsonMap),
      _ => null
    };
  }

  @override
  Future<TaskRecord?> retrieveTaskRecord(String taskId) async {
    return switch (await retrieve(taskRecordsPath, _safeId(taskId))) {
      var jsonMap? => TaskRecord.fromJsonMap(jsonMap),
      _ => null
    };
  }

  @override
  Future<bool> storeModifiedTask(Task task) =>
      store(task.toJsonMap(), modifiedTasksPath, _safeId(task.taskId));

  @override
  Future<bool> storePausedTask(Task task) =>
      store(task.toJsonMap(), pausedTasksPath, _safeId(task.taskId));

  @override
  Future<bool> storeResumeData(ResumeData resumeData) =>
      store(resumeData.toJsonMap(), resumeDataPath, _safeId(resumeData.taskId));

  @override
  Future<bool> storeTaskRecord(TaskRecord record) =>
      store(record.toJsonMap(), taskRecordsPath, _safeId(record.taskId));

  @override
  Future<(String, int)> get storedDatabaseVersion async {
    final metaData =
        await _db.collection(metaDataCollection).doc('metaData').get();
    return ('Localstore', metaData?['version'] as int? ?? 0);
  }
}
