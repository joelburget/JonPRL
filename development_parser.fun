functor DevelopmentParser
  (structure Syntax : PARSE_ABT
   structure Development : DEVELOPMENT
     where type label = string
     where type term = Syntax.t
   structure Context : CONTEXT
   structure Sequent : SEQUENT
     where type term = Syntax.t
     where type context = Syntax.t Context.context
   structure TacticScript : TACTIC_SCRIPT
   sharing TacticScript.Lcf = Development.Lcf
   sharing type TacticScript.state = Development.t
   sharing type TacticScript.Lcf.goal = Sequent.sequent
  ) : DEVELOPMENT_PARSER =
struct
  structure Development = Development

  exception Hole

  open ParserCombinators CharParser
  infix 2 return wth suchthat return guard when
  infixr 1 || <|>
  infixr 3 &&
  infixr 4 << >>

  structure LangDef :> LANGUAGE_DEF =
  struct
    type scanner = char CharParser.charParser
    val commentStart = SOME "(*"
    val commentEnd = SOME "*)"
    val commentLine = SOME "|||"
    val nestedComments = false

    val identLetter = CharParser.letter || CharParser.oneOf (String.explode "-'_ΑαΒβΓγΔδΕεΖζΗηΘθΙιΚκΛλΜμΝνΞξΟοΠπΡρΣσΤτΥυΦφΧχΨψΩω") || CharParser.digit
    val identStart = identLetter
    val opStart = fail "Operators not supported" : scanner
    val opLetter = opStart
    val reservedNames = ["Theorem"]
    val reservedOpNames = []
    val caseSensitive = true
  end

  structure TP = TokenParser (LangDef)
  open TP

  val parse_tm =
    middle (symbol "[") Syntax.parse_abt (symbol "]")
      || middle (symbol "⌊") Syntax.parse_abt (symbol "⌋")

  val parse_definition =
    identifier << symbol "=def="
      && parse_tm
      wth (fn (definiendum, definiens) => fn D =>
             Development.define D (definiendum, definiens))

  val parse_theorem =
    reserved "Theorem" >> identifier << symbol ":"
      && parse_tm
      && braces TacticScript.parse
      wth (fn (thm, (M, tac)) => fn D =>
             Development.prove D (thm, Sequent.>> (Context.empty, M), tac D))

  val parse =
    sepEnd (parse_definition || parse_theorem) dot << not any
      wth (foldl (fn (K, D) => K D) Development.empty)

end

structure CttDevelopmentParser = DevelopmentParser
  (structure Syntax = Syntax
   structure Development = Development
   structure Context = Context
   structure Sequent = Sequent
   structure TacticScript = CttScript)
