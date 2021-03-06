module Main.Update exposing (update)

import Box.Model as Box
import Box.Update as Box
import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import Data.User as User
import Firebase
import Http
import Json.Decode as Decode
import Main.Model exposing (..)
import Routing exposing (Route)
import SignIn.Model as SignIn
import SignIn.Update as SignIn
import SignUp.Model as SignUp
import SignUp.Update as SignUp
import Task
import Time
import Url
import Util exposing (Updater, alert)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequest request ->
            case request of
                Internal url ->
                    ( model
                    , Nav.pushUrl model.key (Url.toString url)
                    )

                External url ->
                    ( model
                    , Cmd.none
                    )

        UrlChanged url ->
            let
                ( state, cmd ) =
                    pageInit model <| Routing.parseUrl url
            in
            ( { model | pageState = state, isActive = False }
            , cmd
            )

        ToggleBurger ->
            ( { model | isActive = not model.isActive }, Cmd.none )

        SignOut ->
            ( model, Firebase.signOut () )

        GetUser value ->
            let
                user =
                    value
                        |> Decode.decodeValue User.decoder
                        |> Result.toMaybe
            in
            ( { model | user = user }, Nav.pushUrl model.key "/" )

        SuccessSignOut _ ->
            ( { model | user = Nothing }, Nav.pushUrl model.key "/signin" )

        BoxInit zone ->
            ( { model | pageState = Box.init zone |> Box |> Loaded }, Cmd.none )

        _ ->
            pageUpdate (getPage model.pageState) msg model


pageUpdate : Page -> Msg -> Model -> ( Model, Cmd Msg )
pageUpdate page msg model =
    case ( msg, page ) of
        ( SignInMsg subMsg, SignIn subModel ) ->
            pageUpdater model SignIn SignInMsg subMsg subModel SignIn.update

        ( SignUpMsg subMsg, SignUp subModel ) ->
            pageUpdater model SignUp SignUpMsg subMsg subModel SignUp.update

        ( BoxMsg subMsg, Box subModel ) ->
            pageUpdater model Box BoxMsg subMsg subModel Box.update

        _ ->
            ( model, Cmd.none )


pageUpdater :
    Model
    -> (subModel -> Page)
    -> (subMsg -> Msg)
    -> subMsg
    -> subModel
    -> Updater subMsg subModel
    -> ( Model, Cmd Msg )
pageUpdater model page msg subMsg subModel updater =
    let
        ( newModel, newCmd ) =
            updater subMsg subModel
    in
    ( { model | pageState = Loaded <| page newModel }
    , Cmd.map msg newCmd
    )


pageInit : Model -> Route -> ( PageState, Cmd Msg )
pageInit model route =
    case route of
        Routing.Home ->
            ( Loaded Home, Cmd.none )

        Routing.SignUp ->
            ( Loaded <| SignUp <| SignUp.init model.key, Cmd.none )

        Routing.SignIn ->
            ( Loaded <| SignIn SignIn.init, Cmd.none )

        Routing.Box ->
            ( Transition <| getPage model.pageState, Task.perform BoxInit Time.here )

        Routing.NotFound ->
            ( Loaded NotFound, Cmd.none )
