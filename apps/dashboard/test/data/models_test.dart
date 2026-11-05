import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/data/models.dart';

void main() {
  group('slugify', () {
    test('lowercases and joins words with dashes', () {
      expect(slugify('HIMATIF ITB 2026'), 'himatif-itb-2026');
      expect(slugify('  Komunitas  Kopi & Kode! '), 'komunitas-kopi-kode');
    });

    test('caps length at 40 without a trailing dash', () {
      final slug = slugify('${'a' * 39} bcd');
      expect(slug.length, lessThanOrEqualTo(40));
      expect(slug.endsWith('-'), isFalse);
    });

    test('output passes the organization ID rule', () {
      for (final name in ['HIMATIF ITB', 'BEM KM 2026', 'Ormawa X']) {
        expect(Organization.slugError(slugify(name)), isNull, reason: name);
      }
    });
  });

  group('Organization validation', () {
    test('rejects short names and bad IDs', () {
      expect(Organization.nameError('X'), isNotNull);
      expect(Organization.nameError('HIMATIF'), isNull);
      expect(Organization.slugError('Bad Slug'), isNotNull);
      expect(Organization.slugError('-starts-with-dash'), isNotNull);
      expect(Organization.slugError('a'), isNotNull);
    });
  });

  group('EventStatus.canBecome matches firestore.rules', () {
    const d = EventStatus.draft, a = EventStatus.active, c = EventStatus.completed;

    test('allowed moves', () {
      expect(d.canBecome(a), isTrue);
      expect(a.canBecome(d), isTrue);
      expect(a.canBecome(c), isTrue);
      for (final s in EventStatus.values) {
        expect(s.canBecome(s), isTrue);
      }
    });

    test('blocked moves', () {
      expect(d.canBecome(c), isFalse);
      expect(c.canBecome(a), isFalse);
      expect(c.canBecome(d), isFalse);
    });

    test('unknown status values parse as draft', () {
      expect(EventStatus.parse('archived'), d);
      expect(EventStatus.parse('active'), a);
    });
  });

  group('EventDraft validation', () {
    test('title is required and at most 120 characters', () {
      expect(EventDraft.titleError('   '), isNotNull);
      expect(EventDraft.titleError('x' * 121), isNotNull);
      expect(EventDraft.titleError('Tech Talk'), isNull);
    });

    test('capacity is empty or a whole number from 1', () {
      expect(EventDraft.capacityError(''), isNull);
      expect(EventDraft.capacityError('150'), isNull);
      expect(EventDraft.capacityError('0'), isNotNull);
      expect(EventDraft.capacityError('1.5'), isNotNull);
      expect(EventDraft.capacityError('many'), isNotNull);
      expect(EventDraft.parseCapacity(' '), isNull);
      expect(EventDraft.parseCapacity('40'), 40);
    });
  });
}
