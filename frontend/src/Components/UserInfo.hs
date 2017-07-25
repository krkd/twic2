{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE RecordWildCards       #-}

module Components.UserInfo where

import Prelude
import Control.Applicative           ((<*>), (<$>))
import Control.Monad                 (void, forM_, when)
import Control.Monad.IO.Class        (liftIO)

import Control.Monad.Fix             (MonadFix)

import qualified Data.List           as DL
import Data.Maybe                    (Maybe(..), isJust, isNothing, listToMaybe, maybe)
import Data.Monoid
import qualified Data.Set            as Set
import qualified Data.Text           as T

import qualified Reflex              as R
import qualified Reflex.Host.App     as RHA

import qualified Data.VirtualDOM     as VD
import qualified JavaScript.Web.WebSocket as WS
import qualified Data.JSString      as JSS
import Web.Twitter.Types (User (..))


import qualified BL.Types           as BL
import BL.Instances

import UIConfig
import Types
import Lib.FRP
import Lib.FW
import Lib.UI
import Lib.Net (getAPI)


-- data UserInfoQuery = RequestUserInfo String

xhrJsonGet :: String -> IO String
xhrJsonGet s = return $ "xhrJsonGet " <> s

userinfoComponent :: (RHA.MonadAppHost t m, MonadFix m) => m (R.Dynamic t (VD.VNode l), Sink UserInfoQuery)
userinfoComponent = do
  liftIO $ print "Hello UserInfo"

  (queryE :: R.Event t UserInfoQuery, queryU) <- RHA.newExternalEvent
  (modelE :: R.Event t (Either String BL.JsonUserInfo), modelU) <- RHA.newExternalEvent
  modelD <- R.holdDyn (Left "") modelE

  subscribeToEvent queryE $ \(RequestUserInfo screenName) -> do
    x <- liftIO . getAPI . JSS.pack $ "http://localhost:3000/userinfo?sn=" <> screenName
    modelU x
    pure ()

  let v = fmap render modelD

  -- show panel
  -- listen for close panel events
  return (v, queryU)

  where
    userInfoStyle User {..} = DL.intercalate ";" [
        "display: block",
        "height: 460px",
        "width: 100%",
        "position: fixed",
        "top: 50%",
        "overflow: hidden",
        "box-shadow: rgb(169, 169, 169) 0px 10px 50px",
        "background-color:" <> maybe "rgba(0,0,0,0.95)" (\c -> "#" <> T.unpack c) userProfileBackgroundColor,
        "background-image:" <> maybe "none" (\src -> "url(" <> T.unpack src <> ")") userProfileBannerURL,
        "background-size:" <> maybe "auto" (const "cover") userProfileBannerURL,
        "color: white",
        "transform: translateY(-300px)",
        "-webkit-transform: translateY(-300px)",
        "z-index: 1000"]
    
    followButton User {..} = maybe
      (VD.text "Unknown status for following")
      (\v -> if not v
        then flip VD.with [VD.On "click" (void . const (print "follow"))] $
          VD.h "button" (VD.prop [("style", DL.intercalate ";" [
            "margin-left: 8px",
            "cursor: pointer",
            "border-radius: 10px",
            "border: 0 solid green",
            "background-color: #B0E57C"])]) [VD.text "Follow"]
        else VD.text "Follow") userFollowRequestSent
      
    unFollowButton User {..} = maybe
      (VD.text "Unknown status for following")
      (\x -> if not x
        then flip VD.with [VD.On "click" (void . const (print "unfollow"))] $
          VD.h "button" (VD.prop [("style", DL.intercalate ";" [
            "margin-left: 8px",
            "cursor: pointer",
            "border-radius: 10px",
            "border: 0 solid red",
            "background-color: #B0E57C"])]) [VD.text "Unfollow"]
        else VD.text "Unfollow") userFollowRequestSent
                    
    renderUser user@User {..} = VD.h "ul" (VD.prop [("style", DL.intercalate ";" [
        "display: block",
        "width: 600px",
        "text-align: left",
        "margin: auto",
        "overflow: hidden",
        "padding: 20px",
        "background-color: rgba(0,0,0,0.3)",
        "height: 420px"])]) [
          VD.h "li" (VD.prop [("style", DL.intercalate ";" [
          "margin: 0",
          "padding: 5px",
          "padding-top: 5px",
          "margin-top: -5px"])]) [VD.h "span" (VD.prop [("style", "font-size: 200%")]) [
            VD.text . T.unpack $ userName, 
            if userVerified 
              then VD.h "span" (VD.prop [("style", "color: blue")]) [VD.text " •"]
              else VD.text "",
            if userProtected
              then VD.h "span" (VD.prop [("style", "color: red")]) [VD.text " •"] 
              else VD.text ""]],
          VD.h "li" (VD.prop [("style", "margin:0; padding: 5px")]) [VD.h "a" (VD.prop [
            ("style", "color: lightgrey"), 
            ("href", "https://twitter.com/" <> T.unpack userScreenName),
            ("target", "_blank")]) [VD.text $ "@" <> T.unpack userScreenName]],
          VD.h "li" (VD.prop [("style", "margin: 0; padding: 5px")]) [
            maybe (VD.text "") (\url -> VD.h "img" (VD.prop [("style", "width: 100px"), ("src", T.unpack url)]) []) userProfileImageURL],
          VD.h "li" (VD.prop [("style", "margin:0; padding: 5px")]) [
            VD.text $ maybe "" T.unpack userDescription],
          VD.h "li" (VD.prop [("style", "margin:0; padding: 5px")]) [
            maybe (VD.text "") (\url -> VD.h "a" (VD.prop [
              ("style", "color: white; text-decoration: underline"), 
              ("href", T.unpack url)]) [VD.text $ T.unpack url]) userURL],
          VD.h "li" (VD.prop [("style", "margin:0; padding: 5px")]) [VD.text $ maybe "" T.unpack userLocation],
          VD.h "li" (VD.prop [("style", "margin:0; padding: 5px")]) [maybe (VD.text "") (\tz -> VD.text $ T.unpack tz <> " timezone") userTimeZone],
          VD.h "li" (VD.prop [("style", "margin:0; padding: 5px")]) [VD.text $ "Register on " <> show userCreatedAt],
          VD.h "li" (VD.prop [("style", "margin:0; padding: 5px")]) [
            VD.text $ show userFollowersCount <> " followers, " <>
                      show userFriendsCount <> " friends, " <>
                      show userStatusesCount <> " tweets"],
          VD.h "li" (VD.prop [("style", "margin:0; padding: 5px")]) [
            maybe 
              (VD.text "Following status unknown") 
              (\fol -> if fol
                then VD.h "span" (VD.prop []) [VD.text "Already following", followButton user, VD.text $ show user]
                else VD.h "span" (VD.prop []) [VD.text "Not following", unFollowButton user]) userFollowing]]
      
    render (Left e) = VD.text e
    render (Right BL.JsonUserInfo {..}) = VD.h "div" (VD.prop [("class", "user-info"), ("style", userInfoStyle uiData)]) [renderUser uiData]