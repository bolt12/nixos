{-# LANGUAGE GHC2024 #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiWayIf #-}

module Main (main) where

import Control.Exception (SomeException, bracket_, catch, try)
import Control.Monad (when)
import Data.Aeson (Value (..), decode, encode, object, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.ByteString.Lazy qualified as LBS
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Data.Text.IO qualified as TIO
import Data.Vector qualified as V
import Network.HTTP.Client
  ( HttpException,
    Request,
    RequestBody (RequestBodyLBS),
    httpLbs,
    method,
    newManager,
    parseRequest,
    requestBody,
    requestHeaders,
    responseBody,
  )
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Options.Applicative
import Options.Applicative.Help.Pretty (vsep)
import System.Console.Haskeline (defaultSettings, getInputLineWithInitial, runInputT)
import System.Directory (findExecutable, getCurrentDirectory, getHomeDirectory, listDirectory)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..), exitFailure, exitWith)
import System.IO
  ( BufferMode (LineBuffering, NoBuffering),
    hFlush,
    hPutStrLn,
    hSetBuffering,
    hSetEcho,
    stderr,
    stdin,
    stdout,
  )
import System.Process (readProcess, system)

data Backend
  = LlamaBackend !Request !Text
  | ClaudeBackend

data Opts = Opts
  { optClaude :: !Bool,
    optInput :: ![Text]
  }

optsParser :: ParserInfo Opts
optsParser =
  info
    (helper <*> parser)
    ( fullDesc
        <> header "ai — natural language shell command generator"
        <> footerDoc
          ( Just $
              vsep
                [ "Environment variables:",
                  "  AI_CMD_URL      OpenAI-compatible API base URL (default: http://10.100.0.100:8080)",
                  "  AI_CMD_MODEL    Model name for llama backend (default: qwen3-coder-next-hass)",
                  "  AI_CMD_BACKEND  Default backend: llama or claude (default: llama)",
                  "",
                  "After generating a command you are prompted:",
                  "  [e]xecute / [n]o / e[d]it",
                  "  e or Enter  Run the command",
                  "  d           Edit the command with readline, then run",
                  "  n / other   Abort"
                ]
          )
    )
  where
    parser :: Parser Opts
    parser =
      Opts
        <$> switch (long "claude" <> help "Use claude-code backend instead of llama")
        <*> many (T.pack <$> strArgument (metavar "REQUEST..." <> help "Natural language request"))

loadConfig :: Opts -> IO Backend
loadConfig opts = do
  envBackend <- lookupEnv "AI_CMD_BACKEND"
  if | optClaude opts              -> pure ClaudeBackend
     | Just "claude" <- envBackend -> pure ClaudeBackend
     | otherwise -> do
        url <- fromMaybe "http://10.100.0.100:8080" <$> lookupEnv "AI_CMD_URL"
        model <- fromMaybe "qwen3-coder-next-hass" <$> lookupEnv "AI_CMD_MODEL"
        req <- parseRequest (url <> "/v1/chat/completions")
        pure $ LlamaBackend req (T.pack model)

buildContext :: IO Text
buildContext = do
  cwd <- getCurrentDirectory
  files <- listDirectory "." `catch` \(_ :: SomeException) -> pure []
  hist <- getHistory
  let filesStr
        | null files = ""
        | otherwise = "\nFiles: " <> T.intercalate ", " (map T.pack (take 20 files))
      histStr
        | T.null hist = ""
        | otherwise = "\nRecent commands:\n" <> hist
  pure $ "OS: NixOS Linux | Shell: bash | CWD: " <> T.pack cwd <> filesStr <> histStr
  where
    getHistory :: IO Text
    getHistory =
      ( do
          home <- getHomeDirectory
          ls <- T.lines <$> TIO.readFile (home <> "/.bash_history")
          pure $ T.unlines $ drop (max 0 (length ls - 10)) ls
      )
        `catch` \(_ :: SomeException) -> pure ""

systemPrompt :: Text
systemPrompt =
  T.unlines
    [ "You translate natural language into shell commands.",
      "Rules:",
      "- Output ONLY the command. No explanations, no markdown, no code fences.",
      "- For multi-step tasks, chain with && or pipes.",
      "- Prefer common coreutils and standard tools."
    ]

fewShotMessages :: [Value]
fewShotMessages =
  [ object ["role" .= ("user" :: Text), "content" .= ("show files modified in the last hour" :: Text)],
    object ["role" .= ("assistant" :: Text), "content" .= ("find . -maxdepth 1 -mmin -60" :: Text)],
    object ["role" .= ("user" :: Text), "content" .= ("count lines of code in all python files" :: Text)],
    object ["role" .= ("assistant" :: Text), "content" .= ("find . -name '*.py' | xargs wc -l" :: Text)],
    object ["role" .= ("user" :: Text), "content" .= ("compress all logs older than 7 days" :: Text)],
    object ["role" .= ("assistant" :: Text), "content" .= ("find /var/log -name '*.log' -mtime +7 -exec gzip {} \\;" :: Text)]
  ]

