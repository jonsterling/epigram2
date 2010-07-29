\section{Developments}
\label{sec:developments}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE FlexibleInstances, TypeOperators, GADTs , StandaloneDeriving #-}

> module ProofState.Structure.Developments where

> import Data.Foldable
> import Data.List
> import Data.Traversable

> import Kit.BwdFwd

> import NameSupply.NameSupply

> import Evidences.Tm

> import Elaboration.ElabMonad

> import DisplayLang.Scheme

%endif


\subsection{The |Dev| data-structure}


A |Dev|elopment is a structure containing entries, some of which may
have their own developments, creating a nested tree-like
structure. Developments can be of different nature: this is indicated
by the |Tip|. A development also keeps a |NameSupply| at hand, for
namespace handling purposes. Initially we had the following
definition:

< type Dev = (Bwd Entry, Tip, NameSupply)

but generalised this to allow other |Traversable| functors |f| in
place of |Bwd|, and to store a |SuspendState|, giving:

> data Dev f = Dev  {  devEntries       :: f (Entry f)
>                   ,  devTip           :: Tip
>                   ,  devNSupply       :: NameSupply
>                   ,  devSuspendState  :: SuspendState
>                   }

%if False

> deriving instance Show (Dev Fwd)
> deriving instance Show (Dev Bwd)

%endif


\subsubsection{|Tip|}

Let us review the different kind of Developments available. The first
kind is a |Module|. A module is a development that cannot have a type
or value. It simply packs up some other developments. 

A development can also be an |Unknown| term of a given type -- the
type being presented both as a term and as a value (for performance
purposes). This is a typical case of \emph{development}: we are
currently building an unknown satisfying the given type.

Finally, a development can be finalised, in which case it is
|Defined|: it has built a term satisfying the given type.

\pierre{What about |Suspended|?}

> data Tip
>   = Module
>   | Unknown (INTM :=>: TY)
>   | Suspended (INTM :=>: TY) EProb
>   | Defined INTM (INTM :=>: TY)
>   deriving Show


\subsubsection{|Entry|}
\label{sec:developments_entry}

As mentionned above, a |Dev| is a kind of tree. The branches are
introduced by the container |f (Entry f)| where |f| is Traversable,
typically a backward list. 

An |Entry| leaves a choice of shape for the branches. Indeed, it can
either be:

\begin{itemize}

\item an |Entity| with a |REF|, the last component of its |Name|
(playing the role of a cache, for performance reasons), and the term
representation of its type, or

\item a module, ie. a |Name| associated with a |Dev| that has no type
or value

\end{itemize}

> data Traversable f => Entry f
>   =  E REF (String, Int) (Entity f) INTM
>   |  M Name (Dev f)

In the Module case, we have already tied the knot, by defining |M|
with a sub-development. In the Entity case, we give yet another choice
of shape, thanks to the |Entity f| constructor. This constructor is
defined in the next section.

Typically, we work with developments that use backwards lists, hence
|f| is |Bwd|:

> type Entries = Bwd (Entry Bwd)


%if False

> instance Show (Entry Bwd) where
>     show (E ref xn e t) = intercalate " " ["E", show ref, show xn, show e, show t]
>     show (M n d) = intercalate " " ["M", show n, show d]
> instance Show (Entry Fwd) where
>     show (E ref xn e t) = intercalate " " ["E", show ref, show xn, show e, show t]
>     show (M n d) = intercalate " " ["M", show n, show d]

%endif

\begin{danger}[Name caching]

We have mentionned above that an Entity |E| caches the last component
of its |Name| in the |(String, Int)| field. Indeed, grabing that
information asks for traversing the whole |Name| up to the last
element:

> lastName :: REF -> (String, Int)
> lastName (n := _) = last n

As we will need it quite frequently for display purposes, we extract
it once and for all with |lastName| and later rely on the cached version.

\end{danger}

\subsubsection{|Entity|}

An |Entity| is either a |Parameter| or a |Definition|. A |Definition|
can have children, that is sub-developments, whereas a |Parameter|
cannot.

> data Traversable f => Entity f
>   =  Parameter   ParamKind
>   |  Definition  DefKind (Dev f)


\paragraph{Kinds of Definitions:}

A \emph{definition} eventually constructs a term, by a (possibly
empty) development of sub-objects. The |Tip| of this sub-development
will either be of |Unknown| or |Defined| kind. \pierre{Can the Tip be
|Suspended|? I suspect so.}

A programming problem is a special kind of definition: it follows a
type |Scheme| (Section~\ref{sec:display-scheme}), the high-level type
of the function we are implementing.

> data DefKind = LETG |  PROG (Scheme INTM)

%if False

> instance Show DefKind where
>     show LETG      = "LETG"
>     show (PROG _)  = "PROG"

%endif


\paragraph{Kinds of Parameters:}

A \emph{parameter} is either a $\lambda$, $\forall$ or $\Pi$
abstraction. It scopes over all following entries and the definitions
(if any) in the enclosing development.

> data ParamKind = LAMB | ALAB | PIB deriving (Show, Eq)


%if False

> instance Show (Entity Bwd) where
>     show (Parameter k) = "Param " ++ show k
>     show (Definition k d) = "Def " ++ show k ++ " " ++ show d

> instance Show (Entity Fwd) where
>     show (Parameter k) = "Param " ++ show k
>     show (Definition k d) = "Def " ++ show k ++ " " ++ show d 

%endif

\subsubsection{Suspension states}

Girls may have suspended elaboration processes attached, indicated by a
|Suspended| tip. These may be stable or unstable. For efficiency in the
scheduler, each development stores the state of its least stable child.

> data SuspendState = SuspendUnstable | SuspendStable | SuspendNone
>   deriving (Eq, Show, Enum, Ord)
