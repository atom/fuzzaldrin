#
# Score similarity between two string
#
#  isMatch: Fast detection if all character of needle is in haystack
#  score: Find string similarity using a Smith Waterman algorithm
#         Modified to account for programing scenarios (CamelCase folder/file.ext object.property)
#
# Copyright (C) 2015 Jean Christophe Roy and contributors
# MIT License: http://opensource.org/licenses/MIT


wm = 100 # base score of making a match
wc = 200 # bonus for proper case

wa = 400 # bonus of making an acronym match
ws = 200 # bonus of making a separator match

we = -10 # penalty to skip a letter inside a match (vs free to skip around the match)

wst = 100 # bonus for match near start of string
wex = 1000 # bonus per character of an exact match. If exact coincide with prefix, bonus will be 2*wex, then it'll fade to 1*wex as string happens later.

#Note: extra zeros are there to allow rounding the fading bonus function to an integer value.

#
# Fading function
#
# f(x) = tau / ( tau + x) will be used for bonus that fade with position and to to penalize larger haystack.
# tau is the value of x, for which f(x) = 0.5*f(0) = 0.5

tau = 15

#
# Separators
#

separators = ' .-_/\\'
PathSeparator = require('path').sep

#Save above separator in a dictionary for quick lookup
sep_map = do ->
  map = {}
  map[sep] = sep for sep in separators
  return map


# Optional chars
# Some characters of query char MUST be in subject,
# Others COULD be there or not, better Score if they are, but don't block isMatch.
#
# Interchangeable are,
# - word separator,
# - backward/forward slashes (to support multiple OS and php namespace)
# - colon (to support Rails  namespace)

opt_char_re = /[ _\-:\/\\]/g

exports.coreChars = coreChars = (query) ->
  return query.replace(opt_char_re, '')

#
# Search window
# string_match compute the score using first occurrence of character.
# we'll consider all occurrences, but limit this search of the best occurrence to
# a window at the start of the string. This mostly concern deeply nested path
# and they receive a special treatment for baseName.
#
# Exact match will still continue to search full string.
#

fuzzyMaxlen = 64

#
# isMatch:
# Are all characters of query in subject, in proper order
#

exports.isMatch = isMatch = (subject_lw, query_lw) ->
  m = subject_lw.length
  n = query_lw.length

  if !m or !n or n > m
    return false

  i = -1
  j = -1
  k = m - 1

  #foreach char of query
  while ++j < n

    qj_lw = query_lw[j]

    #continue search in subject from last match
    while ++i < m

      #found match, goto next char of query
      if subject_lw[i] == qj_lw
        break

      #last char of query AND no match
      else if i == k
        return false


  return true

#----------------------------------------------------------------------

#
# Score adjustment for path
#

exports.basenameScore = (subject, query, fullPathScore, subject_lw = subject.toLowerCase(), query_lw = query.toLowerCase()) ->
  return 0 if fullPathScore == 0

  # Skip trailing slashes
  end = subject.length - 1
  end-- while subject[end] is PathSeparator

  # Get position of basePath of subject. If no PathSeparator, no base path exist.
  basePos = subject.lastIndexOf(PathSeparator, end)

  # Get the number of folder in query
  qdepth = countDir(query, query.length)

  # Get that many folder from subject
  while(basePos > -1 && qdepth--)
    basePos = subject.lastIndexOf(PathSeparator, basePos-1)

  #consumed whole subject ?
  return fullPathScore if (basePos == -1)

  #If fuzzyMaxlen apply, clip to the right  to get as mush of the filename as possible
  basePos = Math.max(basePos, end - fuzzyMaxlen)

  # Get basePath score
  basePos++
  end++
  basePathScore = score(subject[basePos...end], query, subject_lw[basePos...end], query_lw)

  # We'll merge some of that base path score with full path score.
  # Mix start favoring base Path then favor full path as directory depth increase
  # Note that base Path test are more nested than original, so we have to compensate one level of nesting.

  alpha = 0.5 * 2 * tau / ( 2 * tau + countDir(subject, end + 1) )
  return  alpha * basePathScore + (1 - alpha) * fullPathScore

#
# Count number of folder in a path.
# (skip consecutive slashes)

exports.countDir = countDir = (path, end) ->
  return 0 if end < 1

  count = 0
  i = -1
  while ++i < end

    p = path[i]
    if (p == PathSeparator)
      ++count
      while ++i < end and path[i] == PathSeparator
        continue

  return count

#----------------------------------------------------------------------

#
# Main scoring algorithm
#

