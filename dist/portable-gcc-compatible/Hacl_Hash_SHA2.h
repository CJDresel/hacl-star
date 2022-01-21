/* MIT License
 *
 * Copyright (c) 2016-2020 INRIA, CMU and Microsoft Corporation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */


#ifndef __Hacl_Hash_SHA2_H
#define __Hacl_Hash_SHA2_H

#if defined(__cplusplus)
extern "C" {
#endif

#include "evercrypt_targetconfig.h"
#include "libintvector.h"
#include "kremlin/internal/types.h"
#include "kremlin/lowstar_endianness.h"
#include <string.h>
#include "kremlin/internal/target.h"


#include "Hacl_Kremlib.h"

/* SNIPPET_START: Hacl_Hash_SHA2_update_multi_224 */

void Hacl_Hash_SHA2_update_multi_224(uint32_t *s, uint8_t *blocks, uint32_t n_blocks);

/* SNIPPET_END: Hacl_Hash_SHA2_update_multi_224 */

/* SNIPPET_START: Hacl_Hash_SHA2_update_multi_256 */

void Hacl_Hash_SHA2_update_multi_256(uint32_t *s, uint8_t *blocks, uint32_t n_blocks);

/* SNIPPET_END: Hacl_Hash_SHA2_update_multi_256 */

/* SNIPPET_START: Hacl_Hash_SHA2_update_multi_384 */

void Hacl_Hash_SHA2_update_multi_384(uint64_t *s, uint8_t *blocks, uint32_t n_blocks);

/* SNIPPET_END: Hacl_Hash_SHA2_update_multi_384 */

/* SNIPPET_START: Hacl_Hash_SHA2_update_multi_512 */

void Hacl_Hash_SHA2_update_multi_512(uint64_t *s, uint8_t *blocks, uint32_t n_blocks);

/* SNIPPET_END: Hacl_Hash_SHA2_update_multi_512 */

/* SNIPPET_START: Hacl_Hash_SHA2_update_last_224 */

void
Hacl_Hash_SHA2_update_last_224(
  uint32_t *s,
  uint64_t prev_len,
  uint8_t *input,
  uint32_t input_len
);

/* SNIPPET_END: Hacl_Hash_SHA2_update_last_224 */

/* SNIPPET_START: Hacl_Hash_SHA2_update_last_256 */

void
Hacl_Hash_SHA2_update_last_256(
  uint32_t *s,
  uint64_t prev_len,
  uint8_t *input,
  uint32_t input_len
);

/* SNIPPET_END: Hacl_Hash_SHA2_update_last_256 */

/* SNIPPET_START: Hacl_Hash_SHA2_update_last_384 */

void
Hacl_Hash_SHA2_update_last_384(
  uint64_t *s,
  FStar_UInt128_uint128 prev_len,
  uint8_t *input,
  uint32_t input_len
);

/* SNIPPET_END: Hacl_Hash_SHA2_update_last_384 */

/* SNIPPET_START: Hacl_Hash_SHA2_update_last_512 */

void
Hacl_Hash_SHA2_update_last_512(
  uint64_t *s,
  FStar_UInt128_uint128 prev_len,
  uint8_t *input,
  uint32_t input_len
);

/* SNIPPET_END: Hacl_Hash_SHA2_update_last_512 */

/* SNIPPET_START: Hacl_Hash_SHA2_hash_224 */

void Hacl_Hash_SHA2_hash_224(uint8_t *input, uint32_t input_len, uint8_t *dst);

/* SNIPPET_END: Hacl_Hash_SHA2_hash_224 */

/* SNIPPET_START: Hacl_Hash_SHA2_hash_256 */

void Hacl_Hash_SHA2_hash_256(uint8_t *input, uint32_t input_len, uint8_t *dst);

/* SNIPPET_END: Hacl_Hash_SHA2_hash_256 */

/* SNIPPET_START: Hacl_Hash_SHA2_hash_384 */

void Hacl_Hash_SHA2_hash_384(uint8_t *input, uint32_t input_len, uint8_t *dst);

/* SNIPPET_END: Hacl_Hash_SHA2_hash_384 */

/* SNIPPET_START: Hacl_Hash_SHA2_hash_512 */

void Hacl_Hash_SHA2_hash_512(uint8_t *input, uint32_t input_len, uint8_t *dst);

/* SNIPPET_END: Hacl_Hash_SHA2_hash_512 */

#if defined(__cplusplus)
}
#endif

#define __Hacl_Hash_SHA2_H_DEFINED
#endif
