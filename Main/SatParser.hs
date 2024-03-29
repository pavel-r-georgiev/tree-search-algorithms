-- Propositional Inference

module SatParser where

import System.Environment
import Text.ParserCombinators.Parsec
import System.IO
import Data.Char
import Data.List
import Prop
import Inf2d 

getExample file = do
                    satfile <- openFile file ReadMode
                    sentence <- doRead satfile []
                    hClose satfile
                    return sentence
 
doRead satfile clauses = do 
                          fileopen <- hIsEOF satfile
                          case fileopen of
                             True -> return clauses
                             False -> do 
                                        line <- hGetLine satfile
                                        doRead satfile ((readClause line):clauses)

readClause line = case (parse parseClause "" line) of
    Left err -> return []
    Right clause -> return clause 
                   

parseSymbol :: Parser Symbol
parseSymbol = do{ 
                 x <- many1 (char '-' <|> digit);
                 many (char ' ');
                 if (not (SatParser.isNumber x)) 
                  then fail ""
                  else if ((x!!0) == '-') 
                    then return (LTR (False,tail x))
                    else return (LTR (True,x))
                      
                 }

isNumber ('-':[]) = False
isNumber ('-':xs) = and (map (\x -> (isDigit x)) xs)
isNumber (x:xs) = if (isDigit x)
                       then and (map (\x -> (isDigit x)) xs)
                       else False

parseClause :: Parser Clause
parseClause = do {many (char ' ');
                  symbols <- many1 parseSymbol; 
                  many (char ' ');
                  return (filter (\x -> x /= LTR (True,"0")) symbols)
                 }

