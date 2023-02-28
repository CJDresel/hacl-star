module Hacl.Impl.P256.Scalar

open FStar.Mul
open FStar.HyperStack.All
open FStar.HyperStack
module ST = FStar.HyperStack.ST

open Lib.IntTypes
open Lib.Buffer

open Hacl.Spec.P256.Felem
open Hacl.Impl.P256.Bignum
open Hacl.Impl.P256.Constants

module S = Spec.P256
module SL = Hacl.Spec.P256.Lemmas

module BD = Hacl.Spec.Bignum.Definitions
module BM = Hacl.Bignum.Montgomery
module SBM = Hacl.Spec.Bignum.Montgomery
module SBML = Hacl.Spec.Montgomery.Lemmas

friend Hacl.Bignum256

#reset-options "--z3rlimit 50 --fuel 0 --ifuel 0"

val qmod_short_lemma: a:nat{a < pow2 256} ->
  Lemma (let r = if a >= S.order then a - S.order else a in r = a % S.order)

let qmod_short_lemma a =
  let r = if a >= S.order then a - S.order else a in
  if a >= S.order then begin
    Math.Lemmas.lemma_mod_sub a S.order 1;
    assert_norm (pow2 256 - S.order < S.order);
    Math.Lemmas.small_mod r S.order end
  else
   Math.Lemmas.small_mod r S.order


[@CInline]
let qmod_short x res =
  push_frame ();
  let tmp = create (size 4) (u64 0) in
  make_order tmp;
  let h0 = ST.get () in
  let c = bn_sub4 x tmp tmp in
  bn_cmovznz4 c tmp x res;
  as_nat_bound h0 x;
  qmod_short_lemma (as_nat h0 x);
  pop_frame ()

//----------------------
// TODO: share the proofs with Hacl.Spec.P256.Montgomerymultiplication

let lemmaFromDomain a = ()

let lemmaToDomain a = ()

// toDomain_ (fromDomain_ a) == a
let lemmaFromDomainToDomain a =
  calc (==) {
    toDomain_ (fromDomain_ a); // == a
    (==) { }
    (a * qmont_R_inv % S.order) * qmont_R % S.order;
    (==) { Math.Lemmas.lemma_mod_mul_distr_l (a * qmont_R_inv) qmont_R S.order }
    a * qmont_R_inv * qmont_R % S.order;
    (==) { Math.Lemmas.paren_mul_right a qmont_R_inv qmont_R }
    a * (qmont_R_inv * qmont_R) % S.order;
    (==) { Math.Lemmas.lemma_mod_mul_distr_r a (qmont_R_inv * qmont_R) S.order }
    a * (qmont_R_inv * qmont_R % S.order) % S.order;
    (==) { assert_norm (qmont_R_inv * qmont_R % S.order = 1) }
    a % S.order;
    (==) { Math.Lemmas.modulo_lemma a S.order }
    a;
  }


// fromDomain_ (toDomain_ a) == a
let lemmaToDomainFromDomain a =
  calc (==) {
    fromDomain_ (toDomain_ a); // == a
    (==) { }
    (a * qmont_R % S.order) * qmont_R_inv % S.order;
    (==) { Math.Lemmas.lemma_mod_mul_distr_l (a * qmont_R) qmont_R_inv S.order }
    a * qmont_R * qmont_R_inv % S.order;
    (==) { Math.Lemmas.paren_mul_right a qmont_R qmont_R_inv }
    a * (qmont_R * qmont_R_inv) % S.order;
    (==) { Math.Lemmas.lemma_mod_mul_distr_r a (qmont_R * qmont_R_inv) S.order }
    a * (qmont_R * qmont_R_inv % S.order) % S.order;
    (==) { assert_norm (qmont_R * qmont_R_inv % S.order = 1) }
    a % S.order;
    (==) { Math.Lemmas.modulo_lemma a S.order }
    a;
  }


// (fromDomain_ a + fromDomain_ b) % S.order = fromDomain_ (a + b)
let qadd_lemma a b =
  calc (==) {
    (fromDomain_ a + fromDomain_ b) % S.order;
    (==) { }
    (a * qmont_R_inv % S.order + b * qmont_R_inv % S.order) % S.order;
    (==) { Math.Lemmas.modulo_distributivity (a * qmont_R_inv) (b * qmont_R_inv) S.order }
    (a * qmont_R_inv + b * qmont_R_inv) % S.order;
    (==) { Math.Lemmas.distributivity_add_left a b qmont_R_inv }
    (a + b) * qmont_R_inv % S.order;
    (==) { }
    fromDomain_ (a + b);
  }


