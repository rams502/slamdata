{-
Copyright 2016 SlamData, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}

module SlamData.Quasar.Aff where

import SlamData.Prelude

import Data.Date (Now)

import Control.Monad.Aff (Aff)
import Control.Monad.Aff.AVar (AVar)
import Control.Monad.Aff.AVar as AVar
import Control.Monad.Aff.Bus (Bus, Cap)
import Control.Monad.Aff.Free (class Affable, fromAff, fromEff)
import Control.Monad.Eff.Exception as Exn
import Control.Monad.Eff.Random (RANDOM)
import Control.Monad.Eff.Console (CONSOLE)
import Control.Monad.Eff.Ref as Ref

import Control.Monad.Reader.Trans (runReaderT)

import DOM (DOM)

import Network.HTTP.Affjax as AX

import SlamData.Quasar.Auth.Retrieve (retrieveIdToken, fromEither)
import SlamData.Quasar.Auth.Permission (retrieveTokenHashes)
import SlamData.Quasar.Auth.Reauthentication (EIdToken)

import Quasar.Advanced.QuasarAF as QF
import Quasar.Advanced.QuasarAF.Interpreter.Aff as QFA

import OIDCCryptUtils as OIDC

import Utils (passover)
import Utils.At (INTERVAL)

type QEff eff = (interval ∷ INTERVAL, console ∷ CONSOLE, now ∷ Now, rsaSignTime ∷ OIDC.RSASIGNTIME, random ∷ RANDOM, ajax ∷ AX.AJAX, dom ∷ DOM, avar ∷ AVar.AVAR, ref ∷ Ref.REF, err ∷ Exn.EXCEPTION | eff)

-- | Runs a `QuasarF` request in `Aff`, using the `QError` type for errors that
-- | may arise, which allows for convenient catching of 404 errors.
runQuasarF
  ∷ ∀ eff r m e a
  . Affable (QEff eff) m
  ⇒ (Bus (write ∷ Cap | r) (AVar EIdToken))
  → QF.QuasarAFC (Either e a)
  → m (Either e a)
runQuasarF requestNewIdTokenBus qf = (fromAff ∷ ∀ x. Aff (QEff eff) x → m x) do
  fromEff $ Control.Monad.Eff.Console.log "runQuasarF start"
  idToken ← fromEither <$> (passover (\x -> (traceA "runQuasarF") *> (traceAnyA x)) =<< retrieveIdToken requestNewIdTokenBus)
  permissions ← fromEff retrieveTokenHashes
  runReaderT (QFA.eval qf) { basePath: "", idToken, permissions }
