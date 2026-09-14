import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/repositories/gub_deletion_repository.dart';

void main() {
  final cases = <GubDeletionPhase, List<GubDeletionPhase>>{
    GubDeletionPhase.preparing: GubDeletionPhase.values,
    GubDeletionPhase.nestedCollections: const [
      GubDeletionPhase.nestedCollections,
      GubDeletionPhase.directCollections,
      GubDeletionPhase.userCopies,
      GubDeletionPhase.finalizing,
    ],
    GubDeletionPhase.directCollections: const [
      GubDeletionPhase.directCollections,
      GubDeletionPhase.userCopies,
      GubDeletionPhase.finalizing,
    ],
    GubDeletionPhase.userCopies: const [
      GubDeletionPhase.userCopies,
      GubDeletionPhase.finalizing,
    ],
    GubDeletionPhase.finalizing: const [GubDeletionPhase.finalizing],
  };

  for (final entry in cases.entries) {
    test('resume from ${entry.key.name} runs only monotonic phases', () {
      expect(
        GubDeletionRepository.phasesToRunFromForTesting(entry.key),
        entry.value,
      );
    });
  }
}
