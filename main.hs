-- Propositional Inference

---------------------------------------------------------------------------
---------------------------------------------------------------------------

-- Module declaration and imports

module Inf2d where

import System.Random
import Data.Maybe
import Data.List
import Prop

---------------------------------------------------------------------------
---------------------------------------------------------------------------

-- Some simple helper functions

lookupAssignment :: Symbol -> Model -> Maybe Bool
lookupAssignment = undefined

negateSymbol :: Symbol -> Symbol
negateSymbol = undefined

isNegated :: Symbol -> Bool
isNegated = undefined

getUnsignedSymbol :: Symbol -> Symbol
getUnsignedSymbol = undefined

getSymbols :: [Sentence] -> [Symbol]
getSymbols = undefined

-- Whether symbol is satisfied by the model
satisfiesSymbol :: Model -> Symbol -> Bool
satisfiesSymbol [] _ = False
satisfiesSymbol model symbol =  case valueOf model $ variableOf symbol of
                Nothing -> False
                Just variable -> (polarity symbol) == variable

-- Whether clause is satisfied by the model
satisfiesClause :: Model -> Clause -> Bool
satisfiesClause [] _ = False
satisfiesClause model clause = any (satisfiesSymbol model) clause

-- Whether sentence is satisfied by the model
satisfiesSentence :: Model -> Sentence -> Bool
satisfiesSentence [] _ = False
satisfiesSentence model sentence = all (satisfiesClause model) sentence

-- Whether symbol is falsified by the model
falsifiesSymbol :: Model -> Symbol -> Bool
falsifiesSymbol [] _ = False
falsifiesSymbol model symbol = case valueOf model $ variableOf symbol of
                Nothing -> False
                Just variable -> (polarity symbol) /= variable

-- Whether clause is falsified by the model
falsifiesClause :: Model -> Clause -> Bool
falsifiesClause [] _ = False
falsifiesClause model clause = all (falsifiesSymbol model) clause

-- Whether sentence is falsified by the model
falsifiesSentence :: Model -> Sentence -> Bool
falsifiesSentence [] _ = False
falsifiesSentence model sentence = any (falsifiesClause model) sentence

---------------------------------------------------------------------------
---------------------------------------------------------------------------

-- WalkSat
-- List of unsatisfied clauses by the model
unsatClauses :: Model -> Sentence -> [Clause]
unsatClauses model sentence = filter (falsifiesClause model) sentence

-- Returns the number of unsatisfied clauses in the sentence given if the variable given is flipped
numUnsatClauses :: Model -> Sentence -> Variable -> Int
numUnsatClauses model sentence variable = length $ unsatClauses (flipSymbol model variable) sentence

-- Flip all variables in the list and get the one with the minimum amount of unsatisfied clauses -
-- which yields maximum amount of satisfied clauses
maxSatClauses :: Model -> Sentence -> [Variable] -> Variable
maxSatClauses model sentence varList = variable
              where (unsatClauses,variable) = minimum [ (numUnsatClauses model sentence variable, variable) | variable <- varList ]

---------------------------------------------------------------------------

-- Implementation of the WalkSat algorithm.

walkSatRecursion :: RandomGen g => g -> Sentence -> Model -> Float -> Int -> (Maybe (Model,Int),g)
walkSatRecursion gen sentence model _ 0
                 | satisfiesSentence model sentence = (Just (model,0),gen)
                 | otherwise = (Nothing,gen)
walkSatRecursion gen sentence model prob n
                 | satisfiesSentence model sentence = (Just (model,n),gen)
                 | rchoice = walkSatRecursion gen3 sentence flipRandom prob (n-1)
                 | otherwise = walkSatRecursion gen3 sentence flipMaxSat prob (n-1)
                           where (rchoice,gen1) = randomChoice gen prob (1.0::Float)
                                 (clause,gen2) = randomElem gen1 (unsatClauses model sentence)
                                 atms = variablesOfClause clause
                                 (rvariable,gen3) = randomElem gen2 atms
                                 mvariable = maxSatClauses model sentence atms
                                 flipRandom = flipSymbol model rvariable
                                 flipMaxSat = flipSymbol model mvariable

