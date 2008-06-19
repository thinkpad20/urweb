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

structure Expl = struct

type 'a located = 'a ErrorMsg.located

datatype kind' =
         KType
       | KArrow of kind * kind
       | KName
       | KRecord of kind

withtype kind = kind' located

datatype con' =
         TFun of con * con
       | TCFun of string * kind * con
       | TRecord of con

       | CRel of int
       | CNamed of int
       | CModProj of int * string list * string
       | CApp of con * con
       | CAbs of string * kind * con

       | CName of string

       | CRecord of kind * (con * con) list
       | CConcat of con * con

withtype con = con' located

datatype exp' =
         EPrim of Prim.t
       | ERel of int
       | ENamed of int
       | EModProj of int * string list * string
       | EApp of exp * exp
       | EAbs of string * con * con * exp
       | ECApp of exp * con
       | ECAbs of string * kind * exp

       | ERecord of (con * exp * con) list
       | EField of exp * con * { field : con, rest : con }

withtype exp = exp' located

datatype sgn_item' =
         SgiConAbs of string * int * kind
       | SgiCon of string * int * kind * con
       | SgiVal of string * int * con
       | SgiStr of string * int * sgn

and sgn' =
    SgnConst of sgn_item list
  | SgnVar of int

withtype sgn_item = sgn_item' located
and sgn = sgn' located

datatype decl' =
         DCon of string * int * kind * con
       | DVal of string * int * con * exp
       | DSgn of string * int * sgn
       | DStr of string * int * sgn * str

     and str' =
         StrConst of decl list
       | StrVar of int
       | StrProj of str * string

withtype decl = decl' located
     and str = str' located

type file = decl list

end