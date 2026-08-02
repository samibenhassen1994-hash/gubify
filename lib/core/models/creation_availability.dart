import 'package:cloud_firestore/cloud_firestore.dart';

const creationCooldownDuration = Duration(hours: 12);

enum CreationModuleType {
  task('task'),
  organizedEvent('organizedEvent'),
  proposal('proposal'),
  sharedBudget('sharedBudget');

  final String firestoreValue;

  const CreationModuleType(this.firestoreValue);
}

class CreationCooldown {
  final String creatorId;
  final CreationModuleType moduleType;
  final String deletedItemId;
  final String deletedBy;
  final Timestamp? deletedAt;
  final Timestamp availableAt;

  const CreationCooldown({
    required this.creatorId,
    required this.moduleType,
    required this.deletedItemId,
    required this.deletedBy,
    required this.deletedAt,
    required this.availableAt,
  });

  DateTime get effectiveAvailableAt {
    final serverDeletedAt = deletedAt;
    return serverDeletedAt == null
        ? availableAt.toDate()
        : serverDeletedAt.toDate().add(creationCooldownDuration);
  }

  bool get isActive => effectiveAvailableAt.isAfter(DateTime.now());

  Duration get remaining {
    final duration = effectiveAvailableAt.difference(DateTime.now());
    return duration.isNegative ? Duration.zero : duration;
  }
}

class CreationAvailability {
  final bool isUnlimited;
  final String? activeItemId;
  final String? activeItemTitle;
  final Object? activeItem;
  final CreationCooldown? cooldown;

  const CreationAvailability({
    this.isUnlimited = false,
    this.activeItemId,
    this.activeItemTitle,
    this.activeItem,
    this.cooldown,
  });

  bool get hasActiveItem => activeItemId != null;
  bool get isCoolingDown => cooldown?.isActive == true;
  bool get canCreate => isUnlimited || (!hasActiveItem && !isCoolingDown);
}

String formatCooldownRemaining(Duration duration) {
  if (duration <= Duration.zero) return '0m';

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${minutes == 0 ? 1 : minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
