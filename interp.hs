{-# LANGUAGE RankNTypes, FlexibleContexts #-}

import HOAS
import DeBruijn
import qualified BUBS
import qualified Reference
import System (getArgs)

data Value
    = VPlus
    | VAdd Integer
    | VInt Integer
    deriving Show

instance Primitive Value where
    apply VPlus (VInt x) = VAdd x
    apply (VAdd x) (VInt y) = VInt (x+y)
    apply x y = error $ "Type error when applying (" ++ show x ++ ") to (" ++ show y ++ ")"

quote :: (Term t) => (forall u. (Term u) => u) -> t
quote expr = 
    let_ (fun (\f -> fun (\x -> x))) $ \zero ->
    let_ (fun (\n -> fun (\f -> fun (\x -> f % (n % f % x))))) $ \succ ->

    let_ (fun (\body -> fun (\l -> fun (\a -> fun (\v -> l % (body % l % a % v)))))) $ \mkLam ->
    let_ (fun (\left -> fun (\right -> fun (\l -> fun (\a -> fun (\v -> a % (left % l % a % v) % (right % l % a % v))))))) $ \mkApp -> 
    let_ (fun (\num -> fun (\l -> fun (\a -> fun (\v -> v % num))))) $ \mkVar -> 

    let quote (ELam body) = mkLam % quote body
        quote (EApp l r) = mkApp % quote l % quote r
        quote (EVar v)   = mkVar % (iterate (succ %) zero !! fromIntegral v) in
    quote (getDeBruijn expr)

interp :: (Term t) => t
interp = 
    let_ (fun (\x -> x)) $ \id -> 

    let_ (fun (\n -> fun (\c -> n))) $ \nil ->
    let_ (fun (\x -> fun (\xs -> fun (\n -> fun (\c -> c % x % xs))))) $ \cons ->

    let_ (fun (\l -> l % id % fun (\x -> fun (\xs -> x)))) $ \head ->
    let_ (fun (\l -> l % id % fun (\x -> fun (\xs -> xs)))) $ \tail ->

    let_ (fun (\l -> fun (\n -> head % (n % tail % l)))) $ \nth -> 
    
    let_ (fun (\term ->
        term % fun (\body -> fun (\env -> fun (\x -> body % (cons % x % env))))
             % fun (\left -> fun (\right -> fun (\env -> left % env % (right % env))))
             % fun (\n    -> fun (\env -> nth % env % n))
             % nil)) $ \eval -> 
    eval

program :: (Term t) => t
program = 
    let_ (fun (\f -> fun (\x -> x))) $ \zero ->
    let_ (fun (\n -> fun (\f -> fun (\x -> f % (n % f % x))))) $ \succ ->
    succ % (succ % (succ % zero))

go :: Int -> (PrimTerm Value t) => t
go n = 
    let_ (fun (\n -> n % prim (VAdd 1) % prim (VInt 0))) $ \toPrim ->
    toPrim % (foldl (%) interp (replicate n (quote interp)) % quote program)

main = do
    [interp, nstr] <- getArgs
    case interp of
        "bubs" -> print =<< BUBS.eval (go (read nstr))
        "ref"  -> print $ Reference.eval (go (read nstr))
        x      -> fail $ "Unknown interpreter '" ++ x ++ "'.  Choices are 'bubs' and 'ref'."
