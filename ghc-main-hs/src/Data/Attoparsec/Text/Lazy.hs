{-# LANGUAGE Haskell98 #-}
{-# LINE 1 "Data/Attoparsec/Text/Lazy.hs" #-}
{-# OPTIONS_GHC -fno-warn-warnings-deprecations #-}
-- |
-- Module      :  Data.Attoparsec.Text.Lazy
-- Copyright   :  Bryan O'Sullivan 2007-2014
-- License     :  BSD3
--
-- Maintainer  :  bos@serpentine.com
-- Stability   :  experimental
-- Portability :  unknown
--
-- Simple, efficient combinator parsing that can consume lazy 'Text'
-- strings, loosely based on the Parsec library.
--
-- This is essentially the same code as in the 'Data.Attoparsec.Text'
-- module, only with a 'parse' function that can consume a lazy
-- 'Text' incrementally, and a 'Result' type that does not allow
-- more input to be fed in.  Think of this as suitable for use with a
-- lazily read file, e.g. via 'L.readFile' or 'L.hGetContents'.
--
-- /Note:/ The various parser functions and combinators such as
-- 'string' still expect /strict/ 'T.Text' parameters, and return
-- strict 'T.Text' results.  Behind the scenes, strict 'T.Text' values
-- are still used internally to store parser input and manipulate it
-- efficiently.

module Data.Attoparsec.Text.Lazy
    (
      Result(..)
    , module Data.Attoparsec.Text
    -- * Running parsers
    , parse
    , parseTest
    -- ** Result conversion
    , maybeResult
    , eitherResult
    ) where

import Control.DeepSeq (NFData(rnf))
import Data.Text.Lazy.Internal (Text(..), chunk)
import qualified Data.Attoparsec.Internal.Types as T
import qualified Data.Attoparsec.Text as A
import qualified Data.Text as T
import Data.Attoparsec.Text hiding (IResult(..), Result, eitherResult,
                                    maybeResult, parse, parseWith, parseTest)

-- | The result of a parse.
data Result r = Fail Text [String] String
              -- ^ The parse failed.  The 'ByteString' is the input
              -- that had not yet been consumed when the failure
              -- occurred.  The @[@'String'@]@ is a list of contexts
              -- in which the error occurred.  The 'String' is the
              -- message describing the error, if any.
              | Done Text r
              -- ^ The parse succeeded.  The 'ByteString' is the
              -- input that had not yet been consumed (if any) when
              -- the parse succeeded.

instance Show r => Show (Result r) where
    show (Fail bs stk msg) =
        "Fail " ++ show bs ++ " " ++ show stk ++ " " ++ show msg
    show (Done bs r)       = "Done " ++ show bs ++ " " ++ show r

instance NFData r => NFData (Result r) where
    rnf (Fail bs ctxs msg) = rnf bs `seq` rnf ctxs `seq` rnf msg
    rnf (Done bs r)        = rnf bs `seq` rnf r
    {-# INLINE rnf #-}

fmapR :: (a -> b) -> Result a -> Result b
fmapR _ (Fail st stk msg) = Fail st stk msg
fmapR f (Done bs r)       = Done bs (f r)

instance Functor Result where
    fmap = fmapR

-- | Run a parser and return its result.
parse :: A.Parser a -> Text -> Result a
parse p s = case s of
              Chunk x xs -> go (A.parse p x) xs
              empty      -> go (A.parse p T.empty) empty
  where
    go (T.Fail x stk msg) ys      = Fail (chunk x ys) stk msg
    go (T.Done x r) ys            = Done (chunk x ys) r
    go (T.Partial k) (Chunk y ys) = go (k y) ys
    go (T.Partial k) empty        = go (k T.empty) empty

-- | Run a parser and print its result to standard output.
parseTest :: (Show a) => A.Parser a -> Text -> IO ()
parseTest p s = print (parse p s)

-- | Convert a 'Result' value to a 'Maybe' value.
maybeResult :: Result r -> Maybe r
maybeResult (Done _ r) = Just r
maybeResult _          = Nothing

-- | Convert a 'Result' value to an 'Either' value.
eitherResult :: Result r -> Either String r
eitherResult (Done _ r)     = Right r
eitherResult (Fail _ _ msg) = Left msg
