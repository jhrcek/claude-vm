#!/usr/bin/env cabal
{- cabal:
build-depends: base, sqlite-simple, text, process, time
-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Database.SQLite.Simple
import           Data.Text (Text)
import qualified Data.Text as T
import           System.Process (readProcess)
import           Data.Time.Clock.POSIX (getPOSIXTime)

dayNum :: Int
dayNum = 4798

portDeckId :: Int
portDeckId = 1723962662242

fieldSep :: Text
fieldSep = "\US"

main :: IO ()
main = do
  conn <- open "collection.anki2"

  rows <- query conn
    "SELECT DISTINCT n.id, n.flds \
    \FROM cards c JOIN notes n ON n.id = c.nid \
    \WHERE c.did = ? AND c.queue = 2 AND c.due <= ?"
    (portDeckId, dayNum)
    :: IO [(Int, Text)]

  now <- round <$> getPOSIXTime :: IO Int

  mapM_ (processNote conn now) rows
  close conn

processNote :: Connection -> Int -> (Int, Text) -> IO ()
processNote conn now (nid, flds) = do
  let fields = T.splitOn fieldSep flds
      portuguese = T.unpack (fields !! 1)
      noteField  = fields !! 2

  sentence <- T.strip . T.pack <$>
    readProcess "./generate_sentence.sh" [portuguese] ""

  let newNote   = noteField <> "<br>" <> sentence
      newFields = replaceAt 2 newNote fields
      newFlds   = T.intercalate fieldSep newFields

  execute conn
    "UPDATE notes SET flds = ?, mod = ?, usn = -1 WHERE id = ?"
    (newFlds, now, nid)

replaceAt :: Int -> a -> [a] -> [a]
replaceAt i x xs = take i xs ++ [x] ++ drop (i + 1) xs
