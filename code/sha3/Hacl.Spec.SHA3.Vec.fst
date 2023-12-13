module Hacl.Spec.SHA3.Vec

open Hacl.Spec.SHA3.Vec.Common

open Lib.IntTypes
open Lib.IntVector
open Lib.NTuple
open Lib.Sequence
open Lib.ByteSequence
open FStar.Mul
open Lib.LoopCombinators
open Lib.IntVector.Transpose

open Spec.Hash.Definitions
open Spec.SHA3.Constants

#reset-options "--z3rlimit 50 --max_fuel 0 --max_ifuel 0"

unfold
type state (m:m_spec) = lseq (element_t m) 25

unfold
type index = n:size_nat{n < 5}

let get (m:m_spec) (s:state m) (x:index) (y:index) : Tot (element_t m) =
  s.[x + 5 * y]

let set (m:m_spec) (s:state m) (x:index) (y:index) (v:element_t m) : Tot (state m) =
  s.[x + 5 * y] <- v

let state_theta_inner_C (m:m_spec) (s:state m) (i:size_nat{i < 5}) (_C:lseq (element_t m) 5) : Tot (lseq (element_t m) 5) =
  _C.[i] <- get m s i 0 ^| get m s i 1 ^| get m s i 2 ^| get m s i 3 ^| get m s i 4

let state_theta0 (m:m_spec) (s:state m) (_C:lseq (element_t m) 5) =
  repeati 5 (state_theta_inner_C m s) _C

let state_theta_inner_s_inner (m:m_spec) (x:index) (_D:element_t m) (y:index) (s:state m) : Tot (state m) =
  set m s x y (get m s x y ^| _D)

let state_theta_inner_s (m:m_spec) (_C:lseq (element_t m) 5) (x:index) (s:state m) : Tot (state m) =
  let _D = _C.[(x + 4) % 5] ^| (_C.[(x + 1) % 5] <<<| (size 1)) in
  repeati 5 (state_theta_inner_s_inner m x _D) s

let state_theta1 (m:m_spec) (s:state m) (_C:lseq (element_t m) 5) : Tot (state m) =
  repeati 5 (state_theta_inner_s m _C) s

let state_theta (m:m_spec) (s:state m) : Tot (state m) =
  let _C = create 5 (zero_element m) in
  let _C = state_theta0 m s _C in
  state_theta1 m s _C

let state_pi_rho_inner (m:m_spec) (i:size_nat{i < 24}) (current, s) : ((element_t m) & (state m)) =
  let r = keccak_rotc.[i] in
  let _Y = v keccak_piln.[i] in
  let temp = s.[_Y] in
  let s = s.[_Y] <- current <<<| r in
  let current = temp in
  current, s

val state_pi_rho_s: m:m_spec -> i:size_nat{i <= 24} -> Type0
let state_pi_rho_s m i = (element_t m) & (state m)

let state_pi_rho (m:m_spec) (s_theta:state m) : Tot (state m) =
  let current = get m s_theta 1 0 in
  let _, s_pi_rho = repeat_gen 24 (state_pi_rho_s m)
    (state_pi_rho_inner m) (current, s_theta) in
  s_pi_rho

let state_chi_inner0 (m:m_spec) (s_pi_rho:state m) (y:index) (x:index) (s:state m) : Tot (state m) =
  set m s x y
    (get m s_pi_rho x y ^|
     ((~| (get m s_pi_rho ((x + 1) % 5) y)) &|
      get m s_pi_rho ((x + 2) % 5) y))

let state_chi_inner1 (m:m_spec) (s_pi_rho:state m) (y:index) (s:state m) : Tot (state m) =
  repeati 5 (state_chi_inner0 m s_pi_rho y) s

let state_chi (m:m_spec) (s_pi_rho:state m) : Tot (state m)  =
  repeati 5 (state_chi_inner1 m s_pi_rho) s_pi_rho

let state_iota (m:m_spec) (s:state m) (round:size_nat{round < 24}) : Tot (state m) =
  set m s 0 0 (get m s 0 0 ^| (load_element m (secret keccak_rndc.[round])))

(* Equivalence *)

let state_chi_inner (m:m_spec) (y:index) (s:state m) : Tot (state m) =
  let v0  = get m s 0 y ^| ((~| (get m s 1 y)) &| get m s 2 y) in
  let v1  = get m s 1 y ^| ((~| (get m s 2 y)) &| get m s 3 y) in
  let v2  = get m s 2 y ^| ((~| (get m s 3 y)) &| get m s 4 y) in
  let v3  = get m s 3 y ^| ((~| (get m s 4 y)) &| get m s 0 y) in
  let v4  = get m s 4 y ^| ((~| (get m s 0 y)) &| get m s 1 y) in
  let s = set m s 0 y v0 in
  let s = set m s 1 y v1 in
  let s = set m s 2 y v2 in
  let s = set m s 3 y v3 in
  let s = set m s 4 y v4 in
  s

