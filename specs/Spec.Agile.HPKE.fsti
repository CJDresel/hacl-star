module Spec.Agile.HPKE

open FStar.Mul
open Lib.IntTypes
open Lib.RawIntTypes
open Lib.Sequence
open Lib.ByteSequence

module DH = Spec.Agile.DH
//module DHKEM = Spec.Agile.DHKEM
module AEAD = Spec.Agile.AEAD
module Hash = Spec.Agile.Hash
module HKDF = Spec.Agile.HKDF

#set-options "--z3rlimit 20 --fuel 0 --ifuel 1"

let is_ciphersuite = function
  | DH.DH_Curve25519, Hash.SHA2_256, AEAD.AES128_GCM,        Hash.SHA2_256
  | DH.DH_Curve25519, Hash.SHA2_256, AEAD.CHACHA20_POLY1305, Hash.SHA2_256
  | DH.DH_P256,       Hash.SHA2_256, AEAD.AES128_GCM,        Hash.SHA2_256
  | DH.DH_P256,       Hash.SHA2_256, AEAD.CHACHA20_POLY1305, Hash.SHA2_256 -> true
  | DH.DH_Curve25519, Hash.SHA2_256, AEAD.CHACHA20_POLY1305, Hash.SHA2_512 -> true
  | _,_,_,_ -> false

let ciphersuite = cs:(DH.algorithm & Hash.algorithm & AEAD.alg & Hash.algorithm){is_ciphersuite cs}

// TODO rename to dh_of_cs or kemdh or dhkem
let curve_of_cs (cs:ciphersuite) : DH.algorithm =
  let (c,_,_,_) = cs in c

let kem_hash_of_cs (cs:ciphersuite) : Hash.algorithm =
  let (_,h,_,_) = cs in h

let aead_of_cs (cs:ciphersuite) : AEAD.alg =
  let (_,_,a,_) = cs in a

let hash_of_cs (cs:ciphersuite) : Hash.algorithm =
  let (_,_,_,h) = cs in h

/// Constants sizes

inline_for_extraction
let size_aead_nonce (cs:ciphersuite): (n:size_nat{AEAD.iv_length (aead_of_cs cs) n}) =
  assert_norm (8 * 12 <= pow2 64 - 1);
  12

inline_for_extraction
let size_aead_key (cs:ciphersuite): size_nat = AEAD.key_length (aead_of_cs cs)

inline_for_extraction
let size_aead_tag (cs:ciphersuite): size_nat = AEAD.tag_length (aead_of_cs cs)

inline_for_extraction
let size_dh_key (cs:ciphersuite): size_nat = DH.size_key (curve_of_cs cs)

inline_for_extraction
let size_dh_public (cs:ciphersuite): size_nat = match curve_of_cs cs with
  | DH.DH_Curve25519 -> DH.size_public DH.DH_Curve25519
  | DH.DH_P256 -> DH.size_public DH.DH_P256 + 1 // Need the additional byte for representation

inline_for_extraction
let size_kem_kdf (cs:ciphersuite): size_nat = Hash.size_hash (kem_hash_of_cs cs)

inline_for_extraction
let size_kem_key (cs:ciphersuite): size_nat = Hash.size_hash (kem_hash_of_cs cs)

inline_for_extraction
let size_kdf (cs:ciphersuite): size_nat = Hash.size_hash (hash_of_cs cs)

// TODO This could be refined depending on the underlying hash function?
inline_for_extraction
let max_psk (cs:ciphersuite): size_nat = pow2 16 - 1

// TODO rename? length of what? plaintext, right?
inline_for_extraction
let max_length (cs:ciphersuite):size_nat = AEAD.max_length (aead_of_cs cs)

// TODO This could be refined depending on the underlying hash function?
inline_for_extraction
let max_pskID (cs:ciphersuite):size_nat = pow2 16 - 1

// TODO This could be refined depending on the underlying hash function?
inline_for_extraction
let max_info (cs:ciphersuite):size_nat = pow2 16 - 1

// TODO This could be refined depending on the underlying hash function?
inline_for_extraction
let max_exp_ctx: size_nat = pow2 16 - 1

