// ignore_for_file: omit_local_variable_types
import 'package:aggr/aggr.dart';

class RenderingBase<T extends Pixel> {
  /// Pixel Format
  T pixf;

  /// Create new Rendering Base from Pixel Format
  RenderingBase(this.pixf);

  List<int> as_bytes() {
    return pixf.as_bytes();
  }

  Future<void> to_file(String filename) async {
    await pixf.to_file(filename);
  }

  /// Set Image to a single color
  void clear(Rgba8 color) {
    pixf.fill(color);
  }

  /// Get Image size
  List<int> limits() {
    int w = pixf.width();
    int h = pixf.height();
    return [0, w - 1, 0, h - 1];
  }

  /// Blend a color along y-row from x1 to x2
  void blend_hline(int x1, int y, int x2, Color c, int cover) {
    final limits = this.limits();
    final xmin = limits[0];
    final xmax = limits[1];
    final ymin = limits[2];
    final ymax = limits[3];

    int startX = x1;
    int endX = x2;
    if (x2 > x1) {
      startX = x1;
      endX = x2;
    } else {
      startX = x2;
      endX = x1;
    }

    if (y > ymax || y < ymin || startX > xmax || endX < xmin) {
      return;
    }

    final clampedX1 = startX > xmin ? startX : xmin;
    final clampedX2 = endX < xmax ? endX : xmax;

    pixf.blend_hline(clampedX1, y, clampedX2 - clampedX1 + 1, c, cover);
  }

  /// Blend a color from (x,y) with variable covers horizontally
  void blend_solid_hspan<C extends Color>(
      int x, int y, int len, C c, List<int> covers) {
    final limits = this.limits();
    final xmin = limits[0];
    final xmax = limits[1];
    final ymin = limits[2];
    final ymax = limits[3];

    if (y > ymax || y < ymin) {
      return;
    }

    int currentX = x;
    int currentLen = len;
    int offset = 0;

    if (currentX < xmin) {
      currentLen -= xmin - currentX;
      if (currentLen <= 0) {
        return;
      }
      offset += xmin - currentX;
      currentX = xmin;
    }

    if (currentX + currentLen > xmax) {
      currentLen = xmax - currentX + 1;
      if (currentLen <= 0) {
        return;
      }
    }

    final coversWin =
        covers.sublist(offset, offset + currentLen.clamp(0, covers.length));
    assert(currentLen <= covers.sublist(offset).length);
    pixf.blend_solid_hspan(currentX, y, currentLen, c, coversWin);
  }

  /// Blend a color from (x,y) with variable covers vertically
  void blend_solid_vspan<C extends Color>(
      int x, int y, int len, C c, List<int> covers) {
    final limits = this.limits();
    final xmin = limits[0];
    final xmax = limits[1];
    final ymin = limits[2];
    final ymax = limits[3];

    if (x > xmax || x < xmin) {
      return;
    }

    int currentY = y;
    int currentLen = len;
    int offset = 0;

    if (currentY < ymin) {
      currentLen -= ymin - currentY;
      if (currentLen <= 0) {
        return;
      }
      offset += ymin - currentY;
      currentY = ymin;
    }

    if (currentY + currentLen > ymax) {
      currentLen = ymax - currentY + 1;
      if (currentLen <= 0) {
        return;
      }
    }

    final coversWin =
        covers.sublist(offset, offset + currentLen.clamp(0, covers.length));
    assert(currentLen <= covers.sublist(offset).length);
    pixf.blend_solid_vspan(x, currentY, currentLen, c, coversWin);
  }

  /// Blend multiple colors from (x,y) with variable covers vertically
  void blend_color_vspan(
      int x, int y, int len, List<Color> colors, List<int> covers, int cover) {
    final limits = this.limits();
    final xmin = limits[0];
    final xmax = limits[1];
    final ymin = limits[2];
    final ymax = limits[3];

    if (x > xmax || x < xmin) {
      return;
    }

    int currentY = y;
    int currentLen = len;
    int offset = 0;

    if (currentY < ymin) {
      currentLen -= ymin - currentY;
      if (currentLen <= 0) {
        return;
      }
      offset += ymin - currentY;
      currentY = ymin;
    }

    if (currentY + currentLen > ymax) {
      currentLen = ymax - currentY + 1;
      if (currentLen <= 0) {
        return;
      }
    }

    List<int> coversWin = covers.isEmpty
        ? []
        : covers.sublist(offset, offset + currentLen.clamp(0, covers.length));
    List<Color> colorsWin =
        colors.sublist(offset, offset + currentLen.clamp(0, colors.length));

    pixf.blend_color_vspan(
        x, currentY, currentLen, colorsWin, coversWin, cover);
  }

  /// Blend multiple colors from (x,y) with variable covers horizontally
  void blend_color_hspan<C extends Color>(
      int x, int y, int len, List<C> colors, List<int> covers, int cover) {
    final limits = this.limits();
    final xmin = limits[0];
    final xmax = limits[1];
    final ymin = limits[2];
    final ymax = limits[3];

    if (y > ymax || y < ymin) {
      return;
    }

    int currentX = x;
    int currentLen = len;
    int offset = 0;

    if (currentX < xmin) {
      currentLen -= xmin - currentX;
      if (currentLen <= 0) {
        return;
      }
      offset += xmin - currentX;
      currentX = xmin;
    }

    if (currentX + currentLen > xmax) {
      currentLen = xmax - currentX + 1;
      if (currentLen <= 0) {
        return;
      }
    }

    List<int> coversWin = covers.isEmpty
        ? []
        : covers.sublist(offset, offset + currentLen.clamp(0, covers.length));
    List<C> colorsWin =
        colors.sublist(offset, offset + currentLen.clamp(0, colors.length));

    pixf.blend_color_hspan(x, y, currentLen, colorsWin, coversWin, cover);
  }
}
