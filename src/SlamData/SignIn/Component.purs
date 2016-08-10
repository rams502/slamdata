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

module SlamData.SignIn.Component
  ( comp
  , MenuSlot
  , QueryP
  , StateP
  , ChildQuery
  , Query(..)
  , ChildSlot
  , ChildState
  , module SlamData.SignIn.Component.State
  ) where

import SlamData.Prelude

import Control.UI.Browser as Browser
import Control.Monad.Aff.Bus as Bus
import Control.Monad.Aff.Bus (Bus, Cap)
import Control.Monad.Aff.AVar (AVar)
import Control.Coroutine.Stalling as StallingCoroutine

import Halogen as H
import Halogen.HTML.Core (className)
import Halogen.HTML.Indexed as HH
import Halogen.HTML.Properties.Indexed as HP
import Halogen.Menu.Component (MenuQuery(..), menuComponent) as HalogenMenu
import Halogen.Menu.Component.State (makeMenu)
import Halogen.Menu.Submenu.Component (SubmenuQuery(..)) as HalogenMenu
import Halogen.Query.EventSource as HE

import OIDC.Aff as OIDC
import OIDCCryptUtils as Crypt

import Quasar.Advanced.Types (ProviderR)

import SlamData.Analytics as Analytics
import SlamData.Config as Config
import SlamData.Effects (Slam)
import SlamData.Quasar as Api
import SlamData.Quasar.Auth.IdTokenStorageEvents as IdTokenStorageEvents
import SlamData.Quasar.Auth.Reauthentication (EIdToken)
import SlamData.Quasar.Auth.Retrieve as AuthRetrieve
import SlamData.Quasar.Auth.Store as AuthStore
import SlamData.SignIn.Bus (SignInMessage(..), SignInBusW)
import SlamData.SignIn.Component.State (State, initialState)
import SlamData.SignIn.Menu.Component.Query (QueryP) as Menu
import SlamData.SignIn.Menu.Component.State (StateP, makeSubmenuItem, make) as Menu

import Utils.DOM as DOMUtils

data Query a
  = DismissSubmenu a
  | SignedIn a
  | Init a

type QueryP = Coproduct Query (H.ChildF MenuSlot ChildQuery)

data MenuSlot = MenuSlot

derive instance genericMenuSlot ∷ Generic MenuSlot
derive instance eqMenuSlot ∷ Eq MenuSlot
derive instance ordMenuSlot ∷ Ord MenuSlot

type ChildSlot = MenuSlot

type ChildQuery = Menu.QueryP

type ChildState g = Menu.StateP g

type StateP = H.ParentState State (ChildState Slam) Query ChildQuery Slam ChildSlot
type SignInHTML = H.ParentHTML (ChildState Slam) Query ChildQuery Slam ChildSlot
type SignInDSL = H.ParentDSL State (ChildState Slam) Query ChildQuery Slam ChildSlot

comp
  ∷ ∀ r s
  . (Bus (write ∷ Cap | r) (AVar EIdToken))
  → SignInBusW s
  → H.Component StateP QueryP Slam
comp requestNewIdTokenBus signInBus =
  H.lifecycleParentComponent
    { render
    , eval
    , peek: Just (menuPeek ∘ H.runChildF)
    , initializer: Just (H.action Init)
    , finalizer: Nothing
    }
  where
  render ∷ State → SignInHTML
  render state =
    HH.div
      [ HP.classes $ [ className "sd-sign-in" ] ]
      $ guard (not state.hidden)
      $> HH.slot MenuSlot \_ →
          { component: HalogenMenu.menuComponent
          , initialState: H.parentState $ Menu.make []
          }

  eval ∷ Query ~> SignInDSL
  eval  (DismissSubmenu next) = dismissAll $> next
  eval  (SignedIn next) =
    sendMessage *> update $> next
    where
    sendMessage = H.fromAff $ Bus.write SignInSuccess signInBus
  eval (Init next) = subscribeToIdTokenEvents *> update $> next

  subscribeToIdTokenEvents :: SignInDSL Unit
  subscribeToIdTokenEvents =
    H.subscribe'
      ∘ HE.EventSource
      ∘ StallingCoroutine.mapStallingProducer (const $ SignedIn unit)
      =<< H.fromEff IdTokenStorageEvents.getIdTokenStorageEvents

  update ∷ SignInDSL Unit
  update = do
    H.fromEff $ Control.Monad.Eff.Console.log "signIn start"
    mbIdToken ← H.fromAff $ AuthRetrieve.fromEither <$> (Utils.passover (\x -> (traceA "signIn") *> (traceAnyA x)) =<< AuthRetrieve.retrieveIdToken requestNewIdTokenBus)
    traverse_ H.fromEff $ Analytics.identify <$> (Crypt.pluckEmail =<< mbIdToken)
    maybe
      retrieveProvidersAndUpdateMenu
      putEmailToMenu
      mbIdToken
    where
    putEmailToMenu ∷ Crypt.IdToken → SignInDSL Unit
    putEmailToMenu token = do
      H.query MenuSlot
        $ left
        $ H.action
        $ HalogenMenu.SetMenu
        $ makeMenu
          [ { label:
                fromMaybe "unknown user"
                $ map Crypt.runEmail
                $ Crypt.pluckEmail token
            , submenu:
                [ { label: "🔒 Sign out"
                  , shortcutLabel: Nothing
                  , value: Nothing
                  }
                ]
            }
          ]
      H.modify (_{loggedIn = true})

    retrieveProvidersAndUpdateMenu ∷ SignInDSL Unit
    retrieveProvidersAndUpdateMenu = do
      eProviders ← H.fromAff $ Api.retrieveAuthProviders requestNewIdTokenBus
      case eProviders of
        Left _ → H.modify (_{hidden = true})
        Right Nothing → H.modify (_{hidden = true})
        Right (Just []) → H.modify (_{hidden = true})
        Right (Just providers) →
          void
          $ H.query MenuSlot
          $ left
          $ H.action
          $ HalogenMenu.SetMenu
          $ makeMenu
            [ { label: "🔓 Sign in"
              , submenu: Menu.makeSubmenuItem <$> providers
              }
            ]

  dismissAll ∷ SignInDSL Unit
  dismissAll =
    queryMenu $
      H.action HalogenMenu.DismissSubmenu

  menuPeek
    ∷ ∀ a
    . Menu.QueryP a
    → SignInDSL Unit
  menuPeek =
    coproduct
      (const (pure unit))
      (submenuPeek ∘ H.runChildF)

  submenuPeek
    ∷ ∀ a
    . HalogenMenu.SubmenuQuery (Maybe ProviderR) a
    → SignInDSL Unit
  submenuPeek (HalogenMenu.SelectSubmenuItem v _) = do
    {loggedIn} ← H.get
    if loggedIn
      then logOut
      else for_ v $ either (const $ pure unit) (H.fromEff ∘ DOMUtils.openPopup) <=< requestAuthenticationURI
    pure unit
    where
    logOut ∷ SignInDSL Unit
    logOut = do
      H.fromEff do
        AuthStore.clearIdToken
        Browser.reload
    appendAuthPath s = s ++ Config.redirectURIString
    requestAuthenticationURI pr =
      H.fromEff
        $ OIDC.requestAuthenticationURI OIDC.Login pr
        ∘ appendAuthPath
        =<< Browser.locationString

  queryMenu
    ∷ HalogenMenu.MenuQuery (Maybe ProviderR) Unit
    → SignInDSL Unit
  queryMenu q = void $ H.query MenuSlot (left q)
