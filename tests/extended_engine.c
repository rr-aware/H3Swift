// Direct C regression tests, intended to run with ASan and UBSan.
#include "h3extended.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

static int same(H3ExtendedBits a, H3ExtendedBits b) {
    return a.high == b.high && a.low == b.low;
}
static void checkCell(H3ExtendedBits cell) {
    assert(h3eIsValid(cell));
    int res = h3eResolution(cell);
    H3ExtendedLatLng center;
    H3ExtendedBits back;
    assert(!h3eToLatLng(cell, &center));
    assert(!h3eFromLatLng(center, res, &back));
    assert(same(cell, back));
    H3ExtendedBoundary boundary;
    assert(!h3eBoundary(cell, &boundary));
    assert(boundary.numVerts >= 5 && boundary.numVerts <= 10);
    for (int i = 0; i < boundary.numVerts; i++) {
        assert(isfinite(boundary.verts[i].lat));
        assert(isfinite(boundary.verts[i].lng));
    }
    double area;
    assert(!h3eAreaKm2(cell, &area));
    assert(isfinite(area) && area > 0);
    char string[33];
    assert(!h3eFormat(cell, string, sizeof(string)));
    assert(!h3eParse(string, &back));
    assert(same(cell, back));
    assert(h3eFormat(cell, string, 1) == 14);
}
int main(void) {
    for (int base = 0; base < 122; base++) {
        uint64_t standard = (UINT64_C(1) << 59) | (UINT64_C(15) << 52) | ((uint64_t)base << 45);
        H3ExtendedBits parent;
        assert(!h3eFromStandard(standard, &parent));
        uint64_t restored;
        assert(!h3eToStandard(parent, &restored) && restored == standard);
        for (int res = 16; res <= 19; res++) {
            int64_t count;
            assert(!h3eChildrenSize(parent, res, &count));
            assert(count == (h3eIsPentagon(parent) ? 6 : 7));
            H3ExtendedBits children[7];
            assert(h3eChildren(parent, res, children, count - 1) == 14);
            assert(!h3eChildren(parent, res, children, count));
            for (int i = 0; i < count; i++) {
                checkCell(children[i]);
                H3ExtendedBits ancestor;
                assert(!h3eParent(children[i], res - 1, &ancestor));
                assert(same(ancestor, parent));
            }
            parent = children[0]; // central child, including pentagons
            H3ExtendedBits disk[19];
            int distances[19] = {0};
            assert(!h3eDisk(parent, 2, disk, distances, 19));
            for (int i = 0; i < 19; i++) if (disk[i].high || disk[i].low) checkCell(disk[i]);
        }
    }
    // Deterministic worldwide samples, with exact/near poles and seam points.
    uint64_t random = 42;
    for (int i = 0; i < 10000; i++) {
        random = random * UINT64_C(6364136223846793005) + 1;
        double lat = ((double)(random >> 11) / 9007199254740992.0 - 0.5) * 3.141592653589793;
        random = random * UINT64_C(6364136223846793005) + 1;
        double lng = ((double)(random >> 11) / 9007199254740992.0 - 0.5) * 6.283185307179586;
        if (i < 100) lat = (i & 1 ? 1 : -1) * (1.5707963267948966 - (i / 2) * 1e-10);
        H3ExtendedBits cell;
        assert(!h3eFromLatLng((H3ExtendedLatLng){lat, lng}, 16 + i % 4, &cell));
        checkCell(cell);
    }
    int64_t count;
    assert(!h3eDiskSize(675244997, &count));
    assert(count == INT64_C(3) * 675244997 * 675244998 + 1);
    assert(!h3eDiskSize(675244998, &count));
    assert(count == INT64_C(1367867422244777162));
    assert(!h3eDiskSize(INT32_MAX, &count));
    assert(count == INT64_C(1367867422244777162));
    H3ExtendedBits invalid = {0, 0};
    assert(h3eFromLatLng((H3ExtendedLatLng){0, 0}, 20, &invalid) == 4);
    assert(h3eParse("100000000000000000000000000000000", &invalid));
    puts("Extended engine: geometry, hierarchy, serialization, buffer bounds and global samples passed.");
}
