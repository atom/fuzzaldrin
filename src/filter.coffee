scorer = require './scorer'

pluckCandidates = (a) -> a.candidate

sortCandidates = (a, b) -> b.score - a.score

Array::toDict = (key) ->
  @reduce ((dict, obj) -> dict[ obj[key] ] = obj if obj[key]?; return dict), {}

module.exports = (candidates, query, queryHasSlashes, {key, keys, maxResults}={}) ->
  if query
    scoredCandidates = []

    if keys
      for candidate, c in candidates
        for key in keys
          score = scorer.score(candidate[key], query, queryHasSlashes)
          unless queryHasSlashes
            score = scorer.basenameScore(candidate[key], query, score)

          if score > 0
            if scoredCandidates[c]
              scoredCandidates[c].score += score
            else
              scoredCandidates.push({candidate, score})
    else
      for candidate in candidates
        string = if key? then candidate[key] else candidate
        continue unless string
        score = scorer.score(string, query, queryHasSlashes)
        unless queryHasSlashes
          score = scorer.basenameScore(string, query, score)
        scoredCandidates.push({candidate, score}) if score > 0

    # Sort scores in descending order
    scoredCandidates.sort(sortCandidates)

    candidates = scoredCandidates.map(pluckCandidates)

  candidates = candidates[0...maxResults] if maxResults?
  candidates
