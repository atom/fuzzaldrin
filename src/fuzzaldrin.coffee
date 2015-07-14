scorer = require './scorer'
filter = require './filter'
matcher = require './matcher'

PathSeparator = require('path').sep

module.exports =
  filter: (candidates, query, options) ->
    filter(candidates, query, options)

  score: (string, query, {allowErrors}={}) ->
    return 0 unless string
    return 0 unless query
    return 0 unless allowErrors or scorer.isMatch(string,query)

    #get "file.ext" from "folder/file.ext"
    pos = query.indexOf(PathSeparator)
    baseQuery = if pos > -1 then query.substring(pos) else query

    score = scorer.score(string, query)
    score = scorer.basenameScore(string, baseQuery, score)

    score

  match: (string, query, {allowErrors}={}) ->
    return [] unless string
    return [] unless query
    return [0...string.length] if string is query
    return [] unless allowErrors or scorer.isMatch(string,query)

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


