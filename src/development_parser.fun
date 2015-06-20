signature PARSE_CTT =
  PARSE_ABT
    where type Operator.t = string OperatorType.operator
    where type ParseOperator.world = string -> Arity.t

signature PARSE_PATTERN =
  PARSE_ABT
    where type Operator.t = string PatternOperatorType.operator
    where type ParseOperator.world = string -> Arity.t

functor DevelopmentParser
  (structure Syntax : PARSE_CTT
   structure Pattern : PARSE_PATTERN
   sharing type Syntax.Variable.t = Pattern.Variable.t

   structure Sequent : SEQUENT
     where type term = Syntax.t
   structure Development : DEVELOPMENT
     where type Telescope.Label.t = string
     where type judgement = Sequent.sequent
     where type pattern = Pattern.t
     where type term = Syntax.t

   structure TacticScript : TACTIC_SCRIPT
     where type Tacticals.tactic = Development.tactic
     where type Tacticals.goal = Development.judgement
     where type world = Development.world
 ) : DEVELOPMENT_PARSER =
struct
  structure Development = Development

  exception RemainingSubgoals = TacticScript.Tacticals.RemainingSubgoals

  open ParserCombinators CharParser
  infix 2 return wth suchthat return guard when
  infixr 1 || <|>
  infixr 3 &&
  infixr 4 << >> --

  structure TP = TokenParser
    (open JonprlLanguageDef
     val reservedNames = ["Theorem", "Tactic", "Operator"])
  open TP

  val lookupOperator = Development.lookupOperator

  fun parseTm fvs = squares o Syntax.parseAbt fvs o lookupOperator
  val parsePattern = squares o Pattern.parseAbt [] o lookupOperator

  val parseName =
    identifier
      wth Syntax.Variable.named

  fun parseTheorem D =
    reserved "Theorem" >> identifier << colon
      && parseTm [] D
      && braces (TacticScript.parseComplete D)
      wth (fn (thm, (M, tac)) =>
             Development.prove D
              (thm, Sequent.>> (Sequent.Context.empty, M), tac))

  val parseInt =
    repeat1 digit wth valOf o Int.fromString o String.implode

  val parseArity =
    parens (semiSep parseInt)
    wth Vector.fromList

  fun parseTactic D =
    reserved "Tactic" >> identifier
      && braces (TacticScript.parse D)
      wth (fn (lbl, tac) => Development.defineTactic D (lbl, tac))

  fun parseOperatorDecl D =
    (reserved "Operator" >> identifier << colon && parseArity)
    wth Development.declareOperator D

  fun parseOperatorDef D =
    parsePattern D -- (fn (pat : Pattern.t) =>
      succeed pat && (symbol "=def=" >> parseTm (Pattern.freeVariables pat) D)
    ) wth (fn (P : Pattern.t, N : Syntax.t) =>
      Development.defineOperator D
        {definiendum = P,
         definiens = N})

  fun parseDecl D =
      parseTheorem D
      || parseTactic D
      || parseOperatorDecl D
      || parseOperatorDef D

  fun parse' D () =
    whiteSpace >>
    (parseDecl D << dot) -- (fn D' =>
      $ (parse' D') <|>
      (whiteSpace >> not any) return D')

  fun parse D = ($ (parse' D))
end

structure CttDevelopmentParser = DevelopmentParser
  (structure Syntax = Syntax
   structure Pattern = PatternSyntax
   structure Development = Development
   structure Sequent = Sequent
   structure TacticScript = CttScript)
