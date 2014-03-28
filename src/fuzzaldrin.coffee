scorer = require './stringscore'
filter = require './filter'

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
