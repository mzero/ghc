%
% (c) The GRASP/AQUA Project, Glasgow University, 1992-1996
%
\section[IdUtils]{Constructing PrimOp Ids}

\begin{code}
#include "HsVersions.h"

module IdUtils ( primOpNameInfo, primOpId ) where

IMP_Ubiq()
IMPORT_DELOOPER(PrelLoop)		-- here for paranoia checking

import CoreSyn
import CoreUnfold	( UnfoldingGuidance(..) )
import Id		( mkImported, mkTemplateLocals )
import IdInfo		-- quite a few things
import Name		( mkPrimitiveName, OrigName(..) )
import PrelMods		( gHC_BUILTINS )
import PrimOp		( primOpInfo, tagOf_PrimOp, primOp_str,
			  PrimOpInfo(..), PrimOpResultInfo(..) )
import RnHsSyn		( RnName(..) )
import Type		( mkForAllTys, mkFunTy, mkFunTys, mkTyVarTy, applyTyCon )
import TysWiredIn	( boolTy )
import Unique		( mkPrimOpIdUnique )
import Util		( panic )
\end{code}

\begin{code}
primOpNameInfo :: PrimOp -> (FAST_STRING, RnName)
primOpId       :: PrimOp -> Id

primOpNameInfo op = (primOp_str  op, WiredInId (primOpId op))

primOpId op
  = case (primOpInfo op) of
      Dyadic str ty ->
	mk_prim_Id op str [] [ty,ty] (dyadic_fun_ty ty) 2

      Monadic str ty ->
	mk_prim_Id op str [] [ty] (monadic_fun_ty ty) 1

      Compare str ty ->
	mk_prim_Id op str [] [ty,ty] (compare_fun_ty ty) 2

      Coercing str ty1 ty2 ->
	mk_prim_Id op str [] [ty1] (ty1 `mkFunTy` ty2) 1

      PrimResult str tyvars arg_tys prim_tycon kind res_tys ->
	mk_prim_Id op str
	    tyvars
	    arg_tys
	    (mkForAllTys tyvars (mkFunTys arg_tys (applyTyCon prim_tycon res_tys)))
	    (length arg_tys) -- arity

      AlgResult str tyvars arg_tys tycon res_tys ->
	mk_prim_Id op str
	    tyvars
	    arg_tys
	    (mkForAllTys tyvars (mkFunTys arg_tys (applyTyCon tycon res_tys)))
	    (length arg_tys) -- arity
  where
    mk_prim_Id prim_op name tyvar_tmpls arg_tys ty arity
      = mkImported (mkPrimitiveName key (OrigName gHC_BUILTINS name)) ty
	   (noIdInfo `addInfo` (mkArityInfo arity)
	          `addInfo_UF` (mkUnfolding EssentialUnfolding
			         (mk_prim_unfold prim_op tyvar_tmpls arg_tys)))
      where
	key = mkPrimOpIdUnique (IBOX(tagOf_PrimOp prim_op))
\end{code}


\begin{code}
dyadic_fun_ty  ty = mkFunTys [ty, ty] ty
monadic_fun_ty ty = ty `mkFunTy` ty
compare_fun_ty ty = mkFunTys [ty, ty] boolTy
\end{code}

The functions to make common unfoldings are tedious.

\begin{code}
mk_prim_unfold :: PrimOp -> [TyVar] -> [Type] -> CoreExpr{-template-}

mk_prim_unfold prim_op tyvars arg_tys
  = let
	vars = mkTemplateLocals arg_tys
    in
    mkLam tyvars vars $
    Prim prim_op
	([TyArg (mkTyVarTy tv) | tv <- tyvars] ++ [VarArg v | v <- vars])
\end{code}

