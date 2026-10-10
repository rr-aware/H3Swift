/*
 * Modified in H3Swift for the optional 0...19 extended grid.
 * Copyright 2016-2018, 2020 Uber Technologies, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/** @file h3Index.h
 * @brief   H3Index functions.
 */

#ifndef H3INDEX_H
#define H3INDEX_H

#include "faceijk.h"
#include "h3api.h"

// define's of constants and macros for bitwise manipulation of H3Index's.

// The extended engine uses 57 digit bits, 7 base-cell bits, 5 resolution
// bits, 3 reserved bits, 4 mode bits, and one high bit (77 meaningful bits).
#ifdef H3_EXTENDED
#define H3_NUM_BITS 128
#define H3_MAX_OFFSET 76
#define H3_MODE_OFFSET 72
#define H3_BC_OFFSET 57
#define H3_RES_OFFSET 64
#define H3_RESERVED_OFFSET 69
#define H3_RES_MASK ((H3Index)31 << H3_RES_OFFSET)
#else
#define H3_NUM_BITS 64
#define H3_MAX_OFFSET 63
#define H3_MODE_OFFSET 59
#define H3_BC_OFFSET 45
#define H3_RES_OFFSET 52
#define H3_RESERVED_OFFSET 56
#define H3_RES_MASK ((H3Index)15 << H3_RES_OFFSET)
#endif

/** The number of bits in a single H3 resolution digit. */
#define H3_PER_DIGIT_OFFSET 3

/** 1 in the highest bit, 0's everywhere else. */
#define H3_HIGH_BIT_MASK ((H3Index)(1) << H3_MAX_OFFSET)

/** 0 in the highest bit, 1's everywhere else. */
#define H3_HIGH_BIT_MASK_NEGATIVE (~H3_HIGH_BIT_MASK)

/** 1's in the 4 mode bits, 0's everywhere else. */
#define H3_MODE_MASK ((H3Index)(15) << H3_MODE_OFFSET)

/** 0's in the 4 mode bits, 1's everywhere else. */
#define H3_MODE_MASK_NEGATIVE (~H3_MODE_MASK)

/** 1's in the 7 base cell bits, 0's everywhere else. */
#define H3_BC_MASK ((H3Index)(127) << H3_BC_OFFSET)

/** 0's in the 7 base cell bits, 1's everywhere else. */
#define H3_BC_MASK_NEGATIVE (~H3_BC_MASK)

/** 0's in the resolution bits, 1's everywhere else. */
#define H3_RES_MASK_NEGATIVE (~H3_RES_MASK)

/** 1's in the 3 reserved bits, 0's everywhere else. */
#define H3_RESERVED_MASK ((H3Index)(7) << H3_RESERVED_OFFSET)

/** 0's in the 3 reserved bits, 1's everywhere else. */
#define H3_RESERVED_MASK_NEGATIVE (~H3_RESERVED_MASK)

/** 1's in the 3 bits of last resolution digit, 0's everywhere else. */
#define H3_DIGIT_MASK ((H3Index)(7))

/** 0's in the 7 base cell bits, 1's everywhere else. */
#define H3_DIGIT_MASK_NEGATIVE (~H3_DIGIT_MASK)

/**
 * H3 index with mode 0, res 0, base cell 0, and 7 for all index digits.
 * Typically used to initialize the creation of an H3 cell index, which
 * expects all direction digits to be 7 beyond the cell's resolution.
 */
#define H3_INIT (((H3Index)1 << (3 * MAX_H3_RES)) - 1)

/**
 * Gets the highest bit of the H3 index.
 */
#define H3_GET_HIGH_BIT(h3) ((int)((((h3)&H3_HIGH_BIT_MASK) >> H3_MAX_OFFSET)))

/**
 * Sets the highest bit of the h3 to v.
 */
#define H3_SET_HIGH_BIT(h3, v)                 \
    (h3) = (((h3)&H3_HIGH_BIT_MASK_NEGATIVE) | \
            (((H3Index)(v)) << H3_MAX_OFFSET))

/**
 * Gets the integer mode of h3.
 */
#define H3_GET_MODE(h3) ((int)((((h3)&H3_MODE_MASK) >> H3_MODE_OFFSET)))

/**
 * Sets the integer mode of h3 to v.
 */
#define H3_SET_MODE(h3, v) \
    (h3) = (((h3)&H3_MODE_MASK_NEGATIVE) | (((H3Index)(v)) << H3_MODE_OFFSET))

/**
 * Gets the integer base cell of h3.
 */
#define H3_GET_BASE_CELL(h3) ((int)((((h3)&H3_BC_MASK) >> H3_BC_OFFSET)))

/**
 * Sets the integer base cell of h3 to bc.
 */
#define H3_SET_BASE_CELL(h3, bc) \
    (h3) = (((h3)&H3_BC_MASK_NEGATIVE) | (((H3Index)(bc)) << H3_BC_OFFSET))

/**
 * Gets the integer resolution of h3.
 */
#define H3_GET_RESOLUTION(h3) ((int)((((h3)&H3_RES_MASK) >> H3_RES_OFFSET)))

/**
 * Sets the integer resolution of h3.
 */
#define H3_SET_RESOLUTION(h3, res) \
    (h3) = (((h3)&H3_RES_MASK_NEGATIVE) | (((H3Index)(res)) << H3_RES_OFFSET))

/**
 * Gets the resolution res integer digit (0-7) of h3.
 */
#define H3_GET_INDEX_DIGIT(h3, res)                                        \
    ((Direction)((((h3) >> ((MAX_H3_RES - (res)) * H3_PER_DIGIT_OFFSET)) & \
                  H3_DIGIT_MASK)))

/**
 * Sets a value in the reserved space. Setting to non-zero may produce invalid
 * indexes.
 */
#define H3_SET_RESERVED_BITS(h3, v)            \
    (h3) = (((h3)&H3_RESERVED_MASK_NEGATIVE) | \
            (((H3Index)(v)) << H3_RESERVED_OFFSET))

/**
 * Gets a value in the reserved space. Should always be zero for valid indexes.
 */
#define H3_GET_RESERVED_BITS(h3) \
    ((int)((((h3)&H3_RESERVED_MASK) >> H3_RESERVED_OFFSET)))

/**
 * Sets the resolution res digit of h3 to the integer digit (0-7)
 */
#define H3_SET_INDEX_DIGIT(h3, res, digit)                                  \
    (h3) = (((h3) & ~((H3_DIGIT_MASK                                        \
                       << ((MAX_H3_RES - (res)) * H3_PER_DIGIT_OFFSET)))) | \
            (((H3Index)(digit))                                            \
             << ((MAX_H3_RES - (res)) * H3_PER_DIGIT_OFFSET)))

void setH3Index(H3Index *h, int res, int baseCell, Direction initDigit);
int isResolutionClassIII(int r);

// Internal functions

int _h3ToFaceIjkWithInitializedFijk(H3Index h, FaceIJK *fijk);
H3Error _h3ToFaceIjk(H3Index h, FaceIJK *fijk);
H3Index _faceIjkToH3(const FaceIJK *fijk, int res);
Direction _h3LeadingNonZeroDigit(H3Index h);
H3Index _h3RotatePent60ccw(H3Index h);
H3Index _h3RotatePent60cw(H3Index h);
H3Index _h3Rotate60ccw(H3Index h);
H3Index _h3Rotate60cw(H3Index h);
DECLSPEC H3Index _zeroIndexDigits(H3Index h, int start, int end);

#endif
