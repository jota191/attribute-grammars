{-|
Module      : Language.Grammars.AspectAG.Attribute
Description : Named attributes, with polykinded labels
Copyright   : (c) Juan García Garland, 2018 
License     : LGPL
Maintainer  : jpgarcia@fing.edu.uy
Stability   : experimental
Portability : POSIX

Used to build attributions, which are mappings from labels to values
-}
{-# LANGUAGE DataKinds,
             TypeOperators,
             PolyKinds,
             GADTs,
             TypeInType,
             RankNTypes,
             StandaloneDeriving,
             FlexibleInstances,
             FlexibleContexts,
             ConstraintKinds,
             MultiParamTypeClasses,
             FunctionalDependencies,
             UndecidableInstances,
             ScopedTypeVariables,
             TypeFamilies,
             PatternSynonyms
#-}

module Language.Grammars.AspectAG.Attribute where
import Language.Grammars.AspectAG.TagUtils
import Language.Grammars.AspectAG.GenRecord

-- | An Attribute is actually isomprphic to a Tagged (from Data.Tagged).
--it contains a label (purelly phantom) and a value. Attribute has kind
--  k-> * -> *
-- l 
--newtype Attribute l value = Attribute { getVal :: value }
--                          deriving (Eq, Ord,Show)
 
--type Attribute = TagField AttReco
pattern Attribute :: v -> TagField AttReco l v
pattern Attribute v = TagField Label Label v


-- | Apretty constructor for an attribute 
infixr 4 =.

(=.) :: Label l -> v -> Attribute l v
Label =. v = Attribute v
