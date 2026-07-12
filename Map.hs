module Map where

import System.Environment (getArgs)
import Data.Char (isDigit, isSpace)

type City = String
type Item = String
type Turn = Int

data Agent
    = Ladrao
    | Detetive
    deriving (Eq, Show)

data Movement = Movement Agent Turn City City
    deriving Show

data Theft = Theft City Item
    deriving Show

data GameGraph = GameGraph [Movement] [Theft]
    deriving Show

data ParsedEvent
    = ParsedMove Movement
    | ParsedTheft Theft
    deriving Show

data NodeMark = NodeMark City String
    deriving Show

parseLog :: String -> GameGraph
parseLog input =
    foldl addEvent emptyGraph events
    where
        events = concatMap parseLine (lines input)

emptyGraph :: GameGraph
emptyGraph = GameGraph [] []

addEvent :: GameGraph -> ParsedEvent -> GameGraph
addEvent (GameGraph moves thefts) (ParsedMove m) =
    GameGraph (m : moves) thefts

addEvent (GameGraph moves thefts) (ParsedTheft t) =
    GameGraph moves (t : thefts)

parseLine :: String -> [ParsedEvent]
parseLine raw
    | startsWith ">>>>Eventoroubo(" line =
        case parseTheftEvent line of
            Just t -> [ParsedTheft t]
            Nothing -> []
    | contains "ladrao:" line =
        case parseActionLine Ladrao line of
            Just m -> [ParsedMove m]
            Nothing -> []
    | contains "detetive:" line =
        case parseActionLine Detetive line of
            Just m -> [ParsedMove m]
            Nothing -> []
    | otherwise =
        []
    where
        line = normalize raw

normalize :: String -> String
normalize texto =
    filter notSpace texto

notSpace :: Char -> Bool
notSpace c =
    not (isSpace c)

startsWith :: String -> String -> Bool
startsWith prefix str =
    take (length prefix) str == prefix

contains :: String -> String -> Bool
contains needle haystack =
    if startsWith needle haystack
        then True
        else case haystack of
            [] -> False
            (_ : rest) -> contains needle rest

parseActionLine :: Agent -> String -> Maybe Movement
parseActionLine ag line =
    if contains "[OK]" line
        then case span isDigit line of
            ("", _) ->
                Nothing
            (turnText, rest) ->
                case parseMove rest of
                    Just (a, b) ->
                        Just (Movement ag (read turnText) a b)
                    Nothing ->
                        Nothing
        else Nothing

parseMove :: String -> Maybe (City, City)
parseMove str =
    case dropUntil "move(" str of
        Nothing ->
            Nothing
        Just afterMove ->
            let inside = takeWhile (/= ')') afterMove
            in case splitOnComma inside of
                Just (a, b) -> Just (a, b)
                Nothing -> Nothing

dropUntil :: String -> String -> Maybe String
dropUntil pattern str
    | startsWith pattern str = Just (drop (length pattern) str)
    | otherwise =
        case str of
            [] -> Nothing
            (_ : rest) -> dropUntil pattern rest

splitOnComma :: String -> Maybe (String, String)
splitOnComma str =
    case break (== ',') str of
        (a, ',' : b) -> Just (a, b)
        _            -> Nothing

parseTheftEvent :: String -> Maybe Theft
parseTheftEvent str =
    case dropUntil "roubo(" str of
        Nothing ->
            Nothing
        Just afterRoubo ->
            let inside = takeWhile (/= ')') afterRoubo
            in case splitTopLevelFields inside of
                item : city : _ -> Just (Theft city item)
                _              -> Nothing

splitTopLevelFields :: String -> [String]
splitTopLevelFields "" = []
splitTopLevelFields s =
    let (field, rest) = break (== ',') s
    in case rest of
        []       -> [field]
        ',' : xs -> field : splitTopLevelFields xs
        _        -> [field]

renderDot :: GameGraph -> String
renderDot (GameGraph moves thefts) =
    let orderedMoves = reverse moves
        marks = allMarks orderedMoves thefts
    in
    unlines (
        [ "digraph JogoDetetiveLadrao {"
        , "  node [shape=circle];"
        , ""
        , "  // Pontos especiais"
        ]
        ++ map (renderMarkedNode marks) (markedCities marks)
        ++
        [ ""
        , "  // Caminho do ladrao"
        ]
        ++ map renderMovement (filterByAgent Ladrao orderedMoves)
        ++
        [ ""
        , "  // Caminho do detetive"
        ]
        ++ map renderMovement (filterByAgent Detetive orderedMoves)
        ++
        [ "}" ]
    )

allMarks :: [Movement] -> [Theft] -> [NodeMark]
allMarks moves thefts =
    theftMarks thefts ++
    agentMarks Ladrao "ladrao" moves ++
    agentMarks Detetive "detetive" moves

