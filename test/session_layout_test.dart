import 'package:flutter_test/flutter_test.dart';
import 'package:conduit/servers/session_layout.dart';

void main() {
  group('splitPane', () {
    test('splits a matching leaf horizontally', () {
      final result = splitPane(
        layout: const SessionLayoutLeaf('a'),
        focusedPaneId: 'a',
        newPaneId: 'b',
        axis: SessionSplitAxis.horizontal,
        splitId: 's1',
      );

      expect(result, isA<SessionLayoutSplit>());
      final split = result as SessionLayoutSplit;
      expect(split.axis, SessionSplitAxis.horizontal);
      expect(split.first, const SessionLayoutLeaf('a'));
      expect(split.second, const SessionLayoutLeaf('b'));
      expect(split.ratio, 0.5);
      expect(split.paneIds, ['a', 'b']);
    });

    test('splits nested leaf under existing split', () {
      final root = SessionLayoutSplit(
        id: 's1',
        axis: SessionSplitAxis.horizontal,
        first: const SessionLayoutLeaf('a'),
        second: const SessionLayoutLeaf('b'),
      );

      final result = splitPane(
        layout: root,
        focusedPaneId: 'b',
        newPaneId: 'c',
        axis: SessionSplitAxis.vertical,
        splitId: 's2',
      );

      final split = result as SessionLayoutSplit;
      expect(split.first, const SessionLayoutLeaf('a'));
      final nested = split.second as SessionLayoutSplit;
      expect(nested.axis, SessionSplitAxis.vertical);
      expect(nested.first, const SessionLayoutLeaf('b'));
      expect(nested.second, const SessionLayoutLeaf('c'));
    });

    test('leaves unmatched leaf unchanged', () {
      final result = splitPane(
        layout: const SessionLayoutLeaf('a'),
        focusedPaneId: 'x',
        newPaneId: 'b',
        axis: SessionSplitAxis.horizontal,
        splitId: 's1',
      );
      expect(result, const SessionLayoutLeaf('a'));
    });
  });

  group('applySplitRatio', () {
    test('updates matching split and clamps', () {
      final root = SessionLayoutSplit(
        id: 's1',
        axis: SessionSplitAxis.horizontal,
        first: const SessionLayoutLeaf('a'),
        second: const SessionLayoutLeaf('b'),
        ratio: 0.5,
      );

      final updated = applySplitRatio(root, 's1', 0.9) as SessionLayoutSplit;
      expect(updated.ratio, 0.85);

      final low = applySplitRatio(root, 's1', 0.05) as SessionLayoutSplit;
      expect(low.ratio, 0.15);
    });

    test('updates nested split by id', () {
      final root = SessionLayoutSplit(
        id: 's1',
        axis: SessionSplitAxis.horizontal,
        first: const SessionLayoutLeaf('a'),
        second: SessionLayoutSplit(
          id: 's2',
          axis: SessionSplitAxis.vertical,
          first: const SessionLayoutLeaf('b'),
          second: const SessionLayoutLeaf('c'),
        ),
      );

      final updated = applySplitRatio(root, 's2', 0.3) as SessionLayoutSplit;
      final nested = updated.second as SessionLayoutSplit;
      expect(nested.ratio, 0.3);
      expect(updated.ratio, 0.5);
    });
  });

  group('removePaneFromLayout', () {
    test('collapses split when one child is removed', () {
      final root = SessionLayoutSplit(
        id: 's1',
        axis: SessionSplitAxis.horizontal,
        first: const SessionLayoutLeaf('a'),
        second: const SessionLayoutLeaf('b'),
      );
      expect(removePaneFromLayout(root, 'a'), const SessionLayoutLeaf('b'));
      expect(removePaneFromLayout(root, 'b'), const SessionLayoutLeaf('a'));
    });

    test('returns null when last leaf is removed', () {
      expect(removePaneFromLayout(const SessionLayoutLeaf('a'), 'a'), isNull);
    });

    test('collapses nested splits', () {
      final root = SessionLayoutSplit(
        id: 's1',
        axis: SessionSplitAxis.horizontal,
        first: const SessionLayoutLeaf('a'),
        second: SessionLayoutSplit(
          id: 's2',
          axis: SessionSplitAxis.vertical,
          first: const SessionLayoutLeaf('b'),
          second: const SessionLayoutLeaf('c'),
        ),
      );
      final afterB = removePaneFromLayout(root, 'b') as SessionLayoutSplit;
      expect(afterB.first, const SessionLayoutLeaf('a'));
      expect(afterB.second, const SessionLayoutLeaf('c'));
    });
  });

  group('fallbackPaneAfterRemove', () {
    test('prefers sibling of removed pane', () {
      final root = SessionLayoutSplit(
        id: 's1',
        axis: SessionSplitAxis.horizontal,
        first: const SessionLayoutLeaf('a'),
        second: const SessionLayoutLeaf('b'),
      );
      expect(fallbackPaneAfterRemove(root, 'a', ['b', 'c']), 'b');
    });

    test('falls back to remaining list when layout empty', () {
      expect(fallbackPaneAfterRemove(null, 'a', ['b']), 'b');
      expect(fallbackPaneAfterRemove(null, 'a', []), isNull);
    });
  });
}
