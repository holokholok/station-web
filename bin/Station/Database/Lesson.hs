{-# LANGUAGE QuasiQuotes #-}

module Station.Database.Lesson (
	Identifier, Number,
	Type (Record, identifier, course, number, title, content),
	get, list, delete, add, set, exchange
) where

import Prelude (succ)
import Data.Bool (Bool)
import Data.Eq ((==))
import Data.Maybe (Maybe (Nothing, Just))
import Data.List (map)
import Data.Int (Int32)
import Data.String (String)
import Control.Applicative ((<$>), (<*>))
import Control.Monad (return, (>>=))
import Text.Show (Show, show)
import Text.Read (Read, readsPrec)
import System.IO (IO)
import qualified Database.PostgreSQL.Simple as DB
import qualified Database.PostgreSQL.Simple.ToField as DB
import qualified Database.PostgreSQL.Simple.FromField as DB
import qualified Database.PostgreSQL.Simple.ToRow as DB
import qualified Database.PostgreSQL.Simple.FromRow as DB
import Database.PostgreSQL.Simple.SqlQQ (sql)

import qualified Station.Database.Course as DB.Course

newtype Identifier = Identifier Int32

instance Show Identifier where
	show (Identifier i) = show i

instance Read Identifier where
	readsPrec i s = map (\ (x, r) -> (Identifier x, r)) (readsPrec i s)

instance DB.ToField Identifier where
	toField (Identifier i) = DB.toField i

instance DB.FromField Identifier where
	fromField f x = Identifier <$> DB.fromField f x

type Number = Int32

data Type =
	Record{
		identifier :: Identifier,
		course :: DB.Course.Identifier,
		number :: Number,
		title :: String,
		content :: String}

instance DB.ToRow Type where
	toRow lesson =
		[
			DB.toField (identifier lesson),
			DB.toField (course lesson),
			DB.toField (number lesson),
			DB.toField (title lesson),
			DB.toField (content lesson)]

instance DB.FromRow Type where
	fromRow =
		Record
			<$> DB.field
			<*> DB.field
			<*> DB.field
			<*> DB.field
			<*> DB.field

get :: Identifier -> DB.Connection -> IO [Type]
get lesson_identifier db =
	DB.query
		db
		[sql|
			SELECT "IDENTIFIER","COURSE","NUMBER","TITLE","CONTENT"
				FROM "LESSON"
				WHERE "IDENTIFIER"=? |]
		(DB.Only lesson_identifier)

list :: DB.Course.Identifier -> DB.Connection -> IO [(Identifier, Number, String)]
list course_identifier db =
	DB.query
		db
		[sql|
			SELECT "IDENTIFIER","NUMBER","TITLE"
				FROM "LESSON"
				WHERE "COURSE"=?
				ORDER BY "NUMBER" ASC |]
		(DB.Only course_identifier)

delete :: Identifier -> DB.Connection -> IO Bool
delete lesson_identifier db =
	(1 ==)
		<$>
			DB.execute
				db
				[sql| DELETE FROM "LESSON" WHERE "IDENTIFIER"=? |]
				(DB.Only lesson_identifier)

add :: DB.Course.Identifier -> String -> String -> DB.Connection -> IO (Maybe Identifier)
add lesson_course lesson_title lesson_content db =
	DB.query db [sql| SELECT COUNT(*)::INTEGER FROM "LESSON" WHERE "COURSE"=? |] (DB.Only lesson_course) >>= \case
		[DB.Only n] ->
			(\case
				[DB.Only result] -> (Just result)
				_ -> Nothing)
				<$>
					DB.query
						db
						[sql|
							INSERT INTO "LESSON"("COURSE","NUMBER","TITLE","CONTENT")
								VALUES (?,?,?,?)
								RETURNING "IDENTIFIER" |]
						(lesson_course, succ n :: Number, lesson_title, lesson_content)
		_ -> return Nothing

set :: Type -> DB.Connection -> IO Bool
set lesson db =
	(1 ==)
		<$>
			DB.execute
				db
				[sql|
					UPDATE "LESSON"
						SET "COURSE"=?,"NUMBER"=?,"TITLE"=?,"CONTENT"=?
						WHERE "IDENTIFIER"=? |]
				(course lesson, number lesson, title lesson, content lesson, identifier lesson)

exchange :: Identifier -> Identifier -> DB.Connection -> IO Bool
exchange lesson_1 lesson_2 db =
	(2 ==)
		<$>
			DB.execute
				db
				[sql|
					WITH "L" AS (SELECT * FROM "LESSON" WHERE "IDENTIFIER" IN (?,?))
						UPDATE "LESSON"
							SET "NUMBER"="L2"."NUMBER"
							FROM "L" AS "L1", "L" AS "L2"
							WHERE "LESSON"."IDENTIFIER"="L1"."IDENTIFIER"
								AND "L1"."IDENTIFIER"<>"L2"."IDENTIFIER" |]
				(lesson_1, lesson_2)