let state_chi_equiv (m:m_spec) (s_pi_rho:state m) : Tot (state m)  =
  repeati 5 (state_chi_inner m) s_pi_rho

let state_chi_inner_equivalence0 (m:m_spec) (st_old:state m) (y:index) (st:state m) :
  Lemma (requires (forall y'. (y' >= y /\ y' < 5) ==>
                   get m st_old 0 y' == get m st 0 y' /\
                   get m st_old 1 y' == get m st 1 y' /\
                   get m st_old 2 y' == get m st 2 y' /\
                   get m st_old 3 y' == get m st 3 y' /\
                   get m st_old 4 y' == get m st 4 y'))
        (ensures  (let st_new = state_chi_inner1 m st_old y st in
                   st_new == state_chi_inner m y st)) =
         Lib.LoopCombinators.eq_repeati0 5 (state_chi_inner0 m st_old y) st;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner0 m st_old y) st 0;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner0 m st_old y) st 1;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner0 m st_old y) st 2;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner0 m st_old y) st 3;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner0 m st_old y) st 4;
         assert (repeati 5 (state_chi_inner0 m st_old y) st ==
                 state_chi_inner0 m st_old y 4 (state_chi_inner0 m st_old y 3 (state_chi_inner0 m st_old y 2 (state_chi_inner0 m st_old y 1 (state_chi_inner0 m st_old y 0 st)))));
         
         ()

let state_chi_inner_equivalence1 (m:m_spec) (st_old:state m) (y:index) (st_new:state m) :
  Lemma (requires (st_new == state_chi_inner m y st_old))
        (ensures (  (forall y'. (y' < 5 /\ y' > y) ==>
                    (get m st_new 0 y' == get m st_old 0 y' /\
                     get m st_new 1 y' == get m st_old 1 y' /\
                     get m st_new 2 y' == get m st_old 2 y' /\
                     get m st_new 3 y' == get m st_old 3 y' /\
                     get m st_new 4 y' == get m st_old 4 y')))) = ()

