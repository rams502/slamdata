-- | Low level url-hash service
module Hash (setHash, getHash, changed, Hash(..)) where

import Control.Monad.Eff
import Data.String.Regex (replace, regex, noFlags)
import Utils (hashChanged, parent)

type Hash = String
type State = String
type Action = String

foreign import getHashImpl """
function getHashImpl() {
  return document.location.hash;
}
""" :: forall e. Eff e Hash


getHash :: forall e. Eff e Hash
getHash = do
  let rgx = regex "^#" noFlags
  raw <- getHashImpl
  return $ replace rgx "" raw
  

foreign import setHashImpl """
function setHashImpl(string) {
  return function() {
    document.location.hash = string;
  };
}
""" :: forall e. String -> Eff e Unit

setHash :: forall e. String -> Eff e Unit
setHash hash = do
  setHashImpl hash


changed :: forall e. Eff e Unit -> Eff e Unit
changed act = hashChanged (\_ _ -> act)
