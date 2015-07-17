scorer = require './scorer'
legacy_scorer = require './legacy'
filter = require './filter'
matcher = require './matcher'

PathSeparator = require('path').sep

module.exports =
  filter: (candidates, query, options) ->
    filter(candidates, query, options)

  score: (string, query, {allowErrors, legacy}={}) ->
    return 0 unless string
    return 0 unless query

    coreQuery = scorer.coreChars(query)
    return 0 unless allowErrors or scorer.isMatch(string,coreQuery)

    #get "file.ext" from "folder/file.ext"
    pos = query.indexOf(PathSeparator)
    baseQuery = if pos > -1 then query.substring(pos) else query

    if not legacy
      score = scorer.score(string, query)
      score = scorer.basenameScore(string, baseQuery, score)
    else
      queryHasSlashes = pos > -1
      score = legacy_scorer.score(string, coreQuery, queryHasSlashes)
      unless queryHasSlashes
        score = legacy_scorer.basenameScore(string, coreQuery, score)

    score

  match: (string, query, {allowErrors}={}) ->
    return [] unless string
    return [] unless query
    return [0...string.length] if string is query

    coreQuery = scorer.coreChars(query)
    return [] unless allowErrors or scorer.isMatch(string,coreQuery)

    #get "file.ext" from "folder/file.ext"
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
      matches = matcher.mergeMatches(matches,baseMatches)

    matches


