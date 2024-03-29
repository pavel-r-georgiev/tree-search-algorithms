-- Propositional Inference

module Main where

import System.Environment
import Inf2d
import SatParser

main = do
        args <- getArgs
        sat <- getExample (args!!0)
        case (map (\x -> (x!!0)) (filter (\x -> x /= [[]]) sat)) of
         [] -> putStrLn "Not a valid Sat problem"
         sentence -> test sentence (read (args!!1)::Float) (read (args!!2)::Int)


test sentence prob maxflips = do
                 putStrLn "Using WalkSat ..." 
                 walksat <- walkSat sentence prob maxflips
  		 case walksat of
  		   Nothing -> putStrLn("WalkSat: Returned failure!")
		   Just (m,f) -> putStrLn ("WalkSat: Found model for sentence in " ++ (show (maxflips - f)) ++ " flips.")


