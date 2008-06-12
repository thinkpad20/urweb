(* Copyright (c) 2008, Adam Chlipala
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

structure MonoUtil :> MONO_UTIL = struct

open Mono

structure S = Search

structure Typ = struct

fun mapfold fc =
    let
        fun mft c acc =
            S.bindP (mft' c acc, fc)

        and mft' (cAll as (c, loc)) =
            case c of
                TFun (t1, t2) =>
                S.bind2 (mft t1,
                      fn t1' =>
                         S.map2 (mft t2,
                              fn t2' =>
                                 (TFun (t1', t2'), loc)))
              | TRecord xts =>
                S.map2 (ListUtil.mapfold (fn (x, t) =>
                                             S.map2 (mft t,
                                                  fn t' =>
                                                     (x, t')))
                                         xts,
                     fn xts' => (TRecord xts', loc))
              | TNamed _ => S.return2 cAll
    in
        mft
    end

fun map typ c =
    case mapfold (fn c => fn () => S.Continue (typ c, ())) c () of
        S.Return () => raise Fail "Mono_util.Typ.map"
      | S.Continue (c, ()) => c

fun fold typ s c =
    case mapfold (fn c => fn s => S.Continue (c, typ (c, s))) c s of
        S.Continue (_, s) => s
      | S.Return _ => raise Fail "MonoUtil.Typ.fold: Impossible"

fun exists typ k =
    case mapfold (fn c => fn () =>
                             if typ c then
                                 S.Return ()
                             else
                                 S.Continue (c, ())) k () of
        S.Return _ => true
      | S.Continue _ => false

end

structure Exp = struct

datatype binder =
         NamedT of string * int * typ option
       | RelE of string * typ
       | NamedE of string * int * typ * exp option

fun mapfoldB {typ = fc, exp = fe, bind} =
    let
        val mft = Typ.mapfold fc

        fun mfe ctx e acc =
            S.bindP (mfe' ctx e acc, fe ctx)

        and mfe' ctx (eAll as (e, loc)) =
            case e of
                EPrim _ => S.return2 eAll
              | ERel _ => S.return2 eAll
              | ENamed _ => S.return2 eAll
              | EApp (e1, e2) =>
                S.bind2 (mfe ctx e1,
                      fn e1' =>
                         S.map2 (mfe ctx e2,
                              fn e2' =>
                                 (EApp (e1', e2'), loc)))
              | EAbs (x, dom, ran, e) =>
                S.bind2 (mft dom,
                      fn dom' =>
                         S.bind2 (mft ran,
                               fn ran' =>
                                  S.map2 (mfe (bind (ctx, RelE (x, dom'))) e,
                                       fn e' =>
                                          (EAbs (x, dom', ran', e'), loc))))

              | ERecord xes =>
                S.map2 (ListUtil.mapfold (fn (x, e, t) =>
                                             S.bind2 (mfe ctx e,
                                                  fn e' =>
                                                     S.map2 (mft t,
                                                             fn t' =>
                                                                (x, e', t'))))
                                         xes,
                     fn xes' =>
                        (ERecord xes', loc))
              | EField (e, x) =>
                S.map2 (mfe ctx e,
                      fn e' =>
                         (EField (e', x), loc))
    in
        mfe
    end

fun mapfold {typ = fc, exp = fe} =
    mapfoldB {typ = fc,
              exp = fn () => fe,
              bind = fn ((), _) => ()} ()

fun mapB {typ, exp, bind} ctx e =
    case mapfoldB {typ = fn c => fn () => S.Continue (typ c, ()),
                   exp = fn ctx => fn e => fn () => S.Continue (exp ctx e, ()),
                   bind = bind} ctx e () of
        S.Continue (e, ()) => e
      | S.Return _ => raise Fail "MonoUtil.Exp.mapB: Impossible"

fun map {typ, exp} e =
    case mapfold {typ = fn c => fn () => S.Continue (typ c, ()),
                  exp = fn e => fn () => S.Continue (exp e, ())} e () of
        S.Return () => raise Fail "Mono_util.Exp.map"
      | S.Continue (e, ()) => e

fun fold {typ, exp} s e =
    case mapfold {typ = fn c => fn s => S.Continue (c, typ (c, s)),
                  exp = fn e => fn s => S.Continue (e, exp (e, s))} e s of
        S.Continue (_, s) => s
      | S.Return _ => raise Fail "MonoUtil.Exp.fold: Impossible"

fun exists {typ, exp} k =
    case mapfold {typ = fn c => fn () =>
                                    if typ c then
                                        S.Return ()
                                    else
                                        S.Continue (c, ()),
                  exp = fn e => fn () =>
                                    if exp e then
                                        S.Return ()
                                    else
                                        S.Continue (e, ())} k () of
        S.Return _ => true
      | S.Continue _ => false

end

structure Decl = struct

datatype binder = datatype Exp.binder

fun mapfoldB {typ = fc, exp = fe, decl = fd, bind} =
    let
        val mft = Typ.mapfold fc

        val mfe = Exp.mapfoldB {typ = fc, exp = fe, bind = bind}

        fun mfd ctx d acc =
            S.bindP (mfd' ctx d acc, fd ctx)

        and mfd' ctx (dAll as (d, loc)) =
            case d of
                DVal (x, n, t, e) =>
                S.bind2 (mft t,
                      fn t' =>
                         S.map2 (mfe ctx e,
                              fn e' =>
                                 (DVal (x, n, t', e'), loc)))
    in
        mfd
    end    

fun mapfold {typ = fc, exp = fe, decl = fd} =
    mapfoldB {typ = fc,
              exp = fn () => fe,
              decl = fn () => fd,
              bind = fn ((), _) => ()} ()

fun fold {typ, exp, decl} s d =
    case mapfold {typ = fn c => fn s => S.Continue (c, typ (c, s)),
                  exp = fn e => fn s => S.Continue (e, exp (e, s)),
                  decl = fn d => fn s => S.Continue (d, decl (d, s))} d s of
        S.Continue (_, s) => s
      | S.Return _ => raise Fail "MonoUtil.Decl.fold: Impossible"

end

structure File = struct

datatype binder = datatype Exp.binder

fun mapfoldB (all as {bind, ...}) =
    let
        val mfd = Decl.mapfoldB all

        fun mff ctx ds =
            case ds of
                nil => S.return2 nil
              | d :: ds' =>
                S.bind2 (mfd ctx d,
                         fn d' =>
                            let
                                val b =
                                    case #1 d' of
                                        DVal (x, n, t, e) => NamedE (x, n, t, SOME e)
                                val ctx' = bind (ctx, b)
                            in
                                S.map2 (mff ctx' ds',
                                     fn ds' =>
                                        d' :: ds')
                            end)
    in
        mff
    end

fun mapfold {typ = fc, exp = fe, decl = fd} =
    mapfoldB {typ = fc,
              exp = fn () => fe,
              decl = fn () => fd,
              bind = fn ((), _) => ()} ()

fun mapB {typ, exp, decl, bind} ctx ds =
    case mapfoldB {typ = fn c => fn () => S.Continue (typ c, ()),
                   exp = fn ctx => fn e => fn () => S.Continue (exp ctx e, ()),
                   decl = fn ctx => fn d => fn () => S.Continue (decl ctx d, ()),
                   bind = bind} ctx ds () of
        S.Continue (ds, ()) => ds
      | S.Return _ => raise Fail "MonoUtil.File.mapB: Impossible"

fun fold {typ, exp, decl} s d =
    case mapfold {typ = fn c => fn s => S.Continue (c, typ (c, s)),
                  exp = fn e => fn s => S.Continue (e, exp (e, s)),
                  decl = fn d => fn s => S.Continue (d, decl (d, s))} d s of
        S.Continue (_, s) => s
      | S.Return _ => raise Fail "MonoUtil.File.fold: Impossible"

end

end