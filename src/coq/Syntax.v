(* Copyright (c) 2009, Adam Chlipala
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * - The names of contributors may not be used to endorse or promote products
 *   derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *)

Set Implicit Arguments.


Definition name := nat.


(** Syntax of Featherweight Ur *)

Inductive kind : Type :=
| KType : kind
| KName : kind
| KArrow : kind -> kind -> kind
| KRecord : kind -> kind.

Section vars.
  Variable cvar : kind -> Type.

  Inductive con : kind -> Type :=
  | CVar : forall k, cvar k -> con k
  | Arrow : con KType -> con KType -> con KType
  | Poly : forall k, (cvar k -> con KType) -> con KType
  | CAbs : forall k1 k2, (cvar k1 -> con k2) -> con (KArrow k1 k2)
  | CApp : forall k1 k2, con (KArrow k1 k2) -> con k1 -> con k2
  | Name : name -> con KName
  | TRecord : con (KRecord KType) -> con KType
  | CEmpty : forall k, con (KRecord k)
  | CSingle : forall k, con KName -> con k -> con (KRecord k)
  | CConcat : forall k, con (KRecord k) -> con (KRecord k) -> con (KRecord k)
  | CFold : forall k1 k2, con (KArrow (KArrow KName (KArrow k1 (KArrow k2 k2)))
    (KArrow k2 (KArrow (KRecord k1) k2)))
  | CGuarded : forall k1 k2, con (KRecord k1) -> con (KRecord k1) -> con k2 -> con k2.

  Variable dvar : forall k, con (KRecord k) -> con (KRecord k) -> Type.

  Section subs.
    Variable k1 : kind.
    Variable c1 : con k1.

    Inductive subs : forall k2, (cvar k1 -> con k2) -> con k2 -> Type :=
    | S_Unchanged : forall k2 (c2 : con k2),
      subs (fun _ => c2) c2
    | S_CVar : subs (fun x => CVar x) c1
    | S_Arrow : forall c2 c3 c2' c3',
      subs c2 c2'
      -> subs c3 c3'
      -> subs (fun x => Arrow (c2 x) (c3 x)) (Arrow c2' c3')
    | S_Poly : forall k (c2 : cvar k1 -> cvar k -> _) (c2' : cvar k -> _),
      (forall x', subs (fun x => c2 x x') (c2' x'))
      -> subs (fun x => Poly (c2 x)) (Poly c2')
    | S_CAbs : forall k2 k3 (c2 : cvar k1 -> cvar k2 -> con k3) (c2' : cvar k2 -> _),
      (forall x', subs (fun x => c2 x x') (c2' x'))
      -> subs (fun x => CAbs (c2 x)) (CAbs c2')
    | S_CApp : forall k1 k2 (c2 : _ -> con (KArrow k1 k2)) c3 c2' c3',
      subs c2 c2'
      -> subs c3 c3'
      -> subs (fun x => CApp (c2 x) (c3 x)) (CApp c2' c3')
    | S_TRecord : forall c2 c2',
      subs c2 c2'
      -> subs (fun x => TRecord (c2 x)) (TRecord c2')
    | S_CSingle : forall k2 c2 (c3 : _ -> con k2) c2' c3',
      subs c2 c2'
      -> subs c3 c3'
      -> subs (fun x => CSingle (c2 x) (c3 x)) (CSingle c2' c3')
    | S_CConcat : forall k2 (c2 c3 : _ -> con (KRecord k2)) c2' c3',
      subs c2 c2'
      -> subs c3 c3'
      -> subs (fun x => CConcat (c2 x) (c3 x)) (CConcat c2' c3')
    | S_CGuarded : forall k2 k3 (c2 c3 : _ -> con (KRecord k2)) (c4 : _ -> con k3) c2' c3' c4',
      subs c2 c2'
      -> subs c3 c3'
      -> subs c4 c4'
      -> subs (fun x => CGuarded (c2 x) (c3 x) (c4 x)) (CGuarded c2' c3' c4').
  End subs.

  Inductive disj : forall k, con (KRecord k) -> con (KRecord k) -> Prop :=
  | DVar : forall k (c1 c2 : con (KRecord k)),
    dvar c1 c2 -> disj c1 c2
  | DComm : forall k (c1 c2 : con (KRecord k)),
    disj c1 c2 -> disj c2 c1

  | DEmpty : forall k c2,
    disj (CEmpty k) c2
  | DSingleKeys : forall k X1 X2 (c1 c2 : con k),
    X1 <> X2
    -> disj (CSingle (Name X1) c1) (CSingle (Name X2) c2)
  | DSingleValues : forall k n1 n2 (c1 c2 : con k) k' (c1' c2' : con k'),
    disj (CSingle n1 c1') (CSingle n2 c2')
    -> disj (CSingle n1 c1) (CSingle n2 c2)

  | DConcat : forall k (c1 c2 c : con (KRecord k)),
    disj c1 c
    -> disj c2 c
    -> disj (CConcat c1 c2) c

  | DEq : forall k (c1 c2 c1' : con (KRecord k)),
    disj c1 c2
    -> deq c1 c1'
    -> disj c1' c2

  with deq : forall k, con k -> con k -> Prop :=
  | Eq_Beta : forall k1 k2 (c1 : cvar k1 -> con k2) c2 c1',
    subs c2 c1 c1'
    -> deq (CApp (CAbs c1) c2) c1'
  | Eq_Refl : forall k (c : con k),
    deq c c
  | Eq_Comm : forall k (c1 c2 : con k),
    deq c2 c1
    -> deq c1 c2
  | Eq_Trans : forall k (c1 c2 c3 : con k),
    deq c1 c2
    -> deq c2 c3
    -> deq c1 c3
  | Eq_Cong : forall k1 k2 c1 c1' (c2 : cvar k1 -> con k2) c2' c2'',
    deq c1 c1'
    -> subs c1 c2 c2'
    -> subs c1' c2 c2''
    -> deq c2' c2''

  | Eq_Concat_Empty : forall k c,
    deq (CConcat (CEmpty k) c) c
  | Eq_Concat_Comm : forall k (c1 c2 : con (KRecord k)),
    deq (CConcat c1 c2) (CConcat c2 c1)
  | Eq_Concat_Assoc : forall k (c1 c2 c3 : con (KRecord k)),
    deq (CConcat c1 (CConcat c2 c3)) (CConcat (CConcat c1 c2) c3)

  | Eq_Fold_Empty : forall k1 k2 f i,
    deq (CApp (CApp (CApp (CFold k1 k2) f) i) (CEmpty _)) i
  | Eq_Fold_Cons : forall k1 k2 f i c1 c2 c3,
    deq (CApp (CApp (CApp (CFold k1 k2) f) i) (CConcat (CSingle c1 c2) c3))
    (CApp (CApp (CApp f c1) c2) (CApp (CApp (CApp (CFold k1 k2) f) i) c3))

  | Eq_Guarded : forall k1 k2 (c1 c2 : con (KRecord k1)) (c : con k2),
    disj c1 c2
    -> deq (CGuarded c1 c2 c) c

  | Eq_Map_Ident : forall k c,
    deq (CApp (CApp (CApp (CFold k (KRecord k))
      (CAbs (fun x1 => CAbs (fun x2 => CAbs (fun x3 => CConcat (CSingle (CVar x1) (CVar x2)) (CVar x3))))))
    (CEmpty _)) c) c
  | Eq_Map_Dist : forall k1 k2 f c1 c2,
    deq (CApp (CApp (CApp (CFold k1 (KRecord k2))
      (CAbs (fun x1 => CAbs (fun x2 => CAbs (fun x3 => CConcat (CSingle (CVar x1) (CApp f (CVar x2))) (CVar x3))))))
    (CEmpty _)) (CConcat c1 c2))
    (CConcat
      (CApp (CApp (CApp (CFold k1 (KRecord k2))
        (CAbs (fun x1 => CAbs (fun x2 => CAbs (fun x3 => CConcat (CSingle (CVar x1) (CApp f (CVar x2))) (CVar x3))))))
      (CEmpty _)) c1)
      (CApp (CApp (CApp (CFold k1 (KRecord k2))
        (CAbs (fun x1 => CAbs (fun x2 => CAbs (fun x3 => CConcat (CSingle (CVar x1) (CApp f (CVar x2))) (CVar x3))))))
      (CEmpty _)) c2))

  | Eq_Fold_Fuse : forall k1 k2 k3 f i f' c,
    deq (CApp (CApp (CApp (CFold k1 k2) f) i)
      (CApp (CApp (CApp (CFold k3 (KRecord k1))
        (CAbs (fun x1 => CAbs (fun x2 => CAbs (fun x3 => CConcat (CSingle (CVar x1) (CApp f' (CVar x2))) (CVar x3))))))
      (CEmpty _)) c))
    (CApp (CApp (CApp (CFold k3 k2)
      (CAbs (fun x1 => CAbs (fun x2 => CApp (CApp f (CVar x1)) (CApp f' (CVar x2))))))
      i) c).

  Inductive wf : forall k, con k -> Type :=
  | HK_CVar : forall k (x : cvar k),
    wf (CVar x)
  | HK_Arrow : forall c1 c2,
    wf c1 -> wf c2 -> wf (Arrow c1 c2)
  | HK_Poly : forall k (c1 : cvar k -> _),
    (forall x, wf (c1 x)) -> wf (Poly c1)
  | HK_CAbs : forall k1 k2 (c1 : cvar k1 -> con k2),
    (forall x, wf (c1 x)) -> wf (CAbs c1)
  | HK_CApp : forall k1 k2 (c1 : con (KArrow k1 k2)) c2,
    wf c1 -> wf c2 -> wf (CApp c1 c2)
  | HK_Name : forall X,
    wf (Name X)
  | HK_TRecord : forall c,
    wf c -> wf (TRecord c)
  | HK_CEmpty : forall k,
    wf (CEmpty k)
  | HK_CSingle : forall k c1 (c2 : con k),
    wf c1 -> wf c2 -> wf (CSingle c1 c2)
  | HK_CConcat : forall k (c1 c2 : con (KRecord k)),
    wf c2 -> wf c2 -> disj c1 c2 -> wf (CConcat c1 c2)
  | HK_CFold : forall k1 k2,
    wf (CFold k1 k2)
  | HK_CGuarded : forall k1 k2 (c1 c2 : con (KRecord k1)) (c : con k2),
    wf c1 -> wf c2 -> (disj c1 c2 -> wf c) -> wf (CGuarded c1 c2 c).
End vars.