val inDomain_mod_is_not_mod: a:nat -> Lemma (toDomain_ a == toDomain_ (a % S.order))
let inDomain_mod_is_not_mod a =
  calc (==) {
    toDomain_ (a % S.order); // == toDomain_ a
    (==) { }
    (a % S.order) * qmont_R % S.order;
    (==) { Math.Lemmas.lemma_mod_mul_distr_l a qmont_R S.order }
    a * qmont_R % S.order;
  }


val multiplicationInDomain: #k:S.qelem -> #l:S.qelem
  -> a:S.qelem{a == toDomain_ k}
  -> b:S.qelem{b == toDomain_ l} ->
  Lemma (a * b * qmont_R_inv % S.order == toDomain_ (k * l))

let multiplicationInDomain #k #l a b =
  // a = k * qmont_R % S.order = toDomain_ k
  // b = l * qmont_R % S.order = toDomain_ l
  calc (==) {
    a * b * qmont_R_inv % S.order; // == toDomain_ (k * l)
    (==) { }
    a * (l * qmont_R % S.order) * qmont_R_inv % S.order;
    (==) { Math.Lemmas.paren_mul_right a (l * qmont_R % S.order) qmont_R_inv }
    a * ((l * qmont_R % S.order) * qmont_R_inv) % S.order;
    (==) { Math.Lemmas.lemma_mod_mul_distr_r a ((l * qmont_R % S.order) * qmont_R_inv) S.order }
    a * ((l * qmont_R % S.order) * qmont_R_inv % S.order) % S.order;
    (==) { lemmaToDomainFromDomain l }
    (k * qmont_R % S.order) * l % S.order;
    (==) { Math.Lemmas.lemma_mod_mul_distr_l (k * qmont_R) l S.order }
    (k * qmont_R) * l % S.order;
    (==) { Math.Lemmas.paren_mul_right k qmont_R l;
      Math.Lemmas.swap_mul qmont_R l;
      Math.Lemmas.paren_mul_right k l qmont_R }
    (k * l) * qmont_R % S.order;
    (==) { }
    toDomain_ (k * l);
  }

//---------------------

val qmont_R_inv_is_bn_mont_d: unit -> Lemma
  (requires S.order % 2 = 1)
  (ensures  (let d, _ = SBML.eea_pow2_odd 256 S.order in qmont_R_inv == d % S.order))

let qmont_R_inv_is_bn_mont_d () =
  let d, k = SBML.eea_pow2_odd 256 S.order in
  SBML.mont_preconditions_d 64 4 S.order;
  assert (d * pow2 256 % S.order = 1);

  assert_norm (qmont_R * qmont_R_inv % S.order = 1);
  Math.Lemmas.lemma_mod_mul_distr_l (pow2 256) qmont_R_inv S.order;
  assert (qmont_R_inv * pow2 256 % S.order = 1);

  assert (qmont_R_inv * pow2 256 % S.order = d * pow2 256 % S.order);
  Hacl.Spec.P256.Math.lemma_modular_multiplication_pow256_order qmont_R_inv d;
  assert (qmont_R_inv % S.order == d % S.order);
  Math.Lemmas.modulo_lemma qmont_R_inv S.order;
  assert (qmont_R_inv == d % S.order)


val lemma_order_mont: unit ->
  Lemma (S.order % 2 = 1 /\ S.order < pow2 256 /\ (1 + S.order * 0xccd1c8aaee00bc4f) % pow2 64 = 0)

let lemma_order_mont () =
  assert_norm (S.order % 2 = 1);
  assert_norm (S.order < pow2 256);
  assert_norm ((1 + S.order * 0xccd1c8aaee00bc4f) % pow2 64 = 0)


val qmont_reduction_lemma: x:Lib.Sequence.lseq uint64 8 -> n:Lib.Sequence.lseq uint64 4 -> Lemma
  (requires BD.bn_v n = S.order /\ BD.bn_v x < S.order * S.order)
  (ensures  BD.bn_v (SBM.bn_mont_reduction n (u64 0xccd1c8aaee00bc4f) x) ==
    BD.bn_v x * qmont_R_inv % S.order)