exports.score = score = (subject, query, subject_lw = subject.toLowerCase(), query_lw = query.toLowerCase()) ->
  m = subject.length
  n = query.length

  #haystack size penalty
  sz = 4 * tau / (4 * tau + m)

  #----------------------------
  # Abbreviations sequence

  abbr = abbrPrefix(subject, subject_lw, query, query_lw)
  abbrBonus = abbr.bonus
  exact = 2 * wex * abbrBonus * abbrBonus * (1.0 + tau / (tau + abbr.pos))

  #Whole query is abbreviation ? then => bypass
  if( abbr.count == query.length)
    return 2 * exact * sz

  #----------------------------
  # Exact Match
  # => bypass

  pos = subject_lw.indexOf(query_lw)
  if pos > -1

    #bonus per consecutive char grow with number of consecutive
    #so this need to be squared to stay on top.
    base = wex * n * n

    pos2 = subject.indexOf(query, pos)
    if( pos2 > -1)
      #Substring is ExactCase
      #Search start at pos, because case-sensitive occurrence cannot happens before case-insensitive one.
      exact += 3 * base
      pos = pos2 #When we can, use ExactCase position for position based bonus.

    #base bonus + position decay
    exact += base * (1.0 + tau / (tau + pos))

    #sustring happens right after a separator (prefix)
    exact += 5 * base if (pos == 0 or subject[pos - 1] of sep_map)

    #sustring happens right before a separator (suffix)
    exact += base if (pos == m - n or subject[pos + n] of sep_map)

    # Test for abbreviation.
    #abbr = abbrPrefix(subject, subject_lw, query, query_lw)
    #abbrBonus = abbr.bonus
    #exact += 1.5 * wex * abbrBonus * abbrBonus * (1.0 + tau / (tau + abbr.pos))

    return exact * sz


  #----------------------------
  # Individual chars
  # (Smith Waterman algorithm)

  #max string size for O(m*n) best match search
  m = fuzzyMaxlen if m > fuzzyMaxlen
  n = fuzzyMaxlen if n > fuzzyMaxlen

  #Init
  vRow = new Array(n)
  seqRow = new Array(n)
  vmax = 0

  #Fill with 0
  j = -1
  while ++j < n
    vRow[j] = 0
    seqRow[j] = 0

  i = -1 #1..m-1
  while ++i < m     #foreach char of subject

    v = 0
    v_diag = 0
    seq_diag = 0
    si_lw = subject_lw[i]

    j = -1 #1..n-1
    while ++j < n   #foreach char of query

      #Compute a tentative match
      if ( query_lw[j] == si_lw )

        #forward search for a sequence of consecutive char (will apply some bonus for exact casing or complete match)
        seq = if seq_diag == 0 then scoreMatchingSequence(subject, subject_lw, query, query_lw, i, j) else  seq_diag
        seq_diag = seqRow[j]
        seqRow[j] = seq

        #determine bonus for matching A[i] with B[j]
        align = v_diag + seq * scoreMatchingChar(subject, subject_lw, query, i, j, abbrBonus)

      else
        seq_diag = seqRow[j]
        seqRow[j] = 0
        align = 0

      #Compare the score of making a match, a gap in Query (A), or a gap in Subject (B)
      v_diag = vRow[j]
      gap = we + if(v > v_diag) then v else v_diag
      v = vRow[j] = if(align > gap) then align else gap

      #Record the best score so far
      if v > vmax
        vmax = v


  return (vmax + exact) * sz

#
# Compute the bonuses for two chars that are confirmed to matches in a case-insensitive way
#

scoreMatchingChar = (subject, subject_lw, query, i, j, abbrBonus) ->

  si = subject[i]
  qj = query[j]

  #Proper casing bonus
  bonus = if qj == si then wc else 0

  #start of string bonus
  bonus += Math.floor(wst * tau / (tau + i))

  #match IS a separator
  return ws + bonus if si of sep_map

  acn = wa * (1 + abbrBonus)

  #match is FIRST char ( place a virtual token separator before first char of string)
  return acn + bonus if  i == 0

  #get previous char
  prev_s = subject[i - 1]

  #match FOLLOW a separator
  return acn + bonus if ( prev_s of sep_map)

  #match is Capital in camelCase (preceded by lowercase)
  return acn + bonus if (si != subject_lw[i] and prev_s == subject_lw[i-1])

  #normal Match, add proper case bonus
  return wm + bonus

#
# score the quality of a match Neighbourhood
# mostly using consecutive characters count and proper case.
#
# use the fact query_lw[i] == subject_lw[j]
# has been checked before entering.

scoreMatchingSequence = (subject, subject_lw, query, query_lw, i, j) ->
  m = subject.length
  n = query.length

  mi = m - i
  nj = n - j
  k = if mi < nj then mi else nj

  sameCase = 0
  sz = 0 #sz will be one more than the last qi==sj

  sameCase++ if (query[j] == subject[i])
  while (++sz < k and query_lw[++j] == subject_lw[++i])
    sameCase++ if (query[j] == subject[i])


  # most of the sequences are not exact matches
  if sz < n
    return 3 * sz if sz == sameCase #Give a bonus for no case error.
    return sz + sameCase #general case

  #exact case-sensitive match
  if sameCase == n
    return 8 * n

  #exact case-insensitive match (assert sz == n)
  return 2 * (sz + sameCase )