generate :: Backend -> Text -> Text -> IO Text
generate (LlamaBackend req model) = llamaGenerate req model
generate ClaudeBackend            = claudeGenerate

llamaGenerate :: Request -> Text -> Text -> Text -> IO Text
llamaGenerate baseReq model context request = do
  let userMsg = "[" <> context <> "]\n" <> request
      messages =
        [object ["role" .= ("system" :: Text), "content" .= systemPrompt]]
          <> fewShotMessages
          <> [object ["role" .= ("user" :: Text), "content" .= userMsg]]
      payload =
        encode $
          object
            [ "model" .= model,
              "temperature" .= (0.1 :: Double),
              "max_tokens" .= (512 :: Int),
              "messages" .= messages
            ]

  result <- try $ do
    manager <- newManager tlsManagerSettings
    let req =
          baseReq
            { method = "POST",
              requestHeaders = [("Content-Type", "application/json")],
              requestBody = RequestBodyLBS payload
            }
    responseBody <$> httpLbs req manager

  case result of
    Left (e :: HttpException) -> do
      hPutStrLn stderr $ "HTTP error: " <> show e
      exitFailure
    Right body ->
      pure $ extractContent body

extractContent :: LBS.ByteString -> Text
extractContent body =
  case decodeValue body of
    Just (Object obj)
      | Just (Array choices) <- KM.lookup (Key.fromText "choices") obj,
        Just (Object choice) <- choices V.!? 0,
        Just (Object msg) <- KM.lookup (Key.fromText "message") choice,
        Just (String content) <- KM.lookup (Key.fromText "content") msg ->
          content
    _ -> TE.decodeUtf8 (LBS.toStrict body)
  where
    decodeValue :: LBS.ByteString -> Maybe Value
    decodeValue = decode

claudeGenerate :: Text -> Text -> IO Text
claudeGenerate context request = do
  let prompt =
        T.unpack $
          systemPrompt <> "\nContext:\n" <> context <> "\n\nRequest: " <> request
  T.pack <$> readProcess "claude" ["--print", "-p", prompt] ""

-- ------------------------------------------------------------------ Text Processing

stripCodeFences :: Text -> Text
stripCodeFences =
  T.strip
    . T.unlines
    . filter (not . isCodeFence)
    . T.lines
  where
    isCodeFence line = "```" `T.isPrefixOf` T.stripStart line

-- ------------------------------------------------------------------ Terminal Interaction

promptAction :: IO Char
promptAction = do
  TIO.putStr "[e]xecute / [n]o / e[d]it? "
  hFlush stdout
  bracket_
    (hSetBuffering stdin NoBuffering >> hSetEcho stdin False)
    (hSetBuffering stdin LineBuffering >> hSetEcho stdin True)
    (getChar <* putStrLn "")

runTracked :: String -> IO ExitCode
runTracked cmd = do
  hasAtuin <- findExecutable "atuin"
  case hasAtuin of
    Nothing -> system cmd
    Just _ -> do
      histId <- T.strip . T.pack <$> readProcess "atuin" ["history", "start", cmd] ""
      ec <- system cmd
      let code = case ec of ExitSuccess -> "0"; ExitFailure n -> show n
      _ <- try @SomeException $ readProcess "atuin" ["history", "end", "--exit", code, T.unpack histId] ""
      pure ec

run :: Text -> IO ()
run cmd = runTracked (T.unpack cmd) >>= exitWith

editAndRun :: Text -> IO ()
editAndRun cmd = do
  result <- runInputT defaultSettings (getInputLineWithInitial "$ " (T.unpack cmd, ""))
  case result of
    Nothing -> putStrLn "aborted"
    Just edited -> runTracked edited >>= exitWith

-- ------------------------------------------------------------------ Main

main :: IO ()
main = do
  opts <- execParser optsParser
  backend <- loadConfig opts
  input <- getInput opts
  context <- buildContext

  raw <- generate backend context input

  let cmd = stripCodeFences raw

  when (T.null cmd) $ do
    hPutStrLn stderr "Error: empty response from backend"
    exitFailure

  -- Display in cyan bold
  TIO.putStrLn $ "\n  \ESC[1;36m" <> cmd <> "\ESC[0m\n"

  choice <- promptAction
  case choice of
    'e' -> run cmd
    '\n' -> run cmd
    'd' -> editAndRun cmd
    _ -> putStrLn "aborted"
  where
    getInput :: Opts -> IO Text
    getInput opts
      | not (null (optInput opts)) = pure $ T.unwords (optInput opts)
      | otherwise = do
          TIO.putStr "describe> "
          hFlush stdout
          TIO.getLine
