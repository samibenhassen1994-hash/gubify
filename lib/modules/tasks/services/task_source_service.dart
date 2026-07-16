import '../models/task_model.dart';
import 'task_service.dart';

class TaskSourceService {
  TaskSourceService._();

  static final TaskSourceService instance =
      TaskSourceService._();

  Future<void> createManualTask(TaskModel task) async {
    await TaskService.instance.createTask(task);
  }
}