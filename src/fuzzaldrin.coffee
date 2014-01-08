stringScore = require '../vendor/stringscore'

module.exports =
  filter: require './filter'

  score: (string, abbreviation, fuzziness) ->
    return 0 if abbreviation is ''
    stringScore(string, abbreviation, fuzziness)
