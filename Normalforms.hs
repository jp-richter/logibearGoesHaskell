module Normalforms (toNNF, toDNF, toCNF) where

import Prelude hiding (negate) 
import Parser
import MTree

{-
    Author          Jan Richter
    Date            27.02.2018
    Description     This module provides functions to transform MTrees 
                    into Negation Normal Form, Conjunctive Normal Form 
                    and Disjunctive Normal Form. 
-}

{-
    Functions Intended For External Use
-}

toNNF :: MTree -> MTree 
toNNF = resolveNegation . resolveImplication . resolveEquivalence

-- assumes that argument is in negation normal form
toDNF :: MTree -> MTree 
toDNF n = if isDNF n then associativity n; else toDNF $ pullOutOr n  

-- assumes that argument is in negation normal form
toCNF :: MTree -> MTree 
toCNF n = if isCNF n then associativity n; else toCNF $ pullOutAnd n

{-
    Convencience Functions
-}

-- assumes that tree is cnf <-> tree is nnf and does not contain 'or' nodes with 
-- 'and' children
isDNF :: MTree -> Bool 
isDNF (Leaf l)      = True 
isDNF (Node And ns) = foldl (\x y -> x && (not $ isDisjunction y) && isDNF y) True ns 
isDNF (Node _ ns)   = foldl (\x y -> x && isDNF y) True ns

-- assumes that tree is dnf <-> tree is nnf and does not contain 'and' nodes with 
-- 'or' children
isCNF :: MTree -> Bool 
isCNF (Leaf l)      = True 
isCNF (Node Or ns)  = foldl (\x y -> x && (not $ isConjunction y) && isCNF y) True ns 
isCNF (Node _ ns)   = foldl (\x y -> x && isCNF y) True ns

{-
    Tree Transforming Functions
-}

negate :: MTree -> MTree 
negate n@(Leaf _)                   = Node Negate [n]
negate (Node Negate [n@(Leaf _)])   = n 
negate (Node Negate [n@(Node _ _)]) = n
negate n@(Node _ _)                 = Node Negate [n] 
 
resolveEquivalence :: MTree -> MTree 
resolveEquivalence n@(Leaf _)            = n 
resolveEquivalence (Node Equiv (n:m:[])) = 
    let left = Node Impl [n,m]
        right = Node Impl [m,n]
    in  Node And [left, right]
resolveEquivalence (Node Equiv ns)       = 
    let n = head ns 
        m = Node Equiv $ tail ns
        left = Node Impl [n,m]
        right = Node Impl [m,n]
        left' = resolveEquivalence left 
        right' = resolveEquivalence right
    in  Node And [left', right'] 
resolveEquivalence (Node op ns)          = 
    Node op $ map resolveEquivalence ns

resolveImplication :: MTree -> MTree 
resolveImplication n@(Leaf _)     = n 
resolveImplication (Node Impl ns) = Node Or $ f [] ns where 
    f xs [y]     = xs ++ [y]
    f xs (y:ys) = f (map negate $ xs ++ [y]) ys 
resolveImplication (Node op ns)   = Node op $ map resolveImplication ns 

-- assumes argument does not contain equivalences & implications
resolveNegation :: MTree -> MTree 
resolveNegation (Node Negate [(Node And ns)])     = Node Or $ map (resolveNegation . negate) ns
resolveNegation (Node Negate [(Node Or ns)])      = Node And $ map (resolveNegation . negate) ns 
resolveNegation (Node Negate [(Node Negate [n])]) = n 
resolveNegation n                                 = n 
   
-- assumes argument is in negation normal form / -> dnf
pullOutOr :: MTree -> MTree
pullOutOr n@(Leaf _)      = n
pullOutOr n@(Node And ns) = 
    if not $ and $ map (flip hasOperator And) ns 
        then let (Node And ns) = associativity n
                 disjunction   = head $ fst $ splitAtOp ns Or 
                 rest          = snd $ splitAtOp ns Or
                 toConjunct1   = head $ children disjunction
                 toConjunct2   = tail $ children disjunction
                 conjunction1  = Node And $ rest ++ [toConjunct1]
                 conjunction2  = Node And $ rest ++ toConjunct2
             in Node Or [conjunction1, conjunction2]
    else Node And $ map pullOutOr ns
pullOutOr (Node op ns)     = Node op $ map pullOutOr ns

-- assumes argument is in negation normal form / -> cnf
pullOutAnd :: MTree -> MTree 
pullOutAnd n@(Leaf _)     = n
pullOutAnd n@(Node Or ns) = 
    if not $ or $ map (flip hasOperator Or) ns 
        then let (Node Or ns)  = associativity n
                 conjunction   = head $ fst $ splitAtOp ns And 
                 rest          = snd $ splitAtOp ns And
                 toDisjunct1   = head $ children conjunction
                 toDisjunct2   = tail $ children conjunction
                 disjunction1  = Node Or $ rest ++ [toDisjunct1]
                 disjunction2  = Node Or $ rest ++ toDisjunct2
             in Node And [disjunction1, disjunction2]
    else Node Or $ map pullOutAnd ns
pullOutAnd (Node op ns)   = Node op $ map pullOutAnd ns

-- resolves redundant brackets
associativity :: MTree -> MTree 
associativity n@(Leaf _)       = n 
associativity (Node op (n:ns)) = 
    if hasOperator n op 
        then associativity (Node op $ ns ++ (children n))
    else Node op $ n:(map associativity ns)
