module Hacl.Impl.P256.Point

open FStar.Mul
open FStar.HyperStack.All
open FStar.HyperStack
module ST = FStar.HyperStack.ST

open Lib.IntTypes
open Lib.Buffer

open Hacl.Impl.P256.Bignum
open Hacl.Impl.P256.Field
open Hacl.Impl.P256.Finv
open Hacl.Impl.P256.Constants

module S = Spec.P256

#set-options "--z3rlimit 50 --fuel 0 --ifuel 0"

let create_point () =
  create 12ul (u64 0)


[@CInline]
let make_base_point p =
  let x = getx p in
  let y = gety p in
  let z = getz p in
  make_g_x x;
  make_g_y y;
  make_fone z


[@CInline]
let make_point_at_inf p =
  let x = getx p in
  let y = gety p in
  let z = getz p in
  make_fzero x;
  make_fzero y;
  make_fzero z


let copy_point p res = copy res p


///  check if a point is a point-at-infinity

(* https://crypto.stackexchange.com/questions/43869/point-at-infinity-and-error-handling*)
val lemma_mont_is_point_at_inf: p:S.jacob_point{let (_, _, z) = p in z < S.prime} ->
  Lemma (S.is_point_at_inf p == S.is_point_at_inf (SM.fromDomainPoint p))

let lemma_mont_is_point_at_inf p =
  let px, py, pz = p in
  assert (if S.is_point_at_inf p then pz == 0 else pz <> 0);
  assert (SM.fromDomain_ pz == pz * SM.mont_R_inv % S.prime);
  assert_norm (SM.mont_R_inv % S.prime <> 0);
  assert_norm (0 * SM.mont_R_inv % S.prime == 0);
  Hacl.Spec.P256.Math.lemma_multiplication_not_mod_prime pz;
  assert (if pz = 0 then SM.fromDomain_ pz == 0 else SM.fromDomain_ pz <> 0)


[@CInline]
let is_point_at_inf p =
  let h0 = ST.get () in
  lemma_mont_is_point_at_inf (as_point_nat h0 p);
  let pz = getz p in
  bn_is_zero_mask4 pz


[@CInline]
let is_point_at_inf_vartime p =
  let pz = getz p in
  bn_is_zero_vartime4 pz


///  Point conversion between Montgomery and Regular representations

[@CInline]
let point_to_mont p res =
  let open Hacl.Impl.P256.Core in
  let px = getx p in
  let py = gety p in
  let pz = getz p in

  let rx = getx res in
  let ry = gety res in
  let rz = getz res in

  toDomain px rx;
  toDomain py ry;
  toDomain pz rz


[@CInline]
let point_from_mont p res =
  let px = getx p in
  let py = gety p in
  let pz = getz p in

  let rx = getx res in
  let ry = gety res in
  let rz = getz res in

  fromDomain px rx;
  fromDomain py ry;
  fromDomain pz rz


///  Point conversion between Jacobian and Affine coordinates representations

inline_for_extraction noextract
val norm_jacob_point_z: p:point -> res:felem -> Stack unit
  (requires fun h ->
    live h res /\ live h p /\ disjoint p res /\
    point_inv h p)
  (ensures fun h0 _ h1 -> modifies (loc res) h0 h1 /\
    (let _, _, rz = S.norm_jacob_point (SM.fromDomainPoint (as_point_nat h0 p)) in
    as_nat h1 res == rz))

let norm_jacob_point_z p res =
  push_frame ();
  let fresero = create (size 4) (u64 0) in
  let bit = is_point_at_inf p in

  bn_set_one4 res;
  bn_copy_conditional4 res fresero bit;
  pop_frame ()


[@CInline]
let norm_jacob_point_x p res =
  let px = getx p in
  let pz = getz p in

  let h0 = ST.get () in
  fsqr pz res;       // rx = pz * pz
  let h1 = ST.get () in
  assert (fmont_as_nat h1 res == S.fmul (fmont_as_nat h0 pz) (fmont_as_nat h0 pz));
  finv res res;       // rx = finv rx
  let h2 = ST.get () in
  assert (fmont_as_nat h2 res == S.finv (fmont_as_nat h1 res));
  fmul px res res;    // rx = px * rx
  let h3 = ST.get () in
  assert (fmont_as_nat h3 res == S.fmul (fmont_as_nat h0 px) (fmont_as_nat h2 res));
  fromDomain res res;
  let h4 = ST.get () in
  assert (as_nat h4 res == fmont_as_nat h3 res)


// TODO: rm
inline_for_extraction noextract
val norm_jacob_point_y: p:point -> res:felem -> Stack unit
  (requires fun h ->
    live h res /\ live h p /\ disjoint p res /\
    point_inv h p)
  (ensures fun h0 _ h1 -> modifies (loc res) h0 h1 /\
    (let _, ry, _ = S.norm_jacob_point (SM.fromDomainPoint (as_point_nat h0 p)) in
    as_nat h1 res == ry))

let norm_jacob_point_y p res =
  let py = gety p in
  let pz = getz p in

  let h0 = ST.get () in
  fcube pz res;       // ry = pz * pz * pz
  let h1 = ST.get () in
  finv res res;       // ry = finv ry
  let h2 = ST.get () in
  assert (fmont_as_nat h2 res == S.finv (fmont_as_nat h1 res));
  fmul py res res;    // ry = px * ry
  let h3 = ST.get () in
  assert (fmont_as_nat h3 res == S.fmul (fmont_as_nat h0 py) (fmont_as_nat h2 res));
  fromDomain res res;
  let h4 = ST.get () in
  assert (as_nat h4 res == fmont_as_nat h3 res)


[@CInline]
let norm_jacob_point p res =
  push_frame ();
  let tmp = create 12ul (u64 0) in
  let tx = getx tmp in
  let ty = gety tmp in
  let tz = getz tmp in
  norm_jacob_point_x p tx;
  norm_jacob_point_y p ty;
  norm_jacob_point_z p tz;
  copy_point tmp res;
  pop_frame ()


[@CInline]
let to_jacob_point p res =
  let px = aff_getx p in
  let py = aff_gety p in

  let rx = getx res in
  let ry = gety res in
  let rz = getz res in
  copy rx px;
  copy ry py;
  bn_set_one4 rz


///  Check if a point is on the curve

inline_for_extraction noextract
val compute_rp_ec_equation: x:felem -> res:felem -> Stack unit
  (requires fun h ->
    live h x /\ live h res /\ disjoint x res /\
    as_nat h x < S.prime)
  (ensures fun h0 _ h1 -> modifies (loc res) h0 h1 /\ as_nat h1 res < S.prime /\
    (let x = fmont_as_nat h0 x in
    fmont_as_nat h1 res ==
      S.fadd (S.fadd (S.fmul (S.fmul x x) x) (S.fmul S.a_coeff x)) S.b_coeff))

let compute_rp_ec_equation x res =
  push_frame ();
  let tmp = create 4ul (u64 0) in
  fcube x res;
  make_a_coeff tmp;
  fmul tmp x tmp;
  fadd res tmp res;
  make_b_coeff tmp;
  fadd res tmp res;
  pop_frame ()


inline_for_extraction noextract
val is_y_sqr_is_y2_vartime (y2 y:felem) : Stack bool
  (requires fun h ->
    live h y /\ live h y2 /\ disjoint y y2 /\
    as_nat h y2 < S.prime /\ as_nat h y < S.prime)
  (ensures fun h0 b h1 -> modifies (loc y) h0 h1 /\
    b == (fmont_as_nat h0 y2 = S.fmul (fmont_as_nat h0 y) (fmont_as_nat h0 y)))

let is_y_sqr_is_y2_vartime y2 y =
  fsqr y y; // y = y * y
  let r = feq_mask y y2 in
  Hacl.Bignum.Base.unsafe_bool_of_limb r


// y *% y = x *% x *% x +% a_coeff *% x +% b_coeff
[@CInline]
let is_point_on_curve_vartime p =
  push_frame ();
  let rp = create 4ul (u64 0) in
  let tx = create 4ul (u64 0) in
  let ty = create 4ul (u64 0) in
  let px = aff_getx p in
  let py = aff_gety p in
  let h0 = ST.get () in
  Hacl.Impl.P256.Core.toDomain px tx;
  Hacl.Impl.P256.Core.toDomain py ty;

  SM.lemmaToDomainAndBackIsTheSame (as_nat h0 px);
  SM.lemmaToDomainAndBackIsTheSame (as_nat h0 py);
  compute_rp_ec_equation tx rp;
  let r = is_y_sqr_is_y2_vartime rp ty in
  pop_frame ();
  r


///  Point load and store functions

[@CInline]
let aff_store_point res p =
  let px = aff_getx p in
  let py = aff_gety p in

  let h0 = ST.get () in
  update_sub_f h0 res 0ul 32ul
    (fun h -> BSeq.nat_to_bytes_be 32 (as_nat h0 px))
    (fun _ -> bn_to_bytes_be4 px (sub res 0ul 32ul));

  let h1 = ST.get () in
  update_sub_f h1 res 32ul 32ul
    (fun h -> BSeq.nat_to_bytes_be 32 (as_nat h1 py))
    (fun _ -> bn_to_bytes_be4 py (sub res 32ul 32ul));

  let h2 = ST.get () in
  let px = Ghost.hide (BSeq.nat_to_bytes_be 32 (as_nat h0 px)) in
  let py = Ghost.hide (BSeq.nat_to_bytes_be 32 (as_nat h0 py)) in
  LSeq.eq_intro (as_seq h2 res) (LSeq.concat #_ #32 #32 px py)


inline_for_extraction noextract
val is_xy_valid_vartime: p:aff_point -> Stack bool
  (requires fun h -> live h p)
  (ensures fun h0 r h1 -> modifies0 h0 h1 /\
    r == (aff_point_x_as_nat h0 p < S.prime &&
          aff_point_y_as_nat h0 p < S.prime))

let is_xy_valid_vartime p =
  let px = aff_getx p in
  let py = aff_gety p in
  let lessX = bn_is_lt_prime_mask4 px in
  let lessY = bn_is_lt_prime_mask4 py in
  let res = logand lessX lessY in
  logand_lemma lessX lessY;
  Hacl.Bignum.Base.unsafe_bool_of_limb res


[@CInline]
let load_point_vartime p b =
  push_frame ();
  let p_x = sub b 0ul 32ul in
  let p_y = sub b 32ul 32ul in
  let point_aff = create 8ul (u64 0) in
  let bn_p_x = aff_getx point_aff in
  let bn_p_y = aff_gety point_aff in
  bn_from_bytes_be4 p_x bn_p_x;
  bn_from_bytes_be4 p_y bn_p_y;
  let is_xy_valid = is_xy_valid_vartime point_aff in
  let res = if not is_xy_valid then false else is_point_on_curve_vartime point_aff in
  if res then
    to_jacob_point point_aff p;
  pop_frame ();
  res


inline_for_extraction noextract
val recover_y_vartime_candidate (y x:felem) : Stack bool
  (requires fun h ->
    live h x /\ live h y /\ disjoint x y /\ as_nat h x < S.prime)
  (ensures fun h0 b h1 -> modifies (loc y) h0 h1 /\ as_nat h1 y < S.prime /\
   (let x = as_nat h0 x in
    let y2 = S.(x *% x *% x +% a_coeff *% x +% b_coeff) in
    as_nat h1 y == S.fsqrt y2 /\ (b <==> (S.fmul (as_nat h1 y) (as_nat h1 y) == y2))))

let recover_y_vartime_candidate y x =
  push_frame ();
  let y2M = create_felem () in
  let xM = create_felem () in
  let yM = create_felem () in
  let h0 = ST.get () in
  SM.lemmaToDomainAndBackIsTheSame (as_nat h0 x);
  Hacl.Impl.P256.Core.toDomain x xM;
  compute_rp_ec_equation xM y2M; // y2M = x *% x *% x +% S.a_coeff *% x +% S.b_coeff
  fsqrt y2M yM; // yM = fsqrt y2M
  let h1 = ST.get () in
  fromDomain yM y;
  let is_y_valid = is_y_sqr_is_y2_vartime y2M yM in
  pop_frame ();
  is_y_valid


inline_for_extraction noextract
val recover_y_vartime (y x:felem) (is_odd:bool) : Stack bool
  (requires fun h ->
    live h x /\ live h y /\ disjoint x y /\ as_nat h x < S.prime)
  (ensures fun h0 b h1 -> modifies (loc y) h0 h1 /\
    (b <==> Some? (S.recover_y (as_nat h0 x) is_odd)) /\
    (b ==> (as_nat h1 y < S.prime/\
      as_nat h1 y == Some?.v (S.recover_y (as_nat h0 x) is_odd))))

let recover_y_vartime y x is_odd =
  let is_y_valid = recover_y_vartime_candidate y x in
  if not is_y_valid then false
  else begin
    let is_y_odd = bn_is_odd4 y in
    let is_y_odd = Lib.RawIntTypes.u64_to_UInt64 is_y_odd =. 1uL in
    fnegate_conditional_vartime y (is_y_odd <> is_odd);
    true end


[@CInline]
let aff_point_decompress_vartime x y s =
  let s0 = s.(0ul) in
  let s0 = Lib.RawIntTypes.u8_to_UInt8 s0 in
  if not (s0 = 0x02uy || s0 = 0x03uy) then false
  else begin
    let xb = sub s 1ul 32ul in
    bn_from_bytes_be4 xb x;
    let is_x_valid = bn_is_lt_prime_mask4 x in
    let is_x_valid = Hacl.Bignum.Base.unsafe_bool_of_limb is_x_valid in
    let is_y_odd = s0 = 0x03uy in

    if not is_x_valid then false
    else recover_y_vartime y x is_y_odd end


let validate_pubkey pk =
  push_frame ();
  let point_jac = create 12ul (u64 0) in
  let res = load_point_vartime point_jac pk in
  pop_frame ();
  res


[@CInline]
let isMoreThanZeroLessThanOrder x =
  push_frame ();
  let bn_x = create 4ul (u64 0) in
  bn_from_bytes_be4 x bn_x;
  let res = Hacl.Impl.P256.Scalar.bn_is_lt_order_and_gt_zero_mask4 bn_x in
  pop_frame ();
  Hacl.Bignum.Base.unsafe_bool_of_limb res