let max_seq (cs:ciphersuite): nat = pow2 (8*(size_aead_nonce cs)) - 1


/// Types

type key_dh_public_s (cs:ciphersuite) = lbytes (size_dh_public cs)
type key_dh_secret_s (cs:ciphersuite) = lbytes (size_dh_key cs)
type key_kem_s (cs:ciphersuite) = lbytes (size_kem_key cs) // TODO This is true for the current DHKEM. It would be nice to have it modular depending on the KEM.
type key_aead_s (cs:ciphersuite) = lbytes (size_aead_key cs)
type nonce_aead_s (cs:ciphersuite) = lbytes (size_aead_nonce cs)
type seq_aead_s (cs:ciphersuite) = n:nat{n <= max_seq cs}
type psk_s (cs:ciphersuite) = b:bytes{Seq.length b <= max_psk cs}
type pskID_s (cs:ciphersuite) = b:bytes{Seq.length b <= max_pskID cs}
type exporter_secret_s (cs:ciphersuite) = lbytes (size_kdf cs)
type info_s (cs:ciphersuite) = b:bytes{Seq.length b <= max_info cs} // TODO should this be _s?
type exp_ctx_s (cs:ciphersuite) = b:bytes{Seq.length b <= max_exp_ctx} // TODO should this be _s?

// TODO can we hide the contents of encryption_context, i.e. not
//      expose them in this fsti, to avoid usage which is not
//      conform with the spec?
let encryption_context (cs:ciphersuite) = key_aead_s cs & nonce_aead_s cs & seq_aead_s cs & exporter_secret_s cs

val context_export:
    cs:ciphersuite
  -> ctx:encryption_context cs
  -> exp_ctx:exp_ctx_s cs // TODO replace this by a pre-condition that uses labeled_expand predicates
  -> l:size_nat ->
  Pure (lbytes l)
    (requires HKDF.expand_output_length_pred (hash_of_cs cs) l)
    (ensures fun _ -> True)

val context_compute_nonce:
    cs:ciphersuite
  -> ctx:encryption_context cs
  -> seq:seq_aead_s cs ->
  Tot (nonce_aead_s cs)

val context_increment_seq:
    cs:ciphersuite
  -> ctx:encryption_context cs ->
  Tot (option (encryption_context cs))

val context_seal:
    cs:ciphersuite
  -> ctx:encryption_context cs
  -> aad:AEAD.ad (aead_of_cs cs)
  -> pt:AEAD.plain (aead_of_cs cs) ->
  Tot (option (encryption_context cs & AEAD.cipher (aead_of_cs cs)))

val context_open:
    cs:ciphersuite
  -> ctx:encryption_context cs
  -> aad:AEAD.ad (aead_of_cs cs)
  -> ct:AEAD.cipher (aead_of_cs cs) ->
  Tot (option (encryption_context cs & AEAD.plain (aead_of_cs cs)))

val setupBaseS:
    cs:ciphersuite
  -> skE:key_dh_secret_s cs
  -> pkR:DH.serialized_point (curve_of_cs cs)
  -> info:info_s cs ->
  Tot (option (key_dh_public_s cs & encryption_context cs))

val setupBaseR:
    cs:ciphersuite
  -> enc:key_dh_public_s cs
  -> skR:key_dh_secret_s cs
  -> info:info_s cs ->
  Tot (option (encryption_context cs))

val sealBase:
    cs:ciphersuite
  -> skE:key_dh_secret_s cs
  -> pkR:DH.serialized_point (curve_of_cs cs)
  -> info:info_s cs
  -> aad:AEAD.ad (aead_of_cs cs)
  -> pt:AEAD.plain (aead_of_cs cs) ->
  Tot (option (key_dh_public_s cs & AEAD.encrypted #(aead_of_cs cs) pt))

val openBase:
    cs:ciphersuite
  -> enc:key_dh_public_s cs
  -> skR:key_dh_secret_s cs
  -> info:info_s cs
  -> aad:AEAD.ad (aead_of_cs cs)
  -> ct:AEAD.cipher (aead_of_cs cs) ->
  Tot (option (AEAD.decrypted #(aead_of_cs cs) ct))