#push-options "--z3rlimit 50"
let state_chi_equivalence (m:m_spec) (st_old:state m) :
  Lemma (state_chi_equiv m st_old == state_chi m st_old) =
         Lib.LoopCombinators.eq_repeati0 5 (state_chi_inner1 m st_old) st_old;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner1 m st_old) st_old 0;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner1 m st_old) st_old 1;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner1 m st_old) st_old 2;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner1 m st_old) st_old 3;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner1 m st_old) st_old 4;
         Lib.LoopCombinators.eq_repeati0 5 (state_chi_inner m) st_old;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner m) st_old 0;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner m) st_old 1;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner m) st_old 2;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner m) st_old 3;
         Lib.LoopCombinators.unfold_repeati 5 (state_chi_inner m) st_old 4;
         let st1 = state_chi_inner1 m st_old 0 st_old in
         let st2 = state_chi_inner1 m st_old 1 st1 in
         let st3 = state_chi_inner1 m st_old 2 st2 in
         let st4 = state_chi_inner1 m st_old 3 st3 in
         let st5 = state_chi_inner1 m st_old 4 st4 in
         let st1' = state_chi_inner m 0 st_old in
         let st2' = state_chi_inner m 1 st1' in
         let st3' = state_chi_inner m 2 st2' in
         let st4' = state_chi_inner m 3 st3' in
         let st5' = state_chi_inner m 4 st4' in
         state_chi_inner_equivalence0 m st_old 0 st_old;
         assert(st1 == st1');
         state_chi_inner_equivalence1 m st_old 0 st1;
         state_chi_inner_equivalence0 m st_old 1 st1;
         assert(st2 == st2');
         state_chi_inner_equivalence1 m st1' 1 st2';
         state_chi_inner_equivalence0 m st_old 2 st2;
         assert(st3 == st3');
         state_chi_inner_equivalence1 m st2 2 st3;
         state_chi_inner_equivalence0 m st_old 3 st3;
         assert(st4 == st4');
         state_chi_inner_equivalence1 m st3 3 st4;
         state_chi_inner_equivalence0 m st_old 4 st4;
         assert(st5 == st5');
         state_chi_inner_equivalence1 m st4 4 st5;
         ()
#pop-options

(* Equivalence *)

let state_permute1 (m:m_spec) (round:size_nat{round < 24}) (s:state m) : Tot (state m) =
  let s_theta = state_theta m s in
  let s_pi_rho = state_pi_rho m s_theta in
  let s_chi = state_chi m s_pi_rho in
  let s_iota = state_iota m s_chi round in
  s_iota

let state_permute (m:m_spec) (s:state m) : Tot (state m) =
  repeati 24 (state_permute1 m) s

noextract
let state_spec (m:m_spec) = lseq (element_t m) 25

noextract
let ws_spec (m:m_spec) = lseq (element_t m) 32

noextract
let state_spec_v (#a:keccak_alg) (#m:m_spec) (st:state_spec m) : lseq (words_state a) (lanes m) =
  createi #(words_state a) (lanes m) (fun i ->
    createi (state_word_length a) (fun j ->
      (vec_v st.[j]).[i]))

noextract
let ws_spec_v (#a:keccak_alg) (#m:m_spec) (st:ws_spec m) : lseq (lseq (word a) 32) (lanes m) =
  createi #(lseq (word a) 32) (lanes m) (fun i ->
    createi 32 (fun j ->
      (vec_v st.[j]).[i]))

noextract
let multiseq (lanes:lanes_t) (len:nat) =
  ntuple (Seq.lseq uint8 len) lanes

unfold let multiblock_spec (a:keccak_alg) (m:m_spec) =
  multiseq (lanes m) 256

noextract
let load_elementi (#a:keccak_alg) (#m:m_spec) (b:lseq uint8 256) (bi:nat{bi < 32 / lanes m}) : element_t m =
  let l = lanes m in
  vec_from_bytes_le (word_t a) l (sub b (bi * l * word_length a) (l * word_length a))

noextract
let get_wsi (#a:keccak_alg) (#m:m_spec) (b:multiblock_spec a m) (i:nat{i < 32}) : element_t m =
  let l = lanes m in
  let idx_i = i % l in
  let idx_j = i / l in
  load_elementi #a #m b.(|idx_i|) idx_j

noextract
let load_blocks (#a:keccak_alg) (#m:m_spec) (b:multiblock_spec a m) : ws_spec m =
  createi 32 (get_wsi #a #m b)

noextract
let transpose_ws1 (#m:m_spec{lanes m == 1}) (ws:ws_spec m) : ws_spec m = ws

noextract
let transpose_ws4_0 (#m:m_spec{lanes m == 4}) (ws:ws_spec m) 
  : vec_t U64 4 & vec_t U64 4 & vec_t U64 4 & vec_t U64 4 &
    vec_t U64 4 & vec_t U64 4 & vec_t U64 4 & vec_t U64 4
  =
  let (ws0,ws1,ws2,ws3) =
    transpose4x4 (ws.[0], ws.[1], ws.[2], ws.[3]) in
  let (ws4,ws5,ws6,ws7) =
    transpose4x4 (ws.[4], ws.[5], ws.[6], ws.[7]) in
  (ws0,ws1,ws2,ws3,ws4,ws5,ws6,ws7)

noextract
let transpose_ws4_1 (#m:m_spec{lanes m == 4}) (ws:ws_spec m) 
  : vec_t U64 4 & vec_t U64 4 & vec_t U64 4 & vec_t U64 4 &
    vec_t U64 4 & vec_t U64 4 & vec_t U64 4 & vec_t U64 4
  =
  let (ws8,ws9,ws10,ws11) =
    transpose4x4 (ws.[8], ws.[9], ws.[10], ws.[11]) in
  let (ws12,ws13,ws14,ws15) =
    transpose4x4 (ws.[12], ws.[13], ws.[14], ws.[15]) in
  (ws8,ws9,ws10,ws11,ws12,ws13,ws14,ws15)

noextract
let transpose_ws4_2 (#m:m_spec{lanes m == 4}) (ws:ws_spec m) 
  : vec_t U64 4 & vec_t U64 4 & vec_t U64 4 & vec_t U64 4 &
    vec_t U64 4 & vec_t U64 4 & vec_t U64 4 & vec_t U64 4
  =
  let (ws16,ws17,ws18,ws19) =
    transpose4x4 (ws.[16], ws.[17], ws.[18], ws.[19]) in
  let (ws20,ws21,ws22,ws23) =
    transpose4x4 (ws.[20], ws.[21], ws.[22], ws.[23]) in
  (ws16,ws17,ws18,ws19,ws20,ws21,ws22,ws23)

noextract
let transpose_ws4_3 (#m:m_spec{lanes m == 4}) (ws:ws_spec m) 
  : vec_t U64 4 & vec_t U64 4 & vec_t U64 4 & vec_t U64 4 &
    vec_t U64 4 & vec_t U64 4 & vec_t U64 4 & vec_t U64 4
  =
  let (ws24,ws25,ws26,ws27) =
    transpose4x4 (ws.[24], ws.[25], ws.[26], ws.[27]) in
  let (ws28,ws29,ws30,ws31) =
    transpose4x4 (ws.[28], ws.[29], ws.[30], ws.[31]) in
  (ws24,ws25,ws26,ws27,ws28,ws29,ws30,ws31)

noextract
let transpose_ws4 (#m:m_spec{lanes m == 4}) (ws:ws_spec m) : ws_spec m =
  let (ws0,ws1,ws2,ws3,ws4,ws5,ws6,ws7) = transpose_ws4_0 ws in
  let (ws8,ws9,ws10,ws11,ws12,ws13,ws14,ws15) = transpose_ws4_1 ws in
  let (ws16,ws17,ws18,ws19,ws20,ws21,ws22,ws23) = transpose_ws4_2 ws in
  let (ws24,ws25,ws26,ws27,ws28,ws29,ws30,ws31) = transpose_ws4_3 ws in
  create32 ws0 ws1 ws2 ws3 ws4 ws5 ws6 ws7 ws8 ws9 ws10 ws11 ws12 ws13 ws14 ws15
    ws16 ws17 ws18 ws19 ws20 ws21 ws22 ws23 ws24 ws25 ws26 ws27 ws28 ws29 ws30 ws31

noextract
let transpose_ws (#m:m_spec{is_supported m}) (ws:ws_spec m) : ws_spec m =
  match lanes m with
  | 1 -> transpose_ws1 #m ws
  | 4 -> transpose_ws4 #m ws

noextract
let load_ws (#a:keccak_alg) (#m:m_spec{is_supported m}) (b:multiblock_spec a m) : ws_spec m =
  let ws = load_blocks #a #m b in
  transpose_ws #m ws

let loadState_inner (m:m_spec) (ws:ws_spec m) (j:size_nat{j < 25}) (s:state m) : Tot (state m) =
  s.[j] <- s.[j] ^| ws.[j]

let loadState
  (#a:keccak_alg)
  (#m:m_spec{is_supported m})
  (b:multiblock_spec a m)
  (s:state m) :
  Tot (state m) =
  let ws = load_ws b in
  repeati 25 (loadState_inner m ws) s

noextract
let storeState (#a:keccak_alg) (#m:m_spec{is_supported m}) (s:state m) :
                lseq uint8 (lanes m * 32 * word_length a) =
  let ws = create 32 (zero_element m) in
  let ws = update_sub ws 0 25 s in
  let ws = transpose_ws #m ws in
  Lib.IntVector.Serialize.vecs_to_bytes_le ws

noextract
let next_blocks (rateInBytes:size_nat{rateInBytes > 0 /\ rateInBytes <= 256})
                 (b:lseq uint8 256) :
                 lseq uint8 256 =
  b.[rateInBytes - 1] <- u8 0x80

noextract
let next_block1 (#m:m_spec{lanes m == 1})
                (rateInBytes:size_nat{rateInBytes > 0 /\ rateInBytes <= 256})
                (b:multiseq (lanes m) 256) :
                multiseq (lanes m) 256 =
  let b = b.(|0|) in
  ntup1 (next_blocks rateInBytes b)

noextract
let next_block4 (#m:m_spec{lanes m == 4})
                (rateInBytes:size_nat{rateInBytes > 0 /\ rateInBytes <= 256})
                (b:multiseq (lanes m) 256) :
                multiseq (lanes m) 256 =
  let b0 = b.(|0|) in
  let b1 = b.(|1|) in
  let b2 = b.(|2|) in
  let b3 = b.(|3|) in
  let l0 = next_blocks rateInBytes b0 in
  let l1 = next_blocks rateInBytes b1 in
  let l2 = next_blocks rateInBytes b2 in
  let l3 = next_blocks rateInBytes b3 in
  ntup4 (l0, (l1, (l2, l3)))

noextract
let next_block (#m:m_spec{is_supported m})
               (rateInBytes:size_nat{rateInBytes > 0 /\ rateInBytes <= 256})
               (b:multiseq (lanes m) 256) :
               multiseq (lanes m) 256 =
  match lanes m with
  | 1 -> next_block1 #m rateInBytes b
  | 4 -> next_block4 #m rateInBytes b

let absorb_next (#a:keccak_alg) (#m:m_spec{is_supported m})
                (rateInBytes:size_nat{rateInBytes > 0 /\ rateInBytes <= 256})
                (s:state m) : Tot (state m) =
  let nextBlock = next_block #m rateInBytes (next_block_seq_zero m) in
  let s = loadState #a #m nextBlock s in
  state_permute m s

noextract
let load_last_blocks (rem:size_nat{rem < 256})
                     (delimitedSuffix:byte_t)
                     (lastBlock:lseq uint8 256) :
                     lseq uint8 256 =
  lastBlock.[rem] <- byte_to_uint8 delimitedSuffix

noextract
let load_last_block1 (#m:m_spec{lanes m == 1})
                     (rem:size_nat{rem < 256})
                     (delimitedSuffix:byte_t)
                     (b:multiseq (lanes m) 256) :
                     multiseq (lanes m) 256 =
  let b = b.(|0|) in
  ntup1 (load_last_blocks rem delimitedSuffix b)

noextract
let load_last_block4 (#m:m_spec{lanes m == 4})
                     (rem:size_nat{rem < 256})
                     (delimitedSuffix:byte_t)
                     (b:multiseq (lanes m) 256) :
                     multiseq (lanes m) 256 =
  let l0 = load_last_blocks rem delimitedSuffix b.(|0|) in
  let l1 = load_last_blocks rem delimitedSuffix b.(|1|) in
  let l2 = load_last_blocks rem delimitedSuffix b.(|2|) in
  let l3 = load_last_blocks rem delimitedSuffix b.(|3|) in
  ntup4 (l0, (l1, (l2, l3)))

noextract
let load_last_block (#m:m_spec{is_supported m})
                    (rem:size_nat{rem < 256})
                    (delimitedSuffix:byte_t)
                    (b:multiseq (lanes m) 256) :
                    multiseq (lanes m) 256 =
  match lanes m with
  | 1 -> load_last_block1 #m rem delimitedSuffix b
  | 4 -> load_last_block4 #m rem delimitedSuffix b

val absorb_last:
    #a:keccak_alg
  -> #m:m_spec{is_supported m}
  -> delimitedSuffix:byte_t
  -> rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256}
  -> rem:size_nat{rem < rateInBytes}
  -> input:multiseq (lanes m) 256
  -> s:state m ->
  Tot (state m)

let absorb_last #a #m delimitedSuffix rateInBytes rem input s =
  let lastBlock = load_last_block #m rem delimitedSuffix input in
  let s = loadState #a #m lastBlock s in
  let s =
    if not ((delimitedSuffix &. byte 0x80) =. byte 0) &&
       (rem = rateInBytes - 1)
    then state_permute m s else s in
  absorb_next #a #m rateInBytes s

let absorb_inner
  (#a:keccak_alg)
  (#m:m_spec{is_supported m})
  (b:multiblock_spec a m)
  (s:state m) :
  Tot (state m) =
  let s = loadState b s in
  state_permute m s

noextract
let get_multiblock_spec (#m:m_spec)
                        (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
                        (inputByteLen:nat)
                        (b:multiseq (lanes m) inputByteLen)
                        (i:nat{i < inputByteLen / rateInBytes})
                        : multiseq (lanes m) 256 =

    assert (i * rateInBytes < inputByteLen);
    assert (i + 1 <= inputByteLen / rateInBytes);
    assert ((i + 1) * rateInBytes <= inputByteLen);
    assert (i * rateInBytes + rateInBytes <= inputByteLen);
    Lib.NTuple.createi #(Seq.lseq uint8 256) (lanes m)
      (fun j -> update_sub (create 256 (u8 0)) 0 rateInBytes
        (Seq.slice b.(|j|) (i * rateInBytes) (i * rateInBytes + rateInBytes)))

noextract
let get_multilast_spec (#m:m_spec) 
                        (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
                        (inputByteLen:nat)
                        (b:multiseq (lanes m) inputByteLen)
                        : multiseq (lanes m) 256 =
    let rem = inputByteLen % rateInBytes in
    Lib.NTuple.createi #(Seq.lseq uint8 256) (lanes m)
      (fun j -> update_sub (create 256 (u8 0)) 0 rem
        (Seq.slice b.(|j|) (inputByteLen - rem) inputByteLen))

let absorb_inner_block
  (#a:keccak_alg)
  (#m:m_spec{is_supported m})
  (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
  (inputByteLen:nat)
  (input:multiseq (lanes m) inputByteLen)
  (i:nat{i < inputByteLen / rateInBytes})
  (s:state m) :
  Tot (state m) =
  let mb = get_multiblock_spec #m rateInBytes inputByteLen input i in
  absorb_inner #a #m mb s

let absorb_inner_nblocks
  (#a:keccak_alg)
  (#m:m_spec{is_supported m})
  (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
  (inputByteLen:nat)
  (input:multiseq (lanes m) inputByteLen)
  (s:state m) :
  Tot (state m) =
  let blocks = inputByteLen / rateInBytes in
  let s = repeati blocks (absorb_inner_block #a #m rateInBytes inputByteLen input) s in
  s

let absorb
  (#a:keccak_alg)
  (#m:m_spec{is_supported m})
  (s:state m)
  (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
  (inputByteLen:nat)
  (input:multiseq (lanes m) inputByteLen)
  (delimitedSuffix:byte_t) :
  Tot (state m) =

  let s = absorb_inner_nblocks #a #m rateInBytes inputByteLen input s in
  let rem = inputByteLen % rateInBytes in
  let mb = get_multilast_spec #m rateInBytes inputByteLen input in
  let s = absorb_last #a #m delimitedSuffix rateInBytes rem mb s in
  s

noextract
let init_b1 (#m:m_spec{lanes m == 1})
            (outputByteLen:size_nat) :
            multiseq (lanes m) outputByteLen =
  let l = create outputByteLen (u8 0) in
  ntup1 l

noextract
let init_b4 (#m:m_spec{lanes m == 4})
            (outputByteLen:size_nat) :
            multiseq (lanes m) outputByteLen =
  let l0 = create outputByteLen (u8 0) in
  let l1 = create outputByteLen (u8 0) in
  let l2 = create outputByteLen (u8 0) in
  let l3 = create outputByteLen (u8 0) in
  ntup4 (l0, (l1, (l2, l3)))

(* Linked to impl but not used yet *)
noextract
let init_b (#m:m_spec{is_supported m})
           (outputByteLen:size_nat) :
           multiseq (lanes m) outputByteLen =
  match lanes m with
  | 1 -> init_b1 #m outputByteLen
  | 4 -> init_b4 #m outputByteLen

let store_block4
  (#m:m_spec{lanes m == 4})
  (outputByteLen:size_nat)
  (start:size_nat)
  (len:size_nat{len <= 32})
  (block:lseq uint8 (lanes m * 256))
  (i:size_nat{start + i * 32 + len <= outputByteLen /\
              i * 128 + 128 <= 1024})
  (b:multiseq (lanes m) outputByteLen) :
  (multiseq (lanes m) outputByteLen) =
  assert (i * 128 + 32 + len <= 1024);
  let (l0, (l1, (l2, l3))) = tup4 b in
  let l0 = update_sub #uint8 #outputByteLen
    l0 (start + i * 32) len (sub block (i * 128) len) in
  let l1 = update_sub #uint8 #outputByteLen
    l1 (start + i * 32) len (sub block (i * 128 + 32) len) in
  let l2 = update_sub #uint8 #outputByteLen
    l2 (start + i * 32) len (sub block (i * 128 + 64) len) in
  let l3 = update_sub #uint8 #outputByteLen
    l3 (start + i * 32) len (sub block (i * 128 + 96) len) in
  ntup4 (l0, (l1, (l2, l3)))

val store_block4_s: 
  m:m_spec -> outputByteLen:size_nat -> start:size_nat ->
  len:size_nat{len <= 32} -> block:lseq uint8 (lanes m * 256) ->
  i:size_nat{i <= (outputByteLen - start) / 32 /\ i <= 256 / 32} -> Type0
let store_block4_s m outputByteLen start len block i = multiseq (lanes m) outputByteLen

let store_output4
  (#m:m_spec{lanes m == 4})
  (outputByteLen:size_nat)
  (start:size_nat)
  (len:size_nat{start + len <= outputByteLen /\ len <= 256})
  (block:lseq uint8 (lanes m * 256))
  (b:multiseq (lanes m) outputByteLen) :
  (multiseq (lanes m) outputByteLen) =
  let outBlocks = len / 32 in
  let b = repeat_gen outBlocks (store_block4_s m outputByteLen start 32 block)
    (store_block4 #m outputByteLen start 32 block) b in
  let b = if (len % 32 > 0)
    then store_block4 #m outputByteLen start (len % 32) block (len / 32) b else b in
  b

noextract
let update_b1 (#m:m_spec{lanes m == 1})
              (block:lseq uint8 (lanes m * 256))
              (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
              (outputByteLen:size_nat)
              (i:size_nat{i < outputByteLen / rateInBytes})
              (b:multiseq (lanes m) outputByteLen):
              multiseq (lanes m) outputByteLen =
  assert (i * rateInBytes < outputByteLen);
  assert (i + 1 <= outputByteLen / rateInBytes);
  assert ((i + 1) * rateInBytes <= outputByteLen);
  assert (i * rateInBytes + rateInBytes <= outputByteLen);
  let l = tup1 b in
  let l = update_sub #uint8 #outputByteLen 
    l (i * rateInBytes) rateInBytes (sub block 0 rateInBytes) in
  ntup1 l

noextract
let update_b4 (#m:m_spec{lanes m == 4})
              (block:lseq uint8 (lanes m * 256))
              (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
              (outputByteLen:size_nat)
              (i:size_nat{i < outputByteLen / rateInBytes})
              (b:multiseq (lanes m) outputByteLen):
              multiseq (lanes m) outputByteLen =
  store_output4 #m outputByteLen (i * rateInBytes) rateInBytes block b

noextract
let update_b (#m:m_spec{is_supported m})
             (block:lseq uint8 (lanes m * 256))
             (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
             (outputByteLen:size_nat)
             (i:size_nat{i < outputByteLen / rateInBytes})
             (b:multiseq (lanes m) outputByteLen):
             multiseq (lanes m) outputByteLen =
  match lanes m with
  | 1 -> update_b1 #m block rateInBytes outputByteLen i b
  | 4 -> update_b4 #m block rateInBytes outputByteLen i b

noextract
let update_b_last1 (#m:m_spec{lanes m == 1})
              (block:lseq uint8 (lanes m * 256))
              (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
              (outputByteLen:size_nat)
              (outRem:size_nat{outRem == outputByteLen % rateInBytes})
              (b:multiseq (lanes m) outputByteLen):
              multiseq (lanes m) outputByteLen =
  assert (outputByteLen / rateInBytes <= outputByteLen);
  let l = tup1 b in
  let l = update_sub #uint8 #outputByteLen 
    l (outputByteLen - outRem) outRem (sub block 0 outRem) in
  ntup1 l

noextract
let update_b_last4 (#m:m_spec{lanes m == 4})
              (block:lseq uint8 (lanes m * 256))
              (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
              (outputByteLen:size_nat)
              (outRem:size_nat{outRem == outputByteLen % rateInBytes})
              (b:multiseq (lanes m) outputByteLen):
              multiseq (lanes m) outputByteLen =
  store_output4 #m outputByteLen (outputByteLen - outRem) outRem block b

noextract
let update_b_last (#m:m_spec{is_supported m})
             (block:lseq uint8 (lanes m * 256))
             (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
             (outputByteLen:size_nat)
             (outRem:size_nat{outRem == outputByteLen % rateInBytes})
             (b:multiseq (lanes m) outputByteLen):
             multiseq (lanes m) outputByteLen =
  match lanes m with
  | 1 -> update_b_last1 #m block rateInBytes outputByteLen outRem b
  | 4 -> update_b_last4 #m block rateInBytes outputByteLen outRem b

let squeeze_inner
  (#a:keccak_alg)
  (#m:m_spec{is_supported m})
  (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
  (outputByteLen:size_nat)
  (i:size_nat{i < outputByteLen / rateInBytes})
  (s, b) :
  ((state m) & (multiseq (lanes m) outputByteLen)) =

  let block = storeState #a #m s in
  let b = update_b #m block rateInBytes outputByteLen i b in
  let s = state_permute m s in
  s, b

val squeeze_s: 
  m:m_spec -> rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256} ->
  outputByteLen:size_nat -> i:size_nat{i <= outputByteLen / rateInBytes} -> Type0
let squeeze_s m rateInBytes outputByteLen i = (state m) & (multiseq (lanes m) outputByteLen)

let squeeze_nblocks
  (#a:keccak_alg)
  (#m:m_spec{is_supported m})
  (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
  (outputByteLen:size_nat)
  (s, b) :
  ((state m) & (multiseq (lanes m) outputByteLen)) =
  let outBlocks = outputByteLen / rateInBytes in
  repeat_gen outBlocks (squeeze_s m rateInBytes outputByteLen)
    (squeeze_inner #a #m rateInBytes outputByteLen) (s, b)

let squeeze_last
  (#a:keccak_alg)
  (#m:m_spec{is_supported m})
  (s:state m)
  (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
  (outputByteLen:size_nat)
  (b:multiseq (lanes m) outputByteLen) :
  Tot (multiseq (lanes m) outputByteLen) =
  let remOut = outputByteLen % rateInBytes in
  let block = storeState #a #m s in
  update_b_last #m block rateInBytes outputByteLen remOut b

let squeeze
  (#a:keccak_alg)
  (#m:m_spec{is_supported m})
  (s:state m)
  (rateInBytes:size_nat{0 < rateInBytes /\ rateInBytes <= 256})
  (outputByteLen:size_nat)
  (b:multiseq (lanes m) outputByteLen) :
  Tot (multiseq (lanes m) outputByteLen) =
  let s, b = squeeze_nblocks #a #m rateInBytes outputByteLen (s, b) in
  squeeze_last #a #m s rateInBytes outputByteLen b

val keccak:
    #a:keccak_alg
  -> #m:m_spec{is_supported m}
  -> rate:size_nat{rate % 8 == 0 /\ rate / 8 > 0 /\ rate <= 2048}
  -> inputByteLen:nat
  -> input:multiseq (lanes m) inputByteLen
  -> delimitedSuffix:byte_t
  -> outputByteLen:size_nat
  -> b:multiseq (lanes m) outputByteLen ->
  Tot (multiseq (lanes m) outputByteLen)

let keccak #a #m rate inputByteLen input delimitedSuffix outputByteLen b =
  let rateInBytes = rate / 8 in
  let s = create 25 (zero_element m) in
  let s = absorb #a #m s rateInBytes inputByteLen input delimitedSuffix in
  squeeze #a #m s rateInBytes outputByteLen b

let shake128
  (inputByteLen:nat)
  (input:seq uint8{length input == inputByteLen})
  (outputByteLen:size_nat)
  (output:seq uint8{length output == outputByteLen}) :
  Tot (lbytes outputByteLen) =

  keccak #Shake128 #M32 1344 inputByteLen input (byte 0x1F) outputByteLen output

let shake128_4
  (inputByteLen:nat)
  (input:multiseq 4 inputByteLen)
  (outputByteLen:size_nat)
  (output:multiseq 4 outputByteLen) :
  Tot (multiseq 4 outputByteLen) =

  keccak #Shake128 #M256 1344 inputByteLen input (byte 0x1F) outputByteLen output

let shake256
  (inputByteLen:nat)
  (input:seq uint8{length input == inputByteLen})
  (outputByteLen:size_nat)
  (output:seq uint8{length output == outputByteLen}) :
  Tot (lbytes outputByteLen) =

  keccak #Shake256 #M32 1088 inputByteLen input (byte 0x1F) outputByteLen output

let shake256_4
  (inputByteLen:nat)
  (input:multiseq 4 inputByteLen)
  (outputByteLen:size_nat)
  (output:multiseq 4 outputByteLen) :
  Tot (multiseq 4 outputByteLen) =

  keccak #Shake256 #M256 1088 inputByteLen input (byte 0x1F) outputByteLen output

let sha3_224
  (inputByteLen:nat)
  (input:seq uint8{length input == inputByteLen})
  (output:seq uint8{length output == 28}) :
  Tot (lbytes 28) =

  keccak #SHA3_224 #M32 1152 inputByteLen input (byte 0x06) 28 output

let sha3_224_4
  (inputByteLen:nat)
  (input:multiseq 4 inputByteLen)
  (output:multiseq 4 28) :
  Tot (multiseq 4 28) =

  keccak #SHA3_224 #M256 1152 inputByteLen input (byte 0x06) 28 output

let sha3_256
  (inputByteLen:nat)
  (input:seq uint8{length input == inputByteLen})
  (output:seq uint8{length output == 32}) :
  Tot (lbytes 32) =

  keccak #SHA3_256 #M32 1088 inputByteLen input (byte 0x06) 32 output

let sha3_256_4
  (inputByteLen:nat)
  (input:multiseq 4 inputByteLen)
  (output:multiseq 4 32) :
  Tot (multiseq 4 32) =

  keccak #SHA3_256 #M256 1088 inputByteLen input (byte 0x06) 32 output

let sha3_384
  (inputByteLen:nat)
  (input:seq uint8{length input == inputByteLen})
  (output:seq uint8{length output == 48}) :
  Tot (lbytes 48) =

  keccak #SHA3_384 #M32 832 inputByteLen input (byte 0x06) 48 output

let sha3_384_4
  (inputByteLen:nat)
  (input:multiseq 4 inputByteLen)
  (output:multiseq 4 48) :
  Tot (multiseq 4 48) =

  keccak #SHA3_384 #M256 832 inputByteLen input (byte 0x06) 48 output

let sha3_512
  (inputByteLen:nat)
  (input:seq uint8{length input == inputByteLen})
  (output:seq uint8{length output == 64}) :
  Tot (lbytes 64) =

  keccak #SHA3_512 #M32 576 inputByteLen input (byte 0x06) 64 output

let sha3_512_4
  (inputByteLen:nat)
  (input:multiseq 4 inputByteLen)
  (output:multiseq 4 64) :
  Tot (multiseq 4 64) =

  keccak #SHA3_512 #M256 576 inputByteLen input (byte 0x06) 64 output
