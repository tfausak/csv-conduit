{-| 

  This module exports the underlying Attoparsec row parser. This is helpful if
  you want to do some ad-hoc CSV string parsing.

-}

module Data.CSV.Conduit.Parser.Text
    ( parseCSV
    , parseRow
    , row
    , csv
    ) where

-------------------------------------------------------------------------------
import           Control.Applicative
import           Control.Monad (mzero, mplus, foldM, when, liftM)
import           Control.Monad.IO.Class (liftIO, MonadIO)
import           Data.Attoparsec.Text as P hiding (take)
import qualified Data.Attoparsec.Text as T
import qualified Data.Map as M
import           Data.Text (Text)
import qualified Data.Text as T
import           Data.Word (Word8)
-------------------------------------------------------------------------------
import           Data.CSV.Conduit.Types
-------------------------------------------------------------------------------


------------------------------------------------------------------------------
-- | Try to parse given string as CSV
parseCSV :: CSVSettings -> Text -> Either String [Row Text]
parseCSV s = parseOnly $ csv s


------------------------------------------------------------------------------
-- | Try to parse given string as 'Row Text'
parseRow :: CSVSettings -> Text -> Either String (Maybe (Row Text))
parseRow s = parseOnly $ row s


------------------------------------------------------------------------------
-- | Parse CSV
csv :: CSVSettings -> Parser [Row Text]
csv s = do
  r <- row s
  end <- atEnd
  case end of
    True -> case r of
      Just x -> return [x]
      Nothing -> return []
    False -> do
      rest <- csv s
      return $ case r of
        Just x -> x : rest
        Nothing -> rest


------------------------------------------------------------------------------
-- | Parse a CSV row
row :: CSVSettings -> Parser (Maybe (Row Text))
row csvs = csvrow csvs <|> badrow


badrow :: Parser (Maybe (Row Text))
badrow = P.takeWhile (not . T.isEndOfLine) *> 
         (T.endOfLine <|> T.endOfInput) *> return Nothing

csvrow :: CSVSettings -> Parser (Maybe (Row Text))
csvrow c = 
  let rowbody = (quotedField' <|> (field c)) `sepBy` T.char (csvSep c)
      properrow = rowbody <* (T.endOfLine <|> P.endOfInput)
      quotedField' = case csvQuoteChar c of
          Nothing -> mzero
          Just q' -> try (quotedField q')
  in do
    res <- properrow
    return $ Just res

field :: CSVSettings -> Parser Text
field s = P.takeWhile (isFieldChar s) 

isFieldChar s = notInClass xs'
  where xs = csvSep s : "\n\r"
        xs' = case csvQuoteChar s of 
          Nothing -> xs
          Just x -> x : xs

quotedField :: Char -> Parser Text
quotedField c = 
  let quoted = string dbl *> return c
      dbl = T.pack [c,c]
  in do
  T.char c 
  f <- many (T.notChar c <|> quoted)
  T.char c 
  return $ T.pack f


