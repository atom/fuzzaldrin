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
    return [''] unless string
    return [string] unless query
    return ['', string] if string is query

    queryHasSlashes = query.indexOf('/') isnt -1
    query = query.replace(SpaceRegex, '')
    matches = matcher.match(string, query)
    matches