let qmont_reduction_lemma x n =
  let k0 = 0xccd1c8aaee00bc4f in
  lemma_order_mont ();
  assert (SBM.bn_mont_pre n (u64 k0));
  let d, _ = SBML.eea_pow2_odd 256 (BD.bn_v n) in

  let res = SBM.bn_mont_reduction n (u64 k0) x in
  assert_norm (S.order * S.order < S.order * pow2 256);
  assert (BD.bn_v x < S.order * pow2 256);

  SBM.bn_mont_reduction_lemma n (u64 k0) x;
  assert (BD.bn_v res == SBML.mont_reduction 64 4 (BD.bn_v n) k0 (BD.bn_v x));
  SBML.mont_reduction_lemma 64 4 (BD.bn_v n) k0 (BD.bn_v x);
  assert (BD.bn_v res == BD.bn_v x * d % S.order);
  calc (==) {
    (BD.bn_v x) * d % S.order;
    (==) { Math.Lemmas.lemma_mod_mul_distr_r (BD.bn_v x) d S.order }
    (BD.bn_v x) * (d % S.order) % S.order;
    (==) { qmont_R_inv_is_bn_mont_d () }
    (BD.bn_v x) * qmont_R_inv % S.order;
  }


val qmont_reduction: x:widefelem -> res:felem -> Stack unit
  (requires fun h ->
    live h x /\ live h res /\ disjoint x res /\
    wide_as_nat h x < S.order * S.order)
  (ensures fun h0 _ h1 -> modifies (loc res |+| loc x) h0 h1 /\
    as_nat h1 res == wide_as_nat h0 x * qmont_R_inv % S.order)

[@CInline]
let qmont_reduction x res =
  push_frame ();
  let n = create 4ul (u64 0) in
  make_order n;

  let h0 = ST.get () in
  BM.bn_mont_reduction Hacl.Bignum256.bn_inst n (u64 0xccd1c8aaee00bc4f) x res;
  let h1 = ST.get () in
  bignum_bn_v_is_as_nat h0 n;
  bignum_bn_v_is_wide_as_nat h0 x;
  assert (BD.bn_v (as_seq h0 n) == as_nat h0 n);
  assert (BD.bn_v (as_seq h0 x) == wide_as_nat h0 x);
  qmont_reduction_lemma (as_seq h0 x) (as_seq h0 n);
  assert (BD.bn_v (as_seq h1 res) == BD.bn_v (as_seq h0 x) * qmont_R_inv % S.order);
  bignum_bn_v_is_as_nat h1 res;
  assert (as_nat h1 res == wide_as_nat h0 x * qmont_R_inv % S.order);
  pop_frame ()

//-------------------

[@CInline]
let qadd x y res =
  let h0 = ST.get () in
  push_frame ();
  let n = create 4ul (u64 0) in
  make_order n;
  bn_add_mod4 x y n res;
  let h1 = ST.get () in
  assert (as_nat h1 res == (as_nat h0 x + as_nat h0 y) % S.order);
  pop_frame ()


let qmul a b res =
  push_frame ();
  let tmp = create (size 8) (u64 0) in
  let h0 = ST.get () in
  bn_mul4 a b tmp;
  let h1 = ST.get () in
  SL.mul_lemma_ (as_nat h0 a) (as_nat h0 b) S.order;
  qmont_reduction tmp res;
  lemmaFromDomainToDomain (as_nat h0 a);
  lemmaFromDomainToDomain (as_nat h0 b);
  multiplicationInDomain
    #(fromDomain_ (as_nat h0 a)) #(fromDomain_ (as_nat h0 b)) (as_nat h0 a) (as_nat h0 b);
  inDomain_mod_is_not_mod (fromDomain_ (as_nat h0 a) * fromDomain_ (as_nat h0 b));
  pop_frame()


let fromDomainImpl a res =
  push_frame ();
  let t = create (size 8) (u64 0) in
  let t_low = sub t (size 0) (size 4) in
  let t_high = sub t (size 4) (size 4) in

  let h0 = ST.get () in
  copy t_low a;
  let h1 = ST.get () in
  assert (wide_as_nat h0 t = as_nat h0 t_low + as_nat h0 t_high * pow2 256);
  assert_norm (S.order < S.order * S.order);
  qmont_reduction t res;
  pop_frame ()
