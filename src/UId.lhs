\section{UId}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE TypeOperators, GADTs, KindSignatures,
>     TypeSynonymInstances, FlexibleInstances, ScopedTypeVariables #-}

> module UId where

%endif

> import -> CanConstructors where
>   UId    :: Can t
>   Tag    :: String -> Can t

> import -> CanPats where
>   pattern UID = C UId
>   pattern TAG s = C (Tag s)

> import -> TraverseCan where
>   traverse f UId          = (|EnumU|)
>   traverse f (Tag s)      = (|(Tag s)|)

> import -> CanTyRules where
>   canTy _  (Set :>: UId)    = return UId
>   canTy _  (UId :>: Tag s)  = return (Tag s)

> import -> OpRunEqGreen where
>   opRunEqGreen [UID,TAG s1,UID,TAG s2] | s1 == s2 = Right $ TRIVIAL
>   opRunEqGreen [UID,TAG _,UID,TAG _] = Right $ ABSURD
