scorer = require './scorer'
filter = require './filter'
matcher = require './matcher'

PathSeparator = require('path').sep

module.exports =
  filter: (candidates, query, options) ->
    if query
      queryHasSlashes = query.indexOf(PathSeparator) isnt -1
    filter(candidates, query, queryHasSlashes, options)

  score: (string, query) ->
    return 0 unless string
    return 0 unless query

    queryHasSlashes = query.indexOf(PathSeparator) isnt -1
    score = scorer.score(string, query)
    score = scorer.basenameScore(string, query, score) unless queryHasSlashes
    score

  match: (string, query) ->
    return [] unless string
    return [] unless query
    return [0...string.length] if string is query

    queryHasSlashes = query.indexOf(PathSeparator) isnt -1
    matches = matcher.match(string, query)
    unless queryHasSlashes
      baseMatches = matcher.basenameMatch(string, query)
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
