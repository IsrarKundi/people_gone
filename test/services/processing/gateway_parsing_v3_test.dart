import 'package:flutter_test/flutter_test.dart';
import 'package:people_gone/services/processing/gateway_parsing.dart';
import 'package:people_gone/services/processing/processing_api.dart';

/// Contract v3 parsing (Phase A): belongings round-trip from the
/// analyse payload into the app model, with the safe-direction
/// fallbacks — an unknown tier parses as ambiguous (never silently
/// attached to a person), and a v2 payload parses to no belongings.
void main() {
  Map<String, dynamic> v3Proposal() => <String, dynamic>{
        'persons_detected': 13,
        'keeper_ids': <int>[0],
        'removed_ids': <int>[1, 2],
        'persons': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 0,
            'box': <int>[300, 100, 470, 900],
            'score': 0.97,
            'is_keeper': true,
          },
          <String, dynamic>{
            'id': 1,
            'box': <int>[100, 200, 260, 880],
            'score': 0.93,
            'is_keeper': false,
          },
          <String, dynamic>{
            'id': 2,
            'box': <int>[520, 180, 660, 870],
            'score': 0.91,
            'is_keeper': false,
          },
        ],
        'input_dimensions': <int>[900, 1600],
        'contract_version': 3,
        'belongings': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 0,
            'detected_class': 'handbag',
            'box': <int>[185, 743, 265, 876],
            'score': 0.807,
            'tier': 'attached',
            'person_id': 1,
          },
          <String, dynamic>{
            'id': 1,
            'detected_class': 'suitcase',
            'box': <int>[600, 900, 720, 1100],
            'score': 0.66,
            'tier': 'ambiguous',
            'person_id': null,
          },
        ],
      };

  test('v3 payload parses attached + ambiguous belongings', () {
    final proposal = gatewayProposalFromMap(v3Proposal(), '/tmp/photo.jpg');
    expect(proposal.persons, hasLength(3));
    expect(proposal.belongings, hasLength(2));

    final attached = proposal.belongings[0];
    expect(attached.id, 0);
    expect(attached.detectedClass, 'handbag');
    expect(attached.box, <int>[185, 743, 265, 876]);
    expect(attached.score, closeTo(0.807, 1e-9));
    expect(attached.tier, BelongingTier.attached);
    expect(attached.personId, 1);

    final ambiguous = proposal.belongings[1];
    expect(ambiguous.tier, BelongingTier.ambiguous);
    expect(ambiguous.personId, isNull);
  });

  test('unknown tier string parses as ambiguous (safe direction)', () {
    final items = gatewayParseBelongings(<dynamic>[
      <String, dynamic>{
        'id': 5,
        'detected_class': 'backpack',
        'box': <int>[0, 0, 10, 10],
        'score': 0.5,
        'tier': 'something_new',
        'person_id': 2,
      },
    ]);
    expect(items, hasLength(1));
    expect(items.single.tier, BelongingTier.ambiguous);
    // The person link is dropped with the tier: an unrecognised
    // attachment claim must not bind the item to a person.
    expect(items.single.personId, isNull);
  });

  test('v2 payload without belongings parses to an empty list', () {
    final map = v3Proposal()..remove('belongings');
    final proposal = gatewayProposalFromMap(map, '/tmp/p.jpg');
    expect(proposal.belongings, isEmpty);
    expect(gatewayParseBelongings(null), isEmpty);
    expect(gatewayParseBelongings('junk'), isEmpty);
  });

  test('malformed belonging entries are skipped, not fatal', () {
    final items = gatewayParseBelongings(<dynamic>[
      'not-a-map',
      <String, dynamic>{'id': 1}, // no box/class
      <String, dynamic>{
        'id': 2,
        'detected_class': 'umbrella',
        'box': <int>[1, 2, 3, 4],
        'score': 0.4,
        'tier': 'attached',
        'person_id': 0,
      },
    ]);
    expect(items, hasLength(1));
    expect(items.single.id, 2);
  });
}
