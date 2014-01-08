stringScore = require '../vendor/stringscore'
path = require 'path'

module.exports = (candidates, query, options={}) ->
  if query
    scoredCandidates = []
    for candidate in candidates
      string = if options.key? then candidate[options.key] else candidate
      score = stringScore(string, query)

      if query.indexOf('/') is -1
        # Basename matches count for more.
        score += stringScore(path.basename(string), query)

        # Shallow files are scored higher
        depth = Math.max(1, 10 - string.split('/').length - 1)
        score *= depth * 0.01

      scoredCandidates.push({candidate, score}) if score > 0

    scoredCandidates.sort (a, b) ->
      if a.score > b.score then -1
      else if a.score < b.score then 1
      else 0
    candidates = (scoredCandidate.candidate for scoredCandidate in scoredCandidates)

  candidates = candidates[0...options.maxResults] if options.maxResults?
  candidates
