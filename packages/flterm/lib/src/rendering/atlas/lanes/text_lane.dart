import 'dart:math' as math;
import 'dart:ui';

import '../atlas_entry.dart';
import 'paragraph_lane.dart';

/// Rasterizes font-backed text glyphs into the text atlas.
class TextLane extends ParagraphLane {
  TextLane({super.initialSize, super.maxSize}) : super(entryLane: .text);

  @override
  void paintPendingParagraph(
    Canvas canvas,
    Paragraph paragraph,
    AtlasEntry entry,
    double widthScale,
    double heightScale,
    Offset paintOffset,
  ) {
    final offset = Offset(
      entry.srcLeft + paintOffset.dx,
      entry.srcTop + paintOffset.dy,
    );
    if (widthScale == 1.0 && heightScale == 1.0) {
      canvas.drawParagraph(paragraph, offset);
    } else {
      canvas.translate(offset.dx, offset.dy);
      canvas.scale(widthScale, heightScale);
      canvas.drawParagraph(paragraph, Offset.zero);
    }
  }

  /// Builds a paragraph for [text], packs it into the atlas, and returns
  /// an [AtlasEntry] with its source coordinates.
  ///
  /// The glyph is not composited into the atlas image until [ensureImage]
  /// is called. [span] controls how many cell widths the glyph occupies
  /// (2 for wide/CJK characters).
  AtlasEntry rasterizeText(
    String text, {
    required bool bold,
    required bool italic,
    int span = 1,
    double sourcePadding = 0.0,
  }) {
    final pxCellWidth = (this.pxCellWidth * span).ceil().toDouble();
    final pxHeight = pxCellHeight.ceil().toDouble();

    // The sprite is positioned at the cell origin; the overhang width
    // overlaps into the adjacent cell's space without shifting the glyph.
    final overhang = italic ? pxItalicOverhang : 0.0;
    final pxWidth = pxCellWidth + overhang;

    final paragraph = buildParagraph(
      text,
      bold: bold,
      italic: italic,
      size: pxFontSize,
      width: double.infinity,
    );

    final textWidth = paragraph.maxIntrinsicWidth;
    final textHeight = paragraph.height;
    var widthScale = 1.0;
    var heightScale = 1.0;
    var bearingX = 0.0;
    var bearingY = pxBaseline - paragraph.alphabeticBaseline;
    if (span > 1) {
      // Wide (CJK) glyphs keep their full height and are squeezed
      // horizontally into the two-cell budget, or centered when narrower.
      if (textWidth > pxCellWidth) {
        widthScale = pxCellWidth / textWidth;
      } else if (textWidth > 0.0) {
        bearingX = (pxCellWidth - textWidth) / 2;
      }
    } else if (textWidth > pxWidth || textHeight > pxHeight) {
      // Single-width glyphs drawn larger than their cell — Nerd Font icons
      // and fallback symbols whose ink exceeds the monospace advance — are
      // scaled uniformly to fit, centered horizontally, and kept anchored
      // to the baseline so they stop being cropped at the cell edge. The
      // budget includes the italic overhang, so slanted glyphs keep using
      // their overlap allowance instead of shrinking.
      final scale = math.min(
        textWidth > 0.0 ? pxWidth / textWidth : 1.0,
        textHeight > 0.0 ? pxHeight / textHeight : 1.0,
      );
      widthScale = heightScale = scale;
      bearingX = math.max(0.0, (pxCellWidth - textWidth * scale) / 2);
      bearingY = (pxBaseline - paragraph.alphabeticBaseline * scale).clamp(
        0.0,
        math.max(0.0, pxHeight - textHeight * scale),
      );
    }
    final paintOffset = Offset(
      sourcePadding + bearingX,
      sourcePadding + bearingY,
    );
    late final AtlasEntry entry;
    try {
      entry = allocate(
        width: pxWidth + sourcePadding * 2,
        height: pxHeight + sourcePadding * 2,
        bearingX: -sourcePadding,
        bearingY: -sourcePadding,
      );
    } catch (_) {
      paragraph.dispose();
      rethrow;
    }

    addPendingParagraph(
      paragraph,
      entry,
      widthScale: widthScale,
      heightScale: heightScale,
      paintOffset: paintOffset,
    );
    return entry;
  }
}
