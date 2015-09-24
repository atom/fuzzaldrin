scorer = require './scorer'
legacy_scorer = require './legacy'
filter = require './filter'
matcher = require './matcher'

PathSeparator = require('path').sep

module.exports =

  filter: (candidates, query, options) ->
    return [] unless query?.length and candidates?.length
    filter(candidates, query, options)

  prepQuery: (query) ->
    scorer.prepQuery(query)

#
# While the API is backward compatible,
# the following pattern is recommended for speed.
#
# query = ...
# prepared = fuzzaldrin.prepQuery(query)
# for candidate in candidates
#    score = fuzzaldrin.score(candidate, query, prepared)
#

  score: (string, query, prepQuery, {allowErrors, legacy}={}) ->
    return 0 unless string?.length and query?.length
    prepQuery ?= scorer.prepQuery(query)

    if not legacy
      score = scorer.score(string, query, prepQuery, !!allowErrors)
    else
      queryHasSlashes = prepQuery.depth > 0
      coreQuery = prepQuery.core
      score = legacy_scorer.score(string, coreQuery, queryHasSlashes)
      unless queryHasSlashes
        score = legacy_scorer.basenameScore(string, coreQuery, score)

    score

  match: (string, query, prepQuery, {allowErrors}={}) ->
    return [] unless string
    return [] unless query
    return [0...string.length] if string is query
    prepQuery ?= scorer.prepQuery(query)

    return [] unless allowErrors or scorer.isMatch(string, prepQuery.core_lw, prepQuery.core_up)
    string_lw = string.toLowerCase()
    query_lw = prepQuery.query_lw

    # Full path results
    matches = matcher.match(string, string_lw, prepQuery)

    #if there is no matches on the full path, there should not be any on the base path either.
    return matches if matches.length == 0

    # Is there a base path ?
    if(string.indexOf(PathSeparator) > -1)

      # Base path results
      baseMatches = matcher.basenameMatch(string, string_lw, prepQuery)

      # Combine the results, removing duplicate indexes
      matches = matcher.mergeMatches(matches, baseMatches)

    matches


