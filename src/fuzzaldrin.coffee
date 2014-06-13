scorer = require './scorer'
filter = require './filter'
matcher = require './matcher'

SpaceRegex = /\ /g

module.exports =
  filter: (candidates, query, options) ->
    if query
      queryHasSlashes = query.indexOf('/') isnt -1
      query = query.replace(SpaceRegex, '')
    filter(candidates, query, queryHasSlashes, options)

  score: (string, query) ->
    return 0 unless string
    return 0 unless query
    return 2 if string is query

    queryHasSlashes = query.indexOf('/') isnt -1
    query = query.replace(SpaceRegex, '')
    score = scorer.score(string, query)
    score = scorer.basenameScore(string, query, score) unless queryHasSlashes
    score

  match: (string, query) ->
    return [] unless string
    return [] unless query
    return [0..string.length - 1] if string is query

    queryHasSlashes = query.indexOf('/') isnt -1
    query = query.replace(SpaceRegex, '')
    matches = matcher.match(string, query)
    unless queryHasSlashes
      baseMatches = matcher.basenameMatch(string, query)
      # Combine the results, removing dupicate indexes
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
