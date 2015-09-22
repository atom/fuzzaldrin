# A match list is an array of indexes to characters that match.
# This file should closely follow `scorer` except that it returns an array
# of indexes instead of a score.

PathSeparator = require('path').sep
scorer = require './scorer'


exports.basenameMatch = (subject, query) ->

  # Skip trailing slashes
  end = subject.length - 1
  end-- while subject[end] is PathSeparator

  # Get position of basePath of subject.
  basePos = subject.lastIndexOf(PathSeparator, end)

  #If no PathSeparator, no base path exist.
  return [] if (basePos == -1)

  # Get the number of folder in query
  depth = scorer.countDir(query, query.length)

  # Get that many folder from subject
  while(depth-- > 0)
    basePos = subject.lastIndexOf(PathSeparator, basePos - 1)
    return [] if (basePos == -1) #consumed whole subject ?

  # Get basePath match
  exports.match(subject[basePos + 1 ... end + 1], query, basePos + 1)


#
# Combine two matches result and remove duplicate
# (Assume sequences are sorted, matches are sorted by construction.)
#

exports.mergeMatches = (a, b) ->

  out = []
  m = a.length
  n = b.length

  return a.slice() if n == 0
  return b.slice() if m == 0

  i = -1
  j = 0
  bj = b[0]

  while ++i < m
    ai = a[i]

    while bj <= ai and ++j < n
      if bj < ai
        out.push bj
      bj = b[j]

    out.push ai

  while j < n
    out.push b[j++]

  return out

#----------------------------------------------------------------------

#
# Align sequence (used for fuzzaldrin.match)
# Return position of subject characters that match query.
#
# Follow closely scorer.doScore.
# Except at each step we record what triggered the best score.
# Then we trace back to output matched characters.
#
# Differences are:
# - we record values of gap
# - we break consecutive sequence if we do not take the match.
# - no hit miss limit
# - we record the best result in the trace matrix and we finish by a traceback.


exports.match = (subject, query, offset = 0) ->

  m = subject.length
  n = query.length

  subject_lw = subject.toLowerCase()
  query_lw = query.toLowerCase()

  #this is like the consecutive bonus, but for camelCase / snake_case initials
  acro_score = scorer.scoreAcronyms(subject, subject_lw, query, query_lw).score

  #Init
  score_row = new Array(n)
  csc_row = new Array(n)

  vmax = 0
  imax = -1
  jmax = -1

  # Directions constants
  STOP = 0
  UP = 1
  LEFT = 2
  DIAGONAL = 3

  #Traceback matrix
  trace = new Array(m * n)
  pos = -1

  #Fill with 0
  j = -1
  while ++j < n
    score_row[j] = 0
    csc_row[j] = 0

  i = -1 #0..m-1
  while ++i < m #foreach char si of subject

    score = 0
    score_up = 0
    csc_diag = 0
    si_lw = subject_lw[i]

    j = -1 #0..n-1
    while ++j < n #foreach char qj of query

      #reset score
      csc_score = 0
      align = 0
      score_diag = score_up

      #Compute a tentative match
      if ( query_lw[j] == si_lw )

        start = scorer.isWordStart(i, subject, subject_lw)

        # Forward search for a sequence of consecutive char
        csc_score = if csc_diag > 0  then csc_diag else scorer.scoreConsecutives(subject, subject_lw, query, query_lw, i, j, start)

        # Determine bonus for matching A[i] with B[j]
        align = score_diag + scorer.scoreCharacter(i, j, start, acro_score, csc_score)

      #Prepare next sequence & match score.
      score_up = score_row[j] # Current score_up is next run score diag
      csc_diag = csc_row[j]

      #In case of equality, moving UP get us closer to the start of the string.
      if(score > score_up )
        move = LEFT
      else
        score = score_up
        move = UP

      # In case of equality take the gap
      if(align > score)
        score = align
        move = DIAGONAL
      else
        csc_score = 0 #If we do not use this character reset consecutive sequence.


      score_row[j] = score
      csc_row[j] = csc_score
      trace[++pos] = if(score > 0) then move else STOP

      if score > vmax
        vmax = score
        imax = i
        jmax = j


  # -------------------
  # Go back in the trace matrix from imax, jmax
  # and collect diagonals

  i = imax
  j = jmax
  pos = i * n + j
  backtrack = true
  matches = []

  while backtrack and i >= 0 and j >= 0
    switch trace[pos]
      when UP
        i--
        pos -= n
      when LEFT
        j--
        pos--
      when DIAGONAL
        matches.push(i + offset)
        j--
        i--
        pos -= n + 1
      else
        backtrack = false

  matches.reverse()
  return matches

