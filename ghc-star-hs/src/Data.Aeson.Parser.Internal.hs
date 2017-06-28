{-# LANGUAGE Haskell2010 #-}
{-# LINE 1 "Data/Aeson/Parser/Internal.hs" #-}

































































































{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MagicHash #-}

-- |
-- Module:      Data.Aeson.Parser.Internal
-- Copyright:   (c) 2011-2016 Bryan O'Sullivan
--              (c) 2011 MailRank, Inc.
-- License:     BSD3
-- Maintainer:  Bryan O'Sullivan <bos@serpentine.com>
-- Stability:   experimental
-- Portability: portable
--
-- Efficiently and correctly parse a JSON string.  The string must be
-- encoded as UTF-8.

module Data.Aeson.Parser.Internal
    (
    -- * Lazy parsers
      json, jsonEOF
    , value
    , jstring
    -- * Strict parsers
    , json', jsonEOF'
    , value'
    -- * Helpers
    , decodeWith
    , decodeStrictWith
    , eitherDecodeWith
    , eitherDecodeStrictWith
    ) where

import Prelude ()
import Prelude.Compat

import Control.Applicative ((<|>))
import Control.Monad (void, when)
import Data.Aeson.Types.Internal (IResult(..), JSONPath, Result(..), Value(..))
import Data.Attoparsec.ByteString.Char8 (Parser, char, decimal, endOfInput, isDigit_w8, signed, string)
import Data.Scientific (Scientific)
import Data.Text (Text)
import Data.Vector as Vector (Vector, empty, fromListN, reverse)
import qualified Data.Attoparsec.ByteString as A
import qualified Data.Attoparsec.Lazy as L
import qualified Data.ByteString as B
import qualified Data.ByteString.Unsafe as B
import qualified Data.ByteString.Lazy as L
import qualified Data.HashMap.Strict as H
import qualified Data.Scientific as Sci
import Data.Aeson.Parser.Unescape (unescapeText)

import GHC.Base (Int#, (==#), isTrue#, word2Int#)
import GHC.Word (Word8(W8#))


-- | Parse a top-level JSON value.
--
-- The conversion of a parsed value to a Haskell value is deferred
-- until the Haskell value is needed.  This may improve performance if
-- only a subset of the results of conversions are needed, but at a
-- cost in thunk allocation.
--
-- This function is an alias for 'value'. In aeson 0.8 and earlier, it
-- parsed only object or array types, in conformance with the
-- now-obsolete RFC 4627.
json :: Parser Value
json = value

-- | Parse a top-level JSON value.
--
-- This is a strict version of 'json' which avoids building up thunks
-- during parsing; it performs all conversions immediately.  Prefer
-- this version if most of the JSON data needs to be accessed.
--
-- This function is an alias for 'value''. In aeson 0.8 and earlier, it
-- parsed only object or array types, in conformance with the
-- now-obsolete RFC 4627.
json' :: Parser Value
json' = value'

object_ :: Parser Value
object_ = {-# SCC "object_" #-} Object <$> objectValues jstring value

object_' :: Parser Value
object_' = {-# SCC "object_'" #-} do
  !vals <- objectValues jstring' value'
  return (Object vals)
 where
  jstring' = do
    !s <- jstring
    return s

objectValues :: Parser Text -> Parser Value -> Parser (H.HashMap Text Value)
objectValues str val = do
  skipSpace
  w <- A.peekWord8'
  if w == 125
    then A.anyWord8 >> return H.empty
    else loop []
 where
  -- Why use acc pattern here, you may ask? because 'H.fromList' use 'unsafeInsert'
  -- and it's much faster because it's doing in place update to the 'HashMap'!
  loop acc = do
    k <- str <* skipSpace <* char ':'
    v <- val <* skipSpace
    ch <- A.satisfy $ \w -> w == 44 || w == 125
    let acc' = (k, v) : acc
    if ch == 44
      then skipSpace >> loop acc'
      else return (H.fromList acc')
{-# INLINE objectValues #-}

array_ :: Parser Value
array_ = {-# SCC "array_" #-} Array <$> arrayValues value

array_' :: Parser Value
array_' = {-# SCC "array_'" #-} do
  !vals <- arrayValues value'
  return (Array vals)

arrayValues :: Parser Value -> Parser (Vector Value)
arrayValues val = do
  skipSpace
  w <- A.peekWord8'
  if w == 93
    then A.anyWord8 >> return Vector.empty
    else loop [] 1
  where
    loop acc !len = do
      v <- val <* skipSpace
      ch <- A.satisfy $ \w -> w == 44 || w == 93
      if ch == 44
        then skipSpace >> loop (v:acc) (len+1)
        else return (Vector.reverse (Vector.fromListN len (v:acc)))
{-# INLINE arrayValues #-}

-- | Parse any JSON value.  You should usually 'json' in preference to
-- this function, as this function relaxes the object-or-array
-- requirement of RFC 4627.
--
-- In particular, be careful in using this function if you think your
-- code might interoperate with Javascript.  A na&#xef;ve Javascript
-- library that parses JSON data using @eval@ is vulnerable to attack
-- unless the encoded data represents an object or an array.  JSON
-- implementations in other languages conform to that same restriction
-- to preserve interoperability and security.
value :: Parser Value
value = do
  skipSpace
  w <- A.peekWord8'
  case w of
    34  -> A.anyWord8 *> (String <$> jstring_)
    123    -> A.anyWord8 *> object_
    91   -> A.anyWord8 *> array_
    102           -> string "false" *> pure (Bool False)
    116           -> string "true" *> pure (Bool True)
    110           -> string "null" *> pure Null
    _              | w >= 48 && w <= 57 || w == 45
                  -> Number <$> scientific
      | otherwise -> fail "not a valid json value"

-- | Strict version of 'value'. See also 'json''.
value' :: Parser Value
value' = do
  skipSpace
  w <- A.peekWord8'
  case w of
    34  -> do
                     !s <- A.anyWord8 *> jstring_
                     return (String s)
    123    -> A.anyWord8 *> object_'
    91   -> A.anyWord8 *> array_'
    102           -> string "false" *> pure (Bool False)
    116           -> string "true" *> pure (Bool True)
    110           -> string "null" *> pure Null
    _              | w >= 48 && w <= 57 || w == 45
                  -> do
                     !n <- scientific
                     return (Number n)
      | otherwise -> fail "not a valid json value"

-- | Parse a quoted JSON string.
jstring :: Parser Text
jstring = A.word8 34 *> jstring_

-- | Parse a string without a leading quote.
jstring_ :: Parser Text
{-# INLINE jstring_ #-}
jstring_ = {-# SCC "jstring_" #-} do
  s <- A.scan startState go <* A.anyWord8
  case unescapeText s of
    Right r  -> return r
    Left err -> fail $ show err
 where
    startState              = S 0#
    go (S a) (W8# c)
      | isTrue# a                     = Just (S 0#)
      | isTrue# (word2Int# c ==# 34#) = Nothing   -- double quote
      | otherwise = let a' = word2Int# c ==# 92#  -- backslash
                    in Just (S a')

data S = S Int#
-- This hint will no longer trigger once hlint > 1.9.41 is released.
{-# ANN S ("HLint: ignore Use newtype instead of data" :: String) #-}

decodeWith :: Parser Value -> (Value -> Result a) -> L.ByteString -> Maybe a
decodeWith p to s =
    case L.parse p s of
      L.Done _ v -> case to v of
                      Success a -> Just a
                      _         -> Nothing
      _          -> Nothing
{-# INLINE decodeWith #-}

decodeStrictWith :: Parser Value -> (Value -> Result a) -> B.ByteString
                 -> Maybe a
decodeStrictWith p to s =
    case either Error to (A.parseOnly p s) of
      Success a -> Just a
      _         -> Nothing
{-# INLINE decodeStrictWith #-}

eitherDecodeWith :: Parser Value -> (Value -> IResult a) -> L.ByteString
                 -> Either (JSONPath, String) a
eitherDecodeWith p to s =
    case L.parse p s of
      L.Done _ v     -> case to v of
                          ISuccess a      -> Right a
                          IError path msg -> Left (path, msg)
      L.Fail _ _ msg -> Left ([], msg)
{-# INLINE eitherDecodeWith #-}

eitherDecodeStrictWith :: Parser Value -> (Value -> IResult a) -> B.ByteString
                       -> Either (JSONPath, String) a
eitherDecodeStrictWith p to s =
    case either (IError []) to (A.parseOnly p s) of
      ISuccess a      -> Right a
      IError path msg -> Left (path, msg)
{-# INLINE eitherDecodeStrictWith #-}

-- $lazy
--
-- The 'json' and 'value' parsers decouple identification from
-- conversion.  Identification occurs immediately (so that an invalid
-- JSON document can be rejected as early as possible), but conversion
-- to a Haskell value is deferred until that value is needed.
--
-- This decoupling can be time-efficient if only a smallish subset of
-- elements in a JSON value need to be inspected, since the cost of
-- conversion is zero for uninspected elements.  The trade off is an
-- increase in memory usage, due to allocation of thunks for values
-- that have not yet been converted.

-- $strict
--
-- The 'json'' and 'value'' parsers combine identification with
-- conversion.  They consume more CPU cycles up front, but have a
-- smaller memory footprint.

-- | Parse a top-level JSON value followed by optional whitespace and
-- end-of-input.  See also: 'json'.
jsonEOF :: Parser Value
jsonEOF = json <* skipSpace <* endOfInput

-- | Parse a top-level JSON value followed by optional whitespace and
-- end-of-input.  See also: 'json''.
jsonEOF' :: Parser Value
jsonEOF' = json' <* skipSpace <* endOfInput

-- | The only valid whitespace in a JSON document is space, newline,
-- carriage return, and tab.
skipSpace :: Parser ()
skipSpace = A.skipWhile $ \w -> w == 0x20 || w == 0x0a || w == 0x0d || w == 0x09
{-# INLINE skipSpace #-}

------------------ Copy-pasted and adapted from attoparsec ------------------

-- A strict pair
data SP = SP !Integer {-# UNPACK #-}!Int

decimal0 :: Parser Integer
decimal0 = do
  let step a w = a * 10 + fromIntegral (w - zero)
      zero = 48
  digits <- A.takeWhile1 isDigit_w8
  if B.length digits > 1 && B.unsafeHead digits == zero
    then fail "leading zero"
    else return (B.foldl' step 0 digits)

{-# INLINE scientific #-}
scientific :: Parser Scientific
scientific = do
  let minus = 45
      plus  = 43
  sign <- A.peekWord8'
  let !positive = sign == plus || sign /= minus
  when (sign == plus || sign == minus) $
    void A.anyWord8

  n <- decimal0

  let f fracDigits = SP (B.foldl' step n fracDigits)
                        (negate $ B.length fracDigits)
      step a w = a * 10 + fromIntegral (w - 48)

  dotty <- A.peekWord8
  -- '.' -> ascii 46
  SP c e <- case dotty of
              Just 46 -> A.anyWord8 *> (f <$> A.takeWhile1 isDigit_w8)
              _       -> pure (SP n 0)

  let !signedCoeff | positive  =  c
                   | otherwise = -c

  let littleE = 101
      bigE    = 69
  (A.satisfy (\ex -> ex == littleE || ex == bigE) *>
      fmap (Sci.scientific signedCoeff . (e +)) (signed decimal)) <|>
    return (Sci.scientific signedCoeff    e)
