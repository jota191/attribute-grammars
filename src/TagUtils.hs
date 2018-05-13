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
             TypeFamilies
#-}

module TagUtils where
import Data.Tagged

data Label l = Label


labelLVPair :: Tagged (k1,k2) v -> Label (k1,k2)
labelLVPair _ = Label

sndLabel :: Label (a,b) -> Label b
sndLabel _ = undefined
unTaggedChAtt :: Tagged l v -> v
unTaggedChAtt (Tagged v) = v
labelTChAtt :: Tagged l v -> Label l
labelTChAtt _ = Label
