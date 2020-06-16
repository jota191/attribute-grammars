{-|
Module      : Language.Grammars.AspectAG
Description : Main module, First-class attribute grammars
Copyright   : (c) Juan García-Garland, Marcos Viera, 2019, 2020
License     : GPL
Maintainer  : jpgarcia@fing.edu.uy
Stability   : experimental
Portability : POSIX
-}

{-# LANGUAGE PolyKinds                 #-}
{-# LANGUAGE KindSignatures            #-}
{-# LANGUAGE DataKinds                 #-}
{-# LANGUAGE ConstraintKinds           #-}
{-# LANGUAGE RankNTypes                #-}
{-# LANGUAGE TypeOperators             #-}
{-# LANGUAGE FlexibleInstances         #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE GADTs                     #-}
{-# LANGUAGE UndecidableInstances      #-}
{-# LANGUAGE MultiParamTypeClasses     #-}
{-# LANGUAGE TypeFamilies              #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE ScopedTypeVariables       #-}
{-# LANGUAGE TypeFamilies              #-}
{-# LANGUAGE TypeApplications          #-}
{-# LANGUAGE FunctionalDependencies    #-}
{-# LANGUAGE TypeFamilyDependencies    #-}
{-# LANGUAGE PartialTypeSignatures     #-}
{-# LANGUAGE IncoherentInstances       #-}
{-# LANGUAGE AllowAmbiguousTypes       #-}
{-# LANGUAGE UnicodeSyntax             #-}

module Language.Grammars.AspectAG
  (

    -- -- * Rules
    -- Rule, CRule(..),
    
    -- -- ** Defining Rules
    -- syndef, syndefM, syn,
    
    -- synmod, synmodM,


    -- inh, inhdef, inhdefM,

    -- inhmod, inhmodM, 

    -- emptyRule,
    -- emptyRuleAtPrd,
    -- ext,
    
    -- -- * Aspects 
    -- -- ** Building Aspects.
    
    -- emptyAspect,
    -- singAsp,
    -- extAspect,
    -- comAspect,
    -- (.+:),(◃),
    -- (.:+.),(▹),
    -- (.:+:),(⋈),
    
    
    -- CAspect(..),
    -- Label(Label), Prod(..), T(..), NT(..), Child(..), Att(..),
    -- (.#), (#.), (=.), (.=), (.*), (*.),
    -- emptyAtt,
    -- ter,
    -- at, lhs,
    -- sem_Lit,
    -- knitAspect,
    -- traceAspect,
    -- traceRule,
    -- copyAtChi,
    -- use,
    -- emptyAspectC,
    -- emptyAspectForProds,
    -- module Data.GenRec,
    -- module Language.Grammars.AspectAG.HList
  )
  where


import Language.Grammars.AspectAG.HList
import Language.Grammars.AspectAG.RecordInstances

import Data.Type.Require hiding (emptyCtx)

import Data.GenRec
import Data.GenRec.Label

import Data.Kind
import Data.Proxy
import GHC.TypeLits

import Data.Maybe
import Data.Type.Equality
import Control.Monad.Reader

import Data.Singletons
import Data.Singletons.TH
import Data.Singletons.TypeLits
import Data.Singletons.Prelude.Ord
import Data.Singletons.Prelude.Eq
import Data.Singletons.CustomStar
import Data.Singletons.Decide

class SemLit a where
  sem_Lit :: a -> Attribution ('[] :: [(Att,Type)])
               -> Attribution '[ '( 'Att "term" a , a)]
  lit     :: Sing ('Att "term" a)
instance SemLit a where
  sem_Lit a _ = (SAtt (SSym :: Sing "term") undefined =. a) *. emptyAtt
  lit         = SAtt (SSym @ "term") undefined

type instance  WrapField PrdReco (CRule p a b c d e f :: Type)
  = CRule p a b c d e f

-- * Families and Rules

-- | In each node of the grammar, the "Fam" contains a single attribution
-- for the parent, and a collection (Record) of attributions for
-- the children:
data Fam (prd :: Prod)
         (c :: [(Child, [(Att, Type)])])
         (p :: [(Att, Type)]) :: Type
 where
  Fam :: Sing prd -> ChAttsRec prd c -> Attribution p -> Fam prd c p


-- | getter
chi :: Fam prd c p -> ChAttsRec prd c
chi (Fam _ c _) = c

-- | getter
par :: Fam prd c p -> Attribution p
par (Fam _ _  p) = p

-- | getter (extracts a 'Label')
prd :: Fam prd c p -> Sing prd
prd (Fam l _ _) = l

-- | Rules are a function from the input family to the output family,
-- with an extra arity to make them composable.  They are indexed by a production.
type Rule
  (prd  :: Prod)
  (sc   :: [(Child, [(Att, Type)])])
  (ip   :: [(Att,       Type)])
  (ic   :: [(Child, [(Att, Type)])])
  (sp   :: [(Att,       Type)])
  (ic'  :: [(Child, [(Att, Type)])])
  (sp'  :: [(Att,       Type)])
  = Fam prd sc ip -> Fam prd ic sp -> Fam prd ic' sp'

-- | Rules with context (used to print domain specific type errors).
data CRule prd sc ip ic sp ic' sp'
  = CRule { prod :: Sing prd,
            mkRule :: Rule prd sc ip ic sp ic' sp'}

emptyRule =
  CRule sing (\fam inp -> inp)

emptyRuleAtPrd :: Sing prd -> CRule prd sc ip ic' sp' ic' sp'
emptyRuleAtPrd prd = CRule prd (\fam inp -> inp)

-- | Aspects, tagged with context. 'Aspect' is a record instance having
-- productions as labels, containing 'Rule's as fields.
--newtype CAspect (asp :: [(Prod, Type)] )
--  = CAspect { mkAspect :: Proxy ctx -> Aspect asp}

-- | Recall that Aspects are mappings from productions to rules. They
-- have a record-like interface to build them. This is the constructor
-- for the empty Aspect.
emptyAspect :: Aspect '[]
emptyAspect  = EmptyRec

-- | combination of two Aspects. It merges them. When both aspects
-- have rules for a given production, in the resulting Aspect the rule
-- at that field is the combination of the rules for the arguments
-- (with 'ext').
-- comAspect ::
--   ( Require (OpComAsp al ar) ctx
--   , ReqR (OpComAsp al ar) ~ Aspect asp
--   )
--   =>  CAspect ctx al -> CAspect ctx ar -> CAspect ctx asp
-- comAspect al ar
--   = CAspect $ \ctx -> req ctx (OpComAsp (mkAspect al ctx) (mkAspect ar ctx))



ext' ::  CRule prd sc ip ic sp ic' sp'
     ->  CRule prd sc ip a b ic sp
     ->  CRule prd sc ip a b ic' sp'
(CRule p f) `ext'` (CRule _ g)
 = CRule p $ \input -> f input . g input


-- | Given two rules for a given (the same) production, it combines
-- them. Note that the production equality is visible in the context,
-- not sintactically. This is a use of the 'Require' pattern.
ext ::  RequireEq prd prd' (Text "ext":ctx) 
     => CRule prd sc ip ic sp ic' sp'
     -> CRule prd' sc ip a b ic sp
     -> CRule prd sc ip a b ic' sp'
ext = ext'

type family (r :: Type) :+. (r' :: Type) :: Type
type instance
 (CRule prd sc ip ic sp ic' sp') :+.
 (CRule prd sc ip a  b  ic  sp ) =
  CRule prd sc ip a  b  ic' sp'

type family
 ComRA  (rule :: Type) (r :: [(Prod, Type)]) :: [(Prod, Type)]
 where
  ComRA (CRule prd sc ip ic sp ic' sp') '[] =
    '[ '(prd, CRule prd sc ip ic sp ic' sp')]
  ComRA (CRule prd sc ip ic sp ic' sp')
         ( '(prd', CRule prd' sc ip a  b  ic  sp ) ': r) =
    FoldOrdering (Compare prd prd')
     {-LT-} (  '(prd, CRule prd sc ip ic sp ic' sp')
            ': '(prd', CRule prd' sc ip a  b  ic  sp )
            ': r)
    
     {-EQ-} ( '(prd, (CRule prd sc ip ic sp ic' sp')
                 :+. (CRule prd' sc ip a  b  ic  sp))
            ': r)

     {-GT-} ('(prd', CRule prd' sc ip a  b  ic  sp)
            ':  ComRA (CRule prd sc ip ic sp ic' sp') r)


class ExtAspect r a where
  extAspect
   :: r
   -> Aspect (a :: [(Prod, Type)])
   -> Aspect (ComRA r a)

instance ExtAspect (CRule prd sc ip ic sp ic' sp') '[] where
  extAspect cr@(CRule p r) EmptyRec = ConsRec (TagField Proxy p cr) EmptyRec

decideEquality :: forall k (a :: k) (b :: k). SDecide k
               => Sing a -> Sing b -> Maybe (a :~: b)
decideEquality a b =
  case a %~ b of
    Proved Refl -> Just Refl
    Disproved _ -> Nothing

instance 
         (ExtAspect (CRule prd sc ip ic sp ic' sp') a)
         -- solo llamo en un caso
  =>
  ExtAspect (CRule prd sc ip ic sp ic' sp')
            ('(prd', CRule prd' sc ip a1 b  ic  sp ) ': a) where
  extAspect cr@((CRule p r) :: CRule prd sc ip ic sp ic' sp')
            re@(ConsRec lv@(TagField _ p' r') rs) =
    case sCompare p p' of
      SLT -> ConsRec (TagField Proxy p cr) re
      SEQ -> case decideEquality p p' of
               Just Refl -> ConsRec (TagField Proxy p (cr `ext` r')) rs
      SGT -> ConsRec lv (extAspect cr rs)

-- | An operator, alias for 'extAspect'. It combines a rule with an
-- aspect, to build a bigger one.
(.+:) = extAspect
infixr 3 .+:

-- | Unicode version of 'extAspect' or '.+:' (\\triangleleft)
(◃) = extAspect
infixr 3 ◃

-- | The other way, combines an aspect with a rule. It is a `flip`ped
-- 'extAspect'.
(.:+.) = flip extAspect
infixl 3 .:+.

-- | Unicode operator for '.:+.' or `flip extAspect`.
(▹) = flip extAspect
infixl 3 ▹


type family
  ComAsp (r1 :: [(Prod, Type)]) (r2 :: [(Prod, Type)]) :: [(Prod, Type)]
 where
  ComAsp '[] r2 = r2
  ComAsp r1 '[] = r1
  ComAsp ('(prd1, CRule prd1 sc1 ip1 ic1 sp1 ic1' sp1') ': r1)
         ('(prd2, CRule prd2 sc2 ip2 ic2 sp2 ic2' sp2') ': r2) =
    FoldOrdering (Compare prd1 prd2)
    {-LT-} ('(prd1, CRule prd1 sc1 ip1 ic1 sp1 ic1' sp1')
           ': ComAsp r1 ('(prd2, CRule prd2 sc2 ip2 ic2 sp2 ic2' sp2') ': r2)
           ) 
    {-EQ-} ( '(prd1, CRule prd1 sc1 ip1 ic1 sp1 ic1' sp1'
                     :+. CRule prd2 sc2 ip2 ic2 sp2 ic2' sp2')
           ': ComAsp r1 r2
           )
    {-GT-} ('(prd2, CRule prd2 sc2 ip2 ic2 sp2 ic2' sp2')
           ': ComAsp ('(prd1, CRule prd1 sc1 ip1 ic1 sp1 ic1' sp1') ': r1) r2
           )

class ComAspect (r1 :: [(Prod, Type)])(r2 :: [(Prod, Type)]) where
  comAspect :: Aspect r1 -> Aspect r2 -> Aspect (ComAsp r1 r2)
instance ComAspect '[] r2 where
  comAspect _ r = r
instance ComAspect r1 '[] where
  comAspect r _= r

instance
  (ComAspect' (Compare prd1 prd2)
       ('(prd1, CRule prd1 sc1 ip1 ic1 sp1 ic1' sp1') ': r1)
       ('(prd2, CRule prd2 sc2 ip2 ic2 sp2 ic2' sp2') ': r2) )
  => ComAspect
       ('(prd1, CRule prd1 sc1 ip1 ic1 sp1 ic1' sp1') ': r1)
       ('(prd2, CRule prd2 sc2 ip2 ic2 sp2 ic2' sp2') ': r2) where
  comAspect r1@(ConsRec (TagField _ prd1 crule1) asp1) 
            r2@(ConsRec (TagField _ prd2 crule2) asp2) =
    comAspect' (sCompare prd1 prd2) r1 r2

class
  ComAspect' (ord :: Ordering)
             (r1 :: [(Prod, Type)])
             (r2 :: [(Prod, Type)]) where
  comAspect' :: Sing ord -> Aspect r1 -> Aspect r2
             -> Aspect (ComAsp r1 r2)

instance
  ( Compare prd1 prd2 ~ LT
  , ComAspect r1 ('(prd2, CRule prd2 sc2 ip2 ic2 sp2 ic2' sp2') ': r2))
  => ComAspect' LT
            ('(prd1, CRule prd1 sc1 ip1 ic1 sp1 ic1' sp1') ': r1) 
            ('(prd2, CRule prd2 sc2 ip2 ic2 sp2 ic2' sp2') ': r2) where
  comAspect' _ r1@(ConsRec cr1@(TagField _ prd1 crule1) asp1) 
               r2@(ConsRec cr2@(TagField _ prd2 crule2) asp2) =
    ConsRec cr1 $ comAspect asp1 r2
instance
  ( Compare prd1 prd2 ~ EQ
  , prd1 ~ prd2
  , ComAspect r1 r2)
  => ComAspect' EQ
            ('(prd1, CRule prd1 sc1 ip1 ic1 sp1 ic1' sp1') ': r1) 
            ('(prd2, CRule prd2 sc1 ip1 ic2 sp2 ic1  sp1) ': r2) where
  comAspect' _ r1@(ConsRec cr1@(TagField p prd1 crule1) asp1) 
               r2@(ConsRec cr2@(TagField _ prd2 crule2) asp2) =
    ConsRec (TagField p prd1 (crule1 `ext` crule2))$ comAspect asp1 asp2
instance
  ( Compare prd1 prd2 ~ GT
  , ComAspect ('(prd1, CRule prd1 sc1 ip1 ic1 sp1 ic1' sp1') ': r1) r2)
  => ComAspect' GT
            ('(prd1, CRule prd1 sc1 ip1 ic1 sp1 ic1' sp1') ': r1) 
            ('(prd2, CRule prd2 sc2 ip2 ic2 sp2 ic2' sp2') ': r2) where
  comAspect' _ r1@(ConsRec cr1@(TagField _ prd1 crule1) asp1) 
               r2@(ConsRec cr2@(TagField _ prd2 crule2) asp2) =
    ConsRec cr2 $ comAspect r1 asp2


-- | Operator for 'comAspect'. It takes two 'CAspect's to build the
-- combination of both.
(.:+:) = comAspect
infixr 4 .:+:

-- | Unicode operator for 'comAspect' or '.:+:'. (\\bowtie)
(⋈) = comAspect
infixr 4 ⋈

-- | Singleton Aspect. Wraps a rule to build an Aspect from it.
singAsp r
  = r .+: emptyAspect

infixr 6 .+.
(.+.) = ext


syndef att prd f
  = CRule prd $ \inp (Fam prd' ic sp)
   ->  Fam prd ic $ att =. (f inp) *. sp


syndefM att prd = syndef att prd . runReader
syn = syndefM

type Nt_List = 'NT "List"
list = SNT (SSym @ "List")
--cons = Sing @ P_Cons
-- type P_Nil = 'Prd "Nil" Nt_List
-- nil = Sing @ P_Nil
-- asp_cata (Proxy :: Proxy a) f e
--   =   (syndefM (scata @ a) cons $ f <$> ter head <*> at tail (scata @ a))
--   .+: (syndefM (scata @ a) nil $ pure e)
--   .+: emptyAspect

--inh = inhdefM

{-
inhdef att prd chi f
  = CRule prd $ \inp (Fam ic sp)
       -> let ic'   = -- req ctx (OpUpdate chi catts' ic)
              catts = --req ctx (OpLookup chi ic)
              catts'= --req ctx (OpExtend  att (f Proxy inp) catts)
          in  Fam ic' sp



inhdefM
  :: Inhdef t t' ctx ctx' att r v2 prd nt chi ntch ic ic' n
  =>
  Label ('Att att t)
  -> Label ('Prd prd nt)
  -> Label ('Chi chi ('Prd prd nt) ntch)
  -> Reader (Proxy ctx', Fam ('Prd prd nt) sc ip) t'
  -> CRule ctx ('Prd prd nt) sc ip ic sp ic' sp
inhdefM att prd chi = inhdef att prd chi . def




inhmod
  :: ( RequireEq t t' ctx'
     , RequireR (OpUpdate AttReco ('Att att t) t r) ctx
                (Attribution v2)
     , RequireR (OpUpdate (ChiReco ('Prd prd nt))
                ('Chi chi ('Prd prd nt) ntch) v2 ic) ctx
                (ChAttsRec ('Prd prd nt) ic')
     , RequireR (OpLookup (ChiReco ('Prd prd nt))
                ('Chi chi ('Prd prd nt) ntch) ic) ctx
                (Attribution r)
     , RequireEq ntch ('Left n) ctx'
     , ctx' ~ ((Text "inhmod("
                :<>: ShowTE ('Att att t)  :<>: Text ", "
                :<>: ShowTE ('Prd prd nt) :<>: Text ", "
                :<>: ShowTE ('Chi chi ('Prd prd nt) ntch) :<>: Text ")")
                ': ctx))
     =>
     Label ('Att att t)
     -> Label ('Prd prd nt)
     -> Label ('Chi chi ('Prd prd nt) ntch)
     -> (Proxy ctx' -> Fam ('Prd prd nt) sc ip -> t')
     -> CRule ctx ('Prd prd nt) sc ip ic sp ic' sp
inhmod att prd chi f
  = CRule $ \ctx inp (Fam ic sp)
       -> let ic'   = req ctx (OpUpdate chi catts' ic)
              catts = req ctx (OpLookup  chi ic)
              catts'= req ctx (OpUpdate  att (f Proxy inp) catts)
          in  Fam ic' sp


inhmodM
  :: ( RequireEq t t' ctx'
     , RequireR (OpUpdate AttReco ('Att att t) t r) ctx
                (Attribution v2)
     , RequireR (OpUpdate (ChiReco ('Prd prd nt))
                ('Chi chi ('Prd prd nt) ntch) v2 ic) ctx
                (ChAttsRec ('Prd prd nt) ic')
     , RequireR (OpLookup (ChiReco ('Prd prd nt))
                ('Chi chi ('Prd prd nt) ntch) ic) ctx
                (Attribution r)
     , RequireEq ntch ('Left n) ctx'
     , ctx' ~ ((Text "inhmod("
                :<>: ShowTE ('Att att t)  :<>: Text ", "
                :<>: ShowTE ('Prd prd nt) :<>: Text ", "
                :<>: ShowTE ('Chi chi ('Prd prd nt) ntch) :<>: Text ")")
                ': ctx))
     =>
     Label ('Att att t)
     -> Label ('Prd prd nt)
     -> Label ('Chi chi ('Prd prd nt) ntch)
     -> Reader (Proxy ctx', Fam ('Prd prd nt) sc ip) t'
     -> CRule ctx ('Prd prd nt) sc ip ic sp ic' sp
inhmodM att prd chi = inhmod att prd chi . def

data Lhs
lhs :: Label Lhs
lhs = Label

class At pos att m  where
 type ResAt pos att m
 at :: Label pos -> Label att -> m (ResAt pos att m)


instance ( RequireR (OpLookup (ChiReco prd) ('Chi ch prd nt) chi) ctx
                    (Attribution r)
         , RequireR (OpLookup AttReco ('Att att t) r) ctx t'
         , RequireEq prd prd' ctx
         , RequireEq t t' ctx
         , RequireEq ('Chi ch prd nt) ('Chi ch prd ('Left ('NT n)))  ctx
         )
      => At ('Chi ch prd nt) ('Att att t)
            (Reader (Proxy ctx, Fam prd' chi par))  where
 type ResAt ('Chi ch prd nt) ('Att att t) (Reader (Proxy ctx, Fam prd' chi par))
         = t 
 at ch att
  = liftM (\(ctx, Fam chi _)  -> let atts = req ctx (OpLookup ch chi)
                                 in  req ctx (OpLookup att atts))
          ask



instance
         ( RequireR (OpLookup AttReco ('Att att t) par) ctx t'
         , RequireEq t t' ctx
         )
 => At Lhs ('Att att t) (Reader (Proxy ctx, Fam prd chi par))  where
 type ResAt Lhs ('Att att t) (Reader (Proxy ctx, Fam prd chi par))
    = t
 at lhs att
  = liftM (\(ctx, Fam _ par) -> req ctx (OpLookup att par)) ask

def :: Reader (Proxy ctx, Fam prd chi par) a
    -> (Proxy ctx -> (Fam prd chi par) -> a)
def = curry . runReader

ter :: ( RequireR (OpLookup (ChiReco prd) pos chi) ctx
                  (Attribution r)
       , RequireR (OpLookup AttReco ('Att "term" t) r) ctx t'
       , RequireEq prd prd' ctx
       , RequireEq t t' ctx
       , RequireEq pos ('Chi ch prd (Right ('T t))) ctx
       , m ~ Reader (Proxy ctx, Fam prd' chi par) )
    =>  Label pos -> m (ResAt pos ('Att "term" t) m) 
 -- ter (ch :: Label ('Chi ch prd (Right ('T a))))  = at ch (lit @ a)
ter (ch :: Label ('Chi ch prd (Right ('T t))))
  = liftM (\(ctx, Fam chi _)  -> let atts = req ctx (OpLookup ch chi)
                                 in  req ctx (OpLookup (lit @ t) atts))
          ask



class Kn (fcr :: [(Child, Type)]) (prd :: Prod) where
  type ICh fcr :: [(Child, [(Att, Type)])]
  type SCh fcr :: [(Child, [(Att, Type)])]
  kn :: Record fcr -> ChAttsRec prd (ICh fcr) -> ChAttsRec prd (SCh fcr)

instance Kn '[] prod where
  type ICh '[] = '[]
  type SCh '[] = '[] 
  kn _ _ = emptyCh

instance ( lch ~ 'Chi l prd nt
         , Kn fc prd
         -- , LabelSet ('(lch, sch) : SCh fc)
         -- , LabelSet ('(lch, ich) : ICh fc)
         ) =>
  Kn ( '(lch , Attribution ich -> Attribution sch) ': fc) prd where
  type ICh ( '(lch , Attribution ich -> Attribution sch) ': fc)
    = '(lch , ich) ': ICh fc
  type SCh ( '(lch , Attribution ich -> Attribution sch) ': fc)
    = '(lch , sch) ': SCh fc
  kn ((ConsRec (TagField _ lch fch) (fcr :: Record fc)))
   = \((ConsRec pich icr) :: ChAttsRec prd ( '(lch, ich) ': ICh fc))
   -> let scr = kn fcr icr
          ich = unTaggedChAttr pich
      in ConsRec (TaggedChAttr lch
               (fch ich)) scr



emptyCtx = Proxy @ '[]

knit'
  :: ( Kn fc prd
     , Empties fc prd)
  => CRule '[] prd (SCh fc) ip (EmptiesR fc) '[] (ICh fc) sp
  -> Record fc -> Attribution ip -> Attribution sp
knit' (rule :: CRule '[] prd (SCh fc) ip
              (EmptiesR fc) '[] (ICh fc) sp)
              (fc :: Record fc) ip =
  let (Fam ic sp) = mkRule rule emptyCtx
                    (Fam sc ip) (Fam ec emptyAtt)
      sc          = kn fc ic
      ec          = empties fc
  in  sp


class Empties (fc :: [(Child,Type)]) (prd :: Prod) where
  type EmptiesR fc :: [(Child, [(Att, Type)])] 
  empties :: Record fc -> ChAttsRec prd (EmptiesR fc)

instance Empties '[] prd where
  type EmptiesR '[] = '[]
  empties _ = emptyCh

instance
  ( Empties fcr prd
  , chi ~ 'Chi ch prd nt
  )
  =>
  Empties ( '(chi, Attribution e -> Attribution a) ': fcr) prd where
  type EmptiesR ( '(chi, Attribution e -> Attribution a) ': fcr) =
    '(chi, '[]) ': EmptiesR fcr
  empties (ConsRec (TagField labelc
                   (labelch :: Label chi) fch) r) =
    ConsRec (TagField (Label @(ChiReco prd)) labelch emptyAtt) $ empties r


knit (ctx  :: Proxy ctx)
     (rule :: CRule ctx prd (SCh fc) ip (EmptiesR fc) '[] (ICh fc) sp)
     (fc   :: Record fc)
     (ip   :: Attribution ip)
  = let (Fam ic sp) = mkRule rule ctx
                       (Fam sc ip) (Fam ec emptyAtt)
        sc          = kn fc ic
        ec          = empties fc
    in  sp


knitAspect (prd :: Label prd) asp fc ip
  = let ctx  = Proxy @ '[]
        ctx' = Proxy @ '[Text "knit" :<>: ShowTE prd]
    in  knit ctx (req ctx' (OpLookup prd ((mkAspect asp) ctx))) fc ip

-- | use
class Use (att :: Att) (prd :: Prod) (nts :: [NT]) (a :: Type) sc
 where
  usechi :: Label att -> Label prd -> KList nts -> (a -> a -> a) -> ChAttsRec prd sc
         -> Maybe a

class Use' (mnts :: Bool) (att :: Att) (prd :: Prod) (nts :: [NT])
           (a :: Type) sc
 where
  usechi' :: Proxy mnts -> Label att -> Label prd -> KList nts
   -> (a -> a -> a)
   -> ChAttsRec prd sc -> Maybe a

instance Use prd att nts a '[] where
  usechi _ _ _ _ _ = Nothing

instance
  ( HMember' nt nts
  , HMemberRes' nt nts ~ mnts
  , Use' mnts att prd nts a ( '( 'Chi ch prd ('Left nt), attr) ': cs))
  =>
  Use att prd nts a ( '( 'Chi ch prd ('Left nt), attr) ': cs) where
  usechi att prd nts op ch
    = usechi' (Proxy @ mnts) att prd nts op ch

instance
  Use att prd nts a cs
  =>
  Use att prd nts a ( '( 'Chi ch prd ('Right t), attr) ': cs) where
  usechi att prd nts op (ConsRec _ ch)
    = usechi att prd nts op ch


instance
  Use att prd nts a cs
  =>
  Use' False att prd nts a ( '( 'Chi ch prd ('Left nt), attr) ': cs) where
  usechi' _ att prd nts op (ConsRec _ cs) = usechi att prd nts op cs

instance
  ( Require (OpLookup AttReco att attr)
            '[('Text "looking up attribute " ':<>: ShowTE att)
              ':$$: ('Text "on " ':<>: ShowTE attr)]
  , ReqR (OpLookup AttReco att attr) ~ a
  , Use att prd nts a cs
  , WrapField (ChiReco prd) attr ~ Attribution attr)  --ayudín
  =>
  Use' True att prd nts a ( '( 'Chi ch prd ('Left nt), attr) : cs) where
  usechi' _ att prd nts op (ConsRec lattr scr) =
    let attr = unTaggedChAttr lattr
        val  = attr #. att
    in  Just $ maybe val (op val) $ usechi att prd nts op scr


-- | Defines a rule to compute an attribute 'att' in the production
-- 'prd', by applying an operator to the values of 'att' in each non
-- terminal in the list 'nts'.

use
  :: UseC att prd nts t' sp sc sp' ctx
  => Label ('Att att t')
  -> Label prd
  -> KList nts
  -> (t' -> t' -> t')
  -> t'
  -> forall ip ic' . CRule ctx prd sc ip ic' sp ic' sp'
use att prd nts op unit
  = syndef att prd
  $ \_ fam -> maybe unit id (usechi att prd nts op $ chi fam)


type UseC att prd nts t' sp sc sp' ctx =
  ( Require (OpExtend  AttReco ('Att att t') t' sp) ctx
  ,  Use ('Att att t') prd nts t' sc
  ,  ReqR (OpExtend AttReco ('Att att t') t' sp)
     ~ Rec AttReco sp'
  )

class EmptyAspectSameShape (es1 :: [k]) (es2 :: [m])

instance (es2 ~ '[]) => EmptyAspectSameShape '[] es2
instance (EmptyAspectSameShape xs ys, es2 ~ ( '(y1,y2,y3,y4) ': ys))
  => EmptyAspectSameShape (x ': xs) es2


-- require KLIST de prods?, NO, eso está en el kind!
class
  EmptyAspectSameShape prds polyArgs
  =>
  EmptyAspect (prds :: [Prod])
              (polyArgs :: [([(Child, [(Att, Type)])], [(Att, Type)],
                             [(Child, [(Att, Type)])], [(Att, Type)] )])
              ctx where
  type EmptyAspectR prds polyArgs ctx :: [(Prod, Type)]
  emptyAspectC :: KList prds -> Proxy polyArgs
    -> CAspect ctx (EmptyAspectR prds polyArgs ctx)

instance
  EmptyAspect '[] '[] ctx where
  type EmptyAspectR '[] '[] ctx = '[]
  emptyAspectC _ _ = emptyAspect

instance
  ( EmptyAspect prds polys ctx
  , ExtAspect ctx prd sc ip ic sp ic sp
    (EmptyAspectR prds polys ctx)
    (EmptyAspectR (prd ': prds) ( '(sc, ip, ic, sp) ': polys) ctx)
  )
  =>
  EmptyAspect (prd ': prds) ( '(sc, ip, ic, sp) ': polys) ctx where
  type EmptyAspectR (prd ': prds) ( '(sc, ip, ic, sp) ': polys) ctx =
    UnWrap (ReqR (OpComRA '[] prd ((CRule '[] prd sc ip ic sp ic sp))
                  (EmptyAspectR prds polys ctx)))
  emptyAspectC (KCons prd prds) (p :: Proxy ( '(sc, ip, ic, sp) ': polys)) =
    (emptyRule :: CRule ctx prd sc ip ic sp ic sp) 
    .+: emptyAspectC @prds @polys prds (Proxy @ polys)

emptyAspectForProds prdList = emptyAspectC prdList Proxy

-- ** copy rules

-- | a rule to copy one attribute `att` from the parent to the children `chi`

copyAtChi att chi
  = inh att (prdFromChi chi) chi (at lhs att)

-- | to copy at many children
class CopyAtChiList (att :: Att)
                    (chi :: [Child])
                    (polyArgs :: [([(Child, [(Att, Type)])], [(Att, Type)],
                                   [(Child, [(Att, Type)])], [(Att, Type)],
                                   [(Child, [(Att, Type)])], [(Att, Type)] )])
                     ctx where
  type CopyAtChiListR att chi polyArgs ctx :: [(Prod, Type)]
  copyAtChiList :: Label att -> KList chi -> Proxy polyArgs
                -> CAspect ctx (CopyAtChiListR att chi polyArgs ctx)

instance CopyAtChiList att '[] '[] ctx where
  type CopyAtChiListR att '[] '[] ctx = '[]
  copyAtChiList _ _ _ = emptyAspect

-- instance
--   ( CopyAtChiList ('Att att t) chi polys ctx
--   , prd ~ Prd p nt
--   , tnt ~ Left nc
--   )
--   =>
--   CopyAtChiList ('Att att t) (Chi ch prd tnt ': chi)
--    ('(sc, ip, ic, sp, ic', sp') ': polys) ctx where
--   type CopyAtChiListR ('Att att t) (Chi ch prd tnt ': chi)
--    ('(sc, ip, ic, sp, ic', sp') ': polys) ctx =
--     UnWrap (ReqR (OpComRA '[] prd ((CRule '[] prd sc ip ic sp ic' sp'))
--                   (CopyAtChiListR ('Att att t) chi polys ctx)))
--   copyAtChiList att (KCons chi chs :: KList ('Chi ch prd tnt ': chs) )
--    (p :: Proxy ( '(sc, ip, ic, sp, ic', sp') ': polys))
--     = copyAtChi att chi
--     .+: copyAtChiList @('Att att t) @chs att chs (Proxy @polys)
-}
