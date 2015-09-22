scorer = require './scorer'
legacy_scorer = require './legacy'
filter = require './filter'
matcher = require './matcher'

PathSeparator = require('path').sep

module.exports =

  filter: (candidates, query, options) ->
    return [] unless query?.length and candidates?.length
    filter(candidates, query, options)

  #
  # While the API is backward compatible,
  # the following pattern is recommended for speed.
  #
  # query = ...
  # prepared = fuzzaldrin.prepQuery(query)
  # for candidate in candidates
  #    score = fuzzaldrin.score(candidate, query, prepared)
  #

  score: (string, query, prepQuery = scorer.prepQuery(query), {allowErrors, legacy}={}) ->
    return 0 unless string?.length and query?.length

    if not legacy
      score = scorer.score(string, query, prepQuery, !!allowErrors)
    else
      queryHasSlashes = prepQuery.depth > 0
      coreQuery = prepQuery.core
      score = legacy_scorer.score(string, coreQuery, queryHasSlashes)
      unless queryHasSlashes
        score = legacy_scorer.basenameScore(string, coreQuery, score)

    score

  prepQuery: (query) ->
    scorer.prepQuery(query)

  match: (string, query, {allowErrors}={}) ->

    return [] unless string
    return [] unless query
    return [0...string.length] if string is query

    string_lw = string.toLowerCase()
    coreQuery_lw = scorer.coreChars(query).toLowerCase()
    return [] unless allowErrors or scorer.isMatch(string_lw, coreQuery_lw)

    #get base path ("file.ext" from "folder/file.ext) "
    pos = query.indexOf(PathSeparator)
    baseQuery = if pos > -1 then query.substring(pos) else query

    # Full path results
    matches = matcher.match(string, query)

    #if no matches on the long path. there will not be any on the base path either.
    return matches if matches.length == 0

    # Is there a base path ?
    if(string.indexOf(PathSeparator) > -1)

      # Base path results
      baseMatches = matcher.basenameMatch(string, baseQuery)

      # Combine the results, removing duplicate indexes
      matches = matcher.mergeMatches(matches, baseMatches)

    matches


