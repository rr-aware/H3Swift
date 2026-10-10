#ifndef H3_EXTENDED_BRIDGE_H
#define H3_EXTENDED_BRIDGE_H
#include <stdint.h>
#include <stddef.h>

// Portable ABI; __uint128_t never crosses into Swift or a public C header.
typedef struct { uint64_t high, low; } H3ExtendedBits;
typedef struct { double lat, lng; } H3ExtendedLatLng;
typedef struct { int numVerts; H3ExtendedLatLng verts[10]; } H3ExtendedBoundary;

uint32_t h3eFromLatLng(H3ExtendedLatLng coordinate, int res, H3ExtendedBits *out);
uint32_t h3eToLatLng(H3ExtendedBits cell, H3ExtendedLatLng *out);
uint32_t h3eBoundary(H3ExtendedBits cell, H3ExtendedBoundary *out);
int h3eIsValid(H3ExtendedBits cell);
int h3eResolution(H3ExtendedBits cell);
int h3eIsPentagon(H3ExtendedBits cell);
uint32_t h3eParent(H3ExtendedBits cell, int res, H3ExtendedBits *out);
uint32_t h3eChildrenSize(H3ExtendedBits cell, int res, int64_t *out);
uint32_t h3eChildren(H3ExtendedBits cell, int res, H3ExtendedBits *out, int64_t capacity);
uint32_t h3eDiskSize(int k, int64_t *out);
uint32_t h3eDisk(H3ExtendedBits cell, int k, H3ExtendedBits *out, int *distances, int64_t capacity);
uint32_t h3eDistance(H3ExtendedBits a, H3ExtendedBits b, int64_t *out);
uint32_t h3eAreaKm2(H3ExtendedBits cell, double *out);
uint32_t h3eFromStandard(uint64_t cell, H3ExtendedBits *out);
uint32_t h3eToStandard(H3ExtendedBits cell, uint64_t *out);
uint32_t h3eParse(const char *str, H3ExtendedBits *out);
uint32_t h3eFormat(H3ExtendedBits cell, char *out, size_t size);
#endif