walkSat :: Sentence -> Float -> Int -> IO (Maybe (Model,Int))
walkSat sentence prob n = do
      gen <- getStdGen
      let (rassign,gen') = (randomAssign gen (variablesOfSentence sentence))
      let (res,gen'') = walkSatRecursion gen' sentence rassign prob n
      setStdGen (gen'')
      putStrLn $ show res
      return res

---------------------------------------------------------------------------
---------------------------------------------------------------------------

-- DPLL

-- Tautology Deletion

-- Checks if clause is a tautology
isTautology :: Clause -> Bool
isTautology clause = or [isSymbol (complement symbol) clause | symbol <- clause]

-- Removes tautologies from sentence using the above helper function
removeTautologies :: Sentence -> Sentence
removeTautologies sentence = filter (not . isTautology) sentence


---------------------------------------------------------------------------

-- Pure Symbol Heuristic

-- Removes clauses which are satisfied by the model from the sentence
simplifySentence :: Model -> Sentence -> Sentence
simplifySentence model sentence = [clause | clause <- sentence, satisfiesClause model clause == False]


-- Checks if the variable produces a pure symbol.
-- Function filters all symbols in the sentence produced by the passed variable and checks if they all are the same symbol (have the same polarity)
isPureVar :: Variable -> Sentence -> Model -> Maybe Symbol
isPureVar variable sentence model
                            | length varList == 1 = Just (head varList)
                            | otherwise = Nothing
                    where
                      varList = nub $ concat $ map (\clause -> filterClause variable clause) sentence
                      filterClause variable clause = filter (\symbol -> variableOf symbol == variable) clause

-- Checks if any of the variables in the list produce a pure symbol and returns the values to assign to the first one of them.
-- Function first simplifies the sentence by first removing the clauses satisfied by the model.
-- Returns Nothing if no pure symbols are found.
findPureSymbol :: [Variable] -> Sentence -> Model -> Maybe (Variable, Bool)
findPureSymbol variables sentence model
                          | isNothing pureSym = Nothing
                          | otherwise = Just(var, value)

          where
          pureSym = listToMaybe [ fromJust $ purePredicate variable
                                | variable <- variables,
                                  variable `elem` prunedVaribles && isJust (purePredicate variable)
                                ]
          purePredicate variable = isPureVar variable simplifiedSentence model
          prunedVaribles = variablesOfSentence simplifiedSentence
          simplifiedSentence = simplifySentence model sentence
          var = variableOf $ fromJust pureSym
          value = polarity $ fromJust pureSym


-- Unit Clause Heuristic

-- Removes symbols in the clause which are falsified by the model
simplifyClause :: Model -> Clause -> Clause
simplifyClause _ [] = []
simplifyClause [] clause = clause
simplifyClause model clause = [symbol | symbol <- clause, falsifiesSymbol model symbol == False]


-- Checks if any clause in the sentence is unit clause and returns the value to assign to the first one of them.
-- Returns Nothing if no unit clauses are found.
findUnitClause :: Sentence -> Model -> Maybe (Variable, Bool)
findUnitClause sentence model
                  | isNothing unitClause = Nothing
                  | otherwise = Just(variable, value)
          where
          unitClause = find unitPredicate simplifiedSentence
          unitPredicate clause = length (simplifyClause model clause) == 1 && not (satisfiesClause model $ simplifyClause model clause)
          simplifiedSentence = simplifySentence model sentence
          variable = variableOf $ head $ simplifyClause model $ fromJust unitClause
          value = polarity $ head $ simplifyClause model $ fromJust unitClause


--Early Termination

-- Checks whether sentence is satisfied or falsified by the given model
earlyTerminate :: Sentence -> Model -> Bool
earlyTerminate sentence model = falsifiesSentence model sentence || satisfiesSentence model sentence

---------------------------------------------------------------------------

-- DPLL algorithm
-- Code follow pseudo code given in the book.
-- Algorithm first checks for early termination. Then it finds all pure symbols and assigns them to true.
-- It finds all unit clauses and assigns all symbols in there to true.
-- If sentence isn't satisfied it choses a variable using heuristic and branches on that variable.
dpll :: (Node -> Variable) -> [Node] -> Int -> (Bool, Int)
dpll heuristic [] i = (False, i)
dpll heuristic ((sentence, (variables, model)):xs) i
              | earlyTerminate sentence model  =
                case satisfiesSentence model sentence of
                  True -> (True, i)
                  False -> dpll heuristic xs (i + 1)
              | otherwise =
                case findPureSymbol variables sentence model of
                  Just (variable, value) -> dpll heuristic ((sentence,(delete variable variables, assign model variable value)):xs) i
                  Nothing ->
                    case findUnitClause sentence model of
                      Just (variable, value) -> dpll heuristic ((sentence,(delete variable variables, assign model variable value)):xs) i
                      Nothing ->
                          dpll heuristic (nodeTrue:nodeFalse:xs) i
                              where
                                node = (sentence, (variables, model))
                                chosenVariable = heuristic node
                                newVariables = delete chosenVariable variables
                                nodeTrue = (sentence, ( newVariables, assign model chosenVariable True))
                                nodeFalse = (sentence, ( newVariables, assign model chosenVariable False))




---------------------------------------------------------------------------

-- Provided choice function and dpll initialisation

firstVariable :: Node -> Variable
firstVariable (_, ([],_)) = undefined
firstVariable (_, (h:_,_)) = h

dpllSatisfiable :: Sentence -> (Bool, Int)
dpllSatisfiable sentence = dpll firstVariable [(removeTautologies sentence, (variablesOfSentence sentence, []))] 0


---------------------------------------------------------------------------

-- Improved heuristics for DPLL 
-- Idea and inspiration for improvement from Branching Heuristics, Matt Ginsberg(2004) (https://www.cs.cmu.edu/afs/cs/project/jair/pub/volume21/dixon04a-html/node8.html)

-- Applies the formula (f(x) + f(-x))*2^k + f(x)*f(-x) for k = 4
-- This is formula generally used with the MOM heuristic
-- We try to maximize this function
applyFormula :: Float -> Float -> Float
applyFormula f1 f2 = (f1 + f2)*(2^4) + f1*f2


-- Returns ratio of number of occurences of the symbol to the length of the clause it occurs in (relative frequency)
-- This normalizes the frequency and gives higher weight to smaller clauses with high occurances
frequencyRatio :: Symbol -> Clause -> Float
frequencyRatio symbol clause =  (fromIntegral $ length $ filter(\sym -> sym == symbol) clause) / (fromIntegral $ length clause)

-- Given a variable it first calculates the relative frequencies for the positive and negative symbol
-- created by the given variable and then applies the formula we wish to maximise using these numbers.
scoreVariable :: Variable -> Sentence -> Float
scoreVariable variable sentence = applyFormula posRatio negRatio
                      where
                      (posRatio,negRatio) = foldl' (\(a,b) (c,d)-> (a+c, c+d)) (0,0) [(frequencyRatio posSymbol clause, frequencyRatio negSymbol clause) | clause <- sentence ]
                      posSymbol = LTR(True, variable)
                      negSymbol = LTR(False, variable)

-- Heuristic acts on the basis of the Maximum Occurrences on clauses of Minimum size (MOM’s) heuristic
-- Calls the scoreVariable function on every variable in the list and returns the one that maximises the function
-- given in applyFormula.
variableSelectionHeuristic :: Node -> Variable
variableSelectionHeuristic (sentence, (variables, model)) = chosenVariable
                          where
                            (score, chosenVariable) = maximum [(scoreVariable variable simplifiedSentence, variable) | variable <- variables]
                            simplifiedSentence = simplifySentence model sentence

---------------------------------------------------------------------------

-- Provided dpllSatisfiablev2

dpllSatisfiablev2 :: Sentence -> (Bool, Int)
dpllSatisfiablev2 sentence = dpll variableSelectionHeuristic [(removeTautologies sentence, (variablesOfSentence sentence, []))] 0

---------------------------------------------------------------------------

-- Examples of type Sentence which you can use to test the functions you develop
f1 = [[LTR (True,"p"), LTR (True,"q")], [LTR (True,"p"), LTR (False,"p")], [LTR (True,"q")]]
f2 = [[LTR (True,"p"), LTR (True,"q")], [LTR (True,"p"), LTR (True,"q"), LTR (True,"z")], [LTR (False,"z"), LTR (False,"w"), LTR (True,"k")], [LTR (False,"z"), LTR (False,"w"), LTR (True,"s")], [LTR (True,"p"), LTR (False,"q")]]
f3 = [[LTR (True,"k"), LTR (False,"g"), LTR (True,"t")], [LTR (False,"k"), LTR (True,"w"), LTR (True,"z")], [LTR (True,"t"), LTR (True,"p")], [LTR (False,"p")], [LTR (True,"z"), LTR (True,"k"), LTR (False,"w")], [LTR (False,"z"), LTR (False,"k"), LTR (False,"w")], [LTR (False,"z"), LTR (True,"k"), LTR (True,"w")]]
f4 = [[LTR (True,"p")], [LTR (False,"p")]]
f5 = [[LTR (True,"p"), LTR (False,"q")], [LTR (True,"p"), LTR (True,"q")]]
f6 = [[LTR (True,"p"), LTR (False,"q")], [LTR (True,"q")]]
f7 = [[LTR (True,"p"), LTR (False,"q")], [LTR (True,"q"), LTR (True,"k")], [LTR (True,"q"), LTR (False,"p"), LTR (False,"k")]]

-- Models to test functions
model1 = [AS ("z", True)]
model2 = [AS ("p", False), AS("t", True), AS("g", False)]
model3 = [AS ("p", False), AS("g", False)]
model4 = []
---------------------------------------------------------------------------

-- Evaluation

-- WalkSat
{-
          |  p=0  | p=0.5 |  p=1  |
----------+-------+-------+-------+
Sat01.cnf |  56   |  255  |  289  |
Sat02.cnf | Fail  |  Fail |  Fail |
Sat03.cnf |  45   |  140  |  304  |
Sat04.cnf | Fail  |  Fail |  Fail |
Sat05.cnf | Fail  |  592  |  Fail |
Sat06.cnf | Fail  |  Fail |  Fail |
Sat07.cnf | Fail  |  Fail |  Fail |
Say08.cnf |  48   |  133  |  300  |
Say09.cnf | Fail  |  Fail |  Fail |
Say10.cnf |  34   |  573  |  Fail |
----------+-------+-------+-------+

-- TABLE 2 : DPLL and DPLLv2

          | DPLL   | DPLLv2 |
----------+--------+--------+
Sat01.cnf |   0    |   0    |
Sat02.cnf |   93   |   27   |
Sat03.cnf |   0    |   0    |
Sat04.cnf |   337  |   128  |
Sat05.cnf |   260  |   95   |
Sat06.cnf |   943  |   101  |
Sat07.cnf |   624  |   5    |
Say08.cnf |   0    |   0    |
Say09.cnf |   300  |   173  |
Say10.cnf |   158  |   19   |
----------+--------+--------+
-}
---------------------------------------------------------------------------

