stringScore = require '../vendor/stringscore'

module.exports =
  filter: require './filter'

  score: (string, query) ->
    return 0 unless string
    return 0 unless query
    stringScore(string, query)
