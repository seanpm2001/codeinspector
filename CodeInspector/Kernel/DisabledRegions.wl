BeginPackage["CodeInspector`DisabledRegions`"]

DisabledRegions

Begin["`Private`"]

Needs["CodeParser`"]


(*

Please use this syntax:

(* CodeInspect::Push *)
(* CodeInspect::Disable::DuplicateClauses::If *)

If[a, b, b]

(* CodeInspect::Pop *)


*)


codeInspectBeginPat =
  LeafNode[Token`Comment, "(* CodeInspect::Push *)", _] |
  CellNode[Cell, {
      GroupNode[Comment, {
        LeafNode[Token`Boxes`OpenParenStar, "(*", _],
        LeafNode[String, " ", _],
        BoxNode[RowBox, {{
            LeafNode[String, "CodeInspect", _],
            LeafNode[String, "::", _],
            LeafNode[String, "Push", _]
          }}, _],
        LeafNode[String, " ", _], LeafNode[Token`Boxes`StarCloseParen, "*)", _]
      }, _]
    }, _]

codeInspectEndPat =
  LeafNode[Token`Comment, "(* CodeInspect::Pop *)", _] |
  CellNode[Cell, {
      GroupNode[Comment, {
          LeafNode[Token`Boxes`OpenParenStar, "(*", _],
          LeafNode[String, " ", _],
          BoxNode[RowBox, {{
              LeafNode[String, "CodeInspect", _],
              LeafNode[String, "::", _],
              LeafNode[String, "Pop" (* | "End" *), _]
            }}, _],
          LeafNode[String, " ", _], LeafNode[Token`Boxes`StarCloseParen, "*)", _]
        }, _]
    }, _]

codeInspectDisablePat =
  LeafNode[
    Token`Comment,
    str_String /;
      StringMatchQ[str,
        ("(* CodeInspect::Disable::" ~~ LetterCharacter... ~~ " *)") |
        ("(* CodeInspect::Disable::" ~~ LetterCharacter... ~~ "::" ~~ LetterCharacter... ~~ " *)")
      ],
    _
  ] |
  CellNode[Cell, {
      GroupNode[Comment, {
        LeafNode[Token`Boxes`OpenParenStar, "(*", _],
        LeafNode[String, " ", _],
        BoxNode[RowBox, {{
          LeafNode[String, "CodeInspect", _],
          LeafNode[String, "::", _],
          LeafNode[String, "Disable", _],
          LeafNode[String, "::", _],
          LeafNode[String, _, _]}}, _],
          LeafNode[String, " ", _],
          LeafNode[Token`Boxes`StarCloseParen, "*)", _]}, _]
    }, _] |
  CellNode[Cell, {
      GroupNode[Comment, {
        LeafNode[Token`Boxes`OpenParenStar, "(*", _],
        LeafNode[String, " ", _],
        BoxNode[RowBox, {{
          LeafNode[String, "CodeInspect", _],
          LeafNode[String, "::", _],
          LeafNode[String, "Disable", _],
          LeafNode[String, "::", _],
          LeafNode[String, _, _],
          LeafNode[String, "::", _],
          LeafNode[String, _, _]}}, _],
        LeafNode[String, " ", _],
        LeafNode[Token`Boxes`StarCloseParen, "*)", _]}, _]
    }, _]



DisabledRegions[cstIn_] :=
Catch[
Module[{cst, codeInspectBeginPatNodePoss, disabledRegions, siblingsPos, siblings, endFound, candidate, endPos, disableds},

  cst = cstIn;

  codeInspectBeginPatNodePoss = Position[cst, codeInspectBeginPat];

  If[$Debug,
    Print["codeInspectBeginPatNodePoss: ", codeInspectBeginPatNodePoss]
  ];

  disabledRegions = {};
  Do[
    siblingsPos = Most[beginPos];
    siblings = Extract[cst, {siblingsPos}][[1]];
    endFound = False;
    disableds = {};
    Do[
      candidate = siblings[[pos]];
      Switch[candidate,
        codeInspectEndPat,
          endPos = Most[beginPos] ~Join~ {pos};
          endFound = True;
          Break[]
        ,
        codeInspectDisablePat,
          disableds = disableds ~Join~ disabledsFromCandidate[candidate]
      ]
      ,
      {pos, Last[beginPos]+1, Length[siblings]}
    ];
    If[endFound,
      AppendTo[disabledRegions, {rangeStart[Extract[cst, beginPos][[3, Key[Source]]]], rangeEnd[Extract[cst, endPos][[3, Key[Source]]]], disableds}]
      ,
      Message[DisabledRegions::missingpop, cst[[3]]];
      Throw[{}]
    ]
    ,
    {beginPos, codeInspectBeginPatNodePoss}
  ];

  disabledRegions
]]


disabledsFromCandidate[LeafNode[Token`Comment, str_, _]] :=
  StringCases[str, {
      "(* CodeInspect::Disable::" ~~ d:LetterCharacter... ~~ " *)" :> {d},
      "(* CodeInspect::Disable::" ~~ d:LetterCharacter... ~~ "::" ~~ a:LetterCharacter... ~~ " *)" :> {d, a}
  }]

disabledsFromCandidate[
  CellNode[Cell, {
      GroupNode[Comment, {
        LeafNode[Token`Boxes`OpenParenStar, "(*", _],
        LeafNode[String, " ", _],
        BoxNode[RowBox, {{
          LeafNode[String, "CodeInspect", _],
          LeafNode[String, "::", _],
          LeafNode[String, "Disable", _],
          LeafNode[String, "::", _],
          LeafNode[String, d_, _]}}, _],
          LeafNode[String, " ", _],
          LeafNode[Token`Boxes`StarCloseParen, "*)", _]
      }
      ,
      _]
    }, _]
  ] := {d}

disabledsFromCandidate[
  CellNode[Cell, {
      GroupNode[Comment, {
          LeafNode[Token`Boxes`OpenParenStar, "(*", _],
          LeafNode[String, " ", _],
          BoxNode[RowBox, {{
            LeafNode[String, "CodeInspect", _],
            LeafNode[String, "::", _],
            LeafNode[String, "Disable", _],
            LeafNode[String, "::", _],
            LeafNode[String, d_, _],
            LeafNode[String, "::", _],
            LeafNode[String, a_, _]}}, _],
          LeafNode[String, " ", _],
          LeafNode[Token`Boxes`StarCloseParen, "*)", _]
        }
        ,
        _]
    }, _]
  ] := {d, a}



(*
For LineColumn convention, return the start or end span
*)
rangeStart[{s:{_Integer, _Integer}, {_Integer, _Integer}}] :=
  s

rangeEnd[{{_Integer, _Integer}, e:{_Integer, _Integer}}] :=
  e


(*
For SourceCharacterIndex convention, return the start or end span
*)
rangeStart[{s:_Integer, _Integer}] :=
  s

rangeEnd[{_Integer, e:_Integer}] :=
  e


(*
For other conventions, just return the src

We do not know what to do
*)
rangeStart[src_] :=
  src

rangeEnd[src_] :=
  src


End[]

EndPackage[]
