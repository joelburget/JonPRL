structure TacticEval :
        sig
            val eval : Tactic.t -> Ctt.tactic
        end =
struct
  open Tactic
  open Ctt.Rules
  structure T = ProgressTacticals(Lcf)

  fun an a t = AnnotatedLcf.annotate (a, t)

  fun eval t =
    case t of
        LEMMA (wld, lbl, a) => an a (Lemma (wld, lbl))
      | UNFOLD (wld, lbls, a) => an a (Unfolds (wld, lbls))
      | CUSTOM_TACTIC (wld, lbl, a) =>
        an a (Development.lookupTactic wld lbl)
      | WITNESS (t, a) => an a (Witness t)
      | HYPOTHESIS (i, a) => an a (Hypothesis i)
      | EQ_SUBST ({left, right, level}, a) =>
        an a (EqSubst (left, right, level))
      | HYP_SUBST ({dir, index, domain, level}, a) =>
        an a (HypEqSubst (dir, index, domain, level))
      | INTRO ({term, freshVariable, level}, a) =>
        an a (CttUtil.Intro {term = term,
                             freshVariable = freshVariable,
                             level = level})
      | ELIM ({target, term, names}, a) =>
        an a (CttUtil.Elim {target = target, term = term, names = names})
      | EQ_CD ({names, terms, level}, a) =>
        an a (CttUtil.EqCD {names = names, terms = terms, level = level})
      | EXT ({freshVariable, level}, a) =>
        an a (CttUtil.Ext {freshVariable = freshVariable, level = level})
      | CUM (l, a) => an a (Cum l)
      | AUTO a => an a CttUtil.Auto
      | MEM_CD a => an a MemCD
      | ASSUMPTION a => an a Assumption
      | SYMMETRY a => an a EqSym
      | TRY tac => T.TRY (eval tac)
      | REPEAT tac => T.LIMIT (eval tac)
      | ORELSE tacs => List.foldl T.ORELSE T.FAIL (map eval tacs)
      | THEN ts =>
        List.foldl (fn (Sum.INL x, rest) => T.THEN (rest, eval x)
                     | (Sum.INR xs, rest) => T.THENL (rest, map eval xs))
                   T.ID
                   ts
      | ID a => an a T.ID
      | FAIL a => an a T.FAIL
      | TRACE (msg, a) => an a (T.TRACE msg)
end
