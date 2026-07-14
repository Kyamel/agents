module Parser where

import System.Environment (getArgs)
import Data.Char (isDigit, isSpace, isAlphaNum)

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
    = ParsedMove Movement  -- ^ A linha descreve um @move(...)@.
    | ParsedTheft Theft    -- ^ A linha descreve um @Evento roubo(...)@.
    deriving Show

-- | Anotacao a ser pintada num nó do grafo
data NodeMark = NodeMark City String
    deriving Show

-- ============================================================
-- Parser generico
-- ============================================================

-- newtype é como um 'data' restrito a UM construtor com UM unico campo.
-- Em troca dessa restricao, o wrapper e apagado em tempo de execucao:
-- 'Parser' e a funcao que ele envolve tem a mesma representacao em memoria
-- (custo zero), ao contrario de 'data'.
newtype Parser a = Parser (String -> Either String (a, String))

runParser :: Parser a -> String -> Either String (a, String)
runParser (Parser p) input = p input

-- | 'fmap' aplica uma funcao ao valor lido, se a leitura deu certo.
instance Functor Parser where
    fmap f (Parser p) = Parser $ \input ->
        case p input of
            Left err        -> Left err
            Right (a, rest) -> Right (f a, rest)

-- @('<*>')@ encadeia dois parsers, combinando os resultados.
instance Applicative Parser where
    pure x = Parser $ \input -> Right (x, input)
    (Parser pf) <*> (Parser px) = Parser $ \input ->
        case pf input of
            Left err       -> Left err
            Right (f, r1)  ->
                case px r1 of
                    Left err       -> Left err
                    Right (x, r2)  -> Right (f x, r2)

-- | @('>>=')@ liga a saida de um parser na escolha do proximo parser.
instance Monad Parser where
    return = pure
    (Parser p) >>= f = Parser $ \input ->
        case p input of
            Left err        -> Left err
            Right (a, rest) -> runParser (f a) rest

-- ============================================================
-- Combinadores basicos
-- ============================================================

failP :: String -> Parser a
failP msg = Parser $ \_ -> Left msg

-- | tenta o parser da esquerda; se ele falhar, tenta o da direita.
(<|>) :: Parser a -> Parser a -> Parser a
(Parser p1) <|> (Parser p2) = Parser $ \input ->
    case p1 input of
        Left _   -> p2 input
        Right ok -> Right ok

many :: Parser a -> Parser [a]
many p = many1 p <|> pure []

many1 :: Parser a -> Parser [a]
many1 p = do
    x  <- p
    xs <- many p
    return (x : xs)

optional :: Parser a -> Parser ()
optional p = (p >> return ()) <|> return ()

-- ============================================================
-- Parsers de caractere
-- ============================================================

anyChar :: Parser Char
anyChar = Parser $ \input ->
    case input of
        []       -> Left "fim inesperado da entrada"
        (c : cs) -> Right (c, cs)

satisfy :: (Char -> Bool) -> Parser Char
satisfy predicate = Parser $ \input ->
    case input of
        (c : cs) | predicate c -> Right (c, cs)
        (c : _)                -> Left ("caractere inesperado: " ++ [c])
        []                     -> Left "fim inesperado da entrada"

char :: Char -> Parser Char
char x = satisfy (== x)

digit :: Parser Char
digit = satisfy isDigit

space :: Parser Char
space = satisfy isSpace

-- | Lê um caractere valido em nome de cidade / item: Letra, digito ou _.
identChar :: Parser Char
identChar = satisfy (\c -> isAlphaNum c || c == '_')

-- ============================================================
-- Parsers compostos
-- ============================================================

string :: String -> Parser String
string = mapM char

spaces :: Parser String
spaces = many space

number :: Parser Int
number = do
    ds <- many1 digit
    return (read ds)

-- | Lê um identificador: um ou mais 'identChar' (nome de cidade ou item).
identifier :: Parser String
identifier = many1 identChar

-- ============================================================
-- Parsers do dominio
-- ============================================================

agentP :: Parser Agent
agentP =
        (string "ladrao"   >> return Ladrao)
    <|> (string "detetive" >> return Detetive)

-- | Lê uma linha de movimento confirmado, no formato
-- @255 ladrao: move(origem,destino)[OK]@.
moveLine :: Parser ParsedEvent
moveLine = do
    _       <- spaces
    turno   <- number
    _       <- spaces
    agente  <- agentP
    _       <- char ':'
    _       <- spaces
    _       <- string "move"
    _       <- char '('
    origem  <- identifier
    _       <- char ','
    destino <- identifier
    _       <- char ')'
    _       <- string "[OK]"
    return (ParsedMove (Movement agente turno origem destino))

-- | Lê uma linha de roubo, no formato
-- @>>>> Evento roubo(item,cidade,[...])@.
theftLine :: Parser ParsedEvent
theftLine = do
    _     <- spaces
    _     <- string ">>>>"
    _     <- spaces
    _     <- string "Evento"
    _     <- spaces
    _     <- string "roubo"
    _     <- char '('
    item  <- identifier
    _     <- char ','
    city  <- identifier
    return (ParsedTheft (Theft city item))

lineP :: Parser ParsedEvent
lineP = theftLine <|> moveLine

parseLine :: String -> [ParsedEvent]
parseLine raw =
    case runParser lineP raw of
        Right (ev, _) -> [ev]
        Left _        -> []

-- ============================================================
-- Montagem do grafo
-- ============================================================

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

-- ============================================================
-- Renderizacao para .dot
-- ============================================================

startsWith :: String -> String -> Bool
startsWith prefix str =
    take (length prefix) str == prefix

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

-- | Junta as marcacoes de roubo e as posicoes inicial, final de cada agente.
allMarks :: [Movement] -> [Theft] -> [NodeMark]
allMarks moves thefts =
    theftMarks thefts ++
    agentMarks Ladrao "ladrao" moves ++
    agentMarks Detetive "detetive" moves

theftMarks :: [Theft] -> [NodeMark]
theftMarks [] = []
theftMarks (Theft cidade item : rest) =
    NodeMark cidade ("Roubo: " ++ item) : theftMarks rest

-- | Marca as cidades de inicio e fim do trajeto de um agente.
agentMarks :: Agent -> String -> [Movement] -> [NodeMark]
agentMarks ag name moves =
    case agentPositions ag moves of
        Nothing ->
            []
        Just (inicio, fim) ->
            [ NodeMark inicio ("Inicio " ++ name)
            , NodeMark fim ("Fim " ++ name)
            ]

-- | Primeira origem e ultimo destino do agente, ou 'Nothing' se ele nao anda.
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

-- | Junta varios rotulos numa unica string, separados por quebra @\\n@ do dot.
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

-- | Mantem apenas os movimentos do agente dado.
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
            putStrLn "Uso: runhaskell Parser.hs entrada.log saida.dot"
            putStrLn "Depois: dot saida.dot -Tjpeg -o saida.jpeg"
