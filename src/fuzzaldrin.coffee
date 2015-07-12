scorer = require './scorer'
filter = require './filter'
matcher = require './matcher'

PathSeparator = require('path').sep

module.exports =
  filter: (candidates, query, options) ->
    filter(candidates, query, options)

  score: (string, query) ->
    return 0 unless string
    return 0 unless query

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

    return [] unless !!allowErrors or scorer.isMatch(string,query)

    #get "file.ext" from "folder/file.ext"
    pos = query.indexOf(PathSeparator)
    baseQuery = if pos > -1 then query.substring(pos) else query

    matches = matcher.match(string, query)
    if(string.indexOf(PathSeparator) > -1)

      baseMatches = matcher.basenameMatch(string, baseQuery)
      # Combine the results, removing duplicate indexes
      matches = matches.concat(baseMatches).sort (a, b) -> a - b
      seen = null
      index = 0
      while index < matches.length
        if index and seen is matches[index]
          matches.splice(index, 1) # remove duplicate
        else
          seen = matches[index]
          index++

    matches
