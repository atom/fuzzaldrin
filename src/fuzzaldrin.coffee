stringScore = require '../vendor/stringscore'

module.exports =
  filter: require './filter'

  score: (string, abbreviation, fuzziness) ->
    return 0 unless abbreviation
    stringScore(string, abbreviation, fuzziness)
