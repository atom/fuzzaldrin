path = require 'path'
{filter} = require '../src/fuzzaldrin'

bestMatch = (candidates, query) ->
  filter(candidates, query, maxResults: 1)[0]

rootPath = (segments...) ->
  joinedPath = if process.platform is 'win32' then 'C:\\' else '/'
  #joinedPath = path.sep
  for segment in segments
    if segment is path.sep
      joinedPath += segment
    else
      joinedPath = path.join(joinedPath, segment)
  joinedPath

describe "filtering", ->
  it "returns an array of the most accurate results", ->
    candidates = ['Gruntfile', 'filter', 'bile', null, '', undefined]
    expect(filter(candidates, 'file')).toEqual ['Gruntfile', 'filter']

  describe "when the maxResults option is set", ->
    it "limits the results to the result size", ->
      candidates = ['Gruntfile', 'filter', 'bile']
      expect(bestMatch(candidates, 'file')).toBe 'Gruntfile'

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

      expect(bestMatch([path.join('f', 'o', '1_a_z'), path.join('f', 'o', 'a_z')], 'az')).toBe path.join('f', 'o',
        'a_z')
      expect(bestMatch([path.join('f', '1_a_z'), path.join('f', 'o', 'a_z')], 'az')).toBe path.join('f', 'o', 'a_z')

    it "prefer shallow path", ->

      candidate = [
        path.join('b', 'z', 'file'),
        path.join('b_z', 'file')
      ]

      expect(bestMatch(candidate, "file")).toBe candidate[1]
      expect(bestMatch(candidate, "fle")).toBe candidate[1]

      candidate = [
        path.join('foo', 'bar', 'baz', 'file'),
        path.join('foo', 'bar_baz', 'file')
      ]

      expect(bestMatch(candidate, "file")).toBe candidate[1]
      expect(bestMatch(candidate, "fle")).toBe candidate[1]

    it "allow to search structure", ->
      candidate = [
        path.join('base', 'file'),
        path.join('bar', 'file')
      ]

      expect(bestMatch(candidate, "base file")).toBe candidate[0]
      expect(bestMatch(candidate, "as fle")).toBe candidate[0]


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

    it "weighs exact case matches higher even if string is longer", ->
      candidates = ['Diagnostic', 'diagnostics0000']
      expect(bestMatch(candidates, 'diag')).toBe candidates[1]


    it "weighs abbreviation matches after spaces, underscores, and dashes the same", ->
      expect(bestMatch(['sub-zero', 'sub zero', 'sub_zero'], 'sz')).toBe 'sub-zero'
      expect(bestMatch(['sub zero', 'sub_zero', 'sub-zero'], 'sz')).toBe 'sub zero'
      expect(bestMatch(['sub_zero', 'sub-zero', 'sub zero'], 'sz')).toBe 'sub_zero'


    it "weighs abbreviation higher than scattered letter in a smaller word (also not greeddy)", ->
      candidates = [
        'application.rb'
        'application_controller'
      ]
      expect(bestMatch(candidates, 'acon')).toBe candidates[1]

    it "weighs matches at the start of the string or base name higher", ->
      expect(bestMatch(['a_b_c', 'a_b'], 'ab')).toBe 'a_b'
      expect(bestMatch(['z_a_b', 'a_b'], 'ab')).toBe 'a_b'
      expect(bestMatch(['a_b_c', 'c_a_b'], 'ab')).toBe 'a_b_c'
      expect(bestMatch(['Unin-stall', path.join('dir1', 'dir2', 'dir3', 'Installation')],
        'install')).toBe path.join('dir1', 'dir2', 'dir3', 'Installation')
      expect(bestMatch(['Uninstall', path.join('dir', 'Install')], 'install')).toBe path.join('dir', 'Install')

    it "weighs CamelCase matches higher", ->
      candidates = [
        'FilterFactors.js',
        'FilterFactors.styl',
        'FilterFactors.html',
        'FilterFactorTests.html',
        'SpecFilterFactors.js'
      ]
      expect(bestMatch(candidates, 'FFT')).toBe 'FilterFactorTests.html'
      expect(bestMatch(candidates, 'fft')).toBe 'FilterFactorTests.html'

    it "weighs CamelCase matches higher than middle of word exact matches, or snake_abbrv", ->

      candidates = [
        'switch.css',
        'user_id_to_client',
        'ImportanceTableCtrl.js'
      ]
      expect(bestMatch(candidates, 'itc')).toBe candidates[2]
      expect(bestMatch(candidates, 'ITC')).toBe candidates[2]


    it "account for case in CamelCase vs Substring matches", ->

      candidates = [
        'CamelCaseClass.js',
        'cccManager.java00'
      ]
      expect(bestMatch(candidates, 'CCC')).toBe candidates[0]
      expect(bestMatch(candidates, 'ccc')).toBe candidates[1]

    it "prefer CamelCase that happens sooner", ->

      candidates = [
        'anotherCamelCase',
        'thisCamelCase000',
      ]
      expect(bestMatch(candidates, 'CC')).toBe candidates[1]

    it "prefer CamelCase in shorter haystack", ->

      candidates = [
        'CamelCase0',
        'CamelCase',
      ]
      expect(bestMatch(candidates, 'CC')).toBe candidates[1]

    it "prefer uninterrupted sequence CamelCase", ->

      candidates = [
        'CamelSkippedCase',
        'CamelCaseSkipped',
      ]
      expect(bestMatch(candidates, 'CC')).toBe candidates[1]

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

      candidates = [
        path.join('test', 'components', 'core', 'application', 'applicationPageStateServiceSpec.js')
        path.join('test', 'components', 'core', 'view', 'components', 'actions', 'actionsServiceSpec.js')
      ]
      expect(bestMatch(candidates, 'actionsServiceSpec.js')).toBe candidates[1]

  describe "When multiple result can match", ->
    it "returns the result in order", ->
      candidates = [
        'Find And Replace: Selet All',
        'Settings View: Uninstall Packages',
        'Settings View: View Installed Themes',
        'Application: Install Update',
        'install'
      ]
      result = filter(candidates, 'install')
      expect(result[0]).toBe candidates[4]
      expect(result[1]).toBe candidates[3]
      expect(result[2]).toBe candidates[2]
      expect(result[3]).toBe candidates[1]
      expect(result[4]).toBe candidates[0]

    it "weighs substring higher than individual characters", ->
    candidates = [
      'Git Plus: Stage Hunk',
      'Git Plus: Reset Head',
      'Git Plus: Push',
      'Git Plus: Show'
    ]
    expect(bestMatch(candidates, 'push')).toBe 'Git Plus: Push'
    expect(bestMatch(['a_b_c', 'somethingabc'], 'abc')).toBe 'somethingabc'