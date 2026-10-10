#include "namespace.h"
#include "h3Index.h"
#include "h3extended.h"
#include <stdlib.h>

static H3Index unpack(H3ExtendedBits b) {
    return ((H3Index)b.high << 64) | b.low;
}
static H3ExtendedBits pack(H3Index h) {
    return (H3ExtendedBits){(uint64_t)(h >> 64), (uint64_t)h};
}
#define VALIDATE(h) if (!H3_EXPORT(isValidCell)(h)) return E_CELL_INVALID

uint32_t h3eFromLatLng(H3ExtendedLatLng coordinate, int res, H3ExtendedBits *out) {
    LatLng g = {coordinate.lat, coordinate.lng};
    H3Index h = 0;
    H3Error err = H3_EXPORT(latLngToCell)(&g, res, &h);
    if (!err) *out = pack(h);
    return err;
}
uint32_t h3eToLatLng(H3ExtendedBits cell, H3ExtendedLatLng *out) {
    H3Index h = unpack(cell); VALIDATE(h);
    LatLng g;
    H3Error err = H3_EXPORT(cellToLatLng)(h, &g);
    if (!err) *out = (H3ExtendedLatLng){g.lat, g.lng};
    return err;
}
uint32_t h3eBoundary(H3ExtendedBits cell, H3ExtendedBoundary *out) {
    H3Index h = unpack(cell); VALIDATE(h);
    CellBoundary b;
    H3Error err = H3_EXPORT(cellToBoundary)(h, &b);
    if (!err) {
        out->numVerts = b.numVerts;
        for (int i = 0; i < b.numVerts; i++)
            out->verts[i] = (H3ExtendedLatLng){b.verts[i].lat, b.verts[i].lng};
    }
    return err;
}
int h3eIsValid(H3ExtendedBits cell) { return H3_EXPORT(isValidCell)(unpack(cell)); }
int h3eResolution(H3ExtendedBits cell) { return H3_GET_RESOLUTION(unpack(cell)); }
int h3eIsPentagon(H3ExtendedBits cell) {
    return h3eIsValid(cell) && H3_EXPORT(isPentagon)(unpack(cell));
}
uint32_t h3eParent(H3ExtendedBits cell, int res, H3ExtendedBits *out) {
    H3Index h = unpack(cell); VALIDATE(h);
    H3Index parent;
    H3Error err = H3_EXPORT(cellToParent)(h, res, &parent);
    if (!err) *out = pack(parent);
    return err;
}
uint32_t h3eChildrenSize(H3ExtendedBits cell, int res, int64_t *out) {
    H3Index h = unpack(cell); VALIDATE(h);
    return H3_EXPORT(cellToChildrenSize)(h, res, out);
}
uint32_t h3eChildren(H3ExtendedBits cell, int res, H3ExtendedBits *out, int64_t capacity) {
    int64_t count;
    H3Error err = h3eChildrenSize(cell, res, &count);
    if (err) return err;
    if (capacity < count || (uint64_t)count > SIZE_MAX / sizeof(H3Index)) return E_MEMORY_BOUNDS;
    H3Index *cells = calloc((size_t)count, sizeof(H3Index));
    if (!cells) return E_MEMORY_ALLOC;
    err = H3_EXPORT(cellToChildren)(unpack(cell), res, cells);
    if (!err) for (int64_t i = 0; i < count; i++) out[i] = pack(cells[i]);
    free(cells);
    return err;
}
uint32_t h3eDiskSize(int k, int64_t *out) { return H3_EXPORT(maxGridDiskSize)(k, out); }
uint32_t h3eDisk(H3ExtendedBits cell, int k, H3ExtendedBits *out, int *distances, int64_t capacity) {
    H3Index h = unpack(cell); VALIDATE(h);
    int64_t count;
    H3Error err = h3eDiskSize(k, &count);
    if (err) return err;
    if (capacity < count || (uint64_t)count > SIZE_MAX / sizeof(H3Index)) return E_MEMORY_BOUNDS;
    H3Index *cells = calloc((size_t)count, sizeof(H3Index));
    if (!cells) return E_MEMORY_ALLOC;
    err = H3_EXPORT(gridDiskDistances)(h, k, cells, distances);
    if (!err) for (int64_t i = 0; i < count; i++) out[i] = pack(cells[i]);
    free(cells);
    return err;
}
uint32_t h3eDistance(H3ExtendedBits a, H3ExtendedBits b, int64_t *out) {
    H3Index x = unpack(a), y = unpack(b); VALIDATE(x); VALIDATE(y);
    return H3_EXPORT(gridDistance)(x, y, out);
}
uint32_t h3eAreaKm2(H3ExtendedBits cell, double *out) {
    H3Index h = unpack(cell); VALIDATE(h);
    return H3_EXPORT(cellAreaKm2)(h, out);
}
uint32_t h3eFromStandard(uint64_t cell, H3ExtendedBits *out) {
    // Reject all modes except cells, including the standard high bit.
    if ((cell >> 56) != 8) return E_CELL_INVALID;
    H3Index h = H3_INIT;
    H3_SET_MODE(h, H3_CELL_MODE);
    H3_SET_RESOLUTION(h, (cell >> 52) & 15);
    H3_SET_BASE_CELL(h, (cell >> 45) & 127);
    for (int r = 1; r <= 15; r++) H3_SET_INDEX_DIGIT(h, r, (cell >> (3 * (15-r))) & 7);
    VALIDATE(h);
    *out = pack(h);
    return E_SUCCESS;
}
uint32_t h3eToStandard(H3ExtendedBits cell, uint64_t *out) {
    H3Index h = unpack(cell); VALIDATE(h);
    int res = H3_GET_RESOLUTION(h);
    if (res > 15) return E_RES_DOMAIN;
    uint64_t standard = UINT64_C(1) << 59;
    standard |= (uint64_t)res << 52;
    standard |= (uint64_t)H3_GET_BASE_CELL(h) << 45;
    for (int r = 1; r <= 15; r++) standard |= (uint64_t)H3_GET_INDEX_DIGIT(h, r) << (3 * (15-r));
    *out = standard;
    return E_SUCCESS;
}
uint32_t h3eParse(const char *str, H3ExtendedBits *out) {
    H3Index h;
    H3Error err = H3_EXPORT(stringToH3)(str, &h);
    if (err) return err;
    VALIDATE(h);
    *out = pack(h);
    return E_SUCCESS;
}
uint32_t h3eFormat(H3ExtendedBits cell, char *out, size_t size) {
    H3Index h = unpack(cell); VALIDATE(h);
    return H3_EXPORT(h3ToString)(h, out, size);
}
