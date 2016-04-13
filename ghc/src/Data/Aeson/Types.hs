{-# LANGUAGE Haskell98 #-}
{-# LINE 1 "Data/Aeson/Types.hs" #-}







































































{-# LANGUAGE CPP #-}

-- |
-- Module:      Data.Aeson.Types
-- Copyright:   (c) 2011, 2012 Bryan O'Sullivan
--              (c) 2011 MailRank, Inc.
-- License:     Apache
-- Maintainer:  Bryan O'Sullivan <bos@serpentine.com>
-- Stability:   experimental
-- Portability: portable
--
-- Types for working with JSON data.

module Data.Aeson.Types
    (
    -- * Core JSON types
      Value(..)
    , Array
    , emptyArray
    , Pair
    , Object
    , emptyObject
    -- * Convenience types and functions
    , DotNetTime(..)
    , typeMismatch
    -- * Type conversion
    , Parser
    , Result(..)
    , FromJSON(..)
    , fromJSON
    , parse
    , parseEither
    , parseMaybe
    , ToJSON(..)
    , modifyFailure

    -- ** Generic JSON classes
    , GFromJSON(..)
    , GToJSON(..)
    , genericToJSON
    , genericParseJSON

    -- * Inspecting @'Value's@
    , withObject
    , withText
    , withArray
    , withNumber
    , withScientific
    , withBool

    -- * Constructors and accessors
    , (.=)
    , (.:)
    , (.:?)
    , (.!=)
    , object

    -- * Generic and TH encoding configuration
    , Options(..)
    , SumEncoding(..)
    , camelTo
    , defaultOptions
    , defaultTaggedObject
    ) where

import Data.Aeson.Types.Instances
import Data.Aeson.Types.Internal

import Data.Aeson.Types.Generic ()
