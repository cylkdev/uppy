# This file contains the configuration for Credo and you are probably reading
# this after creating it with `mix credo.gen.config`.
#
# If you find anything wrong or unclear in this file, please report an
# issue on GitHub: https://github.com/rrrene/credo/issues
#

allowed_imports = [
  [:ExUnit, :CaptureLog]
]

%{
  # You can have as many configs as you like in the `configs:` field.
  configs: [
    %{
      #
      # Run any config using `mix credo -C <name>`. If no config name is given
      # "default" is used.
      #
      name: "default",
      files: %{
        #
        # You can give explicit globs or simply directories.
        # In the latter case `**/*.{ex,exs}` will be used.
        #
        included: [
          "lib/",
          "src/",
          "test/"
        ],
        excluded: [
          ~r"/_build/",
          ~r"/deps/",
          ~r"/test/support/"
        ]
      },
      plugins: [],
      requires: [
        "deps/blitz_credo_checks/lib/blitz_credo_checks/"
      ],
      strict: true,
      parse_timeout: 10_000,
      color: true,
      checks: %{
        enabled: [
          #
          ## BlitzCredoChecks
          #
          {BlitzCredoChecks.SetWarningsAsErrorInTest, false},
          {BlitzCredoChecks.DocsBeforeSpecs, []},
          {BlitzCredoChecks.DoctestIndent, []},
          {BlitzCredoChecks.NoAsyncFalse, []},
          {BlitzCredoChecks.NoDSLParentheses, []},
          {BlitzCredoChecks.NoIsBitstring, []},
          {BlitzCredoChecks.StrictComparison, []},
          {BlitzCredoChecks.LowercaseTestNames, []},
          {BlitzCredoChecks.ImproperImport, allowed_modules: allowed_imports},

          #
          ## Consistency Checks
          #
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          #
          ## Design Checks
          #
          {Credo.Check.Design.AliasUsage, false},

          #
          ## No outstanding TODOS
          #
          {Credo.Check.Design.TagTODO, []},
          {Credo.Check.Design.TagFIXME, []},

          #
          ## Readability Checks
          #
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},

          #
          ## Refactoring Opportunities
          #
          {Credo.Check.Refactor.Apply, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.FunctionArity, []},
          {Credo.Check.Refactor.LongQuoteBlocks, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},
          {Credo.Check.Refactor.FilterFilter, []},
          {Credo.Check.Refactor.RejectReject, []},
          {Credo.Check.Refactor.RedundantWithClauseResult, []},

          #
          ## Warnings
          #
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.LazyLogging, false},
          {Credo.Check.Warning.MixEnv, false},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.WrongTestFileExtension, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.UnsafeExec, []},

          # Controversial and experimental checks
          {Credo.Check.Consistency.MultiAliasImportRequireUse, false},
          {Credo.Check.Consistency.UnusedVariableNames, false},
          {Credo.Check.Design.DuplicatedCode, false},
          {Credo.Check.Readability.AliasAs, false},
          {Credo.Check.Readability.BlockPipe, []},
          {Credo.Check.Readability.ImplTrue, false},
          {Credo.Check.Refactor.MapInto, false},
          {Credo.Check.Readability.MultiAlias, false},
          {Credo.Check.Readability.NestedFunctionCalls, []},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          {Credo.Check.Design.SkipTestWithoutComment, []},
          {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.Specs, false},
          {Credo.Check.Readability.StrictModuleLayout, false},
          {Credo.Check.Readability.WithCustomTaggedTuple, []},
          {Credo.Check.Refactor.ABCSize, false},
          {Credo.Check.Refactor.AppendSingleItem, false},
          {Credo.Check.Refactor.DoubleBooleanNegation, false},
          {Credo.Check.Refactor.FilterReject, []},
          {Credo.Check.Refactor.IoPuts, []},
          {Credo.Check.Refactor.MapMap, []},
          {Credo.Check.Refactor.ModuleDependencies, false},
          {Credo.Check.Refactor.NegatedIsNil, false},
          {Credo.Check.Refactor.PipeChainStart, false},
          {Credo.Check.Refactor.RejectFilter, []},
          {Credo.Check.Refactor.VariableRebinding, false},
          {Credo.Check.Warning.LeakyEnvironment, false},
          {Credo.Check.Warning.MapGetUnsafePass, false},
          {Credo.Check.Warning.MixEnv, []},
          {Credo.Check.Warning.UnsafeToAtom, false}
        ]
      }
    }
  ]
}
