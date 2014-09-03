path = require 'path'
{filter} = require '../src/fuzzaldrin'

bestMatch = (candidates, query) ->
  filter(candidates, query, maxResults: 1)[0]

rootPath = (segments...) ->
  joinedPath = if process.platform is 'win32' then 'C:\\' else '/'
  for segment in segments
    if segment is path.sep
      joinedPath += segment
    else
      joinedPath = path.join(joinedPath, segment)
  joinedPath

describe "filtering", ->
  it "returns an array of the most accurate results", ->
    candidates = ['Gruntfile','filter', 'bile', null, '', undefined]
    expect(filter(candidates, 'file')).toEqual ['filter', 'Gruntfile']

  describe "when the maxResults option is set", ->
    it "limits the results to the result size", ->
      candidates = ['Gruntfile', 'filter', 'bile']
      expect(bestMatch(candidates, 'file')).toBe 'filter'

  describe "when the entries contains slashes", ->
    it "weighs basename matches higher", ->
      candidates = [
        rootPath('bar', 'foo')
        rootPath('foo', 'bar')
      ]
      expect(bestMatch(candidates, 'bar')).toBe candidates[1]

      candidates = [
        rootPath('bar', 'foo')
        rootPath('foo', 'bar', path.sep, path.sep, path.sep, path.sep, path.sep)
      ]
      expect(bestMatch(candidates, 'bar')).toBe candidates[1]

      candidates = [
        rootPath('bar', 'foo')
        rootPath('foo', 'bar')
        'bar'
      ]
      expect(bestMatch(candidates, 'bar')).toEqual candidates[2]

      candidates = [
        rootPath('bar', 'foo')
        rootPath('foo', 'bar')
        rootPath('bar')
      ]
      expect(bestMatch(candidates, 'bar')).toBe candidates[2]

      candidates = [
        rootPath('bar', 'foo')
        "bar#{path.sep}#{path.sep}#{path.sep}#{path.sep}#{path.sep}#{path.sep}"
      ]
      expect(bestMatch(candidates, 'bar')).toBe candidates[1]

      expect(bestMatch([path.join('f', 'o', '1_a_z'), path.join('f', 'o', 'a_z')], 'az')).toBe path.join('f', 'o', 'a_z')
      expect(bestMatch([path.join('f', '1_a_z'), path.join('f', 'o', 'a_z')], 'az')).toBe path.join('f', 'o', 'a_z')

  describe "when the candidate is all slashes", ->
    it "does not throw an exception", ->
      candidates = [path.sep]
      expect(filter(candidates, 'bar', maxResults: 1)).toEqual []

  describe "when the entries contains spaces", ->
    it "treats spaces as slashes", ->
      candidates = [
        rootPath('bar', 'foo')
        rootPath('foo', 'bar')
      ]
      expect(bestMatch(candidates, 'br f')).toBe candidates[0]

    it "weighs basename matches higher", ->
      candidates = [
        rootPath('bar', 'foo')
        rootPath('foo', 'bar foo')
      ]
      expect(bestMatch(candidates, 'br f')).toBe candidates[1]

      candidates = [
        rootPath('barfoo', 'foo')
        rootPath('foo', 'barfoo')
      ]
      expect(bestMatch(candidates, 'br f')).toBe candidates[1]

      candidates = [
        path.join('lib', 'exportable.rb')
        path.join('app', 'models', 'table.rb')
      ]
      expect(bestMatch(candidates, 'table')).toBe candidates[1]

  describe "when the entries contains mixed case", ->
    it "weighs exact case matches higher", ->
      candidates = ['statusurl', 'StatusUrl']
      expect(bestMatch(candidates, 'Status')).toBe 'StatusUrl'
      expect(bestMatch(candidates, 'SU')).toBe 'StatusUrl'
      expect(bestMatch(candidates, 'status')).toBe 'statusurl'
      expect(bestMatch(candidates, 'su')).toBe 'statusurl'
      expect(bestMatch(candidates, 'statusurl')).toBe 'statusurl'
      expect(bestMatch(candidates, 'StatusUrl')).toBe 'StatusUrl'

  it "weighs abbreviation matches after spaces, underscores, and dashes the same", ->
    expect(bestMatch(['sub-zero', 'sub zero', 'sub_zero'], 'sz')).toBe 'sub-zero'
    expect(bestMatch(['sub zero', 'sub_zero', 'sub-zero'], 'sz')).toBe 'sub zero'
    expect(bestMatch(['sub_zero', 'sub-zero', 'sub zero'], 'sz')).toBe 'sub_zero'

  it "weighs matches at the start of the string or base name higher", ->
    expect(bestMatch(['a_b_c', 'a_b'], 'ab')).toBe 'a_b'
    expect(bestMatch(['z_a_b', 'a_b'], 'ab')).toBe 'a_b'
    expect(bestMatch(['a_b_c', 'c_a_b'], 'ab')).toBe 'a_b_c'

  describe "when the entries are of differing directory depths", ->
    it "places exact matches first, even if they're deeper", ->
      candidates = [
        path.join('app', 'models', 'automotive', 'car.rb')
        path.join('spec', 'factories', 'cars.rb')
      ]
      expect(bestMatch(candidates, 'car.rb')).toBe candidates[0]

      candidates = [
        path.join('app', 'models', 'automotive', 'car.rb')
        'car.rb'
      ]
      expect(bestMatch(candidates, 'car.rb')).toBe candidates[1]

      candidates = [
        'car.rb',
        path.join('app', 'models', 'automotive', 'car.rb')
      ]
      expect(bestMatch(candidates, 'car.rb')).toBe candidates[0]

      candidates = [
        path.join('app', 'models', 'cars', 'car.rb')
        path.join('spec', 'cars.rb')
      ]
      expect(bestMatch(candidates, 'car.rb')).toBe candidates[0]
