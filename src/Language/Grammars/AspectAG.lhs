
> {-|
> Module      : Language.Grammars.AspectAG
> Description : Main module, First-class attribute grammars
> Copyright   : (c) Juan García Garland, Marcos Viera, 2019 
> License     : GPL
> Maintainer  : jpgarcia@fing.edu.uy
> Stability   : experimental
> Portability : POSIX

> -}

> {-# LANGUAGE PolyKinds                 #-}
> {-# LANGUAGE KindSignatures            #-}
> {-# LANGUAGE DataKinds                 #-}
> {-# LANGUAGE ConstraintKinds           #-}
> {-# LANGUAGE RankNTypes                #-}
> {-# LANGUAGE TypeOperators             #-}
> {-# LANGUAGE FlexibleInstances         #-}
> {-# LANGUAGE FlexibleContexts          #-}
> {-# LANGUAGE GADTs                     #-}
> {-# LANGUAGE UndecidableInstances      #-}
> {-# LANGUAGE MultiParamTypeClasses     #-}
> {-# LANGUAGE TypeFamilies              #-}
> {-# LANGUAGE NoMonomorphismRestriction #-}
> {-# LANGUAGE ScopedTypeVariables       #-}
> {-# LANGUAGE TypeFamilies              #-}
> {-# LANGUAGE TypeApplications          #-}
> {-# LANGUAGE FunctionalDependencies    #-}
> {-# LANGUAGE TypeFamilyDependencies    #-}
> {-# LANGUAGE PartialTypeSignatures     #-}
> {-# LANGUAGE IncoherentInstances       #-}
> {-# LANGUAGE AllowAmbiguousTypes       #-}

> module Language.Grammars.AspectAG (
>               module Language.Grammars.AspectAG,
>               module Language.Grammars.AspectAG.HList,
>               module Language.Grammars.AspectAG.GenRecord,
>               module Language.Grammars.AspectAG.RecordInstances,
>               module Language.Grammars.AspectAG.TPrelude
>             ) where


> import Language.Grammars.AspectAG.HList
> import Data.Kind
> import Language.Grammars.AspectAG.TPrelude
> import Data.Proxy


> import Language.Grammars.AspectAG.RecordInstances
> import Language.Grammars.AspectAG.Require
> import Language.Grammars.AspectAG.GenRecord
> import GHC.TypeLits

> import Data.Maybe
> import GHC.Types
> import Data.Type.Equality
> import Control.Monad.Reader

> class SemLit a where
>   sem_Lit :: a -> Attribution ('[] :: [(Att,Type)])
>                -> Attribution '[ '( 'Att "term" a , a)]
>   lit     :: Label ('Att "term" a)
> instance SemLit a where
>   sem_Lit a _ = (Label =. a) *. emptyAtt
>   lit         = Label @ ('Att "term" a)



> data Fam (prd :: Prod)
>          (c :: [(Child, [(Att, Type)])])
>          (p :: [(Att, Type)]) :: Type
>  where
>   Fam :: ChAttsRec prd c -> Attribution p -> Fam prd c p

> chi :: Fam prd c p -> ChAttsRec prd c
> chi (Fam c p) = c

> par :: Fam prd c p -> Attribution p
> par (Fam c p) = p

> prd :: Fam prd c p -> Label prd
> prd (Fam c p) = Label


> type Rule
>   (prd  :: Prod)
>   (sc   :: [(Child, [(Att, Type)])])
>   (ip   :: [(Att,       Type)])
>   (ic   :: [(Child, [(Att, Type)])])
>   (sp   :: [(Att,       Type)])
>   (ic'  :: [(Child, [(Att, Type)])])
>   (sp'  :: [(Att,       Type)])
>   = Fam prd sc ip -> Fam prd ic sp -> Fam prd ic' sp'

> newtype CRule (ctx :: [ErrorMessage]) prd sc ip ic sp ic' sp'
>  = CRule { mkRule :: (Proxy ctx -> Rule prd sc ip ic sp ic' sp')}

> newtype CAspect (ctx :: [ErrorMessage]) (asp :: [(Prod, Type)] )
>   = CAspect { mkAspect :: Proxy ctx -> Aspect asp}



> emptyAspect :: CAspect ctx '[]
> emptyAspect  = CAspect $ const EmptyRec

> comAspect ::
>  ( Require (OpComAsp al ar) ctx
>  , ReqR (OpComAsp al ar) ~ Aspect asp)
>  =>  CAspect ctx al -> CAspect ctx ar -> CAspect ctx asp
> comAspect al ar
>   = CAspect $ \ctx -> req ctx (OpComAsp (mkAspect al ctx) (mkAspect ar ctx))


> traceAspect (_ :: Proxy (e::ErrorMessage))
>   = mapCAspect $ \(_ :: Proxy ctx) -> Proxy @ ((Text "aspect ":<>: e) : ctx)

> traceRule (_ :: Proxy (e::ErrorMessage))
>   = mapCRule $ \(_ :: Proxy ctx) -> Proxy @ ((Text "rule ":<>: e) : ctx)


> mapCRule :: (Proxy ctx -> Proxy ctx')
>           -> CRule ctx' prd sc ip ic sp ic' sp'
>           -> CRule ctx  prd sc ip ic sp ic' sp'
> mapCRule fctx (CRule frule) = CRule $ frule . fctx

> mapCAspect fctx (CAspect fasp) = CAspect $ 
>        mapCtxRec fctx . fasp . fctx

> class MapCtxAsp (r :: [(Prod,Type)]) (ctx :: [ErrorMessage])
>                                      (ctx' :: [ErrorMessage])  where
>   type ResMapCtx r ctx ctx' :: [(Prod,Type)]
>   mapCtxRec :: (Proxy ctx -> Proxy ctx')
>             -> Aspect r -> Aspect (ResMapCtx r ctx ctx')

> instance ( MapCtxAsp r ctx ctx' 
>          , ResMapCtx r ctx ctx' ~ r'
>          , LabelSetF ('(l, CRule ctx prd sc ip ic sp ic' sp') : r')
>          ~ True) =>
>   MapCtxAsp ( '(l, CRule ctx' prd sc ip ic sp ic' sp') ': r) ctx ctx' where
>   type ResMapCtx ( '(l, CRule ctx' prd sc ip ic sp ic' sp') ': r) ctx ctx'
>      =  '(l, CRule ctx prd sc ip ic sp ic' sp') ':  ResMapCtx r ctx ctx'
>   mapCtxRec fctx (ConsRec (TagField c l r) rs) = (ConsRec (TagField c l
>                                                             (mapCRule fctx r))
>                                                           (mapCtxRec fctx rs))

> instance MapCtxAsp ('[] :: [(Prod,Type)]) ctx ctx' where
>   type ResMapCtx ('[] :: [(Prod,Type)]) ctx ctx'
>      =  '[]
>   mapCtxRec _ EmptyRec = EmptyRec

> extAspect
>   :: RequireR (OpComRA ctx prd sc ip ic sp ic' sp' a) ctx (Aspect asp)
>   => CRule ctx prd sc ip ic sp ic' sp'
>      -> CAspect ctx a -> CAspect ctx asp
> extAspect rule (CAspect fasp)
>   = CAspect $ \ctx -> req ctx (OpComRA rule (fasp ctx))

> (.+:) = extAspect
> infixr 3 .+:

> (.:+:) = comAspect
> infixr 4 .:+:

> data OpComAsp  (al :: [(Prod, Type)])
>                (ar :: [(Prod, Type)]) where
>   OpComAsp :: Aspect al -> Aspect ar -> OpComAsp al ar

> instance Require (OpComAsp al '[]) ctx where
>   type ReqR (OpComAsp al '[]) = Aspect al
>   req ctx (OpComAsp al _) = al

> instance
>   ( RequireR (OpComAsp al ar) ctx  (Aspect ar')
>   , Require  (OpComRA ctx prd sc ip ic sp ic' sp' ar') ctx
>   )
>   => Require (OpComAsp al
>        ( '(prd, CRule ctx prd sc ip ic sp ic' sp') ': ar)) ctx where
>   type ReqR (OpComAsp al
>        ( '(prd, CRule ctx prd sc ip ic sp ic' sp') ': ar))
>     = ReqR (OpComRA ctx prd sc ip ic sp ic' sp'
>             (UnWrap (ReqR (OpComAsp al ar))))
>   req ctx (OpComAsp al (ConsRec prdrule ar))
>    = req ctx (OpComRA (untagField prdrule)
>                       (req ctx (OpComAsp al ar)))


> data OpComRA  (ctx  :: [ErrorMessage])
>               (prd  :: Prod)
>               (sc   :: [(Child, [(Att, Type)])])
>               (ip   :: [(Att, Type)])
>               (ic   :: [(Child, [(Att, Type)])])
>               (sp   :: [(Att, Type)])
>               (ic'  :: [(Child, [(Att, Type)])])
>               (sp'  :: [(Att, Type)])
>               (a     :: [(Prod, Type)])  where
>   OpComRA :: CRule ctx prd sc ip ic sp ic' sp'
>           -> Aspect a -> OpComRA ctx prd sc ip ic sp ic' sp' a

> data OpComRA' (b :: Bool)
>               (ctx  :: [ErrorMessage])
>               (prd  :: Prod)
>               (sc   :: [(Child, [(Att, Type)])])
>               (ip   :: [(Att, Type)])
>               (ic   :: [(Child, [(Att, Type)])])
>               (sp   :: [(Att, Type)])
>               (ic'  :: [(Child, [(Att, Type)])])
>               (sp'  :: [(Att, Type)])
>               (a     :: [(Prod, Type)])  where
>   OpComRA' :: Proxy b -> CRule ctx prd sc ip ic sp ic' sp'
>           -> Aspect a -> OpComRA' b ctx  prd sc ip ic sp ic' sp' a


> instance
>  (Require (OpComRA' (HasLabel prd a) ctx prd sc ip ic sp ic' sp' a) ctx)
>   => Require (OpComRA ctx prd sc ip ic sp ic' sp' a) ctx where
>   type ReqR (OpComRA ctx prd sc ip ic sp ic' sp' a)
>      = ReqR (OpComRA' (HasLabel prd a) ctx prd sc ip ic sp ic' sp' a)
>   req ctx (OpComRA rule a)
>      = req ctx (OpComRA' (Proxy @ (HasLabel prd a)) rule a)

> instance
>   (Require (OpExtend PrdReco prd (CRule ctx prd sc ip ic sp ic' sp') a)) ctx
>   => Require (OpComRA' 'False ctx prd sc ip ic sp ic' sp' a) ctx where
>   type ReqR (OpComRA' 'False ctx prd sc ip ic sp ic' sp' a)
>     = ReqR (OpExtend PrdReco prd (CRule ctx prd sc ip ic sp ic' sp') a)
>   req ctx (OpComRA' _ (rule :: CRule ctx prd sc ip ic sp ic' sp') asp)
>     = req ctx (OpExtend (Label @ prd) rule asp)

> instance
>  ( Require (OpUpdate PrdReco prd (CRule ctx prd sc ip ic sp ic'' sp'') a) ctx
>  , RequireR (OpLookup PrdReco prd a) ctx (CRule ctx prd sc ip ic sp ic' sp') 
>  , (IC (ReqR (OpLookup PrdReco prd a))) ~ ic
>  , (SP (ReqR (OpLookup PrdReco prd a))) ~ sp
>  ) => 
>   Require (OpComRA' 'True ctx prd sc ip ic' sp' ic'' sp'' a) ctx where
>   type ReqR (OpComRA' 'True ctx prd sc ip ic' sp' ic'' sp'' a)
>     = ReqR (OpUpdate PrdReco prd
>            (CRule ctx prd sc ip
>              (IC (ReqR (OpLookup PrdReco prd a)))
>              (SP (ReqR (OpLookup PrdReco prd a)))
>             ic'' sp'') a)
>   req ctx (OpComRA' _ rule asp)
>     = let prd     = Label @ prd
>           oldRule = req ctx (OpLookup prd asp)
>           newRule = rule `ext` oldRule
>       in  req ctx (OpUpdate prd newRule asp)



> type family IC (rule :: Type) where
>   IC (Rule prd sc ip ic sp ic' sp') = ic
>   IC (CRule ctx prd sc ip ic sp ic' sp') = ic
> type family SP (rule :: Type) where
>   SP (Rule prd sc ip ic sp ic' sp') = sp
>   SP (CRule ctx prd sc ip ic sp ic' sp') = sp

> syndef
>   :: ( RequireEq t t' ctx'
>      , RequireR (OpExtend AttReco ('Att att t) t sp) ctx (Attribution sp')
>      , ctx'
>          ~ ((Text "syndef("
>              :<>: ShowT ('Att att t) :<>: Text ", "
>              :<>: ShowT prd :<>: Text ")") ': ctx)
>      )
>      => Label ('Att att t)
>      -> Label prd
>      -> (Proxy ctx' -> Fam prd sc ip -> t')
>      -> CRule ctx prd sc ip ic sp ic sp'
> syndef att prd f
>   = CRule $ \ctx inp (Fam ic sp)
>    ->  Fam ic $ req ctx (OpExtend att (f Proxy inp) sp)

> syndefM att prd = syndef att prd . def



> synmod
>   :: RequireR (OpUpdate AttReco ('Att att t) t r) ctx (Attribution sp')
>   => Label ('Att att t)
>      -> Label prd
>      -> (Proxy
>            ((('Text "synmod(" ':<>: ShowT ('Att att t)) :<>: Text ", "
>                               ':<>: ShowT prd :<>: Text ")")
>               : ctx)
>          -> Fam prd sc ip -> t)
>      -> CRule ctx prd sc ip ic' r ic' sp'

> synmod att prd f
>   = CRule $ \ctx  inp (Fam ic sp)
>            -> Fam ic $ req ctx (OpUpdate att (f Proxy inp) sp)

> synmodM att prd = synmod att prd . def



> inhdef
>   :: ( RequireEq t t' ctx'
>      , RequireR  (OpExtend AttReco ('Att att t) t r) ctx (Attribution v2)
>      , RequireR (OpUpdate (ChiReco ('Prd prd nt))
>                 ('Chi chi ('Prd prd nt) ntch) v2 ic) ctx
>                 (ChAttsRec ('Prd prd nt) ic')
>      , RequireR (OpLookup (ChiReco ('Prd prd nt))
>                 ('Chi chi ('Prd prd nt) ntch) ic) ctx
>                 (Attribution r)
>      , RequireEq ntch ('Left n) ctx'
>      , ctx' ~ ((Text "inhdef("
>                 :<>: ShowT ('Att att t)  :<>: Text ", "
>                 :<>: ShowT ('Prd prd nt) :<>: Text ", "
>                 :<>: ShowT ('Chi chi ('Prd prd nt) ntch) :<>: Text ")")
>                 ': ctx))
>      =>
>      Label ('Att att t)
>      -> Label ('Prd prd nt)
>      -> Label ('Chi chi ('Prd prd nt) ntch)
>      -> (Proxy ctx' -> Fam ('Prd prd nt) sc ip -> t')
>      -> CRule ctx ('Prd prd nt) sc ip ic sp ic' sp
> inhdef  att prd chi f
>   = CRule $ \ctx inp (Fam ic sp)
>        -> let ic'   = req ctx (OpUpdate chi catts' ic)
>               catts = req ctx (OpLookup chi ic)
>               catts'= req ctx (OpExtend  att (f Proxy inp) catts)
>           in  Fam ic' sp

> inhdefM att prd chi = inhdef att prd chi . def




> inhmod
>   :: ( RequireEq t t' ctx'
>      , RequireR (OpUpdate AttReco ('Att att t) t r) ctx
>                 (Attribution v2)
>      , RequireR (OpUpdate (ChiReco ('Prd prd nt))
>                 ('Chi chi ('Prd prd nt) ntch) v2 ic) ctx
>                 (ChAttsRec ('Prd prd nt) ic')
>      , RequireR (OpLookup (ChiReco ('Prd prd nt))
>                 ('Chi chi ('Prd prd nt) ntch) ic) ctx
>                 (Attribution r)
>      , RequireEq ntch ('Left n) ctx'
>      , ctx' ~ ((Text "inhmod("
>                 :<>: ShowT ('Att att t)  :<>: Text ", "
>                 :<>: ShowT ('Prd prd nt) :<>: Text ", "
>                 :<>: ShowT ('Chi chi ('Prd prd nt) ntch) :<>: Text ")")
>                 ': ctx))
>      =>
>      Label ('Att att t)
>      -> Label ('Prd prd nt)
>      -> Label ('Chi chi ('Prd prd nt) ntch)
>      -> (Proxy ctx' -> Fam ('Prd prd nt) sc ip -> t')
>      -> CRule ctx ('Prd prd nt) sc ip ic sp ic' sp
> inhmod att prd chi f
>   = CRule $ \ctx inp (Fam ic sp)
>        -> let ic'   = req ctx (OpUpdate chi catts' ic)
>               catts = req ctx (OpLookup  chi ic)
>               catts'= req ctx (OpUpdate  att (f Proxy inp) catts)
>           in  Fam ic' sp

> inhmodM att prd chi = inhmod att prd chi . def

> ext' ::  CRule ctx prd sc ip ic sp ic' sp'
>      ->  CRule ctx prd sc ip a b ic sp
>      ->  CRule ctx prd sc ip a b ic' sp'
> (CRule f) `ext'` (CRule g)
>  = CRule $ \ctx input -> f ctx input . g ctx input

> ext ::  RequireEq prd prd' (Text "ext":ctx) 
>      => CRule ctx prd sc ip ic sp ic' sp'
>      -> CRule ctx prd' sc ip a b ic sp
>      -> CRule ctx prd sc ip a b ic' sp'
> ext = ext'


> infixr 6 .+.
> (.+.) = ext


> --- Por que tiene que ir aca?
> --- Intente pasarlo a Require.hs y no compila
> --- por las overlapping instances.
> type RequireEq (t1 :: k )(t2 :: k) (ctx:: [ErrorMessage])
>     = (Require (OpEq t1 t2) ctx, t1 ~ t2)

> data OpEq t1 t2


> instance Require (OpEq t t) ctx where
>   type ReqR (OpEq t t) = ()
>   req = undefined


> instance Require (OpError (Text "" :<>: ShowT t1 :<>: Text " /= "
>                             :<>: ShowT t2)) ctx
>   => Require (OpEq t1 t2) ctx where
>   type ReqR (OpEq t1 t2) = ()
>   req = undefined
> -----

> data Lhs
> lhs :: Label Lhs
> lhs = Label
>
> class At pos att m  where
>  type ResAt pos att m
>  at :: Label pos -> Label att -> m (ResAt pos att m)


> instance ( RequireR (OpLookup (ChiReco prd) ('Chi ch prd nt) chi) ctx
>                     (Attribution r)
>          , RequireR (OpLookup AttReco ('Att att t) r) ctx t'
>          , RequireEq prd prd' ctx
>          , RequireEq t t' ctx
>          --, RequireEq nt ('Left n) ctx
>          )
>       => At ('Chi ch prd nt) ('Att att t)
>             (Reader (Proxy ctx, Fam prd' chi par))  where
>  type ResAt ('Chi ch prd nt) ('Att att t) (Reader (Proxy ctx, Fam prd' chi par))
>          = t 
>  at ch att
>   = liftM (\(ctx, Fam chi _)  -> let atts = req ctx (OpLookup ch chi)
>                                  in  req ctx (OpLookup att atts))
>           ask



> instance
>          ( RequireR (OpLookup AttReco ('Att att t) par) ctx t'
>          , RequireEq t t' ctx
>          )
>  => At Lhs ('Att att t) (Reader (Proxy ctx, Fam prd chi par))  where
>  type ResAt Lhs ('Att att t) (Reader (Proxy ctx, Fam prd chi par))
>     = t
>  at lhs att
>   = liftM (\(ctx, Fam _ par) -> req ctx (OpLookup att par)) ask

> def :: Reader (Proxy ctx, Fam prd chi par) a
>     -> (Proxy ctx -> (Fam prd chi par) -> a)
> def = curry . runReader

> ter :: ( At pos ('Att "term" a) m
>        , RequireEq pos ('Chi ch prd (Right ('T a))) ctx
>        , m ~ Reader (Proxy ctx, Fam prd chi par) )
>     =>  Label pos -> m (ResAt pos ('Att "term" a) m) 
> ter (ch :: Label ('Chi ch prd (Right ('T a))))  = at ch (lit @ a)


> class Kn (fcr :: [(Child, Type)]) (prd :: Prod) where
>   type ICh fcr :: [(Child, [(Att, Type)])]
>   type SCh fcr :: [(Child, [(Att, Type)])]
>   kn :: Record fcr -> ChAttsRec prd (ICh fcr) -> ChAttsRec prd (SCh fcr)

> instance Kn '[] prod where
>   type ICh '[] = '[]
>   type SCh '[] = '[] 
>   kn _ _ = emptyCh

> instance ( lch ~ 'Chi l prd nt
>          , Kn fc prd
>          , LabelSet ('(lch, sch) : SCh fc)
>          , LabelSet ('(lch, ich) : ICh fc)
>          ) => 
>   Kn ( '(lch , Attribution ich -> Attribution sch) ': fc) prd where
>   type ICh ( '(lch , Attribution ich -> Attribution sch) ': fc)
>     = '(lch , ich) ': ICh fc
>   type SCh ( '(lch , Attribution ich -> Attribution sch) ': fc)
>     = '(lch , sch) ': SCh fc
>   kn ((ConsRec (TagField _ lch fch) (fcr :: Record fc)))
>    = \((ConsCh pich icr) :: ChAttsRec prd ( '(lch, ich) ': ICh fc))
>    -> let scr = kn fcr icr
>           ich = unTaggedChAttr pich
>       in ConsCh (TaggedChAttr lch
>                (fch ich)) scr



> emptyCtx = Proxy @ '[]

> knit' :: ( Kn fc prd
>         , Empties fc prd)
>  => CRule '[] prd (SCh fc) ip (EmptiesR fc) '[] (ICh fc) sp
>   -> Record fc -> Attribution ip -> Attribution sp
> knit' (rule :: CRule '[] prd (SCh fc) ip
>               (EmptiesR fc) '[] (ICh fc) sp)
>               (fc :: Record fc) ip
>   = let (Fam ic sp) = mkRule rule emptyCtx
>                        (Fam sc ip) (Fam ec emptyAtt)
>         sc          = kn fc ic
>         ec          = empties fc
>     in  sp


> class Empties (fc :: [(Child,Type)]) (prd :: Prod) where
>   type EmptiesR fc :: [(Child, [(Att, Type)])] 
>   empties :: Record fc -> ChAttsRec prd (EmptiesR fc)

> instance Empties '[] prd where
>   type EmptiesR '[] = '[]
>   empties _ = emptyCh

> instance ( Empties fcr prd
>          , chi ~ 'Chi ch prd nt
>          , LabelSet ( '(chi, '[]) ': EmptiesR fcr))
>  => Empties ( '(chi, Attribution e -> Attribution a) ': fcr) prd where
>   type EmptiesR ( '(chi, Attribution e -> Attribution a) ': fcr)
>     = '(chi, '[]) ': EmptiesR fcr
>   empties (ConsRec pch fcr)
>     = let lch = labelTChAtt pch
>       in  (lch .= emptyAtt) .* (empties fcr)

> knit (ctx  :: Proxy ctx)
>      (rule :: CRule ctx prd (SCh fc) ip (EmptiesR fc) '[] (ICh fc) sp)
>      (fc   :: Record fc)
>      (ip   :: Attribution ip)
>   = let (Fam ic sp) = mkRule rule ctx
>                        (Fam sc ip) (Fam ec emptyAtt)
>         sc          = kn fc ic
>         ec          = empties fc
>     in  sp


> knitAspect (prd :: Label prd) asp fc ip
>   = let ctx  = Proxy @ '[]
>         ctx' = Proxy @ '[Text "knit" :<>: ShowT prd]
>     in  knit ctx (req ctx' (OpLookup prd ((mkAspect asp) ctx))) fc ip


> class Use (att :: Att) (prd :: Prod) (nts :: [NT]) (a :: Type) sc
>  where
>   usechi :: Label att -> Label prd -> KList nts -> (a -> a -> a) -> ChAttsRec prd sc
>          -> Maybe a

> class Use' (mnts :: Bool) (att :: Att) (prd :: Prod) (nts :: [NT])
>            (a :: Type) sc
>  where
>   usechi' :: Proxy mnts -> Label att -> Label prd -> KList nts
>    -> (a -> a -> a)
>    -> ChAttsRec prd sc -> Maybe a

> instance Use prd att nts a '[] where
>   usechi _ _ _ _ _ = Nothing

> instance( HMember' nt nts
>         , HMemberRes' nt nts ~ mnts
>         , Use' mnts att prd nts a ( '( 'Chi ch prd ('Left nt), attr) ': cs))
>   => Use att prd nts a ( '( 'Chi ch prd ('Left nt), attr) ': cs) where
>   usechi att prd nts op ch
>     = usechi' (Proxy @ mnts) att prd nts op ch

> instance ( LabelSet ( '( 'Chi ch prd ('Left nt), attr) : cs)
>          , Use att prd nts a cs)
>   => Use' False att prd nts a ( '( 'Chi ch prd ('Left nt), attr) ': cs)
>  where
>   usechi' _ att prd nts op (ConsCh _ cs) = usechi att prd nts op cs

> instance ( Require (OpLookup AttReco att attr)
>            '[('Text "looking up attribute " ':<>: ShowT att)
>               ':$$: ('Text "on " ':<>: ShowT attr)]
>          , ReqR (OpLookup AttReco att attr) ~ a
>          , Use att prd nts a cs
>          , LabelSet ( '( 'Chi ch prd ('Left nt), attr) : cs)
>          , WrapField (ChiReco prd) attr ~ Attribution attr)  --ayudín
>   => Use' True att prd nts a ( '( 'Chi ch prd ('Left nt), attr) : cs) where
>   usechi' _ att prd nts op (ConsCh lattr scr)
>     = let attr = unTaggedChAttr lattr
>           val  = attr #. att
>       in  Just $ maybe val (op val) $ usechi att prd nts op scr


> --use :: (Use att prd nts a sc, LabelSet ( '( att, a) ': sp)) =>
> --    Label att -> Label prd-> KList nts -> (a -> a -> a) -> a
> --           -> CRule ctx prd sc ip ic sp ic ( '( att, a) ': sp)

> use att prd nts op unit
>   = syndef att prd $ \_ fam -> maybe unit id (usechi att prd nts op $ chi fam)