#
# Count the number of abbreviation prefix
# Normal char use help of a matching context to determine which one should we take.
# That context is basically the length of the consecutive run they are part of.
#
# This mirror the idea of consecutive run length,
# but compute consecutive of the abbreviated match
# ThisIsTest -> tst
#
# This handle "CamelCase" , "Title Case" "snake_case"
#

class AbbrInfo
  constructor: (@bonus, @pos, @count) ->

abbrInfo0 = new AbbrInfo(0, 0.1, 0)

abbrPrefix = (subject, subject_lw, query, query_lw) ->

  m = subject.length
  n = query.length
  return abbrInfo0 unless m and n

  #Abbreviation is a fuzzy match
  m = fuzzyMaxlen if m > fuzzyMaxlen

  count = 0
  pos = 0
  sameCase = 0

  i = -1
  j = -1
  k = m - 1

  #foreach char of query
  while ++j < n

    qj_lw = query_lw[j]

    while ++i < m

      si_lw = subject_lw[i]

      #test if subject match
      if(qj_lw == si_lw)

        # Is it CamelCase ?
        # 1) si is Uppercase ( different from si.toLowerCase() ) AND
        # 2) j is first char or lowercase
        #
        # Is it snake_case ?
        # 1) j is first char or subject[j-1] is separator

        si = subject[i]
        prev_s = if i == 0 then si else subject[i - 1]

        if  i == 0 or ( prev_s of sep_map ) or (si != si_lw and prev_s == subject_lw[i - 1] )

          #record position and increase count
          pos += i
          count++

          #Is it sameCase ?
          sameCase++ if ( query[j] == si )

          break

    #all of subject is consumed.
    if i == k then break

  #all of query is consumed.
  #a single char is not an acronym (also prevent division by 0)
  if(count < 2)
    return abbrInfo0

  return new AbbrInfo(count + sameCase, pos / count, count)


#----------------------------------------------------------------------

#
# Align sequence (used for match)
# Return position of subject that match query.
#

exports.align = (subject, query, offset = 0) ->
  m = subject.length
  n = query.length

  #max string size for O(m*n) best match search
  m = fuzzyMaxlen if m > fuzzyMaxlen
  n = fuzzyMaxlen if n > fuzzyMaxlen

  subject_lw = subject.toLowerCase()
  query_lw = query.toLowerCase()

  #this is like the consecutive bonus, but for scattered camelCase initials
  abbrBonus = abbrPrefix(subject, subject_lw, query, query_lw).bonus

  #Init
  vRow = new Array(n)
  seqRow = new Array(n)
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
    vRow[j] = 0
    seqRow[j] = 0

  i = -1 #1..m-1
  while ++i < m #foreach char of subject

    v = 0
    v_diag = 0
    seq_diag = 0
    si_lw = subject_lw[i]

    j = -1 #1..n-1
    while ++j < n #foreach char of query

      #Compute a tentative match
      if ( query_lw[j] == si_lw )

        if seq_diag == 0
          # forward search for a sequence of consecutive char
          # (will apply some bonus for exact casing or matching the whole query)
          seq = scoreMatchingSequence(subject, subject_lw, query, query_lw, i, j)

        else
          # Verify that previous char is a Match before applying sequence bonus.
          # (this is not done for score because we don't keep trace)
          seq = if pos >= n and trace[pos - n] == DIAGONAL then seq_diag else 1


        seq_diag = seqRow[j]
        seqRow[j] = seq

        #determine bonus for matching A[i] with B[j]
        align = v_diag + seq * scoreMatchingChar(subject, subject_lw, query, i, j, abbrBonus)

      else
        seq_diag = seqRow[j]
        seqRow[j] = 0
        align = 0

      #Compare the score of making a match, a gap in Query (A), or a gap in Subject (B)
      v_diag = vRow[j]
      gapA = v_diag + we
      gapB = v + we
      gap = if(gapA > gapB) then gapA else gapB
      v = vRow[j] = if(align > gap) then align else gap

      # what triggered the best score ?
      #In case of equality, taking gapA get us closer to the start of the string.
      pos++ #pos = i * n + j
      switch v
        when 0
          trace[pos] = STOP
        when gapA
          trace[pos] = UP
        when gapB
          trace[pos] = LEFT
        when align
          trace[pos] = DIAGONAL
          #Record best score
          if v > vmax
            vmax = v
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
        matches.push i + offset
        j--
        i--
        pos -= n + 1
      else
        backtrack = false

  matches.reverse()
  return matches