theftMarks :: [Theft] -> [NodeMark]
theftMarks [] = []
theftMarks (Theft cidade item : rest) =
    NodeMark cidade ("Roubo: " ++ item) : theftMarks rest

agentMarks :: Agent -> String -> [Movement] -> [NodeMark]
agentMarks ag name moves =
    case agentPositions ag moves of
        Nothing ->
            []
        Just (inicio, fim) ->
            [ NodeMark inicio ("Inicio " ++ name)
            , NodeMark fim ("Fim " ++ name)
            ]

agentPositions :: Agent -> [Movement] -> Maybe (City, City)
agentPositions ag moves =
    case filterByAgent ag moves of
        [] ->
            Nothing
        agentMoves ->
            Just (firstOrigin agentMoves, lastDestination agentMoves)

firstOrigin :: [Movement] -> City
firstOrigin [] = ""
firstOrigin (Movement _ _ origem _ : _) = origem

lastDestination :: [Movement] -> City
lastDestination [] = ""
lastDestination [Movement _ _ _ destino] = destino
lastDestination (_ : rest) = lastDestination rest

markedCities :: [NodeMark] -> [City]
markedCities [] = []
markedCities (NodeMark cidade _ : rest) =
    addCity cidade (markedCities rest)

addCity :: City -> [City] -> [City]
addCity cidade [] = [cidade]
addCity cidade (x : xs)
    | cidade == x = x : xs
    | otherwise = x : addCity cidade xs

renderMarkedNode :: [NodeMark] -> City -> String
renderMarkedNode marks cidade =
    "  " ++ cidade ++
    " [shape=" ++ nodeShape cidade marks ++
    ", style=filled, fillcolor=\"" ++ nodeFillColor cidade marks ++
    "\", label=\"" ++ cidade ++ "\\n" ++ joinLines (labelsForCity cidade marks) ++ "\"];"

nodeShape :: City -> [NodeMark] -> String
nodeShape cidade marks
    | hasTheftMark cidade marks = "doublecircle"
    | otherwise = "circle"

nodeFillColor :: City -> [NodeMark] -> String
nodeFillColor cidade marks
    | hasTheftMark cidade marks = "gold"
    | hasStartMark cidade marks && hasEndMark cidade marks = "lightcyan"
    | hasStartMark cidade marks = "palegreen"
    | hasEndMark cidade marks = "lightgray"
    | otherwise = "white"

labelsForCity :: City -> [NodeMark] -> [String]
labelsForCity cidade [] = []
labelsForCity cidade (NodeMark c label : rest)
    | cidade == c = label : labelsForCity cidade rest
    | otherwise = labelsForCity cidade rest

hasTheftMark :: City -> [NodeMark] -> Bool
hasTheftMark cidade [] = False
hasTheftMark cidade (NodeMark c label : rest)
    | cidade == c && startsWith "Roubo:" label = True
    | otherwise = hasTheftMark cidade rest

hasStartMark :: City -> [NodeMark] -> Bool
hasStartMark cidade [] = False
hasStartMark cidade (NodeMark c label : rest)
    | cidade == c && startsWith "Inicio" label = True
    | otherwise = hasStartMark cidade rest

hasEndMark :: City -> [NodeMark] -> Bool
hasEndMark cidade [] = False
hasEndMark cidade (NodeMark c label : rest)
    | cidade == c && startsWith "Fim" label = True
    | otherwise = hasEndMark cidade rest

joinLines :: [String] -> String
joinLines [] = ""
joinLines [x] = x
joinLines (x : xs) = x ++ "\\n" ++ joinLines xs

renderMovement :: Movement -> String
renderMovement (Movement ag t origem destino) =
    "  " ++ origem ++ " -> " ++ destino ++
    " [color=\"" ++ colorOf ag ++
    "\", label=\"T" ++ show t ++ "\"];"

colorOf :: Agent -> String
colorOf Ladrao = "red"
colorOf Detetive = "blue"

filterByAgent :: Agent -> [Movement] -> [Movement]
filterByAgent ag [] = []
filterByAgent ag (m : ms)
    | sameAgent ag m = m : filterByAgent ag ms
    | otherwise = filterByAgent ag ms

sameAgent :: Agent -> Movement -> Bool
sameAgent ag (Movement ag2 _ _ _) =
    ag == ag2

main :: IO ()
main = do
    args <- getArgs
    case args of
        [inputPath, outputPath] -> do
            content <- readFile inputPath
            let graph = parseLog content
            writeFile outputPath (renderDot graph)

        _ -> do
            putStrLn "Uso: runhaskell Map.hs entrada.log saida.dot"
            putStrLn "Depois: dot saida.dot -Tjpeg -o saida.jpeg"
