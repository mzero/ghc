%
% (c) The University of Glasgow 2001-2006
%
\begin{code}
module ExternalCore where

data Module 
 = Module Mname [Tdef] [Vdefg]

data Tdef 
  = Data (Qual Tcon) [Tbind] [Cdef]
  | Newtype (Qual Tcon) (Qual Tcon) [Tbind] Ty

data Cdef 
  = Constr (Qual Dcon) [Tbind] [Ty]
  | GadtConstr (Qual Dcon) Ty

data Vdefg 
  = Rec [Vdef]
  | Nonrec Vdef

-- Top-level bindings are qualified, so that the printer doesn't have to pass
-- around the module name.
type Vdef = (Bool,Qual Var,Ty,Exp)

data Exp 
  = Var (Qual Var)
  | Dcon (Qual Dcon)
  | Lit Lit
  | App Exp Exp
  | Appt Exp Ty
  | Lam Bind Exp 	  
  | Let Vdefg Exp
  | Case Exp Vbind Ty [Alt] {- non-empty list -}
  | Cast Exp Ty
  | Note String Exp
  | External String String Ty {- target name, convention, and type -} 
  | DynExternal String Ty {- convention and type (incl. Addr# of target as first arg) -} 
  | Label String

data Bind 
  = Vb Vbind
  | Tb Tbind

data Alt 
  = Acon (Qual Dcon) [Tbind] [Vbind] Exp
  | Alit Lit Exp
  | Adefault Exp

type Vbind = (Var,Ty)
type Tbind = (Tvar,Kind)

-- Internally, we represent types and coercions separately; but for
-- the purposes of external core (at least for now) it's still
-- convenient to collapse them into a single type.
data Ty 
  = Tvar Tvar
  | Tcon (Qual Tcon)
  | Tapp Ty Ty
  | Tforall Tbind Ty 
-- We distinguish primitive coercions because External Core treats
-- them specially, so we have to print them out with special syntax.
  | TransCoercion Ty Ty
  | SymCoercion Ty
  | UnsafeCoercion Ty Ty
  | InstCoercion Ty Ty
  | NthCoercion Int Ty

data Kind 
  = Klifted
  | Kunlifted
  | Kunboxed
  | Kopen
  | Karrow Kind Kind
  
data Lit 
  = Lint Integer Ty
  | Lrational Rational Ty
  | Lchar Char Ty
  | Lstring String Ty
  

type Mname = Id
type Var = Id
type Tvar = Id
type Tcon = Id
type Dcon = Id

type Qual t = (Mname,t)

type Id = String

primMname :: Mname
-- For truly horrible reasons, this must be z-encoded.
-- With any hope, the z-encoding will die soon.
primMname = "ghczmprim:GHCziPrim"

tcArrow :: Qual Tcon
tcArrow = (primMname, "(->)")

\end{code}




